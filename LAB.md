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

## Ferramentas do Grupo 1 (as 4 confirmadas no enunciado)

| Categoria | Ferramenta | No lab ao vivo? | Evidência versionada |
|---|---|---|---|
| SAST | OpenGrep | Sim — Ferramenta A (passo 2) | `reports/opengrep-dvwa.sarif` |
| SCA | Snyk Open Source | Não — execução offline | `reports/snyk-nodegoat.json` |
| IaC | Terrascan | Não — execução offline | `reports/terrascan-terragoat.json` |
| DAST | Nikto | Sim — Ferramenta B (passo 4) | `reports/nikto-dvwa.json` |

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

---

## 0. Pré-requisitos (executar ANTES da aula)

- Docker >= 24 e Docker Compose v2 instalados
- 4 GB de RAM livres e ~3 GB em disco
- Porta 8081 livre na máquina (`sudo lsof -i :8081`)

Comandos de preparação:

```bash
git clone <url-do-repo>
cd <repo>
docker compose pull
```

Verificação: `docker images | grep -E "dvwa|opengrep|nikto"` deve retornar as
três imagens listadas.

### Comandos de download de cada imagem (exigido no README.md do repositório)

```bash
docker pull vulnerables/web-dvwa:latest
docker pull opengrep/opengrep:latest
docker pull hysnsec/nikto:latest
```

> Estes três comandos devem constar também no `README.md` do repositório,
> conforme exige a seção 5.3.3 do enunciado — não basta estar só aqui no
> `LAB.md`.

> **Verificar antes de publicar:** o OpenGrep é o fork mantido pela org
> `opengrep` — a imagem **não** é `returntocorp/opengrep` (`returntocorp` é a
> org antiga do Semgrep). Confirmem a tag real com
> `docker pull opengrep/opengrep:latest` e ajustem aqui se necessário. O mesmo
> vale para a imagem do Nikto: `frapsoft/nikto` está sem manutenção há anos;
> `hysnsec/nikto` é a alternativa mais atual. A seção 10 do enunciado penaliza
> "informação técnica incorreta sobre a ferramenta independentemente da origem".

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

Resultado esperado (trecho do output):

```
Scanning 320 files...
Findings: 6 (2 ERROR, 4 WARNING)
Rule ID: php.lang.security.injection.tainted-sql-string
  vulnerabilities/sqli/source/low.php:15
```

O que observar: a regra aponta a linha exata onde a variável `$id` chega
na query sem sanitização — evidência de taint analysis, não só pattern
matching.

> **Verificar na execução real:** `p/php` e `p/owasp-top-ten` são *rulesets do
> Semgrep Registry*; o acesso do OpenGrep ao registry não é idêntico. A rule ID
> acima também é do registry do Semgrep. Substituam o bloco de output e a rule
> ID pelos valores **realmente observados** antes de publicar.

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
NIKTO_HIGH = phpinfo|/admin|Directory indexing|backup|\.git|test/|Default account
```

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

Resultado esperado (trecho do output):

```
+ Server: Apache/2.4...
+ The X-Content-Type-Options header is not set.
+ The X-Frame-Options header is not set.
+ /phpinfo.php: Output from the phpinfo() function was found.
```

O que observar: Nikto não vê o código — ele bate na aplicação em execução
e reporta configuração de runtime que o OpenGrep, olhando só o código
parado, jamais acusaria.

> **Escopo:** o alvo é `http://dvwa:80`, resolvido **dentro da rede do
> `docker-compose`**. Nenhum host externo é varrido, conforme a regra de ética
> da seção 7 do enunciado.

---

## 5. Rodar o pipeline e ver o gate quebrar

O requisito 5 da seção 5.3 exige o pipeline com **as 2 ferramentas
integradas** e um gate de severidade. O `security-gate.yml` tem três jobs: um
por ferramenta, e um terceiro que consolida os dois relatórios e decide.

```yaml
name: security-gate

on:
  push:
    branches: [main]
  pull_request:

jobs:
  sast-opengrep:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Rodar OpenGrep (SAST)
        run: |
          mkdir -p reports
          docker run --rm -v "$PWD:/src" -v "$PWD/reports:/reports" \
            opengrep/opengrep:latest \
            --config=p/php --config=p/owasp-top-ten \
            --sarif --output=/reports/opengrep-dvwa.sarif /src
      - uses: actions/upload-artifact@v4
        with:
          name: opengrep-sarif
          path: reports/opengrep-dvwa.sarif

  dast-nikto:
    runs-on: ubuntu-latest
    services:
      dvwa:
        image: vulnerables/web-dvwa:latest
        ports: ['8081:80']
    steps:
      - uses: actions/checkout@v4
      - name: Aguardar o DVWA responder
        run: |
          for i in $(seq 1 30); do
            curl -sf http://localhost:8081/ > /dev/null && break
            sleep 2
          done
      - name: Rodar Nikto (DAST)
        run: |
          mkdir -p reports
          docker run --rm --network host -v "$PWD/reports:/reports" \
            hysnsec/nikto:latest \
            -h http://localhost:8081 \
            -Format json -o /reports/nikto-dvwa.json || true
      - uses: actions/upload-artifact@v4
        with:
          name: nikto-json
          path: reports/nikto-dvwa.json

  security-gate:
    needs: [sast-opengrep, dast-nikto]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/download-artifact@v4
        with: { name: opengrep-sarif, path: reports }
      - uses: actions/download-artifact@v4
        with: { name: nikto-json, path: reports }

      - name: Gate SAST — ERROR (=HIGH) no SARIF do OpenGrep
        id: sast
        run: |
          N=$(jq '[.runs[].results[] | select(.level=="error")] | length' \
               reports/opengrep-dvwa.sarif)
          echo "OpenGrep: $N achado(s) HIGH"
          echo "count=$N" >> "$GITHUB_OUTPUT"

      - name: Gate DAST — achados HIGH no relatório do Nikto
        id: dast
        run: |
          RE='phpinfo|/admin|Directory indexing|backup|\.git|test/|Default account'
          N=$(jq --arg re "$RE" \
               '[.. | objects | select(has("msg")) | select(.msg | test($re; "i"))] | length' \
               reports/nikto-dvwa.json)
          echo "Nikto: $N achado(s) HIGH"
          echo "count=$N" >> "$GITHUB_OUTPUT"

      - name: Decisão do gate
        env:
          SAST_COUNT: ${{ steps.sast.outputs.count }}
          DAST_COUNT: ${{ steps.dast.outputs.count }}
        run: |
          TOTAL=$(( SAST_COUNT + DAST_COUNT ))
          echo "SAST=$SAST_COUNT  DAST=$DAST_COUNT  TOTAL=$TOTAL"
          if [ "$TOTAL" -gt 0 ]; then
            echo "::error::Gate REPROVADO — $TOTAL achado(s) de severidade HIGH."
            exit 1
          fi
          echo "Gate APROVADO — nenhum achado HIGH."
```

Comando para disparar:

```bash
git push origin main
# acompanhar em: Actions > security-gate
```

Resultado esperado:

- **Build vermelho:** com o DVWA em Security Level **Low**, o job
  `security-gate` falha ao somar o `ERROR` de SQL Injection do OpenGrep com o
  achado de `phpinfo.php` do Nikto.
- **Build verde:** aplicando o patch de exemplo em `patches/fix-sqli.php`
  (troca para prepared statement) e removendo o `phpinfo.php` do alvo, os dois
  contadores zeram e o job passa.

O que observar: **os dois** achados vistos nos passos 2 e 4 são o que derruba
o build — a rastreabilidade entre relatório e gate precisa ficar clara para a
turma. Repare também que o job `dast-nikto` só é possível porque ele sobe o
DVWA como *service container*: o DAST exige a aplicação no ar, o SAST não.

O enunciado exige a demonstração do build vermelho **e** do verde; versionem
os prints/links das duas execuções em `evidencias/`.

> **Verificar antes de publicar:** a estrutura do JSON do Nikto varia entre
> versões (às vezes um array no topo, às vezes `{"vulnerabilities":[...]}`).
> O filtro `jq` acima foi escrito de forma tolerante (`.. | objects`), mas
> confirmem contra o arquivo real gerado no passo 4.

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

---

## Anexo — Análise dos 3 achados (verdadeiro/falso positivo)

Vale **8 pontos** na rubrica. As três linhas precisam ser preenchidas com
achados **reais** da execução do grupo.

| # | Ferramenta | Achado | Veredito | CWE | Justificativa técnica | Correção proposta |
|---|---|---|---|---|---|---|
| 1 | OpenGrep | SQL Injection em `sqli/source/low.php` | Verdadeiro positivo | CWE-89 | `$id` concatenado direto na query, sem prepared statement | Migrar para PDO com bind de parâmetros |
| 2 | OpenGrep | *(preencher com achado real da execução de vocês)* | | | | |
| 3 | Nikto | *(preencher com achado real da execução de vocês)* | | | | |

> As linhas 2 e 3 precisam ser preenchidas com os achados observados na
> execução real do grupo — o enunciado exige análise crítica própria, não
> genérica. Sugestão para a linha 3: os headers ausentes
> (`X-Frame-Options` / `X-Content-Type-Options`) reportados pelo Nikto são
> **verdadeiros positivos de baixa severidade** (CWE-1021 / CWE-693) — bom
> exemplo para discutir que "verdadeiro positivo" não é sinônimo de "urgente".

---

## Apêndice A — Deploy na VM do Azure (extra, **não exigido** pelo enunciado)

> **Este apêndice não faz parte dos 7 requisitos da seção 5.3 e não pontua na
> rubrica.** Está aqui como demonstração adicional do estágio *deploy*. Se o
> tempo apertar nos 12 minutos, **corte esta parte** — ela não é avaliada e
> adiciona risco de escopo (ver aviso abaixo).

O job `deploy` roda **depois** do job `security-gate` e só é disparado se ele
passar (`needs: security-gate`) — ou seja, o gate de severidade é o que decide
se o deploy acontece.

```yaml
  deploy:
    needs: security-gate
    if: success()
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Deploy via SSH na VM Azure
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.AZURE_VM_HOST }}
          username: ${{ secrets.AZURE_VM_USER }}
          key: ${{ secrets.AZURE_VM_SSH_KEY }}
          script: |
            cd /opt/checkpoint01-grupo1
            git pull origin main
            docker compose pull
            docker compose up -d --force-recreate
```

Comando local equivalente, para teste manual antes de confiar só no CI:

```bash
ssh usuario@<ip-da-vm-azure>
cd /opt/checkpoint01-grupo1
git pull origin main
docker compose up -d --force-recreate
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

- [ ] `docker-compose.yml` sobe tudo com um único comando
- [ ] `README.md` com os comandos de `docker pull` de cada imagem
- [ ] Nomes/tags das imagens confirmados com `docker pull` real
- [ ] LAB.md testado em máquina que não é a de vocês
- [ ] Relatórios de saída (`reports/`) versionados — incluindo os do Snyk e do
      Terrascan (Apêndice B)
- [ ] Pipeline integra **as 2 ferramentas** (jobs `sast-opengrep` e `dast-nikto`)
- [ ] Evidência de **build vermelho e build verde** versionada em `evidencias/`
- [ ] Análise dos 3 achados preenchida com achados reais (VP/FP + CWE + correção)
- [ ] Vídeo de plano B de **5 a 8 minutos** (ou GIF da execução completa)
      gravado e versionado
- [ ] 2 perguntas de verificação definidas para a turma
- [ ] `USO-DE-IA.md` preenchido e versionado na raiz
- [ ] Histórico de commits distribuído entre todos os integrantes
- [ ] Repositório publicado com a antecedência confirmada (24h ou 48h)
- [ ] Apresentação ensaiada e cronometrada dentro de 30 min (lab em 12 min)
- [ ] *(se usar o Apêndice A)* Secrets `AZURE_VM_HOST`, `AZURE_VM_USER`,
      `AZURE_VM_SSH_KEY` configurados em Settings > Secrets
- [ ] *(se usar o Apêndice A)* Firewall/NSG da VM Azure restringindo acesso ao
      DVWA (não exposto publicamente)
