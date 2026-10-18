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
  if (!clean) throw new Error('APNS_PRIVATE_KEY 가 비어 있습니다');
  // base64 는 길이가 4의 배수여야 합니다. 패딩(=)만 빠진 경우는 채웁니다.
  const rest = clean.length % 4;
  if (rest === 2) clean += '==';
  else if (rest === 3) clean += '=';
  // 나머지 1 은 있을 수 없는 길이입니다 — 글자가 빠졌거나 더해진 것이라
  // 채워도 소용이 없습니다. 어떻게 넣어야 하는지 바로 알려 줍니다.
  const how = 'openssl 로 키만 뽑아 넣으세요:  supabase secrets set APNS_PRIVATE_KEY=' +
              '"$(openssl pkcs8 -topk8 -nocrypt -in AuthKey_XXXX.p8 -outform DER | base64 | tr -d \'\\n\')"';
  // 키 내용은 절대 찍지 않습니다. 모양만 알려 줍니다.
  const shape = `받은 길이 ${pem.length}, base64 글자만 남기면 ${clean.length - (rest ? 4 - rest : 0)}, ` +
                `머리말 ${/-----BEGIN/.test(pem) ? '있음' : '없음'}`;
  if (rest === 1) {
    throw new Error(
      `APNS_PRIVATE_KEY 의 길이가 base64 로 있을 수 없는 값입니다 (${shape}). ` +
      `글자가 빠졌거나 더해졌습니다. 애플 키는 보통 184자입니다. ${how}`,
    );
  }
  let raw: string;
  try { raw = atob(clean); }
  catch {
    throw new Error(`APNS_PRIVATE_KEY 를 읽을 수 없습니다 (${shape}). ${how}`);
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
        `애플 .p8 의 알맹이는 138바이트 안팎입니다. ${how} 원인: ${String(e)}`,
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

  let body: { message_id?: string; check?: boolean };
  try { body = await req.json(); } catch { return json({ error: '잘못된 요청' }, 400); }
  const messageId = String(body.message_id ?? '');
  if (!messageId && !body.check) return json({ error: 'message_id 가 없습니다' }, 400);

  const url = Deno.env.get('SUPABASE_URL')!;
  // 부른 사람이 누구인지는 그 사람의 토큰으로 확인한다
  const asUser = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: auth } },
  });
  const { data: { user }, error: uErr } = await asUser.auth.getUser();
  if (uErr || !user) return json({ error: '로그인이 필요합니다' }, 401);

  // 보낼 대상은 RLS 너머라서 service_role 로 읽는다
  const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

  // ── 🔎 시험 ({ check: true }) ──────────────────────────────────────
  //  '왜 안 오지' 를 로그를 뒤지며 찾지 않게 한다. 부른 사람 '자기'
  //  기기에만 시험 알림을 쏘고, 애플·구글이 뭐라 했는지 그대로 돌려준다.
  //  남의 기기로는 절대 보내지 않는다 — 보냈다면 아무나 남을 괴롭힐 수 있다.
  //  키 내용은 길이와 모양만 돌려준다. 값은 어디에도 찍지 않는다.
  if (body.check) {
    const rep: Record<string, unknown> = {
      웹푸시_비밀값: HAS_WEB, 아이폰_비밀값: HAS_IOS,
      번들id: APNS_BUNDLE_ID || '(없음)', 보내는곳: APNS_ENV,
    };
    if (HAS_IOS) {
      const k: Record<string, unknown> = {
        받은_길이: APNS_PRIVATE_KEY.length,
        머리말: /-----BEGIN/.test(APNS_PRIVATE_KEY) ? '있음' : '없음',
        키id_길이: APNS_KEY_ID.length, 팀id_길이: APNS_TEAM_ID.length,
      };
      try { k.키_바이트 = pemToDer(APNS_PRIVATE_KEY).length; }
      catch (e) { k.오류 = String((e as Error).message ?? e); }
      try { k.토큰_서명 = (await apnsJwt()).split('.').length === 3 ? '됨' : '안 됨'; }
      catch (e) { k.토큰_서명 = String((e as Error).message ?? e); }
      rep.애플키 = k;
    }

    // 🔴 아이콘 숫자도 같이 확인한다. 시험 알림에 숫자가 안 붙으면
    //  '숫자가 되는지' 를 알 길이 없다 — 여기서 실제 안읽음 수를 붙여 본다.
    let myBadge: number | null = null;
    try {
      const { data: c, error: ce } = await admin.rpc('unread_counts', { p_members: [user.id] });
      if (ce) rep.아이콘숫자 = '못 셈 — ' + ce.message + ' (db/앱아이콘_숫자_DB설치.sql 을 돌렸나요?)';
      else {
        myBadge = Number((c ?? [])[0]?.n ?? 0);
        rep.아이콘숫자 = myBadge;
      }
    } catch (e) { rep.아이콘숫자 = '못 셈 — ' + String(e); }

    const { data: mine } = await admin.from('push_subscriptions')
      .select('*').eq('member_id', user.id);
    rep.내_기기수 = (mine ?? []).length;
    // 기기 수는 여기서 센다. 보낸 결과로 세면 한 기기에 두 번
    // 넣어 본 것(production·sandbox)을 두 대로 잘못 센다.
    rep.내_아이폰 = (mine ?? []).filter((x) => x.kind === 'ios').length;
    rep.내_브라우저 = (mine ?? []).filter((x) => x.kind !== 'ios').length;
    const out: unknown[] = [];
    for (const s of mine ?? []) {
      if (s.kind === 'ios') {
        if (!HAS_IOS) { out.push({ 길: 'ios', 건너뜀: 'APNS 비밀값이 없습니다' }); continue; }
        try {
          const jwt = await apnsJwt();
          for (const host of apnsHosts()) {
            const r = await apnsPost(host, s.endpoint, jwt, {
              aps: {
                alert: { title: 'TCS', body: '시험 알림입니다 🔔' }, sound: 'default',
                ...(typeof myBadge === 'number' ? { badge: myBadge } : {}),
              },
            });
            out.push({ 길: 'ios', 어디: host.includes('sandbox') ? 'sandbox' : 'production',
                       상태: r.status, 까닭: r.reason || (r.status === 200 ? '보냈습니다' : '') });
            if (r.status === 200) break;
            if (!(r.status === 400 && r.reason === 'BadDeviceToken')) break;
          }
        } catch (e) { out.push({ 길: 'ios', 오류: String((e as Error).message ?? e) }); }
      } else {
        if (!HAS_WEB) { out.push({ 길: 'web', 건너뜀: 'VAPID 비밀값이 없습니다' }); continue; }
        try {
          webpush.setVapidDetails(VAPID_SUBJECT, VAPID_PUBLIC, VAPID_PRIVATE);
          await webpush.sendNotification(
            { endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } },
            JSON.stringify({ title: 'TCS', body: '시험 알림입니다 🔔', tag: 'tcs-test' }),
            { TTL: 60 },
          );
          out.push({ 길: 'web', 상태: 201, 까닭: '보냈습니다' });
        } catch (e) {
          const err = e as { statusCode?: number; body?: string; message?: string };
          out.push({ 길: 'web', 상태: err?.statusCode ?? 0,
                     까닭: String(err?.body ?? err?.message ?? '').slice(0, 160) });
        }
      }
    }
    rep.결과 = out;
    return json(rep);
  }

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

  // ── 🔴 앱 아이콘의 빨간 숫자 ──
  //  애플은 보낸 payload 의 badge 칸에 적힌 수를 그대로 아이콘에 붙입니다.
  //  안 적어 보내면 아무것도 안 붙습니다 — 지금까지 그래서 숫자가 없었습니다.
  //  받는 사람마다 '지금 몇 개 안 읽었나' 가 다르므로 한 번에 세어 옵니다.
  //  (db/앱아이콘_숫자_DB설치.sql — 아직 안 깔았으면 그냥 숫자 없이 갑니다)
  const badgeOf = new Map<string, number>();
  try {
    const { data: cnt, error: cntErr } = await admin.rpc('unread_counts', { p_members: targets });
    if (cntErr) console.warn('안읽음 세기 건너뜀:', cntErr.message);
    else (cnt ?? []).forEach((r: { member_id: string; n: number }) =>
      badgeOf.set(r.member_id, Number(r.n) || 0));
  } catch (e) { console.warn('안읽음 세기 건너뜀:', String(e)); }

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
        const n = badgeOf.get(s.member_id);
        const r = await apnsSend(s.endpoint, {
          aps: {
            alert: { title, body: bodyText },
            sound: 'default',
            'thread-id': msg.channel_id,
            // 세지 못했으면 아예 안 적는다. 0 을 적으면 애플이
            // '다 읽었다' 로 알아듣고 있던 숫자까지 지운다.
            ...(typeof n === 'number' ? { badge: n } : {}),
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
      // 'badge' 라고 쓰면 안 된다 — 브라우저 알림에서 badge 는 '작은 단색
      // 아이콘' 을 뜻해서, 숫자를 넣으면 알림 아이콘이 깨진다. count 로 보낸다.
      count: badgeOf.get(s.member_id),   // 설치형(PWA·안드로이드)도 아이콘에 숫자를 단다
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
