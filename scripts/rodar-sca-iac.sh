#!/usr/bin/env bash
#
# Execucao das outras duas ferramentas do grupo: Terrascan (IaC) e
# Snyk Open Source (SCA).
#
# Por que fora do pipeline: o laboratorio conduzido usa OpenGrep e Nikto
# (Apendice B do LAB.md explica a escolha), e o gate do CI avalia essas duas.
# Mas a secao 6(e) do enunciado exige, para cada uma das QUATRO ferramentas,
# o tempo de execucao no projeto testado e a taxa de falsos positivos
# observada -- e a secao 10 exige evidencia versionada de toda afirmacao
# tecnica. Sem estas duas execucoes, metade das ferramentas do grupo nao tem
# nenhum relatorio.
#
# Escopo (secao 7): os dois alvos sao da lista autorizada -- TerraGoat
# (Bridgecrew) e OWASP NodeGoat -- e as duas ferramentas sao ESTATICAS: leem
# arquivos no disco, dentro de containers. Nenhuma varredura ativa, nenhum
# host de terceiros. O Snyk consulta a base de vulnerabilidades dele pela
# rede, o que e requisicao ao proprio servico, nao scan de alvo.
#
# Uso:
#   bash scripts/rodar-sca-iac.sh                # roda o que for possivel
#   SNYK_TOKEN=xxxx bash scripts/rodar-sca-iac.sh   # inclui o Snyk
#
# O token do Snyk NAO deve ser escrito neste arquivo nem commitado: exporte
# na sessao do terminal. Conta gratuita em snyk.io > Account settings.

set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

REPORTS="reports"
TARGETS="targets"
TEMPOS="$REPORTS/tempos.txt"

mkdir -p "$REPORTS" "$TARGETS"

# No Git Bash do Windows o MSYS reescreve caminhos que comecam com "/" antes
# de entregar ao docker.exe, e o -v quebra. Desligar a conversao resolve.
export MSYS_NO_PATHCONV=1

if ! docker info > /dev/null 2>&1; then
  echo "ERRO: o Docker nao esta respondendo. Suba o Docker Desktop / o daemon e tente de novo." >&2
  exit 1
fi

clonar() {
  local repo="$1" dir="$2"
  if [ -d "$TARGETS/$dir/.git" ]; then
    echo "[alvo] $dir ja clonado."
  else
    echo "[alvo] clonando $dir..."
    git clone --depth 1 "$repo" "$TARGETS/$dir" || return 1
  fi
}

registrar_tempo() {
  # ferramenta <TAB> segundos <TAB> data -- lido por resumir-achados.py
  printf '%s\t%s\t%s\n' "$1" "$2" "$(date +%Y-%m-%d)" >> "$TEMPOS"
}

FALHAS=0

# ------------------------------------------------------------------
# Terrascan (IaC) -- alvo TerraGoat
# ------------------------------------------------------------------
echo ""
echo "=== Terrascan (IaC) -> TerraGoat ==="

if clonar https://github.com/bridgecrewio/terragoat.git terragoat; then
  INICIO=$(date +%s)

  # Terrascan sai com codigo != 0 quando ENCONTRA violacao. Aqui isso e o
  # resultado esperado, nao erro de execucao -- por isso o || true.
  docker run --rm -v "$(pwd)/$TARGETS/terragoat:/iac:ro" \
    tenable/terrascan:latest scan -i terraform -d /iac -o json \
    > "$REPORTS/terrascan-terragoat.json" || true

  FIM=$(date +%s)
  SEGUNDOS=$((FIM - INICIO))

  if [ -s "$REPORTS/terrascan-terragoat.json" ]; then
    registrar_tempo terrascan "$SEGUNDOS"
    echo "[ok] $REPORTS/terrascan-terragoat.json em ${SEGUNDOS}s"
  else
    echo "[falha] o Terrascan nao gerou saida. Rode o docker run a mao para ver o erro." >&2
    rm -f "$REPORTS/terrascan-terragoat.json"
    FALHAS=$((FALHAS + 1))
  fi
else
  echo "[falha] nao consegui clonar o TerraGoat." >&2
  FALHAS=$((FALHAS + 1))
fi

# ------------------------------------------------------------------
# Snyk Open Source (SCA) -- alvo OWASP NodeGoat
# ------------------------------------------------------------------
echo ""
echo "=== Snyk Open Source (SCA) -> NodeGoat ==="

if [ -z "${SNYK_TOKEN:-}" ]; then
  echo "[pulado] SNYK_TOKEN nao definido nesta sessao."
  echo "         O Snyk exige autenticacao, mesmo no plano gratuito. Rode:"
  echo "           SNYK_TOKEN=<seu-token> bash scripts/rodar-sca-iac.sh"
  FALHAS=$((FALHAS + 1))
elif clonar https://github.com/OWASP/NodeGoat.git nodegoat; then
  INICIO=$(date +%s)

  # Sem `npm install` o Snyk analisa o manifesto (package.json +
  # package-lock.json), que e exatamente o objeto do SCA: as dependencias
  # declaradas. Nao precisa instalar o projeto.
  #
  # O ponto de montagem e /app, nao um diretorio qualquer: a imagem
  # snyk/snyk:node define WORKDIR /app, e `snyk test` analisa o diretorio
  # ATUAL. Montar em /project fazia o Snyk varrer o /app vazio e responder
  # "Could not detect supported target files in /app" -- com o token
  # perfeitamente valido. O -w deixa a intencao explicita mesmo que a
  # imagem mude o WORKDIR no futuro.
  #
  # Como o Terrascan, o Snyk sai com codigo != 0 quando encontra
  # vulnerabilidade -- resultado esperado.
  docker run --rm -v "$(pwd)/$TARGETS/nodegoat:/app" -w /app \
    -e "SNYK_TOKEN=$SNYK_TOKEN" snyk/snyk:node \
    snyk test --json \
    > "$REPORTS/snyk-nodegoat.json" || true

  FIM=$(date +%s)
  SEGUNDOS=$((FIM - INICIO))

  # Erro de autenticacao tambem produz JSON, mas sem a lista de
  # vulnerabilidades -- entao conferimos o conteudo, nao so o tamanho.
  if grep -q '"vulnerabilities"' "$REPORTS/snyk-nodegoat.json" 2>/dev/null; then
    registrar_tempo snyk "$SEGUNDOS"
    echo "[ok] $REPORTS/snyk-nodegoat.json em ${SEGUNDOS}s"
  else
    echo "[falha] o Snyk nao devolveu lista de vulnerabilidades. Saida:" >&2
    head -c 500 "$REPORTS/snyk-nodegoat.json" >&2
    echo "" >&2
    echo "        LEIA o campo \"error\" acima antes de culpar o token." >&2
    echo "        - \"Could not detect supported target files\": o alvo nao" >&2
    echo "          chegou no diretorio que o Snyk analisa (ponto de montagem)." >&2
    echo "        - \"authentication\" / \"Unauthorized\": ai sim e o token." >&2
    echo "        - sem JSON nenhum: falta de rede." >&2
    rm -f "$REPORTS/snyk-nodegoat.json"
    FALHAS=$((FALHAS + 1))
  fi
fi

# ------------------------------------------------------------------
echo ""
echo "=== Resumo das 4 ferramentas ==="
if command -v python3 > /dev/null 2>&1; then
  PY=python3
elif command -v python > /dev/null 2>&1; then
  PY=python
else
  PY=""
fi

if [ -n "$PY" ]; then
  "$PY" scripts/resumir-achados.py --md "$REPORTS/resumo-achados.md" || true
else
  echo "(python nao encontrado -- rode scripts/resumir-achados.py depois)"
fi

echo ""
if [ "$FALHAS" -gt 0 ]; then
  echo "Terminou com $FALHAS pendencia(s). Veja as mensagens acima."
  exit 1
fi
echo "Terrascan e Snyk executados. Commitem os relatorios de reports/."
