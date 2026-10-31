-- NAGI 公式サイト：予約受付・公開イベント一覧・イベント参加申込
-- 管理用 Supabase (nagi-management) の SQL Editor で1回実行。
-- 既存の問い合わせ・予約データは削除しません。
begin;
alter table public.nagi_bookings alter column created_by drop not null;
-- 管理者のみ閲覧可能。匿名ユーザーにはテーブル権限を与えない。
revoke all on public.nagi_bookings from anon;

create or replace function public.nagi_public_submit_booking(
 p_name text,p_email text,p_phone text,p_service text,p_requested_local text,
 p_alternate_local text default '',p_notes text default '',p_website text default ''
) returns void language plpgsql security definer set search_path = '' as $$
declare
 v_start timestamp; v_alt timestamp; v_name text:=pg_catalog.btrim(coalesce(p_name,''));
 v_email text:=pg_catalog.btrim(coalesce(p_email,''));
 v_phone text:=pg_catalog.btrim(coalesce(p_phone,''));
 v_service text:=pg_catalog.btrim(coalesce(p_service,''));
 v_notes text:=pg_catalog.btrim(coalesce(p_notes,''));
begin
 if coalesce(p_website,'')<>'' then return; end if;
 if pg_catalog.length(v_name) not between 1 and 100 or pg_catalog.length(v_email) not between 5 and 254
 or v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
 or pg_catalog.length(v_phone) not between 6 and 30 or pg_catalog.length(v_service) not between 1 and 120
 or pg_catalog.length(v_notes)>2000 then raise exception '入力内容が不正です'; end if;
 if p_requested_local !~ '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$' then raise exception '日時形式が不正です'; end if;
 v_start:=p_requested_local::timestamp;
 if (v_start at time zone 'Asia/Tokyo') <= pg_catalog.now() then raise exception '未来の日時を指定してください'; end if;
 if coalesce(p_alternate_local,'')<>'' then
  if p_alternate_local !~ '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$' then raise exception '第2希望日時形式が不正です'; end if;
  v_alt:=p_alternate_local::timestamp;
 end if;
 insert into public.nagi_bookings(customer_name,customer_email,customer_phone,service_name,starts_at,ends_at,status,notes,created_by)
 values(v_name,v_email,v_phone,v_service,v_start at time zone 'Asia/Tokyo',
 (v_start+interval '60 minutes') at time zone 'Asia/Tokyo','pending',
 '【公式サイトからの予約申込・未確定】' || chr(10) ||
 '第2希望: ' || coalesce(to_char(v_alt,'YYYY-MM-DD HH24:MI'),'なし') || chr(10) ||
 '備考: ' || v_notes || chr(10) || '※終了時刻は仮の60分枠です。確定前に施術時間・空き状況を確認してください。',null);
end $$;
revoke all on function public.nagi_public_submit_booking(text,text,text,text,text,text,text,text) from public;
grant execute on function public.nagi_public_submit_booking(text,text,text,text,text,text,text,text) to anon,authenticated;

-- 公開済みイベントだけを匿名閲覧。イベント本体の非公開情報は開放しない。
create or replace function public.nagi_public_list_events()
returns table(id uuid,title text,starts_at timestamptz,venue_name text,price_yen integer)
language sql security definer set search_path = '' stable as $$
 select e.id,e.title,e.starts_at,e.venue_name,e.price_yen
 from public.events e
 where e.status='published' and e.starts_at>=pg_catalog.now()
 order by e.starts_at asc limit 30
$$;
revoke all on function public.nagi_public_list_events() from public;
grant execute on function public.nagi_public_list_events() to anon,authenticated;

-- 参加申込は既存の管理画面「お問い合わせ」に届く（新規の管理UI不要）。
create or replace function public.nagi_public_submit_event_application(
 p_event_id text,p_name text,p_email text,p_phone text default '',
 p_count integer default 1,p_notes text default '',p_website text default ''
) returns void language plpgsql security definer set search_path = '' as $$
declare v_title text;v_name text:=pg_catalog.btrim(coalesce(p_name,''));v_email text:=pg_catalog.btrim(coalesce(p_email,''));
begin
 if coalesce(p_website,'')<>'' then return; end if;
 if p_event_id !~ '^[0-9a-fA-F-]{36}$' then raise exception 'イベントIDが不正です'; end if;
 if pg_catalog.length(v_name) not between 1 and 100 or pg_catalog.length(v_email) not between 5 and 254
 or v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
 or pg_catalog.length(coalesce(p_phone,''))>30 or pg_catalog.length(coalesce(p_notes,''))>2000
 or p_count not between 1 and 10 then raise exception '入力内容が不正です'; end if;
 select e.title into v_title from public.events e
 where e.id=p_event_id::uuid and e.status='published' and e.starts_at>=pg_catalog.now();
 if v_title is null then raise exception '受付中のイベントではありません'; end if;
 insert into public.nagi_inquiries(subject,sender_name,sender_email,source,message,status,created_by)
 values('イベント参加申込：'||left(v_title,70),v_name,v_email,'NAGI公式サイト',
 '【イベント参加申込・未確定】'||chr(10)||'イベント：'||v_title||chr(10)||
 'イベントID：'||p_event_id||chr(10)||'人数：'||p_count||chr(10)||
 '電話番号：'||coalesce(p_phone,'')||chr(10)||'備考：'||coalesce(p_notes,''), 'new',null);
end $$;
revoke all on function public.nagi_public_submit_event_application(text,text,text,text,integer,text,text) from public;
grant execute on function public.nagi_public_submit_event_application(text,text,text,text,integer,text,text) to anon,authenticated;
commit;
