# CLAUDE.md

Trabalho acadêmico avaliado por rubrica. O repositório sobe o **DVWA**, uma
aplicação deliberadamente vulnerável — o que torna duas regras absolutas:

1. **Nenhuma porta do `docker-compose.yml` sai de `127.0.0.1`.** Expor o DVWA
   é nota zero no trabalho (seção 7 do enunciado). Verifique com
   `bash scripts/verificar-escopo.sh`.
2. **Nenhuma varredura contra alvo fora da lista autorizada** (DVWA,
   TerraGoat, NodeGoat — todos locais, em container).

E três hábitos que o enunciado cobra:

3. Todo número afirmado em documento tem de sair de um relatório de
   `reports/` — confira com `python3 scripts/resumir-achados.py`.
4. Contribuição de IA é declarada em `USO-DE-IA.md`.
5. Mudança de código é registrada em `VIBE.md`.

O contexto completo — as quatro ferramentas, como o gate decide, onde cada
coisa está, o que ainda falta — fica em:

@.claude/contexto.md
