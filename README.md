# claude-code-bitwarden

Dá ao [Claude Code](https://claude.com/claude-code) acesso ao seu cofre do
**Bitwarden** no macOS — do mesmo jeito que o CLI `op` dá acesso ao 1Password:
desbloqueio pelo **app desktop com Touch ID**, sessão em cache no **Keychain**, e
**nenhum segredo impresso na tela** sem você pedir.

> **English:** a Claude Code plugin + `bwcc` CLI wrapper that lets the agent
> search and use your Bitwarden vault on macOS. Unlock happens through the
> Bitwarden desktop app (Touch ID); the session key is cached in the macOS
> Keychain with a sliding TTL; secret values are masked by default and are
> normally handed to a child process (`bwcc run`) or a file (`bwcc inject`)
> instead of being printed — so they never reach the model transcript. Docs
> below are in Portuguese; `bwcc --help` is self-documenting.

```
você: "roda a migração do banco"
                │
            Claude Code
                │  bwcc run -- npm run migrate
                ▼
              bwcc ──── Keychain (sessão, TTL 15 min)
                │
                │  bw unlock (pty)
                ▼
      app Bitwarden desktop ──► Touch ID
                │
                ▼
          cofre Bitwarden
```

O segredo vai para o ambiente do `npm` e **não** para a transcrição da conversa.

## Por que isso existe

O 1Password tem integração de primeira classe com CLI e app desktop, então um
agente consegue ler o cofre com biometria e sem senha digitada. O Bitwarden
chegou nesse ponto só agora: o CLI oficial **2026.10** passou a tentar o
desbloqueio biométrico pelo app desktop quando `bw unlock` roda interativamente.

Faltavam três coisas para isso funcionar dentro do Claude Code:

1. **O shell do agente não tem tty.** O `bw` só tenta a biometria no caminho
   interativo. O `bwcc` roda o unlock dentro de um pty (`script(1)`) e extrai a
   chave de sessão da saída.
2. **A sessão não sobrevive entre comandos.** `BW_SESSION` morre junto com o
   shell, e um agente roda cada comando em um shell novo — seriam dezenas de
   prompts de Touch ID. O `bwcc` guarda a sessão no Keychain com TTL deslizante.
3. **Tudo que o agente imprime sai da sua máquina.** O `bwcc` mascara segredos
   por padrão e oferece caminhos em que o valor nunca é exibido.

## Requisitos

| | |
|---|---|
| macOS | Keychain, Touch ID, `pbcopy`, `osascript` |
| [Bitwarden desktop](https://bitwarden.com/download/) | **2026.9.0+** com "desbloqueio com Touch ID" ligado (sem isso, cai na senha mestra) |
| CLI `bw` | **2026.10+** — `npm install -g @bitwarden/cli` |
| `jq` | `brew install jq` (já vem no macOS 15+) |
| bash | 3.2, o que já vem no sistema |

## Instalação

```bash
git clone https://github.com/ManecoGomes/claude-code-bitwarden
cd claude-code-bitwarden
./install.sh          # instala dependências que faltarem e linka o bwcc
bw login              # uma vez só — tem 2FA, é você que digita
bwcc doctor           # confere CLI, app, ponte IPC, Keychain e login
```

> **O `bw login` tem que ser num terminal de verdade** (Terminal.app, iTerm).
> Não funciona por agente nem pelo prefixo `!` do Claude Code: o CLI usa readline
> e aborta com `ERR_USE_AFTER_CLOSE` quando não tem tty próprio. Quem precisa de
> login sem prompt usa a API key pessoal do cofre web:
> `BW_CLIENTID=... BW_CLIENTSECRET=... bw login --apikey`.
> Isso é só o login: o **desbloqueio** depois é por Touch ID, e disso o `bwcc` cuida.

E, dentro do Claude Code:

```
/plugin marketplace add ManecoGomes/claude-code-bitwarden
/plugin install bitwarden@claude-code-bitwarden
```

O plugin traz a skill `bitwarden` (o Claude passa a saber usar o cofre sozinho,
sem você explicar) e os comandos `/bitwarden` e `/bw-doctor`.

## Uso

### Descobrir

```bash
bwcc list github            # nome, usuário, domínio e id dos itens que casam
bwcc fields "GitHub"        # que campos o item tem — sem os valores
```

Busca ambígua **não** é resolvida por chute: o `bwcc` lista os candidatos e sai
com erro.

### Ler

```bash
bwcc get "GitHub" username          # campo aberto → imprime
bwcc get "GitHub" password          # campo secreto → •••••••• (12 chars, sha256:a1b2c3d4)
bwcc copy "GitHub" password         # → área de transferência, nada na tela
bwcc totp "GitHub"                  # código 2FA
bwcc get "GitHub" password --reveal # imprime de fato (só quando você quer ver)
```

A máscara mostra tamanho e um fingerprint SHA-256 de 8 caracteres: dá pra
conferir *qual* segredo é, e comparar dois, sem expor nenhum.

### Usar sem exibir

Referência: `bw://<item>/<campo>` — campo omitido quer dizer `password`.

```bash
# segredo no ambiente de um comando
DATABASE_URL='bw://Supabase MGE/connection_string' bwcc run -- npm run migrate

# template → arquivo real (modo 600)
bwcc inject -i .env.example -o .env     # troca {{ bw://item/campo }}

# arquivo de referências → ambiente
bwcc run -e .env.refs -- ./deploy.sh
```

`.env.example` versionável, sem segredo nenhum:

```env
DATABASE_URL={{ bw://Supabase MGE/connection_string }}
STRIPE_KEY={{ bw://Stripe/secret_key }}
```

### Escrever

```bash
bwcc gen --length 32 --words                 # gera senha ou passphrase
bwcc add "Serviço novo" --username eu@ex.com --uri https://ex.com --generate
printf '%s' "$SENHA" | bwcc add "Serviço" --username u --password-stdin
```

Senha nunca vai em argumento de linha de comando (`argv` é visível a outros
processos) — só por stdin ou gerada internamente.

**Não existe `delete` nem `edit`.** É decisão de projeto: um agente não apaga
seu cofre. Essas operações são no app do Bitwarden.

### Sessão

```bash
bwcc unlock    # Touch ID agora e guarda a sessão
bwcc status    # estado do CLI, do app, da conta e da sessão
bwcc lock      # trava e apaga a sessão do cache
bwcc sync      # sincroniza antes de ler algo que mudou agora
```

## Configuração

| Variável | Padrão | O que faz |
|---|---|---|
| `BWCC_SESSION_TTL` | `900` | validade da sessão em cache, em segundos (`0` = não expira) |
| `BWCC_SESSION_STORE` | `keychain` | `keychain`, `file` (0600 em `~/.local/state/bwcc`) ou `none` |
| `BWCC_REVEAL` | `never` | `always` faz o `get` imprimir segredo por padrão |
| `BWCC_BIOMETRICS` | `1` | `0` pula a biometria e vai direto na senha mestra |
| `BWCC_UNLOCK_TIMEOUT` | `90` | segundos de espera pelo Touch ID |
| `BWCC_BW_BIN` | — | caminho do `bw` quando não está no `PATH` |
| `BWCC_KEYCHAIN_SERVICE` | `bwcc-session` | nome do item no Keychain |

## Comparação

| | `op` (1Password) | **bwcc** | MCP oficial do Bitwarden |
|---|---|---|---|
| desbloqueio | app desktop + Touch ID | app desktop + Touch ID, com queda pra senha mestra | `BW_SESSION` fixo na config, ou diálogo de senha |
| sessão entre comandos | gerenciada pelo app | Keychain, TTL deslizante | variável de ambiente estática |
| segredo mascarado por padrão | não | **sim** | não |
| injeção em processo/arquivo | `op run` / `op inject` | `bwcc run` / `bwcc inject` | não |
| escrita no cofre | sim | criar item apenas | criar, editar e apagar |
| onde o token fica | — | Keychain | arquivo de configuração do cliente MCP |

O [MCP oficial](https://github.com/bitwarden/mcp-server) é complementar: se você
quiser as ferramentas MCP, use `bwcc unlock` e exporte a sessão pra ele em vez de
deixar um token colado num JSON de configuração.

## Segurança

Leia [SECURITY.md](SECURITY.md) — tem o modelo de ameaça inteiro, incluindo o
que esta ferramenta **não** protege. Em resumo:

- a senha mestra nunca passa por `argv`, só por variável de ambiente descartável;
- a chave de sessão nunca passa por `argv` — vai por ambiente para o `bw`;
- a sessão em cache fica no Keychain (criptografado em repouso), com TTL;
- segredo não é impresso a menos que você peça (`--reveal`) ou configure
  `BWCC_REVEAL=always`;
- `inject` escreve com modo 600 e se recusa a mandar segredo pra stdout sem
  `--stdout` explícito;
- **um agente de IA com acesso ao seu cofre pode ler suas senhas.** O desenho
  aqui reduz o que vaza por acidente; não transforma isso em risco zero.

## Testes

```bash
./tests/test-bwcc.sh       # 36 testes, offline, sem conta e sem rede
```

Os caminhos que exigem cofre de verdade (Touch ID, leitura, injeção) estão em
[docs/MANUAL-TESTS.md](docs/MANUAL-TESTS.md).

## Licença

MIT — veja [LICENSE](LICENSE).
