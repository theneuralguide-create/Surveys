-- =====================================================================
-- Personal CRM — database setup (Postgres on Neon)
-- Run once against the database: Neon console -> SQL Editor -> paste the
-- whole file -> Run. Safe to re-run (idempotent).
--
-- AFTERWARDS: set your real password (see the bottom of this file).
--
-- SECURITY MODEL
--   * The database is reachable only from api/crm.js on Vercel, using the
--     DATABASE_URL secret. The page never talks to Postgres directly and
--     there is no public key of any kind.
--   * api/crm.js can only call the public.crm_* functions listed below.
--   * Every function first checks a session token. crm_login() hands one
--     out in exchange for the (bcrypt-hashed) password; the phone stores
--     the token, never the password. Sessions last 30 days.
--   * 8 wrong passwords in 15 minutes locks logins for 15 minutes.
-- =====================================================================

create schema if not exists crm;
create extension if not exists pgcrypto;

-- ---------- Tables (private schema, no API surface) ----------

-- The password, bcrypt-hashed. Never stored or transmitted in clear.
create table if not exists crm.config (
  id            int primary key default 1 check (id = 1),
  password_hash text not null
);

-- Login sessions. crm_login() hands back an opaque token; the app stores
-- the token, never the password, so a stolen phone doesn't leak the
-- password and sessions can be expired or revoked.
create table if not exists crm.sessions (
  token      text primary key,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null
);

-- Failed-login log, used to lock out brute force attempts.
create table if not exists crm.auth_attempts (
  id  bigserial primary key,
  at  timestamptz not null default now(),
  ok  boolean not null
);
create index if not exists crm_auth_attempts_at_idx on crm.auth_attempts (at);

-- ---------- Contacts: who I've spoken to ----------
create table if not exists crm.contacts (
  id             uuid primary key default gen_random_uuid(),

  -- who they are and how to reach them
  full_name      text not null,
  email          text,
  phone          text,
  linkedin       text,
  other_link     text,
  location       text,

  -- what they do, split up so it stays queryable
  company        text,
  job_title      text,
  work_area      text,          -- their actual specialism; the useful one
  seniority      text,
  industry       text,

  -- how they fit into the network
  how_we_met     text,
  introduced_by  text,
  tags           text[] not null default '{}',
  warmth         int  not null default 3 check (warmth between 1 and 5),
  cadence_days   int  not null default 0 check (cadence_days >= 0),

  -- the headline: what I might be able to do for them
  key_problem    text,
  problem_status text not null default 'open'
                 check (problem_status in ('open','exploring','solved','parked')),
  their_ask      text,          -- what they want from me
  my_ask         text,          -- what I want from them

  personal_notes text,
  notes          text,
  archived       boolean not null default false,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index if not exists crm_contacts_name_idx on crm.contacts (lower(full_name));

-- ---------- Interactions: one row per conversation ----------
-- The "list of every date we've spoken" is just these rows sorted by
-- date, so it can never drift out of sync with the conversations.
create table if not exists crm.interactions (
  id              uuid primary key default gen_random_uuid(),
  contact_id      uuid not null references crm.contacts(id) on delete cascade,
  happened_on     date not null default current_date,
  channel         text,          -- in person / call / video / email / dm / event
  context         text,          -- where, or which event
  summary         text,
  takeaways       text,          -- key takeaways
  their_cta       text,          -- their biggest call to action
  problem_spotted text,          -- a problem of theirs I might solve
  my_next_step    text,
  next_step_due   date,
  next_step_done  boolean not null default false,
  created_at      timestamptz not null default now()
);
create index if not exists crm_inter_contact_idx on crm.interactions (contact_id, happened_on desc);
create index if not exists crm_inter_due_idx     on crm.interactions (next_step_due) where next_step_done = false;

insert into crm.config (id, password_hash)
  values (1, crypt('CHANGE-ME', gen_salt('bf')))
  on conflict (id) do nothing;

-- ---------- Internal helpers (crm schema = not exposed by api/crm.js) ----------

-- Raises unless the token maps to a live session. Every public function
-- below starts with this.
create or replace function crm.guard(tok text)
returns void
language plpgsql security definer set search_path = crm, public as $$
begin
  delete from crm.sessions where expires_at < now();
  if tok is null or not exists (
    select 1 from crm.sessions s where s.token = tok and s.expires_at > now()
  ) then
    raise exception 'not signed in';
  end if;
end;
$$;

-- Trimmed text out of a jsonb payload; blank becomes null.
create or replace function crm.txt(payload jsonb, k text)
returns text
language sql immutable as $$
  select nullif(btrim(coalesce(payload ->> k, '')), '');
$$;

-- A jsonb array of strings -> text[], blanks dropped.
create or replace function crm.tags(payload jsonb)
returns text[]
language sql immutable as $$
  select coalesce(
    (select array_agg(btrim(t)) from jsonb_array_elements_text(
        case when jsonb_typeof(payload -> 'tags') = 'array' then payload -> 'tags' else '[]'::jsonb end
     ) as t where btrim(t) <> ''),
    '{}'::text[]);
$$;

-- ---------- Auth ----------

-- Returns a session token, or null if the password is wrong.
-- Locks out after 8 failures in 15 minutes.
create or replace function public.crm_login(pw text)
returns text
language plpgsql security definer set search_path = crm, public as $$
declare
  fails int;
  tok   text;
  pw_ok boolean;
begin
  delete from crm.auth_attempts where at < now() - interval '1 day';

  select count(*) into fails from crm.auth_attempts
   where ok = false and at > now() - interval '15 minutes';
  if fails >= 8 then
    raise exception 'too many failed attempts - wait 15 minutes';
  end if;

  select (c.password_hash = crypt(coalesce(pw, ''), c.password_hash))
    into pw_ok from crm.config c where c.id = 1;

  if not coalesce(pw_ok, false) then
    insert into crm.auth_attempts (ok) values (false);
    return null;
  end if;

  insert into crm.auth_attempts (ok) values (true);
  tok := encode(gen_random_bytes(24), 'hex');
  insert into crm.sessions (token, expires_at) values (tok, now() + interval '30 days');
  delete from crm.sessions where expires_at < now();
  return tok;
end;
$$;

create or replace function public.crm_logout(tok text)
returns void
language sql security definer set search_path = crm, public as $$
  delete from crm.sessions where token = tok;
$$;

-- ---------- Dashboard: everything the home screen needs, in one call ----------

create or replace function public.crm_dashboard(tok text)
returns jsonb
language plpgsql security definer set search_path = crm, public as $$
declare res jsonb;
begin
  perform crm.guard(tok);

  with roll as (
    select
      c.id, c.full_name, c.company, c.job_title, c.work_area, c.warmth,
      c.cadence_days, c.key_problem, c.problem_status, c.their_ask, c.tags,
      (select max(i.happened_on) from crm.interactions i where i.contact_id = c.id) as last_spoke_on,
      (select count(*)           from crm.interactions i where i.contact_id = c.id) as times_spoken
    from crm.contacts c
    where not c.archived
  ),
  chilled as (
    select r.*, (current_date - r.last_spoke_on) as days_since
    from roll r
    where r.cadence_days > 0
      and (r.last_spoke_on is null or (current_date - r.last_spoke_on) > r.cadence_days)
  ),
  steps as (
    select i.id, i.contact_id, c.full_name, c.company, i.my_next_step,
           i.next_step_due, i.happened_on
    from crm.interactions i
    join crm.contacts c on c.id = i.contact_id
    where i.next_step_done = false
      and coalesce(btrim(i.my_next_step), '') <> ''
      and not c.archived
  )
  select jsonb_build_object(
    'today', current_date,
    'stats', jsonb_build_object(
      'contacts',      (select count(*) from roll),
      'conversations', (select count(*) from crm.interactions),
      'overdue',       (select count(*) from steps where next_step_due is not null and next_step_due < current_date),
      'due_soon',      (select count(*) from steps where next_step_due between current_date and current_date + 7),
      'cold',          (select count(*) from chilled),
      'open_problems', (select count(*) from roll where problem_status = 'open' and coalesce(btrim(key_problem), '') <> '')
    ),
    'overdue',  coalesce((select jsonb_agg(to_jsonb(s) order by s.next_step_due)
                            from steps s where s.next_step_due is not null and s.next_step_due < current_date), '[]'::jsonb),
    'due_soon', coalesce((select jsonb_agg(to_jsonb(s) order by s.next_step_due)
                            from steps s where s.next_step_due between current_date and current_date + 7), '[]'::jsonb),
    'undated',  coalesce((select jsonb_agg(to_jsonb(s) order by s.happened_on desc)
                            from steps s where s.next_step_due is null), '[]'::jsonb),
    'cold',     coalesce((select jsonb_agg(to_jsonb(x) order by x.days_since desc nulls first)
                            from chilled x), '[]'::jsonb),
    'problems', coalesce((select jsonb_agg(to_jsonb(r) order by lower(r.full_name))
                            from roll r where r.problem_status = 'open'
                              and coalesce(btrim(r.key_problem), '') <> ''), '[]'::jsonb),
    'recent',   coalesce((select jsonb_agg(t.row) from (
                            select jsonb_build_object(
                              'id', i.id, 'contact_id', i.contact_id, 'full_name', c.full_name,
                              'happened_on', i.happened_on, 'channel', i.channel,
                              'summary', i.summary, 'takeaways', i.takeaways) as row
                            from crm.interactions i
                            join crm.contacts c on c.id = i.contact_id
                            order by i.happened_on desc, i.created_at desc
                            limit 8) t), '[]'::jsonb)
  ) into res;

  return res;
end;
$$;

-- ---------- Contacts ----------

-- Search runs across the person AND everything ever said in a
-- conversation with them, so "who mentioned hiring?" works.
create or replace function public.crm_list_contacts(tok text, q text default null, tag text default null)
returns jsonb
language plpgsql security definer set search_path = crm, public as $$
declare res jsonb; needle text;
begin
  perform crm.guard(tok);
  needle := nullif(btrim(coalesce(q, '')), '');

  with roll as (
    select c.*,
      (select max(i.happened_on) from crm.interactions i where i.contact_id = c.id) as last_spoke_on,
      (select count(*)           from crm.interactions i where i.contact_id = c.id) as times_spoken
    from crm.contacts c
  )
  select coalesce(jsonb_agg(to_jsonb(r) order by lower(r.full_name)), '[]'::jsonb) into res
  from (
    select r.*,
           case when r.cadence_days > 0
                 and (r.last_spoke_on is null or (current_date - r.last_spoke_on) > r.cadence_days)
                then true else false end as is_cold,
           (current_date - r.last_spoke_on) as days_since
    from roll r
    where not r.archived
      and (tag is null or btrim(tag) = '' or tag = any(r.tags))
      and (needle is null or
           concat_ws(' ', r.full_name, r.company, r.job_title, r.work_area, r.seniority,
                          r.industry, r.location, r.email, r.how_we_met, r.introduced_by,
                          r.key_problem, r.their_ask, r.my_ask, r.notes, r.personal_notes,
                          array_to_string(r.tags, ' ')) ilike '%' || needle || '%'
           or exists (select 1 from crm.interactions i
                       where i.contact_id = r.id
                         and concat_ws(' ', i.summary, i.takeaways, i.their_cta,
                                            i.problem_spotted, i.my_next_step, i.context)
                             ilike '%' || needle || '%'))
  ) r;

  return res;
end;
$$;

create or replace function public.crm_get_contact(tok text, p_id uuid)
returns jsonb
language plpgsql security definer set search_path = crm, public as $$
declare res jsonb;
begin
  perform crm.guard(tok);

  select to_jsonb(c) || jsonb_build_object(
    'last_spoke_on', (select max(i.happened_on) from crm.interactions i where i.contact_id = c.id),
    'times_spoken',  (select count(*)           from crm.interactions i where i.contact_id = c.id),
    'interactions',  coalesce((select jsonb_agg(to_jsonb(i) order by i.happened_on desc, i.created_at desc)
                                 from crm.interactions i where i.contact_id = c.id), '[]'::jsonb)
  ) into res
  from crm.contacts c where c.id = p_id;

  if res is null then raise exception 'contact not found'; end if;
  return res;
end;
$$;

-- Insert when payload has no id, update when it does.
create or replace function public.crm_save_contact(tok text, payload jsonb)
returns jsonb
language plpgsql security definer set search_path = crm, public as $$
declare
  cid    uuid := nullif(payload ->> 'id', '')::uuid;
  nm     text := crm.txt(payload, 'full_name');
  status text := coalesce(crm.txt(payload, 'problem_status'), 'open');
  warm   int  := coalesce(nullif(payload ->> 'warmth', '')::int, 3);
  cad    int  := coalesce(nullif(payload ->> 'cadence_days', '')::int, 0);
begin
  perform crm.guard(tok);

  if nm is null then raise exception 'a name is required'; end if;
  if status not in ('open','exploring','solved','parked') then status := 'open'; end if;
  warm := greatest(1, least(5, warm));
  cad  := greatest(0, cad);

  if cid is null then
    insert into crm.contacts (
      full_name, email, phone, linkedin, other_link, location,
      company, job_title, work_area, seniority, industry,
      how_we_met, introduced_by, tags, warmth, cadence_days,
      key_problem, problem_status, their_ask, my_ask,
      personal_notes, notes, archived)
    values (
      nm, crm.txt(payload,'email'), crm.txt(payload,'phone'), crm.txt(payload,'linkedin'),
      crm.txt(payload,'other_link'), crm.txt(payload,'location'),
      crm.txt(payload,'company'), crm.txt(payload,'job_title'), crm.txt(payload,'work_area'),
      crm.txt(payload,'seniority'), crm.txt(payload,'industry'),
      crm.txt(payload,'how_we_met'), crm.txt(payload,'introduced_by'), crm.tags(payload), warm, cad,
      crm.txt(payload,'key_problem'), status, crm.txt(payload,'their_ask'), crm.txt(payload,'my_ask'),
      crm.txt(payload,'personal_notes'), crm.txt(payload,'notes'),
      coalesce((payload ->> 'archived')::boolean, false))
    returning id into cid;
  else
    update crm.contacts set
      full_name = nm,
      email = crm.txt(payload,'email'), phone = crm.txt(payload,'phone'),
      linkedin = crm.txt(payload,'linkedin'), other_link = crm.txt(payload,'other_link'),
      location = crm.txt(payload,'location'), company = crm.txt(payload,'company'),
      job_title = crm.txt(payload,'job_title'), work_area = crm.txt(payload,'work_area'),
      seniority = crm.txt(payload,'seniority'), industry = crm.txt(payload,'industry'),
      how_we_met = crm.txt(payload,'how_we_met'), introduced_by = crm.txt(payload,'introduced_by'),
      tags = crm.tags(payload), warmth = warm, cadence_days = cad,
      key_problem = crm.txt(payload,'key_problem'), problem_status = status,
      their_ask = crm.txt(payload,'their_ask'), my_ask = crm.txt(payload,'my_ask'),
      personal_notes = crm.txt(payload,'personal_notes'), notes = crm.txt(payload,'notes'),
      archived = coalesce((payload ->> 'archived')::boolean, archived),
      updated_at = now()
    where id = cid;
    if not found then raise exception 'contact not found'; end if;
  end if;

  return public.crm_get_contact(tok, cid);
end;
$$;

create or replace function public.crm_delete_contact(tok text, p_id uuid)
returns void
language plpgsql security definer set search_path = crm, public as $$
begin
  perform crm.guard(tok);
  delete from crm.contacts where id = p_id;   -- interactions cascade
end;
$$;

-- ---------- Conversations ----------

create or replace function public.crm_save_interaction(tok text, payload jsonb)
returns jsonb
language plpgsql security definer set search_path = crm, public as $$
declare
  iid     uuid := nullif(payload ->> 'id', '')::uuid;
  cid     uuid := nullif(payload ->> 'contact_id', '')::uuid;
  on_date date := coalesce(nullif(payload ->> 'happened_on', '')::date, current_date);
  due     date := nullif(payload ->> 'next_step_due', '')::date;
  spotted text := crm.txt(payload, 'problem_spotted');
begin
  perform crm.guard(tok);
  if cid is null then raise exception 'a contact is required'; end if;
  if not exists (select 1 from crm.contacts where id = cid) then
    raise exception 'contact not found';
  end if;

  if iid is null then
    insert into crm.interactions (
      contact_id, happened_on, channel, context, summary, takeaways,
      their_cta, problem_spotted, my_next_step, next_step_due, next_step_done)
    values (
      cid, on_date, crm.txt(payload,'channel'), crm.txt(payload,'context'),
      crm.txt(payload,'summary'), crm.txt(payload,'takeaways'),
      crm.txt(payload,'their_cta'), spotted, crm.txt(payload,'my_next_step'), due,
      coalesce((payload ->> 'next_step_done')::boolean, false))
    returning id into iid;
  else
    update crm.interactions set
      contact_id = cid, happened_on = on_date,
      channel = crm.txt(payload,'channel'), context = crm.txt(payload,'context'),
      summary = crm.txt(payload,'summary'), takeaways = crm.txt(payload,'takeaways'),
      their_cta = crm.txt(payload,'their_cta'), problem_spotted = spotted,
      my_next_step = crm.txt(payload,'my_next_step'), next_step_due = due,
      next_step_done = coalesce((payload ->> 'next_step_done')::boolean, next_step_done)
    where id = iid;
    if not found then raise exception 'conversation not found'; end if;
  end if;

  -- If this is the first problem you've spotted for them, promote it to
  -- the contact's headline problem so you don't have to type it twice.
  if spotted is not null then
    update crm.contacts
       set key_problem = spotted, updated_at = now()
     where id = cid and coalesce(btrim(key_problem), '') = '';
  end if;

  return public.crm_get_contact(tok, cid);
end;
$$;

create or replace function public.crm_complete_step(tok text, p_id uuid, p_done boolean default true)
returns void
language plpgsql security definer set search_path = crm, public as $$
begin
  perform crm.guard(tok);
  update crm.interactions set next_step_done = coalesce(p_done, true) where id = p_id;
end;
$$;

create or replace function public.crm_delete_interaction(tok text, p_id uuid)
returns void
language plpgsql security definer set search_path = crm, public as $$
begin
  perform crm.guard(tok);
  delete from crm.interactions where id = p_id;
end;
$$;

-- ---------- Export (backup / CSV) ----------

create or replace function public.crm_export(tok text)
returns jsonb
language plpgsql security definer set search_path = crm, public as $$
declare res jsonb;
begin
  perform crm.guard(tok);
  select jsonb_build_object(
    'exported_at',  now(),
    'contacts',     coalesce((select jsonb_agg(to_jsonb(c) order by lower(c.full_name)) from crm.contacts c), '[]'::jsonb),
    'interactions', coalesce((select jsonb_agg(to_jsonb(i) order by i.happened_on desc) from crm.interactions i), '[]'::jsonb)
  ) into res;
  return res;
end;
$$;

-- =====================================================================
-- IMPORTANT — set your real password now. Make it long and random, and
-- do NOT reuse the survey admin password. This password is the only
-- thing standing between the open internet and your contacts' details.
--
--   update crm.config
--      set password_hash = crypt('your-long-random-password',
--                                           gen_salt('bf'))
--    where id = 1;
--
-- To sign every device out again:
--
--   delete from crm.sessions;
-- =====================================================================
