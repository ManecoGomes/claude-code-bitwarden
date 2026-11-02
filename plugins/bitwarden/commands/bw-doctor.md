---
description: Diagnostica a integração Bitwarden ↔ Claude Code
---

Rode `bwcc doctor` e interprete o resultado para o usuário.

Para cada item com ✗, diga em uma linha o que resolve:

- **CLI bw** ausente → `npm install -g @bitwarden/cli`
- **app Bitwarden desktop** ausente ou abaixo de 2026.9.0 → atualizar o app; sem
  isso não existe desbloqueio por Touch ID e o `bwcc` cai na senha mestra
- **login** `unauthenticated` → o usuário roda `bw login` no Terminal.app ou iTerm
  (tem 2FA, não tente por ele). O prefixo `!` do Claude Code **não** serve: sem tty
  o CLI aborta com `ERR_USE_AFTER_CLOSE`. Ofereça abrir o terminal:
  `osascript -e 'tell application "Terminal" to do script "bw login"'`
- **Keychain** falhando → a sessão não fica em cache; cada comando pede Touch ID.
  Alternativa: `export BWCC_SESSION_STORE=file`
- **jq** ausente → `brew install jq`

No fim, se estiver tudo ✓, confirme com `bwcc status` se o cofre está destravado.
