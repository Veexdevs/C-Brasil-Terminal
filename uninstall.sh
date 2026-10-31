#!/usr/bin/env sh
# Remove o comando `cbrasil` e a instalação da linguagem.
#
#   sh uninstall.sh              remove o comando e a pasta de dados
#   sh uninstall.sh --keep-data  remove só o comando
#   sh uninstall.sh --home DIR   usa uma pasta de instalação específica

set -eu

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CB_HOME_OPT=""
BIN_DIR_OPT=""
KEEP_DATA=0

msg() { printf 'cbrasil: %s\n' "$*"; }
die() { printf 'cbrasil: erro: %s\n' "$*" >&2; exit 1; }

is_termux() {
    case "${PREFIX:-}" in
        *com.termux*) return 0 ;;
    esac
    return 1
}

while [ $# -gt 0 ]; do
    case "$1" in
        --keep-data) KEEP_DATA=1 ;;
        --home) shift; [ $# -ge 1 ] || die "--home precisa de um valor"; CB_HOME_OPT=$1 ;;
        --bin) shift; [ $# -ge 1 ] || die "--bin precisa de um valor"; BIN_DIR_OPT=$1 ;;
        -h|--help)
            printf 'Uso: sh uninstall.sh [--keep-data] [--home DIR] [--bin DIR]\n'
            exit 0 ;;
        *) die "opção desconhecida: $1" ;;
    esac
    shift
done

if [ -n "$CB_HOME_OPT" ]; then
    CB_HOME=$CB_HOME_OPT
elif [ -n "${CBRAZIL_HOME:-}" ]; then
    CB_HOME=$CBRAZIL_HOME
elif is_termux; then
    CB_HOME=$PREFIX/share/cbrasil
else
    CB_HOME=${XDG_DATA_HOME:-$HOME/.local/share}/cbrasil
fi

if [ -n "$BIN_DIR_OPT" ]; then
    BIN_DIR=$BIN_DIR_OPT
elif is_termux; then
    BIN_DIR=$PREFIX/bin
elif [ -d /usr/local/bin ] && [ -w /usr/local/bin ]; then
    BIN_DIR=/usr/local/bin
else
    BIN_DIR=$HOME/.local/bin
fi

# Descobre a pasta gravada dentro do comando, se o padrão não existir.
if [ ! -d "$CB_HOME" ] && [ -f "$BIN_DIR/cbrasil" ]; then
    FOUND=$(sed -n 's/^CBRAZIL_HOME_DEFAULT="\(.*\)"$/\1/p' "$BIN_DIR/cbrasil" | head -n 1)
    if [ -n "${FOUND:-}" ] && [ "$FOUND" != "__CBRAZIL_HOME__" ] && [ -d "$FOUND" ]; then
        CB_HOME=$FOUND
    fi
fi

if [ -f "$BIN_DIR/cbrasil" ]; then
    rm -f "$BIN_DIR/cbrasil"
    msg "comando removido: $BIN_DIR/cbrasil"
else
    msg "comando não encontrado em $BIN_DIR/cbrasil"
fi

if [ "$KEEP_DATA" -eq 1 ]; then
    msg "dados mantidos em $CB_HOME"
    exit 0
fi

CACHE=${CBRAZIL_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/cbrasil}
if [ -d "$CB_HOME" ]; then
    rm -rf "$CB_HOME"
    msg "instalação removida: $CB_HOME"
fi
if [ -d "$CACHE" ]; then
    rm -rf "$CACHE"
    msg "cache removido: $CACHE"
fi

msg "pronto."
