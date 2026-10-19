-- ════════════════════════════════════════════════════════════════════
--  👑 방을 만든 사람이 방장
--
--  "채팅방을 처음 만든 사람이 방장을 하고, 방장 권한으로 채팅방 이름
--   변경과 초청된 사람을 내보낼 수 있는 권한을 줘"
--
--  방은 이미 channels.created_by 에 만든 사람을 적어 두고 있습니다.
--  그걸 방장으로 씁니다 — 새 칸을 만들지 않습니다.
--
--  지금은 교직원(staff_of)만 방 이름을 바꿀 수 있습니다. 학생이
--  만든 토픽방은 정작 만든 본인이 이름도 못 고칩니다.
--
--  방장이 할 수 있는 일 — 이 둘뿐입니다:
--    · 방 이름·설명·이모지 바꾸기
--    · 초대한 사람 내보내기
--  방을 지우는 건 교직원만 그대로 둡니다. 되돌릴 수 없는 일입니다.
--
--  1:1 대화에는 방장을 두지 않습니다. 둘뿐인 자리에서 한쪽이 다른
--  쪽을 내보낼 수 있으면 그건 대화가 아닙니다.
--
--  두 번 돌려도 안전합니다.
-- ════════════════════════════════════════════════════════════════════

create or replace function public.is_channel_owner(ch uuid)
returns boolean language sql stable security definer parallel safe
set search_path = public as $$
  select exists (
    select 1 from public.channels c
     where c.id = ch
       and c.created_by = auth.uid()
       and coalesce(c.kind, 'topic') <> 'dm'   -- 1:1 에는 방장이 없다
  );
$$;
grant execute on function public.is_channel_owner(uuid) to authenticated;

-- ── 방 이름 바꾸기 ──
drop policy if exists channels_update on public.channels;
create policy channels_update on public.channels for update to authenticated
  using      ( public.staff_of(community_id) or public.is_channel_owner(id) )
  with check ( public.staff_of(community_id) or public.is_channel_owner(id) );

-- ── 내보내기 ──
--  나가기(본인)·교직원은 그대로. 방장이 더해집니다.
drop policy if exists channel_members_delete on public.channel_members;
create policy channel_members_delete on public.channel_members for delete to authenticated
  using (
    member_id = auth.uid()                       -- 내가 나가는 건 늘 된다
    or public.can_moderate_channel(channel_id)   -- 교직원
    or ( public.is_channel_owner(channel_id)     -- 방장
         and member_id <> auth.uid() )           -- (자기를 내보내는 건 '나가기' 로)
  );

notify pgrst, 'reload schema';

select '설치 끝 — 방을 만든 사람이 이름 바꾸기·내보내기를 할 수 있어요' as "결과";
