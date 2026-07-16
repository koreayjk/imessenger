// Supabase Edge Function: store
// TCS 매점(가계부) 백엔드 — 재고/판매/지출/통계 + 학생 용돈 자동 차감.
//  · 판매·재고·지출 등 "매점 관리" 동작은 공동체별 비밀번호로 인증(service_role 로 처리).
//  · 비밀번호 설정(set_password)은 로그인한 관리자(JWT)만 가능.
//  service_role / URL / anon 키는 Supabase가 자동 주입하므로 별도 설정 불필요.
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

async function sha256(s: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return Array.from(new Uint8Array(buf)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

const admin = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } });

const CURRENCIES = ["원", "$", "₱"];
const normCurrency = (c: unknown) => (CURRENCIES.includes(String(c)) ? String(c) : "원");

// 비밀번호 검증 (매점 관리 동작 공통)
async function verifyPass(community_id: string, password: string) {
  if (!community_id) return { ok: false, msg: "공동체가 필요합니다" };
  const { data } = await admin.from("store_settings").select("pass_hash, store_name, currency").eq("community_id", community_id).single();
  if (!data || !data.pass_hash) return { ok: false, msg: "매점이 아직 설정되지 않았어요 (관리자가 비밀번호를 먼저 등록하세요)", code: "unset" };
  const h = await sha256(String(password || ""));
  if (h !== data.pass_hash) return { ok: false, msg: "비밀번호가 올바르지 않습니다", code: "badpass" };
  return { ok: true, store_name: data.store_name, currency: normCurrency(data.currency) };
}

// 호출자 정보 (JWT) 조회
async function getCaller(req: Request) {
  const authHeader = req.headers.get("Authorization") || "";
  const userClient = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: authHeader } }, auth: { persistSession: false },
  });
  const { data: { user } } = await userClient.auth.getUser();
  if (!user) return null;
  const { data: me } = await admin.from("members").select("community_role, community_id").eq("id", user.id).single();
  return me ? { id: user.id, ...me } : null;
}

// 로그인한 사용자가 해당 공동체 관리자인지 (set_password 용)
async function requireAdmin(req: Request, community_id: string) {
  const me = await getCaller(req);
  if (!me) return { ok: false, msg: "로그인이 필요합니다" };
  const isSuper = me.community_role === "super_admin";
  const isAdmin = ["community_admin", "admin_officer"].includes(me.community_role) && me.community_id === community_id;
  if (!isSuper && !isAdmin) return { ok: false, msg: "매점 비밀번호는 공동체 관리자만 설정할 수 있어요" };
  return { ok: true };
}

// 해당 공동체 구성원(또는 총관리자)인지 — 매점 현황/설정 조회용
async function requireMember(req: Request, community_id: string) {
  const me = await getCaller(req);
  if (!me) return { ok: false, msg: "로그인이 필요합니다" };
  if (me.community_role === "super_admin" || me.community_id === community_id) return { ok: true, role: me.community_role };
  return { ok: false, msg: "권한이 없습니다" };
}

const itemsSummary = (items: { name: string; qty: number }[]) =>
  items.map((i) => `${i.name}${i.qty > 1 ? "×" + i.qty : ""}`).join(", ");

const fmtMoney = (n: number, currency: string) => {
  const v = (Number(n) || 0).toLocaleString("en-US", { maximumFractionDigits: 2 });
  return currency === "원" ? v + "원" : currency + v;
};

// 영수증 텍스트(채팅 pre-wrap 로 보기 좋게)
function buildReceipt(storeName: string, lines: { name: string; qty: number; price: number }[], total: number, currency: string, buyerName: string, payMethod: string) {
  const now = new Date();
  const p2 = (x: number) => String(x).padStart(2, "0");
  const dt = `${now.getFullYear()}-${p2(now.getMonth() + 1)}-${p2(now.getDate())} ${p2(now.getHours())}:${p2(now.getMinutes())}`;
  const count = lines.reduce((s, l) => s + l.qty, 0);
  const itemLines = lines.map((l) => `• ${l.name} ×${l.qty} — ${fmtMoney(l.price * l.qty, currency)}`).join("\n");
  const pay = payMethod === "cash" ? "현금" : "용돈 차감";
  return [
    `🏪 ${storeName}`,
    `━━━━━━━━━━━━━`,
    `🧾 영수증 · ${dt}`,
    ``,
    itemLines,
    ``,
    `────────────`,
    `합계 ${count}개 · ${fmtMoney(total, currency)}`,
    `결제: ${pay}`,
    `구매자: ${buyerName || ""}`,
    `━━━━━━━━━━━━━`,
    `이용해 주셔서 감사합니다 🙏`,
  ].join("\n");
}

// 공동체별 '매점' 발신자(members 행) 확보 — 없으면 생성(숨김 처리)
async function ensureStoreBot(cid: string, storeName: string): Promise<string | null> {
  const { data: st } = await admin.from("store_settings").select("bot_member_id").eq("community_id", cid).single();
  if (st?.bot_member_id) {
    await admin.from("members").update({ name: storeName }).eq("id", st.bot_member_id);
    return st.bot_member_id;
  }
  const email = `store.${cid}@imstore.local`;
  let uid: string | null = null;
  const { data: created } = await admin.auth.admin.createUser({ email, password: crypto.randomUUID(), email_confirm: true, user_metadata: { store: true } });
  if (created?.user) uid = created.user.id;
  else {
    const { data: existing } = await admin.from("members").select("id").eq("email", email).maybeSingle();
    uid = existing?.id || null;
  }
  if (!uid) return null;
  // status='removed' 로 일반 구성원 목록에는 숨기되, 발신자(members)로는 존재
  await admin.from("members").upsert({
    id: uid, name: storeName, initials: "🏪", color: "#1d3a5f",
    role: "매점", community_role: "store_bot", email, status: "removed", community_id: cid,
  });
  await admin.from("store_settings").update({ bot_member_id: uid }).eq("community_id", cid);
  return uid;
}

// 매점↔구매자 1:1(DM) 채널 확보 — 없으면 생성
async function ensureReceiptDM(cid: string, botId: string, buyerId: string, storeName: string): Promise<string | null> {
  const { data: rows } = await admin.from("channel_members").select("channel_id, member_id").in("member_id", [botId, buyerId]);
  const map = new Map<string, Set<string>>();
  for (const r of rows || []) {
    const s = map.get(r.channel_id) || new Set<string>();
    s.add(r.member_id); map.set(r.channel_id, s);
  }
  for (const [chId, set] of map) {
    if (set.has(botId) && set.has(buyerId)) {
      const { data: ch } = await admin.from("channels").select("id, kind").eq("id", chId).single();
      if (ch && ch.kind === "dm") return chId;
    }
  }
  const { data: ch } = await admin.from("channels").insert({
    name: `${storeName} 영수증`, emoji: "🏪", description: "매점 결제 내역", pinned: false, kind: "dm", community_id: cid,
  }).select().single();
  if (!ch) return null;
  await admin.from("channel_members").insert([{ channel_id: ch.id, member_id: botId }, { channel_id: ch.id, member_id: buyerId }]);
  return ch.id;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const b = await req.json().catch(() => ({}));
    const action = String(b.action || "");
    const cid = String(b.community_id || "");

    // ── 관리자(JWT) 전용: 매점 비밀번호 설정/변경 ──
    if (action === "set_password") {
      const gate = await requireAdmin(req, cid);
      if (!gate.ok) return json({ error: gate.msg }, 200);
      const pw = String(b.password || "");
      if (pw.length < 4) return json({ error: "비밀번호는 4자 이상이어야 해요" }, 200);
      const pass_hash = await sha256(pw);
      const row: Record<string, unknown> = { community_id: cid, pass_hash, store_name: b.store_name || null, updated_at: new Date().toISOString() };
      if (b.currency !== undefined) row.currency = normCurrency(b.currency);
      const { error } = await admin.from("store_settings").upsert(row);
      if (error) return json({ error: error.message }, 200);
      return json({ ok: true });
    }
    // 매점 설정 여부·통화 확인 (교사·간사·관리자 등 공동체 구성원)
    if (action === "status") {
      const gate = await requireMember(req, cid);
      if (!gate.ok) return json({ error: gate.msg }, 200);
      const { data } = await admin.from("store_settings").select("pass_hash, store_name, currency").eq("community_id", cid).single();
      return json({ ok: true, configured: !!(data && data.pass_hash), store_name: data?.store_name || null, currency: normCurrency(data?.currency) });
    }

    // ── 이하 매점 관리 동작: 공동체 비밀번호 인증 필요 ──
    const v = await verifyPass(cid, b.password);
    if (!v.ok) return json({ error: v.msg, code: v.code }, 200);

    if (action === "login") {
      return json({ ok: true, store_name: v.store_name, currency: v.currency });
    }

    // 매점 설정 변경(가게 이름·통화) — 비밀번호는 여기서 바꾸지 않음
    if (action === "save_settings") {
      const row: Record<string, unknown> = { updated_at: new Date().toISOString() };
      if (b.store_name !== undefined) row.store_name = b.store_name || null;
      if (b.currency !== undefined) row.currency = normCurrency(b.currency);
      const { error } = await admin.from("store_settings").update(row).eq("community_id", cid);
      if (error) return json({ error: error.message }, 200);
      return json({ ok: true, currency: normCurrency(b.currency ?? v.currency), store_name: b.store_name ?? v.store_name });
    }

    if (action === "products") {
      const { data } = await admin.from("store_products").select("*").eq("community_id", cid).order("category").order("name");
      return json({ ok: true, products: data || [] });
    }

    if (action === "save_product") {
      const p = b.product || {};
      const row: Record<string, unknown> = {
        community_id: cid, name: (p.name || "").trim(), category: p.category || null,
        price: Number(p.price) || 0, cost: Number(p.cost) || 0, stock: Math.trunc(Number(p.stock) || 0),
        barcode: p.barcode || null, active: p.active !== false,
      };
      if (!row.name) return json({ error: "상품명을 입력하세요" }, 200);
      let res;
      if (p.id) res = await admin.from("store_products").update(row).eq("id", p.id).eq("community_id", cid).select().single();
      else res = await admin.from("store_products").insert(row).select().single();
      if (res.error) return json({ error: res.error.message }, 200);
      return json({ ok: true, product: res.data });
    }

    if (action === "delete_product") {
      const { error } = await admin.from("store_products").delete().eq("id", b.id).eq("community_id", cid);
      if (error) return json({ error: error.message }, 200);
      return json({ ok: true });
    }

    // 재고 조정(입고/실사): delta 만큼 증감
    if (action === "adjust_stock") {
      const { data: prod } = await admin.from("store_products").select("stock").eq("id", b.id).eq("community_id", cid).single();
      if (!prod) return json({ error: "상품을 찾을 수 없어요" }, 200);
      const next = Math.max(0, (prod.stock || 0) + Math.trunc(Number(b.delta) || 0));
      const { error } = await admin.from("store_products").update({ stock: next }).eq("id", b.id).eq("community_id", cid);
      if (error) return json({ error: error.message }, 200);
      return json({ ok: true, stock: next });
    }

    // 매점 이용 가능한 학생 목록
    if (action === "members") {
      const { data } = await admin.from("members")
        .select("id, name, grade, role, community_role, status")
        .eq("community_id", cid).order("name");
      // 학생뿐 아니라 그 공동체에 등록(승인)된 모든 구성원이 매점을 이용할 수 있음
      const roleOrder: Record<string, number> = { student: 0, staff: 1, teacher: 2, admin_officer: 3, community_admin: 4, super_admin: 5 };
      const people = (data || [])
        .filter((m) => m.status !== "removed" && m.status !== "pending" && m.community_role !== "store_bot")
        .sort((a, b) => (roleOrder[a.community_role] ?? 9) - (roleOrder[b.community_role] ?? 9) || String(a.name).localeCompare(String(b.name), "ko"));
      return json({ ok: true, members: people });
    }

    // ── 판매: 재고차감 + 영수증 저장 + (회원이면) 용돈 지출 자동 기록 ──
    if (action === "sale") {
      const items = Array.isArray(b.items) ? b.items : [];
      if (!items.length) return json({ error: "판매할 상품이 없어요" }, 200);
      const payMethod = b.pay_method === "cash" ? "cash" : "allowance";
      const memberId = b.member_id || null;
      if (payMethod === "allowance" && !memberId) return json({ error: "용돈 차감은 학생을 선택해야 해요" }, 200);

      // 상품 로드 & 재고/가격 확정
      const ids = items.map((i: { product_id: string }) => i.product_id);
      const { data: prods } = await admin.from("store_products").select("*").in("id", ids).eq("community_id", cid);
      const pmap = new Map((prods || []).map((p) => [p.id, p]));
      const lines: { product_id: string; name: string; qty: number; price: number }[] = [];
      let total = 0;
      for (const it of items) {
        const p = pmap.get(it.product_id);
        if (!p) return json({ error: "상품 정보를 찾을 수 없어요" }, 200);
        const qty = Math.max(1, Math.trunc(Number(it.qty) || 1));
        if ((p.stock || 0) < qty) return json({ error: `재고 부족: ${p.name} (남은 수량 ${p.stock || 0})` }, 200);
        lines.push({ product_id: p.id, name: p.name, qty, price: Number(p.price) || 0 });
        total += (Number(p.price) || 0) * qty;
      }

      let buyerName = b.buyer_name || null;
      let memberCommunity = cid;
      if (memberId) {
        const { data: mem } = await admin.from("members").select("name, community_id").eq("id", memberId).single();
        buyerName = mem?.name || buyerName;
        memberCommunity = mem?.community_id || cid;
      }

      // 영수증
      const { data: sale, error: sErr } = await admin.from("store_sales").insert({
        community_id: cid, member_id: memberId, buyer_name: buyerName, total,
        pay_method: payMethod, note: b.note || null, operator: b.operator || null,
      }).select().single();
      if (sErr || !sale) return json({ error: sErr?.message || "판매 저장 실패" }, 200);

      // 품목
      await admin.from("store_sale_items").insert(lines.map((l) => ({ sale_id: sale.id, ...l })));

      // 재고 차감
      for (const l of lines) {
        const p = pmap.get(l.product_id);
        await admin.from("store_products").update({ stock: Math.max(0, (p.stock || 0) - l.qty) }).eq("id", l.product_id);
      }

      // 용돈 자동 차감 (회원 + allowance 결제)
      let allowanceEntryId: string | null = null;
      if (memberId && payMethod === "allowance") {
        const today = new Date().toISOString().slice(0, 10);
        const { data: ae } = await admin.from("allowance_entries").insert({
          member_id: memberId, community_id: memberCommunity, date: today,
          type: "expense", category: "매점", memo: itemsSummary(lines), amount: total, currency: v.currency,
        }).select().single();
        if (ae) {
          allowanceEntryId = ae.id;
          await admin.from("store_sales").update({ allowance_entry_id: ae.id }).eq("id", sale.id);
        }
      }

      // 영수증을 구매자 개인 채팅(매점 발신자)으로 발송 — 구성원 결제 시
      let receiptSent = false;
      if (memberId) {
        try {
          const storeName = v.store_name || "매점";
          const botId = await ensureStoreBot(cid, storeName);
          if (botId) {
            const chId = await ensureReceiptDM(cid, botId, memberId, storeName);
            if (chId) {
              const text = buildReceipt(storeName, lines, total, v.currency, buyerName || "", payMethod);
              await admin.from("messages").insert({ channel_id: chId, sender_id: botId, sender_name: storeName, text, kind: "text" });
              receiptSent = true;
            }
          }
        } catch (_) { /* 영수증 실패는 판매를 막지 않음 */ }
      }

      return json({ ok: true, sale_id: sale.id, total, allowance_entry_id: allowanceEntryId, receipt: receiptSent });
    }

    // 판매 취소: 재고 복구 + 용돈 지출 삭제 + voided 처리
    if (action === "void_sale") {
      const { data: sale } = await admin.from("store_sales").select("*").eq("id", b.id).eq("community_id", cid).single();
      if (!sale) return json({ error: "판매 내역을 찾을 수 없어요" }, 200);
      if (sale.voided) return json({ ok: true });
      const { data: its } = await admin.from("store_sale_items").select("*").eq("sale_id", sale.id);
      for (const it of its || []) {
        if (!it.product_id) continue;
        const { data: p } = await admin.from("store_products").select("stock").eq("id", it.product_id).single();
        if (p) await admin.from("store_products").update({ stock: (p.stock || 0) + (it.qty || 0) }).eq("id", it.product_id);
      }
      if (sale.allowance_entry_id) await admin.from("allowance_entries").delete().eq("id", sale.allowance_entry_id);
      await admin.from("store_sales").update({ voided: true, allowance_entry_id: null }).eq("id", sale.id);
      return json({ ok: true });
    }

    // 판매 내역 (기간 필터 + 품목 포함)
    if (action === "sales") {
      let q = admin.from("store_sales").select("*, store_sale_items(*)").eq("community_id", cid).order("created_at", { ascending: false });
      if (b.from) q = q.gte("created_at", b.from);
      if (b.to) q = q.lte("created_at", b.to);
      const { data } = await q.limit(Number(b.limit) || 300);
      return json({ ok: true, sales: data || [] });
    }

    // 지출
    if (action === "expenses") {
      const { data } = await admin.from("store_expenses").select("*").eq("community_id", cid).order("date", { ascending: false }).limit(300);
      return json({ ok: true, expenses: data || [] });
    }
    if (action === "save_expense") {
      const e = b.expense || {};
      const row = { community_id: cid, date: e.date || new Date().toISOString().slice(0, 10), category: e.category || null, memo: e.memo || null, amount: Number(e.amount) || 0 };
      let res;
      if (e.id) res = await admin.from("store_expenses").update(row).eq("id", e.id).eq("community_id", cid);
      else res = await admin.from("store_expenses").insert(row);
      if (res.error) return json({ error: res.error.message }, 200);
      return json({ ok: true });
    }
    if (action === "delete_expense") {
      const { error } = await admin.from("store_expenses").delete().eq("id", b.id).eq("community_id", cid);
      if (error) return json({ error: error.message }, 200);
      return json({ ok: true });
    }

    // 통계: 학생별 일/주/월 지출 + 상품 랭킹 + 매출/지출 요약
    if (action === "stats") {
      const now = new Date();
      const dayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate()).toISOString();
      const weekStart = new Date(now.getTime() - 6 * 864e5).toISOString();
      const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).toISOString();

      const { data: sales } = await admin.from("store_sales")
        .select("member_id, buyer_name, total, created_at, voided, store_sale_items(name, qty)")
        .eq("community_id", cid).eq("voided", false).gte("created_at", monthStart).order("created_at", { ascending: false });

      const perStudent = new Map<string, { name: string; day: number; week: number; month: number; count: number }>();
      const productRank = new Map<string, number>();
      let daySum = 0, weekSum = 0, monthSum = 0;
      for (const s of sales || []) {
        const t = Number(s.total) || 0;
        const key = s.member_id || ("cash:" + (s.buyer_name || "현금"));
        const cur = perStudent.get(key) || { name: s.buyer_name || "현금", day: 0, week: 0, month: 0, count: 0 };
        cur.month += t; cur.count += 1;
        if (s.created_at >= weekStart) cur.week += t;
        if (s.created_at >= dayStart) cur.day += t;
        perStudent.set(key, cur);
        monthSum += t;
        if (s.created_at >= weekStart) weekSum += t;
        if (s.created_at >= dayStart) daySum += t;
        for (const it of s.store_sale_items || []) productRank.set(it.name, (productRank.get(it.name) || 0) + (it.qty || 0));
      }
      const students = [...perStudent.entries()].map(([k, v]) => ({ key: k, ...v })).sort((a, b2) => b2.month - a.month);
      const products = [...productRank.entries()].map(([name, qty]) => ({ name, qty })).sort((a, b2) => b2.qty - a.qty).slice(0, 10);

      // 재고/월 지출 요약
      const { data: prods } = await admin.from("store_products").select("name, stock, price").eq("community_id", cid).eq("active", true);
      const lowStock = (prods || []).filter((p) => (p.stock || 0) <= 5).sort((a, b2) => (a.stock || 0) - (b2.stock || 0));
      const { data: exps } = await admin.from("store_expenses").select("amount, date").eq("community_id", cid).gte("date", monthStart.slice(0, 10));
      const expMonth = (exps || []).reduce((s, e) => s + (Number(e.amount) || 0), 0);

      return json({
        ok: true,
        summary: { daySum, weekSum, monthSum, expMonth, netMonth: monthSum - expMonth, productCount: (prods || []).length },
        students, products, lowStock,
      });
    }

    return json({ error: "알 수 없는 동작: " + action }, 400);
  } catch (e) {
    return json({ error: String((e as Error)?.message || e) }, 400);
  }
});
