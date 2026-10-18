-- ════════════════════════════════════════════════════════════════════
--  🔴 앱 아이콘의 빨간 숫자 (배지)
--
--  "알림설정해서 문자오면 잘뜨는데 어플아이콘에 숫자는 안뜨나?"
--
--  안 떴습니다. 알림 내용만 보내고 숫자 칸(badge)을 아예 비워서
--  보내고 있었습니다. 애플은 그 칸에 적힌 수를 그대로 아이콘에
--  붙이고, 안 적어 보내면 아무것도 안 붙입니다.
--
--  숫자를 붙이려면 '받는 사람이 지금 몇 개를 안 읽었는지' 를 서버가
--  알아야 합니다. 화면에서 세던 것과 같은 셈을 여기로 옮깁니다:
--
--    내가 들어가 있는 방들에서,
--    내가 쓰지 않았고, 가려지지 않았고,
--    내가 그 방을 마지막으로 읽은 시각보다 나중에 온 글
--
--  한 번도 읽은 적 없는 방은 최근 45일치만 셉니다 (화면과 같은 기준).
--
--  두 번 돌려도 안전합니다.
-- ════════════════════════════════════════════════════════════════════

create or replace function public.unread_counts(p_members uuid[])
returns table (member_id uuid, n integer)
language sql stable security definer parallel safe
set search_path = public as $$
  select cm.member_id,
         count(m.id)::int as n
    from public.channel_members cm
    left join public.channel_reads cr
           on cr.channel_id = cm.channel_id
          and cr.member_id  = cm.member_id
    left join public.messages m
           on m.channel_id = cm.channel_id
          and m.sender_id <> cm.member_id
          and m.hidden_at is null
          -- 창을 45일로 묶는다. 안 그러면 몇 해치 글을 다 세느라
          -- 알림 한 번 보낼 때마다 데이터베이스가 한참 걸린다.
          and m.created_at > now() - interval '45 days'
          and m.created_at > coalesce(cr.last_read_at, now() - interval '45 days')
   where cm.member_id = any(p_members)
   group by cm.member_id;
$$;

-- 남의 안읽음 수는 남의 사정이다. 알림 보내는 서버(service_role)만
-- 부를 수 있게 한다 — 로그인한 사람에게는 열지 않는다.
revoke all on function public.unread_counts(uuid[]) from public, anon, authenticated;
grant execute on function public.unread_counts(uuid[]) to service_role;

-- 세는 길을 빠르게
create index if not exists messages_ch_created_idx
  on public.messages (channel_id, created_at desc);
create index if not exists channel_reads_mem_ch_idx
  on public.channel_reads (member_id, channel_id);

notify pgrst, 'reload schema';

select '설치 끝 — unread_counts() 준비됨' as "결과";
