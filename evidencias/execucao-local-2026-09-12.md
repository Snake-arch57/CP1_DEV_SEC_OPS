# Execução local completa — 2026-09-12

Tudo abaixo foi **executado**, não estimado. Docker Engine 29.7.2, containers
Linux, tudo em `127.0.0.1`.

Reproduzir:

```bash
docker compose up -d dvwa                      # ou com o override de hardening
python3 scripts/testar-sqli.py                 # prova da correção do SQLi
bash scripts/rodar-sca-iac.sh                  # Terrascan (e Snyk, com token)
python3 scripts/resumir-achados.py             # tabela de contagens
```

---

## 1. Resumo: o gate nas duas pontas

| | sem remediação | com remediação |
|---|---|---|
| OpenGrep — achados totais | 58 | 56 |
| OpenGrep — nível `error` | 25 | 23 |
| OpenGrep — `error` em `vulnerabilities/sqli/` (**o que o gate conta**) | **2** | **0** |
| Nikto — itens reportados | 15 | 12 |
| Nikto — na lista `NIKTO_HIGH` (**o que o gate conta**) | **2** | **0** |
| **Decisão do gate** | **REPROVADO — total 4** | **APROVADO — total 0** |

Os programas `jq` do job `security-gate` foram rodados contra esses relatórios
e devolveram exatamente esses números.

### Saída do gate, sem remediação

```
OpenGrep: 2 achado(s) HIGH em vulnerabilities/sqli/ (de 25 no DVWA inteiro)
  - /src/vulnerabilities/sqli/source/low.php:10  php.lang.security.injection.tainted-sql-string.tainted-sql-string
  - /src/vulnerabilities/sqli/source/low.php:31  php.lang.security.injection.tainted-sql-string.tainted-sql-string
Nikto: 2 achado(s) HIGH
  - /config/  Directory indexing found.
  - /docs/    Directory indexing found.
SAST=2  DAST=2  TOTAL=4
::error::Gate REPROVADO — 4 achado(s) de severidade HIGH. Deploy bloqueado.
```

### Saída do gate, com remediação

```
OpenGrep: 0 achado(s) HIGH em vulnerabilities/sqli/ (de 23 no DVWA inteiro)
Nikto: 0 achado(s) HIGH
SAST=0  DAST=0  TOTAL=0
Gate APROVADO — nenhum achado HIGH.
```

> Falta ainda o **print do GitHub Actions** — esta é a execução local. O job
> `security-gate` imprime essa mesma tabela na aba *Summary* da execução, e é
> dali que sai o print para esta pasta.

## 2. Tempos de execução medidos (seção 6e)

| Ferramenta | Alvo | Tempo | Achados |
|---|---|---|---|
| OpenGrep 1.22.0 | DVWA (250 arquivos) | **31 s** | 58 (25 error, 33 warning) |
| Nikto 2.5.0 | DVWA no ar (7857 requisições) | **6 s** | 15 itens |
| Terrascan | TerraGoat (494 políticas) | **10 s** | 67 (35 HIGH, 27 MEDIUM, 5 LOW) |
| Snyk Open Source | NodeGoat | — | **não executado** (falta token) |

Valores em `reports/tempos.txt`, recontáveis com
`python3 scripts/resumir-achados.py`.

Saída literal do OpenGrep: `Ran 126 rules on 250 files: 58 findings.` — das
561 regras que o SARIF registra, 126 se aplicaram às linguagens encontradas.

## 3. SAST — a correção do SQL Injection funciona no código

```
sem patch   total= 58  error= 25  error em vulnerabilities/sqli/ = 2
COM patch   total= 56  error= 23  error em vulnerabilities/sqli/ = 0
```

Confirma a afirmação do `LAB.md`: 25 → 23, e o escopo do gate a zero. As duas
ocorrências removidas são a mesma regra, nas linhas 10 e 31 de
`vulnerabilities/sqli/source/low.php`.

Relatórios: `reports/opengrep-dvwa.sarif` (antes) e
`reports/opengrep-dvwa-remediado.sarif` (depois).

## 4. SAST — e funciona na aplicação no ar

`python3 scripts/testar-sqli.py`, nível de segurança **low** confirmado
(formulário sem `user_token`, ou seja `low.php` e não `impossible.php`):

### Antes da correção

| caso | payload | linhas |
|---|---|---|
| consulta legítima | `1` | 1 |
| consulta legítima | `3` | 1 |
| id inexistente | `999` | 0 |
| injeção clássica | `1' OR '1'='1` | **5 — tabela inteira** |
| injeção sem dígito inicial | `' OR '1'='1` | **5 — tabela inteira** |
| injeção com comentário | `1' OR 1=1 -- ` | **5 — tabela inteira** |
| union select | `1' UNION SELECT user, password FROM users -- ` | **6 — tabela inteira** |
| aspas soltas | `'` | 0 — **erro de SQL vazando na página** |

### Depois da correção

| caso | payload | linhas |
|---|---|---|
| consulta legítima | `1` | 1 |
| consulta legítima | `3` | 1 |
| id inexistente | `999` | 0 |
| injeção clássica | `1' OR '1'='1` | 1 |
| injeção sem dígito inicial | `' OR '1'='1` | 0 |
| injeção com comentário | `1' OR 1=1 -- ` | 1 |
| union select | `1' UNION SELECT user, password FROM users -- ` | 1 |
| aspas soltas | `'` | 0 |

Zero notices ou erros de PHP vindos de `low.php`.

> **Por que `1' OR '1'='1` ainda devolve 1 linha, e por que isso não é
> injeção.** O prepared statement entrega a string inteira como *dado*. O
> MySQL então compara a coluna `user_id`, que é inteira, com essa string, e
> faz conversão numérica implícita: o prefixo `1` vira o número 1, e a
> consulta acha o usuário 1. Nada do payload foi interpretado como SQL — a
> prova é `' OR '1'='1`, sem dígito no início, que devolve **0** linhas.
> Antes da correção os dois devolviam as 5.
>
> É um detalhe que vale levar para a apresentação: "0 linhas" não é o único
> resultado possível de uma correção certa, e "1 linha" não é sinal de que a
> injeção continua.

## 5. DAST — a correção do directory indexing funciona

`/config/` é onde o DVWA guarda a configuração do banco.

| Estado | `/config/` | `/docs/` |
|---|---|---|
| sem `docker-compose.hardening.yml` | **HTTP 200, `Index of /config` — listagem exposta** | **HTTP 200, listagem exposta** |
| com o override (`Options -Indexes`) | HTTP 403 | HTTP 403 |

Nikto, na mesma comparação: 15 itens e 2 HIGH sem hardening; 12 itens e
0 HIGH com hardening.

Relatórios: `reports/nikto-dvwa.json` (antes) e
`reports/nikto-dvwa-remediado.json` (depois).

## 6. IaC — Terrascan no TerraGoat

Primeira execução da ferramenta no trabalho. 494 políticas validadas,
**67 violações** em 10 segundos:

| Severidade | Violações |
|---|---|
| HIGH | 35 |
| MEDIUM | 27 |
| LOW | 5 |

Por provedor: AWS 42, Azure 14, GCP 11.

Três exemplos HIGH, para a análise crítica:

| Regra | Recurso | Arquivo |
|---|---|---|
| `keyVaultAuditLoggingEnabled` | `azurerm_key_vault` | `terraform/azure/key_vault.tf:1` |
| `sqlServerADAdminConfigured` | `azurerm_sql_server` | `terraform/azure/sql.tf:9` |
| `sslConnectionEnabled` | `azurerm_mysql_server` | `terraform/azure/sql.tf:44` |

Relatório: `reports/terrascan-terragoat.json`.

## 7. Guarda de escopo — testada contra exposição

`scripts/verificar-escopo.sh` em modo estrito (`docker compose config`):

| Caso | Resultado |
|---|---|
| arquivo inalterado | ✅ passa |
| `- "8081:80"` (todas as interfaces) | ❌ reprova — `dvwa: 0.0.0.0:8081 -> 80` |
| `- "0.0.0.0:8081:80"` | ❌ reprova |
| `- "192.168.0.10:8081:80"` | ❌ reprova — nomeia o IP |
| porta pública **acrescentada** ao lado do bind local | ❌ reprova — `dvwa: 0.0.0.0:9090 -> 80` |
| porta do DVWA trocada para 8082 | ❌ reprova — a documentação assume 8081 |

O último caso da lista era o buraco da versão anterior, que só olhava a linha
do DVWA e deixava passar uma porta acrescentada.

## 8. O que ainda não foi executado

- **Snyk Open Source** — exige token de conta (`SNYK_TOKEN`). É a única das
  quatro ferramentas sem nenhuma evidência
- **O pipeline no GitHub Actions** — tudo acima rodou localmente. Faltam os
  prints das duas execuções (`remediacao` marcada e desmarcada)
