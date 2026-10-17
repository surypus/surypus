# GraphQL Client Migration Plan

**Issue:** US-3-7 — Move external consumers from REST endpoints to the GraphQL proxy at `/graphql`.

---

## 1. Current Architecture

### REST Endpoints (to be deprecated)

```
GET  /api/v1/bills          → listBills
GET  /api/v1/goods          → listGoods
GET  /api/v1/persons        → listPersons
POST /api/v1/payments       → listPayments
GET  /api/v1/orders         → listOrders
GET  /api/v1/dashboard/summary
...
```

### GraphQL Proxy

All REST endpoints are mapped one-to-one to the GraphQL layer at `POST /graphql`:

```json
{
  "query": "<operation_name>",
  "variables": { ... }
}
```

| Operation (query) | REST endpoint | Response type |
|-------------------|---------------|---------------|
| `bills` | `GET /api/v1/bills` | `Bills[]` |
| `goods` | `GET /api/v1/goods` | `Goods[]` |
| `persons` | `GET /api/v1/persons` | `Persons[]` |
| `payments` | `POST /api/v1/payments` | `Payments[]` |
| `orders` | `GET /api/v1/orders` | `Orders[]` |
| `dashboardKPI` | `GET /api/v1/dashboard/summary` | `DashboardStats` |
| `deals` | `GET /api/v1/crm/deals` | `Deals[]` |
| `contacts` | `GET /api/v1/crm/contacts` | `Contacts[]` |
| `companies` | `GET /api/v1/crm/companies` | `Companies[]` |
| `pipelineForecast` | `GET /api/v1/crm/pipeline` | `Pipeline[]` |
| `pipelineStages` | `GET /api/v1/crm/stages` | `Stages[]` |

---

## 2. Migration Steps for Consumers

### 2.1 Bulk / Script Migration (Python example)

```python
import requests

API_URL = "https://api.example.com/graphql"
HEADERS = {"Content-Type": "application/json", "Authorization": "Bearer ..."}

def execute(query: str, variables: dict = None) -> dict:
    payload = {"query": query}
    if variables:
        payload["variables"] = variables
    resp = requests.post(API_URL, json=payload, headers=HEADERS)
    resp.raise_for_status()
    return resp.json()

# Old: GET /api/v1/bills?limit=100&offset=0
# New:
result = execute("bills", {"limit": 100, "offset": 0})
bills = result["data"]
errors = result.get("errors", [])
```

**Variables accepted by most operations:**

| Variable | Type | Description |
|----------|------|-------------|
| `limit` | Int | Page size (default: 100) |
| `offset` | Int | Offset for skip |
| `filter` | JSON object | Field-value pairs for filtering |
| `sort` | JSON array | `["field:asc", "field2:desc"]` |
| `status` | String | E.g. `"active"`, `"cancelled"` |

### 2.2 Frontend Migration (React example)

```javascript
const client = new ApolloClient({
  uri: "/graphql",
  headers: { Authorization: `Bearer ${token}` }
});

// Old:
// const bills = await api.get('/bills?limit=100');

// New:
const { data, loading, error } = useQuery(
  gql`{ bills(limit: 100) { id number status total } }`,
  { errorPolicy: "all" }
);
```

---

## 3. Deprecation Timeline

| Phase | Date | Action |
|-------|------|--------|
| 1 | 2026-10-16 | GraphQL proxy enabled (already live) |
| 2 | 2026-11-01 | Deprecation warning added to REST response headers |
| 3 | 2027-01-01 | REST endpoints return HTTP 410 (Gone) |

---

## 4. Monitoring & Rollout

- Enable `@surypus/api-monitoring` to track:
  - `/graphql` request volume
  - GraphQL error rates
  - Client-by-client adoption (parsed from user-agent)
- Set up alert if REST error rate exceeds 0 after Phase 2.

---

## 5. Known Limitations

1. All operations return flat objects; nested filtering not yet supported.
2. Pagination: cursor-based (`after`/`before`) coming in Phase 4.
3. File uploads: must use presigned S3 URLs; GraphQL attachment support pending.