# Contexto do projeto — CP1 DevSecOps, Grupo 1

Trabalho acadêmico avaliado por rubrica (Check Point 01, preparatório E|CDE,
Módulo III). O repositório sobe o **DVWA**, uma aplicação deliberadamente
vulnerável, e roda quatro ferramentas open source de segurança sobre ele num
pipeline com gate de severidade.

Antes de mexer em qualquer coisa, leia [`../VIBE.md`](../VIBE.md): é o registro
do que já foi feito no código, com o motivo de cada decisão e a lista de
pendências.

## Regras que não se negociam

1. **O DVWA nunca sai de `127.0.0.1`.** Nenhuma porta do `docker-compose.yml`
   pode ser publicada em outra interface. A seção 7 do enunciado pune isso com
   nota zero e encaminhamento à coordenação. A verificação automática está em
   `scripts/verificar-escopo.sh`, usada pelo CI e pelo deploy — não a
   contorne, não a duplique.
2. **Nenhuma varredura contra alvo fora da lista autorizada.** Só DVWA,
   TerraGoat e OWASP NodeGoat, todos locais, em container. Nada de host de
   terceiros, site público ou rede da instituição — nem para "testar rápido".
3. **Todo número afirmado num documento tem de sair de um relatório
   versionado em `reports/`.** A seção 10 exige evidência verificável. Antes
   de escrever "N achados" em qualquer lugar, rode:
   ```bash
   python3 scripts/resumir-achados.py
   ```
   Se o número do documento divergir do relatório, o documento está errado.
4. **`targets/` nunca entra no repositório** (é o DVWA e os outros alvos
   clonados). O `.gitignore` cuida disso.
5. **Uso de IA é declarado.** Toda contribuição de IA vai para
   `USO-DE-IA.md`, com o que foi gerado e como foi validado — exigência da
   seção 10. Não é opcional e não é detalhe.
6. **Segredo nenhum no repositório.** Os três secrets do deploy
   (`AZURE_VM_HOST`, `AZURE_VM_USER`, `AZURE_VM_SSH_KEY`) vivem no GitHub; o
   `SNYK_TOKEN` entra como variável de sessão.
7. **Depois de mexer no código, atualize o `VIBE.md`** — o que mudou, por quê,
   e o que foi ou não verificado. É o que permite a qualquer integrante
   defender a mudança na apresentação.

## As quatro ferramentas

| Categoria | Ferramenta | Onde roda |
|---|---|---|
| SAST | OpenGrep | laboratório ao vivo + pipeline |
| DAST | Nikto | laboratório ao vivo + pipeline |
| SCA | Snyk Open Source | offline, `scripts/rodar-sca-iac.sh` |
| IaC | Terrascan | offline, `scripts/rodar-sca-iac.sh` |

O laboratório conduzido (12 minutos) usa só OpenGrep e Nikto, que são de
categorias diferentes — requisito da seção 5.3.

Estado das execuções: OpenGrep, Nikto e Terrascan rodaram, com relatórios em
`reports/`. O **Snyk ainda não** — exige token de conta, e é a única das
quatro sem evidência para a seção 6(e).

## Onde as coisas estão

- `LAB.md` — roteiro do laboratório, análise dos achados, checklist de entrega
- `DEPLOY.md` — preparação da VM Azure, chave de CI, secrets, NSG
- `USO-DE-IA.md` — declaração de uso de IA (seção 10)
- `VIBE.md` — registro do trabalho de código
- `reports/README.md` — o que cada relatório contém, com os números conferidos
- `.github/workflows/security-gate.yml` — pipeline, gate e deploy
- `scripts/` — `verificar-escopo.sh` (guarda de escopo),
  `rodar-sca-iac.sh` (Terrascan + Snyk), `resumir-achados.py` (contagem dos
  4 relatórios), `testar-sqli.py` (prova a correção na aplicação no ar)
- `evidencias/` — prints e a execução local documentada
- `patches/`, `hardening/` — as duas correções que fazem o gate passar

## Como o gate decide

Nenhuma das duas ferramentas do lab usa os rótulos HIGH/CRITICAL que o
enunciado pede, então o mapeamento é decisão documentada do grupo:

- **OpenGrep**: nível `error` na *definição da regra* = HIGH. A severidade não
  está em cada achado — fica em `tool.driver.rules[].defaultConfiguration.level`
  e o achado herda. Filtrar pelo campo `level` do resultado devolve zero
- **Nikto**: não emite severidade. HIGH = achado que casa com a lista
  `NIKTO_HIGH`, testada contra `url + msg` (na Nikto 2.5.0 o caminho fica só
  em `url`)
- O gate conta só o escopo `vulnerabilities/sqli/` no SAST — o módulo em
  remediação —, não o DVWA inteiro

Build vermelho e verde são reproduzíveis: *Actions > security-gate > Run
workflow*, com a opção `remediacao` marcada (verde) ou desmarcada (vermelho).

## Ao mexer no pipeline

Valide antes de commitar:

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/security-gate.yml',encoding='utf-8')); print('YAML ok')"
bash -n scripts/verificar-escopo.sh && bash -n scripts/rodar-sca-iac.sh
bash scripts/verificar-escopo.sh
```

Não há `jq` nem `php` na máquina, mas **há Docker** — o que dá para rodar a
lógica do gate de verdade, sem esperar o Actions:

```bash
docker run --rm -v "$(pwd):/w" -w /w alpine sh -c 'apk add --no-cache bash jq >/dev/null && jq --version'
```

E o patch do PHP se testa no próprio container do DVWA:

```bash
docker exec dvwa php -l /var/www/html/vulnerabilities/sqli/source/low.php
python3 scripts/testar-sqli.py
```

Atenção a duas armadilhas já pagas, registradas no `VIBE.md`: a imagem roda
**DVWA 1.9**, que não tem `$_DVWA['SQLI_DB']` (o CI clona o DVWA atual, que
tem); e a página de SQLi só está em `low.php` se o cookie `security` valer
`low` — no default o DVWA serve `impossible.php`, que já usa prepared
statement e daria "protegido" sem correção nenhuma.
