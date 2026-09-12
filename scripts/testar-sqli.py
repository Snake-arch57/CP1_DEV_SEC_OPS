#!/usr/bin/env python3
"""Exercita a pagina de SQL Injection do DVWA local e diz se ela esta vulneravel.

Para que serve: o relatorio do OpenGrep aponta o achado no codigo, mas nao
prova que a correcao funciona na aplicacao. Este script bate na pagina com
uma bateria de payloads e compara quantas linhas cada um devolve -- e a
verificacao que fecha o ciclo achado -> correcao -> evidencia.

Alvo: http://127.0.0.1:8081, o container do proprio laboratorio, em
localhost. Nenhum host de terceiros e tocado (secao 7 do enunciado).

Uso:
    docker compose up -d dvwa
    # abrir http://localhost:8081/setup.php e clicar em Create / Reset Database
    python3 scripts/testar-sqli.py

Saida: 0 = nenhuma injecao vazou a tabela; 2 = vulneravel; 3 = nao deu para
testar (pagina no nivel errado, login falhou).

Para comparar antes e depois da correcao:

    docker exec dvwa cp /var/www/html/vulnerabilities/sqli/source/low.php /tmp/low.orig
    python3 scripts/testar-sqli.py                      # vulneravel
    docker cp patches/fix-sqli.php dvwa:/var/www/html/vulnerabilities/sqli/source/low.php
    python3 scripts/testar-sqli.py                      # corrigido
    docker exec dvwa cp /tmp/low.orig /var/www/html/vulnerabilities/sqli/source/low.php
"""

import http.cookiejar
import re
import sys
import urllib.parse
import urllib.request

BASE = "http://127.0.0.1:8081"
USUARIO = "admin"
SENHA = "password"

PAYLOADS = [
    ("consulta legitima", "1"),
    ("consulta legitima", "3"),
    ("id inexistente", "999"),
    ("injecao classica", "1' OR '1'='1"),
    ("injecao sem digito inicial", "' OR '1'='1"),
    ("injecao com comentario", "1' OR 1=1 -- "),
    ("union select", "1' UNION SELECT user, password FROM users -- "),
    ("aspas soltas", "'"),
]

cj = http.cookiejar.CookieJar()
op = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))
op.addheaders = [("User-Agent", "cp1-lab-test")]


def get(caminho):
    with op.open(BASE + caminho, timeout=30) as r:
        return r.read().decode("utf-8", "replace")


def post(caminho, dados):
    corpo = urllib.parse.urlencode(dados).encode()
    with op.open(BASE + caminho, corpo, timeout=60) as r:
        return r.read().decode("utf-8", "replace")


def token(html):
    """O DVWA poe um user_token (anti-CSRF) nos formularios."""
    m = re.search(r"name=['\"]user_token['\"]\s+value=['\"]([^'\"]+)", html)
    return m.group(1) if m else None


def set_cookie(nome, valor):
    cj.set_cookie(http.cookiejar.Cookie(
        version=0, name=nome, value=valor, port=None, port_specified=False,
        domain="127.0.0.1", domain_specified=False, domain_initial_dot=False,
        path="/", path_specified=True, secure=False, expires=None,
        discard=True, comment=None, comment_url=None, rest={}, rfc2109=False))


def main():
    try:
        html = get("/login.php")
    except Exception as e:
        print("nao consegui falar com %s (%s)." % (BASE, e))
        print("Suba o ambiente: docker compose up -d dvwa")
        return 3

    dados = {"username": USUARIO, "password": SENHA, "Login": "Login"}
    t = token(html)
    if t:
        dados["user_token"] = t
    post("/login.php", dados)

    if "Logout" not in get("/index.php"):
        print("login falhou. O banco foi inicializado em /setup.php?")
        return 3

    # O nivel de seguranca vem do cookie `security`. Sem ele, o DVWA cai em
    # impossible.php -- que ja usa prepared statement e daria "protegido"
    # sem patch nenhum. Esta e a armadilha que mais atrapalha este teste.
    set_cookie("security", "low")

    pagina = get("/vulnerabilities/sqli/")
    if "user_token" in pagina:
        print("a pagina esta em impossible.php, nao em low.php -- abortando.")
        print("Ajuste o nivel em /security.php para Low.")
        return 3
    print("nivel confirmado: low.php (formulario sem user_token)")
    print()

    print("%-30s %-46s %s" % ("caso", "payload", "linhas"))
    print("-" * 88)
    grave = False
    for nome, p in PAYLOADS:
        html = get("/vulnerabilities/sqli/?id=%s&Submit=Submit"
                   % urllib.parse.quote(p, safe=""))
        linhas = re.findall(r"First name:\s*([^<]+)", html)
        marca = ""
        if len(linhas) >= 5:
            marca += "  <-- TABELA INTEIRA"
            grave = True
        if "error in your SQL syntax" in html:
            marca += "  <-- ERRO DE SQL VAZANDO"
            grave = True
        print("%-30s %-46s %d%s" % (nome, repr(p), len(linhas), marca))

    print()
    if grave:
        print("VEREDITO: VULNERAVEL — alguma injecao devolveu a tabela"
              " inteira ou vazou erro de SQL.")
        return 2

    print("VEREDITO: nenhuma injecao devolveu a tabela nem vazou erro de SQL.")
    print()
    print("Nota: com o prepared statement, `1' OR '1'='1` ainda devolve 1"
          " linha. Nao e injecao:")
    print("o MySQL compara a coluna user_id (inteiro) com a string recebida e"
          " converte o prefixo")
    print("numerico dela para 1, achando o usuario 1. O dado nunca foi"
          " interpretado como SQL —")
    print("`' OR '1'='1`, sem digito no inicio, devolve 0.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
