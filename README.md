# Omni MVP Monorepo

Omni MVP with:
- iOS SwiftUI app (`apps/ios`) with onboarding + tabs: `Now`, `Today`, `Tasks`, `Insights`, `Settings`
- NestJS API (`apps/api`) with Supabase auth verification, Google Calendar/Tasks integration, Gemini plan/nudge/breakdown/day-close endpoints
- Shared API contracts (`packages/shared`) with Zod schemas
- Supabase SQL migrations + RLS (`supabase/migrations`)
- Screen Time scaffolding (FamilyControls + DeviceActivity + manual drift fallback)

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
2. Copy:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `SUPABASE_SERVICE_ROLE_KEY`
3. Copy `apps/api/.env.example` to `apps/api/.env` and fill values.
4. Run SQL migrations from `supabase/migrations/001_init.sql`.
   - CLI: `supabase db push` (or run SQL in dashboard editor).
5. In Supabase Auth providers, enable Apple.
6. Add local redirect URLs if needed (including app callback `omni://...`).

## 2) Google OAuth Setup

1. In Google Cloud:
   - Enable **Google Calendar API**
   - Enable **Google Tasks API**
2. Create OAuth Client Credentials.
3. Add redirect URI:
   - `http://localhost:3001/v1/google/oauth/callback`
4. Put values in `apps/api/.env`:
   - `GOOGLE_CLIENT_ID`
   - `GOOGLE_CLIENT_SECRET`

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

Health check:
```bash
curl http://localhost:3001/v1/health
```

API docs/examples:
- `apps/api/docs/curl-examples.md`
- `apps/api/docs/postman_collection.json`

## 5) iOS Run

1. Open `apps/ios/Omni.xcodeproj` in Xcode.
2. Copy `apps/ios/Omni/Config/Secrets.example.plist` -> `apps/ios/Omni/Config/Secrets.plist` and fill:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `API_BASE_URL`
   - `IOS_OAUTH_CALLBACK_SCHEME` (default `omni`)
   - `APP_GROUP_ID`
3. Set bundle IDs, signing team, and App Group in both targets:
   - `Omni`
   - `OmniDeviceActivityMonitor`
4. Run on physical device for Screen Time flows.
   - Simulator fallback: manual drift button in `Now`/`BlockDetail`.

## 6) Verify End-to-End

1. Sign in with Apple.
2. Connect Google.
3. Fetch Google tasks.
4. Generate day plan.
5. Use `Now` actions:
   - done
   - check-in
   - drift
   - swap
   - breakdown
6. Run day close and verify summary response.

## Happy Path Integration Checklist

- [ ] `GET /v1/health` returns `{ ok: true }`
- [ ] Missing bearer token is rejected on protected routes
- [ ] Google OAuth connect writes `google_connections`
- [ ] `GET /v1/google/calendar/events?date=YYYY-MM-DD` returns normalized events
- [ ] `GET /v1/google/tasks` returns normalized tasks
- [ ] `POST /v1/google/tasks/:taskId/complete` completes + updates cache
- [ ] `POST /v1/ai/plan` writes idempotent `plans` + `plan_blocks`
- [ ] `POST /v1/signals/drift` creates signal and nudge path works
- [ ] `POST /v1/ai/day-close` writes `daily_logs`

## Tests

Run backend tests:
```bash
pnpm --filter api test
```

Included minimal Jest tests:
- auth guard rejects missing token
- `/ai/plan` response validates against schema
- token encryption/decryption round-trip
- plan + blocks idempotent write behavior per user/date

## Screen Time Notes

- Feature is scaffolded behind runtime enablement.
- If authorization denied/unavailable, app continues with manual drift workflow.
- Update placeholder App Group (`group.com.example.omni`) in:
  - `apps/ios/Omni/Config/Secrets.plist`
  - `apps/ios/Omni/Omni.entitlements`
  - `apps/ios/OmniDeviceActivityMonitor/OmniDeviceActivityMonitor.entitlements`
  - `apps/ios/OmniDeviceActivityMonitor/OmniDeviceActivityMonitor.swift`

## Troubleshooting

- `401 Invalid Supabase token`: verify iOS session token is being sent in `Authorization: Bearer ...`.
- Google callback fails: confirm redirect URI exact match in Google Cloud and API `.env`.
- `TOKEN_ENCRYPTION_KEY` errors: provide exactly 32-byte raw/base64 or 64-char hex.
- Screen Time APIs fail: test on real device with required entitlement enabled.
