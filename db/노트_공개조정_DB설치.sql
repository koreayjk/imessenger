-- ══════════════════════════════════════════════════════════════
--  노트 공개 상태 — 관리자가 조정하기
--  (개선창 ⑧ · 양회광 · IM HQ · 2026-11-03)
-- ══════════════════════════════════════════════════════════════
--
--  바라던 것 : "이미 올라온 노트들을 관리자가 공개상태 조정을 할 수 있도록"
--
--  지금은 notes_update 가 `user_id = auth.uid()` 뿐이라, 글쓴이 말고는
--  아무도 못 바꿉니다. 관리자가 눌러도 **표가 조용히 0줄을 돌려주고**
--  화면만 바뀐 척합니다. 그래서 서버에 길을 하나 냅니다.
--
--  ★ 지키는 선 ─ 둘 다 서버에서 막습니다
--   ① 관리자도 남의 「나만 보기」 노트는 못 보고 못 건드립니다.
--      → 이미 공개된 노트(community · selected) 만 조정됩니다.
--   ② 관리자가 남의 노트 '내용' 은 못 고칩니다.
--      → 그래서 표를 열어 주지 않고, 공개 칸만 만지는 길 하나만 냅니다.
--        (RLS 로는 칸을 가릴 수 없어서, update 정책을 넓히면
--         제목·본문까지 열립니다. 그 길은 쓰지 않습니다.)
--
--  고를 수 있는 값은 두 가지뿐입니다 — 🌐 공동체 공개 / 🔒 나만 보기.
--  '고른 사람만' 은 넣지 않았습니다. 남의 노트를 누구에게 보일지
--  관리자가 대신 고르는 건 지나칩니다.
--
--  누가 할 수 있나 : 총관리자는 어디서나, 관리자·부총관리자는
--  **자기 소속 공동체** 의 노트만.
-- ══════════════════════════════════════════════════════════════

create or replace function public.admin_set_note_visibility(p_note uuid, p_vis text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me     public.members;
  v_note   public.notes;
begin
  if p_vis is null or p_vis not in ('private', 'community') then
    raise exception '공개 상태는 「나만 보기」 또는 「공동체 공개」 만 됩니다.';
  end if;

  select * into v_me from public.members where id = auth.uid();
  if v_me.id is null or coalesce(v_me.status, 'active') = 'removed' then
    raise exception '권한이 없습니다.';
  end if;

  select * into v_note from public.notes where notes.id = p_note;
  if v_note.id is null then
    raise exception '노트를 찾을 수 없습니다.';
  end if;

  -- 관리자인가 — 총관리자는 어디서나, 나머지는 자기 소속 공동체에서만
  if not ( v_me.community_role = 'super_admin'
           or ( v_me.community_role in ('vice_admin', 'community_admin')
                and v_me.community_id = v_note.community_id ) ) then
    raise exception '관리자만 할 수 있습니다.';
  end if;

  -- ★ 선 ① — 이미 공개된 노트만. 남의 「나만 보기」는 관리자도 못 건드립니다.
  if v_note.visibility not in ('community', 'selected') then
    raise exception '이미 공개된 노트만 조정할 수 있습니다.';
  end if;

  update public.notes
     set visibility    = p_vis,
         share_members = '{}'::uuid[],
         share_groups  = '{}'::uuid[],
         updated_at    = now()
   where notes.id = p_note;

  return p_vis;
end
$$;

-- 아무나 부르지 못하게. 로그인한 사람만 부르고, 그 안에서 또 걸러냅니다.
revoke all     on function public.admin_set_note_visibility(uuid, text) from public;
revoke all     on function public.admin_set_note_visibility(uuid, text) from anon;
grant  execute on function public.admin_set_note_visibility(uuid, text) to authenticated;
