# Relatórios versionados

Evidência exigida pela seção 10 do enunciado ("toda afirmação técnica deve ser
verificável... deve haver evidência disso nos relatórios versionados") e pela
rubrica da seção 9 (5 pts).

Todos os números abaixo foram **contados nestes arquivos**. Para recontar:

```bash
python3 scripts/resumir-achados.py
```

| Arquivo | Ferramenta | Estado |
|---|---|---|
| `opengrep-dvwa.sarif` | OpenGrep (SAST) | antes da remediação |
| `opengrep-dvwa-remediado.sarif` | OpenGrep (SAST) | depois da remediação |
| `nikto-dvwa.json` / `.txt` | Nikto (DAST) | antes da remediação |
| `nikto-dvwa-remediado.json` | Nikto (DAST) | depois da remediação |
| `terrascan-terragoat.json` | Terrascan (IaC) | alvo TerraGoat |
| `snyk-nodegoat.json` | Snyk (SCA) | alvo NodeGoat |
| `tempos.txt` | — | tempo medido de cada execução |
| `resumo-achados.md` | — | tabela gerada pelo script |

---

## OpenGrep (SAST) — alvo: código-fonte do DVWA

| | antes | depois |
|---|---|---|
| Achados totais | 58 | 56 |
| `error` (= HIGH no mapeamento do grupo) | 25 | 23 |
| `warning` (= MEDIUM) | 33 | 33 |
| `error` em `vulnerabilities/sqli/` (escopo do gate) | **2** | **0** |
| Arquivos com achado | 24 | — |

Tempo de execução medido: **31 s**. Saída literal da ferramenta:
`Ran 126 rules on 250 files: 58 findings.` — das 561 regras que o SARIF
registra no driver, 126 se aplicaram às linguagens encontradas.

Os 2 achados em escopo são a mesma regra
(`php.lang.security.injection.tainted-sql-string.tainted-sql-string`), nas
linhas **10 e 31** de `vulnerabilities/sqli/source/low.php` — o SQL Injection
que `patches/fix-sqli.php` corrige. O `-remediado` é a mesma varredura com o
patch aplicado: os dois somem, e nada mais muda.

> A severidade não está em cada achado: fica em
> `tool.driver.rules[].defaultConfiguration.level`, e o achado herda dela.
> Filtrar pelo campo `level` de cada `result` devolve zero — foi o primeiro
> bug do gate, registrado no `LAB.md`.

## Nikto (DAST) — alvo: DVWA em execução

Gerado por **Nikto 2.5.0**, 7857 requisições, **6 s** por varredura.

| | antes | depois |
|---|---|---|
| Itens reportados | 15 | 12 |
| Na lista `NIKTO_HIGH` (= HIGH) | **2** | **0** |

Os 2 em HIGH são `Directory indexing found.` em `/config/` e em `/docs/`,
corrigidos por `hardening/no-indexes.conf` (`Options -Indexes`). Conferido na
aplicação no ar: sem o override, `/config/` responde **200 com `Index of
/config`**; com ele, **403**.

O Nikto não emite severidade — o corte é a lista `NIKTO_HIGH`, decisão
documentada do grupo.

### `nikto-dvwa.txt` — cuidado ao ler

O Nikto **acrescenta** ao arquivo de saída em vez de sobrescrever, então este
arquivo contém **três execuções empilhadas**: duas com **Nikto 2.1.5** e uma
com **2.5.0** (a que corresponde ao `.json`).

As duas versões reportam de forma diferente, e isso não é detalhe de
formatação:

- na 2.1.5 a mensagem repetia o caminho (`GET /config/: /config/: Directory
  indexing found.`); na 2.5.0 o caminho fica só no campo `url`. O gate testa
  `url + msg` por causa disso — casar só em `msg` fazia os padrões de caminho
  da lista `NIKTO_HIGH` nunca casarem
- a 2.5.0 reporta headers de segurança ausentes (CSP, HSTS,
  `x-content-type-options`, `referrer-policy`, `permissions-policy`) e o
  `.gitignore`, que a 2.1.5 não trazia

**Pendência:** `docker-compose.yml` usa `hysnsec/nikto:latest`, e foi essa tag
que mudou de versão entre as execuções. O mesmo vale para
`vulnerables/web-dvwa:latest` (a imagem atual traz **DVWA 1.9 com PHP
7.0.30**). Fixar as duas tags — como o `Dockerfile` já faz com
`OPENGREP_VERSION=v1.22.0` — é o que garante que a turma veja todos o mesmo
resultado.

## Terrascan (IaC) — alvo: TerraGoat

494 políticas validadas, **67 violações** em **10 s**:

| Severidade | Violações |
|---|---|
| HIGH | 35 |
| MEDIUM | 27 |
| LOW | 5 |

Por provedor: AWS 42, Azure 14, GCP 11. Três exemplos HIGH estão em
[`../evidencias/execucao-local-2026-09-12.md`](../evidencias/execucao-local-2026-09-12.md),
para a análise crítica.

## Snyk Open Source (SCA) — `snyk-nodegoat.json`

Alvo: **OWASP NodeGoat** (`npm`), da lista autorizada da seção 7.
Execução em **10 s**, sobre **341 dependências** declaradas.

| Severidade | Achados |
|---|---|
| CRITICAL | 0 |
| HIGH | 170 |
| MEDIUM | 68 |
| LOW | 133 |
| **Total** | **371** |

### Dois números, e a diferença entre eles

O relatório traz `"uniqueCount": 80` ao lado dos 371 achados. São **371
caminhos de dependência** levando a **80 vulnerabilidades distintas** — o
mesmo CVE alcançado por rotas diferentes na árvore de pacotes.

Essa distinção não existe nas outras três categorias. No SAST, um achado é uma
ocorrência no código; no SCA, um achado é um *caminho até* um pacote
vulnerável. Comparar totais brutos entre categorias leva à conclusão errada.

### Por que o SCA encontra tanto

371 achados, contra 140 das outras três somadas. Não é a ferramenta ser
melhor: é a categoria olhar outra coisa. O SCA consulta uma base de
vulnerabilidades conhecidas contra as dependências declaradas — e um projeto
Node arrasta centenas de pacotes transitivos que ninguém da equipe escolheu
diretamente.

É o ponto que o enunciado chama de "a confusão mais comum da disciplina:
SAST não é SCA". Aqui ele está medido, com dados do grupo.

### Reproduzir

```bash
SNYK_TOKEN=<seu-token> bash scripts/rodar-sca-iac.sh
```

Token gratuito em snyk.io > Account settings. **Nunca commitem o token** — o
`.gitignore` bloqueia `.env`, mas o certo é não escrever em arquivo nenhum.
