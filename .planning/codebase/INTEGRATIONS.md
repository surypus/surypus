---
last_mapped_commit: 7bd87f6f9f0abbbaddaeb0e604b8ff8fe2ff4c41
last_mapped_at: 2026-10-23
---
# External Integrations

**Analysis Date:** 2026-10-23

## Integration Status Summary

| Integration | Direction | Status | Primary file(s) |
|-------------|-----------|--------|-----------------|
| PostgreSQL 16 | Read/write | Operational (driver + SQL) | `src/DAL/`, `sql/migrations/` |
| Redis 7 | Read/write | Operational (cache, streams, queues) | `src/Infrastructure/Redis/`, `src/Core/Accounting/RedisCache.hs` |
| OpenAI Chat Completions | Outbound HTTP | Operational call, narrow use | `src/Surypus/API/AI.hs` |
| Anthropic Messages API | Outbound HTTP | Stub | `src/Surypus/AI/Anthropic.hs` |
| Generic external REST APIs | Outbound HTTP | Client implemented, no concrete provider wired | `src/Integration/API/ExternalAPI.hs` |
| Bank statements (OFX / ISO 20022) | Inbound file parse | Implemented parser + DB import | `src/Integration/BankStatement.hs`, `src/Surypus/API/Integrations.hs` |
| SMTP email | Outbound | Config read, delivery is file/stdout | `src/Email.hs`, `src/Infrastructure/EmailSender.hs` |
| Web Push | Outbound | Subscription storage only | `src/Surypus/API/Push.hs` |
| EGAIS / VETIS / UHTT / EDI / marketplace / payment / blockchain | Outbound | Contract types or placeholders | `src/External/`, `src/Integration/` |
| JasperReports / Pentaho | Outbound report engine | Placeholder paths | `src/External/Jasper/Jasper.hs`, `src/External/Pentaho/Pentaho.hs` |
| Kafka / Redpanda | Event streaming | Declared in Compose, not implemented in Haskell | `docker/docker-compose.yml`, `src/EventBus.hs` |
| Open Policy Agent | Authorization | Policies present, app does not call OPA | `opa/policies/`, `src/Surypus/RBAC.hs` |
| Prometheus / Grafana | Observability | Metrics endpoint + configs, path mismatch | `src/Surypus/Metrics.hs`, `config/grafana/` |
| gRPC | Contract | Proto only, no server/client runtime | `api/grpc/surypus.proto` |

## APIs & External Services

**AI / LLM:**
- OpenAI Chat Completions - extracts structured data from invoices/receipts and generates recommendations.
  - SDK/Client: raw HTTP via `http-conduit` (`Network.HTTP.Simple`) in `src/Surypus/API/AI.hs`
  - Endpoint: `https://api.openai.com/v1/chat/completions`, model `gpt-4-turbo-preview` (`src/Surypus/API/AI.hs:83-94`)
  - Auth: `SURYPUS_OPENAI_API_KEY` (bearer token)
  - Related stubs: `src/Surypus/AI.hs` returns canned recommendations; `src/Surypus/AI/OpenAI.hs` returns `"stub-response"`; CLI `app/ai-report.hs` calls the canned path.
- Anthropic - declared provider with endpoint `https://api.anthropic.com` and model `claude-3-sonnet`, but `callAnthropic` returns a stub (`src/Surypus/AI/Anthropic.hs`).

**Generic outbound REST:**
- `APIClient` in `src/Integration/API/ExternalAPI.hs` provides `initAPIClient`, `apiGet`, `apiPost`, `apiPostJSON`, bearer key injection (`attachApiKey`), status handling, and `retryRequest`.
- No concrete SaaS provider is bound to it; it is the intended seam for future integrations.

**Regulatory / government (Russia):**
- EGAIS (alcohol tracking) - `src/External/EGAIS.hs` (shipment/product types, `validateEgaisShipment`), `src/External/EGais/EGais.hs` (`fetchEGaisData = pure []`), DB schema `config/schema_egais.sql`. No network client.
- VETIS (veterinary certification) - `src/External/VETIS.hs` (entity/movement types, `isVetisActive`), DB schema `config/schema_vetis.sql`. No network client.
- UHTT online store - `src/External/UHTT/UhttStore.hs` stores `usURL` and `usAPIKey` fields; `src/External/UHTT` has no HTTP calls.

**Commerce / payments:**
- Payment gateways - `PaymentGatewayAdapter` in `src/Integration/Adapter.hs:234` carries a free-text `pgaGatewayType` (`"Stripe"`, `"PayPal"`, etc.) and `pgaApiEndpoint`; `fetch` returns `Right []`. No Stripe/PayPal SDK or HTTP call exists anywhere in `src/`.
- Marketplace adapter - `MarketplaceAdapter` in `src/Integration/Adapter.hs` transforms `ExternalData` into `MarketplaceOrder` domain entities; no transport implementation.
- Payment cards - `src/Commerce/PaymentCard.hs` stores card records (`CTVisa`, `CTMasterCard`, `CTMir`, `CTAmex`) and masks numbers; no tokenization or processor integration.
- EDI - `src/Integration/EDI/EDI.hs` defines `EDIExchange`, `EDIType` (`EDIOrder`, `EDIInvoice`, `EDIDesadv`, `EDIRecadv`) and statuses; schema in `config/schema_edi.sql`, `config/schema_edi_extended.sql`, `config/schema_edi_provider.sql`.

**Banking:**
- OFX and ISO 20022 (camt.053) statement parsing with auto-matching - `parseOFX`, `parseISO20022`, `importStatementLines`, `matchTransactionsToBills` in `src/Integration/BankStatement.hs`; API-facing equivalents in `src/Surypus/API/Integrations.hs`; schema `config/schema_bank_account_type.sql`, `src/Surypus/API/Integrations.hs` types.
- Integration health tracking - `src/Integration/Health.hs` plus table/function `sql/migrations/V020__integration_health.sql`.

**Reporting engines:**
- JasperReports - `JasperConfig { jcJarPath }` in `src/External/Jasper/Jasper.hs`; `generateReport` returns a fabricated `/reports/jasper/<name>.jrprint` path. Also `src/Reports/Jasper.hs`.
- Pentaho - `PentahoConfig { serverUrl }` in `src/External/Pentaho/Pentaho.hs`; `generateReport` returns a static `.prpt` path.
- Crystal Reports migration - `src/Surypus/Reports/Conversion/CrystalToPdfSlave.hs`, `src/Surypus/Reports/Templates.hs`; YAML templates in `templates/reports/*.yaml`.
- PDF generation - external `weasyprint` CLI invoked with `readProcessWithExitCode` in `src/Surypus/API/Reports.hs:195`; output directory `/tmp/surypus-reports`.
- PDF text extraction - `src/Surypus/PDF.hs` is a stub (`extractTextFromPDFPath` returns an error).

**Other external-domain models (types only):**
- Blockchain/smart contracts - `src/DAL/Blockchain.hs` (`SmartContract`, `BlockchainTransaction`, Wei values, Solidity source field), no node RPC.
- Post-quantum crypto - `src/Security/Quantum/Crypto.hs` offers `Kyber | Dilithium | Falcon | SPHINCS` but all functions return zero-filled placeholders and `verifySignature = True`.
- Hardware - electronic scales `src/Retail/Device/Scale.hs` (IP/port fields), generic hardware loads `src/System/Hardware.hs` with LiquidHaskell refinements; no device protocol implementation.
- Marketplace/CRM sync - `src/Integration/Sync.hs` (session/object/action types), `src/MultiTenancy/*` (tenant isolation, RLS).

## Data Storage

**Databases:**
- PostgreSQL 16 (primary system of record)
  - Connection: `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_POOL_SIZE` read in `src/Surypus/DB/Pool.hs:45-50`; a second pool in `src/DAL/Database.hs:44` hardcodes a localhost DSN with fixed development credentials and ignores the environment.
  - Client: `persistent-postgresql` + `esqueleto`; raw SQL via `rawSql`/`rawExecute` throughout `src/DAL/`, `src/Integration/BankStatement.hs`, `src/Surypus/API/Server.hs`.
  - Schema/persistence definitions: `src/DAL/Schema.hs` (Template Haskell, generated from `dsl/schema.yaml`), `src/Surypus/DB/Schema.hs`, `src/DAL/Types.hs`.
  - Migrations: `sql/migrations/` (`V000__schema_version.sql` … `V1000__event_store_schema.sql`), applied by `sql/migrations/init_db.sh`, `scripts/init_db.sh`, `scripts/setup_test_db.sh`; legacy/alternate schemas in `config/schema*.sql` and `config/database*.sql`.
  - Extensions: `uuid-ossp`, `pg_trgm`, `hstore`, `pgcrypto`, `btree_gin` (`config/schema_advanced.sql`, `sql/migrations/V011__consolidated.sql`, `V212__event_store_advanced.sql`); optional `postgis` (`sql/migrations/V218__geospatial_support.sql`) and `vector`/pgvector with `VECTOR(1536)` embeddings (`sql/migrations/V231__semantic_search.sql`, `V249__knowledge_graph.sql`) loaded only when available.
  - Stored procedures/functions: `sql/procedures/`, `sql/aggregate/`, `sql/projection/`, `sql/policy/`; `calc_vat`, `calc_bill_totals`, `get_lot_bounds` in `sql/archive/procedures.sql` (invoked generically through `src/DAL/Procedures.hs`).
  - Event store tables: `sql/migrations/V014__event_store.sql`, `V1000__event_store_schema.sql`, plus `src/DAL/EventStore.hs`, `src/Infrastructure/EventStore/{Accounting,CRM,Inventory}.hs`.
  - Row-level security and tenancy: `sql/migrations/V016__rls_policies.sql`, tenant context set per request in `src/DAL/Database.hs` (`set_config('app.tenant_id', ...)`) via `src/MultiTenancy/Middleware.hs`.

**File Storage:**
- Local filesystem only - `src/Infrastructure/FileStorage.hs` (`StorageConfig` base path, 100 MB limit, `.png .jpg .pdf .txt` allowlist, SHA-like hash metadata).
- Generated reports are written to `/tmp/surypus-reports` (`src/Surypus/API/Reports.hs`).
- Backups target a local destination directory (`src/Infrastructure/BackupManager.hs`); ad-hoc `pg_dump` in `src/Surypus/API/Server.hs:910` uses a hardcoded DSN.

**Caching:**
- Redis 7 via `hedis`:
  - Accounting balance read-model cache with TTL 5 s, db `0`, `localhost:6379` (`src/Core/Accounting/RedisCache.hs:56-70`), used by `src/Core/Accounting/Cache.hs`.
  - Redis Streams for domain events: `surypus:events` (`src/Infrastructure/Redis/EventStream.hs`), `accounting-events` (`src/Core/Accounting/RedisCache.hs`).
  - Report task queue (`src/Infrastructure/Redis/TaskQueue.hs`) and Redis job queue (`src/System/JobQueue.hs`).
  - Pub/sub publishing for WebSocket fan-out: channel `surypus:events` (`src/Surypus/WebSocket/RedisPublisher.hs`).
- In-process STM caches: `src/Core/Accounting/Cache.hs`, `src/System/Cache.hs`, rate limiter `src/System/RateLimiter.hs`.

**Message/event infrastructure:**
- PostgreSQL event store is the system of record; Redis Streams is the fan-out path (documented in `src/Infrastructure/Redis/EventStream.hs`).
- Kafka/Redpanda is provisioned in `docker/docker-compose.yml` (redpanda, redpanda-console, Debezium `event-publisher`, `projection-builder`) with `KAFKA_BROKERS=redpanda:9092`, but Haskell publishing is a TODO (`src/EventBus.hs:39-41`) and `scripts/publish-events.sh` only marks outbox rows published after a simulated send.
- In-memory event buses: `src/Integration/API/EventBusAdvanced.hs`, `src/Integration/API/EventProcessor.hs`, `src/Surypus/EventBridge.hs`.

## Authentication & Identity

**Auth Provider:**
- Custom, built into the application (no OAuth/OIDC/LDAP/SAML/Keycloak code found in `src/`).
  - JWT HS256 signing/verification with `jose` in `src/Surypus/JWT/Token.hs`; claims `sub`, `name`, `role`, `tenant_id`, `aud` = `surypus-api`, `iat`, `exp` (1 hour).
  - Signing secret from `SURYPUS_JWT_SECRET`; startup fails if unset (`src/Surypus/JWT/Token.hs:75-78`). Development fallback constant exists in `defaultSecretKey`.
  - Bearer extraction and per-route permission checks in `src/Surypus/API/AuthMiddleware.hs` and `src/Surypus/API/Authorization.hs`.
  - Refresh tokens persisted in PostgreSQL `user_sessions` via `src/Surypus/RefreshTokenRepo.hs` (`storeRefreshToken`, `rotateStoredRefreshToken`, `validateRefreshToken`).
  - RBAC model and canonical migrations in `src/Surypus/RBAC.hs`, `src/Surypus/RBAC/Store.hs`, `src/Surypus/Domain/RBACCanon/*`; tables from `sql/migrations/V002__rbac_indexes.sql` through `V009__rbac_store.sql`, `sql/core/V001__rbac_schema.sql`.
  - Password hashing in `src/Infrastructure/Encryption.hs` labels output `pbkdf2` but uses a custom reversible XOR-fold with a fixed salt `deadbeef`; encryption/decryption functions are no-ops.
  - In-memory secret store with rotation metadata/audit in `src/System/Secrets.hs` (values stored unencrypted in an STM `Map`).

**External authorization engine:**
- OPA/Rego policies exist (`opa/policies/rbac.rego`, `opa/policies/inventory.rego`) and OPA runs in `docker/docker-compose.yml` on port 8181 with `OPA_URL` set for the API container. No Haskell module imports or HTTP-calls OPA (grep for `8181` in `src/` returns no integration code), so enforcement is currently in-process.

**Push identity:**
- Web Push subscriptions (`endpoint`, `p256dh`, `auth`) are stored per user in a `TVar` map (`src/Surypus/API/Push.hs`); no push service call or VAPID signing exists.

## Monitoring & Observability

**Error Tracking:**
- No external error tracker (Sentry/Rollbar/etc.).

**Metrics:**
- Prometheus text exposition generated by `renderPrometheus` in `src/Surypus/Metrics.hs`; served at `/api/v1/metrics` by `metricsEndpoint` in `src/Surypus/API/Server.hs`.
- Instrumented series: `surypus_http_requests_total`, `surypus_http_request_duration_seconds` (histogram buckets), `surypus_http_requests_error`, DB pool connections, job queue size.
- Scrape configs: `prometheus/prometheus.yml` targets `api:8080` with `metrics_path: /metrics`; `config/prometheus.yml` targets `surypus-api:3000`, `postgres-exporter:9187`, `opa:8181`. Both paths/ports differ from the implemented `/api/v1/metrics` on port 8080/3000, so scrapes need adjustment.
- Dashboards: `config/grafana/dashboards/event-sourcing.json`; datasources `config/grafana/datasources/datasources.yml` (Prometheus + PostgreSQL).

**Logs:**
- Structured JSON logging via katip (`src/Surypus/API/Logger.hs`, `Katip.Scribes.Handle` to stdout) with correlation IDs.
- Additional in-memory log stores: `src/System/Logger.hs`, `src/System/Log.hs`.
- Distributed tracing is in-process only (`src/System/Tracing.hs` creates spans/UUIDs); no OpenTelemetry/Zipkin/Jaeger exporter.

## CI/CD & Deployment

**Hosting:**
- Container image `ghcr.io/<owner>/<repo>` published by `.github/workflows/docker-publish.yml` (buildx + GHCR login + attestations).
- Documentation site published to GitHub Pages by `.github/workflows/documentation-deploy.yml` (MkDocs + Haddock).
- Release artifacts/SBOM via `sbom.yml` and `slsa-compliance.yml`; tag-driven Hackage publish in `hackage-publish.yml`.

**CI Pipeline:**
- GitHub Actions, 83 workflows under `.github/workflows/`.
- Core build/test: `ci.yml` (Stack build + `stack test`), `postgres-integration.yml` (Postgres 16 service + migrations), `haskell-coverage.yml` (hpc-codecov), `property-testing.yml`, `benchmark.yml`.
- Quality gates: `haskell-hlint.yml`, `haskell-formatting.yml` (Fourmolu, non-blocking), `haskell-cabal-format.yml`, `liquidhaskell-verify.yml`, `codeql.yml` (Python/JavaScript only), `security-scan.yml`, `secret-guard.yml`, `sbom.yml`.
- Docs gates: `documentation.yml` (Haddock, doctest, Hoogle, inventory, module graph, drift), `documentation-deploy.yml`.
- Repository automation: `beads-sync-github.yml` mirrors `.beads/` into GitHub Issues every six hours; `.github/workflows/webhook-notifications.yml` posts to Slack/Discord.

**Deployment topology (reference):**
- `docker-compose.yml`: `db` (Postgres 16), `redis` (Redis 7), `api` (port 8080→443), `worker` (command `surypus-job-worker`, no such executable target in `Surypus.cabal`).
- `docker/docker-compose.yml`: `postgres`, `opa`, `redpanda`, `redis`, `redpanda-console`, `surypus-api` (port 3000), `event-publisher`, `projection-builder`, `prometheus`, `grafana`.
- `docker-compose.graphql.yml` references a `./surypus-graphql` build context that does not exist in the repository.

## Environment Configuration

**Required env vars (application code):**
- `SURYPUS_JWT_SECRET` - required for token signing; process aborts without it.
- `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_POOL_SIZE` - PostgreSQL pool.
- `SURYPUS_OPENAI_API_KEY` - AI document parsing endpoint.
- `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, `SMTP_FROM`, `SMTP_FROM_NAME`, `EMAIL_OUTPUT_FILE` - email configuration.

**Optional / test-only:**
- `SURYPUS_TEST_DATABASE_URL`, `SURYPUS_TEST_REDIS_URL` - enable live integration specs.

**Compose-injected (not consumed by current Haskell code):**
- `DATABASE_URL`, `REDIS_URL`, `OPA_URL`, `KAFKA_BROKERS`, `APP_ENV`, `POSTGRES_PASSWORD`, `PORT`.

**Secrets location:**
- `.env.example` (template) and `docker/.env.production` exist in the repository; contents are not reproduced here. `.gitignore` excludes `.env` and `.env.*` while allowing `.env.example`.
- GitHub Actions secrets include `GITHUB_TOKEN`, `GH_TOKEN`, `DISCORD_WEBHOOK_URL`, `SLACK_WEBHOOK_URL`, `SLACK_BOT_TOKEN`, plus registry/Pages OIDC tokens (referenced in `.github/workflows/` and `docs/webhooks/SETUP.md`).
- Runtime secret handling is in-memory (`src/System/Secrets.hs`); no Vault/KMS/AWS Secrets Manager client.

## Webhooks & Callbacks

**Incoming:**
- None. `type SurypusApi` in `src/Surypus/API/Server.hs:240` has no webhook route; `config/schema_webhook.sql` defines a `webhook` table and `src/Integration/Webhook.hs` defines `Webhook`/`WebhookLog` types, but no receiver or dispatcher is implemented.

**Outgoing:**
- No application-level webhook delivery. The `Webhook` model records `whURL`, `whEvent` (`WEBillCreated`, `WEBillUpdated`, `WEOrderCreated`, `WEPaymentReceived`), `whSecret`, and delivery logs, but nothing consumes them.
- Repository/CI notifications use Slack and Discord webhooks via GitHub Actions; setup is documented in `docs/webhooks/SETUP.md`.

## Protocol Surfaces

- **REST:** Servant API mounted under `/api/v1` (`src/Surypus/API/Server.hs`), JWT bearer auth except public paths. Specs: `openapi/openapi.yaml` (`http://localhost:8080/api/v1`), `api/rest/openapi.yaml` (event-sourcing view), `static/swagger.json`. No route serves these specs.
- **GraphQL:** `POST /api/v1/graphql` implemented in `src/Surypus/API/GraphQL.hs`; it dispatches on the first word of the query (`bills`, `goods`, `persons`, `payments`, `deals`, `contacts`, `companies`, `orders`, `dashboardKPI`, `pipelineForecast`, `pipelineStages`) rather than parsing GraphQL. Migration notes in `docs/GRAPHQL_MIGRATION.md`.
- **WebSocket:** `/api/v1/ws` handled by `Network.WebSockets` with rooms `global`, `bills`, `inventory`, `persons`, `notifications` (`src/Surypus/WebSocket.hs`, `src/Surypus/WebSocket/Integration.hs`); desktop client uses `ws://localhost:8080/api/v1/ws` (`frontend/qml/WsClient.qml`).
- **gRPC:** `api/grpc/surypus.proto` defines `CommandService`, `QueryService`, `SagaService`; `Makefile` has `build-proto` using `protoc --haskell_out`, but no gRPC dependency or generated code is present.
- **Health:** `/api/v1/health` (liveness) and `/api/v1/health/db` (database probe) in `src/Surypus/API/Server.hs`.

---

*Integration audit: 2026-10-23*
