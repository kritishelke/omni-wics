# Omni MVP Monorepo

Omni MVP with:
- iOS SwiftUI app (`apps/ios`) with onboarding + tabs: `Dashboard`, `Calendar`, `Feedback`, `Reward`, `Settings`
- NestJS API (`apps/api`) with Supabase auth verification, Google Calendar/Tasks integration, Gemini plan/nudge/breakdown/day-close endpoints
- Shared API contracts (`packages/shared`) with Zod schemas
- Supabase SQL migrations + RLS (`supabase/migrations`)
- Manual drift + AI check-in flow (no Screen Time entitlement required)

## Repo Layout

```text
.
├── apps
│   ├── api
│   └── ios
├── packages
│   └── shared
├── supabase
│   ├── migrations
│   └── README.md
├── .env.example
└── README.md
```

## 1) Supabase Setup

1. Create a Supabase project.
2. Copy `apps/api/.env.example` to `apps/api/.env` and set:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `SUPABASE_SERVICE_ROLE_KEY`
3. Run SQL migrations in order:
   - `supabase/migrations/001_init.sql`
   - `supabase/migrations/002_profile_toggles_and_focus_signal.sql`
4. In Supabase Auth providers, ensure **Email** auth is enabled.

## 2) Google OAuth Setup

1. In Google Cloud, enable:
   - Google Calendar API
   - Google Tasks API
2. Create OAuth client credentials with **Web application** type.
3. Add redirect URI:
   - local: `http://localhost:3001/v1/google/oauth/callback`
   - if using ngrok: `https://<your-ngrok-domain>/v1/google/oauth/callback`
4. Set in `apps/api/.env`:
   - `GOOGLE_CLIENT_ID`
   - `GOOGLE_CLIENT_SECRET`
   - `GOOGLE_OAUTH_REDIRECT_URL`

## 3) Gemini Setup

1. Create Gemini API key.
2. Add to `apps/api/.env`:
   - `GEMINI_API_KEY`
   - optional `GEMINI_MODEL` (default `gemini-2.0-flash`)

## 4) Backend Run

```bash
pnpm i
pnpm --filter api dev
```

Health check (local):
```bash
curl http://localhost:3001/v1/health
```

Health check (ngrok):
```bash
curl -H "ngrok-skip-browser-warning: true" https://<your-ngrok-domain>/v1/health
```

API docs/examples:
- `apps/api/docs/curl-examples.md`
- `apps/api/docs/postman_collection.json`

## 5) iOS Run

1. Open `apps/ios/Omni.xcodeproj`.
2. Copy `apps/ios/Omni/Config/Secrets.example.plist` to `apps/ios/Omni/Config/Secrets.plist` and set:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `API_BASE_URL` (localhost or ngrok HTTPS URL)
   - `IOS_OAUTH_CALLBACK_SCHEME` (`omni` by default)
3. Ensure bundle id + signing team are set for the `Omni` target.
4. Ensure `URL Types` contains the `omni` scheme for OAuth callback.
5. Run `Omni` scheme on your iPhone.

## 6) Manual End-to-End Script

1. Sign in with email/password.
2. Connect Google.
3. Generate a plan.
4. Dashboard shows current task + upcoming task + upcoming event.
5. Start focus session, submit check-in, press drift.
6. Calendar shows Google events + Omni blocks + add task.
7. Feedback shows drift + focus window + derail + burnout summary.
8. Reward shows score + weekly consistency + badges.
9. Settings shows integrations + toggles + sign out.

## Happy Path Integration Checklist

- [ ] `GET /v1/health` returns `{ ok: true }`
- [ ] Missing bearer token is rejected on protected routes
- [ ] Google OAuth connect writes `google_connections`
- [ ] `GET /v1/google/calendar/events?date=YYYY-MM-DD` returns normalized events
- [ ] `GET /v1/google/tasks` returns normalized tasks
- [ ] `POST /v1/google/tasks/:taskId/complete` completes + updates cache
- [ ] `POST /v1/ai/plan` writes idempotent `plans` + `plan_blocks`
- [ ] `POST /v1/signals/checkin` stores progress/focus/driftMinutes
- [ ] `POST /v1/signals/drift` logs drift and can return nudge
- [ ] `GET /v1/insights/today` returns feedback metrics
- [ ] `GET /v1/rewards/weekly` returns score/streak/badges

## Tests

Run backend tests:
```bash
pnpm --filter api test -- --watchman=false
```

Included minimal Jest tests:
- auth guard rejects missing token
- `/ai/plan` response validates against schema
- token encryption/decryption round-trip
- plan + blocks idempotent write behavior per user/date

## Troubleshooting

- `401 Invalid Supabase token`: verify iOS session token is sent in `Authorization: Bearer ...`.
- Google callback fails: confirm redirect URI exact match in Google Cloud and `.env`.
- `TOKEN_ENCRYPTION_KEY` errors: provide exactly 32-byte raw/base64 or 64-char hex.
- ngrok 404/offline: start backend first, then run `ngrok http 3001`.
- If notifications do not route tabs, verify app notification permission is granted.
