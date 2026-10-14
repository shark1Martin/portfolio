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
--    Guarded so re-running this script doesn't abort here (a bare ALTER
--    PUBLICATION ... ADD TABLE errors on the second run and would skip
--    everything below it, including the storage bucket + policies).
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'secret_file'
  ) then
    alter publication supabase_realtime add table public.secret_file;
  end if;
end $$;

-- 3. Storage bucket for the uploaded file. No mime allowlist — accepts
--    (almost) any file type. 50MB cap, the Free plan maximum (Pro can
--    raise file_size_limit further). The SELECT policy below isn't for
--    public downloads
--    (those go through the public bucket's CDN path and bypass RLS) —
--    it's required so upload(..., { upsert: true }) can look up whether
--    an object already exists before deciding to insert or update it.
--    Without it, overwriting an existing upload fails with a row-level
--    security error even though the INSERT/UPDATE policies look correct.
insert into storage.buckets (id, name, public, file_size_limit)
values (
  'secret-files',
  'secret-files',
  true,
  52428800
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit;

drop policy if exists "public can read secret-files objects" on storage.objects;
create policy "public can read secret-files objects"
  on storage.objects for select
  to anon
  using (bucket_id = 'secret-files');

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
