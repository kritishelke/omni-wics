alter table public.user_profiles
  add column if not exists sleep_suggestions_enabled boolean not null default true,
  add column if not exists pause_monitoring boolean not null default false,
  add column if not exists push_notifications_enabled boolean not null default true;

alter table public.signals
  drop constraint if exists signals_type_check;

alter table public.signals
  add constraint signals_type_check
  check (type in ('drift', 'checkin', 'overload', 'deadlineRisk', 'manualSwap', 'focusSessionStart'));
