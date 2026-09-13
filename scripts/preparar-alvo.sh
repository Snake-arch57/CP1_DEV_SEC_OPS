#!/usr/bin/env bash
#
# Prepara o codigo-fonte do alvo para o SAST.
#
# Por que existe: o OpenGrep analisa o CODIGO-FONTE do DVWA, nao a imagem em
# execucao. O compose monta ./targets/dvwa em /src, mas esse diretorio esta
# no .gitignore -- e um repositorio de terceiros, com historico proprio, e
# versiona-lo poluiria o historico de commits do grupo, que e avaliado.
#
# Resultado pratico: quem clona este repositorio NAO recebe o alvo junto, e
# precisa clona-lo. Este script faz isso de forma idempotente.
#
# Uso:
#     bash scripts/preparar-alvo.sh
#
# Rode na raiz do repositorio, antes do passo 2 do LAB.md.

set -euo pipefail

ALVO_URL="https://github.com/digininja/DVWA.git"
ALVO_DIR="targets/dvwa"

# A raiz do repositorio, independente de onde o script foi chamado.
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

if [ -d "$ALVO_DIR/.git" ]; then
    echo "[ok] $ALVO_DIR ja existe ($(find "$ALVO_DIR" -type f | wc -l) arquivos)."
    echo "     Para recomeçar do zero: rm -rf $ALVO_DIR && bash scripts/preparar-alvo.sh"
    exit 0
fi

if [ -d "$ALVO_DIR" ] && [ -n "$(ls -A "$ALVO_DIR" 2>/dev/null)" ]; then
    echo "[erro] $ALVO_DIR existe, tem conteudo, mas nao e um repositorio git." >&2
    echo "       Remova-o e rode este script de novo." >&2
    exit 1
fi

# Diretorio criado pelo Docker, e nao por quem esta rodando o script.
#
# Como isso acontece: o compose monta ./targets/dvwa em /src. Quando o
# caminho nao existe, o Docker o CRIA -- e como o daemon roda como root, os
# diretorios nascem root:root. Quem executa o passo 2 antes do passo 0 fica
# preso: o clone falha com "Permission denied".
#
# O detalhe que custou um teste: o Docker cria a arvore INTEIRA, entao
# `targets/` tambem e root. Remover so `targets/dvwa` nao resolve -- o git
# ainda nao consegue criar o diretorio dentro do pai. Por isso a remocao
# precisa alcancar o primeiro nivel que nao e gravavel.
ALVO_PAI="$(dirname "$ALVO_DIR")"
if { [ -d "$ALVO_DIR" ] && [ ! -w "$ALVO_DIR" ]; } \
   || { [ -d "$ALVO_PAI" ] && [ ! -w "$ALVO_PAI" ]; }; then

    if [ -d "$ALVO_PAI" ] && [ ! -w "$ALVO_PAI" ]; then
        remover="$ALVO_PAI"
        alvo_descrito="$ALVO_PAI (e tudo dentro dele)"
    else
        remover="$ALVO_DIR"
        alvo_descrito="$ALVO_DIR"
    fi

    dono=$(stat -c '%U' "$remover" 2>/dev/null || echo "outro usuario")
    cat >&2 <<FIM
[erro] $alvo_descrito pertence a "$dono", nao a $(id -un).

       Isso acontece quando o passo 2 roda antes do passo 0: o Docker cria
       os diretorios do bind mount, e o daemon roda como root.

       Remova e rode este script de novo:

           sudo rm -rf $remover
           bash scripts/preparar-alvo.sh

FIM
    exit 1
fi

echo "[..] Clonando o alvo em $ALVO_DIR"
echo "     $ALVO_URL"

# --depth 1: so o estado atual. O historico do DVWA nao interessa ao
# laboratorio, e o clone raso baixa uma fracao do tamanho.
git clone --quiet --depth 1 "$ALVO_URL" "$ALVO_DIR"

total=$(find "$ALVO_DIR" -type f | wc -l)
php=$(find "$ALVO_DIR" -name '*.php' -type f | wc -l)

echo "[ok] Alvo pronto: $total arquivos, sendo $php .php"

# O arquivo que o passo 3 do LAB.md manda procurar. Se ele nao estiver aqui,
# a estrutura do DVWA mudou e o roteiro precisa ser revisto.
SQLI="$ALVO_DIR/vulnerabilities/sqli/source/low.php"
if [ -f "$SQLI" ]; then
    echo "[ok] $SQLI presente -- e o achado que o passo 3 manda encontrar."
else
    echo "[aviso] $SQLI nao encontrado." >&2
    echo "        A estrutura do DVWA pode ter mudado; confira o passo 3 do LAB.md." >&2
fi

echo
echo "Proximo passo: o passo 1 do LAB.md (docker compose up -d dvwa)."
