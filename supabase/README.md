# Supabase Setup

## 1) Create project
Create a new Supabase project and copy:
- Project URL
- `anon` key
- `service_role` key

Use these in `apps/api/.env` and iOS secrets.

## 2) Run migrations
Option A (Supabase CLI):
```bash
supabase db push --db-url "<your-postgres-connection-string>"
```

Option B (Dashboard SQL editor):
1. Open SQL Editor.
2. Run files from `supabase/migrations` in order.

## 3) Auth provider configuration
Enable Apple provider in Authentication -> Providers.

## 4) Redirect URLs
For local development, add any required redirect URL entries in Authentication settings.
Typical values:
- iOS deep link callback: `omni://oauth/google`
- API callback endpoint: `http://localhost:3001/v1/google/oauth/callback`

## 5) Notes
- RLS is enabled for all Omni app tables.
- Service role is used by the backend for server-side operations.
- User-scoped routes enforce `user_id = auth.uid()` semantics at the application and policy layers.
