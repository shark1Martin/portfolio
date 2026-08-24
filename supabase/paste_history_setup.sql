-- Run this once in the Supabase SQL editor (Project → SQL Editor → New query)
-- for the /method page's paste history side panel. Additive alongside
-- secret_paste_setup.sql — does not touch the secret_paste table, the
-- secret_file table, or their existing storage policies. Assumes
-- secret_paste_setup.sql has already been run: this script reuses the
-- secret-uploads bucket it creates and only adds one new policy on it.

-- 1. Table: append-only history log, capped at 5 rows client-side (both by
--    routine post-insert pruning and by quota-eviction). Unlike
--    secret_paste/secret_file, this table intentionally grants anon INSERT
--    and DELETE — history has real row lifecycle (append + prune), not a
--    single fixed row that only gets overwritten. Accepted trade-off:
--    since this page is already fully open/unauthenticated with no
--    per-row ownership, any visitor can also insert/delete history rows
--    directly via the REST API, not just through this page's UI — same
--    spirit as the rest of /method ("anyone with this link can... delete it").
create table if not exists public.paste_history (
  id bigint generated always as identity primary key,
  content_type text not null check (content_type in ('text', 'image')),
  content text check (char_length(content) <= 5000000),
  image_path text,
  image_mime text,
  created_at timestamptz not null default now()
);

alter table public.paste_history enable row level security;

drop policy if exists "public can read paste history" on public.paste_history;
create policy "public can read paste history"
  on public.paste_history for select
  to anon
  using (true);

drop policy if exists "public can add paste history" on public.paste_history;
create policy "public can add paste history"
  on public.paste_history for insert
  to anon
  with check (true);

drop policy if exists "public can delete paste history" on public.paste_history;
create policy "public can delete paste history"
  on public.paste_history for delete
  to anon
  using (true);

-- 2. Realtime: lets open tabs see history updates from other visitors
--    live. Guarded so re-running this script doesn't abort here (a bare
--    ALTER PUBLICATION ... ADD TABLE errors on the second run).
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'paste_history'
  ) then
    alter publication supabase_realtime add table public.paste_history;
  end if;
end $$;

-- 3. Storage: history images reuse the existing secret-uploads bucket
--    (already has the right 5MB cap + image mime allowlist) under a new
--    history/<uuid> path prefix, distinct from the paste section's fixed
--    "current" key. The existing SELECT/INSERT/UPDATE policies from
--    secret_paste_setup.sql are scoped only by bucket_id (not by object
--    name), so they already cover history/* paths — nothing to add for
--    those. Only DELETE is new (the existing setup never added one).
--    Scoped to the history/ prefix specifically — NOT bucket-wide — so
--    this feature can't be used to delete the main panel's "current"
--    image via a direct Storage API call.
drop policy if exists "public can delete secret-uploads history objects" on storage.objects;
create policy "public can delete secret-uploads history objects"
  on storage.objects for delete
  to anon
  using (bucket_id = 'secret-uploads' and name like 'history/%');
