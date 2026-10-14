-- Run this once in the Supabase SQL editor (Project → SQL Editor → New query)
-- for the v2 shared-clipboard page. Run it after secret_paste_setup.sql,
-- secret_file_setup.sql and paste_history_setup.sql. Safe to re-run.
--
-- What changes:
-- 1. paste_history becomes the clipboard itself. Every paste is one row,
--    and the newest text and the newest screenshot are "latest". The page
--    no longer reads or writes secret_paste or the secret-uploads/current
--    object. Both are left in place (not dropped) so nothing is lost.
-- 2. Old entries can be moved back to the top (clip_bump).
-- 3. Deleting the uploaded file now deletes the stored object too, and the
--    file size limit goes from 20MB to 50MB.
-- 4. Read-only GET endpoints for scripts and agents (clip_* functions).

-- 1. History is ordered by created_at (so it can be bumped), not by id.
create index if not exists paste_history_type_created_idx
  on public.paste_history (content_type, created_at desc, id desc);

-- Carry over the current text paste if history doesn't already have it.
-- The old page saved secret_paste first and history second, so the two
-- could drift apart.
insert into public.paste_history (content_type, content, created_at)
select 'text', sp.content, sp.updated_at
from public.secret_paste sp
where sp.id = 1
  and sp.content_type = 'text'
  and sp.content is not null
  and not exists (
    select 1 from public.paste_history ph
    where ph.content_type = 'text' and ph.content = sp.content
  );

-- 2. Bump. anon may update created_at and nothing else (column-level
--    grant), so an UPDATE can't rewrite someone's paste content.
revoke update on public.paste_history from anon;
grant update (created_at) on public.paste_history to anon;

drop policy if exists "public can bump paste history" on public.paste_history;
create policy "public can bump paste history"
  on public.paste_history for update
  to anon
  using (true)
  with check (true);

-- Uses the server clock, so two PCs with drifting clocks still agree on
-- which entry is newest.
create or replace function public.clip_bump(item_id bigint)
returns void
language sql
as $$
  update public.paste_history set created_at = now() where id = item_id;
$$;

grant execute on function public.clip_bump(bigint) to anon;

-- 3. Uploaded file. New uploads go to <uuid>/<filename> instead of a
--    fixed "current" key, so the public URL ends in the real file name
--    and the previous object can be removed after a replace or delete.
alter table public.secret_file add column if not exists file_path text;

update public.secret_file set file_path = 'current'
  where id = 1 and file_name is not null and file_path is null;

-- 50MB per file, the most the Free plan allows (its project-wide upload
-- cap is 50MB, so a higher bucket limit wouldn't take effect anyway).
update storage.buckets set file_size_limit = 52428800 where id = 'secret-files';

drop policy if exists "public can delete secret-files objects" on storage.objects;
create policy "public can delete secret-files objects"
  on storage.objects for delete
  to anon
  using (bucket_id = 'secret-files');

-- 4. GET endpoints, e.g.
--      GET <SUPABASE_URL>/rest/v1/rpc/clip_text?apikey=<ANON_KEY>
--    The API gateway accepts the key as a query parameter, so no headers
--    are needed. All are STABLE (PostgREST only allows GET on STABLE or
--    IMMUTABLE functions) and run as the caller, so the read policies
--    above still apply.
--
--    They return the "*/*" domain, which PostgREST serves for any Accept
--    header (none, curl's, a browser's), sending the bytes as-is with the
--    Content-Type the function sets. A "text/plain" domain only applies
--    when the client explicitly asks for text/plain; everyone else gets a
--    JSON-quoted string.
--
--    Dropped first because CREATE OR REPLACE can't change a return type
--    or add parameters (earlier versions of this script returned a
--    "text/plain" domain and had no n parameter).
drop function if exists public.clip_text(bigint);
drop function if exists public.clip_text(bigint, integer);
drop function if exists public.clip_image(bigint);
drop function if exists public.clip_image(bigint, integer);
drop function if exists public.clip_file();
drop domain if exists public."text/plain";

do $$
begin
  if not exists (
    select 1 from pg_type
    where typname = '*/*' and typnamespace = 'public'::regnamespace
  ) then
    create domain public."*/*" as bytea;
  end if;
end $$;

-- Latest text. &n=2 is the one before it, &n=3 the one before that, and
-- so on (n counts back from the newest, 1 = newest). Or a specific one
-- with &id=<id>, which ignores n.
create function public.clip_text(id bigint default null, n integer default 1)
returns public."*/*"
language plpgsql
stable
as $$
declare
  body text;
begin
  select ph.content into body
  from public.paste_history ph
  where ph.content_type = 'text'
    and (clip_text.id is null or ph.id = clip_text.id)
  order by ph.created_at desc, ph.id desc
  offset case when clip_text.id is null then greatest(clip_text.n, 1) - 1 else 0 end
  limit 1;

  perform set_config('response.headers', '[{"Content-Type": "text/plain; charset=utf-8"}]', true);
  if body is null then
    perform set_config('response.status', '404', true);
    body := 'No text.';
  end if;
  return convert_to(body, 'UTF8');
end;
$$;

-- Latest screenshot, with &n and &id working as in clip_text. Redirects to
-- the public image. The Location is relative to the Supabase URL, which
-- curl -L and browsers resolve against the request URL.
create function public.clip_image(id bigint default null, n integer default 1)
returns public."*/*"
language plpgsql
stable
as $$
declare
  target text;
begin
  select '/storage/v1/object/public/secret-uploads/' || ph.image_path into target
  from public.paste_history ph
  where ph.content_type = 'image'
    and ph.image_path is not null
    and (clip_image.id is null or ph.id = clip_image.id)
  order by ph.created_at desc, ph.id desc
  offset case when clip_image.id is null then greatest(clip_image.n, 1) - 1 else 0 end
  limit 1;

  if target is null then
    perform set_config('response.headers', '[{"Content-Type": "text/plain; charset=utf-8"}]', true);
    perform set_config('response.status', '404', true);
    return convert_to('No screenshot.', 'UTF8');
  end if;

  perform set_config('response.status', '302', true);
  perform set_config('response.headers', json_build_array(
    json_build_object('Content-Type', 'text/plain; charset=utf-8'),
    json_build_object('Location', target))::text, true);
  return convert_to(target, 'UTF8');
end;
$$;

-- The uploaded file. Redirects to the public file.
create function public.clip_file()
returns public."*/*"
language plpgsql
stable
as $$
declare
  target text;
begin
  select '/storage/v1/object/public/secret-files/' || sf.file_path into target
  from public.secret_file sf
  where sf.id = 1 and sf.file_name is not null and sf.file_path is not null;

  if target is null then
    perform set_config('response.headers', '[{"Content-Type": "text/plain; charset=utf-8"}]', true);
    perform set_config('response.status', '404', true);
    return convert_to('No file.', 'UTF8');
  end if;

  perform set_config('response.status', '302', true);
  perform set_config('response.headers', json_build_array(
    json_build_object('Content-Type', 'text/plain; charset=utf-8'),
    json_build_object('Location', target))::text, true);
  return convert_to(target, 'UTF8');
end;
$$;

-- Everything at once: the latest text in full, the latest screenshot, the
-- file, and the last 20 of each type with ids (texts as 200-char previews;
-- fetch a full one with clip_text?id=<id>). URLs are relative to the
-- Supabase URL.
create or replace function public.clip_state()
returns json
language sql
stable
as $$
  select json_build_object(
    'text', (
      select json_build_object(
        'id', ph.id,
        'created_at', ph.created_at,
        'length', char_length(ph.content),
        'content', ph.content)
      from public.paste_history ph
      where ph.content_type = 'text'
      order by ph.created_at desc, ph.id desc
      limit 1),
    'screenshot', (
      select json_build_object(
        'id', ph.id,
        'created_at', ph.created_at,
        'mime', ph.image_mime,
        'url', '/storage/v1/object/public/secret-uploads/' || ph.image_path)
      from public.paste_history ph
      where ph.content_type = 'image' and ph.image_path is not null
      order by ph.created_at desc, ph.id desc
      limit 1),
    'file', (
      select json_build_object(
        'name', sf.file_name,
        'mime', sf.file_mime,
        'size', sf.file_size,
        'updated_at', sf.updated_at,
        'url', '/storage/v1/object/public/secret-files/' || sf.file_path)
      from public.secret_file sf
      where sf.id = 1 and sf.file_name is not null),
    'texts', coalesce((
      select json_agg(json_build_object(
        'id', t.id,
        'created_at', t.created_at,
        'length', char_length(t.content),
        'preview', left(t.content, 200)) order by t.created_at desc, t.id desc)
      from (
        select * from public.paste_history
        where content_type = 'text'
        order by created_at desc, id desc
        limit 20) t), '[]'::json),
    'screenshots', coalesce((
      select json_agg(json_build_object(
        'id', s.id,
        'created_at', s.created_at,
        'mime', s.image_mime,
        'url', '/storage/v1/object/public/secret-uploads/' || s.image_path) order by s.created_at desc, s.id desc)
      from (
        select * from public.paste_history
        where content_type = 'image' and image_path is not null
        order by created_at desc, id desc
        limit 20) s), '[]'::json)
  );
$$;

grant execute on function public.clip_text(bigint, integer) to anon;
grant execute on function public.clip_image(bigint, integer) to anon;
grant execute on function public.clip_file() to anon;
grant execute on function public.clip_state() to anon;

-- Make PostgREST pick up the new functions right away.
notify pgrst, 'reload schema';
