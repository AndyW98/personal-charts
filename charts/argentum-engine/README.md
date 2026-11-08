# argentum-engine

[Argentum Engine](https://github.com/wingedsheep/argentum-engine) is an
unofficial Magic: The Gathering rules engine with a browser client. You can
play against an AI opponent (a built-in heuristic AI or an LLM), draft, or
play other people. It isn't affiliated with Wizards of the Coast, and only
the cards the project has implemented are playable
([set tracker](https://magic.wingedsheep.com/set-completion)).

## Install

```sh
helm repo add personal-charts https://andyw98.github.io/personal-charts
helm upgrade --install mtg personal-charts/argentum-engine \
  --namespace mtg --create-namespace -f my-values.yaml
kubectl -n mtg port-forward svc/mtg-argentum-engine-frontend 8080:80
```

## Components

| Component | What it runs | Notes |
|-----------|--------------|-------|
| `backend` | Spring Boot game server, `:8080` (`/api`, `/game` WebSocket) | 1 replica with `Recreate`, because games live in memory and a restart drops games in progress |
| `frontend` | nginx serving the web client | The chart's own nginx config proxies `/api` and `/game` to the backend, running unprivileged on 8080 |
| `redis` | `redis:8.6-alpine` StatefulSet, append-only, 1Gi PVC | Upstream's cache. Use `redis.external.host` for your own Redis, or `redis.enabled=false` to skip it |

Upstream only publishes `latest` images, for amd64 only. `backend.image.digest`
and `frontend.image.digest` pin the builds this chart version was made with.
To move to a newer upstream build, update both digests together, since the
frontend and backend come from the same commit, and bump the chart version.

## AI opponent

| `ai.mode` | Opponent | Needs |
|-----------|----------|-------|
| `engine` (default) | Built-in rules-engine AI | Nothing |
| `llm` | Any OpenAI-compatible chat API at `ai.baseUrl` (default OpenRouter), using `ai.model` | `GAME_AI_API_KEY` or `OPENROUTER_API_KEY` in `existingSecret` |
| `jev` | OpenRouter's Decisions API (`typesafe/jev-1.13`) | `OPENROUTER_API_KEY` |

The LLM sees the same hidden-information view of the game as a human player.
If it fails or gives an answer the server can't parse, the server falls back
to heuristic play. Upstream calls this opponent experimental. It also builds
the AI's limited decks unless `ai.skipLlmDeckbuilding=true`.

To use a local model, point `ai.baseUrl` at an OpenAI-compatible server in the
cluster, such as Ollama or vLLM:

```yaml
ai:
  mode: llm
  baseUrl: http://ollama.ollama.svc:11434/v1
  model: qwen3:14b
```

```sh
kubectl -n mtg create secret generic argentum-env \
  --from-literal=OPENROUTER_API_KEY=sk-or-... \
  --from-literal=GAME_ADMIN_PASSWORD="$(openssl rand -base64 24)"
```

## Access

The app has **no login** unless accounts are enabled. Anyone who can reach it
can start games, which spends your LLM credits in `llm` or `jev` mode. Keep it
on a private network, or put an auth proxy in front of the ingress.
`GAME_ADMIN_PASSWORD` only protects `/admin`.

The ingress only needs to point at the frontend. Games hold a WebSocket open,
so raise your proxy's timeouts (see `ingress.annotations` in `values.yaml`).

## Accounts (optional)

Accounts add saved decks, match stats and magic-link login, and need an
external PostgreSQL:

```yaml
existingSecret: argentum-env   # + ACCOUNTS_DB_PASSWORD, ACCOUNTS_AUTH_SECRET, MAIL_USERNAME/PASSWORD
accounts:
  enabled: true
  database:
    url: jdbc:postgresql://postgres.db.svc:5432/argentum
    user: argentum
  mail:
    host: smtp.example.com
    port: "587"
```

`APP_BASE_URL` for magic links defaults to the first ingress host. Without
mail credentials, the backend logs the login links instead of emailing them.
Without `ACCOUNTS_AUTH_SECRET`, sign-ins don't survive a restart.

## Values

| Key | Default | Description |
|-----|---------|-------------|
| `ai.enabled` / `ai.mode` | `true` / `engine` | AI opponent and its mode |
| `ai.baseUrl` / `ai.model` / `ai.deckbuildingModel` | OpenRouter / upstream default / `""` | LLM settings |
| `ai.skipLlmDeckbuilding` | `false` | Always use the built-in deck builder |
| `existingSecret` | `""` | Secret loaded into the backend via `envFrom` |
| `accounts.*` | disabled | See above |
| `backend.image.*` / `frontend.image.*` | `latest` pinned by digest | Images |
| `backend.javaOpts` | `-XX:MaxRAMPercentage=75 -XX:+ExitOnOutOfMemoryError` | `JAVA_TOOL_OPTIONS` |
| `backend.env` / `extraEnv` / `extraEnvFrom` | | Other upstream settings, e.g. `GAME_TOURNAMENT_SIMULATE_AI_MATCHES` |
| `backend.resources` | 250m / 1Gi request, 3Gi limit | |
| `frontend.service.*` | ClusterIP :80 | |
| `redis.enabled` / `redis.external.*` / `redis.persistence.*` | bundled, 1Gi | |
| `ingress.*` | disabled | Points at the frontend |
| `*.podSecurityContext` / `*.securityContext` | non-root, read-only root fs, drop ALL | Per component |
| `*.nodeSelector` / `*.tolerations` / `*.affinity` | | Per component (amd64 nodes only) |
