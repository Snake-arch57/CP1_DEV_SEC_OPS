# Achados por ferramenta

Gerado por `scripts/resumir-achados.py` a partir dos
relatorios em `reports/`. Nao editar a mao: rode o
script de novo.

| Ferramenta | Cat. | Achados | HIGH | MEDIUM | LOW | Tempo (s) | Observacao |
|---|---|---|---|---|---|---|---|
| OpenGrep | SAST | 58 | 25 | 33 | 0 | 31 | 2 HIGH em vulnerabilities/sqli/ (escopo do gate) |
| Nikto | DAST | 15 | 2 | 13 | 0 | 6 | sem severidade nativa; HIGH = lista NIKTO_HIGH |
| Terrascan | IaC | 67 | 35 | 27 | 5 | 11 | alvo: TerraGoat (Terraform) |
| Snyk Open Source | SCA | 371 | 170 | 68 | 133 | 10 | alvo: NodeGoat (Node.js); 0 CRITICAL |

A taxa de falsos positivos NAO esta nesta tabela: e analise do
grupo, nao contagem automatica (rubrica: analise critica propria).
