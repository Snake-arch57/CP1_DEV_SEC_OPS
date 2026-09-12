# Laboratório: OpenGrep (SAST) + Nikto (DAST)

Grupo 1 — Integrantes: _____________________________

Duração estimada: 12 minutos (bloco 3 da divisão de tempo do enunciado)

> **Nota sobre prazo de publicação:** o PDF de slides do Check Point 01 e a
> seção 5.3.3 do documento oficial citam **24h** de antecedência; o **Anexo B**
> do documento oficial cita **48h**, e o marco **D-2** do cronograma (seção 8)
> também implica 48h. **Confirmar com o professor qual prazo vale** e ajustar a
> data no cronograma do grupo antes de fechar o repositório. Por segurança,
> tratem 48h como o prazo real até a confirmação.

> **Segunda divergência a confirmar:** o Arquivo de Apoio diz "Grupos: 3" e
> "ao final das três apresentações a turma terá visto 12 ferramentas", mas o
> slide "5 GRUPOS" lista **5 grupos × 4 ferramentas = 20**. Isso muda a
> participação individual, que fala em "executar os laboratórios dos **outros
> dois** grupos" (10 pts) — com 5 grupos seriam 4.

---

## ⚠️ Alvo e escopo — leia antes do passo 0

**Alvo deste laboratório: DVWA — Damn Vulnerable Web Application (PHP)**,
imagem `vulnerables/web-dvwa`. Consta na lista de **alvos vulneráveis
autorizados** da seção 7 do enunciado.

O DVWA é uma aplicação **deliberadamente vulnerável**. Ao seguir este roteiro
você sobe, na sua própria máquina, uma aplicação projetada para ser invadida —
com credenciais padrão (`admin` / `password`) e Security Level em **Low**. Isso
é intencional: é o que faz as ferramentas encontrarem achados reais, conforme
o requisito 4 da seção 5.3. Mas exige cuidado.

### Regras de escopo deste laboratório

- **Tudo roda em Docker local**, na rede interna do `docker-compose`.
- **A porta 8081 fica em `localhost`.** Não publiquem na rede da instituição,
  não rodem em Wi-Fi público e não exponham à internet.
- **Nenhum passo varre host de terceiros.** O Nikto aponta para
  `http://dvwa:80`, nome resolvido apenas dentro da rede do compose.
- **Ao terminar, derrubem o ambiente:** `docker compose down -v` (passo 7).
  Não deixem o DVWA rodando depois da aula.

### Alvos usados neste repositório — todos da seção 7

| Alvo | Categoria | Onde é usado |
|---|---|---|
| DVWA (PHP) | SAST + DAST | Laboratório ao vivo, passos 1 a 5 |
| TerraGoat (Terraform) | IaC | Apêndice B (execução offline) |
| OWASP NodeGoat (Node.js) | SCA | Apêndice B (execução offline) |

### Por que a regra é rígida

A seção 7 do enunciado é a única com penalidade máxima:

> "É terminantemente proibido executar DAST, fuzzing ou qualquer varredura
> ativa contra sistemas de terceiros, sites públicos, ambientes da empresa onde
> você trabalha, ou qualquer alvo fora da lista acima. Varredura sem
> autorização é crime no Brasil (Lei 12.737/2012 e Art. 154-A do Código Penal).
> Trabalho que apresente evidência de varredura em alvo não autorizado recebe
> **nota zero** e o caso é encaminhado à coordenação."

Vale para quem apresenta **e** para quem assiste: apontar o Nikto para
qualquer coisa que não seja o container local está fora do escopo autorizado.

---

## Ferramentas do Grupo 1 (as 4 confirmadas no enunciado)

| Categoria | Ferramenta | No lab ao vivo? | Evidência versionada |
|---|---|---|---|
| SAST | OpenGrep | Sim — Ferramenta A (passo 2) | ✅ `reports/opengrep-dvwa.sarif` |
| SCA | Snyk Open Source | Não — execução offline | ⬜ **ainda não executado** |
| IaC | Terrascan | Não — execução offline | ✅ `reports/terrascan-terragoat.json` |
| DAST | Nikto | Sim — Ferramenta B (passo 4) | ✅ `reports/nikto-dvwa.json` |

O enunciado exige que o **documento de pesquisa** responda o roteiro da
seção 6 (identificação, fundamento técnico, instalação, integração,
avaliação crítica) para as **4** ferramentas. O **laboratório conduzido**
usa só **2**, de categorias diferentes — escolhemos OpenGrep (SAST) e
Nikto (DAST) porque ambas se aplicam diretamente ao DVWA como alvo.

> **Atenção — Snyk e Terrascan também precisam ser executados.** A seção 6(e)
> exige, para cada uma das 4 ferramentas, a "taxa de falsos positivos
> **observada no laboratório**" e o "tempo de execução **no projeto testado**".
> A seção 10 reforça: "toda afirmação técnica deve ser verificável... deve
> haver evidência disso nos relatórios versionados", e a rubrica dá 5 pts para
> "relatórios de saída versionados" e 5 pts para "análise crítica própria".
> Por isso Snyk e Terrascan rodam **fora dos 12 minutos**, contra alvos
> autorizados que façam sentido para cada categoria — ver
> [Apêndice B](#apêndice-b--execuções-complementares-snyk-e-terrascan).
>
> **Estado:** o Terrascan já rodou (67 violações no TerraGoat, 10 s,
> `reports/terrascan-terragoat.json`). O **Snyk continua sem execução** — é a
> única das quatro sem nenhuma evidência, e ele exige token de conta.

---

## 0. Pré-requisitos (executar ANTES da aula)

- Docker >= 24 e Docker Compose v2 instalados
- 4 GB de RAM livres e ~3 GB em disco
- Porta 8081 livre na máquina (`sudo lsof -i :8081`)

Comandos de preparação:

```bash
git clone https://github.com/Snake-arch57/CP1_DEV_SEC_OPS.git
cd CP1_DEV_SEC_OPS
docker compose pull      # baixa DVWA e Nikto
docker compose build     # compila a imagem do OpenGrep (ver nota abaixo)
```

Verificação: `docker images | grep -E "dvwa|opengrep|nikto"` deve retornar as
três imagens.

### Comandos de download de cada imagem (exigido no README.md do repositório)

```bash
docker pull vulnerables/web-dvwa:latest
docker pull hysnsec/nikto:latest
docker compose build opengrep    # OpenGrep é compilado, não baixado
```

> Estes comandos devem constar também no `README.md` do repositório,
> conforme exige a seção 5.3.3 do enunciado — não basta estar só aqui no
> `LAB.md`.

> **Por que o OpenGrep é compilado e não baixado:** não há imagem oficial
> publicada pela organização `opengrep` no Docker Hub. O `Dockerfile` deste
> repositório instala o binário a partir do script oficial do projeto, com a
> versão fixada em `OPENGREP_VERSION=v1.22.0`. Fixar a versão é deliberado:
> garante que a turma inteira rode exatamente o mesmo binário que o grupo
> testou.
>
> Cuidado com a confusão comum: `returntocorp/opengrep` **não** é o OpenGrep —
> `returntocorp` é a organização antiga do **Semgrep**, projeto do qual o
> OpenGrep é um fork.

> **O OpenGrep analisa o código-fonte do DVWA, não a imagem em execução.** O
> serviço monta `./targets/dvwa` como `/src`. Antes do passo 2, clonar o
> código-fonte:
>
> ```bash
> git clone https://github.com/digininja/DVWA.git targets/dvwa
> ```
>
> Esse é o contraste central do laboratório: o SAST precisa do **código**, o
> DAST precisa da **aplicação no ar**.

---

## 1. Subir o ambiente

Comando:

```bash
docker compose up -d dvwa
```

Resultado esperado:

Container `dvwa` em estado `Up` (`docker ps`). Acessar
`http://localhost:8081/setup.php`, clicar em **Create / Reset Database**.
Login padrão: `admin` / `password`. Definir DVWA Security Level como **Low**
em *DVWA Security* — achados mais previsíveis para a demonstração.

---

## 2. Executar a Ferramenta A — OpenGrep (SAST)

Comando:

```bash
docker compose run --rm opengrep \
  --config=p/php \
  --config=p/owasp-top-ten \
  --sarif --output=/reports/opengrep-dvwa.sarif \
  /src
```

Resultado esperado — o que está **contado** no relatório versionado
[`reports/opengrep-dvwa.sarif`](reports/opengrep-dvwa.sarif), produzido pelo
`Opengrep OSS 1.22.0`:

```
58 achados, em 24 arquivos
  25 error    (= HIGH no mapeamento do grupo)
  33 warning  (= MEDIUM)

php.lang.security.injection.tainted-sql-string.tainted-sql-string
  vulnerabilities/sqli/source/low.php:10
  vulnerabilities/sqli/source/low.php:31
  "User data flows into this manually-constructed SQL string."
```

As regras de nível `error` que mais aparecem no DVWA inteiro:
`tainted-sql-string` (14 ocorrências), `tainted-exec` (8), `phpinfo-use`,
`echoed-request` e `run-shell-injection` (1 cada).

O que observar: a regra aponta as linhas exatas onde a variável `$id` chega
na query sem sanitização, e a mensagem fala do **fluxo** do dado do usuário
até a string da query — evidência de taint analysis, não de simples
casamento de padrão.

> `p/php` e `p/owasp-top-ten` são rulesets do Semgrep Registry, e o OpenGrep
> resolveu os dois. A linha literal da ferramenta é
> `Ran 126 rules on 250 files: 58 findings.` — das 561 regras que o SARIF
> registra no driver, 126 se aplicaram às linguagens encontradas. A varredura
> levou **31 s**. Repare que a
> rule ID completa repete o nome da regra no fim
> (`...tainted-sql-string.tainted-sql-string`) — é assim que o OpenGrep a
> escreve, e é essa string que entra no mapa `ruleId → level` do gate. Citar
> a versão curta no documento faz o `jq` não encontrar nada.

> Para recontar a qualquer momento, sem abrir o SARIF:
>
> ```bash
> python3 scripts/resumir-achados.py
> ```

---

## 3. Interpretar o relatório

Onde fica o arquivo: `reports/opengrep-dvwa.sarif`

Como abrir: `code reports/opengrep-dvwa.sarif` (extensão SARIF Viewer) ou
colar em https://microsoft.github.io/sarif-web-component/ para visualização
sem instalar nada.

Achado que queremos que você encontre: SQL Injection em
`vulnerabilities/sqli/source/low.php`, severidade ERROR, CWE-89.

### Mapeamento de severidade usado pelo grupo

O requisito 5 da seção 5.3 pede um gate que quebre o build em **HIGH ou
CRITICAL**. Nenhuma das duas ferramentas usa esses rótulos nativamente, então
o grupo definiu e documentou o seguinte mapeamento — ele é o que o
`security-gate.yml` implementa:

| Ferramenta | Rótulo nativo | Mapeado para | Quebra o build? |
|---|---|---|---|
| OpenGrep (SARIF) | `error` | HIGH | Sim |
| OpenGrep (SARIF) | `warning` | MEDIUM | Não |
| OpenGrep (SARIF) | `note` | LOW | Não |
| Nikto | achado na lista `NIKTO_HIGH` (abaixo) | HIGH | Sim |
| Nikto | demais achados | MEDIUM / LOW | Não |

O Nikto **não emite severidade** — ele lista itens encontrados. Essa é uma
limitação real da ferramenta e vale ser citada na avaliação crítica do
documento (seção 6e). Para ter um gate determinístico, o grupo classificou
como HIGH os achados que representam exposição de informação ou execução, e
não apenas ausência de hardening:

```
NIKTO_HIGH = phpinfo|/admin|Directory indexing|backup|/\.git/|test/|Default account
```

> **Falso positivo que o grupo introduziu e corrigiu.** A primeira versão
> dessa lista trazia `\.git` sem as barras. Ela casava com o achado
> `".gitignore file found"`, que é divulgação de informação de severidade
> baixa — e o gate o tratava como HIGH. O alvo pretendido era o diretório
> `/.git/` exposto, que vaza o histórico inteiro do código-fonte.
>
> Não foi erro do Nikto: foi erro da **política de severidade do grupo**. É
> um bom exemplo de que falso positivo nem sempre vem da ferramenta — às
> vezes vem da regra que a equipe escreveu em volta dela.

### Escopo do gate no SAST

A varredura do OpenGrep cobre o **DVWA inteiro** — o SARIF versionado em
`reports/` tem os 58 achados, e é essa a evidência exigida pela seção 10.

O **gate**, porém, conta só os achados `error` em `vulnerabilities/sqli/`, o
módulo que o grupo está de fato remediando com `patches/fix-sqli.php`.

Isso não é para facilitar: é como se adota SAST em código legado. Mede-se
tudo, e o gate começa pelo escopo sob remediação, ampliando conforme a dívida
é paga. Ampliar aqui é trocar uma variável no workflow.

A alternativa — exigir zero achados no DVWA inteiro — significaria corrigir as
25 vulnerabilidades de propósito da aplicação, o que descaracterizaria o alvo
e apagaria o objeto de estudo do laboratório.

---

## 4. Executar a Ferramenta B — Nikto (DAST)

Comando:

```bash
docker compose run --rm nikto \
  -h http://dvwa:80 \
  -Format json -o /reports/nikto-dvwa.json
```

Para a leitura ao vivo (mais legível que JSON), rodar também:

```bash
docker compose run --rm nikto \
  -h http://dvwa:80 \
  -Format txt -o /reports/nikto-dvwa.txt
```

Resultado esperado — **output real** da execução do grupo, versionado em
[`reports/nikto-dvwa.txt`](reports/nikto-dvwa.txt):

```
- Nikto v2.1.5/2.1.5
+ Target Host: dvwa
+ Target Port: 80
+ GET /: Cookie PHPSESSID created without the httponly flag
+ GET /: Cookie security created without the httponly flag
+ GET /: The anti-clickjacking X-Frame-Options header is not present.
+ GET /robots.txt: Server leaks inodes via ETags
+ GET /robots.txt: "robots.txt" contains 1 entry which should be manually viewed.
+ -3268: GET /config/: Directory indexing found.
+ GET /config/: Configuration information may be available remotely.
+ -3268: GET /docs/: Directory indexing found.
+ -3233: GET /icons/README: Apache default file found.
+ GET /login.php: Admin login page/section found.
```

O que observar: Nikto não vê o código — ele bate na aplicação em execução
e reporta configuração de runtime que o OpenGrep, olhando só o código
parado, jamais acusaria. Repare em `/config/`: o **directory indexing** expõe
o diretório onde o DVWA guarda a configuração do banco. Nenhuma análise
estática do código PHP acusaria isso, porque o problema está na configuração
do Apache, não no código.


> **Escopo:** o alvo é `http://dvwa:80`, resolvido **dentro da rede do
> `docker-compose`**. Nenhum host externo é varrido, conforme a regra de ética
> da seção 7 do enunciado.

> **A saída acima é da Nikto 2.1.5.** O `reports/nikto-dvwa.json` versionado
> foi gerado pela **2.5.0**, que reporta os mesmos dois `Directory indexing`
> mas também headers de segurança ausentes e o `.gitignore` — e não repete
> mais o caminho dentro da mensagem. O `docker-compose.yml` usa
> `hysnsec/nikto:latest`, e foi a tag que mudou entre as duas execuções: quem
> rodar hoje pode ver a saída da 2.5.0. Fixar a tag numa versão, como o
> `Dockerfile` já faz com `OPENGREP_VERSION=v1.22.0`, é o que garante que a
> turma veja todos o mesmo resultado. Detalhes em
> [`reports/README.md`](reports/README.md).

---

## 5. Rodar o pipeline e ver o gate quebrar

O requisito 5 da seção 5.3 exige o pipeline com **as 2 ferramentas
integradas** e um gate de severidade.

O arquivo completo é **[`.github/workflows/security-gate.yml`](.github/workflows/security-gate.yml)**
— leiam de lá, não desta seção. O que segue é só a lógica de decisão, que é o
ponto didático; duplicar o YAML inteiro aqui garantiria que as duas versões
divergissem.

### Os seis jobs

```
guarda-de-escopo ─┐
sast-opengrep ────┼─→ security-gate ─→ config-do-deploy ─→ deploy
dast-nikto ───────┘
```

| Job | O que faz |
|---|---|
| `guarda-de-escopo` | falha se o `docker-compose.yml` expuser o DVWA fora de `localhost` |
| `sast-opengrep` | clona o código do DVWA, compila o OpenGrep, gera o SARIF |
| `dast-nikto` | sobe o DVWA, espera responder, roda o Nikto, derruba tudo |
| `security-gate` | soma os achados HIGH das duas ferramentas e decide |
| `config-do-deploy` | verifica se os secrets do deploy existem |
| `deploy` | publica na VM Azure — só em push na `main`, só com o gate verde |

O `config-do-deploy` existe por uma limitação do GitHub Actions: o contexto
`secrets` não pode ser lido num `if:` de job. Sem ele, um repositório sem os
secrets configurados teria o build vermelho por um motivo que não é achado de
segurança.

### Como o gate conta

```bash
# SAST — o OpenGrep não escreve "level" em cada achado: a severidade fica na
# definição da regra, e o achado herda. Por isso montamos o mapa
# ruleId -> level antes de contar. Filtrar direto por .level retorna zero.
jq '
  [ .runs[]
    | (reduce (.tool.driver.rules[]?) as $r ({};
          .[$r.id] = $r.defaultConfiguration.level)) as $lv
    | .results[]
    | (.level // $lv[.ruleId] // "warning")
  ] | map(select(. == "error")) | length
' reports/opengrep-dvwa.sarif

# DAST — o Nikto não emite severidade nenhuma, então o corte é a lista
# NIKTO_HIGH definida pelo grupo (ver passo 3). O teste roda sobre
# `url + msg`, não só sobre `msg`: no Nikto 2.5.0 o caminho ficou apenas no
# campo `url`, e casar só na mensagem fazia os padrões de caminho da lista
# (`/admin`, `/.git/`, `backup`, `test/`) nunca casarem com nada.
jq --arg re "$NIKTO_HIGH" \
  '[.. | objects | select(has("msg"))
     | select(((.url // "") + " " + .msg) | test($re; "i"))] | length' \
  reports/nikto-dvwa.json
```

O build quebra se a **soma** for maior que zero.

> **Erro que o grupo cometeu e corrigiu:** a primeira versão do gate filtrava
> `select(.level=="error")` direto nos resultados do SARIF. Como nenhum
> resultado do OpenGrep carrega esse campo, o gate reportava `OpenGrep: 0`
> mesmo com 58 achados no relatório. O build ficava vermelho assim mesmo, por
> causa do Nikto — o que mascarava o problema. Só apareceu ao conferir o log
> do job. Depois da correção: `SAST=25 DAST=3 TOTAL=28`.
>
> Esse `28` é do gate daquele momento, que contava o DVWA inteiro e ainda
> tinha o padrão `\.git` sem barras. Com o gate atual — escopo
> `vulnerabilities/sqli/` e o padrão `/\.git/` — os **mesmos** relatórios
> versionados dão `SAST=2 DAST=2 TOTAL=4`. Os dois números estão certos, em
> momentos diferentes; a contagem de hoje está conferida em
> [`reports/README.md`](reports/README.md).

### Disparar

```bash
git push origin main
# acompanhar em: Actions > security-gate
```

Em `push` e em `pull_request` o pipeline **sempre aplica as duas correções**
— o patch do SQLi no job de SAST e o override de hardening no de DAST. É o
estado que vai para a VM, e por isso o resultado dessas execuções é o build
verde.

Para reproduzir o **build vermelho** depois que as correções já entraram, rode
o workflow à mão e **desmarque** a opção `remediacao`:

```
Actions > security-gate > Run workflow > remediacao: [ ]
```

Sem essa chave, o vermelho só era reproduzível editando o workflow — o que
inviabilizava tirar o print de novo.

Resultado esperado (contado nos relatórios versionados em `reports/`):

| Execução | OpenGrep em `vulnerabilities/sqli/` | Nikto na lista `NIKTO_HIGH` | Total | Gate |
|---|---|---|---|---|
| `remediacao` desmarcada | 2 | 2 | 4 | ❌ **vermelho** |
| `push` na `main` | 0 | 0 | 0 | ✅ **verde** |

- Os 2 do OpenGrep são a mesma regra de SQL Injection, nas duas ocorrências
  em `vulnerabilities/sqli/source/low.php`. São 25 achados `error` no DVWA
  inteiro; o gate conta só o escopo em remediação.
- Os 2 do Nikto são `Directory indexing found.` em `/config/` e em `/docs/`.
- **Decisão pendente do grupo:** a página de login administrativa **não**
  entra na conta. O padrão `/admin` da lista foi escrito para pegar um
  diretório `/admin/` exposto e não casa com a mensagem `Admin login
  page/section found.`. Incluí-la é acrescentar `Admin login page` à lista;
  deixá-la fora é dizer que uma página de login exposta é MEDIUM, não HIGH.
  Qualquer das duas serve — o que não serve é não ter decidido, porque isso
  muda o número que aparece no print.

O que observar: **os dois** achados vistos nos passos 2 e 4 alimentam a mesma
decisão — a rastreabilidade entre relatório e gate precisa ficar clara para a
turma. Repare também que o job `dast-nikto` sobe o DVWA antes de escanear,
enquanto o `sast-opengrep` só precisa do código-fonte: é o contraste entre as
duas categorias, visível no próprio YAML.

O enunciado exige a demonstração do build vermelho **e** do verde; versionem os
prints das duas execuções em `evidencias/`.

---

## 6. Perguntas de verificação (responder e entregar)

1. Quantos achados de severidade **HIGH** (nível `error` no SARIF) o OpenGrep
   reportou no arquivo `vulnerabilities/sqli/source/low.php`?
2. Qual **CWE** está associado a esse achado, e qual header de segurança o
   Nikto reportou como ausente no DVWA?

Comprovante exigido: print do output final de cada ferramenta + respostas
às duas perguntas acima, entregues **individualmente** ao final da aula.

---

## 7. Encerrar o ambiente

```bash
docker compose down -v
```

---

## Troubleshooting

| Sintoma | Causa provável | Solução |
|---|---|---|
| `docker compose up` falha na porta 8081 | Porta já em uso na máquina | Editar `docker-compose.yml` para outra porta (ex. `8082:80`) |
| DVWA carrega mas login falha | Banco não inicializado | Voltar a `setup.php` e clicar em Create/Reset Database |
| OpenGrep retorna 0 findings | Volume `/src` não aponta para a pasta certa | Conferir `volumes:` no `docker-compose.yml` |
| OpenGrep falha ao baixar `p/php` | Sem acesso ao registry de regras | Usar regras locais (`--config=./rules/`) versionadas no repo |
| Nikto não conecta em `http://dvwa:80` | Container do Nikto fora da rede do compose | Confirmar que os serviços estão na mesma `network:` do `docker-compose.yml` |
| Nikto gera JSON vazio | Versão da imagem ignora `-Format json` | Gerar `-Format xml` e ajustar o filtro do gate |
| Pipeline não quebra mesmo com ERROR no SARIF | Filtro `jq` do job `security-gate` não bate com o schema | Rodar o `jq` localmente contra `reports/opengrep-dvwa.sarif` |
| Job `dast-nikto` falha por timeout | DVWA ainda inicializando o MySQL | Aumentar o loop de espera do step "Aguardar o DVWA responder" |

### Problemas que o grupo encontrou de fato

Os quatro abaixo aconteceram durante a montagem do laboratório. Estão
registrados com causa e correção porque foram os que mais custaram tempo — e
porque **nenhum deles é achado de ferramenta**. São falhas de orquestração e
de operação, invisíveis para SAST, SCA, IaC e DAST.

| Sintoma | Causa | Correção |
|---|---|---|
| Gate reporta `OpenGrep: 0` com 58 achados no SARIF | O OpenGrep não escreve `level` em cada `result`: a severidade fica em `tool.driver.rules[].defaultConfiguration.level` e o resultado herda dela | Montar o mapa `ruleId → level` antes de contar (ver passo 5) |
| Hardening aplicado, mas o Nikto continua reportando `Directory indexing` | `docker compose run nikto` rodou sem o `-f docker-compose.hardening.yml`. Como `nikto` tem `depends_on: dvwa`, o Compose recriou o DVWA **sem** o volume, desfazendo a remediação segundos antes do scan | Usar a mesma lista de `-f` em **todas** as invocações do job (variável `$COMPOSE`) |
| Deploy falha com `container name "/dvwa" is already in use` | O Compose deriva o nome do projeto do diretório. Renomear a pasta na VM criou um projeto novo, que não pode reutilizar um `container_name` pertencente a outro | `name: cp1` no topo do `docker-compose.yml`, desacoplando o projeto do caminho |
| Perda total de acesso SSH à VM | `>` em vez de `>>` ao escrever em `authorized_keys`, sobrescrevendo a única chave autorizada | Recuperação pelo console serial do portal Azure. Sempre conferir com `wc -l` que o arquivo **cresceu** |

---

## Anexo — Análise dos 3 achados (verdadeiro/falso positivo)

Vale **8 pontos** na rubrica. Os três achados abaixo saíram das execuções
reais do grupo, versionadas em `reports/`.

| # | Ferramenta | Achado | Veredito | CWE |
|---|---|---|---|---|
| 1 | OpenGrep | SQL Injection em `vulnerabilities/sqli/source/low.php` | Verdadeiro positivo | CWE-89 |
| 2 | Nikto | `Directory indexing found` em `/config/` | Verdadeiro positivo | CWE-548 |
| 3 | Nikto | `.gitignore file found` classificado como HIGH | **Falso positivo da política do grupo** | CWE-527 |

### 1 — SQL Injection (OpenGrep) · verdadeiro positivo

**Evidência:** `reports/opengrep-dvwa.sarif`, regra
`php.lang.security.injection.tainted-sql-string`, 2 ocorrências no mesmo
arquivo, severidade `error`.

**Justificativa:** `$id` vem de `$_REQUEST` e é concatenado diretamente na
string da query. O dado do usuário é interpretado como SQL — `1' OR '1'='1`
retorna a tabela inteira. A regra rastreia o fluxo da fonte (`$_REQUEST`) até
o sink (a query), o que é *taint analysis*, não simples casamento de padrão.

**Correção aplicada:** `patches/fix-sqli.php` — prepared statement com bind.
O driver envia query e dados separadamente, então `$id` nunca é analisado
como SQL. Não há sanitização nem escape: a diferença conceitual é que escapar
tenta neutralizar a entrada, enquanto o prepared statement remove a
possibilidade de a entrada virar código.

**Verificação executada, em duas frentes.** No código: o total de achados
`error` caiu de 25 para 23 e o escopo `vulnerabilities/sqli/` foi a zero
(`opengrep-dvwa.sarif` → `opengrep-dvwa-remediado.sarif`). Na aplicação no
ar, com `python3 scripts/testar-sqli.py`: antes do patch, `1' OR '1'='1`
devolvia as **5 linhas** da tabela e `1' UNION SELECT user, password FROM
users -- ` devolvia **6**; depois, nenhuma injeção devolve mais de 1 linha e
a consulta legítima continua funcionando.

> **Detalhe que vale para a apresentação:** depois da correção,
> `1' OR '1'='1` ainda devolve **1** linha. Não é injeção — o prepared
> statement entregou a string como dado, e o MySQL, comparando a coluna
> inteira `user_id` com ela, converteu o prefixo numérico para 1 e achou o
> usuário 1. A prova é `' OR '1'='1`, sem dígito no início: devolve 0. Antes
> do patch, os dois devolviam 5.

### 2 — Directory indexing (Nikto) · verdadeiro positivo

**Evidência:** `reports/nikto-dvwa.json` — 2 ocorrências, `/config/` e
`/docs/`.

**Justificativa:** o Apache serve a listagem do diretório quando não há
index. O caso de `/config/` é o grave: é onde o DVWA guarda a configuração do
banco. Repare que **isso não está no código PHP** — é configuração do servidor
web. Nenhuma análise estática acusaria; só o DAST, batendo na aplicação em
execução, encontra. É o contraste central do laboratório.

**Correção aplicada:** `hardening/no-indexes.conf` com `Options -Indexes`,
montado via `docker-compose.hardening.yml`.

**Verificação executada:** sem o override, `/config/` e `/docs/` respondem
**HTTP 200 com `Index of /config`** — listagem exposta. Com o override, os
dois respondem **HTTP 403**. Na mesma comparação, o Nikto cai de 15 para 12
itens, e de 2 para 0 na lista `NIKTO_HIGH`. Relatórios: `nikto-dvwa.json` e
`nikto-dvwa-remediado.json`.

### 3 — `.gitignore` como HIGH · falso positivo da política do grupo

**Evidência:** o gate reportava 3 achados HIGH quando o Nikto encontrava só 2
problemas relevantes.

**Justificativa:** o Nikto reportou corretamente `".gitignore file found"` —
o arquivo existe mesmo e revela um pouco da estrutura de diretórios. O erro
não foi da ferramenta: foi da **regra de severidade que o grupo escreveu em
volta dela**. A lista `NIKTO_HIGH` continha o padrão `\.git`, pensado para
pegar um diretório `/.git/` exposto — que vaza o histórico inteiro do
código-fonte, coisa séria. Mas o padrão casava também com `.gitignore`, cuja
exposição é de severidade baixa.

Ou seja: **verdadeiro positivo da ferramenta, falso positivo da política**. É
uma distinção que raramente aparece nos exemplos de manual, e ela importa —
uma política mal calibrada produz ruído que leva a equipe a ignorar o gate.

**Correção aplicada:** o padrão passou a exigir as barras (`/\.git/`).
Validado contra o relatório real: 3 achados com a regex antiga, 2 com a nova.

> **Antes de entregar:** confiram cada uma das três análises e reescrevam com
> as palavras de vocês onde discordarem. O enunciado avalia análise crítica
> **própria**, e qualquer integrante pode ser questionado sobre qualquer parte
> na apresentação.

---

## Apêndice A — Deploy na VM do Azure (extra, **não exigido** pelo enunciado)

> **Este apêndice não faz parte dos 7 requisitos da seção 5.3 e não pontua na
> rubrica.** Está aqui como demonstração adicional do estágio *deploy*. Se o
> tempo apertar nos 12 minutos, **corte esta parte** — ela não é avaliada e
> adiciona risco de escopo (ver aviso abaixo).

**Status: implementado e funcionando.** A configuração completa da VM, da
chave dedicada ao CI e dos secrets está em [`DEPLOY.md`](DEPLOY.md). O job
`deploy` está em [`.github/workflows/security-gate.yml`](.github/workflows/security-gate.yml)
— não é reproduzido aqui para não divergir do arquivo real.

O `deploy` só executa quando **três** condições valem ao mesmo tempo:

```yaml
if: github.event_name == 'push'              # não roda em pull_request
    && github.ref == 'refs/heads/main'       # só a main
    && needs.config-do-deploy.outputs.configurado == 'true'
needs: [security-gate, config-do-deploy]     # gate verde
```

Consequência prática, observada: abrir um PR roda a guarda, o SAST, o DAST e
o gate, mas o `deploy` **nem é agendado**. Vocês veem se o gate passaria antes
de mandar para a `main`, sem nenhum risco de tocar a VM.

### O que o deploy faz na VM

Clona (ou atualiza com `git reset --hard origin/main`) em
`/opt/CP1_DEV_SEC_OPS`, reconfere o bind `127.0.0.1` e sobe **apenas** o
serviço `dvwa`, com o mesmo `docker-compose.hardening.yml` que o gate validou.

O `reset --hard` é deliberado: descarta qualquer alteração feita à mão na VM.
A máquina é descartável, e seu estado é sempre o commit da `main` — nunca algo
editado localmente.

> **Por que o mesmo override do gate:** sem ele, o gate validaria uma
> configuração e a VM receberia outra. Validar A e publicar B é uma das formas
> mais fáceis de um pipeline dar falsa segurança.

### Conferir o que foi publicado

```bash
ssh -i ~/.ssh/<sua-chave> <usuario>@<ip-da-vm>
cd /opt/CP1_DEV_SEC_OPS
git log -1 --oneline     # precisa bater com o commit da main
docker compose ls        # projeto "cp1", com os dois arquivos de compose
docker ps                # dvwa Up, 127.0.0.1:8081->80/tcp
```

O `git log -1` é a verificação que importa: se o hash bate com a `main`, está
provado que foi exatamente aquele código que passou no gate e chegou ao
servidor.

### Acessar o DVWA na VM

Ele escuta em `127.0.0.1`, então não abre pelo IP público. O túnel roda na
**sua máquina**, não na VM:

```bash
ssh -i ~/.ssh/<sua-chave> -L 8081:127.0.0.1:8081 <usuario>@<ip-da-vm>
# com a janela aberta, acesse http://localhost:8081
```

**Cuidado operacional — risco de nota zero.** DVWA é uma aplicação
deliberadamente vulnerável. A seção 7 do enunciado exige "ambiente local
isolado (Docker/VM), preferencialmente sem exposição à rede externa", e a
penalidade por alvo não autorizado é **nota zero e encaminhamento à
coordenação**. Se a VM Azure expuser a porta do DVWA publicamente, ela deixa
de ser ambiente isolado e passa a ser um alvo real acessível por terceiros.
Restringir o acesso por firewall/NSG do Azure (liberar só o IP da sala/VPN da
instituição) **antes** de subir qualquer coisa.

---

## Apêndice B — Execuções complementares (Snyk e Terrascan)

Não entram nos 12 minutos do lab ao vivo, mas **precisam ser executadas** para
gerar a evidência exigida pela seção 6(e) e pela seção 10. O DVWA não serve de
alvo para nenhuma das duas (não tem manifesto de infraestrutura, e suas
dependências PHP não são o foco), então cada uma usa um alvo autorizado da
seção 7 adequado à sua categoria.

Os dois comandos abaixo estão automatizados em
[`scripts/rodar-sca-iac.sh`](scripts/rodar-sca-iac.sh), que também mede o
tempo de cada execução e grava em `reports/tempos.txt` — evita a medição a
olho, que é o que a seção 6(e) cobra:

```bash
SNYK_TOKEN=<seu-token> bash scripts/rodar-sca-iac.sh
```

O que ele roda, se preferirem à mão:

**Terrascan (IaC) — alvo: TerraGoat**

```bash
git clone https://github.com/bridgecrewio/terragoat.git targets/terragoat
docker run --rm -v "$PWD/targets/terragoat:/iac" \
  tenable/terrascan:latest scan -i terraform -d /iac -o json \
  > reports/terrascan-terragoat.json
```

**Snyk Open Source (SCA) — alvo: OWASP NodeGoat**

```bash
git clone https://github.com/OWASP/NodeGoat.git targets/nodegoat
docker run --rm -v "$PWD/targets/nodegoat:/project" \
  -e SNYK_TOKEN="$SNYK_TOKEN" snyk/snyk:node \
  snyk test --json > reports/snyk-nodegoat.json
```

Para cada uma, anotar no documento de pesquisa (seção 6e):

- tempo de execução medido (prefixar o comando com `time`)
- total de achados e quantos foram considerados falso positivo pelo grupo
- limitação prática observada na execução

> Snyk Open Source aparece com `*` no Anexo C do enunciado (licença não é 100%
> open source / tem restrições de uso comercial). Como foi **atribuído** ao
> Grupo 1 e não é uma substituição, não há problema de conformidade — mas vale
> registrar a ressalva de licença no documento, já que a seção 6(a) pede
> licença de cada ferramenta.

---

## Anexo — Declaração de uso de IA

A declaração exigida pela **seção 10** do enunciado ("uso de IA generativa é
permitido e incentivado, desde que declarado em um anexo `USO-DE-IA.md`
indicando o que foi gerado e como foi validado") está versionada como arquivo
separado na raiz do repositório:

**[`USO-DE-IA.md`](USO-DE-IA.md)**

O conteúdo **não é reproduzido aqui de propósito** — é um documento vivo, com
checkboxes que vão sendo marcados conforme as validações acontecem. Manter uma
cópia neste arquivo garantiria que as duas versões divergissem.

Ao marcar um item como validado no `USO-DE-IA.md`, confiram se o `LAB.md`
correspondente já foi atualizado com o output real — os dois andam juntos:

| Ao validar em `USO-DE-IA.md` (seção 4.2) | Atualizar no `LAB.md` |
|---|---|
| Execução real das ferramentas | Blocos "Resultado esperado" dos passos 2 e 4 |
| Nome/tag reais das imagens | Comandos `docker pull` do passo 0 |
| Rulesets e rule IDs do OpenGrep | Comando e output do passo 2 |
| Filtros `jq` testados | Job `security-gate` do passo 5 |
| Build vermelho e verde | Passo 5 + `evidencias/` |
| Achados reais observados | Anexo "Análise dos 3 achados" |

---

## Checklist de publicação (marco D-2)

> Documento vivo — marquem conforme concluírem. Item desmarcado significa
> *ainda não feito*, não esquecimento.

### Pronto

- [x] `docker-compose.yml` sobe o ambiente com um único comando
- [x] `README.md` com os comandos de download de cada imagem (seção 5.3.3)
- [x] Nomes/tags das imagens confirmados em execução real
- [x] Pipeline integra **as 2 ferramentas** (`sast-opengrep` e `dast-nikto`)
- [x] Gate de severidade funcionando, com build vermelho e verde reproduzidos
- [x] Relatórios do OpenGrep e do Nikto versionados em `reports/`
- [x] 2 perguntas de verificação definidas para a turma (passo 6)
- [x] `USO-DE-IA.md` preenchido e versionado na raiz
- [x] Secrets `AZURE_VM_HOST`, `AZURE_VM_USER`, `AZURE_VM_SSH_KEY` configurados
- [x] Deploy automático na VM Azure funcionando, gated pelo `security-gate`
- [x] Build vermelho **reproduzível** a qualquer momento (`Run workflow` com
      `remediacao` desmarcada), e não só antes das correções entrarem
- [x] Guarda de escopo em `scripts/verificar-escopo.sh`, usada pelo CI e pelo
      deploy, cobrindo qualquer porta do compose — não só a linha do DVWA
- [x] `.gitignore` impedindo que `targets/` (DVWA, TerraGoat, NodeGoat) entre
      no repositório
- [x] Contagem dos relatórios automatizada (`scripts/resumir-achados.py`),
      para o documento não divergir da evidência
- [x] **Terrascan executado** — 67 violações (35 HIGH) no TerraGoat em 10 s,
      relatório em `reports/terrascan-terragoat.json`
- [x] **Tempo de execução medido** de OpenGrep (31 s), Nikto (6 s) e
      Terrascan (10 s), em `reports/tempos.txt`
- [x] **Correção do SQLi verificada na aplicação no ar**, não só no
      relatório: `python3 scripts/testar-sqli.py` mostra a injeção devolvendo
      a tabela inteira antes e nada depois
- [x] **Relatórios pós-remediação versionados**
      (`opengrep-dvwa-remediado.sarif`, `nikto-dvwa-remediado.json`),
      comprovando os números do build verde

### Falta — em ordem de peso na nota

- [ ] **Rodar o Snyk.** É a única das quatro ferramentas sem nenhuma
      evidência de execução, e isso afeta três frentes: relatórios
      versionados (5 pts), análise crítica própria (5 pts) e cobertura do
      roteiro da seção 6 (10 pts). Já está automatizado — falta o token:
      `SNYK_TOKEN=<seu-token> bash scripts/rodar-sca-iac.sh`.
      Token gratuito em snyk.io > Account settings. **Não commitem o token**
- [ ] **Reescrever as três análises de achado com as palavras do grupo.** Os
      dados são reais, mas a redação saiu da IA. Vale 8 pts e qualquer
      integrante pode ser questionado sobre elas na apresentação
- [ ] **Taxa de falso positivo das 4 ferramentas**, para a seção 6(e). Os
      totais e os tempos já estão medidos (`reports/tempos.txt`,
      `python3 scripts/resumir-achados.py`); o que falta é a classificação —
      análise do grupo, que nenhum script decide
- [ ] **Prints de build vermelho e verde** salvos em `evidencias/`. O job
      `security-gate` agora imprime a tabela de contagem no resumo da
      execução (aba *Summary*) — é dali que sai o print legível, não do log
- [ ] **Vídeo de plano B**, 5 a 8 minutos (3 pts)
- [ ] **Testar o `LAB.md` em máquina que não é de nenhum integrante** —
      exigência explícita do enunciado
- [ ] **Histórico de commits distribuído** entre todos os integrantes. O slide
      é explícito: repositório com commits de uma pessoa só não caracteriza
      trabalho em grupo, por mais completo que esteja
- [ ] Apresentação ensaiada e cronometrada dentro de 30 min (lab em 12)
- [ ] Repositório publicado com a antecedência confirmada (24h ou 48h — ver
      nota no topo deste arquivo)

### Recomendado, não exigido

- [ ] Conferir no portal que o NSG **não** tem regra para a 8081, e restringir
      a origem da porta 22 ao IP de vocês em vez de `Any`
- [ ] Desabilitar autenticação por senha na VM (há duas chaves funcionando).
      Antes, cadastrar uma chave reserva pelo portal, em *Help > Reset password*
- [ ] Desabilitar o LLMNR na VM (`ss -tlnp` mostra a porta 5355 escutando em
      todas as interfaces) — achado real da infraestrutura do grupo
- [ ] `gh auth logout` na VM: há um token com acesso de escrita ao repositório
      guardado numa máquina que hospeda o DVWA
