// 🧪 시험용 밑자료 — 브라우저에 먼저 심어 두는 가짜 공동체.
//
//  index.html 을 진짜로 열어서 화면을 재 보려면, 로그인·Supabase 없이도
//  돌아갈 만큼의 자료가 있어야 합니다. 여기서 그걸 만듭니다.
//  (앞서 이 파일을 저장소 밖 /tmp 에 두었다가 컨테이너가 회수되면서
//   통째로 잃었습니다. 다시는 밖에 두지 않습니다.)
(() => {
  const CID = 'c1';
  const T = (d) => new Date(Date.now() + d * 86400000).toISOString();
  window.__seed = () => ({
    communities: [{ id: CID, name: 'IMUSA' }],
    members: [
      { id:'me', community_id:CID, community_role:'community_admin', role:'관리자', name:'김선생', initials:'김', color:'#1d3a5f', status:'approved', email:'teacher@example.com' },
      { id:'s1', community_id:CID, community_role:'student', role:'학생', name:'홍길동', initials:'홍', color:'#2a5298', status:'approved', grade:'3학년', birth_date:'2011-03-04' },
      { id:'s2', community_id:CID, community_role:'student', role:'학생', name:'김하은', initials:'김', color:'#6F8A5C', status:'approved', grade:'2학년', birth_date:'2012-07-09' },
      { id:'s3', community_id:CID, community_role:'student', role:'학생', name:'이준서', initials:'이', color:'#7B6BA0', status:'approved', grade:'3학년', birth_date:'2011-11-21' },
      { id:'t2', community_id:CID, community_role:'teacher', role:'교사', name:'박교사', initials:'박', color:'#5A7C8B', status:'approved' },
      { id:'p1', community_id:CID, community_role:'parent',  role:'학부모', name:'홍어머니', initials:'홍', color:'#be5b2a', status:'approved' },
    ],
    channels: [
      { id:'ch1', community_id:CID, name:'전체 공지', kind:'topic', pinned:true,  created_by:'me', created_at:T(-30) },
      { id:'ch2', community_id:CID, name:'3학년',     kind:'topic', pinned:false, created_by:'me', created_at:T(-20) },
      { id:'ch3', community_id:CID, name:'교사실',    kind:'topic', pinned:false, created_by:'me', created_at:T(-18) },
      { id:'ch4', community_id:CID, name:'학부모 공지', kind:'topic', pinned:false, created_by:'me', created_at:T(-9) },
    ],
    channel_members: ['ch1','ch2','ch3','ch4'].map(c => ({ channel_id:c, member_id:'me' })),
    messages: [
      { id:'m1', channel_id:'ch2', sender_id:'t2', sender_name:'박교사', text:'내일 체육대회 준비물 안내드립니다 🏃', created_at:T(-0.2) },
      { id:'m2', channel_id:'ch2', sender_id:'me', sender_name:'김선생', text:'체육복과 모자 챙겨오면 됩니다!',       created_at:T(-0.15) },
      { id:'m3', channel_id:'ch2', sender_id:'s1', sender_name:'홍길동', text:'선생님 물통도 가져가나요?',           created_at:T(-0.1) },
    ],
    events: [
      { id:'e1', community_id:CID, title:'체육대회',       start_date:T(1).slice(0,10), color:'#2a7a5a' },
      { id:'e2', community_id:CID, title:'학부모 상담주간', start_date:T(4).slice(0,10), color:'#be5b2a' },
    ],
  });
})();
