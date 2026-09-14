# Roteiro do vídeo de plano B

Requisito 6 da seção 5.3: *"gravação em vídeo (5–8 min) ou GIF/screenshots da
execução completa, para o caso de falha de rede ou ambiente no dia. Sem plano
B, o risco é do grupo."* Vale **3 pts** na rubrica.

A finalidade é operacional: se a rede da instituição cair, se o Docker Hub
estiver fora ou se a máquina travar, alguém passa o vídeo e a apresentação
continua. **Grave pensando em substituir a demonstração ao vivo**, não em
ilustrá-la.

---

## Antes de apertar o rec

Deixe tudo pronto. Tempo de download não cabe em 8 minutos.

```bash
# imagens ja em cache
docker pull vulnerables/web-dvwa:latest
docker pull hysnsec/nikto:latest
docker compose build opengrep

# alvo ja clonado
bash scripts/preparar-alvo.sh
```

Abra em abas separadas, prontas para alternar:

1. Terminal na raiz do repositório
2. Navegador em `http://localhost:8081`
3. A execução **vermelha**: <https://github.com/Snake-arch57/CP1_DEV_SEC_OPS/actions/runs/34763310159>
4. A execução **verde**: <https://github.com/Snake-arch57/CP1_DEV_SEC_OPS/actions/runs/34762690575>

Aumente a fonte do terminal. O que é legível na sua tela não é legível num
projetor.

---

## As cenas

### 0:00–0:30 · Abertura

Mostre o `README.md` aberto e diga, em uma frase:

> "Grupo 1. Quatro ferramentas: OpenGrep para SAST, Nikto para DAST, Terrascan
> para IaC e Snyk para SCA. O laboratório usa as duas primeiras contra o DVWA."

### 0:30–1:15 · Passo 0 — preparar

```bash
git clone https://github.com/Snake-arch57/CP1_DEV_SEC_OPS.git
cd CP1_DEV_SEC_OPS
docker compose pull
docker compose build
bash scripts/preparar-alvo.sh
```

Termine com as duas verificações, e **mostre as duas**:

```bash
docker images | grep -E "dvwa|opengrep|nikto"
ls targets/dvwa/vulnerabilities/sqli/source/
```

Diga por que a segunda existe: o SAST lê **código-fonte**, que não vem no
repositório.

### 1:15–2:00 · Passo 1 — subir o ambiente

```bash
docker compose up -d dvwa
```

No navegador: `http://localhost:8081/setup.php` → **Create / Reset Database** →
login `admin` / `password` → *DVWA Security* → **Low**.

Uma frase que vale a pena dizer aqui:

> "O DVWA é deliberadamente vulnerável, está na lista de alvos autorizados do
> enunciado, e sobe só em `127.0.0.1` — não fica exposto na rede."

### 2:00–3:15 · Passo 2 — OpenGrep (SAST)

```bash
docker compose run --rm opengrep \
  --config=p/php --config=p/owasp-top-ten \
  --sarif --output=/reports/opengrep-dvwa.sarif /src
```

Espere aparecer a linha final e **deixe na tela**:

```
Ran 126 rules on 250 files: 58 findings.
```

### 3:15–4:15 · Passo 3 — achar o SQL Injection

Abra o `reports/opengrep-dvwa.sarif` no VS Code, ou busque direto:

```bash
grep -n "tainted-sql-string" reports/opengrep-dvwa.sarif | head -3
```

**Mostre na tela o achado que a turma vai procurar:**

```
vulnerabilities/sqli/source/low.php:10
vulnerabilities/sqli/source/low.php:31
```

Essa é a cena mais importante do vídeo. É ela que responde a pergunta de
verificação nº 1.

Diga por que é *taint analysis* e não busca por padrão: a regra rastreia o
`$id` desde o `$_REQUEST` até a string da query.

### 4:15–5:15 · Passo 4 — Nikto (DAST)

```bash
docker compose run --rm nikto -h http://dvwa:80 -Format txt -o /reports/nikto-dvwa.txt
```

Destaque, quando aparecerem:

```
+ /config/: Directory indexing found.
+ /docs/:   Directory indexing found.
```

E diga o contraste, que é o ponto do laboratório inteiro:

> "Isso não está no código PHP. É configuração do Apache. Nenhum SAST
> acusaria — só o DAST, batendo na aplicação em execução."

### 5:15–6:45 · Passo 5 — o gate decide o deploy

Alterne para as duas abas do GitHub Actions já abertas.

**Vermelho** — mostre o job `security-gate` com os achados nomeados:

```
OpenGrep: 2 achado(s) HIGH em vulnerabilities/sqli/ (de 25 no DVWA inteiro)
Nikto: 2 achado(s) HIGH
SAST=2  DAST=2  TOTAL=4
Gate REPROVADO — Deploy bloqueado.
```

Aponte a barra lateral: `config-do-deploy` e `deploy` aparecem **pulados**, não
como falha. O deploy não quebrou — foi bloqueado.

**Verde** — a mesma tela, com `TOTAL=0`, `Gate APROVADO` e os seis jobs verdes,
com o `deploy` executado.

> "Mesma pipeline, mesmo código. Muda só se as correções foram aplicadas antes
> de medir."

### 6:45–7:15 · Passo 6 — as respostas

Mostre as duas perguntas de verificação do `LAB.md` e responda na tela:

1. **2** achados HIGH em `vulnerabilities/sqli/source/low.php`
2. **CWE-89**, e o Nikto reportou o `X-Frame-Options` ausente

### 7:15–7:30 · Passo 7 — encerrar

```bash
docker compose down -v
```

---

## Os quatro pontos que não podem faltar

Se o vídeo for assistido no lugar da demonstração, o avaliador precisa ver:

1. ✅ O **SQL Injection** encontrado no relatório do OpenGrep
2. ✅ O **Directory indexing** encontrado pelo Nikto
3. ✅ O gate **vermelho bloqueando** e o **verde liberando** o deploy
4. ✅ As **respostas das 2 perguntas** de verificação

Sem esses quatro, o vídeo ilustra mas não substitui.

---

## Como caber em 8 minutos

- **Não espere download.** As imagens já estão em cache; o `pull` vira uma
  linha de "already exists"
- **Acelere 4× ou 8×** os trechos de build, com uma legenda dizendo o tempo
  real
- **Não rode o pipeline durante a gravação.** As duas execuções já existem —
  basta abrir
- Corte pausas e digitação hesitante

## Ferramenta e formato

**OBS Studio** (gratuito) ou a gravação nativa do Windows (`Win + G`).

**Narre.** Mesmo baixinho, mesmo lendo. Vídeo mudo de terminal é difícil de
acompanhar, e a rubrica avalia clareza e didática.

Salve como `evidencias/plano-b.mp4`.

> Se passar de 100 MB, o GitHub recusa o arquivo. Nesse caso suba no YouTube
> como **não listado** e ponha o link no `evidencias/README.md` — o Anexo B
> pede o plano B disponível, não necessariamente o arquivo versionado.
