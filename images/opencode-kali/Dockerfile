# syntax=docker/dockerfile:1
# Kali Linux (rolling) with the opencode CLI, running `opencode serve`.
FROM kalilinux/kali-rolling

LABEL org.opencontainers.image.source="https://github.com/AndyW98/personal-charts" \
      org.opencontainers.image.description="opencode serve on Kali Linux rolling" \
      org.opencontainers.image.licenses="MIT"

# opencode release to install (https://github.com/anomalyco/opencode/releases).
# CI passes the chart's appVersion (charts/opencode-kali/Chart.yaml).
ARG APP_VERSION=1.19.5
# Kali packages to install. kali-linux-headless is Kali's default CLI tool set;
# set to "" for a minimal image (used for CI) or e.g. "kali-linux-large".
ARG KALI_PACKAGES="kali-linux-headless"
ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl git ripgrep tini procps less nano jq openssh-client \
      ${KALI_PACKAGES} \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    case "${TARGETARCH:-amd64}" in \
      amd64) asset=opencode-linux-x64.tar.gz ;; \
      arm64) asset=opencode-linux-arm64.tar.gz ;; \
      *) echo "unsupported arch: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://github.com/anomalyco/opencode/releases/download/v${APP_VERSION}/${asset}" \
      | tar -xz -C /usr/local/bin opencode; \
    chmod 0755 /usr/local/bin/opencode; \
    opencode --version

# Unprivileged user; uid/gid 1000 to match the chart's securityContext.
RUN set -eux; \
    groupadd -g 1000 kali; \
    useradd -m -u 1000 -g 1000 -s /bin/bash kali; \
    mkdir -p /workspace; \
    chown kali:kali /workspace

ENV HOME=/home/kali \
    OPENCODE_DISABLE_AUTOUPDATE=true

USER 1000:1000
WORKDIR /workspace
EXPOSE 4096

ENTRYPOINT ["/usr/bin/tini", "--", "opencode"]
CMD ["serve", "--hostname", "0.0.0.0", "--port", "4096"]
