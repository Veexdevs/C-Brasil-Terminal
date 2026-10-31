# cbrasil — a linguagem C-Brasil no terminal

Este repositório instala o comando **`cbrasil`**, que executa arquivos `.cbr` da
linguagem [C-Brasil](https://github.com/vorgweb/C-Brasil) direto no terminal,
exatamente como `python arquivo.py`, `node arquivo.js` ou `bash script.sh`:

```sh
nano ola.cbr
cbrasil ola.cbr
```

O comando funciona **de qualquer pasta**, sem precisar estar dentro do
repositório, e busca/atualiza a linguagem automaticamente no
[repositório oficial](https://github.com/vorgweb/C-Brasil).

---

## Instalação no Termux

```sh
pkg update
pkg install -y git clang

git clone https://github.com/Veexdevs/C-Brasil-Terminal.git
cd C-Brasil-Terminal
sh install.sh
cd
```

Depois disso você pode apagar a pasta clonada: o comando `cbrasil` fica em
`$PREFIX/bin`, a linguagem fica em `$PREFIX/share/cbrasil` e o cache em
`~/.cache/cbrasil`.

Teste:

```sh
nano ola.cbr
```

```cbr
nome = "mundo"
printf("Olá, {str.nome}!\n")
end(0)
```

```sh
cbrasil ola.cbr
# Olá, mundo!
```

## Instalação no Linux / macOS

```sh
sudo apt install gcc git        # Debian/Ubuntu (macOS: xcode-select --install)
git clone https://github.com/Veexdevs/C-Brasil-Terminal.git
cd C-Brasil-Terminal
sh install.sh
```

O instalador escolhe `/usr/local/bin` se você tiver permissão, senão
`~/.local/bin`. Para usar outra pasta do `PATH`:

```sh
sh install.sh --bin ~/bin
```

E se a pasta não estiver no `PATH`:

```sh
sh install.sh --add-path      # adiciona em ~/.profile e ~/.bashrc
```

## Uso

```sh
cbrasil programa.cbr              # executa (como python arquivo.py)
cbrasil programa                   # a extensão .cbr é opcional
cbrasil -                          # lê o programa da entrada padrão
cbrasil gerar programa.cbr         # mostra/gera o C traduzido
cbrasil compilar programa.cbr      # gera um executável nativo otimizado
cbrasil --update                   # atualiza a linguagem agora
cbrasil --doctor                   # diagnóstico da instalação
cbrasil --where                    # caminhos usados
cbrasil --version                  # versões do executor e da linguagem
cbrasil --help                     # ajuda
```

O código de saída do programa é preservado (`end(3)` → `$?` = 3), e a entrada
padrão, a saída e os erros são os do próprio terminal — então `scan(...)`,
`pipe` e redirecionamento funcionam normalmente.

### Exemplos incluídos

```sh
cbrasil examples/ola.cbr
cbrasil examples/tabuada.cbr
printf '7.5\n5.0\n' | cbrasil examples/media.cbr
```

---

## Como funciona

O C-Brasil é uma linguagem traduzida para C. O `cbrasil` faz o caminho completo
para você:

```
programa.cbr  ──►  tradutor Cbr  ──►  programa.c  ──►  cc/gcc/clang  ──►  executa
```

1. **Fonte da linguagem**: `cbrasil --update` clona (ou atualiza via `git`) o
   repositório [`vorgweb/C-Brasil`](https://github.com/vorgweb/C-Brasil) em
   `$CBRAZIL_HOME/src` e compila o tradutor `cbr.c` para `$CBRAZIL_HOME/bin/cbr`.
   Sem `git` instalado, o mesmo conteúdo é baixado como tarball do GitHub.
2. **Execução**: cada `.cbr` é traduzido, compilado e executado. Os binários
   ficam em cache (`~/.cache/cbrasil`) por *hash do conteúdo do arquivo*, então
   a segunda execução do mesmo arquivo é instantânea. Se você editar o arquivo
   no `nano`, o cache é invalidado sozinho e ele recompila.
3. **Atualização automática**: a cada 6 horas o `cbrasil` verifica em segundo
   plano se o repositório oficial mudou. Quando muda, ele baixa, recompila o
   tradutor, limpa o cache e avisa na próxima execução:

   ```
   cbrasil: linguagem C-Brasil atualizada (a1b2c3d)
   ```

   A atualização roda em segundo plano: o programa que você está executando
   nunca fica esperando rede.

## Atualizar o próprio comando

```sh
cd C-Brasil-Terminal
git pull
sh install.sh
```

(A linguagem em si não precisa disso — ela se atualiza sozinha.)

## Variáveis de ambiente

| Variável | Padrão | Para que serve |
| --- | --- | --- |
| `CBRAZIL_HOME` | Termux: `$PREFIX/share/cbrasil`; outros: `~/.local/share/cbrasil` | Pasta da instalação (fonte + tradutor) |
| `CBRAZIL_NO_UPDATE` | `0` | `1` desliga a atualização automática |
| `CBRAZIL_UPDATE_INTERVAL` | `21600` (6 h) | Segundos entre verificações de atualização |
| `CBRAZIL_CACHE` | `~/.cache/cbrasil` | Cache dos programas compilados |
| `CBRAZIL_QUIET` | `0` | `1` esconde o aviso de atualização |
| `CBRAZIL_SOURCE_DIR` | — | Usa uma pasta local com `cbr.c` em vez do GitHub (offline/desenvolvimento) |
| `CBRAZIL_REPO_URL` | `https://github.com/vorgweb/C-Brasil.git` | Outro repositório/fork da linguagem |
| `CBRAZIL_REPO_BRANCH` | `main` | Outro branch da linguagem |
| `CC` | `cc`/`gcc`/`clang` | Compilador C usado |

## Desinstalar

```sh
sh uninstall.sh              # remove o comando, a instalação e o cache
sh uninstall.sh --keep-data  # remove só o comando
```

---

## Estrutura do repositório

```
bin/cbrasil        comando autossuficiente (baixa, compila, executa, atualiza)
install.sh         instalador (Termux, Linux, macOS)
uninstall.sh       desinstalador
examples/          programas de exemplo em .cbr
tests/test.sh      testes automatizados (instalação, execução, erros, update)
Makefile           atalhos: make install / make test
```

## Testes

```sh
sh tests/test.sh
# ou, usando um clone local da linguagem (sem internet):
CBRAZIL_SOURCE_DIR=~/C-Brasil sh tests/test.sh
```

Os testes rodam em pastas temporárias e não tocam na sua instalação real.

## Problemas comuns

**"nenhum compilador C encontrado"**
O C-Brasil traduz para C, então precisa de um compilador:
`pkg install clang` (Termux) ou `sudo apt install gcc`.

**"não foi possível atualizar"**
Rode `cbrasil --doctor`. Veja o log em `$CBRAZIL_HOME/update.log`. Se estiver
offline, o programa continua funcionando com a versão já instalada.

**O comando não é encontrado**
`$PREFIX/bin` (Termux) já está no `PATH`. No Linux, rode
`sh install.sh --add-path` ou adicione `~/.local/bin` ao `PATH`.

**Erro no meu programa**
O tradutor aponta arquivo e linha, por exemplo:
`ola.cbr:2: erro: variável usada na expressão não foi declarada`.
A lista de recursos e limitações da linguagem está no
[README do C-Brasil](https://github.com/vorgweb/C-Brasil).

## Licença

O executor e os scripts deste repositório seguem a mesma licença do projeto
C-Brasil.
