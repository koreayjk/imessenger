-- =====================================================================
--  📋 제출 현황 — 채팅방에 매일 올려야 하는 것(플래너 등)을 한눈에
--
--  어떻게 세나
--   올리는 방식은 바꾸지 않습니다. 지금처럼 채팅방에 사진을 올리면 됩니다.
--   "제출" 버튼을 따로 만들어 그걸 눌러야 인정되게 하면 며칠은 지키다가
--   결국 아무도 안 누릅니다. 그래서 이미 쌓이고 있는 메시지를 읽어서
--   누가 그날 올렸는지를 셉니다.
--
--   늦게 낸 사람, 아파서 못 낸 사람 같은 예외는 선생님이 표의 칸을 눌러
--   손으로 고칠 수 있습니다. 그 손으로 고친 기록만 아래 표에 저장됩니다.
--   (메시지 자체는 그대로 두고 읽기만 하므로 채팅에는 아무 영향이 없습니다)
--
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행해도 안전)
-- =====================================================================


-- ── 1. 채팅방마다의 설정 ──
alter table public.channels
  add column if not exists checkin_on      boolean not null default false,
  add column if not exists checkin_label   text,
  add column if not exists checkin_days    text not null default '0,1,2,3,4,5,6',
  add column if not exists checkin_require text not null default 'image',
  add column if not exists checkin_start   date,
  add column if not exists checkin_exempt  text not null default '';

comment on column public.channels.checkin_on      is '이 방에서 매일 제출을 확인할지';
comment on column public.channels.checkin_label   is '무엇을 내는지 (예: 플래너)';
comment on column public.channels.checkin_days    is '세는 요일. 0=일 … 6=토';
comment on column public.channels.checkin_require is 'image=사진 | file=사진·파일 | any=아무 메시지';
comment on column public.channels.checkin_start   is '이 날부터 센다. 비어 있으면 처음부터';
comment on column public.channels.checkin_exempt  is '안 내도 되는 사람 (선생님 등). member id 를 쉼표로';


-- ── 2. 손으로 고친 기록만 저장한다 ──
--  자동으로 센 것은 저장하지 않는다. 메시지가 이미 사실이기 때문에,
--  따로 복사해 두면 지우거나 고칠 때 두 곳이 어긋난다.
create table if not exists public.checkin_marks (
  id         uuid primary key default gen_random_uuid(),
  channel_id uuid not null references public.channels(id) on delete cascade,
  member_id  uuid not null,
  day        date not null,
  state      text not null default 'ok',   -- ok = 인정 | excused = 면제
  note       text,
  marked_by  uuid,
  created_at timestamptz not null default now(),
  unique (channel_id, member_id, day)
);
create index if not exists checkin_marks_ch_day on public.checkin_marks (channel_id, day);


-- ── 3. 누가 보고 누가 고치나 ──
--  보기 : 그 채팅방에 들어와 있는 사람 (+ 총관리자·부총관리자)
--  고치기: 학생을 뺀 구성원 (간사 이상) — 앱 화면과 같은 기준
create or replace function public.in_channel(ch uuid)
returns boolean language sql security definer stable set search_path = public as $$
  select exists (select 1 from public.channel_members
                  where channel_id = ch and member_id = auth.uid());
$$;
grant execute on function public.in_channel(uuid) to authenticated;

create or replace function public.is_staff_member()
returns boolean language sql security definer stable set search_path = public as $$
  select exists (select 1 from public.members
                  where id = auth.uid()
                    and coalesce(community_role,'') <> 'student'
                    and coalesce(role,'') <> '학생');
$$;
grant execute on function public.is_staff_member() to authenticated;

-- 부총관리자 파일을 아직 안 돌렸어도 이 파일만으로 동작하게 (있으면 그대로 덮어씀)
create or replace function public.can_view_all_communities()
returns boolean language sql security definer stable set search_path = public as $$
  select exists (select 1 from public.members
                  where id = auth.uid()
                    and community_role in ('super_admin','vice_admin'));
$$;
grant execute on function public.can_view_all_communities() to authenticated;

alter table public.checkin_marks enable row level security;

drop policy if exists checkin_marks_select on public.checkin_marks;
create policy checkin_marks_select on public.checkin_marks
  for select to authenticated
  using ( public.in_channel(channel_id) or public.can_view_all_communities() );

drop policy if exists checkin_marks_write on public.checkin_marks;
create policy checkin_marks_write on public.checkin_marks
  for all to authenticated
  using      ( public.is_staff_member()
               and (public.in_channel(channel_id) or public.can_view_all_communities()) )
  with check ( public.is_staff_member()
               and (public.in_channel(channel_id) or public.can_view_all_communities()) );

grant select, insert, update, delete on public.checkin_marks to authenticated;

notify pgrst, 'reload schema';


-- ── 4. 확인 ──
select count(*) as "설정 붙은 채팅방 수" from information_schema.columns
 where table_schema = 'public' and table_name = 'channels' and column_name like 'checkin%';

select polname as "정책", case when polpermissive then '허용' else '제한' end as "종류"
  from pg_policy where polrelid = 'public.checkin_marks'::regclass order by 1;


-- =====================================================================
--  쓰는 법
--   채팅방을 열고 머리글의 📋 제출 → "제출 현황 켜기"
--     · 무엇을 내는지 이름 (플래너 / 숙제 / QT …)
--     · 사진만 셀지, 파일도 셀지, 아무 메시지나 셀지
--     · 세는 요일 (주말을 빼면 표에서 아예 빠집니다)
--     · 언제부터 셀지
--
--   켜고 나면 표에 지난 기록이 바로 채워집니다. 전에 올린 사진까지
--   거슬러 올라가 세기 때문에 처음부터 다시 모을 필요가 없습니다.
--
--   이름을 누르면 그 사람은 아예 세지 않습니다 (받는 선생님 본인 등).
--   칸을 누르면 ✅인정 → 🏖면제 → 자동 으로 바뀝니다.
--   면제한 날은 분모에서 빠지고, 연속 기록(🔥)도 끊기지 않습니다.
--
--  ❗ 되돌리려면
--       drop table if exists public.checkin_marks;
--       alter table public.channels drop column if exists checkin_on,
--         drop column if exists checkin_label, drop column if exists checkin_days,
--         drop column if exists checkin_require, drop column if exists checkin_start,
--         drop column if exists checkin_exempt;
-- =====================================================================
