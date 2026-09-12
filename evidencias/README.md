# Evidências

Exigido pelo requisito 5 da seção 5.3 e pelo Anexo B do enunciado.

| Arquivo | O que é |
|---|---|
| [`execucao-local-2026-09-12.md`](execucao-local-2026-09-12.md) | execução local completa: o gate nas duas pontas, tempos medidos das ferramentas, e a prova de que as duas correções funcionam na aplicação no ar |
| _falta_ | **print do build vermelho** do GitHub Actions (`Run workflow` com `remediacao` desmarcada) |
| _falta_ | **print do build verde** (push na `main`) |

Os prints saem da aba **Summary** da execução, não do log: o job
`security-gate` imprime ali a tabela de contagem por ferramenta, com o total e
o veredito. É o que se lê num print.
