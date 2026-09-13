FROM debian:bookworm-slim

ARG OPENGREP_VERSION=v1.22.0

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates \
       curl \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL https://raw.githubusercontent.com/opengrep/opengrep/main/install.sh \
       | bash -s -- -v "${OPENGREP_VERSION}" \
    && ln -s /root/.opengrep/cli/"${OPENGREP_VERSION}"/opengrep /usr/local/bin/opengrep

WORKDIR /src

# O entrypoint confere que /src tem conteudo antes de chamar o opengrep.
# Sem essa guarda, quem pular o clone do alvo (passo 0 do LAB.md) recebe
# "0 findings" com codigo de saida 0 -- um falso sucesso, que so aparece
# na hora da demonstracao.
COPY entrypoint-opengrep.sh /usr/local/bin/entrypoint-opengrep.sh
RUN chmod +x /usr/local/bin/entrypoint-opengrep.sh

ENTRYPOINT ["/usr/local/bin/entrypoint-opengrep.sh"]
