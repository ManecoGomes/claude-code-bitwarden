---
description: Diagnostica a integração Bitwarden ↔ Claude Code
---

Rode `bwcc doctor` e interprete o resultado para o usuário.

Para cada item com ✗, diga em uma linha o que resolve:

- **CLI bw** ausente → `npm install -g @bitwarden/cli`
- **app Bitwarden desktop** ausente ou abaixo de 2026.9.0 → atualizar o app
- **login** `unauthenticated` → o usuário roda `bw login` no Terminal.app ou iTerm
  (tem 2FA, não tente por ele). O prefixo `!` do Claude Code **não** serve: sem tty
  o CLI aborta com `ERR_USE_AFTER_CLOSE`. Ofereça abrir o terminal:
  `osascript -e 'tell application "Terminal" to do script "bw login"'`
- **Keychain** falhando → a sessão não fica em cache; cada comando pede Touch ID.
  Alternativa: `export BWCC_SESSION_STORE=file`
- **jq** ausente → `brew install jq`

As linhas com `·` são **fatos da máquina, não defeitos** — não ofereça conserto
pra elas:

- **sensor biométrico AUSENTE** → Mac mini/Studio não tem Touch ID. Não existe
  configuração, app ou truque que resolva, e o iPhone não serve como sensor do
  Mac (a Apple não expõe isso). O único caminho é um Magic Keyboard com Touch ID.
  Nesse caso a senha mestra é o normal, e o jeito de reduzir atrito é
  `BWCC_SESSION_TTL=0` em `~/.config/bwcc/config` (uma senha por boot).
- **flag biometrics-sdk-ipc desligada** → rollout da Bitwarden, do lado do
  servidor. Sem conserto local; `BWCC_BIOMETRICS=force` tenta mesmo assim.

No fim, se estiver tudo ✓, confirme com `bwcc status` se o cofre está destravado.
