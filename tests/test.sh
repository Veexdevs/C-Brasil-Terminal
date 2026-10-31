#!/usr/bin/env sh
# ============================================================================
#  Testes do comando `cbrasil`
#
#  Roda tudo em pastas temporárias: não mexe na instalação real.
#  Usa a internet (git clone do GitHub) a menos que CBRAZIL_SOURCE_DIR
#  aponte para um clone local de https://github.com/vorgweb/C-Brasil
# ============================================================================

set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d "${TMPDIR:-/tmp}/cbrasil-testes.XXXXXX")
trap 'rm -rf "$TMP"' EXIT INT TERM HUP

PASS=0
FAIL=0

ok()  { PASS=$((PASS + 1)); printf '  ok     %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf '  FALHOU %s\n' "$1"; }

assert_contains() { # descrição texto agulha
    case "$2" in
        *"$3"*) ok "$1" ;;
        *) bad "$1"; printf '         esperado conter: %s\n         obtido: %s\n' "$3" "$2" ;;
    esac
}

assert_status() { # descrição esperado obtido
    if [ "$2" = "$3" ]; then
        ok "$1"
    else
        bad "$1"; printf '         status esperado %s, obtido %s\n' "$2" "$3"
    fi
}

assert_file() { # descrição caminho
    if [ -f "$2" ]; then ok "$1"; else bad "$1 (não existe: $2)"; fi
}

# ---------------------------------------------------------------------------
# Ambiente isolado
# ---------------------------------------------------------------------------

export HOME="$TMP/home"
export XDG_DATA_HOME="$TMP/data"
export XDG_CACHE_HOME="$TMP/cache"
export CBRAZIL_HOME="$TMP/data/cbrasil"
export CBRAZIL_NO_UPDATE=1
export CBRAZIL_QUIET=1
BIN="$TMP/bin"
PROJ="$TMP/projeto"
mkdir -p "$HOME" "$BIN" "$PROJ"
PATH="$BIN:$PATH"
export PATH

if [ -n "${CBRAZIL_SOURCE_DIR:-}" ]; then
    printf 'usando fonte local: %s\n' "$CBRAZIL_SOURCE_DIR"
else
    printf 'usando a fonte do GitHub (defina CBRAZIL_SOURCE_DIR para testar offline)\n'
fi

printf '\n== instalação ==\n'
INSTALL_OUT=$(sh "$ROOT/install.sh" --home "$CBRAZIL_HOME" --bin "$BIN" 2>&1)
INSTALL_STATUS=$?
assert_status "instalador termina com sucesso" 0 "$INSTALL_STATUS"
assert_file "comando instalado" "$BIN/cbrasil"
assert_file "tradutor compilado" "$CBRAZIL_HOME/bin/cbr"
assert_file "fonte da linguagem presente" "$CBRAZIL_HOME/src/cbr.c"
assert_contains "teste do instalador rodou um programa" "$INSTALL_OUT" "cbrasil funcionando"

# ---------------------------------------------------------------------------
printf '\n== execução de programas ==\n'
# ---------------------------------------------------------------------------

cp "$ROOT/examples/ola.cbr" "$PROJ/ola.cbr"
cd "$PROJ" || exit 1

OUT=$(cbrasil ola.cbr 2>&1); st=$?
assert_status "ola.cbr executa" 0 "$st"
assert_contains "saída do ola.cbr" "$OUT" "Olá, mundo!"

OUT=$(cbrasil ola 2>&1); st=$?
assert_status "extensão .cbr é opcional" 0 "$st"
assert_contains "saída sem extensão" "$OUT" "C-Brasil rodando no terminal"

# Execução fora da pasta do repositório e com caminho absoluto.
cd "$TMP" || exit 1
OUT=$(cbrasil "$PROJ/ola.cbr" 2>&1); st=$?
assert_status "funciona fora da pasta do repositório" 0 "$st"
assert_contains "saída com caminho absoluto" "$OUT" "Olá, mundo!"

# Código de saída propagado (end(3)).
cat > "$PROJ/saida.cbr" <<'EOF'
printf("saindo com 3\n")
end(3)
EOF
OUT=$(cbrasil "$PROJ/saida.cbr" 2>&1); st=$?
assert_status "código de saída é propagado" 3 "$st"
assert_contains "saída antes de terminar" "$OUT" "saindo com 3"

# Entrada padrão.
OUT=$(printf 'printf("stdin-ok\\n")\nend(0)\n' | cbrasil - 2>&1); st=$?
assert_status "programa pela entrada padrão" 0 "$st"
assert_contains "saída do programa via stdin" "$OUT" "stdin-ok"

# Cache: a segunda execução reaproveita o binário.
OUT1=$(cbrasil "$PROJ/ola.cbr" 2>&1)
OUT2=$(cbrasil "$PROJ/ola.cbr" 2>&1)
assert_contains "segunda execução usa o cache" "$OUT2" "Olá, mundo!"
assert_contains "saída do cache é igual" "$OUT1" "C-Brasil rodando no terminal"

# Programa com entrada do usuário (scan).
OUT=$(printf '7.5\n5.0\n' | cbrasil "$ROOT/examples/media.cbr" 2>&1); st=$?
assert_status "programa com scan executa" 0 "$st"
assert_contains "scan calcula a média" "$OUT" "Media: 6.25"

# ---------------------------------------------------------------------------
printf '\n== mensagens de erro ==\n'
# ---------------------------------------------------------------------------

OUT=$(cbrasil nao_existe.cbr 2>&1); st=$?
assert_status "arquivo inexistente retorna 2" 2 "$st"
assert_contains "mensagem de arquivo inexistente" "$OUT" "arquivo não encontrado"

cat > "$PROJ/erro.cbr" <<'EOF'
x = 10
y = variavel_indefinida + 1
EOF
OUT=$(cbrasil "$PROJ/erro.cbr" 2>&1); st=$?
if [ "$st" -ne 0 ]; then ok "erro de compilação falha o programa"; else bad "erro de compilação falha o programa"; fi
assert_contains "erro aponta arquivo e linha" "$OUT" "erro.cbr:2"
assert_contains "mensagem do tradutor" "$OUT" "não foi declarada"

# ---------------------------------------------------------------------------
printf '\n== ferramentas ==\n'
# ---------------------------------------------------------------------------

OUT=$(cbrasil --version 2>&1)
assert_contains "--version mostra o executor" "$OUT" "executor C-Brasil"
assert_contains "--version mostra a linguagem" "$OUT" "Cbr"

OUT=$(cbrasil --help 2>&1); st=$?
assert_status "--help funciona" 0 "$st"
assert_contains "--help descreve o uso" "$OUT" "Uso:"

OUT=$(cbrasil --doctor 2>&1); st=$?
assert_status "--doctor funciona" 0 "$st"
assert_contains "--doctor detecta o compilador" "$OUT" "compilador"

cd "$PROJ" || exit 1
OUT=$(cbrasil gerar ola.cbr 2>&1); st=$?
assert_status "gerar traduz para C" 0 "$st"
assert_file "arquivo C gerado" "$PROJ/ola.c"
if grep -q 'int main' "$PROJ/ola.c" 2>/dev/null; then ok "C gerado tem main"; else bad "C gerado tem main"; fi

OUT=$(cbrasil compilar ola.cbr -o ola-bin 2>&1); st=$?
assert_status "compilar gera executável" 0 "$st"
assert_file "executável nativo" "$PROJ/ola-bin"
OUT=$(./ola-bin 2>&1)
assert_contains "executável nativo roda" "$OUT" "Olá, mundo!"

OUT=$(cbrasil --where 2>&1); st=$?
assert_status "--where funciona" 0 "$st"
assert_contains "--where mostra a instalação" "$OUT" "$CBRAZIL_HOME"

# ---------------------------------------------------------------------------
printf '\n== atualização ==\n'
# ---------------------------------------------------------------------------

OUT=$(cbrasil --update 2>&1); st=$?
assert_status "--update funciona" 0 "$st"
assert_contains "--update diz que está atualizado" "$OUT" "já está na versão mais recente"

# Simula uma nova versão da linguagem numa cópia local da fonte.
SRC_ORIGEM=${CBRAZIL_SOURCE_DIR:-$CBRAZIL_HOME/src}
SRC2="$TMP/fonte-nova"
mkdir -p "$SRC2"
( cd "$SRC_ORIGEM" && tar -cf - . ) 2>/dev/null | ( cd "$SRC2" && tar -xf - ) 2>/dev/null || true
if [ -f "$SRC2/cbr.c" ]; then
    printf '\n/* versão de teste %s */\n' "$(date +%s)" >> "$SRC2/cbr.c"
    OUT=$(CBRAZIL_SOURCE_DIR="$SRC2" cbrasil --update 2>&1); st=$?
    assert_status "atualização com fonte nova" 0 "$st"
    assert_contains "atualização reporta nova versão" "$OUT" "atualizado para"
    OUT=$(CBRAZIL_SOURCE_DIR="$SRC2" cbrasil "$PROJ/ola.cbr" 2>&1)
    assert_contains "programa roda com o tradutor novo" "$OUT" "Olá, mundo!"
else
    bad "não foi possível preparar a fonte para o teste de atualização"
fi

# ---------------------------------------------------------------------------
printf '\n== desinstalação ==\n'
# ---------------------------------------------------------------------------

sh "$ROOT/uninstall.sh" --home "$CBRAZIL_HOME" --bin "$BIN" >/dev/null 2>&1
if [ -f "$BIN/cbrasil" ]; then bad "uninstall remove o comando"; else ok "uninstall remove o comando"; fi
if [ -d "$CBRAZIL_HOME" ]; then bad "uninstall remove a instalação"; else ok "uninstall remove a instalação"; fi

# ---------------------------------------------------------------------------
printf '\n%d teste(s) ok, %d falha(s)\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
