-- Run this once in the Supabase SQL editor for the site's self-hosted
-- pageview counter (no Google Analytics dashboard required).

-- 1. Raw log. RLS has no SELECT policy for anon, so this table cannot be
--    read directly via the public API — only inserted into. All reads go
--    through the aggregate function below, which never returns raw rows.
create table if not exists public.page_views (
  id bigint generated always as identity primary key,
  path text not null check (char_length(path) <= 300),
  referrer text check (char_length(referrer) <= 500),
  created_at timestamptz not null default now()
);

create index if not exists page_views_created_at_idx on public.page_views (created_at);
create index if not exists page_views_path_idx on public.page_views (path);

alter table public.page_views enable row level security;

drop policy if exists "public can log a pageview" on public.page_views;
create policy "public can log a pageview"
  on public.page_views for insert
  to anon
  with check (path like '/%');

-- 2. Aggregate-only read path. security definer lets it read the table it
--    owns even though anon has no SELECT grant on the table itself; it
--    only ever returns counts, never individual rows (no path is tied to
--    a specific visitor since nothing identifying is stored anyway).
create or replace function public.get_dashboard_stats()
returns json
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  result json;
begin
  select json_build_object(
    'total', (select count(*) from public.page_views),
    'today', (select count(*) from public.page_views where created_at >= date_trunc('day', now())),
    'week', (select count(*) from public.page_views where created_at >= now() - interval '7 days'),
    'daily', (
      select coalesce(json_agg(json_build_object('day', d.day, 'count', d.count) order by d.day), '[]'::json)
      from (
        select to_char(gs::date, 'YYYY-MM-DD') as day,
               coalesce(pv.cnt, 0) as count
        from generate_series((now() - interval '29 days')::date, now()::date, interval '1 day') gs
        left join (
          select date_trunc('day', created_at)::date as day, count(*) as cnt
          from public.page_views
          where created_at >= now() - interval '30 days'
          group by 1
        ) pv on pv.day = gs::date
      ) d
    ),
    'top_pages', (
      select coalesce(json_agg(json_build_object('path', p.path, 'count', p.count)), '[]'::json)
      from (
        select path, count(*) as count
        from public.page_views
        group by path
        order by count desc
        limit 5
      ) p
    ),
    'top_referrers', (
      select coalesce(json_agg(json_build_object('referrer', r.referrer, 'count', r.count)), '[]'::json)
      from (
        select case when referrer is null or referrer = '' then 'Direct / None' else referrer end as referrer,
               count(*) as count
        from public.page_views
        group by 1
        order by count desc
        limit 5
      ) r
    )
  ) into result;
  return result;
end;
$$;

grant execute on function public.get_dashboard_stats() to anon;
