# Check Point 01 — Grupo 1

[![security-gate](https://github.com/Snake-arch57/CP1_DEV_SEC_OPS/actions/workflows/security-gate.yml/badge.svg)](https://github.com/Snake-arch57/CP1_DEV_SEC_OPS/actions/workflows/security-gate.yml)

Ferramentas open source de SAST, DAST, IaC Security e SCA no pipeline.
DevSecOps — preparatório E|CDE, Módulo III.

**Integrantes:** Eduardo José *(relator)* · Hyago Antônio · Pedro Frommer *(líder técnico)* · Sarah Pereira · Vinicius Olivetti

---

## ⚠️ Leia antes de executar

Este repositório sobe o **DVWA (Damn Vulnerable Web Application)**, uma aplicação
**deliberadamente vulnerável**, com credenciais padrão e Security Level *Low*.
Isso é intencional — é o que faz as ferramentas encontrarem achados reais.

O `docker-compose.yml` publica o DVWA em **`127.0.0.1:8081`**, acessível só pela
sua máquina. **Não altere esse bind** para `0.0.0.0` nem exponha a porta na rede
da instituição ou na internet.

O DVWA consta na lista de alvos autorizados da seção 7 do enunciado. Varredura
contra qualquer alvo fora dessa lista é crime (Lei 12.737/2012, Art. 154-A) e
recebe nota zero no trabalho.

---

## As 4 ferramentas do grupo

| Categoria | Ferramenta | No lab ao vivo | Relatório versionado |
|---|---|---|---|
| SAST | OpenGrep | ✅ Ferramenta A | ✅ `reports/opengrep-dvwa.sarif` |
| DAST | Nikto | ✅ Ferramenta B | ✅ `reports/nikto-dvwa.json` |
| SCA | Snyk Open Source | execução offline | ✅ `reports/snyk-nodegoat.json` |
| IaC | Terrascan | execução offline | ✅ `reports/terrascan-terragoat.json` |

As 2 do laboratório conduzido são de **categorias diferentes** (SAST + DAST),
conforme exige a seção 5.3.

---

## Download de cada imagem

Exigido pela seção 5.3.3 do enunciado. Rode antes da aula — é o que permite
executar o laboratório sem depender da rede no dia.

| Item | Comando |
|---|---|
| DVWA (alvo) | `docker pull vulnerables/web-dvwa:latest` |
| Nikto (DAST) | `docker pull hysnsec/nikto:latest` |
| OpenGrep (SAST) | `docker compose build opengrep` |
| Código-fonte do DVWA | `bash scripts/preparar-alvo.sh` |

> **Por que o OpenGrep é compilado e não baixado:** não há imagem oficial
> publicada pela organização `opengrep` no Docker Hub. O `Dockerfile` instala o
> binário pelo script oficial do projeto, com a versão fixada em `v1.22.0`,
> para que todos rodem exatamente o mesmo build. Cuidado com a confusão comum:
> `returntocorp/opengrep` **não** é o OpenGrep — `returntocorp` é a organização
> antiga do **Semgrep**, projeto do qual o OpenGrep é um fork.

> **Por que o código-fonte é um item à parte:** o SAST analisa o **código** do
> DVWA, não a imagem em execução. Esse código não vem no repositório — está no
> `.gitignore`, porque versionar um repositório de terceiros poluiria o
> histórico de commits do grupo, que é avaliado. Se esquecer, o passo 2 falha
> com mensagem dizendo o que fazer, em vez de reportar "0 findings" e sair com
> sucesso.

A sequência completa, na ordem de execução, está na seção seguinte.

---

## Executar o laboratório

Duração estimada: **12 minutos**. Cada passo é **um bloco só** — copie inteiro,
cole no terminal, siga para o próximo. Todos os comandos foram executados e as
saídas abaixo são as reais.

Só os passos 1 e 6 pedem algo fora do terminal: o navegador e as respostas.

> Esta é a mesma sequência do [LAB.md](LAB.md), sem as explicações. O
> **[LAB.md](LAB.md) é o roteiro oficial** — traz o resultado esperado de cada
> passo, o que observar em cada saída e o troubleshooting. Havendo divergência
> entre os dois, vale o `LAB.md`.

### Passo 0 — preparar (antes da aula)

```bash
git clone https://github.com/Snake-arch57/CP1_DEV_SEC_OPS.git
cd CP1_DEV_SEC_OPS
docker compose pull
docker compose build
bash scripts/preparar-alvo.sh
echo "--- as tres imagens ---"
docker images | grep -E "dvwa|opengrep|nikto"
echo "--- o alvo do SAST ---"
ls targets/dvwa/vulnerabilities/sqli/source/
```

Você deve ver **três imagens** e o arquivo **`low.php`**. Se faltar alguma
coisa aqui, não siga em frente.

### Passo 1 — subir o ambiente

```bash
docker compose up -d dvwa
echo "aguardando o DVWA responder..."
until curl -sf -o /dev/null http://localhost:8081/; do sleep 3; done
echo "no ar: http://localhost:8081/setup.php"
```

Agora **no navegador**, uma vez só:

1. Abra <http://localhost:8081/setup.php>
2. Clique em **Create / Reset Database**
3. Login `admin`, senha `password`
4. Menu **DVWA Security** → **Low** → *Submit*

### Passo 2 — OpenGrep (SAST)

```bash
docker compose run --rm opengrep \
  --config=p/php \
  --config=p/owasp-top-ten \
  --sarif --output=/reports/opengrep-dvwa.sarif \
  /src
```

Esperado no fim: `Ran 126 rules on 250 files: 58 findings.`

### Passo 3 — achar o SQL Injection no relatório

```bash
echo "--- arquivos com achado de SQL Injection ---"
grep -oE '"uri":"[^"]*sqli[^"]*"' reports/opengrep-dvwa.sarif | sort -u
echo "--- linhas em sqli/source/low.php ---"
grep -oE 'sqli/source/low\.php.{0,160}' reports/opengrep-dvwa.sarif \
  | grep -oE '"endLine":[0-9]+'
```

Saída real:

```
--- arquivos com achado de SQL Injection ---
"uri":"/src/vulnerabilities/sqli/source/low.php"
"uri":"/src/vulnerabilities/sqli_blind/source/high.php"
"uri":"/src/vulnerabilities/sqli_blind/source/low.php"
"uri":"/src/vulnerabilities/sqli_blind/source/medium.php"
--- linhas em sqli/source/low.php ---
"endLine":10
"endLine":31
```

São **2 achados** em `vulnerabilities/sqli/source/low.php` — guarde o número,
é a resposta da pergunta 1. Repare que há SQL Injection também no módulo
`sqli_blind`: o gate conta só `vulnerabilities/sqli/`, o módulo em remediação.

### Passo 4 — Nikto (DAST)

```bash
docker compose run --rm nikto \
  -h http://dvwa:80 \
  -Format txt -o /reports/nikto-dvwa.txt
```

Procure na saída, e guarde para a pergunta 2:

```
+ /config/: Directory indexing found.
+ /docs/: Directory indexing found.
+ The anti-clickjacking X-Frame-Options header is not present.
```

### Passo 5 — o gate decide o deploy

Nada para rodar: as duas execuções já estão no Actions, prontas para comparar.

| | Execução | Resultado |
|---|---|---|
| 🔴 | [build vermelho](https://github.com/Snake-arch57/CP1_DEV_SEC_OPS/actions/runs/34763310159) | `SAST=2 DAST=2 TOTAL=4` — deploy **bloqueado** |
| 🟢 | [build verde](https://github.com/Snake-arch57/CP1_DEV_SEC_OPS/actions/runs/34762690575) | `TOTAL=0` — deploy **executado** |

No vermelho, repare que `config-do-deploy` e `deploy` aparecem **pulados**, não
como falha: o deploy não quebrou, foi bloqueado pelo gate.

### Passo 6 — as duas perguntas de verificação

Entregue individualmente ao final da aula, junto com o print do output final de
cada ferramenta:

1. Quantos achados de severidade **HIGH** (nível `error` no SARIF) o OpenGrep
   reportou em `vulnerabilities/sqli/source/low.php`?
2. Qual **CWE** está associado a esse achado, e qual header de segurança o
   Nikto reportou como ausente no DVWA?

A primeira sai do passo 3, a segunda do passo 4 mais o CWE que o próprio
relatório registra.

### Passo 7 — encerrar

```bash
docker compose down -v
```

---

## Pipeline com gate de severidade

O workflow [`security-gate.yml`](.github/workflows/security-gate.yml) roda as
**duas ferramentas** e decide se o build passa:

```
guarda-de-escopo ─┐
sast-opengrep ────┼─→ security-gate ─→ config-do-deploy ─→ deploy
dast-nikto ───────┘
```

| Job | O que faz |
|---|---|
| `guarda-de-escopo` | falha se o `docker-compose.yml` expuser o DVWA fora de `localhost` |
| `sast-opengrep` | compila o OpenGrep, analisa o código do DVWA, gera SARIF |
| `dast-nikto` | sobe o DVWA, roda o Nikto contra a aplicação no ar |
| `security-gate` | soma os achados HIGH das duas e quebra o build se houver algum |
| `deploy` | publica na VM Azure — **só** em push na `main` e **só** com o gate verde |

Em `push` e `pull_request` o pipeline aplica as duas correções antes de medir,
e o gate passa. O **build vermelho** se reproduz em *Actions > security-gate >
Run workflow* com a opção `remediacao` **desmarcada** — os dois prints que o
requisito 5 exige saem daí.

### Mapeamento de severidade

O enunciado pede gate em HIGH/CRITICAL; nenhuma das duas ferramentas usa esses
rótulos. O critério abaixo é decisão do grupo:

| Ferramenta | Rótulo nativo | Mapeado para |
|---|---|---|
| OpenGrep | `error` (na definição da regra) | HIGH |
| OpenGrep | `warning` / `note` | MEDIUM / LOW |
| Nikto | achado na lista `NIKTO_HIGH` | HIGH |
| Nikto | demais achados | MEDIUM / LOW |

O Nikto **não emite severidade** — ele lista itens encontrados. A lista
`NIKTO_HIGH` reúne os padrões que representam exposição de informação ou
execução, e não apenas ausência de hardening.

O OpenGrep também não escreve a severidade em cada achado: ela fica na
definição da regra, e o achado herda. O gate monta o mapa `ruleId → level`
antes de contar — filtrar direto pelo campo `level` do resultado retorna zero.

---

## Estrutura

```
.
├── README.md                        # este arquivo
├── LAB.md                           # roteiro do laboratório (12 min)
├── DEPLOY.md                        # preparação da VM Azure e secrets
├── USO-DE-IA.md                     # declaração de uso de IA (seção 10)
├── VIBE.md                          # registro do que foi feito no código
├── docs/
│   └── revisao-de-codigo-2026-09-12.pdf  # relatório da revisão de código
├── docker-compose.yml               # DVWA + OpenGrep + Nikto
├── docker-compose.hardening.yml     # override de remediação (CI e deploy)
├── Dockerfile                       # imagem do OpenGrep
├── .gitignore                       # mantém targets/ fora do repositório
├── CLAUDE.md                        # regras do repo para o Claude Code
├── .claude/                         # contexto de apoio ao Claude Code
├── .github/workflows/
│   └── security-gate.yml            # pipeline com gate e deploy
├── hardening/
│   └── no-indexes.conf              # Options -Indexes (correção do DAST)
├── patches/
│   └── fix-sqli.php                 # correção do SQLi (correção do SAST)
├── entrypoint-opengrep.sh            # guarda: falha se o alvo do SAST estiver vazio
├── scripts/
│   ├── preparar-alvo.sh             # clona o codigo-fonte do DVWA
│   ├── verificar-escopo.sh          # guarda de escopo (CI + VM)
│   ├── rodar-sca-iac.sh             # executa Terrascan e Snyk
│   ├── testar-sqli.py               # prova a correção na aplicação no ar
│   └── resumir-achados.py           # conta os achados dos 4 relatórios
├── reports/                         # relatórios de saída versionados
└── evidencias/                      # prints de build vermelho e verde
```

---

## Documentos

- **[LAB.md](LAB.md)** — roteiro conduzido, troubleshooting e análise dos achados
- **[DEPLOY.md](DEPLOY.md)** — preparação da VM, chave de CI, secrets e NSG
- **[USO-DE-IA.md](USO-DE-IA.md)** — o que foi gerado com IA e como foi validado
- **[VIBE.md](VIBE.md)** — registro do trabalho de código: o que mudou, por quê
  e o que ficou pendente
- **[docs/revisao-de-codigo-2026-09-12.pdf](docs/revisao-de-codigo-2026-09-12.pdf)**
  — o mesmo conteúdo em relatório fechado, para anexar ou imprimir
- **[reports/README.md](reports/README.md)** — o que cada relatório contém, com
  os números conferidos
- **[evidencias/execucao-local-2026-09-12.md](evidencias/execucao-local-2026-09-12.md)**
  — execução local completa: gate nas duas pontas, tempos medidos, e a prova
  de que as duas correções funcionam
