-- ═══════════════════════════════════════════════════════════════════
--  자료실 2단 — 🌐 전체 공용 폴더 / 🏠 우리 공동체 폴더
--  Supabase → SQL Editor 에 붙여넣고 Run 하세요. 여러 번 돌려도 됩니다.
-- ═══════════════════════════════════════════════════════════════════
--
--  우리 공동체 폴더는 이미 communities.drive_root_folder_id 에 있습니다.
--  전체 공용 폴더는 **같은 그룹끼리 같은 하나**를 보는 것이라, 공동체 칸이
--  아니라 앱 전체에 자리를 둡니다. 그래서 작은 표 하나를 둡니다.
--
--  열쇠는 공동체 종류마다 하나씩입니다 —
--    drive_shared_folder_id_community : 리뉴젠 공동체 그룹
--    drive_shared_folder_id_academy   : 리뉴젠 아카데미 그룹
--  두 그룹은 서로 다른 자료실을 봅니다. 한쪽이 비어 있으면 그 그룹에는
--  '아직 없어요' 라고 하고, **다른 그룹 폴더로 되돌아가지 않습니다.**
--
--  ⚠️ 예전에 쓰던 DRIVE_ROOT_FOLDER_ID 시크릿과 다릅니다. 그건 '폴더를
--     안 정한 공동체가 남의 자료실을 보던' 사고의 원인이라 없앴습니다.
--     이건 **일부러 모두에게 보여주는** 폴더입니다.
-- ═══════════════════════════════════════════════════════════════════

create table if not exists public.app_settings (
  key        text primary key,
  value      text,
  updated_at timestamptz not null default now(),
  updated_by uuid
);

comment on table public.app_settings is
  '앱 전체에 하나뿐인 설정. 총관리자만 씁니다. 지금 쓰는 열쇠: drive_shared_folder_id_community · drive_shared_folder_id_academy';

alter table public.app_settings enable row level security;

--  보기: 로그인한 사람 모두 (자료실이 이 값을 읽어야 합니다)
drop policy if exists app_settings_select on public.app_settings;
create policy app_settings_select on public.app_settings
  for select to authenticated using (true);

--  쓰기: 총관리자만
drop policy if exists app_settings_insert on public.app_settings;
create policy app_settings_insert on public.app_settings
  for insert to authenticated with check ((select public.is_super_admin()));

drop policy if exists app_settings_update on public.app_settings;
create policy app_settings_update on public.app_settings
  for update to authenticated
  using ((select public.is_super_admin()))
  with check ((select public.is_super_admin()));

drop policy if exists app_settings_delete on public.app_settings;
create policy app_settings_delete on public.app_settings
  for delete to authenticated using ((select public.is_super_admin()));

revoke truncate on public.app_settings from anon, authenticated;
revoke all on public.app_settings from anon;
grant select, insert, update, delete on public.app_settings to authenticated;

--  적을 때 시각과 사람을 남긴다
create or replace function public.app_settings_touch()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  new.updated_at := now();
  new.updated_by := auth.uid();
  return new;
end $$;

drop trigger if exists app_settings_touch_trg on public.app_settings;
create trigger app_settings_touch_trg before insert or update on public.app_settings
  for each row execute function public.app_settings_touch();

do $$
declare n int;
begin
  select count(*) into n from pg_policies
   where schemaname='public' and tablename='app_settings';
  if n <> 4 then raise exception '정책이 4개여야 하는데 %개입니다', n; end if;
  raise notice 'app_settings 설치 완료 (정책 4개)';
end $$;
