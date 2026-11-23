-- ═══════════════════════════════════════════════════════════════════
--  🙏 기도제목 — 남의 글은 못 고치게
--  Supabase → SQL Editor 에 붙여넣고 Run 하세요. 여러 번 돌려도 됩니다.
-- ═══════════════════════════════════════════════════════════════════
--
--  지금 prayers 의 UPDATE 규칙은 이렇습니다.
--      USING (community_id = my_community_id())
--  같은 공동체면 **누구나 아무 줄이나** 고칠 수 있습니다.
--
--  일부러 이렇게 둔 까닭이 있습니다. 「🙏 함께 기도」 를 누르면 그 줄의
--  prayer_count 를 올리는데, 그게 남의 줄이기 때문입니다. 규칙을
--  「본인만」 으로 좁히면 함께 기도 숫자가 아무도 안 올라갑니다.
--
--  그런데 곁가지로 **남이 올린 기도의 글까지 고칠 수 있게** 되어 있습니다.
--  화면에는 본인에게만 ✏️ 가 보이지만, 화면을 거치지 않고 부르면 막히지
--  않습니다. 규칙(RLS)은 줄 단위라 '이 칸만' 을 가릴 수 없으므로,
--  칸을 보는 일은 방아쇠(trigger)에 맡깁니다.
--
--  넣고 나면 —
--   · 함께 기도 숫자 올리기 : 그대로 됩니다 (prayer_count 만 바뀌므로)
--   · 내 글 고치기          : 됩니다
--   · 남의 글 고치기        : 막힙니다 (오류로 되돌아갑니다)
--   · 주인·공동체 바꿔치기  : 막힙니다
-- ═══════════════════════════════════════════════════════════════════

create or replace function public.prayers_guard_edit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  --  글(제목·본문·공개범위)은 올린 사람만 고칩니다.
  --  관리자는 지울 수는 있어도, 남이 올린 기도의 말을 바꾸지는 않습니다.
  if (new.title is distinct from old.title
   or new.body  is distinct from old.body
   or new.scope is distinct from old.scope)
   and old.member_id is distinct from auth.uid() then
    raise exception '남이 올린 기도제목의 글은 고칠 수 없습니다';
  end if;

  --  주인과 공동체는 누구도 바꾸지 못합니다. 바꿀 수 있으면 남의 글을
  --  내 것으로 만들어 놓고 고치는 길이 열립니다.
  if new.member_id   is distinct from old.member_id
   or new.community_id is distinct from old.community_id then
    raise exception '기도제목의 주인과 공동체는 바꿀 수 없습니다';
  end if;

  return new;
end $$;

drop trigger if exists prayers_guard_edit_trg on public.prayers;
create trigger prayers_guard_edit_trg
  before update on public.prayers
  for each row execute function public.prayers_guard_edit();

--  제대로 걸렸는지 확인
do $$
declare n int;
begin
  select count(*) into n from pg_trigger
   where tgrelid = 'public.prayers'::regclass
     and tgname = 'prayers_guard_edit_trg'
     and not tgisinternal;
  if n <> 1 then raise exception '방아쇠가 안 걸렸습니다 (%개)', n; end if;
  raise notice '기도제목 본인만 고치기 — 설치 완료';
end $$;
