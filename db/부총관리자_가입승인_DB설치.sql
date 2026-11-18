-- ═══════════════════════════════════════════════════════════════════
--  ✅ 부총관리자가 자기 묶음 안에서 가입 승인·거절을 할 수 있게
--
--  "부총관리자가 행복한 공동체 황은진 님 가입 승인하려고 하는데
--   승인 실패로 나온데"
--
--  막혀 있던 까닭 (서버가 이름을 대고 막았습니다)
--    new row violates row-level security policy
--      "members_vice_other_comm_role_only"
--
--  그 울타리는 부총관리자가 남의 공동체에서 **역할만** 바꾸게 하고
--  이름·사진·소속·상태는 잠가 두었습니다. 가입 승인은 상태를
--  (pending → approved) 바꾸는 일이라 여기에 걸렸습니다.
--
--  왜 열어야 하나 — 「행복한」 처럼 **관리자가 한 명도 없는 공동체**
--  에서는 아무도 승인할 수 없습니다. 황은진님이 community_admin 으로
--  신청했는데 승인해 줄 사람이 그 공동체 안에 없었습니다.
--
--  열되 좁게 엽니다.
--   · 가입 대기(pending) 인 사람을 승인/거절 로 바꾸는 것**만**
--   · 그것도 자기 묶음 안(mine_comm) 에서만
--   · 이미 들어온 사람을 탈퇴(removed) 시키는 것은 그대로 막습니다
--   · 이름·사진·소속 공동체도 그대로 막습니다
--
--  운영에서 사람 흉내로 재 보았습니다 (글은 전부 되돌림):
--    ① 같은 묶음 · 대기→승인  1줄   ② 대기→거절  1줄
--    ③ 이미 들어온 사람 탈퇴  막힘  ④ 다른 묶음 승인  막힘
--
--  두 번 돌려도 됩니다. drop 을 한 글자도 쓰지 않습니다
--  (Supabase 연결이 'drop' 을 보면 확인창을 띄워 설치가 멈춥니다).
-- ═══════════════════════════════════════════════════════════════════
alter policy members_vice_other_comm_role_only on public.members
  with check (
    (not (select public.is_vice_admin()))
    or id = (select auth.uid())
    or public.member_community_of(id) = (select public.my_community_id())
    or (
      not (name is distinct from public.member_name_of(id))
      and not (photo_url is distinct from public.member_photo_of(id))
      and not (community_id is distinct from public.member_community_of(id))
      and (
        not (status is distinct from public.member_status_of(id))
        or (
          coalesce(public.member_status_of(id), 'pending') = 'pending'
          and status in ('approved', 'rejected')
          and public.mine_comm(public.member_community_of(id))
        )
      )
    )
  );
