# .claude/ — pasta de apoio ao Claude Code

Contexto que o Claude Code carrega ao abrir este repositório, para não ter de
redescobrir as regras do trabalho a cada sessão.

| Arquivo | O que é |
|---|---|
| [`contexto.md`](contexto.md) | as regras do trabalho, as 4 ferramentas, como o gate decide, onde cada coisa está |
| `settings.local.json` | preferências pessoais de quem usa a ferramenta — **não versionado** (está no `.gitignore`) |

O [`../CLAUDE.md`](../CLAUDE.md) na raiz é o arquivo que o Claude Code lê
primeiro; ele traz as regras absolutas e importa o `contexto.md` com
`@.claude/contexto.md`.

O registro do que foi feito no código fica em [`../VIBE.md`](../VIBE.md), não
aqui — é documento do grupo, não da ferramenta.

**Mantenham o `contexto.md` atualizado.** Ele não conta para a nota, mas
contexto errado faz a IA propor mudança errada, e aí o erro chega no que conta.
