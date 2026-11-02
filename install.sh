#!/usr/bin/env bash
# Instalador do claude-code-bitwarden (macOS).
# Não pede sudo: o link vai pra ~/.local/bin por padrão.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/plugins/bitwarden/bin/bwcc"
BIN_DIR="${BWCC_BIN_DIR:-$HOME/.local/bin}"
REPO_URL="https://github.com/ManecoGomes/claude-code-bitwarden"

say()  { printf '%s\n' "$1"; }
step() { printf '\n==> %s\n' "$1"; }
warn() { printf '!   %s\n' "$1" >&2; }
die()  { printf 'erro: %s\n' "$1" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || die "este instalador é pra macOS (Touch ID + Keychain)."
[ -f "$SRC" ] || die "não achei $SRC — rode o instalador de dentro do repositório."

step "dependências"
if ! command -v jq >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    say "instalando jq pelo Homebrew..."
    brew install jq
  else
    die "jq é necessário e não há Homebrew. Instale o jq e rode de novo."
  fi
fi
say "jq       $(jq --version)"

if ! command -v bw >/dev/null 2>&1; then
  if command -v npm >/dev/null 2>&1; then
    say "instalando o CLI oficial do Bitwarden (npm -g @bitwarden/cli)..."
    npm install -g @bitwarden/cli
  else
    die "CLI bw ausente e npm não encontrado. Instale o Node ou use: brew install bitwarden-cli"
  fi
fi
say "bw CLI   $(bw --version)"

if [ -d /Applications/Bitwarden.app ]; then
  dv="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
        /Applications/Bitwarden.app/Contents/Info.plist 2>/dev/null || echo '?')"
  say "app      Bitwarden $dv"
  case "$dv" in
    2026.[9]*|2026.1[0-9]*|202[7-9]*|20[3-9]*) : ;;
    *) warn "app desktop $dv: o desbloqueio por Touch ID no CLI exige 2026.9.0 ou mais novo." ;;
  esac
else
  warn "app Bitwarden desktop não encontrado em /Applications — sem ele não há Touch ID,"
  warn "o bwcc vai pedir a senha mestra num diálogo."
fi

step "instalando o bwcc em $BIN_DIR"
mkdir -p "$BIN_DIR"
chmod +x "$SRC"
ln -sf "$SRC" "$BIN_DIR/bwcc"
say "$BIN_DIR/bwcc -> $SRC"

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) warn "$BIN_DIR não está no PATH. Acrescente ao seu ~/.zshrc:"
     warn "    export PATH=\"$BIN_DIR:\$PATH\"" ;;
esac

step "plugin do Claude Code"
cat <<MSG
Dentro do Claude Code, rode:

    /plugin marketplace add ManecoGomes/claude-code-bitwarden
    /plugin install bitwarden@claude-code-bitwarden

Ou, pra usar este clone local direto:

    /plugin marketplace add $HERE

MSG

step "próximos passos"
cat <<MSG
1) Faça login uma única vez (tem 2FA, então é você quem digita):

       bw login

2) Ligue a biometria no app Bitwarden desktop:
   Configurações → Desbloqueio com Touch ID

3) Confira tudo:

       bwcc doctor
       bwcc status

Documentação: $REPO_URL
MSG
