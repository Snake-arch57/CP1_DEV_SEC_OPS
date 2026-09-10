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

ENTRYPOINT ["opengrep"]
