#!/usr/bin/env sh
# ============================================================================
#  Instalador do comando `cbrasil`
#
#  Uso:
#     sh install.sh                instala para o usuário atual
#     sh install.sh --bin ~/bin    escolhe a pasta do comando
#     sh install.sh --add-path     adiciona a pasta do comando ao PATH
#
#  Depois de instalar, `cbrasil arquivo.cbr` funciona de qualquer pasta,
#  inclusive fora do repositório, e a linguagem se atualiza sozinha a partir
#  de https://github.com/vorgweb/C-Brasil
# ============================================================================

set -eu

INSTALLER_VERSION="1.0.0"
SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
LAUNCHER_URL="https://raw.githubusercontent.com/Veexdevs/C-Brasil-Terminal/main/bin/cbrasil"

CB_HOME_OPT=""
BIN_DIR_OPT=""
ADD_PATH=0
SKIP_BUILD=0

msg()  { printf 'cbrasil: %s\n' "$*"; }
warn() { printf 'cbrasil: aviso: %s\n' "$*" >&2; }
err()  { printf 'cbrasil: erro: %s\n' "$*" >&2; }
die()  { err "$*"; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

usage() {
    cat <<EOF
Instalador do cbrasil $INSTALLER_VERSION

Uso: sh install.sh [opções]

Opções:
  --home DIR     pasta de instalação (padrão em Termux: \$PREFIX/share/cbrasil)
  --bin DIR      pasta onde o comando cbrasil será criado
  --add-path     adiciona a pasta do comando ao PATH (~/.bashrc, ~/.profile)
  --no-build     não baixa/compila a linguagem agora
  -h, --help     mostra esta ajuda

Depois: cbrasil programa.cbr
EOF
}

is_termux() {
    case "${PREFIX:-}" in
        *com.termux*) return 0 ;;
    esac
    return 1
}

pick_cc() {
    if [ -n "${CC:-}" ]; then printf '%s' "$CC"; return 0; fi
    for c in cc gcc clang; do
        if have "$c"; then printf '%s' "$c"; return 0; fi
    done
    return 1
}

while [ $# -gt 0 ]; do
    case "$1" in
        --home) shift; [ $# -ge 1 ] || die "--home precisa de um valor"; CB_HOME_OPT=$1 ;;
        --bin) shift; [ $# -ge 1 ] || die "--bin precisa de um valor"; BIN_DIR_OPT=$1 ;;
        --add-path) ADD_PATH=1 ;;
        --no-build) SKIP_BUILD=1 ;;
        -h|--help) usage; exit 0 ;;
        *) die "opção desconhecida: $1 (use --help)" ;;
    esac
    shift
done

# ---------------------------------------------------------------------------
# Pastas
# ---------------------------------------------------------------------------

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

# ---------------------------------------------------------------------------
# Dependências
# ---------------------------------------------------------------------------

if CC_BIN=$(pick_cc); then
    msg "compilador C: $CC_BIN"
else
    err "nenhum compilador C encontrado — o C-Brasil traduz para C e precisa compilar."
    if is_termux; then
        err "Termux: pkg install clang git"
    else
        err "Debian/Ubuntu: sudo apt install gcc git | Fedora: sudo dnf install gcc git"
    fi
    exit 1
fi

if [ -n "${CBRAZIL_SOURCE_DIR:-}" ] && [ -f "${CBRAZIL_SOURCE_DIR}/cbr.c" ]; then
    msg "fonte local: $CBRAZIL_SOURCE_DIR"
elif have git; then
    msg "git: $(git --version | head -n 1)"
elif have curl || have wget; then
    warn "git não encontrado — será usado o download do tarball do GitHub"
else
    err "instale 'git' ou 'curl' para baixar a linguagem"
    exit 1
fi

if ! mkdir -p "$CB_HOME" 2>/dev/null || [ ! -w "$CB_HOME" ]; then
    die "sem permissão de escrita em $CB_HOME (use --home ~/cbrasil)"
fi
mkdir -p "$BIN_DIR" 2>/dev/null || die "não foi possível criar $BIN_DIR"

# ---------------------------------------------------------------------------
# Comando cbrasil
# ---------------------------------------------------------------------------

CB_HOME_VALUE="$CB_HOME"

# Termux pode não ter /tmp: escolhe uma pasta temporária que exista.
tmp_dir() {
    for d in "${TMPDIR:-}" /tmp "$CB_HOME"; do
        if [ -n "$d" ] && [ -d "$d" ] && [ -w "$d" ]; then
            printf '%s' "$d"
            return 0
        fi
    done
    printf '.'
}
TMPD=$(tmp_dir)

TMP_LAUNCHER=$(mktemp "$TMPD/cbrasil-install.XXXXXX") || die "mktemp falhou"
trap 'rm -f "$TMP_LAUNCHER"' EXIT INT TERM HUP

if [ -f "$SELF_DIR/bin/cbrasil" ]; then
    cp "$SELF_DIR/bin/cbrasil" "$TMP_LAUNCHER"
elif have curl; then
    curl -fsSL --connect-timeout 20 "$LAUNCHER_URL" -o "$TMP_LAUNCHER" || die "não foi possível baixar o cbrasil"
elif have wget; then
    wget -q -O "$TMP_LAUNCHER" "$LAUNCHER_URL" || die "não foi possível baixar o cbrasil"
else
    die "bin/cbrasil não encontrado ao lado do instalador"
fi

# Grava a pasta de instalação dentro do comando (assim ele acha tudo fora do repo).
sed "s|__CBRAZIL_HOME__|$CB_HOME_VALUE|g" "$TMP_LAUNCHER" > "$TMP_LAUNCHER.new"
mv "$TMP_LAUNCHER.new" "$TMP_LAUNCHER"
chmod +x "$TMP_LAUNCHER"
mv "$TMP_LAUNCHER" "$BIN_DIR/cbrasil"
trap - EXIT INT TERM HUP
chmod +x "$BIN_DIR/cbrasil"
msg "comando instalado em $BIN_DIR/cbrasil"

# ---------------------------------------------------------------------------
# Linguagem (fonte + tradutor compilado)
# ---------------------------------------------------------------------------

if [ "$SKIP_BUILD" -eq 0 ]; then
    CBRAZIL_HOME="$CB_HOME" "$BIN_DIR/cbrasil" --update || die "falha ao instalar a linguagem"
fi

# ---------------------------------------------------------------------------
# PATH
# ---------------------------------------------------------------------------

case ":${PATH:-}:" in
    *":$BIN_DIR:"*) IN_PATH=1 ;;
    *) IN_PATH=0 ;;
esac

if [ "$IN_PATH" -eq 0 ]; then
    warn "$BIN_DIR não está no PATH"
    if [ "$ADD_PATH" -eq 1 ]; then
        LINE="export PATH=\"$BIN_DIR:\$PATH\""
        for RC in "$HOME/.profile" "$HOME/.bashrc"; do
            [ -f "$RC" ] || continue
            if ! grep -F "$BIN_DIR" "$RC" >/dev/null 2>&1; then
                printf '\n# cbrasil\n%s\n' "$LINE" >> "$RC"
                msg "PATH adicionado em $RC"
            fi
        done
        warn "abra um novo terminal (ou rode: . ~/.profile) para o comando valer"
    else
        msg "adicione ao PATH com: export PATH=\"$BIN_DIR:\$PATH\""
        msg "ou rode: sh install.sh --add-path"
    fi
fi

# ---------------------------------------------------------------------------
# Teste rápido
# ---------------------------------------------------------------------------

if [ "$SKIP_BUILD" -eq 0 ]; then
    TEST_FILE=$(mktemp "$TMPD/cbrasil-teste.XXXXXX.cbr")
    printf 'printf("cbrasil funcionando!\\n")\nend(0)\n' > "$TEST_FILE"
    if OUT=$(CBRAZIL_HOME="$CB_HOME" "$BIN_DIR/cbrasil" "$TEST_FILE" 2>&1); then
        msg "teste: $OUT"
    else
        rm -f "$TEST_FILE"
        die "o teste falhou. Rode '$BIN_DIR/cbrasil --doctor' para diagnosticar"
    fi
    rm -f "$TEST_FILE"
fi

cat <<EOF

Pronto! O comando "cbrasil" está instalado.

  cbrasil programa.cbr      executa um programa
  cbrasil --update          busca a versão mais nova da linguagem
  cbrasil --doctor          diagnóstico
  cbrasil --help            ajuda completa

A linguagem é atualizada sozinha a partir de
https://github.com/vorgweb/C-Brasil (verificação a cada 6 horas).

EOF
