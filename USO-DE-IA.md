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

- [ ] **Reescrever as três análises de achado do `LAB.md` com as palavras do
      grupo.** Os dados são reais (vieram dos relatórios em `reports/`), mas a
      redação saiu da IA. O enunciado avalia análise crítica **própria**, e
      qualquer integrante pode ser questionado sobre qualquer parte na
      apresentação — este é o item mais importante desta lista
- [ ] Confirmar de forma independente que o CWE-89 é o correto para o padrão
      encontrado, consultando a base MITRE e não a sugestão da IA
- [ ] Executar o `LAB.md` inteiro **em máquina que não é a de nenhum
      integrante** — exigência explícita do enunciado, ainda não cumprida
- [ ] Rodar Snyk e Terrascan (Apêndice B) e versionar os relatórios; sem isso
      não há evidência para duas das quatro ferramentas
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
