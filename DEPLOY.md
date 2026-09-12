# Deploy automático na VM Azure — passo a passo

Configuração do job `deploy` do workflow `.github/workflows/security-gate.yml`.
Faça na ordem. Os passos 1 a 4 são feitos **uma única vez**.

> **Antes de começar, entenda o comportamento esperado:** o job `deploy` só roda
> se o job `security-gate` passar. Enquanto existirem achados HIGH, **o deploy
> não acontece** — esse é o desenho correto, não um defeito.
>
> Hoje o pipeline aplica as duas correções (`patches/fix-sqli.php` e o
> override de hardening) em todo `push` e `pull_request`, então o gate passa e
> o deploy roda. O **build vermelho** exigido pelo requisito 5 se reproduz sob
> demanda, em *Actions > security-gate > Run workflow*, **desmarcando**
> `remediacao`.

---

## 1. Preparar a VM

Conecte na VM e instale Docker, Compose e Git.

```bash
ssh usuario@<ip-da-vm>

sudo apt-get update
sudo apt-get install -y ca-certificates curl git

# Repositório oficial do Docker
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg \
     -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
     docker-buildx-plugin docker-compose-plugin
```

> Se o `apt-get update` reclamar que não existe repositório para o codinome da
> sua distro (o Docker costuma demorar a publicar para versões muito novas),
> troque `$(. /etc/os-release && echo "$VERSION_CODENAME")` por `bookworm` na
> linha do `tee` e repita.

Dê ao seu usuário permissão de usar Docker sem `sudo`:

```bash
sudo usermod -aG docker "$(id -un)"
```

**Encerre a sessão SSH e reconecte** — a mudança de grupo só vale em sessão
nova. Confirme:

```bash
docker run --rm hello-world
```

Crie o diretório do projeto **com dono correto**. Isso é o que permite ao
workflow rodar sem `sudo` sem senha:

```bash
sudo mkdir -p /opt/CP1_DEV_SEC_OPS
sudo chown -R "$(id -un)":"$(id -un)" /opt/CP1_DEV_SEC_OPS
```

---

## 2. Criar uma chave SSH dedicada ao deploy

Gere o par **na sua máquina**, nunca na VM. A regra é: a chave privada nasce
onde vai ser usada e não atravessa a rede. Aqui ela vai virar secret do GitHub,
então nasce na máquina de onde você grava o secret.

Use uma chave exclusiva para o CI — não reaproveite a sua chave pessoal: se
precisar revogar o acesso do GitHub Actions, você revoga só esta.

```bash
ssh-keygen -t ed25519 -C "github-actions-cp1-ci" -f ~/.ssh/cp1_ci -N ""
chmod 600 ~/.ssh/cp1_ci
```

Gera `cp1_ci` (privada, vira o secret) e `cp1_ci.pub` (pública, vai para a VM).

Mostre a pública para copiar:

```bash
cat ~/.ssh/cp1_ci.pub
```

**Na VM**, acrescente a linha ao `authorized_keys`:

```bash
cat >> ~/.ssh/authorized_keys <<'EOF'
<cole aqui a linha inteira do cp1_ci.pub>
EOF
chmod 600 ~/.ssh/authorized_keys
wc -l ~/.ssh/authorized_keys
```

> ⚠️ **Use `>>`, nunca `>`.** Um `>` sozinho **sobrescreve** o arquivo e apaga
> todas as outras chaves — inclusive a que te dá acesso à VM. Aconteceu conosco
> durante a montagem deste laboratório, e o acesso só voltou pelo console serial
> do portal do Azure. Confira com `wc -l` que o número de linhas **aumentou**.

Teste antes de seguir — se isso não funcionar, o workflow também não vai:

```bash
ssh -i ~/.ssh/cp1_ci <usuario>@<ip-da-vm> "docker --version && ls -ld /opt/CP1_DEV_SEC_OPS"
```

Tem que responder **sem pedir senha**. Se pedir, a chave pública não foi
autorizada corretamente.

---

## 3. Configurar os secrets no repositório

Três secrets, em *Settings > Secrets and variables > Actions > New repository
secret*:

| Secret | Valor |
|---|---|
| `AZURE_VM_HOST` | IP público ou DNS da VM |
| `AZURE_VM_USER` | usuário do SSH |
| `AZURE_VM_SSH_KEY` | conteúdo **completo** da chave privada `~/.ssh/cp1_ci` |

A chave privada inclui as linhas `-----BEGIN OPENSSH PRIVATE KEY-----` e
`-----END OPENSSH PRIVATE KEY-----` e a quebra de linha final. Copiar pela
interface web costuma perder a última quebra — por isso prefira o CLI:

```bash
gh secret set AZURE_VM_HOST    --repo Snake-arch57/CP1_DEV_SEC_OPS --body "<ip-da-vm>"
gh secret set AZURE_VM_USER    --repo Snake-arch57/CP1_DEV_SEC_OPS --body "<usuario>"
gh secret set AZURE_VM_SSH_KEY --repo Snake-arch57/CP1_DEV_SEC_OPS < ~/.ssh/cp1_ci
```

Conferir (mostra os nomes, nunca os valores):

```bash
gh secret list --repo Snake-arch57/CP1_DEV_SEC_OPS
```

---

## 4. Fechar o firewall do Azure (NSG)

O passo mais importante, e o único com risco de **nota zero**.

No portal do Azure, em *Networking > Network security group* da VM:

- **Porta 22 (SSH):** liberada. Restrinja a origem ao IP da sala/VPN da
  instituição sempre que possível, em vez de `Any`.
- **Porta 8081 (DVWA): NÃO abrir.** Não crie regra nenhuma para ela.

O `docker-compose.yml` publica o DVWA em `127.0.0.1:8081`, então ele já não
escuta na interface pública mesmo que o NSG estivesse aberto. São duas camadas
independentes — mantenha as duas.

Para acessar o DVWA na VM, use túnel SSH:

```bash
ssh -L 8081:127.0.0.1:8081 usuario@<ip-da-vm>
# e então abra http://localhost:8081 no seu navegador
```

> Por que isso importa: o DVWA é deliberadamente vulnerável. Expô-lo na internet
> deixa de ser "ambiente local isolado" (seção 7 do enunciado) e passa a ser um
> alvo real acessível por terceiros.

---

## 5. Subir o workflow

```bash
git add .github/workflows/security-gate.yml DEPLOY.md
git commit -m "ci: pipeline com gate de severidade e deploy na VM Azure"
git push origin main
```

Acompanhe em **Actions > security-gate**.

---

## 6. O que esperar na primeira execução

Num `push` na `main` (com as correções aplicadas, que é o padrão):

| Job | Resultado esperado |
|---|---|
| `guarda-de-escopo` | ✅ verde — nenhuma porta do compose sai de `127.0.0.1` |
| `sast-opengrep` | ✅ verde — o job roda; os achados não o derrubam |
| `dast-nikto` | ✅ verde — idem |
| `security-gate` | ✅ verde — 0 achados HIGH em escopo |
| `config-do-deploy` | ✅ verde — secrets presentes |
| `deploy` | ▶️ executa |

Rodando à mão com `remediacao` **desmarcada**:

| Job | Resultado esperado |
|---|---|
| `security-gate` | ❌ **vermelho** — `SAST=2 DAST=2 TOTAL=4` |
| `config-do-deploy` | ⏭️ pulado — o gate falhou |
| `deploy` | ⏭️ pulado (e não roda em `workflow_dispatch` de todo jeito) |

**Esse vermelho é o entregável.** Tire print da aba *Summary* do job
`security-gate`, que traz a tabela de contagem — é a "evidência de build
vermelho" exigida pelo requisito 5. Salve em `evidencias/`.

---

## 7. Provocar o build verde e o deploy

Para o gate passar, os dois contadores precisam zerar:

1. **SQL Injection (OpenGrep):** aplicar `patches/fix-sqli.php` — troca a
   concatenação por prepared statement com bind de parâmetro (`mysqli_prepare`
   + `mysqli_stmt_bind_param`, e `SQLite3::prepare` no caminho SQLite).
2. **Directory indexing (Nikto):** desabilitar o autoindex do Apache no alvo
   (`Options -Indexes`), eliminando os achados em `/config/` e `/docs/`.

Com os dois corrigidos, `git push origin main` novamente. Agora:

| Job | Resultado |
|---|---|
| `security-gate` | ✅ verde |
| `deploy` | ▶️ executa |

Print do verde também vai para `evidencias/`.

---

## 8. Conferir o deploy

Na VM:

```bash
cd /opt/CP1_DEV_SEC_OPS
git log -1 --oneline      # deve bater com o commit do push
docker compose ps         # containers com CREATED recente
```

O resumo do job no GitHub Actions também imprime o commit publicado e o comando
do túnel SSH.

---

## Troubleshooting

| Sintoma | Causa provável | Solução |
|---|---|---|
| `deploy` pulado com gate verde | Secrets ausentes ou com nome errado | `gh secret list` e conferir os três nomes |
| `ssh: handshake failed` | Chave privada incompleta no secret | Regravar com `gh secret set ... < arquivo`, não por copiar/colar |
| `permission denied` no `/opt/...` | Passo 1 não executado | `sudo chown -R "$(id -un)" /opt/CP1_DEV_SEC_OPS` |
| `docker: permission denied` na VM | Usuário fora do grupo `docker` | `sudo usermod -aG docker "$(id -un)"` e **reconectar** |
| Deploy aborta na guarda de escopo | Bind alterado no `docker-compose.yml` | Restaurar `127.0.0.1:8081:80` e conferir com `bash scripts/verificar-escopo.sh` |
| `git reset --hard` falha | Alteração manual feita na VM | É esperado: a VM é descartável, não edite nada lá |
