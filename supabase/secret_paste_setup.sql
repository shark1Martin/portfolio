-- Run this once in the Supabase SQL editor (Project → SQL Editor → New query)
-- for the /secret shared-clipboard page.

-- 1. Table: exactly one row (id = 1). No public INSERT/DELETE policy is
--    granted, so the row count can never change from the client — only its
--    content can be overwritten.
create table if not exists public.secret_paste (
  id integer primary key default 1,
  content_type text check (content_type in ('text', 'image')),
  content text check (char_length(content) <= 5000000),
  image_mime text,
  updated_at timestamptz not null default now(),
  constraint single_row check (id = 1)
);

insert into public.secret_paste (id) values (1)
  on conflict (id) do nothing;

-- Raises the limit on tables created before this was bumped from 50,000 to
-- 5,000,000 characters (create table if not exists above won't touch an
-- already-existing table's constraints).
alter table public.secret_paste drop constraint if exists secret_paste_content_check;
alter table public.secret_paste add constraint secret_paste_content_check
  check (char_length(content) <= 5000000);

alter table public.secret_paste enable row level security;

drop policy if exists "public can read the paste" on public.secret_paste;
create policy "public can read the paste"
  on public.secret_paste for select
  to anon
  using (true);

drop policy if exists "public can update the paste" on public.secret_paste;
create policy "public can update the paste"
  on public.secret_paste for update
  to anon
  using (id = 1)
  with check (id = 1);

-- 2. Realtime: lets open tabs see updates from other visitors live.
--    Guarded so re-running this script doesn't abort here (a bare ALTER
--    PUBLICATION ... ADD TABLE errors on the second run and would skip
--    everything below it, including the storage bucket + policies).
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'secret_paste'
  ) then
    alter publication supabase_realtime add table public.secret_paste;
  end if;
end $$;

-- 3. Storage bucket for the (optional) pasted image. Public bucket so
--    reads don't need a policy; 5MB cap and image-only mime allowlist are
--    enforced server-side here, not just in the client.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'secret-uploads',
  'secret-uploads',
  true,
  5242880,
  array['image/png', 'image/jpeg', 'image/gif', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Needed even though the bucket is public: upload(..., { upsert: true })
-- looks up whether the object already exists before deciding to insert or
-- update it. Without this SELECT policy, that lookup is blocked by RLS and
-- the upload fails with "new row violates row-level security policy" even
-- though the INSERT/UPDATE policies below look correct.
drop policy if exists "public can read secret-uploads objects" on storage.objects;
create policy "public can read secret-uploads objects"
  on storage.objects for select
  to anon
  using (bucket_id = 'secret-uploads');

drop policy if exists "public can upload to secret-uploads" on storage.objects;
create policy "public can upload to secret-uploads"
  on storage.objects for insert
  to anon
  with check (bucket_id = 'secret-uploads');

drop policy if exists "public can overwrite secret-uploads" on storage.objects;
create policy "public can overwrite secret-uploads"
  on storage.objects for update
  to anon
  using (bucket_id = 'secret-uploads')
  with check (bucket_id = 'secret-uploads');
