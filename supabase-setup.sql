-- =====================================================================
-- Survey Hub — Supabase setup
-- Run this once in your Supabase project: Dashboard → SQL Editor →
-- paste the whole file → Run. Safe to re-run (idempotent).
--
-- AFTERWARDS: change the admin password (see the bottom of this file).
-- =====================================================================

-- ---------- Tables ----------

create table if not exists public.surveys (
  id          uuid primary key default gen_random_uuid(),
  slug        text unique not null,
  title       text not null,
  description text not null default '',
  url         text not null,
  status      text not null default 'live' check (status in ('live','draft','closed')),
  est_minutes text not null default '5-8',
  sort_order  int  not null default 0,
  created_at  timestamptz not null default now()
);

create table if not exists public.responses (
  id           uuid primary key default gen_random_uuid(),
  survey_slug  text not null,
  variant      text,
  answers      jsonb not null,
  submitted_at timestamptz not null default now()
);

create index if not exists responses_slug_idx on public.responses (survey_slug, submitted_at);

-- Holds the admin password. RLS is enabled with NO policies, so it can
-- never be read through the public API — only the SECURITY DEFINER
-- functions below can see it.
create table if not exists public.admin_config (
  id       int primary key default 1 check (id = 1),
  password text not null
);
insert into public.admin_config (id, password)
  values (1, 'CHANGE-ME')
  on conflict (id) do nothing;

-- ---------- Row Level Security ----------

alter table public.surveys      enable row level security;
alter table public.responses    enable row level security;
alter table public.admin_config enable row level security;

-- Anyone may see live surveys (powers the public directory page).
drop policy if exists "public read live surveys" on public.surveys;
create policy "public read live surveys" on public.surveys
  for select using (status = 'live');

-- Anyone may submit a response (that's how surveys save answers).
drop policy if exists "public insert responses" on public.responses;
create policy "public insert responses" on public.responses
  for insert with check (true);

-- Anyone may read responses. Responses are anonymous by design; this
-- powers the live "how you compare" section on survey results pages.
-- If you'd rather keep raw data private, delete this policy — surveys
-- will then fall back to their built-in reference sample, and you can
-- read data via the admin functions below instead.
drop policy if exists "public read responses" on public.responses;
create policy "public read responses" on public.responses
  for select using (true);

-- ---------- Admin functions (password-checked, SECURITY DEFINER) ----------

create or replace function public.admin_check(pw text)
returns boolean
language sql security definer set search_path = public as $$
  select exists(select 1 from admin_config where id = 1 and password = pw);
$$;

create or replace function public.admin_list_surveys(pw text)
returns setof public.surveys
language plpgsql security definer set search_path = public as $$
begin
  if not admin_check(pw) then raise exception 'invalid admin password'; end if;
  return query select * from surveys order by sort_order, created_at;
end;
$$;

create or replace function public.admin_upsert_survey(
  pw text, p_slug text, p_title text, p_description text,
  p_url text, p_status text, p_est_minutes text, p_sort_order int
) returns public.surveys
language plpgsql security definer set search_path = public as $$
declare result public.surveys;
begin
  if not admin_check(pw) then raise exception 'invalid admin password'; end if;
  insert into surveys (slug, title, description, url, status, est_minutes, sort_order)
    values (p_slug, p_title, p_description, p_url, p_status, p_est_minutes, p_sort_order)
  on conflict (slug) do update set
    title = excluded.title, description = excluded.description,
    url = excluded.url, status = excluded.status,
    est_minutes = excluded.est_minutes, sort_order = excluded.sort_order
  returning * into result;
  return result;
end;
$$;

create or replace function public.admin_delete_survey(pw text, p_slug text)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if not admin_check(pw) then raise exception 'invalid admin password'; end if;
  delete from surveys where slug = p_slug;
end;
$$;

create or replace function public.admin_delete_response(pw text, p_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if not admin_check(pw) then raise exception 'invalid admin password'; end if;
  delete from responses where id = p_id;
end;
$$;

-- ---------- Seed: register the first survey ----------

insert into public.surveys (slug, title, description, url, status, est_minutes, sort_order)
values (
  'decision-making',
  'Decision-Making Under Uncertainty',
  'How do you weigh risk, reward, and the things that can never be undone? There are no right answers — only your honest ones.',
  'surveys/decision-making-survey.html',
  'live', '5-8', 0
)
on conflict (slug) do nothing;

-- =====================================================================
-- IMPORTANT — set your real admin password now (pick your own):
--
--   update public.admin_config set password = 'your-strong-password' where id = 1;
--
-- =====================================================================
