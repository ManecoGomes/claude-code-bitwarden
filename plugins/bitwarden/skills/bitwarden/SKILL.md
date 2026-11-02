---
name: bitwarden
description: Lê e usa segredos do cofre Bitwarden do usuário no macOS através do comando `bwcc`. Use SEMPRE que o pedido envolver uma credencial que mora no cofre — "qual minha senha do X", "pega o token do Y", "busca no Bitwarden", "procura no meu cofre", "preciso da API key de Z", "roda esse script com as credenciais do banco", "preenche o .env", "salva essa senha no cofre", "gera uma senha e guarda", "código do 2FA/TOTP", "copia a senha pra área de transferência", "lista o que tenho de login do domínio W" — e também quando um comando falhar por falta de credencial que provavelmente está no Bitwarden. NÃO use para 1Password (ali é o CLI `op`) nem para segredos que já estão em variáveis de ambiente ou arquivos do projeto.
---

# Bitwarden pelo Claude Code

O comando `bwcc` é a ponte com o cofre. Ele embrulha o CLI oficial `bw`,
desbloqueia pelo app desktop (Touch ID), guarda a sessão no Keychain do macOS e
**mascara segredos por padrão**.

Rode `bwcc --help` se precisar da lista completa.

## A regra que não se quebra

Todo valor que você imprime entra na transcrição da conversa e, com ela, sai da
máquina do usuário. Então:

1. **Não use `--reveal` por iniciativa própria.** Só quando o usuário pediu o
   valor em tela, com essas palavras ("me mostra a senha", "imprime o token").
2. Quando ele quer *usar* o segredo (colar em algum lugar, logar em um site),
   use `bwcc copy` — vai pra área de transferência e nada aparece.
3. Quando um **comando** precisa do segredo, use `bwcc run`. O valor entra no
   ambiente do processo filho e nunca passa pelo terminal.
4. Quando um **arquivo** precisa do segredo (`.env`, config), use `bwcc inject`.
5. Nunca repita um segredo revelado numa mensagem posterior, nem em comentário
   de código, nem em mensagem de commit.

## Descobrir antes de pedir

Não adivinhe nome de item nem de campo.

```bash
bwcc list github          # itens que casam com "github": nome, usuário, domínio, id
bwcc fields "GitHub"      # quais campos esse item tem — sem os valores
```

Se a busca casar com vários itens, `bwcc` lista os candidatos e sai com erro em
vez de escolher um. Mostre a lista ao usuário e pergunte qual é.

## Ler

```bash
bwcc get "GitHub" username        # campo aberto: imprime normal
bwcc get "GitHub" password        # campo secreto: mascarado + fingerprint
bwcc copy "GitHub" password       # → área de transferência  ← o caminho normal
bwcc get "GitHub" password --reveal   # só com pedido explícito do usuário
bwcc totp "GitHub"                # código 2FA (expira em ~30s)
```

Campos abertos: `username`, `uri`, `name`, `id` e campos custom visíveis.
Campos secretos: `password`, `notes`, `totp` e campos custom ocultos.

## Usar sem exibir

Referência: `bw://<item>/<campo>` (campo omitido = `password`).

```bash
# roda um comando com o segredo no ambiente
DATABASE_URL='bw://Supabase MGE/connection_string' bwcc run -- npm run migrate

# um .env de template virando .env real
bwcc inject -i .env.example -o .env     # troca {{ bw://item/campo }}

# um arquivo .env cujos valores são referências
bwcc run -e .env.refs -- ./deploy.sh
```

## Escrever

```bash
bwcc gen --length 32                     # gera (imprime: não é dado do cofre ainda)
bwcc add "Nome do serviço" --username maneco@exemplo.com \
         --uri https://exemplo.com --generate     # cria sem nunca exibir a senha
printf '%s' "$SENHA" | bwcc add "Serviço" --username u --password-stdin
```

`bwcc` **não apaga nem edita** itens — isso é de propósito. Se o usuário pedir
pra remover ou alterar algo no cofre, diga que ele faz isso no app do Bitwarden.

## Sessão e erros

| Situação | O que fazer |
|---|---|
| `você não está logado` | Ele precisa rodar `bw login` uma vez **no Terminal.app ou iTerm**. Não tente logar por ele e **não use o prefixo `!`**: o CLI usa readline e morre com `ERR_USE_AFTER_CLOSE` sem tty próprio. Dá pra abrir o terminal pra ele: `osascript -e 'tell application "Terminal" to do script "bw login"'`. Quem não quer prompt usa `bw login --apikey` com `BW_CLIENTID`/`BW_CLIENTSECRET`. |
| primeiro comando da sessão demora | É o desbloqueio: ou o prompt de Touch ID, ou o diálogo de senha mestra. Normal — avise que apareceu um diálogo na tela dele. |
| `biometria indisponível` / sem Touch ID | Esperado em Mac sem sensor (mini/Studio) ou com a flag `biometrics-sdk-ipc` desligada pelo servidor. **Não** mande o usuário "ligar a biometria no app": rode `bwcc doctor` e leia o motivo real antes de orientar. |
| algo esquisito na instalação | `bwcc doctor` diagnostica tudo (CLI, app, proxy IPC, Keychain, login). |
| segredo mudou no cofre agora | `bwcc sync` antes de ler. |

A sessão fica em cache (padrão: 15 min de TTL deslizante; se o usuário puser
`BWCC_SESSION_TTL=0` em `~/.config/bwcc/config`, vale até reiniciar o Mac).
Então uma sequência de comandos só desbloqueia uma vez. `bwcc lock` encerra na
hora. A sessão nunca sobrevive a um restart.
