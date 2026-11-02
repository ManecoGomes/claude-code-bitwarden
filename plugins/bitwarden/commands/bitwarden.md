---
description: Acessa o cofre Bitwarden (buscar, copiar, injetar segredos) via bwcc
---

Use a skill `bitwarden` para atender este pedido: $ARGUMENTS

Sem argumentos, mostre o estado atual com `bwcc status` e um resumo curto do que
você consegue fazer (buscar item, copiar segredo pra área de transferência,
rodar comando com credencial, preencher `.env`, criar item novo).

Lembre da regra central: segredo não vai pra tela sem o usuário pedir — prefira
`bwcc copy`, `bwcc run` e `bwcc inject`.
