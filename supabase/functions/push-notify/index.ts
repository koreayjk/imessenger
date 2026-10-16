// 새 메시지를 그 방 사람들의 기기로 밀어 보낸다 (웹푸시).
//
//  보내는 쪽에서 메시지를 넣자마자 이 함수를 부릅니다. 함수는 그 메시지가
//  진짜인지, 부른 사람이 정말 그 메시지를 쓴 사람인지 서버에서 다시 확인한
//  뒤에야 보냅니다. 클라이언트가 보내 준 제목·내용은 믿지 않습니다 —
//  믿으면 아무나 남의 이름으로 알림을 뿌릴 수 있습니다.
//
//  길이 둘입니다. 브라우저는 웹푸시(VAPID), 아이폰 앱은 애플 APNs 입니다.
//  같은 표(push_subscriptions)를 쓰고 kind 로 갈라집니다. 한쪽 비밀값만
//  넣어 두어도 그쪽 길은 정상으로 돕니다.
//
//  배포:  supabase functions deploy push-notify
//  비밀값: supabase secrets set VAPID_PUBLIC=... VAPID_PRIVATE=... VAPID_SUBJECT=mailto:...
//         supabase secrets set APNS_KEY_ID=... APNS_TEAM_ID=... \
//                              APNS_BUNDLE_ID=io.github.koreayjk.tcs \
//                              APNS_PRIVATE_KEY="$(cat AuthKey_XXXXXXXXXX.p8)"
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
const HAS_WEB = !!(VAPID_PUBLIC && VAPID_PRIVATE);

// ── 🍎 애플 APNs ────────────────────────────────────────────────────
//  아이폰 앱(WKWebView)은 서비스워커 푸시를 받지 못합니다. 애플에
//  직접 넣어야 합니다. 인증은 .p8 키로 서명한 짧은 토큰(ES256 JWT)입니다.
const APNS_KEY_ID      = Deno.env.get('APNS_KEY_ID') ?? '';
const APNS_TEAM_ID     = Deno.env.get('APNS_TEAM_ID') ?? '';
const APNS_BUNDLE_ID   = Deno.env.get('APNS_BUNDLE_ID') ?? '';
const APNS_PRIVATE_KEY = Deno.env.get('APNS_PRIVATE_KEY') ?? '';
// production | sandbox | auto. Xcode 로 직접 돌린 앱의 기기 표는 sandbox
// 에서만, TestFlight·앱스토어 앱은 production 에서만 받습니다. auto 는
// 한쪽이 BadDeviceToken 을 내면 다른 쪽으로 한 번 더 넣어 봅니다.
const APNS_ENV = (Deno.env.get('APNS_ENV') ?? 'auto').toLowerCase();
const HAS_IOS = !!(APNS_KEY_ID && APNS_TEAM_ID && APNS_BUNDLE_ID && APNS_PRIVATE_KEY);

const APNS_HOST = {
  production: 'https://api.push.apple.com',
  sandbox: 'https://api.sandbox.push.apple.com',
};
function apnsHosts(): string[] {
  if (APNS_ENV === 'sandbox') return [APNS_HOST.sandbox];
  if (APNS_ENV === 'production') return [APNS_HOST.production];
  return [APNS_HOST.production, APNS_HOST.sandbox];
}

function b64url(bytes: Uint8Array): string {
  let s = '';
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
function b64urlText(s: string): string {
  return b64url(new TextEncoder().encode(s));
}
function pemToDer(pem: string): Uint8Array {
  // 비밀값으로 넣는 길이 여러 가지라 별게 다 섞여 들어옵니다 —
  // 줄바꿈이 \n 글자로, 따옴표가 그대로, 캐리지리턴, 앞뒤 공백.
  // 머리말을 걷어낸 다음 base64 글자가 아닌 것은 전부 버립니다.
  let clean = pem
    .replace(/\\n/g, '\n')
    .replace(/-----[^-]*-----/g, '')
    .replace(/[^A-Za-z0-9+/=]/g, '');
  // 길이가 4의 배수가 아니면 애플 키가 아니라 잘려 들어온 것입니다.
  // 패딩만 빠진 경우는 채워 줍니다.
  if (clean.length % 4 === 2) clean += '==';
  else if (clean.length % 4 === 3) clean += '=';
  if (!clean) throw new Error('APNS_PRIVATE_KEY 가 비어 있습니다');
  let raw: string;
  try { raw = atob(clean); }
  catch {
    // 키 내용은 절대 찍지 않습니다. 모양만 알려 줍니다.
    throw new Error(
      `APNS_PRIVATE_KEY 를 읽을 수 없습니다 (받은 길이 ${pem.length}, ` +
      `base64 글자만 남기면 ${clean.length}, 머리말 ` +
      `${/-----BEGIN/.test(pem) ? '있음' : '없음'}). ` +
      `AuthKey_XXXX.p8 안의 내용을 그대로 넣었는지 보세요.`,
    );
  }
  const out = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) out[i] = raw.charCodeAt(i);
  return out;
}

let _apnsKey: CryptoKey | null = null;
let _apnsJwt = { tok: '', at: 0 };

async function apnsJwt(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  // 애플은 1시간 넘은 토큰을 거절하고, 너무 자주 새로 만들어도 막습니다.
  if (_apnsJwt.tok && now - _apnsJwt.at < 2400) return _apnsJwt.tok;
  if (!_apnsKey) {
    const der = pemToDer(APNS_PRIVATE_KEY);
    try {
      _apnsKey = await crypto.subtle.importKey(
        'pkcs8', der, { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign'],
      );
    } catch (e) {
      throw new Error(
        `APNS_PRIVATE_KEY 가 애플 키 모양이 아닙니다 (${der.length}바이트). ` +
        `애플 .p8 은 보통 250바이트 안팎입니다. 원인: ${String(e)}`,
      );
    }
  }
  const head = b64urlText(JSON.stringify({ alg: 'ES256', kid: APNS_KEY_ID }));
  const body = b64urlText(JSON.stringify({ iss: APNS_TEAM_ID, iat: now }));
  const sig = new Uint8Array(await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' }, _apnsKey,
    new TextEncoder().encode(head + '.' + body),
  ));
  const tok = head + '.' + body + '.' + b64url(sig);
  _apnsJwt = { tok, at: now };
  return tok;
}

async function apnsPost(host: string, device: string, jwt: string, payload: unknown) {
  const r = await fetch(`${host}/3/device/${device}`, {
    method: 'POST',
    headers: {
      'authorization': 'bearer ' + jwt,
      'apns-topic': APNS_BUNDLE_ID,
      'apns-push-type': 'alert',
      'apns-priority': '10',
      'apns-expiration': String(Math.floor(Date.now() / 1000) + 3600),
      'content-type': 'application/json',
    },
    body: JSON.stringify(payload),
  });
  const txt = await r.text();          // 안 읽으면 연결이 남습니다
  let reason = '';
  if (r.status !== 200) { try { reason = String(JSON.parse(txt).reason ?? ''); } catch { reason = txt.slice(0, 120); } }
  return { status: r.status, reason };
}

// 보냈으면 true, 그 기기가 죽었으면 'dead', 아니면 false
async function apnsSend(device: string, payload: unknown): Promise<true | 'dead' | false> {
  const jwt = await apnsJwt();
  let last = { status: 0, reason: '' };
  for (const host of apnsHosts()) {
    last = await apnsPost(host, device, jwt, payload);
    if (last.status === 200) return true;
    // 환경이 어긋났을 때만 다른 쪽을 더 본다. 나머지는 더 봐도 같다.
    if (!(last.status === 400 && last.reason === 'BadDeviceToken')) break;
  }
  // 410 Unregistered = 앱을 지웠다. 400 BadDeviceToken = 쓸 수 없는 표.
  if (last.status === 410) return 'dead';
  if (last.status === 400 && (last.reason === 'BadDeviceToken' || last.reason === 'DeviceTokenNotForTopic')) return 'dead';
  console.error('APNs 실패', last.status, last.reason);
  return false;
}

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
  if (!HAS_WEB && !HAS_IOS) {
    return json({ error: '보낼 길이 없습니다. VAPID_* (웹) 또는 APNS_* (아이폰) 비밀값을 먼저 넣으세요.' }, 500);
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

  if (HAS_WEB) webpush.setVapidDetails(VAPID_SUBJECT, VAPID_PUBLIC, VAPID_PRIVATE);

  const who   = String(msg.sender_name ?? '새 메시지');
  const where = ch && ch.kind !== 'dm' && ch.name ? ' · ' + ch.name : '';
  const text  = previewOf(msg as Record<string, unknown>);

  let sent = 0;
  const dead: string[] = [];
  const ok = async (s: any) => {
    sent++;
    await admin.from('push_subscriptions')
      .update({ last_ok_at: new Date().toISOString(), fail_count: 0 }).eq('id', s.id);
  };
  const bad = async (s: any) => {
    await admin.from('push_subscriptions')
      .update({ fail_count: (s.fail_count ?? 0) + 1 }).eq('id', s.id);
  };

  await Promise.all(subs.map(async (s) => {
    if (!s.enabled) return;
    if (String(s.mutes ?? '').split(',').filter(Boolean).includes(msg.channel_id)) return;
    const myName = nameOf.get(s.member_id) ?? '';
    const mentioned = atAll || (!!myName && plain.includes('@' + myName));
    if (s.only_mention && !mentioned) return;

    const title = (mentioned ? '@ ' : '') + who + where;
    const bodyText = s.preview ? text : '새 메시지가 왔어요';

    // ── 🍎 아이폰 앱
    if (s.kind === 'ios') {
      if (!HAS_IOS) return;
      try {
        const r = await apnsSend(s.endpoint, {
          aps: {
            alert: { title, body: bodyText },
            sound: 'default',
            'thread-id': msg.channel_id,
          },
          channelId: msg.channel_id,
        });
        if (r === true) await ok(s);
        else if (r === 'dead') dead.push(s.id);
        else await bad(s);
      } catch (e) {
        console.error('APNs 던짐', String(e));
        await bad(s);
      }
      return;
    }

    // ── 브라우저 웹푸시
    if (!HAS_WEB || !s.p256dh || !s.auth) return;
    const payload = JSON.stringify({
      title, body: bodyText,
      tag: 'tcs-' + msg.channel_id,
      channelId: msg.channel_id,
    });
    try {
      await webpush.sendNotification(
        { endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } },
        payload,
        { TTL: 3600, urgency: 'high' },
      );
      await ok(s);
    } catch (e: any) {
      const code = e?.statusCode ?? 0;
      // 404·410 = 그 기기가 더는 받지 않는다(브라우저를 지웠거나 껐다). 치운다.
      if (code === 404 || code === 410) dead.push(s.id);
      else await bad(s);
    }
  }));

  if (dead.length) await admin.from('push_subscriptions').delete().in('id', dead);

  return json({ sent, removed: dead.length });
});
