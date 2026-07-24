-- Run this once in the Supabase SQL editor (Project → SQL Editor → New query)
-- for the file upload/download box on the /method shared-clipboard page.

-- 1. Table: exactly one row (id = 1), same single-slot pattern as
--    secret_paste. No public INSERT/DELETE policy, so the row count can
--    never change from the client — only its content can be overwritten.
create table if not exists public.secret_file (
  id integer primary key default 1,
  file_name text,
  file_mime text,
  file_size bigint,
  updated_at timestamptz not null default now(),
  constraint single_row check (id = 1)
);

insert into public.secret_file (id) values (1)
  on conflict (id) do nothing;

alter table public.secret_file enable row level security;

drop policy if exists "public can read the file" on public.secret_file;
create policy "public can read the file"
  on public.secret_file for select
  to anon
  using (true);

drop policy if exists "public can update the file" on public.secret_file;
create policy "public can update the file"
  on public.secret_file for update
  to anon
  using (id = 1)
  with check (id = 1);

-- 2. Realtime: lets open tabs see updates from other visitors live.
alter publication supabase_realtime add table public.secret_file;

-- 3. Storage bucket for the uploaded file. Public bucket so reads don't
--    need a policy. No mime allowlist — accepts (almost) any file type.
--    20MB cap; raise file_size_limit if you need bigger files.
insert into storage.buckets (id, name, public, file_size_limit)
values (
  'secret-files',
  'secret-files',
  true,
  20971520
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit;

drop policy if exists "public can upload to secret-files" on storage.objects;
create policy "public can upload to secret-files"
  on storage.objects for insert
  to anon
  with check (bucket_id = 'secret-files');

drop policy if exists "public can overwrite secret-files" on storage.objects;
create policy "public can overwrite secret-files"
  on storage.objects for update
  to anon
  using (bucket_id = 'secret-files')
  with check (bucket_id = 'secret-files');
