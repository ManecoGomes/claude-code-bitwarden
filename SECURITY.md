# Segurança

## Modelo de ameaça

O `bwcc` resolve um problema específico: **um agente de IA com acesso ao seu
cofre vaza segredo por descuido** — imprimindo na tela, colocando em log, em
comentário de código, em mensagem de commit. Tudo que o agente imprime vai pra
transcrição da conversa e, com ela, sai da sua máquina.

Então o padrão aqui é *não mostrar*, e oferecer caminhos onde o valor nunca
aparece: `bwcc copy` (área de transferência), `bwcc run` (ambiente do processo
filho), `bwcc inject` (arquivo com modo 600).

### O que é protegido

| Risco | Como |
|---|---|
| segredo na transcrição do modelo | mascarado por padrão; `--reveal` é explícito |
| senha mestra visível em `ps` | nunca vai em `argv`; só por env var descartável (`--passwordenv`) |
| chave de sessão visível em `ps` | nunca vai em `argv`; passa por `BW_SESSION` no ambiente do filho |
| sessão em texto claro no disco | fica no Keychain do macOS, criptografado em repouso |
| sessão viva pra sempre | TTL deslizante (15 min por padrão); `bwcc lock` encerra na hora |
| agente apagar o cofre | não existe `delete` nem `edit` — só leitura e criação |
| `.env` gerado com permissão frouxa | `inject` escreve `chmod 600` |
| segredo despejado em stdout por engano | `inject` exige `-o arquivo` ou `--stdout` explícito |
| escolher o item errado em busca ambígua | erro com a lista de candidatos, nunca um chute |

### O que NÃO é protegido

Seja honesto com você mesmo sobre isto:

1. **O agente consegue ler suas senhas.** Se ele pode rodar `bwcc copy`, pode
   rodar `bwcc get --reveal`. A proteção é contra *acidente*, não contra um
   agente determinado nem contra prompt injection que peça o segredo em tela.
   Se isso te incomoda, o lugar de barrar é a camada de permissão do Claude Code
   (veja abaixo).
2. **Área de transferência é global.** `bwcc copy` deixa o segredo disponível
   para qualquer app rodando na sua sessão, até você copiar outra coisa.
3. **O ambiente do processo filho é legível** pelo próprio processo e por
   qualquer coisa que ele execute. `bwcc run` tira o segredo da tela, não do
   processo.
4. **Malware rodando como você** lê o Keychain do seu login, o cofre destravado e
   a memória do `bw`. Nenhum wrapper resolve isso.
5. **A biometria é do app desktop.** Quem decide se o Touch ID basta é o
   Bitwarden, não o `bwcc`.

### Barrando por permissão (recomendado)

Pra impedir que o agente revele segredo sem você aprovar na hora, negue só o
caminho de revelação em `.claude/settings.json`:

```json
{
  "permissions": {
    "deny": ["Bash(bwcc get:*--reveal*)", "Bash(bwcc * --reveal)"],
    "allow": ["Bash(bwcc list:*)", "Bash(bwcc fields:*)", "Bash(bwcc copy:*)"]
  }
}
```

Assim `list`, `fields` e `copy` rodam sem atrito e qualquer `--reveal` precisa
passar por você.

## Decisões de projeto

- **Bash, sem dependência fora do sistema.** Uma ferramenta que toca o seu cofre
  tem que ser auditável numa sentada: ~800 linhas que você consegue ler. Só
  `bw`, `jq` e utilitários do macOS.
- **Nenhum segredo em disco além do Keychain.** Não há cache de item, de busca,
  nem log.
- **Sem telemetria e sem rede própria.** O único tráfego é o do `bw` oficial
  falando com o servidor do Bitwarden.
- **TTL deslizante em vez de sessão infinita.** Um agente roda vários comandos
  em sequência; um Touch ID por janela de 15 minutos é o equilíbrio entre
  atrito e exposição.

## Reportar vulnerabilidade

Abra uma *security advisory* privada em
<https://github.com/ManecoGomes/claude-code-bitwarden/security/advisories/new>,
não um issue público.

Se a falha for do Bitwarden (CLI, app desktop ou a ponte IPC), reporte direto a
eles: <https://bitwarden.com/contact/>.
