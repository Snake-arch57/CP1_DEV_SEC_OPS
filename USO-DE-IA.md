# Declaração de Uso de IA Generativa — Grupo 1

Check Point 01 — DevSecOps (preparatório E|CDE, Módulo III)
Ferramentas do grupo: OpenGrep (SAST) · Snyk Open Source (SCA) · Terrascan (IaC) · Nikto (DAST)

Documento exigido pela seção 10 do enunciado ("Regras de conduta acadêmica").

> **Status:** documento vivo. As validações abaixo são marcadas conforme
> acontecem — item desmarcado significa *ainda não executado*, não omissão.
> Última atualização: ver histórico de commits deste arquivo.

---

## 1. Ferramenta de IA utilizada

Claude (Anthropic), via Claude Code — apoio à redação, estruturação e revisão
de documentação técnica. Nenhuma outra ferramenta de IA generativa foi usada
até o momento.

## 2. O que foi gerado com apoio de IA

- Estrutura do `LAB.md` (esqueleto de seções seguindo o template do Anexo A do
  enunciado)
- Rascunho dos comandos de exemplo do OpenGrep e do Nikto
- Redação da tabela de troubleshooting
- Rascunho do workflow `security-gate.yml`: separação em jobs por ferramenta,
  filtros `jq` e lógica de decisão do gate
- Revisão de conformidade do `LAB.md` contra o enunciado do Check Point 01
  (checagem requisito a requisito da seção 5.3 e da rubrica da seção 9)
- Rascunho do `README.md`, do `DEPLOY.md` e do `patches/fix-sqli.php`
- Diagnóstico dos quatro erros listados em 4.1, a partir dos logs de execução
  e dos relatórios reais
- Redação das três análises de achado do `LAB.md`, a partir dos dados das
  execuções — **pendente de revisão e reescrita pelo grupo** (ver 4.2)
- Revisão de código de 2026-09-12 (Claude Code, Opus 5), sobre o pipeline e
  os arquivos de apoio:
  - `scripts/verificar-escopo.sh` — a guarda de escopo saiu do YAML para um
    script único, usado pelo CI e pelo deploy
  - chave `remediacao` no `workflow_dispatch`, que torna o build vermelho
    reproduzível sob demanda
  - correção do filtro `jq` do gate de DAST (passou a testar `url + msg`)
  - `scripts/rodar-sca-iac.sh` e `scripts/resumir-achados.py`
  - `.gitignore`, `reports/README.md` e `VIBE.md`
  - reescrita de `patches/fix-sqli.php`, que não funcionava na imagem do
    laboratório (ver 4.1)
  - `scripts/testar-sqli.py`, que prova a correção na aplicação no ar
  O detalhamento de cada mudança, com o motivo, está em `VIBE.md`

### Arquivos de instrução para a própria IA

O repositório versiona também a configuração que orienta a ferramenta de IA
quando ela atua sobre este projeto. Estão declarados aqui porque a seção 10
exige transparência sobre o uso — omiti-los seria esconder justamente a parte
mais visível do processo.

| Arquivo | O que é |
|---|---|
| `CLAUDE.md` | as duas regras inegociáveis do projeto (nenhuma porta fora de `127.0.0.1`, nenhum alvo fora da lista da seção 7) e três hábitos que o enunciado cobra |
| `.claude/contexto.md` | contexto do projeto: as 4 ferramentas, como o gate decide, onde cada coisa está, o que falta |
| `.claude/README.md` | explica para que serve o diretório |

O conteúdo do `CLAUDE.md` **não é configuração de conveniência**: é a regra de
ética da seção 7 escrita como política versionada, com o script que a verifica
(`scripts/verificar-escopo.sh`) ao lado. Vale para qualquer pessoa que
contribua no repositório, com ou sem IA.

## 3. O que NÃO foi gerado por IA

Decisões técnicas e de conteúdo tomadas pelo grupo:

- Escolha das 2 ferramentas do laboratório (OpenGrep + Nikto) e do alvo (DVWA)
- Definição do mapeamento de severidade — `ERROR` → HIGH no SARIF, e a lista
  `NIKTO_HIGH` de padrões que o grupo considera severidade alta. O Nikto não
  emite severidade nativa; o critério de corte é decisão do grupo, a IA apenas
  o formatou em tabela
- Perguntas de verificação definidas para a turma
- Vídeo de plano B
- Execução do pipeline e das ferramentas
- Medições de tempo de execução e taxa de falso positivo do documento

## 4. Validação pelo grupo

O enunciado (seção 10) é explícito: *"o que não é aceitável é entregar texto
gerado sem verificação"*. Esta seção registra o estado real da verificação.

### 4.1 Já validado

- [x] **Erro factual encontrado e corrigido na revisão:** a IA havia indicado a
      imagem `returntocorp/opengrep` nos comandos de `docker pull`.
      `returntocorp` é a organização antiga do **Semgrep**, não do OpenGrep. Ao
      conferir, o grupo constatou que **não existe imagem oficial do OpenGrep no
      Docker Hub** — a sugestão seguinte da IA (`opengrep/opengrep`) também não
      se sustentava. A solução adotada foi escrever um `Dockerfile` que instala
      o binário pelo script oficial do projeto, com a versão fixada em
      `OPENGREP_VERSION=v1.22.0`. Registrado como evidência de que o material
      gerado passa por conferência, e não é aceito como veio
- [x] Conferência de que as 4 ferramentas do `LAB.md` correspondem às
      atribuídas ao Grupo 1 no slide de distribuição do enunciado
- [x] Conferência de que as 2 ferramentas do lab são de **categorias
      diferentes** (SAST + DAST), conforme requisito da seção 5.3
- [x] Conferência de que o alvo (DVWA) consta na lista de alvos autorizados da
      seção 7
- [x] **Ferramentas executadas de fato.** OpenGrep e Nikto rodaram no pipeline
      em execuções sucessivas; os relatórios reais estão versionados em
      `reports/` e os blocos "Resultado esperado" dos passos 2 e 4 do `LAB.md`
      foram substituídos pelos outputs observados
- [x] **Rulesets confirmados.** `p/php` e `p/owasp-top-ten` resolvem no
      OpenGrep e produziram 58 achados (25 `error`, 33 `warning`) no DVWA. A
      regra `php.lang.security.injection.tainted-sql-string` existe e aponta a
      linha correta
- [x] **Imagens conferidas.** `vulnerables/web-dvwa` e `hysnsec/nikto` baixam
      com `docker pull`; o OpenGrep é compilado pelo `Dockerfile` do repo
- [x] **Build vermelho e build verde reproduzidos** no GitHub Actions, com o
      deploy na VM Azure bloqueado no vermelho e executado no verde
- [x] **Segundo erro da IA, encontrado ao conferir o log:** o filtro `jq` do
      gate usava `select(.level=="error")` nos resultados do SARIF. Nenhum
      resultado do OpenGrep carrega esse campo — a severidade fica na definição
      da regra e o resultado herda. O gate reportava `OpenGrep: 0` com 58
      achados no relatório, e ficava vermelho só por causa do Nikto, o que
      mascarava o problema. Corrigido montando o mapa `ruleId → level`;
      validado contra o SARIF real: 25 `error`
- [x] **Terceiro erro, de orquestração:** o job do Nikto subia o DVWA com o
      override de hardening mas rodava `docker compose run nikto` sem ele.
      Como `nikto` tem `depends_on: dvwa`, o Compose recriava o DVWA sem o
      volume, desfazendo a remediação antes do scan. A correção existia e
      estava certa — testada fora do CI —, mas era desfeita pela orquestração
- [x] **Quarto erro, de estado implícito:** renomear o diretório de deploy na
      VM quebrou o `docker compose up` com `container name already in use`. O
      nome do projeto Compose vinha do nome da pasta. Corrigido com `name: cp1`
      no `docker-compose.yml`
- [x] **Falso positivo da própria política do grupo:** o padrão `\.git` da
      lista `NIKTO_HIGH` casava com `.gitignore`. O alvo pretendido era o
      diretório `/.git/` exposto. Verdadeiro positivo da ferramenta, falso
      positivo da regra que o grupo escreveu em volta dela. Analisado no
      `LAB.md`, achado nº 3

### 4.2 Pendente — a executar antes da entrega

- [x] **Contagens reconferidas nos relatórios versionados** (2026-09-12):
      OpenGrep 58 achados / 25 `error` / 2 `error` em `vulnerabilities/sqli/`;
      Nikto 15 achados / 2 na lista `NIKTO_HIGH`. O gate atual, portanto, dá
      `TOTAL=4` no build vermelho, e não os `28` citados no histórico do
      `LAB.md` — os `28` são de antes de o escopo do gate ser restringido.
      Recontável com `python3 scripts/resumir-achados.py`
- [x] **Quinto erro, encontrado nessa revisão:** o filtro `jq` do gate de DAST
      testava apenas o campo `msg`. Na Nikto 2.1.5 a mensagem repetia o
      caminho, então os padrões de caminho da lista `NIKTO_HIGH` casavam por
      acidente; na 2.5.0, que gerou o relatório versionado, o caminho ficou só
      em `url`, e `/admin`, `/.git/`, `backup` e `test/` deixaram de casar com
      qualquer coisa — um `/.git/` exposto passaria pelo gate. Corrigido para
      testar `url + msg`; conferido que o veredito dos relatórios já
      versionados não muda (2 achados antes e depois)
- [x] **Guarda de escopo testada contra casos de exposição** (`8081:80`,
      `0.0.0.0:`, outro IP da máquina, porta pública acrescentada ao lado do
      bind local): a versão anterior deixava passar a porta acrescentada, a
      atual reprova todas
- [x] **Sexto erro, encontrado ao rodar de verdade:** o `patches/fix-sqli.php`
      gerado com apoio de IA usava `$_DVWA['SQLI_DB']` e as constantes
      `MYSQL`/`SQLITE`, que só existem no DVWA **atual** — a imagem do
      laboratório roda o **DVWA 1.9**, que não as tem. Aplicado no container,
      o patch enchia o log de `Undefined index: SQLI_DB` e a consulta
      legítima passava a devolver **zero linha**: a página quebrava, e o
      "sumiço" da injeção era só efeito disso. O patch também dava `echo` em
      vez de acumular em `$html`, que é como a página monta a saída.
      Reescrito para detectar a versão do DVWA em vez de assumir, e
      verificado nas duas pontas — no relatório do SAST e na aplicação no ar
- [x] **Correção verificada na aplicação em execução**, não só no relatório:
      `scripts/testar-sqli.py` mostra a injeção devolvendo as 5 linhas da
      tabela antes do patch e no máximo 1 depois, sem nenhum notice de PHP
- [x] **Programas `jq` do gate executados** contra os relatórios reais, com
      os dois vereditos: `SAST=2 DAST=2 TOTAL=4` reprova, `0 e 0` aprova
- [x] **Afirmação do `LAB.md` conferida por execução:** o total de achados
      `error` do OpenGrep cai de 25 para 23 com o patch, e o escopo do gate
      vai a zero. Os relatórios pós-remediação estão versionados
- [x] **Suposição da IA que NÃO se confirmou:** a revisão trocou
      `mysqli_stmt_get_result()` por `bind_result` alegando que a função
      poderia não existir na imagem. Conferido: a imagem tem PHP 7.0.30 com
      mysqlnd e a função **existe**. O `bind_result` ficou porque funciona em
      qualquer build e não custa nada, mas o motivo registrado no arquivo foi
      corrigido — a justificativa original era uma suposição, não um fato
- [ ] **Reescrever as três análises de achado do `LAB.md` com as palavras do
      grupo.** Os dados são reais (vieram dos relatórios em `reports/`), mas a
      redação saiu da IA. O enunciado avalia análise crítica **própria**, e
      qualquer integrante pode ser questionado sobre qualquer parte na
      apresentação — este é o item mais importante desta lista
- [ ] Confirmar de forma independente que o CWE-89 é o correto para o padrão
      encontrado, consultando a base MITRE e não a sugestão da IA
- [ ] Executar o `LAB.md` inteiro **em máquina que não é a de nenhum
      integrante** — exigência explícita do enunciado, ainda não cumprida
- [ ] Rodar o **Snyk** (`SNYK_TOKEN=<token> bash scripts/rodar-sca-iac.sh`).
      É a única das quatro ferramentas sem evidência de execução — exige
      token de conta. O Terrascan já rodou: 67 violações no TerraGoat
- [ ] Medir tempo de execução e taxa de falso positivo de cada uma das 4
      ferramentas, para a seção 6(e) do documento
- [ ] Capturar os prints de build vermelho e verde para `evidencias/`
- [ ] Gravar o vídeo de plano B (5 a 8 minutos)

## 5. Trechos de terceiros citados (seção 10 — citação obrigatória)

- Template do `LAB.md`: Anexo A do enunciado do Check Point 01
- Comandos de instalação e flags: documentação oficial de cada ferramenta,
  referenciadas na bibliografia do documento de pesquisa
- Alvos vulneráveis (DVWA, TerraGoat, NodeGoat): projetos OWASP / Bridgecrew,
  referenciados no documento

---

*Integrantes do Grupo 1: _____________________________*
