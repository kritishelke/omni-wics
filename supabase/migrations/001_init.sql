create extension if not exists pgcrypto;

create table if not exists public.user_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  coach_mode text not null default 'balanced' check (coach_mode in ('gentle', 'balanced', 'strict')),
  checkin_cadence_minutes integer not null default 60,
  sleep_time text,
  wake_time text,
  energy_profile jsonb not null default '{}'::jsonb,
  distraction_profile jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.google_connections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  google_sub text,
  scopes text not null,
  access_token_enc text not null,
  refresh_token_enc text,
  expiry_ts timestamptz,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique(user_id)
);

create table if not exists public.calendar_events_cache (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  source_id text not null,
  start_at timestamptz not null,
  end_at timestamptz not null,
  title text not null,
  location text,
  raw jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(user_id, source_id)
);

create table if not exists public.task_lists (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  google_tasklist_id text not null,
  title text not null,
  raw jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(user_id, google_tasklist_id)
);

create table if not exists public.tasks_cache (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  google_task_id text not null,
  google_tasklist_id text not null,
  title text not null,
  notes text,
  due_at timestamptz,
  status text not null,
  parent_task_id text,
  updated_at timestamptz not null default now(),
  raw jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(user_id, google_task_id)
);

create table if not exists public.plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  plan_date date not null,
  top_outcomes jsonb not null default '[]'::jsonb,
  shutdown_suggestion text,
  risk_flags jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  unique(user_id, plan_date)
);

create table if not exists public.plan_blocks (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.plans(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  start_at timestamptz not null,
  end_at timestamptz not null,
  type text not null check (type in ('task', 'sticky', 'break')),
  google_task_id text,
  label text not null,
  rationale text not null,
  priority_score numeric not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.signals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  type text not null check (type in ('drift', 'checkin', 'overload', 'deadlineRisk', 'manualSwap')),
  ts timestamptz not null default now(),
  related_block_id uuid references public.plan_blocks(id) on delete set null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.nudges (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  ts timestamptz not null default now(),
  trigger_type text not null check (trigger_type in ('cadence', 'drift', 'deadline', 'manual')),
  recommended_action text not null,
  alternatives jsonb not null default '[]'::jsonb,
  accepted_action text,
  related_block_id uuid references public.plan_blocks(id) on delete set null,
  rationale text,
  created_at timestamptz not null default now()
);

create table if not exists public.daily_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  log_date date not null,
  summary text not null,
  completed_outcomes jsonb not null default '[]'::jsonb,
  biggest_blocker text,
  energy_end text,
  created_at timestamptz not null default now(),
  unique(user_id, log_date)
);

create table if not exists public.task_breakdowns (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  google_task_id text,
  parent_title text not null,
  subtasks jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_plans_user_date on public.plans (user_id, plan_date);
create index if not exists idx_plan_blocks_user on public.plan_blocks (user_id);
create index if not exists idx_signals_user_ts on public.signals (user_id, ts desc);
create index if not exists idx_nudges_user_ts on public.nudges (user_id, ts desc);

alter table public.user_profiles enable row level security;
alter table public.google_connections enable row level security;
alter table public.calendar_events_cache enable row level security;
alter table public.task_lists enable row level security;
alter table public.tasks_cache enable row level security;
alter table public.plans enable row level security;
alter table public.plan_blocks enable row level security;
alter table public.signals enable row level security;
alter table public.nudges enable row level security;
alter table public.daily_logs enable row level security;
alter table public.task_breakdowns enable row level security;

drop policy if exists "user_profiles_owner" on public.user_profiles;
create policy "user_profiles_owner"
  on public.user_profiles
  for all
  using (id = auth.uid())
  with check (id = auth.uid());

drop policy if exists "google_connections_owner" on public.google_connections;
create policy "google_connections_owner"
  on public.google_connections
  for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "calendar_events_cache_owner" on public.calendar_events_cache;
create policy "calendar_events_cache_owner"
  on public.calendar_events_cache
  for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "task_lists_owner" on public.task_lists;
create policy "task_lists_owner"
  on public.task_lists
  for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "tasks_cache_owner" on public.tasks_cache;
create policy "tasks_cache_owner"
  on public.tasks_cache
  for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "plans_owner" on public.plans;
create policy "plans_owner"
  on public.plans
  for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "plan_blocks_owner" on public.plan_blocks;
create policy "plan_blocks_owner"
  on public.plan_blocks
  for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "signals_owner" on public.signals;
create policy "signals_owner"
  on public.signals
  for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "nudges_owner" on public.nudges;
create policy "nudges_owner"
  on public.nudges
  for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "daily_logs_owner" on public.daily_logs;
create policy "daily_logs_owner"
  on public.daily_logs
  for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "task_breakdowns_owner" on public.task_breakdowns;
create policy "task_breakdowns_owner"
  on public.task_breakdowns
  for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());
