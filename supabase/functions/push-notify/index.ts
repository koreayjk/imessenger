// 새 메시지를 그 방 사람들의 기기로 밀어 보낸다 (웹푸시).
//
//  보내는 쪽에서 메시지를 넣자마자 이 함수를 부릅니다. 함수는 그 메시지가
//  진짜인지, 부른 사람이 정말 그 메시지를 쓴 사람인지 서버에서 다시 확인한
//  뒤에야 보냅니다. 클라이언트가 보내 준 제목·내용은 믿지 않습니다 —
//  믿으면 아무나 남의 이름으로 알림을 뿌릴 수 있습니다.
//
//  배포:  supabase functions deploy push-notify
//  비밀값: supabase secrets set VAPID_PUBLIC=... VAPID_PRIVATE=... VAPID_SUBJECT=mailto:...
import webpush from 'npm:web-push@3.6.7';
import { createClient } from 'jsr:@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

const VAPID_PUBLIC  = Deno.env.get('VAPID_PUBLIC')  ?? '';
const VAPID_PRIVATE = Deno.env.get('VAPID_PRIVATE') ?? '';
const VAPID_SUBJECT = Deno.env.get('VAPID_SUBJECT') ?? 'mailto:admin@example.com';

// 꾸민 글(HTML)에서 글자만. 알림에 <span style=...> 가 나가면 안 된다.
function strip(html: string): string {
  return String(html ?? '')
    .replace(/<br\s*\/?>/gi, ' ')
    .replace(/<[^>]*>/g, '')
    .replace(/&nbsp;/gi, ' ').replace(/&amp;/gi, '&')
    .replace(/&lt;/gi, '<').replace(/&gt;/gi, '>')
    .replace(/&quot;/gi, '"').replace(/&#0?39;|&apos;/gi, "'")
    .replace(/\s+/g, ' ').trim();
}

function previewOf(m: Record<string, unknown>): string {
  const kind = String(m.kind ?? 'text');
  const raw  = String(m.text ?? '');
  if (kind === 'poll') { try { return '📊 ' + (JSON.parse(raw).q ?? '투표'); } catch { return '📊 투표'; } }
  if (kind === 'file') {
    try {
      const f = JSON.parse(raw);
      const names = f.name ?? (Array.isArray(f.items) ? f.items.map((x: any) => x.name).join(', ') : '');
      return '📎 ' + (names || '첨부파일');
    } catch { return '📎 첨부파일'; }
  }
  return (m.format === 'html' ? strip(raw) : raw).slice(0, 140);
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (!VAPID_PUBLIC || !VAPID_PRIVATE) {
    return json({ error: 'VAPID 키가 없습니다. supabase secrets set VAPID_PUBLIC=... VAPID_PRIVATE=... 를 먼저 하세요.' }, 500);
  }

  const auth = req.headers.get('Authorization') ?? '';
  if (!auth) return json({ error: '로그인이 필요합니다' }, 401);

  let body: { message_id?: string };
  try { body = await req.json(); } catch { return json({ error: '잘못된 요청' }, 400); }
  const messageId = String(body.message_id ?? '');
  if (!messageId) return json({ error: 'message_id 가 없습니다' }, 400);

  const url = Deno.env.get('SUPABASE_URL')!;
  // 부른 사람이 누구인지는 그 사람의 토큰으로 확인한다
  const asUser = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: auth } },
  });
  const { data: { user }, error: uErr } = await asUser.auth.getUser();
  if (uErr || !user) return json({ error: '로그인이 필요합니다' }, 401);

  // 보낼 대상은 RLS 너머라서 service_role 로 읽는다
  const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

  const { data: msg } = await admin.from('messages')
    .select('id,channel_id,sender_id,sender_name,text,kind,format,hidden_at')
    .eq('id', messageId).maybeSingle();
  if (!msg) return json({ error: '메시지를 찾을 수 없습니다' }, 404);
  // 쓴 사람만 자기 메시지의 알림을 쏠 수 있다. 아니면 아무나
  // 남의 메시지 번호로 알림을 뿌릴 수 있다.
  if (msg.sender_id !== user.id) return json({ error: '이 메시지의 작성자가 아닙니다' }, 403);
  if (msg.hidden_at) return json({ sent: 0, skipped: 'hidden' });

  const { data: ch } = await admin.from('channels')
    .select('id,name,kind').eq('id', msg.channel_id).maybeSingle();

  // 그 방 사람들 (쓴 사람 빼고)
  const { data: mems } = await admin.from('channel_members')
    .select('member_id').eq('channel_id', msg.channel_id);
  const targets = (mems ?? []).map((x) => x.member_id).filter((id) => id !== msg.sender_id);
  if (!targets.length) return json({ sent: 0 });

  // 나를 차단한 사람에게는 안 보낸다
  const { data: blocks } = await admin.from('user_blocks')
    .select('blocker_id').eq('blocked_id', msg.sender_id).in('blocker_id', targets);
  const blockedBy = new Set((blocks ?? []).map((b) => b.blocker_id));

  const { data: subs } = await admin.from('push_subscriptions')
    .select('*').in('member_id', targets.filter((id) => !blockedBy.has(id)));
  if (!subs || !subs.length) return json({ sent: 0 });

  // @멘션 — 이름으로 가린다 (mentions 칸이 있으면 그걸 먼저 본다)
  const plain = msg.format === 'html' ? strip(String(msg.text ?? '')) : String(msg.text ?? '');
  const atAll = /@(전체|everyone|all)(?![\w가-힣])/i.test(plain);
  const { data: names } = await admin.from('members')
    .select('id,name').in('id', targets);
  const nameOf = new Map((names ?? []).map((m) => [m.id, String(m.name ?? '')]));

  webpush.setVapidDetails(VAPID_SUBJECT, VAPID_PUBLIC, VAPID_PRIVATE);

  const who   = String(msg.sender_name ?? '새 메시지');
  const where = ch && ch.kind !== 'dm' && ch.name ? ' · ' + ch.name : '';
  const text  = previewOf(msg as Record<string, unknown>);

  let sent = 0;
  const dead: string[] = [];

  await Promise.all(subs.map(async (s) => {
    if (!s.enabled) return;
    if (String(s.mutes ?? '').split(',').filter(Boolean).includes(msg.channel_id)) return;
    const myName = nameOf.get(s.member_id) ?? '';
    const mentioned = atAll || (!!myName && plain.includes('@' + myName));
    if (s.only_mention && !mentioned) return;

    const payload = JSON.stringify({
      title: (mentioned ? '@ ' : '') + who + where,
      body: s.preview ? text : '새 메시지가 왔어요',
      tag: 'tcs-' + msg.channel_id,
      channelId: msg.channel_id,
    });
    try {
      await webpush.sendNotification(
        { endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } },
        payload,
        { TTL: 3600, urgency: 'high' },
      );
      sent++;
      await admin.from('push_subscriptions')
        .update({ last_ok_at: new Date().toISOString(), fail_count: 0 }).eq('id', s.id);
    } catch (e: any) {
      const code = e?.statusCode ?? 0;
      // 404·410 = 그 기기가 더는 받지 않는다(브라우저를 지웠거나 껐다). 치운다.
      if (code === 404 || code === 410) dead.push(s.id);
      else await admin.from('push_subscriptions')
        .update({ fail_count: (s.fail_count ?? 0) + 1 }).eq('id', s.id);
    }
  }));

  if (dead.length) await admin.from('push_subscriptions').delete().in('id', dead);

  return json({ sent, removed: dead.length });
});
