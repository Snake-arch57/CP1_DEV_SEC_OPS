#!/usr/bin/env python3
"""Resume os relatorios de reports/ numa tabela unica.

Para que serve: a secao 6(e) do enunciado pede, para cada uma das 4
ferramentas, o total de achados, o tempo de execucao no projeto testado e a
taxa de falsos positivos observada. Contar isso a mao em quatro formatos
diferentes (SARIF, JSON do Nikto, JSON do Terrascan, JSON do Snyk) e onde o
numero do documento acaba divergindo do relatorio versionado.

Este script le os arquivos que existirem e imprime os totais. O que ele NAO
faz -- de proposito -- e decidir o que e falso positivo: isso e analise do
grupo, vale 8 pontos na rubrica e nenhum script tem como inferir.

Uso:
    python3 scripts/resumir-achados.py
    python3 scripts/resumir-achados.py --md reports/resumo-achados.md

Tempo de execucao: se reports/tempos.txt existir (gerado por
scripts/rodar-sca-iac.sh), a ultima medicao de cada ferramenta entra na
tabela.
"""

import argparse
import json
import os
import re
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPORTS = os.path.join(RAIZ, "reports")

# Mesmo escopo que o gate do workflow conta.
ESCOPO_SAST = "vulnerabilities/sqli/"

# Mesma lista do job security-gate. Se uma mudar, a outra tem de mudar --
# estao ligadas pelo comentario nos dois arquivos.
NIKTO_HIGH = r"phpinfo|/admin|Directory indexing|backup|/\.git/|test/|Default account"


def carregar(nome):
    caminho = os.path.join(REPORTS, nome)
    if not os.path.exists(caminho) or os.path.getsize(caminho) == 0:
        return None
    with open(caminho, encoding="utf-8", errors="replace") as f:
        try:
            return json.load(f)
        except json.JSONDecodeError as e:
            print(f"aviso: {nome} nao e JSON valido ({e})", file=sys.stderr)
            return None


def tempos():
    """Ultima medicao de cada ferramenta, de reports/tempos.txt (TSV)."""
    caminho = os.path.join(REPORTS, "tempos.txt")
    medidos = {}
    if os.path.exists(caminho):
        with open(caminho, encoding="utf-8") as f:
            for linha in f:
                partes = linha.strip().split("\t")
                if len(partes) >= 2:
                    medidos[partes[0]] = partes[1]
    return medidos


def opengrep():
    """SARIF: a severidade fica na definicao da regra, nao no achado.

    E o mesmo detalhe que quebrou o gate na primeira versao -- filtrar pelo
    campo .level de cada result devolve zero, porque o OpenGrep nao escreve
    esse campo: ele fica em tool.driver.rules[].defaultConfiguration.level e
    o achado herda.
    """
    d = carregar("opengrep-dvwa.sarif")
    if d is None:
        return None

    niveis = {"error": 0, "warning": 0, "note": 0}
    no_escopo = 0
    total = 0

    for run in d.get("runs", []):
        mapa = {
            r.get("id"): r.get("defaultConfiguration", {}).get("level")
            for r in run.get("tool", {}).get("driver", {}).get("rules", [])
        }
        for res in run.get("results", []):
            total += 1
            nivel = res.get("level") or mapa.get(res.get("ruleId")) or "warning"
            niveis[nivel] = niveis.get(nivel, 0) + 1
            locais = res.get("locations") or [{}]
            uri = (
                locais[0]
                .get("physicalLocation", {})
                .get("artifactLocation", {})
                .get("uri", "")
            )
            if nivel == "error" and ESCOPO_SAST in uri:
                no_escopo += 1

    return {
        "total": total,
        "high": niveis.get("error", 0),
        "medium": niveis.get("warning", 0),
        "low": niveis.get("note", 0),
        "obs": f"{no_escopo} HIGH em {ESCOPO_SAST} (escopo do gate)",
    }


def nikto():
    """Nikto nao emite severidade: o corte HIGH e a lista do grupo."""
    d = carregar("nikto-dvwa.json")
    if d is None:
        return None

    achados = []

    def andar(o):
        if isinstance(o, dict):
            if "msg" in o:
                achados.append((o.get("url", ""), o["msg"]))
            for v in o.values():
                andar(v)
        elif isinstance(o, list):
            for v in o:
                andar(v)

    andar(d)
    rx = re.compile(NIKTO_HIGH, re.I)
    # url + msg, igual ao gate: no Nikto 2.5.0 o caminho fica so em .url.
    high = sum(1 for url, msg in achados if rx.search((url or "") + " " + msg))

    return {
        "total": len(achados),
        "high": high,
        "medium": len(achados) - high,
        "low": 0,
        "obs": "sem severidade nativa; HIGH = lista NIKTO_HIGH",
    }


def terrascan():
    d = carregar("terrascan-terragoat.json")
    if d is None:
        return None

    violacoes = (d.get("results") or {}).get("violations") or []
    conta = {"high": 0, "medium": 0, "low": 0}
    for v in violacoes:
        sev = str(v.get("severity", "")).lower()
        if sev in conta:
            conta[sev] += 1

    return {
        "total": len(violacoes),
        "high": conta["high"],
        "medium": conta["medium"],
        "low": conta["low"],
        "obs": "alvo: TerraGoat (Terraform)",
    }


def snyk():
    d = carregar("snyk-nodegoat.json")
    if d is None:
        return None

    # Snyk devolve objeto para um projeto e lista para varios.
    projetos = d if isinstance(d, list) else [d]
    conta = {"critical": 0, "high": 0, "medium": 0, "low": 0}
    total = 0
    for p in projetos:
        for v in p.get("vulnerabilities") or []:
            total += 1
            sev = str(v.get("severity", "")).lower()
            if sev in conta:
                conta[sev] += 1

    return {
        "total": total,
        # Critical entra em HIGH: o gate do enunciado quebra em HIGH ou
        # CRITICAL, entao as duas contam do mesmo lado da linha.
        "high": conta["critical"] + conta["high"],
        "medium": conta["medium"],
        "low": conta["low"],
        "obs": f"alvo: NodeGoat (Node.js); {conta['critical']} CRITICAL",
    }


FERRAMENTAS = [
    ("OpenGrep", "SAST", "opengrep", opengrep, "reports/opengrep-dvwa.sarif"),
    ("Nikto", "DAST", "nikto", nikto, "reports/nikto-dvwa.json"),
    ("Terrascan", "IaC", "terrascan", terrascan, "reports/terrascan-terragoat.json"),
    ("Snyk Open Source", "SCA", "snyk", snyk, "reports/snyk-nodegoat.json"),
]


def montar_tabela():
    medidos = tempos()
    linhas = []
    faltando = []

    for nome, cat, chave, fn, arquivo in FERRAMENTAS:
        r = fn()
        tempo = medidos.get(chave, "-")
        if r is None:
            faltando.append((nome, arquivo))
            linhas.append(
                [nome, cat, "**nao executado**", "-", "-", "-", tempo,
                 f"falta {arquivo}"]
            )
        else:
            linhas.append(
                [nome, cat, str(r["total"]), str(r["high"]), str(r["medium"]),
                 str(r["low"]), tempo, r["obs"]]
            )

    return linhas, faltando


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--md", metavar="ARQUIVO",
                    help="tambem grava a tabela em Markdown neste caminho")
    args = ap.parse_args()

    linhas, faltando = montar_tabela()
    cab = ["Ferramenta", "Cat.", "Achados", "HIGH", "MEDIUM", "LOW",
           "Tempo (s)", "Observacao"]

    md = ["| " + " | ".join(cab) + " |",
          "|" + "|".join(["---"] * len(cab)) + "|"]
    md += ["| " + " | ".join(l) + " |" for l in linhas]

    md.append("")
    md.append("A taxa de falsos positivos NAO esta nesta tabela: e analise do")
    md.append("grupo, nao contagem automatica (rubrica: analise critica propria).")

    saida = "\n".join(md)
    print(saida)

    if faltando:
        print("", file=sys.stderr)
        for nome, arquivo in faltando:
            print(f"sem evidencia de execucao: {nome} ({arquivo})", file=sys.stderr)
        print("Rode scripts/rodar-sca-iac.sh para gerar os que faltam.",
              file=sys.stderr)

    if args.md:
        os.makedirs(os.path.dirname(os.path.abspath(args.md)), exist_ok=True)
        with open(args.md, "w", encoding="utf-8") as f:
            f.write("# Achados por ferramenta\n\n")
            f.write("Gerado por `scripts/resumir-achados.py` a partir dos\n")
            f.write("relatorios em `reports/`. Nao editar a mao: rode o\n")
            f.write("script de novo.\n\n")
            f.write(saida + "\n")
        print(f"\ngravado em {args.md}", file=sys.stderr)

    # Sai 1 quando falta evidencia, para servir de checagem em pipeline.
    return 1 if faltando else 0


if __name__ == "__main__":
    sys.exit(main())
