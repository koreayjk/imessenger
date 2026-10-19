-- ════════════════════════════════════════════════════════════════════
--  🔢 방마다 안 읽은 글 수 (채팅 목록의 빨간 숫자)
--
--  "안 읽었던 그 방은 근데 왜 안 읽은 숫자 표시가 안 되었던 거야?"
--
--  화면이 직접 세고 있었기 때문입니다. 45일치 글을 통째로 받아다가
--  브라우저에서 셌는데, 데이터베이스는 한 번에 1000줄까지만 돌려줍니다.
--  순서를 안 정해 줬으니 오래된 1000개가 왔고, 정작 안 읽은 '최근 글' 은
--  한 줄도 안 왔습니다. 그래서 방마다 '다 읽음' 으로 보였습니다.
--  (방 38개 · 45일치 글이 1000개를 훨씬 넘는 계정에서 드러났습니다)
--
--  세는 일은 데이터베이스가 해야 합니다. 수만 돌려주면 잘릴 것이 없습니다.
--
--  ⚠️ security invoker 입니다 — 부른 사람의 권한 그대로 돕니다.
--     그래서 남의 방은 애초에 안 보이고, 볼 수 있는 방만 셉니다.
--     auth.uid() 를 함수 안에서 쓰므로 '남의 안읽음' 을 물어볼 수도 없습니다.
--
--  세는 규칙은 unread_counts(아이콘 숫자) 와 똑같습니다:
--    내가 쓰지 않았고, 가려지지 않았고, 45일 안에 왔고,
--    내가 그 방을 마지막으로 읽은 시각보다 나중에 온 글.
--
--  두 번 돌려도 안전합니다.
-- ════════════════════════════════════════════════════════════════════

create or replace function public.unread_by_channel()
returns table (channel_id uuid, n integer)
language sql stable security invoker parallel safe
set search_path = public as $$
  select c.id as channel_id,
         count(m.id)::int as n
    from public.channels c
    left join public.channel_reads cr
           on cr.channel_id = c.id
          and cr.member_id  = auth.uid()
    left join public.messages m
           on m.channel_id = c.id
          and m.sender_id <> auth.uid()
          and m.hidden_at is null
          -- 창을 45일로 묶는다. 화면·아이콘 숫자와 같은 기준이다.
          and m.created_at > now() - interval '45 days'
          and m.created_at > coalesce(cr.last_read_at, now() - interval '45 days')
   group by c.id;
$$;

-- 로그인한 사람만. 익명은 부를 수 없다.
revoke all on function public.unread_by_channel() from public, anon;
grant execute on function public.unread_by_channel() to authenticated;

-- 세는 길을 빠르게 (이미 있으면 그냥 넘어갑니다)
create index if not exists messages_ch_created_idx
  on public.messages (channel_id, created_at desc);
create index if not exists channel_reads_mem_ch_idx
  on public.channel_reads (member_id, channel_id);

notify pgrst, 'reload schema';

select '설치 끝 — unread_by_channel() 준비됨' as "결과";
