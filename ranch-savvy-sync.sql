-- ============================================================
-- Lunch Lady <- Ranch Savvy read-only herd sync
-- Run once in the Ranch Savvy Supabase project (SQL editor).
-- ============================================================
--
-- What this exposes: for every ACTIVE herd, its id, name, and the count
-- of animals with status = 'active' -- the same computed count the Ranch
-- Savvy Herds page displays (NOT the manually-entered herds.head_count
-- used for AUM billing math). Nothing else. No write path exists.
--
-- How access works: all 29 Ranch Savvy tables stay RLS-locked to
-- authenticated users. This one function runs SECURITY DEFINER (so it can
-- read past RLS) and is granted to the anon role, gated by a shared key
-- sent as the x-feedwagon-key request header. Since the Lunch Lady repo
-- is public, treat that key as a bot-scraper filter and a kill switch,
-- not a secret: anyone who reads the repo source can see it. The blast
-- radius if it leaks is herd names + head counts, nothing more. To cut
-- access instantly, change the key here (or DROP the function).
--
-- BEFORE RUNNING: replace put-a-long-random-string-here below with a
-- long random string, and paste the same string into RS_APP_KEY near the
-- top of index.html.

create or replace function public.get_herd_summary()
returns table(herd_id uuid, name text, active_count bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(current_setting('request.headers', true)::json->>'x-feedwagon-key', '')
     <> 'put-a-long-random-string-here' then
    raise exception 'unauthorized';
  end if;
  return query
    select h.id,
           h.name,
           count(a.id) filter (where a.status = 'active')
    from herds h
    left join animals a on a.herd_id = h.id
    where h.is_active = true
    group by h.id, h.name
    order by h.name;
end;
$$;

-- lock the function down to exactly the callers intended
revoke all on function public.get_herd_summary() from public;
grant execute on function public.get_herd_summary() to anon;
grant execute on function public.get_herd_summary() to authenticated;

-- Verify (should error):
--   select * from get_herd_summary();
-- Verify (should return rows) -- run from Lunch Lady's Settings > Refresh,
-- or with curl:
--   curl -X POST 'https://tthhlfuqsomgulasjszv.supabase.co/rest/v1/rpc/get_herd_summary' \
--     -H 'apikey: YOUR_ANON_KEY' -H 'Authorization: Bearer YOUR_ANON_KEY' \
--     -H 'x-feedwagon-key: YOUR_APP_KEY' -H 'Content-Type: application/json' -d '{}'
