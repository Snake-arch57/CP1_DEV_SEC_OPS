#!/usr/bin/env bash
#
# Guarda de escopo -- secao 7 do enunciado.
#
# O DVWA e deliberadamente vulneravel. Se qualquer porta do compose passar a
# escutar fora de 127.0.0.1, a aplicacao deixa de estar em "ambiente local
# isolado" e vira alvo real acessivel por terceiros -- o que o enunciado pune
# com nota zero. Este script e a verificacao automatica disso, e roda em dois
# lugares: no job `guarda-de-escopo` do CI e no deploy, dentro da VM.
#
# Uso (a partir da raiz do repositorio):
#   bash scripts/verificar-escopo.sh
#
# Sai 0 se tudo esta preso em localhost, 1 caso contrario.
#
# Sao dois modos porque as maquinas onde ele roda nao sao iguais:
#
#   estrito -- pergunta ao proprio Compose como a configuracao final ficou e
#              confere porta por porta. Pega qualquer forma de escrever a
#              porta: sintaxe curta, longa, IPv6, servico novo, arquivo de
#              override. Precisa de docker e de python3.
#   grep    -- plano B para maquina sem um dos dois. Le o docker-compose.yml
#              linha por linha; nao entende override nem sintaxe longa. O
#              script diz qual modo usou, para ninguem confundir "passou" com
#              "foi verificado a fundo".

set -uo pipefail

BIND_ESPERADO="127.0.0.1"
PORTA_DVWA="8081"

erro() {
  # ::error:: aparece destacado no log do GitHub Actions e e ignorado em
  # qualquer outro terminal.
  echo "::error::$*"
  echo "ERRO: $*" >&2
}

if [ ! -f docker-compose.yml ]; then
  erro "docker-compose.yml nao encontrado. Rode o script na raiz do repositorio."
  exit 1
fi

ARQUIVOS=(-f docker-compose.yml)
[ -f docker-compose.hardening.yml ] && ARQUIVOS+=(-f docker-compose.hardening.yml)

PY=""
for CANDIDATO in python3 python; do
  if command -v "$CANDIDATO" > /dev/null 2>&1; then
    PY="$CANDIDATO"
    break
  fi
done

# ------------------------------------------------------------------
# Modo estrito
#
# O Compose normaliza toda porta para { host_ip, published, target }, entao
# basta exigir host_ip = 127.0.0.1 em TODAS elas. Quando host_ip nao aparece,
# o default do Docker e 0.0.0.0 -- ou seja, ausencia do campo e exposicao.
# ------------------------------------------------------------------
CFG_JSON=""
if command -v docker > /dev/null 2>&1 && [ -n "$PY" ]; then
  CFG_JSON=$(mktemp 2>/dev/null || echo "")
  if [ -n "$CFG_JSON" ]; then
    trap 'rm -f "$CFG_JSON"' EXIT
    docker compose "${ARQUIVOS[@]}" config --format json > "$CFG_JSON" 2>/dev/null \
      || : > "$CFG_JSON"
  fi
fi

if [ -n "$CFG_JSON" ] && [ -s "$CFG_JSON" ]; then
  echo "Modo estrito (docker compose config)."
  "$PY" - "$CFG_JSON" "$BIND_ESPERADO" "$PORTA_DVWA" <<'PYFIM'
import json
import sys

caminho, bind, porta_dvwa = sys.argv[1], sys.argv[2], sys.argv[3]

with open(caminho, encoding="utf-8") as f:
    cfg = json.load(f)

expostas = []
dvwa_na_porta = False

for servico, dados in (cfg.get("services") or {}).items():
    for p in (dados.get("ports") or []):
        # Sem host_ip, o default do Docker e 0.0.0.0: todas as interfaces.
        host_ip = p.get("host_ip") or "0.0.0.0"
        publicada = str(p.get("published", "?"))
        alvo = p.get("target", "?")
        if host_ip != bind:
            expostas.append("%s: %s:%s -> %s" % (servico, host_ip, publicada, alvo))
        if servico == "dvwa" and publicada == porta_dvwa:
            dvwa_na_porta = True

def erro(msg):
    print("::error::" + msg)
    print("ERRO: " + msg, file=sys.stderr)

if expostas:
    erro("ha porta(s) publicada(s) fora de %s:" % bind)
    for linha in expostas:
        print("  " + linha, file=sys.stderr)
    erro("Use o formato %s:<porta-host>:<porta-container> -- ver secao 7 do enunciado." % bind)
    sys.exit(1)

# O LAB.md, o DEPLOY.md e o comando do tunel SSH assumem a 8081. Se ela
# mudar, a documentacao para de bater com o ambiente.
if not dvwa_na_porta:
    erro("o servico dvwa nao publica a porta %s, assumida pelo LAB.md e pelo DEPLOY.md." % porta_dvwa)
    sys.exit(1)

print("OK -- todas as portas publicadas estao presas a %s, e o dvwa usa a %s."
      % (bind, porta_dvwa))
PYFIM
  exit $?
fi

# ------------------------------------------------------------------
# Modo grep (plano B)
#
# Casa item de lista com a forma de mapeamento de porta -- `- <algo>:<numero>`
# terminando em digitos e sem barra, o que exclui volumes como
# `./reports:/reports` e `...:/etc/apache2/x.conf:ro` -- e exige o prefixo
# 127.0.0.1 em cada um.
# ------------------------------------------------------------------
echo "AVISO: docker ou python indisponiveis -- usando o modo grep, que cobre menos casos." >&2

FORMA_PORTA='^[[:space:]]*-[[:space:]]*"?[^"/[:space:]]+:[0-9]+"?[[:space:]]*$'
SUSPEITAS=""
N=0

while IFS= read -r LINHA; do
  N=$((N + 1))
  printf '%s' "$LINHA" | grep -Eq "$FORMA_PORTA" || continue
  printf '%s' "$LINHA" | grep -Eq "^[[:space:]]*-[[:space:]]*\"?${BIND_ESPERADO}:" && continue
  SUSPEITAS="${SUSPEITAS}  linha ${N}:${LINHA}"$'\n'
done < docker-compose.yml

if [ -n "$SUSPEITAS" ]; then
  erro "mapeamento(s) de porta sem o prefixo $BIND_ESPERADO em docker-compose.yml:"
  printf '%s' "$SUSPEITAS" >&2
  erro "Use o formato $BIND_ESPERADO:<porta-host>:<porta-container> -- ver secao 7 do enunciado."
  exit 1
fi

grep -q "${BIND_ESPERADO}:${PORTA_DVWA}:80" docker-compose.yml || {
  erro "bind ${BIND_ESPERADO}:${PORTA_DVWA}:80 nao encontrado em docker-compose.yml."
  exit 1
}

echo "OK -- nenhum mapeamento fora de $BIND_ESPERADO, e o bind do dvwa esta presente."
