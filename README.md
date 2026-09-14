# Check Point 01 — Grupo 1

[![security-gate](https://github.com/Snake-arch57/CP1_DEV_SEC_OPS/actions/workflows/security-gate.yml/badge.svg)](https://github.com/Snake-arch57/CP1_DEV_SEC_OPS/actions/workflows/security-gate.yml)

Ferramentas open source de SAST, DAST, IaC Security e SCA no pipeline.
DevSecOps — preparatório E|CDE, Módulo III.

**Integrantes:** _____________________________

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

## Download das imagens

Rode antes da aula — é o que permite executar o laboratório sem depender da rede
no dia:

```bash
git clone https://github.com/Snake-arch57/CP1_DEV_SEC_OPS.git
cd CP1_DEV_SEC_OPS

docker pull vulnerables/web-dvwa:latest
docker pull hysnsec/nikto:latest
docker compose build opengrep
```

> O OpenGrep é **compilado**, não baixado: não há imagem oficial publicada pela
> organização `opengrep` no Docker Hub. O `Dockerfile` instala o binário pelo
> script oficial do projeto, com a versão fixada em `v1.22.0` para que todos
> rodem exatamente o mesmo build.

O SAST analisa o **código-fonte** do DVWA, não a imagem em execução — e esse
código **não vem com o repositório**. Prepare o alvo antes do passo 2:

```bash
bash scripts/preparar-alvo.sh
```

O script clona o DVWA em `targets/dvwa` se ainda não existir, e não faz nada se
já existir. O equivalente manual é
`git clone https://github.com/digininja/DVWA.git targets/dvwa`.

Verificação:

```bash
docker images | grep -E "dvwa|opengrep|nikto"   # as três imagens
ls targets/dvwa/vulnerabilities/sqli/source/    # o alvo do passo 2
```

> Se esquecer o alvo, o passo 2 **falha com mensagem dizendo o que fazer** — a
> imagem do OpenGrep confere o diretório antes de varrer, em vez de reportar
> "0 findings" e sair com sucesso.

---

## Executar o laboratório

O roteiro completo, com comandos copiáveis e resultado esperado de cada passo,
está em **[LAB.md](LAB.md)**. Duração estimada: 12 minutos.

```bash
docker compose up -d dvwa     # passo 1
# ... siga o LAB.md
docker compose down -v        # passo 7
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
