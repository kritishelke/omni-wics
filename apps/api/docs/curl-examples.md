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

Integrations status:
```bash
curl "$API_BASE_URL/integrations/status" \
  -H "Authorization: Bearer $SUPABASE_JWT"
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
curl "$API_BASE_URL/google/calendar/events?date=2026-02-22" \
  -H "Authorization: Bearer $SUPABASE_JWT"
```

Tasks:
```bash
curl "$API_BASE_URL/google/tasks" \
  -H "Authorization: Bearer $SUPABASE_JWT"
```

Create task:
```bash
curl -X POST "$API_BASE_URL/google/tasks/create" \
  -H "Authorization: Bearer $SUPABASE_JWT" \
  -H "Content-Type: application/json" \
  -d '{"title":"Review chemistry notes","dueAt":"2026-02-22T18:00:00.000Z","estimatedMinutes":45}'
```

Complete task:
```bash
curl -X POST "$API_BASE_URL/google/tasks/<task_id>/complete" \
  -H "Authorization: Bearer $SUPABASE_JWT"
```

Generate plan:
```bash
curl -X POST "$API_BASE_URL/ai/plan" \
  -H "Authorization: Bearer $SUPABASE_JWT" \
  -H "Content-Type: application/json" \
  -d '{"date":"2026-02-22","energy":"med"}'
```

Get today's plan:
```bash
curl "$API_BASE_URL/plans/today" \
  -H "Authorization: Bearer $SUPABASE_JWT"
```

Submit check-in:
```bash
curl -X POST "$API_BASE_URL/signals/checkin" \
  -H "Authorization: Bearer $SUPABASE_JWT" \
  -H "Content-Type: application/json" \
  -d '{"planBlockId":"<block_uuid>","done":false,"progress":55,"focus":6,"energy":"med","happenedTags":["distracted"],"derailReason":"social media","driftMinutes":10}'
```

Submit drift:
```bash
curl -X POST "$API_BASE_URL/signals/drift" \
  -H "Authorization: Bearer $SUPABASE_JWT" \
  -H "Content-Type: application/json" \
  -d '{"planBlockId":"<block_uuid>","minutes":7,"derailReason":"social media","apps":["YouTube"]}'
```

Start focus session signal:
```bash
curl -X POST "$API_BASE_URL/signals/focus-session-start" \
  -H "Authorization: Bearer $SUPABASE_JWT" \
  -H "Content-Type: application/json" \
  -d '{"planBlockId":"<block_uuid>","plannedMinutes":50}'
```

Manual nudge request:
```bash
curl -X POST "$API_BASE_URL/ai/nudge" \
  -H "Authorization: Bearer $SUPABASE_JWT" \
  -H "Content-Type: application/json" \
  -d '{"planBlockId":"<block_uuid>","triggerType":"manual","signalPayload":{"reason":"swap requested"}}'
```

Break task into subtasks:
```bash
curl -X POST "$API_BASE_URL/ai/breakdown" \
  -H "Authorization: Bearer $SUPABASE_JWT" \
  -H "Content-Type: application/json" \
  -d '{"title":"Study for biology exam","dueAt":"2026-02-24T17:00:00.000Z"}'
```

Insights today:
```bash
curl "$API_BASE_URL/insights/today" \
  -H "Authorization: Bearer $SUPABASE_JWT"
```

Rewards weekly:
```bash
curl "$API_BASE_URL/rewards/weekly" \
  -H "Authorization: Bearer $SUPABASE_JWT"
```

Claim weekly reward:
```bash
curl -X POST "$API_BASE_URL/rewards/claim" \
  -H "Authorization: Bearer $SUPABASE_JWT" \
  -H "Content-Type: application/json" \
  -d '{}'
```
