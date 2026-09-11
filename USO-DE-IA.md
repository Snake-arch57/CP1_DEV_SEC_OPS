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

### 4.2 Pendente — a executar antes da entrega

- [x] **Nikto executado** contra o DVWA local; output real versionado em
      `reports/nikto-dvwa.txt` e `reports/nikto-dvwa.json`, e o bloco "Resultado
      esperado" do passo 4 do `LAB.md` foi substituido pelo output real
- [ ] Executar os comandos restantes do `LAB.md` (OpenGrep) e **substituir
      os blocos de output de exemplo pelos outputs reais**
- [ ] Confirmar que `hysnsec/nikto` e `vulnerables/web-dvwa` baixam com
      `docker pull`, e que `docker compose build opengrep` conclui sem erro em
      máquina limpa
- [ ] Conferir os rulesets (`p/php`, `p/owasp-top-ten`) e as rule IDs contra a
      saída real do OpenGrep — as citadas hoje vêm do registry do Semgrep e
      podem não existir no OpenGrep
- [ ] Testar os filtros `jq` do gate contra os arquivos SARIF e JSON realmente
      gerados, antes de confiar no CI
- [ ] Reproduzir o build vermelho e o build verde no GitHub Actions
- [ ] Preencher as linhas 2 e 3 da análise de achados com achados **observados
      pelo grupo**, não sugeridos pela IA
- [ ] Confirmar que o CWE-89 está corretamente associado ao padrão de SQL
      Injection efetivamente encontrado
- [ ] Medir tempo de execução e taxa de falso positivo de cada uma das 4
      ferramentas, para a seção 6(e) do documento

## 5. Trechos de terceiros citados (seção 10 — citação obrigatória)

- Template do `LAB.md`: Anexo A do enunciado do Check Point 01
- Comandos de instalação e flags: documentação oficial de cada ferramenta,
  referenciadas na bibliografia do documento de pesquisa
- Alvos vulneráveis (DVWA, TerraGoat, NodeGoat): projetos OWASP / Bridgecrew,
  referenciados no documento

---

*Integrantes do Grupo 1: _____________________________*
