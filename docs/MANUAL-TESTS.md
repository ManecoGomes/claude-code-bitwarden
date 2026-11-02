# Testes manuais (exigem cofre de verdade)

A suíte `tests/test-bwcc.sh` roda offline e cobre parsing, classificação de
campos, máscara, extração de sessão e as guardas de argumento. O que depende de
conta, app desktop e Touch ID é verificado à mão, uma vez por máquina.

Pré-requisito: `bwcc doctor` com tudo ✓ e `bw login` feito.

| # | Comando | Resultado esperado |
|---|---|---|
| 1 | `bwcc status` | `estado unlocked` ou `locked`, conta certa, app detectado |
| 2 | `bwcc unlock` (cofre travado) | com `biometrics-sdk-ipc=true`: prompt de Touch ID. Com `false`: aviso explicando a flag + diálogo de senha mestra. Nos dois casos termina em "sessão em cache, expira em 900s" |
| 3 | `bwcc unlock` de novo, na sequência | **sem** novo Touch ID (cache válido) |
| 4 | `bwcc list` | tabela com NOME/USUÁRIO/URI/ID, nenhuma senha |
| 5 | `bwcc fields "<item>"` | lista de campos, marcando `(secreto)`, **sem valores** |
| 6 | `bwcc get "<item>" username` | imprime o usuário |
| 7 | `bwcc get "<item>" password` | `•••••••• (N chars, sha256:…)` — nunca o valor |
| 8 | `bwcc copy "<item>"` | "copiado para a área de transferência"; `pbpaste` confirma |
| 9 | `bwcc get "<item>" password --reveal` | imprime o valor (o único caminho que mostra) |
| 10 | `bwcc get <busca ambígua>` | erro listando candidatos, código de saída 2 |
| 11 | `bwcc totp "<item com 2FA>"` | 6 dígitos mascarados; com `--reveal`, o código |
| 12 | `FOO='bw://<item>/password' bwcc run -- sh -c 'echo ${#FOO}'` | imprime o **tamanho**, provando que o valor chegou sem passar pela tela |
| 13 | `bwcc inject -i tpl -o /tmp/t.env` | "escrito em … modo 600"; `ls -l` mostra `-rw-------` |
| 14 | `bwcc inject -i tpl` (sem `-o`) | erro pedindo `-o` |
| 15 | `bwcc add "teste-bwcc" --username u --generate` | item criado, senha **não** exibida; confere no app |
| 16 | `bwcc lock` então `bwcc get "<item>"` | pede Touch ID de novo |
| 17 | `BWCC_BIOMETRICS=0 bwcc unlock` | diálogo de senha mestra em vez de Touch ID |
| 18 | `BWCC_SESSION_TTL=5 bwcc unlock; sleep 6; bwcc list` | sessão expirou, pede Touch ID |
| 19 | app desktop fechado, `bwcc unlock` | avisa "biometria indisponível" e cai na senha mestra |
| 21 | `bwcc doctor \| grep biometrics` | reporta a flag como ligada/desligada/desconhecida, com explicação |
| 22 | `BWCC_BIOMETRICS=force bwcc unlock` (flag `false`) | tenta a ponte IPC mesmo assim; espera até o timeout e cai na senha |
| 23 | `bwcc doctor` em Mac sem sensor | linha `· sensor biométrico AUSENTE` **sem** contar como falha; a flag aparece como "irrelevante sem sensor" |
| 24 | diálogo de senha mestra | mostra a conta e "Pedido por: bwcc (Claude Code)" |
| 25 | `BWCC_SESSION_TTL=0`, desbloquear, reiniciar o Mac, rodar `bwcc list` | pede a senha de novo: a sessão não sobrevive ao restart (boot-time no payload) |
| 26 | config com chave inventada | avisa `chave ignorada no config: X` e segue |
| 27 | disparar desbloqueio com outra janela em foco | o diálogo nasce **na frente** (sem o `activate` ele abre atrás e você espera um prompt invisível) |
| 28 | abrir o diálogo e não responder | desiste em `BWCC_UNLOCK_TIMEOUT` (120s) com "sem resposta", em vez de pendurar o comando |
| 29 | cancelar o diálogo, depois `security find-generic-password -s bwcc-session -w` | **nada** no Keychain: falha de desbloqueio não grava sessão vazia |
| 20 | `security find-generic-password -s bwcc-session -w` | devolve `<timestamp>:<chave>` — confirma onde a sessão mora |

Limpeza: `bwcc lock` e apague o item `teste-bwcc` no app.
