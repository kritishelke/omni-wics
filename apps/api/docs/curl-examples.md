# Omni API Curl Examples

Set env:
```bash
export API_BASE_URL=http://localhost:3001/v1
export SUPABASE_JWT="<supabase_access_token>"
```

Health:
```bash
curl "$API_BASE_URL/health"
```

Start Google OAuth:
```bash
curl -X POST "$API_BASE_URL/google/oauth/start" \
  -H "Authorization: Bearer $SUPABASE_JWT" \
  -H "Content-Type: application/json" \
  -d '{"callbackScheme":"omni"}'
```

Calendar events:
```bash
curl "$API_BASE_URL/google/calendar/events?date=2026-02-21" \
  -H "Authorization: Bearer $SUPABASE_JWT"
```

Tasks:
```bash
curl "$API_BASE_URL/google/tasks" \
  -H "Authorization: Bearer $SUPABASE_JWT"
```

Complete task:
```bash
curl -X POST "$API_BASE_URL/google/tasks/<task_id>/complete" \
  -H "Authorization: Bearer $SUPABASE_JWT"
```

Create task:
```bash
curl -X POST "$API_BASE_URL/google/tasks/create" \
  -H "Authorization: Bearer $SUPABASE_JWT" \
  -H "Content-Type: application/json" \
  -d '{"title":"Quick task from Omni"}'
```

Generate plan:
```bash
curl -X POST "$API_BASE_URL/ai/plan" \
  -H "Authorization: Bearer $SUPABASE_JWT" \
  -H "Content-Type: application/json" \
  -d '{"date":"2026-02-21","energy":"med"}'
```

Signal drift:
```bash
curl -X POST "$API_BASE_URL/signals/drift" \
  -H "Authorization: Bearer $SUPABASE_JWT" \
  -H "Content-Type: application/json" \
  -d '{"planBlockId":"<uuid>","minutes":7,"apps":["YouTube"]}'
```

Day close:
```bash
curl -X POST "$API_BASE_URL/ai/day-close" \
  -H "Authorization: Bearer $SUPABASE_JWT" \
  -H "Content-Type: application/json" \
  -d '{"date":"2026-02-21","completedOutcomes":["Draft done"],"energyEnd":"med"}'
```
