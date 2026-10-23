// 📞 통화에 쓸 TURN 자격을 만들어 준다
//
//  WebRTC 는 기기끼리 바로 잇는 게 먼저지만, 학교·회사 와이파이처럼
//  방화벽이 센 곳에서는 직접 연결이 안 된다. 그때 소리를 중계해 주는
//  것이 TURN 이다. 재 보면 전체 통화의 20~25% 가 이게 있어야 붙는다.
//
//  ⚠️ Cloudflare 가 주는 열쇠는 '오래 사는 비밀' 이라 앱에 넣으면 안 된다.
//     공개 저장소다. 여기(서버)에서만 들고 있다가, 로그인한 사람에게만
//     짧게 사는 자격을 만들어 준다.
//
//  필요한 비밀값 두 개:
//    CF_TURN_KEY_ID      Cloudflare → Realtime → TURN 에서 만든 키의 ID
//    CF_TURN_API_TOKEN   그 키의 토큰
//
//  둘 중 하나라도 없으면 STUN 만 돌려준다 — 집·휴대폰에서는 그래도 걸린다.
const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

// 아무것도 없을 때 쓰는 공짜 STUN. 중계는 못 하지만 대부분은 이걸로 붙는다.
const FALLBACK = [
  { urls: ['stun:stun.cloudflare.com:3478'] },
  { urls: ['stun:stun.l.google.com:19302'] },
];

function out(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });

  // 로그인한 사람만. 안 그러면 남이 우리 몫의 중계를 써 버린다.
  const auth = req.headers.get('Authorization') || '';
  if (!auth.startsWith('Bearer ')) return out({ error: '로그인이 필요합니다' }, 401);

  const SUPA = Deno.env.get('SUPABASE_URL') || '';
  const ANON = Deno.env.get('SUPABASE_ANON_KEY') || '';
  try {
    const who = await fetch(`${SUPA}/auth/v1/user`, {
      headers: { Authorization: auth, apikey: ANON },
    });
    if (!who.ok) return out({ error: '로그인이 필요합니다' }, 401);
  } catch (_) {
    return out({ error: '로그인을 확인하지 못했습니다' }, 401);
  }

  const KEY_ID = Deno.env.get('CF_TURN_KEY_ID') || '';
  const TOKEN = Deno.env.get('CF_TURN_API_TOKEN') || '';
  if (!KEY_ID || !TOKEN) {
    // 아직 설정 안 함 — 숨기지 않고 알려 준다. 왜 학교에서 안 걸리는지
    // 모른 채 헤매는 것보다 낫다.
    return out({ iceServers: FALLBACK, turn: false, why: 'CF_TURN_KEY_ID/CF_TURN_API_TOKEN 이 없습니다' });
  }

  try {
    const r = await fetch(
      `https://rtc.live.cloudflare.com/v1/turn/keys/${KEY_ID}/credentials/generate-ice-servers`,
      {
        method: 'POST',
        headers: { Authorization: `Bearer ${TOKEN}`, 'Content-Type': 'application/json' },
        // 통화 하나가 이보다 길 일은 없다. 짧을수록 새어도 덜 위험하다.
        body: JSON.stringify({ ttl: 3600 }),
      },
    );
    if (!r.ok) {
      const t = (await r.text()).slice(0, 200);
      return out({ iceServers: FALLBACK, turn: false, why: `Cloudflare ${r.status}: ${t}` });
    }
    const j = await r.json();
    const list = Array.isArray(j?.iceServers) ? j.iceServers
               : (j?.iceServers ? [j.iceServers] : null);
    if (!list) return out({ iceServers: FALLBACK, turn: false, why: '받은 모양이 낯섭니다' });
    return out({ iceServers: list, turn: true });
  } catch (e) {
    return out({ iceServers: FALLBACK, turn: false, why: String(e).slice(0, 160) });
  }
});
