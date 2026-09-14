# Evidências

Exigido pelo requisito 5 da seção 5.3 e pelo Anexo B do enunciado.

| Arquivo | O que é |
|---|---|
| [`build-vermelho.png`](build-vermelho.png) | gate reprovando e **bloqueando o deploy** |
| [`build-verde.png`](build-verde.png) | gate aprovando e **liberando o deploy** |
| [`execucao-local-2026-09-12.md`](execucao-local-2026-09-12.md) | execução local completa: o gate nas duas pontas, tempos medidos das ferramentas, e a prova de que as duas correções funcionam na aplicação no ar |


## Plano B — requisito 6 da seção 5.3

O vídeo da execução completa do laboratório **foi gravado e entregue pelo
Teams**, junto com os demais artefatos. Não está versionado aqui por causa do
tamanho.

O que ele cobre, na ordem do [`../README.md`](../README.md):

| Cena | Conteúdo |
|---|---|
| Passo 0 | preparação: imagens, build do OpenGrep e clone do alvo |
| Passo 1 | DVWA no ar em `127.0.0.1:8081` |
| Passo 2 | OpenGrep — `Ran 126 rules on 250 files: 58 findings` |
| Passo 3 | o SQL Injection localizado em `sqli/source/low.php`, linhas 10 e 31 |
| Passo 4 | Nikto — `Directory indexing` em `/config/` e `/docs/` |
| Passo 5 | gate vermelho bloqueando e verde liberando o deploy |
| Passo 7 | `docker compose down -v` |

Serve para o caso de falha de rede ou de ambiente no dia da apresentação: o
grupo passa a gravação e a demonstração continua.

---

## Build vermelho

Execução [`34763310159`](https://github.com/Snake-arch57/CP1_DEV_SEC_OPS/actions/runs/34763310159),
disparada em *Actions > security-gate > Run workflow* com a opção
`remediacao` **desmarcada**.

```
OpenGrep: 2 achado(s) HIGH em vulnerabilities/sqli/ (de 25 no DVWA inteiro)
  - /src/vulnerabilities/sqli/source/low.php:10  ...tainted-sql-string
  - /src/vulnerabilities/sqli/source/low.php:31  ...tainted-sql-string

Nikto: 2 achado(s) HIGH
  - /config/  Directory indexing found.
  - /docs/    Directory indexing found.

SAST=2  DAST=2  TOTAL=4
Gate REPROVADO — 4 achado(s) de severidade HIGH. Deploy bloqueado.
```

O print traz os quatro achados **nomeados**, com arquivo, linha e regra. É a
rastreabilidade que o passo 5 do `LAB.md` pede: o achado que a turma procura
no SARIF durante o passo 3 é literalmente o mesmo que derruba o build.

| Job | Resultado |
|---|---|
| `guarda-de-escopo` | ✅ |
| `sast-opengrep` | ✅ 2 achados `error` em `vulnerabilities/sqli/` — patch não aplicado |
| `dast-nikto` | ✅ 2 `Directory indexing` — DVWA sem o override de hardening |
| `security-gate` | ❌ **falhou** |
| `config-do-deploy` | ⏭️ **pulado** |
| `deploy` | ⏭️ **pulado** |

O detalhe que importa: os dois últimos aparecem como **pulados**, não como
falha. O deploy não quebrou — foi **bloqueado** pelo gate, que é exatamente o
que o requisito 5 pede para demonstrar.

## Build verde

Execução [`34762690575`](https://github.com/Snake-arch57/CP1_DEV_SEC_OPS/actions/runs/34762690575),
um `push` na `main`, que aplica as duas correções antes de medir.

```
REMEDIAR: true
SAST_COUNT: 0   SAST_TOTAL: 23   SAST_ESCOPO: vulnerabilities/sqli/
DAST_COUNT: 0
SAST=0  DAST=0  TOTAL=0
Gate APROVADO — nenhum achado HIGH.
```

Os seis jobs em verde, incluindo o `deploy`, que publicou na VM Azure.

---

## Como ler os dois lado a lado

Mesma pipeline, mesmo código, mesmas ferramentas. A única variável é se as
correções foram aplicadas antes de medir:

| | Vermelho | Verde |
|---|---|---|
| `patches/fix-sqli.php` aplicado | não | sim |
| `docker-compose.hardening.yml` | não | sim |
| Achados `error` no DVWA inteiro | 25 | **23** |
| Achados HIGH no escopo do gate | 4 | **0** |
| Deploy | bloqueado | executado |

A diferença de 2 no total do DVWA são precisamente os achados de SQL Injection
que o patch elimina — o mesmo número que sai do escopo do gate pelo lado do
SAST.

## Como reproduzir

**Vermelho** — *Actions > security-gate > Run workflow*, desmarcando
`remediacao`. Ou, pela linha de comando:

```bash
gh workflow run security-gate.yml -f remediacao=false
```

**Verde** — qualquer `push` na `main`, ou o mesmo comando com
`-f remediacao=true`.

> Os prints vêm da tela do job `security-gate`, com o step **"Decisao do gate"**
> expandido. A aba **Summary** da execução traz a mesma informação em tabela
> formatada e serve igualmente: o job escreve nas duas.
