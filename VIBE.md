# VIBE.md — registro do trabalho de código

O que este arquivo é: o diário da **parte de código** do Check Point 01 — o
que foi mexido, por que, como foi conferido e o que ficou pendente. Serve para
qualquer integrante (ou qualquer sessão de IA) retomar o trabalho sem
reconstruir o raciocínio, e para a apresentação: cada mudança aqui tem o
motivo escrito, e qualquer um do grupo pode ser questionado sobre ela.

Não substitui nenhum documento exigido pelo enunciado. A declaração de uso de
IA continua em [`USO-DE-IA.md`](USO-DE-IA.md), o roteiro em
[`LAB.md`](LAB.md), o deploy em [`DEPLOY.md`](DEPLOY.md).

**Divisão do trabalho:** este arquivo cobre só código e pipeline. Documento de
pesquisa (seção 6), vídeo de plano B, apresentação e prints são de outros
integrantes.

---

## Estado atual

| Frente | Estado |
|---|---|
| Ambiente (`docker-compose.yml`, `Dockerfile`) | ✅ funcionando |
| SAST — OpenGrep | ✅ executado, antes e depois da remediação |
| DAST — Nikto | ✅ executado, antes e depois da remediação |
| IaC — Terrascan | ✅ executado, 67 violações no TerraGoat |
| SCA — Snyk Open Source | ⬜ **automatizado, falta o token** |
| Pipeline + gate de severidade | ✅ validado localmente nas duas pontas |
| Build vermelho e verde | ✅ reproduzíveis sob demanda |
| Deploy na VM Azure | ✅ funcionando, bloqueado pelo gate |
| Correção do SQLi na aplicação no ar | ✅ verificada |
| Correção do directory indexing | ✅ verificada |
| Prints do GitHub Actions em `evidencias/` | ⬜ faltam |

Números **medidos** (recontáveis com `python3 scripts/resumir-achados.py`;
detalhe em [`evidencias/execucao-local-2026-09-12.md`](evidencias/execucao-local-2026-09-12.md)):

| | sem remediação | com remediação |
|---|---|---|
| OpenGrep — totais | 58 (24 arquivos) | 56 |
| OpenGrep — `error` | 25 | 23 |
| OpenGrep — `error` em `sqli/` (gate) | **2** | **0** |
| Nikto — itens | 15 | 12 |
| Nikto — `NIKTO_HIGH` (gate) | **2** | **0** |
| **Gate** | **REPROVADO (4)** | **APROVADO (0)** |

Tempos: OpenGrep 31 s, Nikto 6 s, Terrascan 10 s.

---

## 2026-09-12 — revisão do código e do pipeline

Revisão completa do lado de código, com correção dos problemas encontrados.
Tudo abaixo foi conferido contra os relatórios reais em `reports/`, não contra
o que a documentação afirmava.

### 1. O build vermelho tinha deixado de ser reproduzível

**Problema.** O job `sast-opengrep` aplicava `patches/fix-sqli.php` e o
`dast-nikto` subia o DVWA com `docker-compose.hardening.yml` em **toda**
execução. Depois que as duas correções entraram, todo `push` e todo
`pull_request` davam verde — e não havia mais como gerar o print do build
vermelho que o requisito 5 exige, a não ser editando o workflow e commitando
a edição.

**Correção.** O `workflow_dispatch` ganhou a entrada booleana `remediacao`
(padrão: marcada). `push` e `pull_request` continuam sempre remediando; rodar
à mão com a caixa desmarcada reproduz o estado vulnerável:

```
Actions > security-gate > Run workflow > remediacao: [ ]
```

Uma variável de ambiente só, `REMEDIAR`, controla os dois jobs — o passo do
patch no SAST e a lista de arquivos do Compose no DAST. E o job de DAST passou
a **verificar as duas direções**: com remediação, exige o `no-indexes.conf`
montado; sem remediação, exige que ele **não** esteja. Sem essa segunda
checagem, um vermelho que subisse com hardening por engano daria "0 achados" e
seria lido como "o Nikto não achou nada".

### 2. O gate de DAST não casava mais com os padrões de caminho

**Problema — o mais sério dos encontrados.** O filtro `jq` testava a lista
`NIKTO_HIGH` só contra o campo `msg`. Na **Nikto 2.1.5** a mensagem repetia o
caminho (`GET /config/: /config/: Directory indexing found.`), então padrões
como `/admin`, `/\.git/`, `backup` e `test/` casavam — por acidente. A
**2.5.0**, que gerou o `reports/nikto-dvwa.json` versionado, deixou o caminho
apenas no campo `url`.

Consequência: quatro dos sete padrões da política do grupo não casavam com
nada. **Um diretório `/.git/` exposto passaria pelo gate** — exatamente o
achado que a correção do falso positivo (o `\.git` que virou `/\.git/`) tinha
sido escrita para proteger.

**Correção.** O teste passou a rodar sobre `url + " " + msg`. Conferido nos
relatórios versionados: **2 achados antes e 2 depois** — a mudança devolve a
intenção da política sem alterar nenhum número já publicado.

### 3. A guarda de escopo tinha um buraco

**Problema.** O job `guarda-de-escopo` fazia dois `grep` no
`docker-compose.yml`: um recusava `0.0.0.0:<porta>:80` e outro exigia a
presença literal de `127.0.0.1:8081:80`. **Acrescentar** uma porta pública ao
lado do bind local passava pelos dois. É a única verificação automática da
regra cuja penalidade é nota zero.

**Correção.** A verificação virou [`scripts/verificar-escopo.sh`](scripts/verificar-escopo.sh),
usado pelo CI **e** pelo deploy (antes havia duas cópias do `grep`, uma em
cada lugar, livres para divergir). Ele tem dois modos:

- **estrito** — pergunta ao Compose como a configuração final ficou
  (`docker compose config --format json`) e exige `host_ip = 127.0.0.1` em
  **toda** porta publicada. Pega sintaxe curta, longa, IPv6, serviço novo e
  arquivo de override. Precisa de docker e de python3 — os dois existem no
  runner do Actions e na VM
- **grep** — plano B para máquina sem um dos dois; avisa que está no modo
  reduzido, para ninguém confundir "passou" com "foi verificado a fundo"

Rodado em modo estrito contra seis variações do compose. A versão antiga
deixava passar a porta acrescentada; a nova reprova todas e diz qual serviço
e qual IP:

| Caso | Antes | Agora |
|---|---|---|
| arquivo inalterado | passa | passa |
| `- "8081:80"` | reprova | reprova — `dvwa: 0.0.0.0:8081 -> 80` |
| `- "0.0.0.0:8081:80"` | reprova | reprova |
| `- "192.168.0.10:8081:80"` | reprova | reprova — nomeia o IP |
| porta pública **acrescentada** ao lado do bind local | **passa** | reprova — `dvwa: 0.0.0.0:9090 -> 80` |
| porta do DVWA trocada para 8082 | reprova | reprova — a documentação assume 8081 |

### 4. `patches/fix-sqli.php` não funcionava na imagem do laboratório

Este só apareceu ao rodar. Vale como lição: o patch estava "certo" à leitura,
passava no SAST, e quebrava a aplicação.

**Problema.** O patch usava `$_DVWA['SQLI_DB']` e as constantes
`MYSQL`/`SQLITE`, que existem no **DVWA atual** — o que o CI clona do GitHub
para o SAST. A imagem do laboratório (`vulnerables/web-dvwa`) roda o
**DVWA 1.9**, que não tem nada disso. Aplicado no container, o resultado foi:

```
PHP Notice: Undefined index: SQLI_DB in .../sqli/source/low.php on line 36
PHP Notice: Use of undefined constant MYSQL - assumed 'MYSQL' on line 37
```

E a consulta legítima `id=1` passou a devolver **zero linha**: a página
quebrou. A injeção "sumia" só porque nada mais funcionava — o pior tipo de
correção, a que parece certa pelo sintoma.

Segundo defeito, no mesmo arquivo: o patch dava `echo`, mas a página monta a
saída em `$html` e a imprime depois (`{$html}` no `index.php` da seção). Mesmo
com o banco certo, o resultado sairia fora do lugar.

**Correção.** Reescrito para **detectar** em vez de assumir: usa SQLite só se
`$_DVWA['SQLI_DB']` e a constante `SQLITE` existirem, e cai no mysqli em
qualquer outro caso. Acumula em `$html`. Um arquivo só serve para as duas
versões do DVWA — a da imagem e a que o CI clona.

**Verificado nas duas pontas.** No código: `error` cai de 25 para 23 e o
escopo do gate vai a zero. Na aplicação no ar, com `scripts/testar-sqli.py`:

| payload | antes | depois |
|---|---|---|
| `1` (legítimo) | 1 linha | 1 linha |
| `1' OR '1'='1` | **5 — tabela inteira** | 1 |
| `' OR '1'='1` | **5 — tabela inteira** | 0 |
| `1' UNION SELECT user, password FROM users -- ` | **6** | 1 |
| `'` | erro de SQL vazando | 0 |

Zero notices de PHP vindos de `low.php`.

**Uma suposição da revisão que não se confirmou.** A troca de
`mysqli_stmt_get_result()` por `bind_result` foi feita alegando que a função
poderia faltar na imagem (depende do driver mysqlnd). Conferido na imagem:
PHP 7.0.30 com mysqlnd, a função **existe**. O `bind_result` ficou — funciona
em qualquer build e não custa nada —, mas o comentário no arquivo foi
corrigido para não afirmar um risco que não se materializa aqui.

O `DEPLOY.md` dizia "prepared statement com **PDO**"; o patch nunca usou PDO.
Texto corrigido.

### 5. Os números da documentação não batiam com os relatórios

Tudo recontado nos arquivos de `reports/`:

- **`LAB.md`, passo 2** trazia um bloco de saída inventado
  (`Findings: 6 (2 ERROR, 4 WARNING)`, `low.php:15`) e uma rule ID encurtada.
  O real: 58 achados em 24 arquivos, 25 `error`, 33 `warning`, e as duas
  ocorrências em `low.php` nas linhas **10 e 31**, com a rule ID completa
  `php.lang.security.injection.tainted-sql-string.tainted-sql-string` — o nome
  da regra repete no fim, e citar a versão curta faz o `jq` do gate não
  encontrar nada
- **`LAB.md`, passo 5** dizia que o vermelho somava "os 25 do OpenGrep com os
  3 da lista `NIKTO_HIGH` (…e a página de login administrativa)". Errado em
  três pontos: o gate conta o escopo `vulnerabilities/sqli/` (2, não 25); o
  Nikto dá 2, não 3; e a página de login **não** entra, porque o padrão
  `/admin` não casa com a mensagem `Admin login page/section found.`
  Substituído por uma tabela com os números conferidos
- **`SAST=25 DAST=3 TOTAL=28`**, citado no `LAB.md`, era verdade no momento em
  que foi escrito — antes de o escopo do gate ser restringido e de o padrão
  `\.git` ganhar as barras. Mantido como histórico, com a contagem de hoje ao
  lado

### 6. Faltava `.gitignore`

O passo 0 do `LAB.md` manda clonar o DVWA em `targets/dvwa`, e o Apêndice B
clona TerraGoat e NodeGoat. Sem `.gitignore`, um `git add .` de qualquer
integrante jogaria os três repositórios de terceiros dentro do trabalho — e o
slide de avaliação olha justamente o histórico de commits do grupo. Criado,
com `targets/`, chaves (`*.pem`, `cp1_ci*`, `.env`) e lixo de editor.

`reports/` **não** está ignorado: os relatórios são a evidência exigida pela
seção 10.

### 7. Terrascan executado; Snyk ainda não

[`scripts/rodar-sca-iac.sh`](scripts/rodar-sca-iac.sh) clona os alvos
autorizados (TerraGoat e NodeGoat), roda as duas ferramentas, **mede o tempo
de cada execução** — que é o que a seção 6(e) cobra — e grava os relatórios em
`reports/`.

**Terrascan rodou:** 494 políticas validadas, **67 violações** (35 HIGH,
27 MEDIUM, 5 LOW) no TerraGoat, em **10 s**. Por provedor: AWS 42, Azure 14,
GCP 11. Relatório em `reports/terrascan-terragoat.json`, com três exemplos
HIGH já separados em `evidencias/` para a análise crítica.

**Snyk continua sem execução** — exige token de conta, mesmo no plano
gratuito. É a única das quatro ferramentas sem nenhuma evidência:

```bash
SNYK_TOKEN=<seu-token> bash scripts/rodar-sca-iac.sh
```

O token não vai para o repositório: entra como variável na sessão do
terminal (e `.gitignore` já cobre `.env`).

### 8. Contagem dos achados automatizada

[`scripts/resumir-achados.py`](scripts/resumir-achados.py) lê os quatro
formatos (SARIF, JSON do Nikto, do Terrascan e do Snyk) e imprime uma tabela
com total, HIGH, MEDIUM, LOW e o tempo medido de cada ferramenta — a tabela da
seção 6(e), pronta para o documento.

Foi escrito porque contar isso à mão em quatro formatos diferentes é
exatamente onde o número do documento acaba divergindo do relatório
versionado. Ele **não** calcula taxa de falso positivo: essa é análise do
grupo, vale 8 pontos e nenhum script decide por vocês.

### 9. Evidência documentada

[`reports/README.md`](reports/README.md) explica o que cada relatório contém,
com os números conferidos, e registra duas coisas que atrapalham a leitura:

- `nikto-dvwa.txt` tem **três execuções empilhadas** (duas da 2.1.5, uma da
  2.5.0) — o Nikto acrescenta ao arquivo de saída em vez de sobrescrever
- o SARIF versionado é o estado **antes** da remediação, e agora existe
  também o **depois** (`opengrep-dvwa-remediado.sarif`). Os dois medem coisas
  diferentes de propósito: um é a evidência do achado, o outro a prova de que
  a correção funcionou

O pacote de evidência passou de 3 para 7 arquivos em `reports/`:
`opengrep-dvwa.sarif` e `-remediado`, `nikto-dvwa.json`/`.txt` e
`nikto-dvwa-remediado.json`, `terrascan-terragoat.json`, mais `tempos.txt`
(tempo medido de cada ferramenta) e `resumo-achados.md` (a tabela da seção
6e, gerada). A execução que produziu tudo isso está descrita em
[`evidencias/execucao-local-2026-09-12.md`](evidencias/execucao-local-2026-09-12.md).

---

## Arquivos tocados nesta revisão

| Arquivo | O que aconteceu |
|---|---|
| `.github/workflows/security-gate.yml` | chave `remediacao`; gate de DAST testando `url + msg`; guarda de escopo virou script; tabela de contagem no *Summary* |
| `patches/fix-sqli.php` | reescrito — não funcionava na imagem do laboratório |
| `scripts/verificar-escopo.sh` | **novo** — guarda de escopo, modo estrito + plano B |
| `scripts/rodar-sca-iac.sh` | **novo** — Terrascan e Snyk, com medição de tempo |
| `scripts/resumir-achados.py` | **novo** — conta os 4 relatórios, gera a tabela da 6e |
| `scripts/testar-sqli.py` | **novo** — prova a correção na aplicação no ar |
| `.gitignore` | **novo** — `targets/`, chaves, lixo de editor |
| `reports/` | 4 relatórios novos + `tempos.txt` + `resumo-achados.md` |
| `reports/README.md` | **novo** — o que cada relatório contém, com os números |
| `evidencias/execucao-local-2026-09-12.md` | **novo** — a execução completa |
| `evidencias/README.md` | passou a dizer o que falta (os dois prints) |
| `LAB.md` | números do passo 2 e do passo 5 corrigidos; verificações medidas; checklist |
| `DEPLOY.md` | comportamento do gate; "PDO" corrigido; troubleshooting |
| `README.md` | árvore de arquivos, tabela de ferramentas, como reproduzir o vermelho |
| `USO-DE-IA.md` | declaração da revisão e das validações por execução |
| `VIBE.md` | **novo** — este arquivo |
| `CLAUDE.md`, `.claude/` | **novos** — contexto do projeto para o Claude Code |

---

## Pendências de código

Em ordem de peso na nota:

- [ ] **Rodar o Snyk** — `SNYK_TOKEN=<token> bash scripts/rodar-sca-iac.sh` — e
      commitar `reports/snyk-nodegoat.json`. Única das quatro ferramentas sem
      evidência
- [ ] **Prints do build vermelho e do verde** do GitHub Actions em
      `evidencias/`. O job `security-gate` imprime a tabela de contagem na aba
      *Summary* — é dali que sai o print legível, não do log. A execução local
      equivalente já está documentada em
      `evidencias/execucao-local-2026-09-12.md`
- [ ] **Fixar as tags das imagens.** `vulnerables/web-dvwa:latest` e
      `hysnsec/nikto:latest` já mudaram de comportamento entre execuções do
      grupo (a Nikto foi de 2.1.5 para 2.5.0, com saída diferente; a imagem do
      DVWA traz a 1.9). O `Dockerfile` faz certo com
      `OPENGREP_VERSION=v1.22.0`; as outras duas deviam seguir o mesmo padrão
- [ ] **Decidir a política sobre a página de login administrativa.** Incluir
      `Admin login page` na lista `NIKTO_HIGH` sobe o vermelho para
      `TOTAL=5`; deixar fora é afirmar que é MEDIUM. Qualquer das duas serve —
      não decidir é o problema, porque muda o número do print
- [ ] **Testar o `LAB.md` numa máquina que não é de nenhum integrante** —
      exigência explícita do enunciado

## O que foi executado, e o que não

Executado nesta revisão (Docker Engine 29.7.2, tudo em `127.0.0.1`):

- os **programas `jq` do gate**, contra os relatórios reais, com os dois
  vereditos — `SAST=2 DAST=2 TOTAL=4` reprovando e `0 e 0` aprovando
- **OpenGrep** duas vezes, com e sem o patch: 58 → 56 achados, 25 → 23
  `error`, 2 → 0 no escopo do gate. A varredura sem patch reproduz o
  relatório versionado achado por achado
- **Nikto** duas vezes, com e sem o hardening: 15 → 12 itens, 2 → 0 HIGH
- **a aplicação no ar**, com `scripts/testar-sqli.py` e com `curl` em
  `/config/` e `/docs/` — as duas correções fazem o que dizem
- **Terrascan** no TerraGoat
- **`scripts/verificar-escopo.sh`** em modo estrito, contra seis variações do
  compose

Ainda **não** executado:

- **o pipeline no GitHub Actions.** O YAML foi validado e a lógica dos jobs
  foi rodada passo a passo localmente, mas a primeira execução real precisa
  ser acompanhada — principalmente a chave `remediacao` e o `if:` dos passos
- **Snyk Open Source** — falta o token
