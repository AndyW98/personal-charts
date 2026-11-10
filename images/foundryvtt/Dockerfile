# syntax=docker/dockerfile:1
# Foundry Virtual Tabletop (Node.js build) running as the unprivileged "node" user.
#
# Foundry is licensed software, so the release zip is not in this repo. Builds
# fetch it from a download URL supplied as the BuildKit secret "foundry_url"
# (a timed URL from your foundryvtt.com account, for the version in APP_VERSION):
#   docker build --secret id=foundry_url,env=FOUNDRY_URL images/foundryvtt
# FOUNDRY_STUB=1 builds a placeholder instead: a tiny HTTP server on port 30000
# with no Foundry code, used by CI to test the chart.

ARG NODE_IMAGE=docker.io/library/node:24-slim

FROM ${NODE_IMAGE} AS download
# Foundry version (generation.build) the zip must contain. CI passes the chart's
# appVersion (charts/foundryvtt/Chart.yaml).
ARG APP_VERSION=14.359
ARG FOUNDRY_STUB=0
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl unzip \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /foundryvtt
RUN --mount=type=secret,id=foundry_url,required=false <<'SH'
set -eu
if [ "$FOUNDRY_STUB" = "1" ]; then
  mkdir app
  printf '{"name":"foundryvtt-stub","release":{"generation":%s,"build":%s}}\n' \
    "${APP_VERSION%%.*}" "${APP_VERSION#*.}" > app/package.json
  cat > app/main.js <<'JS'
// CI placeholder: no Foundry code, just answers HTTP like Foundry's port would.
const port = Number((process.argv.find(a => a.startsWith("--port=")) || "--port=30000").split("=")[1]);
require("http").createServer((req, res) => res.end("foundryvtt stub\n")).listen(port);
JS
  exit 0
fi
if [ ! -s /run/secrets/foundry_url ]; then
  echo "No foundry_url build secret and FOUNDRY_STUB is not 1" >&2
  exit 1
fi
curl -fsSL -o /tmp/foundryvtt.zip "$(cat /run/secrets/foundry_url)"
unzip -q /tmp/foundryvtt.zip -d /foundryvtt/dist
rm /tmp/foundryvtt.zip
# The Node.js zip (v13+) has main.js at its root; older and Linux zips keep the
# app under resources/app.
if [ -f dist/main.js ]; then mv dist app; else mv dist/resources/app app && rm -rf dist; fi
SH
# Refuse to ship a zip that is not the version the chart expects.
RUN node -e ' \
  const p = require("/foundryvtt/app/package.json"); \
  const v = p.release ? `${p.release.generation}.${p.release.build}` : String(p.version); \
  if (v !== process.env.APP_VERSION) { console.error(`zip is Foundry ${v}, expected ${process.env.APP_VERSION}`); process.exit(1); } \
  console.log(`Foundry ${v}`);'

FROM ${NODE_IMAGE}
ARG APP_VERSION=14.359
LABEL org.opencontainers.image.source="https://github.com/AndyW98/personal-charts" \
      org.opencontainers.image.description="Foundry Virtual Tabletop" \
      org.opencontainers.image.version="${APP_VERSION}"
RUN apt-get update \
 && apt-get install -y --no-install-recommends tini \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /foundrydata \
 && chown node:node /foundrydata
COPY --from=download --chown=root:root /foundryvtt/app /foundryvtt
ENV NODE_ENV=production
# The node image's unprivileged user (uid/gid 1000), matching the chart.
USER 1000:1000
WORKDIR /foundryvtt
EXPOSE 30000
VOLUME /foundrydata
ENTRYPOINT ["/usr/bin/tini", "--", "node", "/foundryvtt/main.js"]
CMD ["--dataPath=/foundrydata", "--port=30000"]
