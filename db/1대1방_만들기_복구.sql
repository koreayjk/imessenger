-- =====================================================================
--  💬 1:1 채팅방이 만들어지지 않던 것 (개선창 · 박유빈)
--
--  증상
--    "선교사님이나 간사님과 채팅을 하려고 하면 채팅방이 만들어지지가 않아요"
--    학생만의 일이 아니었습니다. **간사·선생님이 먼저 걸어도 똑같이** 안 됐습니다.
--    단체방은 멀쩡했습니다.
--
--  원인
--    앱은 방을 만들면서 'insert ... returning' 으로 방금 만든 줄을 돌려받습니다
--    (supabase-js 의 .insert({...}).select().single()).
--    그런데 읽기 정책이 이랬습니다:
--
--      id IN (my_channel_ids())  OR  (staff_of(...) AND kind <> 'dm')
--
--    · my_channel_ids() 는 **channels 표를 다시 읽는 함수**입니다.
--      같은 문장 안에서 방금 넣은 줄은 그 조회의 스냅샷에 아직 없습니다.
--    · 두 번째 조항은 kind <> 'dm' 이라 1:1 은 아예 빠집니다.
--
--    그래서 누가 만들든 '돌려받기' 에서 막히고, 앱은
--    "대화방을 만들지 못했어요" 를 띄웠습니다.
--    실제로 10월 22일 뒤로 새 1:1 방이 거의 0 이었습니다.
--
--  고침
--    created_by 를 맨 앞에 둡니다. 이건 **그 줄만 보면 알 수 있어서**
--    표를 다시 읽지 않습니다. 그래서 RETURNING 에서 통과합니다.
--
--  ⚠️ 권한은 한 뼘도 넓어지지 않습니다.
--     my_channel_ids() 안에 이미 'c.created_by = me.id' 가 들어 있습니다.
--     같은 조건을 밖으로 꺼내 쓸 수 있게 한 것뿐입니다.
--     · 학생끼리 1:1 은 그대로 막힙니다 (can_dm + channel_members 정책)
--     · 내가 안 낀 남의 1:1 방은 그대로 안 보입니다
--
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행해도 안전)
-- =====================================================================

drop policy if exists channels_select on public.channels;
create policy channels_select on public.channels
  for select to authenticated
  using (
    --  ① 내가 만든 방 — 방금 만든 줄도 여기서 걸린다 (표를 다시 읽지 않는다)
    created_by = (select auth.uid())
    --  ② 내가 든 방
    or id in (select public.my_channel_ids())
    --  ③ 교직원은 공동체의 단체방을 다 본다. 1:1 은 뺀다.
    or (public.staff_of(community_id) and coalesce(kind, 'topic') <> 'dm')
  );
