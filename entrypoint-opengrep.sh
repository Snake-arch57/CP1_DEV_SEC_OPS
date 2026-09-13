#!/bin/sh
# Guarda do alvo do SAST.
#
# O compose monta ./targets/dvwa em /src. Esse diretorio NAO vem com o
# repositorio: esta no .gitignore, e o passo 0 do LAB.md manda clona-lo.
#
# Quando o diretorio nao existe, o Docker cria um vazio no lugar do bind
# mount. O OpenGrep entao varre nada, reporta "0 findings" e sai com codigo
# 0 -- exito. Quem pulou o clone ve um resultado que parece valido, nao
# encontra o SQL Injection que o roteiro promete, e descobre o problema na
# frente da turma.
#
# Falhar alto aqui e melhor do que acertar em silencio.

set -eu

if [ ! -d /src ] || [ -z "$(ls -A /src 2>/dev/null)" ]; then
    cat >&2 <<'FIM'

ERRO: o diretorio do alvo esta vazio.

  O OpenGrep analisa o CODIGO-FONTE do DVWA, que nao vem versionado neste
  repositorio. Sem ele, a varredura nao tem o que ler.

  Rode, na raiz do repositorio:

      sudo rm -rf targets           # o Docker acabou de cria-lo como root
      bash scripts/preparar-alvo.sh

  Depois repita o passo 2 do LAB.md.

  O sudo e necessario porque o bind mount deste container criou a arvore
  targets/ como root ao nao encontrar o caminho -- inclusive o diretorio
  pai. Preparar o alvo ANTES do passo 2 evita isso por completo.

FIM
    exit 1
fi

exec opengrep "$@"
