-- =====================================================================
--  🩹 증명사진 주소 복구
--
--  무엇이 잘못됐나
--   앱에서 속성값을 다듬는 함수가 값을 100자에서 잘라 버렸습니다.
--   원래 답장 미리보기 한 곳을 위해 만든 건데 어느새 앱 전체에서 쓰이면서,
--   증명사진 주소(보통 190자쯤)가 100자에서 끊긴 채 저장됐습니다.
--
--     .../public/messenger/students/5b16f945-2b25-4      ← 여기서 끊김
--
--   사진 파일 자체는 멀쩡히 올라가 있습니다. 주소만 잘렸습니다.
--   그래서 다시 올릴 필요 없이, 저장된 주소만 제자리로 돌려놓으면 됩니다.
--
--   앱은 이미 고쳤습니다. 이 파일은 그 전에 잘려 저장된 것을 고칩니다.
--
--  Supabase → SQL Editor 에 붙여넣고 실행하세요. (재실행해도 안전)
-- =====================================================================


-- ── 1. 먼저 무엇이 깨져 있는지 본다 (고치지 않음) ──
select count(*) as "주소가 잘린 증명사진 수"
  from public.tcs_records r
 where r.section = 'personal'
   and coalesce(r.data->>'photo','') <> ''
   and r.data->>'photo' not like '%.jpg'
   and r.data->>'photo' not like '%.jpeg'
   and r.data->>'photo' not like '%.png';


-- ── 2. 학생마다 실제로 올라가 있는 가장 최근 사진을 찾아 주소를 되돌린다 ──
--  경로 규칙: students/<공동체>/<학생>/photo_<시각>.jpg
--  학생 id 로 찾으므로 공동체가 섞여 있어도 안전하다.
with base as (
  -- 잘리지 않은 주소에서 앞부분을 뽑아 둔다. 하나도 없으면 아래에서 직접 만든다.
  select coalesce(
    (select split_part(r.data->>'photo', '/storage/v1/object/public/messenger/', 1)
       from public.tcs_records r
      where r.section = 'personal'
        and r.data->>'photo' like 'https://%/storage/v1/object/public/messenger/%'
      limit 1),
    '') as origin
),
broken as (
  select r.student_id, r.section
    from public.tcs_records r
   where r.section = 'personal'
     and coalesce(r.data->>'photo','') <> ''
     and r.data->>'photo' not like '%.jpg'
     and r.data->>'photo' not like '%.jpeg'
     and r.data->>'photo' not like '%.png'
),
found as (
  select b.student_id,
         (select o.name
            from storage.objects o
           where o.bucket_id = 'messenger'
             and o.name like 'students/%/' || b.student_id::text || '/photo_%'
           order by o.created_at desc
           limit 1) as obj
    from broken b
)
update public.tcs_records r
   set data = jsonb_set(r.data, '{photo}',
                        to_jsonb((select origin from base) || '/storage/v1/object/public/messenger/' || f.obj))
  from found f
 where r.student_id = f.student_id
   and r.section = 'personal'
   and f.obj is not null
   and (select origin from base) <> '';


-- ── 3. 결과 ──
select r.student_id as "학생",
       m.name       as "이름",
       case when r.data->>'photo' like '%.jpg' or r.data->>'photo' like '%.jpeg'
                 or r.data->>'photo' like '%.png' then '✅ 고쳐짐'
            else '⚠️ 올라온 사진을 못 찾음 — 다시 올려주세요' end as "결과",
       length(r.data->>'photo') as "주소 길이"
  from public.tcs_records r
  left join public.members m on m.id = r.student_id
 where r.section = 'personal'
   and coalesce(r.data->>'photo','') <> ''
 order by 3, 2;

-- =====================================================================
--  ⚠️ 가 하나도 없으면 전부 제자리로 돌아왔습니다.
--  브라우저를 새로고침하면 사진이 다시 보입니다.
--
--  ⚠️ 가 있는 학생은 사진 파일 자체가 저장소에 없는 경우입니다.
--  그 학생만 다시 올려주세요.
-- =====================================================================
