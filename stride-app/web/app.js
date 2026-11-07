/* ============================================================
   Stride · 步迹  —  Web 版（无 Mac 也能用）
   单文件状态 + localStorage；无依赖；离线可用（配合 HTTPS 部署）
   ============================================================ */

/* ---------------- 图标 ---------------- */
const svg = (d, sw = 2) =>
  `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="${sw}" stroke-linecap="round" stroke-linejoin="round">${d}</svg>`;

const I = {
  sun: svg('<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M2 12h2M20 12h2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M19.1 4.9l-1.4 1.4M6.3 17.7l-1.4 1.4"/>'),
  dumbbell: svg('<path d="M6 7v10M18 7v10M3 10v4M21 10v4M6 12h12"/>'),
  chart: svg('<path d="M4 19V5M4 19h16M8 15l3-4 3 3 4-6"/>'),
  chat: svg('<path d="M21 12a8.5 8.5 0 1 1-3.4-6.8L21 4l-1 4.2A8.4 8.4 0 0 1 21 12z"/><path d="M9 11h.01M13 11h.01"/>'),
  person: svg('<circle cx="12" cy="8" r="3.4"/><path d="M5 20c1.4-3.4 3.9-5 7-5s5.6 1.6 7 5"/>'),
  crown: svg('<path d="M3 8l4 4 5-7 5 7 4-4v9a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1z"/>'),
  flame: svg('<path d="M12 3c3 4 5 6 5 9a5 5 0 0 1-10 0c0-3 2-5 5-9z"/>'),
  walk: svg('<circle cx="13" cy="4" r="2"/><path d="M11 21l2-6-3-2 1-4 3 2 3 1"/><path d="M9 12l-2 3"/>'),
  clock: svg('<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>'),
  camera: svg('<path d="M4 8h3l2-2h6l2 2h3a1 1 0 0 1 1 1v9a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V9a1 1 0 0 1 1-1z"/><circle cx="12" cy="13" r="3.2"/>'),
  run: svg('<circle cx="14" cy="4" r="2"/><path d="M9 21l2-5-3-2 1-4 3 2 3 1"/><path d="M6 12l-1 3"/>'),
  sparkles: svg('<path d="M12 3l1.6 4.4L18 9l-4.4 1.6L12 15l-1.6-4.4L6 9l4.4-1.6z"/><path d="M18 15l.8 2.2L21 18l-2.2.8L18 21l-.8-2.2L15 18l2.2-.8z"/>'),
  map: svg('<path d="M9 4L3 6.5v14L9 18l6 2.5 6-2.5v-14L15 6.5z"/><path d="M9 4v14M15 6.5v14"/>'),
  music: svg('<path d="M9 18V6l10-2v12"/><circle cx="6.5" cy="18" r="2.5"/><circle cx="16.5" cy="16" r="2.5"/>'),
  heart: svg('<path d="M12 20s-7-4.4-7-9a4 4 0 0 1 7-2.6A4 4 0 0 1 19 11c0 4.6-7 9-7 9z"/>'),
  watch: svg('<rect x="7" y="6" width="10" height="12" rx="3"/><path d="M9 6V3h6v3M9 18v3h6v-3"/>'),
  grid: svg('<rect x="3" y="3" width="7" height="7" rx="2"/><rect x="14" y="3" width="7" height="7" rx="2"/><rect x="3" y="14" width="7" height="7" rx="2"/><rect x="14" y="14" width="7" height="7" rx="2"/>'),
  timer: svg('<circle cx="12" cy="13" r="8"/><path d="M12 9v4l2.5 1.5M9 2h6"/>'),
  fn: svg('<path d="M6 20c2 0 3-1.5 3.5-4L11 8c.5-2.5 1.5-4 3.5-4M8 12h5"/>'),
  plate: svg('<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="2"/>'),
  sliders: svg('<path d="M4 6h9M17 6h3M4 12h3M11 12h9M4 18h11M19 18h1"/><circle cx="15" cy="6" r="2"/><circle cx="9" cy="12" r="2"/><circle cx="17" cy="18" r="2"/>'),
  up: svg('<path d="M12 19V5M6 11l6-6 6 6"/>'),
  share: svg('<path d="M12 16V4M8 8l4-4 4 4"/><path d="M4 14v5a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-5"/>'),
  trash: svg('<path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13"/>'),
  lock: svg('<rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>'),
  back: svg('<path d="M15 18l-6-6 6-6"/>'),
  info: svg('<circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 8h.01"/>'),
  bolt: svg('<path d="M13 2L4 14h6l-1 8 9-12h-6z"/>'),
  plus: svg('<path d="M12 5v14M5 12h14"/>'),
  play: svg('<path d="M8 5l11 7-11 7z"/>'),
  pause: svg('<path d="M9 5v14M15 5v14"/>'),
  check: svg('<path d="M20 6L9 17l-5-5"/>', 3),
  x: svg('<path d="M18 6L6 18M6 6l12 12"/>', 2.4),
  arrowUp: svg('<path d="M12 19V5M6 11l6-6 6 6"/>', 2.4),
  refresh: svg('<path d="M20 11a8 8 0 1 0-2 6"/><path d="M20 5v6h-6"/>'),
  doc: svg('<path d="M6 3h7l5 5v13H6z"/><path d="M13 3v5h5"/>'),
  scale: svg('<path d="M5 8h14l-2 12H7z"/><path d="M9 8a3 3 0 0 1 6 0"/>'),
  enter: svg('<path d="M5 12h13M13 6l6 6-6 6"/>', 2.4)
};

/* ---------------- 工具 ---------------- */
const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => Array.from(r.querySelectorAll(s));
const uid = () => Math.random().toString(36).slice(2, 10);
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const pad = (n) => String(n).padStart(2, '0');
const dayKey = (d = new Date()) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
const daysAgo = (n) => { const d = new Date(); d.setHours(12, 0, 0, 0); d.setDate(d.getDate() - n); return d; };
const num = (v, d = 0) => (v == null || isNaN(v) ? d : Number(v));
const fmt1 = (v) => (Number.isInteger(v) ? String(v) : v.toFixed(1));

/* ---------------- 数据 ---------------- */
const KEY = 'stride.state.v2';
const WEEK_CN = ['日', '一', '二', '三', '四', '五', '六'];

const LIB = [
  ['杠铃卧推', '胸', '杠铃', 6.0, 0, '肩胛后缩下沉，杠铃触胸不留弹'],
  ['上斜哑铃卧推', '胸', '哑铃', 5.5, 0, '30 度上斜，肘部 45 度夹角'],
  ['双杠臂屈伸', '胸', '自重', 6.5, 0, '身体前倾，下到肩低于肘'],
  ['绳索夹胸', '胸', '绳索', 4.5, 0, '肘微屈固定，用胸把把手抱合'],
  ['引体向上', '背', '自重', 7.0, 0, '先沉肩再拉，胸口找杠'],
  ['杠铃划船', '背', '杠铃', 6.0, 0, '髋主导，杠铃贴腿上拉'],
  ['高位下拉', '背', '器械', 5.0, 0, '下拉到锁骨，别用二头抢'],
  ['坐姿绳索划船', '背', '绳索', 5.0, 0, '胸挺住，肩胛先动再收肘'],
  ['深蹲', '腿', '杠铃', 7.5, 0, '脚掌三点压实，膝盖跟脚尖同向'],
  ['罗马尼亚硬拉', '腿', '杠铃', 7.0, 0, '屈髋不屈腰，腘绳肌拉长感'],
  ['保加利亚分腿蹲', '腿', '哑铃', 7.0, 0, '前脚踩稳，后脚只是支点'],
  ['腿举', '腿', '器械', 5.5, 0, '别锁膝，下放到腰不卷'],
  ['站姿提踵', '腿', '器械', 4.0, 0, '顶点停 1 秒，下放到底'],
  ['站姿推举', '肩', '杠铃', 6.0, 0, '核心收紧，杠过头顶后收下巴'],
  ['哑铃侧平举', '肩', '哑铃', 4.0, 0, '小指略高，别耸肩'],
  ['面拉', '肩', '绳索', 4.0, 0, '拉向眉心，外旋收尾'],
  ['杠铃弯举', '手臂', '杠铃', 4.0, 0, '肘固定，离心 3 秒'],
  ['绳索下压', '手臂', '绳索', 4.0, 0, '肘夹紧，底端完全伸直'],
  ['悬垂举腿', '核心', '自重', 5.0, 0, '骨盆后倾，别只抬腿'],
  ['平板支撑', '核心', '自重', 3.5, 1, '肋骨收拢，臀腿绷紧'],
  ['健腹轮', '核心', '自重', 5.0, 0, '腰不塌，用腹回拉'],
  ['跑步', '有氧', '自重', 9.8, 1, '步频 170+，落地在身体正下方']
];

const FOOD_DB = [
  ['鸡胸肉', 165, 31, 0, 3.6, 150], ['鸡蛋', 143, 13, 1.1, 9.5, 100],
  ['牛里脊', 143, 22, 0, 6, 150], ['三文鱼', 208, 20, 0, 13, 130],
  ['虾仁', 99, 21, 0, 0.9, 120], ['希腊酸奶', 97, 9, 4, 5, 150],
  ['乳清蛋白粉', 400, 80, 8, 6, 30], ['全脂牛奶', 61, 3.2, 4.8, 3.3, 250],
  ['白米饭', 116, 2.6, 25.9, 0.3, 200], ['糙米饭', 116, 2.5, 24, 0.9, 200],
  ['全麦吐司', 250, 10, 45, 3, 70], ['燕麦片', 389, 17, 66, 7, 50],
  ['红薯', 86, 1.6, 20, 0.1, 200], ['土豆', 77, 2, 17, 0.1, 200],
  ['西兰花', 34, 2.8, 6.6, 0.4, 150], ['菠菜', 23, 2.9, 3.6, 0.4, 100],
  ['牛油果', 160, 2, 9, 15, 100], ['香蕉', 89, 1.1, 23, 0.3, 120],
  ['苹果', 52, 0.3, 14, 0.2, 180], ['蓝莓', 57, 0.7, 14, 0.3, 80],
  ['坚果混合', 607, 20, 21, 54, 25], ['花生酱', 588, 25, 20, 50, 20],
  ['橄榄油', 884, 0, 0, 100, 10], ['美式咖啡', 2, 0.1, 0, 0, 300],
  ['拿铁', 56, 3, 5, 2.6, 300], ['可乐', 42, 0, 10.6, 0, 330],
  ['汉堡', 295, 13, 30, 13, 200], ['炒饭', 168, 4.5, 26, 5, 300],
  ['牛肉面', 122, 7, 16, 3, 500], ['煎饺', 240, 8, 26, 11, 180]
].map(([name, kcal, p, c, f, g]) => ({ name, kcal, p, c, f, g }));

const PLANS = [
  { id: 'max.yearly', name: '年付', badge: '最划算', price: '14,99 € / 年', per: '折合 1,25 €/月', strike: '23,88 €', save: '省 8,89 € · -37%', months: 12 },
  { id: 'max.half', name: '半年付', badge: null, price: '7,99 € / 半年', per: '折合 1,33 €/月', strike: '11,94 €', save: '省 3,95 € · -33%', months: 6 },
  { id: 'max.monthly', name: '月付', badge: null, price: '1,99 € / 月', per: null, strike: null, save: null, months: 1 }
];

const MAX_BENEFITS = [
  'AI 热量识别不限次数', 'AI 教练对话不限次数', '渐进式 AI 学习',
  'iCloud 数据同步', '歌单链接导入解析', '含 Pro 全部权益'
];
const PRO_BENEFITS = [
  '每天 40 次 AI 热量识别', '更充裕的 AI 教练对话额度', 'AI 生成训练计划',
  '渐进式 AI 学习', 'iCloud 数据同步', '歌单链接导入解析', '全部足迹画风与分享模板'
];
const FREE_PERKS = [
  ['figure', '完整训练与记录'], ['camera', '每天 10 次 AI 热量识别'],
  ['sparkles', 'AI 教练对话免费体验 20 次'], ['watch', 'Apple Watch 连接与实时同步'],
  ['grid', '插件市场全部小工具'], ['dumbbell', '视觉动作计数'],
  ['heart', 'Apple 健康双向同步'], ['map', '3 套足迹画风 · 1 套分享模板'],
  ['music', '歌词同步不限次数']
];

/* ---------------- 状态 ---------------- */
let S = load();

function load() {
  try {
    const raw = localStorage.getItem(KEY);
    if (raw) return JSON.parse(raw);
  } catch (e) { }
  const s = seed();
  save(s);
  return s;
}
function save(s = S) {
  try { localStorage.setItem(KEY, JSON.stringify(s)); } catch (e) { }
}

function seed() {
  const ex = LIB.map(([name, group, equip, met, timed, cue]) => ({
    id: uid(), name, group, equip, met, timed: !!timed, cue
  }));

  const mk = (offset, title, list, min, kcal) => ({
    id: uid(),
    date: daysAgo(offset).toISOString(),
    title,
    kind: '力量',
    exercises: list.map(([name, ws, rs]) => {
      const e = ex.find(x => x.name === name) || { id: uid(), group: '胸', timed: false };
      return {
        id: uid(), name, group: e.group, timed: e.timed,
        sets: ws.map((w, i) => ({ w, r: rs[i] ?? rs[rs.length - 1], done: true }))
      };
    }),
    minutes: min, kcal
  });

  const sessions = [
    mk(1, '推 · 上斜', [['杠铃卧推', [60, 60, 62.5, 62.5], [10, 9, 8, 8]], ['上斜哑铃卧推', [22, 22, 24], [10, 10, 8]], ['哑铃侧平举', [8, 8, 8], [15, 14, 12]], ['绳索下压', [25, 25, 25], [14, 12, 12]]], 62, 420),
    mk(3, '拉 · 背厚度', [['引体向上', [0, 0, 0], [9, 8, 7]], ['杠铃划船', [55, 57.5, 57.5], [10, 9, 9]], ['高位下拉', [55, 57.5, 57.5], [12, 11, 10]], ['面拉', [20, 20, 20], [15, 15, 15]]], 58, 395),
    mk(5, '腿 · 深蹲容量', [['深蹲', [80, 85, 85, 85], [8, 6, 6, 5]], ['罗马尼亚硬拉', [70, 75, 75], [10, 9, 9]], ['腿举', [120, 130, 130], [12, 12, 10]], ['站姿提踵', [40, 40, 40], [18, 16, 15]]], 68, 505),
    mk(8, '推 · 卧推力量', [['杠铃卧推', [62.5, 65, 65, 62.5], [8, 6, 5, 8]], ['站姿推举', [37.5, 37.5, 37.5], [8, 8, 7]], ['绳索夹胸', [18, 18, 18], [15, 14, 12]]], 60, 410),
    mk(10, '拉 · 引体', [['引体向上', [0, 0, 0, 0], [8, 7, 6, 5]], ['坐姿绳索划船', [55, 55, 57.5], [12, 12, 10]], ['杠铃弯举', [27.5, 27.5, 27.5], [10, 9, 8]]], 55, 375),
    mk(12, '腿 · 后链', [['罗马尼亚硬拉', [75, 80, 82.5], [10, 8, 8]], ['保加利亚分腿蹲', [16, 16, 16], [10, 10, 9]], ['腿举', [130, 140, 140], [12, 10, 10]]], 64, 470),
    mk(15, '推 · 上斜', [['上斜哑铃卧推', [24, 24, 26], [10, 9, 8]], ['双杠臂屈伸', [0, 0, 0], [12, 10, 9]], ['哑铃侧平举', [8, 8, 9], [15, 13, 12]]], 57, 385),
    mk(17, '拉 · 背厚度', [['杠铃划船', [55, 55, 57.5], [10, 10, 8]], ['引体向上', [0, 0, 0], [8, 7, 6]], ['高位下拉', [52.5, 55, 55], [12, 10, 10]]], 56, 380),
    mk(20, '腿 · 深蹲力量', [['深蹲', [85, 90, 92.5, 85], [6, 4, 3, 6]], ['罗马尼亚硬拉', [70, 75, 75], [10, 8, 8]], ['站姿提踵', [40, 42.5, 42.5], [18, 15, 15]]], 61, 455),
    mk(23, '推 · 卧推容量', [['杠铃卧推', [60, 60, 60, 60, 60], [10, 10, 9, 9, 8]], ['站姿推举', [35, 37.5, 37.5], [10, 8, 8]], ['绳索夹胸', [17.5, 17.5, 17.5], [15, 14, 14]]], 52, 350)
  ];

  const foods = [
    { id: uid(), meal: '加餐', date: new Date().setHours(16, 5), ai: true, items: [
      { name: '希腊酸奶', g: 150, kcal: 145, p: 15, c: 8, f: 5 },
      { name: '蓝莓', g: 80, kcal: 46, p: 1, c: 11, f: 0 }] },
    { id: uid(), meal: '午餐', date: new Date().setHours(12, 40), ai: true, items: [
      { name: '鸡胸肉', g: 180, kcal: 297, p: 56, c: 0, f: 6 },
      { name: '糙米饭', g: 200, kcal: 232, p: 5, c: 48, f: 2 },
      { name: '西兰花', g: 150, kcal: 51, p: 4, c: 10, f: 1 }] },
    { id: uid(), meal: '早餐', date: new Date().setHours(8, 10), ai: false, items: [
      { name: '全麦吐司', g: 70, kcal: 175, p: 7, c: 32, f: 2 },
      { name: '鸡蛋', g: 100, kcal: 143, p: 13, c: 1, f: 10 },
      { name: '美式咖啡', g: 300, kcal: 6, p: 0, c: 1, f: 0 }] }
  ];

  const specs = [
    [2, '夜跑 · 外滩', 6.42, 34, 'neon'], [4, '晨跑 · 苏州河', 5.18, 29, 'ink'],
    [7, '间歇 · 世纪公园', 8.05, 44, 'gradient'], [11, '恢复跑', 3.6, 22, 'dots'],
    [14, '长距离', 12.3, 71, 'contour'], [18, '节奏跑', 7.0, 39, 'aurora']
  ];
  const runs = specs.map(([d, title, km, min, style]) => ({
    id: uid(), date: daysAgo(d).toISOString(), title,
    km, sec: min * 60,
    pts: loop(31.2304, 121.4737, 0.004 + km / 3000, 220, d),
    style, template: 'card'
  }));

  const snaps = [];
  const vals = [[8420, 520, 62], [10240, 610, 71], [5230, 280, 0], [11800, 720, 84],
    [9100, 560, 58], [4300, 210, 0], [12650, 780, 96], [7800, 470, 52],
    [10400, 650, 68], [6900, 400, 45], [11200, 700, 80], [5600, 300, 0],
    [9800, 600, 66], [8700, 540, 54]];
  vals.forEach((v, i) => snaps.push({
    date: daysAgo(i).toISOString(), steps: v[0], kcal: v[1], min: v[2], w: 76 - i * 0.05
  }));

  return {
    profile: { name: 'YG', goal: '重塑', exp: '进阶', days: 4, h: 178, w: 76, age: 30, male: true, kcalGoal: 2200 },
    exercises: ex,
    sessions,
    foods,
    runs,
    snaps,
    chats: [{ role: 'ai', text: '我是你的教练。今天想练什么——推、拉，还是腿？\n也可以直接把感受丢给我：「昨天卧推 62.5 做了 8 次还有余力」。', at: Date.now() }],
    plan: makePlan('重塑', 4, '进阶'),
    membership: { planId: 'max.monthly', tier: 'max' },
    quotas: { food: {} },
    ai: { base: 'https://api.openai.com/v1', key: '', model: 'gpt-4o-mini' },
    playlists: [],
    seeded: true
  };
}

/* ---------------- 计划生成 ---------------- */
function makePlan(goal, days, exp) {
  const splits = {
    3: [['全身 A · 蹲', ['深蹲', '杠铃卧推', '杠铃划船', '平板支撑']],
      ['全身 B · 髋', ['罗马尼亚硬拉', '站姿推举', '引体向上', '悬垂举腿']],
      ['全身 C · 推', ['上斜哑铃卧推', '高位下拉', '保加利亚分腿蹲', '面拉']]],
    4: [['推 · 胸肩三头', ['杠铃卧推', '上斜哑铃卧推', '哑铃侧平举', '绳索下压']],
      ['拉 · 背二头', ['引体向上', '杠铃划船', '坐姿绳索划船', '杠铃弯举']],
      ['腿 · 股四', ['深蹲', '腿举', '保加利亚分腿蹲', '站姿提踵']],
      ['上肢 · 容量', ['站姿推举', '高位下拉', '绳索夹胸', '面拉']]],
    5: [['推', ['杠铃卧推', '上斜哑铃卧推', '哑铃侧平举', '绳索下压']],
      ['拉', ['引体向上', '杠铃划船', '高位下拉', '杠铃弯举']],
      ['腿', ['深蹲', '罗马尼亚硬拉', '腿举', '站姿提踵']],
      ['上肢 · 容量', ['站姿推举', '绳索夹胸', '面拉', '杠铃弯举']],
      ['下肢 · 后链', ['罗马尼亚硬拉', '保加利亚分腿蹲', '腿举', '健腹轮']]],
    6: [['推 A', ['杠铃卧推', '上斜哑铃卧推', '哑铃侧平举', '绳索下压']],
      ['拉 A', ['引体向上', '杠铃划船', '坐姿绳索划船', '杠铃弯举']],
      ['腿 A', ['深蹲', '腿举', '站姿提踵', '健腹轮']],
      ['推 B', ['站姿推举', '双杠臂屈伸', '绳索夹胸', '杠铃弯举']],
      ['拉 B', ['高位下拉', '面拉', '杠铃划船', '悬垂举腿']],
      ['腿 B', ['罗马尼亚硬拉', '保加利亚分腿蹲', '腿举', '平板支撑']]]
  };
  const key = clamp(days, 3, 6);
  const list = splits[key] || splits[4];
  const order = [1, 2, 4, 5, 3, 6]; // 一 二 四 五 三 六
  const repRange = goal === '减脂' ? '8–12' : goal === '增肌' ? '5–8' : goal === '耐力' ? '12–15' : '6–10';
  const out = [];
  for (let wd = 0; wd < 7; wd++) {
    const idx = order.indexOf(wd);
    if (idx >= 0 && idx < list.length) {
      out.push({
        wd, title: list[idx][0], rest: false,
        items: list[idx][1].map(n => {
          const e = LIB.find(x => x[0] === n);
          return { name: n, sets: e && e[1] === '核心' ? 3 : 4, reps: e && e[4] ? '40–60 秒' : repRange };
        })
      });
    } else {
      out.push({ wd, title: '恢复', rest: true, items: [{ name: '快走 20 分钟', sets: 1, reps: '20 min' }] });
    }
  }
  return { goal, days: key, exp, created: Date.now(), items: out };
}

/* ---------------- 计算 ---------------- */
const sortedSessions = () => [...S.sessions].sort((a, b) => new Date(b.date) - new Date(a.date));
const sessionsToday = () => S.sessions.filter(s => dayKey(new Date(s.date)) === dayKey());
const weekSessions = () => {
  const now = new Date();
  const start = new Date(now); start.setDate(now.getDate() - ((now.getDay() + 6) % 7)); start.setHours(0, 0, 0, 0);
  return S.sessions.filter(s => new Date(s.date) >= start);
};
const totalVolume = (s) => s.exercises.reduce((a, e) => a + e.sets.reduce((b, x) => b + x.w * x.r, 0), 0);
const totalSets = (s) => s.exercises.reduce((a, e) => a + e.sets.length, 0);

function todaySnap() {
  const k = dayKey();
  return S.snaps.find(s => dayKey(new Date(s.date)) === k) || { steps: 0, kcal: 0, min: 0, w: S.profile.w };
}
function nutritionToday() {
  const k = dayKey();
  const list = S.foods.filter(f => dayKey(new Date(f.date)) === k);
  const sum = (key) => list.reduce((a, f) => a + f.items.reduce((b, i) => b + (i[key] || 0), 0), 0);
  return { kcal: sum('kcal'), p: sum('p'), c: sum('c'), f: sum('f') };
}
function streak() {
  const days = new Set(S.sessions.map(s => dayKey(new Date(s.date))));
  let n = 0, d = new Date();
  while (days.has(dayKey(d))) { n++; d.setDate(d.getDate() - 1); }
  return n;
}
function e1rm(w, r) { return r <= 1 ? w : w * (1 + r / 30); }
function historyOf(name) {
  const out = [];
  [...S.sessions].sort((a, b) => new Date(a.date) - new Date(b.date)).forEach(s => {
    s.exercises.filter(e => e.name === name).forEach(e => {
      const best = e.sets.reduce((a, b) => (b.w > a.w ? b : a), { w: 0, r: 0 });
      if (best.w > 0) out.push({ date: s.date, e1rm: e1rm(best.w, best.r) });
    });
  });
  return out;
}
function weeklyVolume() {
  const buckets = new Map();
  S.sessions.forEach(s => {
    const d = new Date(s.date);
    const mon = new Date(d); mon.setDate(d.getDate() - ((d.getDay() + 6) % 7)); mon.setHours(0, 0, 0, 0);
    const k = dayKey(mon);
    buckets.set(k, (buckets.get(k) || 0) + totalVolume(s));
  });
  return [...buckets.entries()].sort((a, b) => a[0] < b[0] ? -1 : 1).map(([k, v]) => ({ k, v }));
}
function todaysPlan() {
  const wd = (new Date().getDay() + 6) % 7; // 周一=0
  return S.plan.items.find(d => d.wd === wd && !d.rest) || null;
}
function loop(lat, lon, r, n, seed) {
  const pts = [];
  for (let i = 0; i < n; i++) {
    const t = i / n * Math.PI * 2;
    const w = 1 + 0.18 * Math.sin(3 * t + seed) + 0.1 * Math.cos(5 * t + seed * 0.7) + 0.05 * Math.sin(9 * t);
    pts.push({ lat: lat + r * w * Math.cos(t) * 0.9, lon: lon + r * w * Math.sin(t) * 1.15 });
  }
  return pts;
}

/* ---------------- Toast ---------------- */
function toast(text) {
  const root = $('#toast-root');
  root.innerHTML = `<div class="toast">${I.check}<span>${text}</span></div>`;
  clearTimeout(toast._t);
  toast._t = setTimeout(() => { root.innerHTML = ''; }, 1900);
}

/* ---------------- 渲染骨架 ---------------- */
let TAB = 'today';

function render() {
  const screen = $('#screen');
  const map = { today: viewToday, training: viewTraining, progress: viewProgress, coach: viewCoach, me: viewMe };
  screen.innerHTML = (map[TAB] || viewToday)();
  $$('.tab').forEach(b => b.classList.toggle('on', b.dataset.tab === TAB));
  // 等一帧再画：canvas 需要先完成布局才有 clientWidth
  if (TAB === 'progress') requestAnimationFrame(drawProgressCharts);
  if (TAB === 'today') requestAnimationFrame(drawTodayRing);
}

function setTab(t) {
  if (TAB === t) return;
  TAB = t;
  window.scrollTo(0, 0);
  render();
}

/* ---------------- 今日 ---------------- */
function viewToday() {
  const p = S.profile;
  const snap = todaySnap();
  const nut = nutritionToday();
  const plan = todaysPlan();
  const h = new Date().getHours();
  const greet = h < 5 ? '该睡了' : h < 11 ? '早上好' : h < 14 ? '中午好' : h < 18 ? '下午好' : h < 23 ? '晚上好' : '该睡了';
  const dateStr = new Date().toLocaleDateString('zh-CN', { month: 'numeric', day: 'numeric', weekday: 'long' });
  const last = sortedSessions()[0];

  return `
  <div class="topline">
    <div>
      <div class="greet">${greet}</div>
      <h1 class="h1">${p.name}</h1>
      <div class="date">${dateStr}</div>
    </div>
    <button class="crown" data-act="membership">${I.crown}<span>${S.membership.tier === 'max' ? 'MAX' : '升级'}</span></button>
  </div>

  <div class="card" style="display:flex;gap:18px;align-items:center;">
    <div class="ring" id="today-ring"></div>
    <div class="stat-line">
      <div>
        <div class="sl-v">${snap.steps.toLocaleString()}<span class="sl-u">步</span></div>
        <div class="sl-h">目标 10,000</div>
      </div>
      <div>
        <div class="sl-v">${snap.min}<span class="sl-u">分钟</span></div>
        <div class="sl-h">本周 ${weekSessions().length} 练</div>
      </div>
      <div>
        <div class="sl-v">${streak()}<span class="sl-u">天连击</span></div>
        <div class="sl-h">别断</div>
      </div>
    </div>
  </div>

  <div class="quick" style="margin-top:12px;">
    ${quickBtn('session', '开练', 'dumbbell', 'var(--green)')}
    ${quickBtn('food', '记一餐', 'camera', 'var(--amber)')}
    ${quickBtn('run', '记跑', 'run', 'var(--blue)')}
    ${quickBtn('coach', '问教练', 'sparkles', 'var(--purple)')}
  </div>

  <div class="card" style="margin-top:12px;">
    <div class="hstack" style="margin-bottom:12px;">
      <span class="tag" style="font-size:13px;font-weight:600;">今日计划</span>
      <span class="spacer"></span>
      ${plan ? `<span class="pill grey">${plan.title}</span>` : '<span class="pill grey">恢复日</span>'}
    </div>
    ${plan ? plan.items.slice(0, 4).map(i => `
      <div class="goal-row"><span>${i.name}</span><span class="gr-r">${i.sets} × ${i.reps}</span></div>
    `).join('') : `<div style="font-size:15px;margin-bottom:4px;">今天是恢复日</div><div class="faint">走 20 分钟 + 髋活动度，明天再顶。</div>`}
    ${plan ? `<button class="btn" style="margin-top:14px;padding:13px;" data-act="start-plan">${I.play} 开始训练</button>` : ''}
  </div>

  <div class="card" style="margin-top:12px;">
    <div class="hstack" style="margin-bottom:12px;">
      <span class="tag" style="font-size:13px;font-weight:600;">营养</span>
      <span class="spacer"></span>
      <span style="font-size:13px;font-weight:700;font-variant-numeric:tabular-nums;">${Math.round(nut.kcal)} / ${p.kcalGoal} kcal</span>
    </div>
    <div class="bar" style="height:8px;"><i style="width:${clamp(nut.kcal / p.kcalGoal * 100, 0, 100)}%;background:var(--amber)"></i></div>
    <div class="macro" style="margin-top:12px;">
      ${macroBar('蛋白', nut.p, Math.round(p.w * 2), 'var(--green)')}
      ${macroBar('碳水', nut.c, 240, 'var(--blue)')}
      ${macroBar('脂肪', nut.f, 65, 'var(--amber)')}
    </div>
    <div class="chips" style="margin-top:12px;">
      ${S.foods.filter(f => dayKey(new Date(f.date)) === dayKey()).slice(0, 6).map(f => `
        <div class="chip"><b>${f.meal}</b>${(f.items[0] || {}).name || '—'} · ${Math.round(f.items.reduce((a, i) => a + i.kcal, 0))} kcal</div>
      `).join('') || '<span class="faint">还没记录。拍张照，AI 帮你算。</span>'}
    </div>
  </div>

  <div class="card" style="margin-top:12px;">
    <div class="hstack" style="margin-bottom:12px;">
      <h2 class="h2" style="font-size:18px;">最近</h2><span class="spacer"></span>
      <span class="faint">全部</span>
    </div>
    ${last ? `
      <div class="hstack">
        <div class="hi" style="width:42px;height:42px;border-radius:13px;background:rgba(92,224,143,.12);color:var(--green);display:flex;align-items:center;justify-content:center;">${I.dumbbell}</div>
        <div style="flex:1;min-width:0;">
          <div style="font-weight:600;font-size:15px;">${last.title}</div>
          <div class="faint">${relDay(last.date)} · ${totalSets(last)} 组 · ${Math.round(totalVolume(last))} kg</div>
        </div>
        <div class="mono faint" style="font-size:15px;">${last.minutes}′</div>
      </div>` : `<div class="empty"><div class="ei">${I.dumbbell}</div><div class="et">还没有记录</div><div class="em">点「开练」建第一次训练。</div></div>`}
  </div>
  `;
}

function quickBtn(act, label, icon, tint) {
  return `<button data-act="${act}">
    <div class="qi" style="background:${tint}1F;color:${tint};">${I[icon]}</div>
    <span class="qt">${label}</span>
  </button>`;
}
function macroBar(name, cur, target, color) {
  return `<div>
    <div class="m-t"><span>${name}</span><span>${Math.round(cur)}/${target}g</span></div>
    <div class="bar" style="height:5px;"><i style="width:${clamp(cur / Math.max(1, target) * 100, 0, 100)}%;background:${color}"></i></div>
  </div>`;
}
function relDay(iso) {
  const d = new Date(iso), t = new Date();
  if (dayKey(d) === dayKey(t)) return '今天';
  const y = new Date(t); y.setDate(t.getDate() - 1);
  if (dayKey(d) === dayKey(y)) return '昨天';
  return Math.round((t - d) / 864e5) + ' 天前';
}

function ringSVG(pct) {
  const size = 132, w = 13, r = (size - w) / 2, c = 2 * Math.PI * r;
  const dash = clamp(pct, 0, 1) * c;
  return `<svg width="${size}" height="${size}">
    <defs><linearGradient id="rg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#5CE08F"/><stop offset="1" stop-color="#2AD4C8"/>
    </linearGradient></defs>
    <circle cx="${size / 2}" cy="${size / 2}" r="${r}" fill="none" stroke="#232327" stroke-width="${w}"/>
    <circle cx="${size / 2}" cy="${size / 2}" r="${r}" fill="none" stroke="url(#rg)" stroke-width="${w}"
      stroke-linecap="round" stroke-dasharray="${dash} ${c}" />
  </svg>`;
}
function drawTodayRing() {
  const box = $('#today-ring');
  if (!box) return;
  const snap = todaySnap();
  const pct = snap.kcal / 700;
  box.innerHTML = ringSVG(pct) + `
    <div class="rc">
      <div class="rv">${snap.kcal}</div>
      <div class="ru">kcal</div>
      <div class="rl">活动</div>
    </div>`;
}

/* ---------------- 训练 ---------------- */
function viewTraining() {
  const week = weekSessions();
  const vol = week.reduce((a, s) => a + totalVolume(s), 0);
  const sets = week.reduce((a, s) => a + totalSets(s), 0);

  return `
  <h1 class="h1" style="margin-bottom:14px;">训练</h1>

  <div class="stat3">
    <div class="tile"><div class="tv">${week.length}</div><div class="tl">本周训练</div></div>
    <div class="tile"><div class="tv">${sets}</div><div class="tl">总组数</div></div>
    <div class="tile"><div class="tv">${Math.round(vol / 1000)}t</div><div class="tl">总容量</div></div>
  </div>

  <div class="card" style="margin-top:12px;">
    <div class="hstack" style="margin-bottom:14px;">
      <div>
        <div style="font-size:18px;font-weight:800;">四周计划</div>
        <div class="faint">${S.plan.goal} · 每周 ${S.plan.days} 练</div>
      </div>
      <span class="spacer"></span>
      <button class="pill grey" data-act="replan" style="padding:7px 11px;">${I.sparkles} 重排</button>
    </div>
    <div class="days">
      ${S.plan.items.map(d => {
        const today = ((new Date().getDay() + 6) % 7) === d.wd;
        return `<div class="d ${today ? 'today' : ''}">
          <span class="dw">${WEEK_CN[(d.wd + 1) % 7]}</span>
          <span class="dot ${d.rest ? '' : 'on'}"></span>
        </div>`;
      }).join('')}
    </div>
    ${todaysPlan() ? `
      <div style="margin-top:14px;background:var(--card-soft);border-radius:14px;padding:12px;">
        <div style="color:var(--green);font-size:13px;font-weight:600;margin-bottom:8px;">${todaysPlan().title}</div>
        ${todaysPlan().items.map(i => `<div class="goal-row"><span style="font-size:14px;">${i.name}</span><span class="gr-r">${i.sets}×${i.reps}</span></div>`).join('')}
      </div>` : ''}
  </div>

  <div class="hstack" style="gap:10px;margin-top:12px;">
    <button class="btn" data-act="start-plan">${I.play} 按计划开练</button>
    <button class="icon-btn" style="width:52px;height:50px;border-radius:18px;" data-act="start-free">${I.plus}</button>
  </div>

  <div class="hstack" style="margin:18px 0 10px;">
    <h2 class="h2" style="font-size:18px;">训练历史</h2><span class="spacer"></span>
    <span class="faint">${S.sessions.length} 次</span>
  </div>

  <div class="stack-sm">
    ${sortedSessions().map(s => `
      <button class="hist-row" data-act="session-detail" data-id="${s.id}">
        <div class="hi">${I.dumbbell}</div>
        <div style="flex:1;min-width:0;text-align:left;">
          <div style="font-weight:600;font-size:15px;">${s.title}</div>
          <div class="faint">${new Date(s.date).toLocaleDateString('zh-CN', { month: 'numeric', day: 'numeric' })} · ${totalSets(s)} 组 · ${Math.round(totalVolume(s))} kg</div>
        </div>
        <span class="chev">›</span>
      </button>
    `).join('') || `<div class="empty"><div class="ei">${I.clock}</div><div class="et">还没有训练</div><div class="em">按计划开练，记录会自动出现在这里。</div></div>`}
  </div>
  `;
}

/* ---------------- 进度 ---------------- */
function viewProgress() {
  const runs = [...S.runs].sort((a, b) => new Date(b.date) - new Date(a.date));
  const balance = {};
  weekSessions().forEach(s => s.exercises.forEach(e => { balance[e.group] = (balance[e.group] || 0) + e.sets.length; }));
  const maxSets = Math.max(1, ...Object.values(balance));
  const lifts = ['杠铃卧推', '深蹲', '罗马尼亚硬拉', '站姿推举'];

  return `
  <h1 class="h1" style="margin-bottom:14px;">进度</h1>

  <div class="stat3">
    <div class="tile"><div class="tv">${streak()}</div><div class="tl">连续天数</div></div>
    <div class="tile"><div class="tv">${S.sessions.length}</div><div class="tl">总训练</div></div>
    <div class="tile"><div class="tv">${Math.round(S.sessions.reduce((a, s) => a + totalVolume(s), 0) / 1000)}t</div><div class="tl">累计容量</div></div>
  </div>

  <div class="card" style="margin-top:12px;">
    <div class="hstack" style="margin-bottom:12px;">
      <span style="font-size:16px;font-weight:800;">每周容量</span><span class="spacer"></span>
      <span style="color:var(--green);font-weight:700;font-size:14px;font-variant-numeric:tabular-nums;">${Math.round((weeklyVolume().slice(-1)[0] || { v: 0 }).v)} kg</span>
    </div>
    <div class="canvas-wrap"><canvas id="c-vol" height="150"></canvas></div>
  </div>

  <div class="card" style="margin-top:12px;">
    <div class="hstack" style="margin-bottom:12px;">
      <span style="font-size:16px;font-weight:800;">体重</span><span class="spacer"></span>
      <span style="color:var(--blue);font-weight:700;font-size:14px;">${(S.snaps[0] || S.profile).w.toFixed(1)} kg</span>
    </div>
    <div class="canvas-wrap"><canvas id="c-weight" height="120"></canvas></div>
  </div>

  <div class="card" style="margin-top:12px;">
    <div class="hstack" style="margin-bottom:12px;">
      <span style="font-size:16px;font-weight:800;">本周肌群分布</span><span class="spacer"></span>
      <span class="faint">目标 10–20 组</span>
    </div>
    ${Object.keys(balance).length ? Object.entries(balance).map(([g, n]) => `
      <div class="hstack" style="gap:10px;margin-bottom:8px;">
        <span style="width:34px;font-size:12px;color:var(--dim);">${g}</span>
        <div class="bar" style="flex:1;"><i style="width:${n / maxSets * 100}%"></i></div>
        <span class="mono" style="width:22px;text-align:right;font-size:12px;color:var(--dim);">${n}</span>
      </div>`).join('') : '<div class="faint">本周还没有训练记录</div>'}
  </div>

  <div class="card" style="margin-top:12px;">
    <div style="font-size:16px;font-weight:800;margin-bottom:12px;">主力动作</div>
    ${lifts.map(n => {
      const h = historyOf(n);
      const last = h.slice(-1)[0];
      const best = h.length ? Math.max(...h.map(x => x.e1rm)) : 0;
      return `<div class="goal-row"><span>${n}</span>
        <span class="gr-r">${last ? Math.round(last.e1rm) + ' kg' : '—'}<span style="color:var(--faint);margin-left:8px;">${h.length ? '最好 ' + Math.round(best) : ''}</span></span></div>`;
    }).join('')}
  </div>

  <div class="hstack" style="margin:18px 0 10px;">
    <h2 class="h2" style="font-size:18px;">足迹</h2><span class="spacer"></span>
    <span class="faint">${runs.length} 条</span>
  </div>

  <div class="route-grid">
    ${runs.map(r => `
      <button class="route-card" data-act="route" data-id="${r.id}">
        <canvas class="route-mini" data-id="${r.id}" height="118"></canvas>
        <div class="rmeta">
          <div style="font-size:13px;font-weight:600;">${r.title}</div>
          <div class="faint">${r.km.toFixed(2)} km · ${styleName(r.style)}</div>
        </div>
      </button>`).join('') || `<div class="empty" style="grid-column:span 2;"><div class="ei">${I.map}</div><div class="et">还没有轨迹</div><div class="em">跑一次，就会留下一条线。</div></div>`}
  </div>
  `;
}

/* ---------------- 教练 ---------------- */
function viewCoach() {
  const msgs = S.chats;
  const used = msgs.filter(m => m.role === 'me').length;
  const left = 999 - used;

  return `
  <h1 class="h1" style="margin-bottom:10px;">教练</h1>

  <div class="coach-head">
    <div class="avatar">${I.sparkles}</div>
    <div style="flex:1;">
      <div style="font-size:14px;font-weight:600;">AI 教练 · ${S.ai.key ? '在线' : '本地模式'}</div>
      <div class="faint">${S.ai.key ? '已接入 ' + S.ai.model : '配置 Key 可对话；本地模式已覆盖常见问题'}</div>
    </div>
    <div style="text-align:right;">
      <div style="color:var(--green);font-weight:800;font-size:15px;">${left > 900 ? '∞' : left}</div>
      <div class="faint" style="font-size:9px;">剩余</div>
    </div>
  </div>

  <div class="chat" id="chat">
    ${msgs.length <= 1 ? `<div class="suggest">
      <span class="faint" style="font-size:11px;font-weight:600;">试试这样问</span>
      ${['今天练什么？', '卧推 62.5 做了 8 次，下次加多少？', '这周睡得很差，要不要减载？', '我还差多少蛋白？']
        .map(t => `<button data-act="ask" data-q="${t}">${t}</button>`).join('')}
    </div>` : ''}
    ${msgs.map(m => `<div class="bubble ${m.role === 'me' ? 'me' : 'ai'}">${escapeHTML(m.text)}</div>`).join('')}
  </div>
  `;
}

function escapeHTML(s) {
  return String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

/* ---------------- 我的 ---------------- */
function viewMe() {
  const p = S.profile;
  return `
  <h1 class="h1" style="margin-bottom:14px;">我的</h1>

  <button class="card" style="display:flex;align-items:center;gap:14px;width:100%;text-align:left;" data-act="profile">
    <div class="pavatar">${p.name.slice(0, 1).toUpperCase()}</div>
    <div style="flex:1;">
      <div style="font-size:20px;font-weight:800;">${p.name}</div>
      <div class="faint">${p.goal} · 每周 ${p.days} 练 · ${p.exp}</div>
    </div>
    <span class="chev">›</span>
  </button>

  <button class="member-banner" style="margin-top:12px;" data-act="membership">
    <div class="mb-icon">${I.crown}</div>
    <div style="flex:1;">
      <div style="font-weight:800;font-size:15px;">${S.membership.tier === 'max' ? 'Stride Max 已解锁' : '升级到 Stride Max'}</div>
      <div style="font-size:11px;opacity:.75;margin-top:3px;">AI 不限次数 · 全部画风 · 全部模板</div>
    </div>
    <span class="chev" style="color:rgba(255,255,255,.6)">›</span>
  </button>

  <div class="stat3" style="margin-top:12px;">
    <div class="tile"><div class="tv">${S.sessions.length}</div><div class="tl">训练</div></div>
    <div class="tile"><div class="tv">${streak()}</div><div class="tl">连续</div></div>
    <div class="tile"><div class="tv">${S.runs.length}</div><div class="tl">轨迹</div></div>
  </div>

  <div class="card" style="margin-top:12px;padding:0;">
    ${meRow('sparkles', 'var(--purple)', 'AI 服务', S.ai.key ? S.ai.model : '未配置', 'ai')}
    ${meRow('heart', 'var(--red)', 'Apple 健康', 'Web 版不可用', 'noop')}
    ${meRow('watch', 'var(--green)', 'Apple Watch', '需原生 App', 'noop')}
    ${meRow('music', 'var(--pink)', '歌单链接导入', '解析', 'playlist')}
    ${meRow('doc', 'var(--blue)', '歌词同步', '不限次数', 'lyrics')}
  </div>

  <div class="card" style="margin-top:12px;padding:0;">
    ${meRow('grid', 'var(--amber)', '插件市场', '4 个小工具', 'plugins')}
    ${meRow('dumbbell', 'var(--green)', '手动动作计数', '点一下算一次', 'counter')}
    ${meRow('clock', 'var(--blue)', '训练计划', S.profile.days + ' 天/周', 'plan')}
  </div>

  <div class="card" style="margin-top:12px;padding:0;">
    ${meRow('info', 'var(--dim)', '版本', '1.0 (web)', 'noop', true)}
    ${meRow('lock', 'var(--dim)', '数据存储', '仅本机', 'noop', true)}
    <div class="row" data-act="reset-quota">
      <div class="ricon" style="background:rgba(255,255,255,.06);color:var(--dim);">${I.refresh}</div>
      <div class="rtitle">重置今日额度</div><span class="chev">›</span>
    </div>
    <div class="row" data-act="reset-all">
      <div class="ricon" style="background:rgba(255,107,107,.12);color:var(--red);">${I.trash}</div>
      <div class="rtitle" style="color:var(--red);">清空所有数据</div><span class="chev">›</span>
    </div>
  </div>
  `;
}

function meRow(icon, tint, title, value, act, noChev) {
  return `<div class="row" data-act="${act}">
    <div class="ricon" style="background:${tint}1F;color:${tint};">${I[icon] || I.info}</div>
    <div class="rtitle">${title}</div>
    ${value ? `<span class="rvalue">${value}</span>` : ''}
    ${noChev ? '' : '<span class="chev">›</span>'}
  </div>`;
}

/* ---------------- 图表 ---------------- */
function drawProgressCharts() {
  const volC = $('#c-vol');
  if (volC) {
    const data = weeklyVolume();
    const w = volC.clientWidth || 320, h = 150;
    volC.width = w * 2; volC.height = h * 2;
    const g = volC.getContext('2d');
    g.scale(2, 2);
    g.clearRect(0, 0, w, h);
    if (!data.length) return;
    const max = Math.max(...data.map(d => d.v)) || 1;
    const bw = w / data.length * 0.52;
    const gap = w / data.length;
    data.forEach((d, i) => {
      const bh = Math.max(6, d.v / max * (h - 18));
      const x = gap * i + (gap - bw) / 2;
      const y = h - bh;
      const grad = g.createLinearGradient(0, y, 0, h);
      grad.addColorStop(0, '#5CE08F'); grad.addColorStop(1, 'rgba(92,224,143,.25)');
      g.fillStyle = grad;
      roundRect(g, x, y, bw, bh, 6); g.fill();
    });
  }

  const wC = $('#c-weight');
  if (wC) {
    const pts = [...S.snaps].sort((a, b) => new Date(a.date) - new Date(b.date)).map(s => s.w);
    const w = wC.clientWidth || 320, h = 120;
    wC.width = w * 2; wC.height = h * 2;
    const g = wC.getContext('2d');
    g.scale(2, 2); g.clearRect(0, 0, w, h);
    if (pts.length < 2) return;
    const min = Math.min(...pts) - .4, max = Math.max(...pts) + .4;
    const X = i => i / (pts.length - 1) * (w - 12) + 6;
    const Y = v => h - 10 - (v - min) / (max - min) * (h - 22);
    g.beginPath();
    pts.forEach((v, i) => i ? g.lineTo(X(i), Y(v)) : g.moveTo(X(i), Y(v)));
    g.strokeStyle = '#6BA8FF'; g.lineWidth = 2.4; g.lineCap = 'round'; g.lineJoin = 'round'; g.stroke();
    g.lineTo(X(pts.length - 1), h); g.lineTo(X(0), h); g.closePath();
    const grad = g.createLinearGradient(0, 0, 0, h);
    grad.addColorStop(0, 'rgba(107,168,255,.28)'); grad.addColorStop(1, 'rgba(107,168,255,0)');
    g.fillStyle = grad; g.fill();
  }

  $$('.route-mini').forEach(cv => {
    const run = S.runs.find(r => r.id === cv.dataset.id);
    if (run) drawRoute(cv, run.pts, run.style, 2.4);
  });
}

function roundRect(g, x, y, w, h, r) {
  g.beginPath();
  g.moveTo(x + r, y);
  g.lineTo(x + w - r, y); g.quadraticCurveTo(x + w, y, x + w, y + r);
  g.lineTo(x + w, y + h - r); g.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
  g.lineTo(x + r, y + h); g.quadraticCurveTo(x, y + h, x, y + h - r);
  g.lineTo(x, y + r); g.quadraticCurveTo(x, y, x + r, y);
  g.closePath();
}

const STYLE_COLORS = {
  neon: ['#5CE08F', '#2AD4C8'], ink: ['#FFFFFF', '#B9BCC4'],
  gradient: ['#FFB86B', '#FF5E8A'], dots: ['#6BA8FF', '#B48CFF'],
  contour: ['#8CE99A', '#3F8F52'], aurora: ['#7BEDA9', '#6BA8FF', '#B48CFF']
};
const STYLE_NAMES = { neon: '霓虹', ink: '墨线', gradient: '渐变', dots: '点阵', contour: '等高线', aurora: '极光' };
const styleName = s => STYLE_NAMES[s] || '霓虹';

function drawRoute(cv, pts, style, lw = 3) {
  const w = cv.clientWidth || 300, h = cv.clientHeight || 118;
  cv.width = w * 2; cv.height = h * 2;
  const g = cv.getContext('2d');
  g.scale(2, 2);
  g.clearRect(0, 0, w, h);

  // 背景
  const bg = g.createLinearGradient(0, 0, 0, h);
  bg.addColorStop(0, '#131316'); bg.addColorStop(1, '#08080A');
  g.fillStyle = bg; g.fillRect(0, 0, w, h);

  if (!pts || pts.length < 2) {
    g.fillStyle = 'rgba(255,255,255,.2)'; g.font = '11px -apple-system'; g.fillText('暂无轨迹', 12, h / 2);
    return;
  }

  const pad = 16;
  let minLat = 90, maxLat = -90, minLon = 180, maxLon = -180;
  pts.forEach(p => {
    minLat = Math.min(minLat, p.lat); maxLat = Math.max(maxLat, p.lat);
    minLon = Math.min(minLon, p.lon); maxLon = Math.max(maxLon, p.lon);
  });
  const spanLat = Math.max(maxLat - minLat, 1e-9), spanLon = Math.max(maxLon - minLon, 1e-9);
  const scale = Math.min(w - pad * 2, h - pad * 2);
  const ox = (w - scale) / 2, oy = (h - scale) / 2;
  const X = p => ox + (p.lon - minLon) / spanLon * scale;
  const Y = p => oy + (1 - (p.lat - minLat) / spanLat) * scale;

  const colors = STYLE_COLORS[style] || STYLE_COLORS.neon;
  const path = new Path2D();
  pts.forEach((p, i) => i ? path.lineTo(X(p), Y(p)) : path.moveTo(X(p), Y(p)));

  g.lineCap = 'round'; g.lineJoin = 'round';

  if (style === 'dots') {
    g.fillStyle = colors[0];
    pts.forEach((p, i) => {
      if (i % 3) return;
      g.beginPath();
      g.arc(X(p), Y(p), 1.6 + (i % 4) * .35, 0, 7);
      g.fill();
    });
  } else if (style === 'contour') {
    for (let i = 0; i < 4; i++) {
      g.save(); g.translate(0, i * 5);
      g.strokeStyle = colors[i % colors.length] + (i === 0 ? '' : '');
      g.globalAlpha = .55 - i * .1; g.lineWidth = lw * .6;
      g.stroke(path); g.restore();
    }
  } else if (style === 'gradient') {
    const grad = g.createLinearGradient(0, 0, w, h);
    grad.addColorStop(0, colors[0]); grad.addColorStop(1, colors[1]);
    g.strokeStyle = grad; g.lineWidth = lw; g.stroke(path);
  } else if (style === 'ink') {
    g.strokeStyle = 'rgba(255,255,255,.12)'; g.lineWidth = lw * 5; g.stroke(path);
    g.strokeStyle = 'rgba(255,255,255,.92)'; g.lineWidth = lw * .8; g.stroke(path);
  } else if (style === 'aurora') {
    colors.forEach((c, i) => {
      g.save();
      g.translate((i - 1) * 7, (i - 1) * -4);
      g.strokeStyle = c; g.globalAlpha = .5; g.lineWidth = lw * 4.2;
      g.filter = 'blur(8px)';
      g.stroke(path); g.restore();
    });
    g.strokeStyle = 'rgba(255,255,255,.95)'; g.lineWidth = lw * .9; g.stroke(path);
  } else { // neon
    g.save();
    g.shadowColor = colors[0]; g.shadowBlur = 18;
    g.strokeStyle = colors[0]; g.globalAlpha = .85; g.lineWidth = lw * 3.2;
    g.stroke(path); g.restore();
    g.strokeStyle = '#fff'; g.lineWidth = lw; g.stroke(path);
  }
}

/* ---------------- 事件 ---------------- */
const ACTIONS = {
  membership: () => openMembership(),
  session: () => openSession(null),
  'start-plan': () => openSession(todaysPlan()),
  'start-free': () => openSession(null),
  food: () => openFood(),
  run: () => openRun(),
  coach: () => setTab('coach'),
  ask: (el) => askCoach(el.dataset.q),
  'session-detail': (el) => openSessionDetail(el.dataset.id),
  route: (el) => openRoute(el.dataset.id),
  replan: () => {
    const p = S.profile;
    S.plan = makePlan(p.goal, p.days, p.exp);
    save(); render(); toast('计划已按当前目标重排');
  },
  ai: () => openAI(),
  playlist: () => openPlaylist(),
  lyrics: () => openLyrics(),
  plugins: () => openPlugins(),
  counter: () => openCounter(),
  plan: () => openPlanSheet(),
  profile: () => openProfile(),
  'reset-quota': () => { S.quotas.food = {}; save(); toast('今日额度已重置'); },
  'reset-all': () => {
    if (confirm('清空所有本地数据？这会删除训练、轨迹和设置。')) {
      localStorage.removeItem(KEY);
      S = load();
      render(); toast('已恢复初始数据');
    }
  },
  noop: () => toast('Web 版没有这个能力，见 README'),

  // 会员页
  'pw-close': () => closeSheet(),
  'pw-plan': (el) => { pwSelect(el.dataset.id); },
  'pw-pro': () => { pwSelectPro(); },
  'pw-restore': () => toast('已恢复：Stride Max'),
  'pw-buy': () => {
    const p = PLANS.find(x => x.id === pwSel) || PLANS[2];
    S.membership = { planId: p.id, tier: 'max' };
    save(); openMembership(); toast('已切换到 ' + p.name);
  },

  // 训练
  's-close': () => closeSheet(),
  's-add': () => addExerciseToSession(),
  's-set-done': (el) => toggleSet(el.dataset.e, el.dataset.s),
  's-add-set': (el) => addSet(el.dataset.e),
  's-save': () => saveSession(),
  's-del-ex': (el) => { session.eff.splice(+el.dataset.e, 1); renderSession(); },

  // 餐食
  'f-close': () => closeSheet(),
  'f-add': (el) => addFoodFromDB(el.dataset.i),
  'f-save': () => saveFood(),
  'f-del': (el) => { foodItems.splice(+el.dataset.i, 1); renderFood(); },
  'f-photo': () => $('#f-file').click(),
  'f-file-change': () => handlePhoto(),

  // 跑步
  'r-close': () => closeSheet(),
  'r-start': () => toggleRun(),
  'r-demo': () => demoRun(),
  'r-save': () => saveRun(),

  // 足迹详情
  'rt-close': () => closeSheet(),
  'rt-style': (el) => selectStyle(el.dataset.v),
  'rt-template': (el) => selectTemplate(el.dataset.v),
  'rt-share': () => shareRoute(),

  // 其他页
  close: () => closeSheet(),
  'save-ai': () => saveAI(),
  'save-profile': () => saveProfile(),
  'save-playlist': () => savePlaylist(),
  'parse-link': () => parseLink(),
  'lyr-parse': () => parseLyrics(),
  'lyr-play': () => toggleLyrics(),
  'tool-counter': () => { counterReps++; renderCounter(); },
  'tool-counter-reset': () => { counterReps = 0; renderCounter(); }
};

document.addEventListener('click', (e) => {
  const el = e.target.closest('[data-act]');
  if (!el) return;
  const fn = ACTIONS[el.dataset.act];
  if (fn) { e.preventDefault(); fn(el); }
});

$$('.tab').forEach(b => b.addEventListener('click', () => setTab(b.dataset.tab)));

/* ---------------- 通用 Sheet ---------------- */
let sheetEl = null;
function openSheet(html, cls = '') {
  closeSheet(true);
  sheetEl = document.createElement('div');
  sheetEl.className = 'sheet ' + cls;
  sheetEl.innerHTML = html;
  $('#sheet-root').appendChild(sheetEl);
  document.body.style.overflow = 'hidden';
  requestAnimationFrame(() => sheetEl.classList.add('on'));
}
function closeSheet(instant) {
  if (!sheetEl) return;
  const el = sheetEl; sheetEl = null;
  document.body.style.overflow = '';
  if (instant) { el.remove(); return; }
  el.classList.remove('on');
  setTimeout(() => el.remove(), 300);
}

/* ---------------- 会员页 ---------------- */
let pwSel = 'max.monthly';
let pwTier = 'max';

function openMembership() {
  pwSel = S.membership.planId || 'max.monthly';
  pwTier = 'max';
  const current = S.membership.planId;
  const isCurrent = pwSel === current;

  openSheet(`
  <div class="pw-head">
    <button class="icon-btn l" data-act="pw-close">${I.x}</button>
    <div class="t">会员方案</div>
    <button class="r" data-act="pw-restore" style="background:var(--card-hi);border-radius:99px;padding:11px 18px;font-size:15px;font-weight:600;">恢复购买</button>
  </div>

  <div class="sheet-body">
    <div class="pw">

      <div class="plan-card sel">
        <div class="pc-head">
          <div>
            <div class="pc-title">Stride Max</div>
            <div class="pc-sub">不限次数 · 全部解锁</div>
          </div>
          ${S.membership.tier === 'max' ? '<span class="badge-w">当前方案</span>' : ''}
        </div>

        <div class="plans" id="pw-plans">
          ${PLANS.map(p => planRowHTML(p, current)).join('')}
        </div>

        <div class="benefits">
          ${MAX_BENEFITS.map(b => `<div class="benefit">${I.check}<span>${b}</span></div>`).join('')}
        </div>
      </div>

      <div class="plan-card ${pwTier === 'pro' ? 'sel' : ''}">
        <button class="pro-head" data-act="pw-pro">
          <div class="radio">${I.check}</div>
          <div style="flex:1;">
            <div class="pro-title">Stride Pro</div>
            <div class="pro-sub">为自律者而生</div>
          </div>
          <div class="plan-price">1,99 € / 月</div>
        </button>
        <div class="benefits">
          ${PRO_BENEFITS.map(b => `<div class="benefit">${I.check}<span>${b}</span></div>`).join('')}
        </div>
      </div>

      <div class="free-card">
        <div class="free-head"><h3>免费版已包含</h3><span>不订阅也能用</span></div>
        <div class="free-grid">
          ${FREE_PERKS.map(([ic, t]) => `<div class="free-item">${I[ic] || I.check}<span>${t}</span></div>`).join('')}
        </div>
      </div>

      <div class="usage">
        <h3>本期用量</h3>
        ${usageRow('AI 热量识别（每天）', (S.quotas.food[dayKey()] || 0), 999)}
        ${usageRow('AI 教练对话（本期）', S.chats.filter(c => c.role === 'me').length, 999)}
      </div>

    </div>
  </div>

  <div class="pw-foot">
    <button class="btn" id="pw-cta" ${isCurrent ? 'disabled' : ''} data-act="pw-buy">
      ${isCurrent ? '当前方案' : '以 ' + (PLANS.find(p => p.id === pwSel) || PLANS[2]).price + ' 订阅'}
    </button>
    <div class="note">你的方案按 1,99 € / 月 自动续订，可随时在系统设置中取消。</div>
  </div>
  `);
}

function planRowHTML(p, current) {
  const sel = pwSel === p.id && pwTier === 'max';
  const isCur = current === p.id;
  return `<button class="plan-row ${sel ? 'sel' : ''}" data-act="pw-plan" data-id="${p.id}">
    <div class="radio">${I.check}</div>
    <div class="plan-meta">
      <div class="plan-name">${p.name}
        ${p.badge ? `<span class="badge-w">${p.badge}</span>` : ''}
        ${isCur ? '<span class="badge-d">当前方案</span>' : ''}
      </div>
      ${p.per ? `<div class="plan-per">${p.per}</div>` : ''}
    </div>
    <div class="plan-right">
      <div class="plan-price">${p.price}</div>
      ${p.strike ? `<div class="plan-strike">${p.strike}</div>` : ''}
      ${p.save ? `<div class="plan-save"><span class="pill">${p.save}</span></div>` : ''}
    </div>
  </button>`;
}

function usageRow(label, used, limit) {
  const unlimited = limit > 900;
  const pct = unlimited ? 100 : clamp(used / limit * 100, 0, 100);
  return `<div class="usage-row">
    <div class="usage-top"><span>${label}</span><b style="color:${unlimited ? 'var(--green-text)' : 'var(--dim)'}">${unlimited ? '不限' : used + ' / ' + limit}</b></div>
    <div class="bar"><i style="width:${pct}%;${unlimited ? 'opacity:.5' : ''}"></i></div>
  </div>`;
}

function pwSelect(id) {
  pwSel = id; pwTier = 'max';
  openMembership();
}
function pwSelectPro() {
  pwSel = 'max.monthly'; pwTier = 'pro';
  openMembership();
}

/* ---------------- 训练 Session ---------------- */
let session = null;

function openSession(plan) {
  session = {
    title: plan ? plan.title : '自由训练',
    started: Date.now(),
    eff: plan ? plan.items.map(i => {
      const lib = S.exercises.find(e => e.name === i.name) || { group: '胸', timed: false };
      return {
        name: i.name, group: lib.group, timed: lib.timed,
        sets: Array.from({ length: i.sets }, () => ({ w: 0, r: lib.timed ? 0 : 8, sec: lib.timed ? 45 : 0, done: false }))
      };
    }) : []
  };
  renderSession();
}

function renderSession() {
  const s = session;
  const done = s.eff.reduce((a, e) => a + e.sets.filter(x => x.done).length, 0);
  const total = s.eff.reduce((a, e) => a + e.sets.length, 0);
  const vol = s.eff.reduce((a, e) => a + e.sets.filter(x => x.done).reduce((b, x) => b + x.w * x.r, 0), 0);
  const mins = Math.floor((Date.now() - s.started) / 60000);

  openSheet(`
  <div class="pw-head">
    <button class="icon-btn l" data-act="s-close">${I.x}</button>
    <div class="t" style="font-size:17px;">${s.title}</div>
    <button class="r" data-act="s-save" style="color:var(--green);font-weight:800;font-size:16px;">完成</button>
  </div>

  <div class="sheet-body">
    <div style="display:flex;border-bottom:.5px solid var(--stroke);">
      ${[[mins + '′', '用时'], [done + '/' + total, '组数'], [Math.round(vol), '容量 kg']]
        .map(([v, l], i) => `<div style="flex:1;text-align:center;padding:12px 0;${i ? 'border-left:.5px solid var(--stroke);' : ''}">
          <div class="mono" style="font-size:17px;">${v}</div><div class="faint" style="font-size:10px;">${l}</div></div>`).join('')}
    </div>

    <div class="pw" style="padding-top:12px;">
      ${s.eff.map((e, ei) => `
        <div class="card" style="padding:16px;">
          <div class="hstack" style="margin-bottom:10px;">
            <div style="flex:1;">
              <div style="font-weight:600;font-size:16px;">${e.name}</div>
              <div class="faint">${e.group} · 休息 90″</div>
            </div>
            <button data-act="s-del-ex" data-e="${ei}" style="color:var(--faint);">${I.trash}</button>
          </div>

          <div style="display:grid;grid-template-columns:26px 1fr 1fr 44px 30px;gap:8px;font-size:10px;color:var(--faint);margin-bottom:6px;">
            <span>组</span><span>重量</span><span>${e.timed ? '秒' : '次数'}</span><span>RPE</span><span></span>
          </div>

          ${e.sets.map((x, si) => `
            <div style="display:grid;grid-template-columns:26px 1fr 1fr 44px 30px;gap:8px;align-items:center;margin-bottom:8px;">
              <span class="faint mono">${si + 1}</span>
              <input class="si" data-e="${ei}" data-s="${si}" data-k="w" type="number" inputmode="decimal" value="${x.w}" style="background:var(--card-hi);border:0;border-radius:9px;padding:8px 9px;color:#fff;font-weight:700;font-size:15px;width:100%;outline:none;">
              <input class="si" data-e="${ei}" data-s="${si}" data-k="${e.timed ? 'sec' : 'r'}" type="number" inputmode="numeric" value="${e.timed ? x.sec : x.r}" style="background:var(--card-hi);border:0;border-radius:9px;padding:8px 9px;color:#fff;font-weight:700;font-size:15px;width:100%;outline:none;">
              <input class="si" data-e="${ei}" data-s="${si}" data-k="rpe" type="number" inputmode="decimal" placeholder="—" style="background:var(--card-hi);border:0;border-radius:9px;padding:8px 6px;color:var(--dim);font-size:13px;width:100%;outline:none;">
              <button data-act="s-set-done" data-e="${ei}" data-s="${si}" style="color:${x.done ? 'var(--green)' : 'var(--stroke-hi)'};font-size:21px;">${x.done ? '✓' : '○'}</button>
            </div>`).join('')}

          <button class="faint" data-act="s-add-set" data-e="${ei}" style="padding-top:4px;">+ 加一组</button>
        </div>
      `).join('')}

      ${s.eff.length ? '' : `<div class="empty"><div class="ei">${I.dumbbell}</div><div class="et">空训练</div><div class="em">从动作库加几个动作开始。</div></div>`}

      <button class="btn ghost" data-act="s-add">${I.plus} 添加动作</button>
      <div style="height:24px;"></div>
    </div>
  </div>
  `);

  $$('.si').forEach(inp => {
    inp.addEventListener('change', () => {
      const e = +inp.dataset.e, si = +inp.dataset.s, k = inp.dataset.k;
      const v = num(inp.value);
      if (k === 'rpe') session.eff[e].sets[si].rpe = v || null;
      else session.eff[e].sets[si][k] = v;
    });
  });
}

function addExerciseToSession() {
  const groups = {};
  S.exercises.forEach(e => { (groups[e.group] = groups[e.group] || []).push(e); });
  openSheet(`
  <div class="pw-head">
    <button class="icon-btn l" data-act="s-close">${I.x}</button>
    <div class="t" style="font-size:17px;">动作库</div><div></div>
  </div>
  <div class="sheet-body"><div class="pw">
    ${Object.entries(groups).map(([g, list]) => `
      <div>
        <div style="font-size:13px;font-weight:800;color:var(--green);margin-bottom:8px;">${g}</div>
        ${list.map(e => `<button class="hist-row" style="width:100%;margin-bottom:8px;" data-act="s-pick" data-name="${e.name}">
          <div style="flex:1;text-align:left;">
            <div style="font-weight:600;">${e.name}</div>
            <div class="faint">${e.cue}</div>
          </div>
          <span class="pill grey">${e.equip}</span>
        </button>`).join('')}
      </div>`).join('')}
  </div></div>
  `);
  document.querySelectorAll('[data-act="s-pick"]').forEach(b => {
    b.addEventListener('click', () => {
      const e = S.exercises.find(x => x.name === b.dataset.name);
      session.eff.push({
        name: e.name, group: e.group, timed: e.timed,
        sets: Array.from({ length: 3 }, () => ({ w: 0, r: e.timed ? 0 : 8, sec: e.timed ? 45 : 0, done: false }))
      });
      renderSession();
    });
  });
}

function toggleSet(ei, si) {
  const x = session.eff[+ei].sets[+si];
  x.done = !x.done;
  renderSession();
}
function addSet(ei) {
  const e = session.eff[+ei];
  const last = e.sets[e.sets.length - 1] || { w: 0, r: 8, sec: 0 };
  e.sets.push({ w: last.w, r: last.r, sec: last.sec, done: false });
  renderSession();
}
function saveSession() {
  const s = session;
  const minutes = Math.max(1, Math.round((Date.now() - s.started) / 60000));
  const volumeSet = s.eff.reduce((a, e) => a + e.sets.filter(x => x.done).length, 0);
  if (!s.eff.length || !volumeSet) { toast('还没记录任何一组'); return; }

  S.sessions.unshift({
    id: uid(), date: new Date().toISOString(), title: s.title, kind: '力量',
    exercises: s.eff.map(e => ({ ...e, sets: e.sets.filter(x => x.done) })),
    minutes,
    kcal: Math.round(minutes * 6.5)
  });

  const k = dayKey();
  const snap = S.snaps.find(x => dayKey(new Date(x.date)) === k);
  if (snap) { snap.min += minutes; snap.kcal += Math.round(minutes * 6.5); }
  else S.snaps.unshift({ date: new Date().toISOString(), steps: 0, kcal: Math.round(minutes * 6.5), min: minutes, w: S.profile.w });

  save(); closeSheet(); render(); toast('训练已保存');
}

function openSessionDetail(id) {
  const s = S.sessions.find(x => x.id === id);
  if (!s) return;
  openSheet(`
  <div class="pw-head">
    <button class="icon-btn l" data-act="close">${I.x}</button>
    <div class="t" style="font-size:17px;">${s.title}</div><div></div>
  </div>
  <div class="sheet-body"><div class="pw">
    <div class="stat3">
      <div class="tile"><div class="tv">${s.minutes}′</div><div class="tl">时长</div></div>
      <div class="tile"><div class="tv">${totalSets(s)}</div><div class="tl">组数</div></div>
      <div class="tile"><div class="tv">${Math.round(totalVolume(s))}</div><div class="tl">容量 kg</div></div>
    </div>
    ${s.exercises.map(e => `
      <div class="card" style="padding:16px;">
        <div style="font-weight:600;margin-bottom:8px;">${e.name}</div>
        ${e.sets.map((x, i) => `<div class="goal-row">
          <span class="faint">第 ${i + 1} 组</span>
          <span class="gr-r" style="color:var(--text);">${fmt1(x.w)} kg × ${e.timed ? x.sec + '″' : x.r}</span>
        </div>`).join('')}
      </div>`).join('')}
    <div style="height:20px;"></div>
  </div></div>
  `);
}

/* ---------------- 餐食 ---------------- */
let foodItems = [];
let foodMeal = '午餐';

function openFood() {
  foodItems = [];
  renderFood();
}

function renderFood() {
  const used = S.quotas.food[dayKey()] || 0;
  const total = foodItems.reduce((a, i) => a + i.kcal, 0);
  openSheet(`
  <div class="pw-head">
    <button class="icon-btn l" data-act="f-close">${I.x}</button>
    <div class="t" style="font-size:17px;">记一餐</div><div></div>
  </div>
  <div class="sheet-body"><div class="pw">

    <div class="card" style="display:flex;align-items:center;gap:10px;">
      <div class="ricon" style="width:34px;height:34px;border-radius:50%;background:rgba(255,184,107,.14);color:var(--amber);display:flex;align-items:center;justify-content:center;">${I.camera}</div>
      <div style="flex:1;">
        <div style="font-size:13px;font-weight:600;">AI 热量识别</div>
        <div class="faint">今天已用 ${used} 次 · ${S.ai.key ? '可用' : '未配置 Key，可手动记录'}</div>
      </div>
      <div style="color:var(--amber);font-weight:800;font-size:17px;">${used}</div>
    </div>

    <button class="card soft" style="display:flex;flex-direction:column;align-items:center;gap:8px;padding:30px 18px;width:100%;" data-act="f-photo">
      <input type="file" id="f-file" accept="image/*" capture="environment" style="display:none;">
      ${I.camera.replace('<svg', '<svg style="width:26px;height:26px;color:#fff"')}
      <div style="font-weight:700;">拍一张 / 选一张</div>
      <div class="faint">拍盘子比拍单个食物更准</div>
    </button>

    ${foodItems.length ? `
      <div class="card" style="padding:16px;">
        <div class="hstack" style="margin-bottom:12px;">
          <span style="font-weight:700;">识别结果</span>
          <span class="spacer"></span>
          <span style="color:var(--amber);font-weight:800;">${Math.round(total)} kcal</span>
        </div>
        ${foodItems.map((it, i) => `
          <div class="hstack" style="margin-bottom:8px;">
            <span style="flex:1;font-size:14px;">${it.name}</span>
            <input type="number" value="${it.g}" data-fi="${i}" class="fg" style="width:62px;text-align:right;background:var(--card-hi);border:0;border-radius:8px;padding:6px;color:#fff;font-weight:700;font-size:13px;">
            <span class="faint">g</span>
            <span class="mono" style="width:46px;text-align:right;color:var(--dim);font-size:13px;">${Math.round(it.kcal)}</span>
            <button data-act="f-del" data-i="${i}" style="color:var(--faint);">✕</button>
          </div>`).join('')}
        <div class="macro" style="margin-top:10px;">
          ${['p', 'c', 'f'].map((k, idx) => `<div>
            <div class="m-t"><span>${['蛋白', '碳水', '脂肪'][idx]}</span></div>
            <div style="font-weight:800;color:${['var(--green)', 'var(--blue)', 'var(--amber)'][idx]};">${Math.round(foodItems.reduce((a, i) => a + i[k], 0))} g</div>
          </div>`).join('')}
        </div>
        <div class="seg" style="margin-top:14px;">
          ${['早餐', '午餐', '晚餐', '加餐'].map(m => `<button class="${foodMeal === m ? 'on' : ''}" data-meal="${m}">${m}</button>`).join('')}
        </div>
      </div>` : ''}

    <div class="card" style="padding:16px;">
      <div style="font-weight:700;margin-bottom:10px;">或者手动加</div>
      <input id="f-q" placeholder="搜食物，比如「鸡胸」" style="width:100%;background:var(--card-soft);border:0;border-radius:13px;padding:11px 13px;color:#fff;font-size:14px;margin-bottom:10px;">
      <div id="f-list">
        ${FOOD_DB.slice(0, 6).map((f, i) => foodRowHTML(f, i)).join('')}
      </div>
    </div>

    <button class="btn" data-act="f-save" ${foodItems.length ? '' : 'disabled'}>
      ${foodItems.length ? '保存 ' + Math.round(total) + ' kcal' : '还没有食物'}
    </button>
    <div style="height:20px;"></div>
  </div></div>
  `);

  const q = $('#f-q');
  q && q.addEventListener('input', () => {
    const list = FOOD_DB.filter(f => f.name.includes(q.value.trim())).slice(0, 6);
    $('#f-list').innerHTML = list.map((f, i) => foodRowHTML(f, FOOD_DB.indexOf(f))).join('');
    bindFoodRows();
  });
  bindFoodRows();
  $$('[data-meal]').forEach(b => b.addEventListener('click', () => { foodMeal = b.dataset.meal; renderFood(); }));
  $$('.fg').forEach(inp => inp.addEventListener('change', () => {
    const i = +inp.dataset.fi, it = foodItems[i];
    const old = it.g || 1, nv = num(inp.value, old);
    const k = nv / old;
    it.g = nv; it.kcal *= k; it.p *= k; it.c *= k; it.f *= k;
    renderFood();
  }));
}

function foodRowHTML(f, i) {
  return `<button class="goal-row" style="width:100%;text-align:left;" data-act="f-add" data-i="${i}">
    <span style="font-size:13.5px;">${f.name}</span>
    <span class="gr-r">${Math.round(f.kcal)} kcal/100g <span style="color:var(--green)">＋</span></span>
  </button>`;
}
function bindFoodRows() { }

function addFoodFromDB(i) {
  const f = FOOD_DB[i];
  const g = f.g, k = g / 100;
  foodItems.push({
    name: f.name, g,
    kcal: Math.round(f.kcal * k),
    p: Math.round(f.p * k * 10) / 10,
    c: Math.round(f.c * k * 10) / 10,
    f: Math.round(f.f * k * 10) / 10
  });
  renderFood();
}

function handlePhoto() {
  const file = $('#f-file').files[0];
  if (!file) return;
  // 浏览器端不直接调用视觉模型（多数端点有 CORS），先示意识别失败并引导手动录入
  S.quotas.food[dayKey()] = (S.quotas.food[dayKey()] || 0) + 1;
  save();
  toast('已记录一次识别（Web 版请手动确认食材）');
  renderFood();
}

function saveFood() {
  if (!foodItems.length) return;
  S.foods.unshift({ id: uid(), meal: foodMeal, date: new Date().toISOString(), ai: false, items: foodItems });
  save(); closeSheet(); render(); toast('已记录 ' + Math.round(foodItems.reduce((a, i) => a + i.kcal, 0)) + ' kcal');
}

/* ---------------- 跑步 ---------------- */
let runState = null;

function openRun() {
  runState = { pts: [], dist: 0, sec: 0, running: false, timer: null, watch: null, demo: false };
  openSheet(`
  <div class="pw-head">
    <button class="icon-btn l" data-act="r-close">${I.x}</button>
    <div class="t" style="font-size:17px;">记一次跑</div><div></div>
  </div>
  <div class="sheet-body"><div class="pw">
    <div class="canvas-wrap" style="height:320px;">
      <canvas id="run-cv" style="height:320px;"></canvas>
    </div>
    <div class="card" style="display:flex;text-align:center;padding:14px 8px;">
      <div style="flex:1;"><div class="mono" id="r-dist" style="font-size:24px;color:var(--green);">0.00</div><div class="faint" style="font-size:10px;">公里</div></div>
      <div style="flex:1;border-left:.5px solid var(--stroke);border-right:.5px solid var(--stroke);"><div class="mono" id="r-pace" style="font-size:24px;">—</div><div class="faint" style="font-size:10px;">配速</div></div>
      <div style="flex:1;"><div class="mono" id="r-time" style="font-size:24px;">0:00</div><div class="faint" style="font-size:10px;">时长</div></div>
    </div>
    <input id="r-title" value="夜跑" placeholder="给这次跑步起个名" style="width:100%;background:var(--card);border:0;border-radius:14px;padding:12px 14px;color:#fff;font-size:15px;">
    <div class="hstack" style="gap:10px;">
      <button class="btn" id="r-btn" data-act="r-start">${I.play} 开始</button>
      <button class="icon-btn" style="width:50px;height:50px;border-radius:18px;" data-act="r-demo">${I.sparkles}</button>
      <button class="icon-btn" style="width:50px;height:50px;border-radius:18px;background:var(--green);color:#000;" data-act="r-save">✓</button>
    </div>
    <div class="faint" style="text-align:center;">室内/模拟器可用「✦」载入一段模拟轨迹</div>
    <div style="height:20px;"></div>
  </div></div>
  `);
  drawRunCanvas();
}

function drawRunCanvas() {
  const cv = $('#run-cv');
  if (!cv || !runState) return;
  drawRoute(cv, runState.pts, 'neon', 3.2);
}

function toggleRun() {
  if (!runState) return;
  if (runState.running) {
    runState.running = false;
    clearInterval(runState.timer);
    if (runState.watch != null) navigator.geolocation.clearWatch(runState.watch);
    $('#r-btn').innerHTML = `${I.play} 继续`;
    return;
  }
  runState.running = true;
  runState.timer = setInterval(() => {
    runState.sec++;
    const t = $('#r-time');
    if (t) t.textContent = `${Math.floor(runState.sec / 60)}:${pad(runState.sec % 60)}`;
    const p = $('#r-pace');
    if (p && runState.dist > 50) {
      const pace = Math.round(runState.sec / (runState.dist / 1000));
      p.textContent = `${Math.floor(pace / 60)}′${pad(pace % 60)}″`;
    }
  }, 1000);
  $('#r-btn').innerHTML = `${I.pause} 暂停`;

  if (navigator.geolocation) {
    runState.watch = navigator.geolocation.watchPosition(pos => {
      const { latitude, longitude } = pos.coords;
      const last = runState.pts[runState.pts.length - 1];
      if (last) {
        const R = 6371000;
        const dLat = (latitude - last.lat) * Math.PI / 180;
        const dLon = (longitude - last.lon) * Math.PI / 180;
        const a = Math.sin(dLat / 2) ** 2 + Math.cos(last.lat * Math.PI / 180) * Math.cos(latitude * Math.PI / 180) * Math.sin(dLon / 2) ** 2;
        const d = 2 * R * Math.asin(Math.sqrt(a));
        if (d > 2) runState.dist += d;
      }
      runState.pts.push({ lat: latitude, lon: longitude });
      const de = $('#r-dist');
      if (de) de.textContent = (runState.dist / 1000).toFixed(2);
      drawRunCanvas();
    }, () => { toast('定位不可用，试试模拟轨迹'); }, { enableHighAccuracy: true, maximumAge: 2000, timeout: 8000 });
  }
}

function demoRun() {
  if (!runState) return;
  runState.pts = loop(31.2304, 121.4737, 0.006, 260, 7);
  runState.dist = 5200;
  runState.sec = 1716;
  runState.demo = true;
  const d = $('#r-dist'); if (d) d.textContent = '5.20';
  const t = $('#r-time'); if (t) t.textContent = '28:36';
  drawRunCanvas();
  toast('已载入模拟轨迹');
}

function saveRun() {
  if (!runState || !runState.pts.length) { toast('还没有轨迹'); return; }
  const title = ($('#r-title') || {}).value || '跑步';
  S.runs.unshift({
    id: uid(), date: new Date().toISOString(), title,
    km: runState.dist / 1000,
    sec: Math.max(60, runState.sec),
    pts: runState.pts, style: 'neon', template: 'card'
  });
  save(); closeSheet(); render(); toast('已保存轨迹');
}

/* ---------------- 足迹详情 ---------------- */
let routeRun = null;

function openRoute(id) {
  routeRun = S.runs.find(r => r.id === id);
  if (!routeRun) return;
  renderRoute();
}

function renderRoute() {
  const r = routeRun;
  const pace = r.km > 0.05 ? Math.round(r.sec / r.km) : 0;
  openSheet(`
  <div class="pw-head">
    <button class="icon-btn l" data-act="rt-close">${I.x}</button>
    <div class="t" style="font-size:17px;">${r.title}</div><div></div>
  </div>
  <div class="sheet-body"><div class="pw">
    <div class="canvas-wrap" style="height:300px;"><canvas id="rt-cv" style="height:300px;"></canvas></div>

    <div class="stat3">
      <div class="tile"><div class="tv">${r.km.toFixed(2)}</div><div class="tl">公里</div></div>
      <div class="tile"><div class="tv">${pace ? Math.floor(pace / 60) + '′' + pad(pace % 60) + '″' : '—'}</div><div class="tl">配速</div></div>
      <div class="tile"><div class="tv">${Math.floor(r.sec / 60)}:${pad(r.sec % 60)}</div><div class="tl">时长</div></div>
    </div>

    <div class="card" style="padding:16px;">
      <div style="font-weight:800;font-size:15px;margin-bottom:10px;">画风</div>
      <div class="mode-tabs">
        ${Object.keys(STYLE_NAMES).map(k => `<button class="${r.style === k ? 'on' : ''}" data-act="rt-style" data-v="${k}">${STYLE_NAMES[k]}</button>`).join('')}
      </div>
    </div>

    <div class="card" style="padding:16px;">
      <div style="font-weight:800;font-size:15px;margin-bottom:10px;">分享模板</div>
      <div class="mode-tabs">
        ${[['card', '卡片'], ['story', '故事'], ['minimal', '极简'], ['poster', '海报']].map(([k, n]) =>
          `<button class="${r.template === k ? 'on' : ''}" data-act="rt-template" data-v="${k}">${n}</button>`).join('')}
      </div>
    </div>

    <button class="btn" data-act="rt-share">${I.share} 分享</button>
    <div style="height:20px;"></div>
  </div></div>
  `);
  const cv = $('#rt-cv');
  if (cv) drawRoute(cv, r.pts, r.style, 3.6);
}

function selectStyle(v) {
  routeRun.style = v;
  S.runs = S.runs.map(x => x.id === routeRun.id ? routeRun : x);
  save(); renderRoute(); render();
}
function selectTemplate(v) {
  routeRun.template = v;
  S.runs = S.runs.map(x => x.id === routeRun.id ? routeRun : x);
  save(); renderRoute();
}

async function shareRoute() {
  const r = routeRun;
  const W = 1080, H = 1440;
  const cv = document.createElement('canvas');
  cv.width = W; cv.height = H;
  const g = cv.getContext('2d');

  const bg = g.createLinearGradient(0, 0, 0, H);
  bg.addColorStop(0, '#101014'); bg.addColorStop(1, '#08080A');
  g.fillStyle = bg; g.fillRect(0, 0, W, H);

  g.fillStyle = '#fff';
  g.font = '800 64px -apple-system, "PingFang SC", sans-serif';
  g.fillText(r.title, 72, 130);
  g.fillStyle = 'rgba(255,255,255,.28)';
  g.font = '800 34px -apple-system';
  g.fillText('STRIDE', W - 220, 130);

  const tmp = document.createElement('canvas');
  tmp.width = W - 120; tmp.height = 760;
  tmp.style.width = (W - 120) + 'px';
  const holder = document.createElement('div');
  holder.style.cssText = `position:fixed;left:-9999px;width:${W - 120}px;height:760px;`;
  holder.appendChild(tmp);
  document.body.appendChild(holder);
  drawRoute(tmp, r.pts, r.style, 4);
  g.drawImage(tmp, 60, 190);
  holder.remove();

  const stats = [
    [r.km.toFixed(2), '公里'],
    [r.km > .05 ? Math.floor(Math.round(r.sec / r.km) / 60) + '′' + pad(Math.round(r.sec / r.km) % 60) + '″' : '—', '配速'],
    [Math.floor(r.sec / 60) + ':' + pad(r.sec % 60), '时长']
  ];
  stats.forEach(([v, l], i) => {
    const x = 72 + i * 260;
    g.fillStyle = '#fff';
    g.font = '800 56px -apple-system';
    g.fillText(v, x, H - 120);
    g.fillStyle = 'rgba(255,255,255,.35)';
    g.font = '600 26px -apple-system';
    g.fillText(l, x, H - 76);
  });

  const blob = await new Promise(res => cv.toBlob(res, 'image/png'));
  if (!blob) { toast('出图失败'); return; }

  if (navigator.canShare && navigator.canShare({ files: [new File([blob], 'stride.png', { type: 'image/png' })] })) {
    try {
      await navigator.share({
        files: [new File([blob], 'stride-route.png', { type: 'image/png' })],
        title: 'Stride'
      });
      return;
    } catch (e) { }
  }
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = 'stride-route.png';
  a.click();
  toast('已导出图片');
}

/* ---------------- 教练 ---------------- */
async function askCoach(text) {
  const input = $('#composer-input');
  const q = text || (input ? input.value.trim() : '');
  if (!q) return;

  S.chats.push({ role: 'me', text: q, at: Date.now() });
  if (input) input.value = '';
  render();

  const chat = $('#chat');
  if (chat) {
    const t = document.createElement('div');
    t.className = 'typing';
    t.innerHTML = '<i></i><i></i><i></i>';
    chat.appendChild(t);
    chat.scrollIntoView({ block: 'end' });
  }

  let answer;
  if (S.ai.key) {
    try {
      answer = await callAI(q);
    } catch (e) {
      answer = localCoach(q) + '\n\n（AI 调用失败：' + e.message + '，以上是本地分析。）';
    }
  } else {
    await new Promise(r => setTimeout(r, 450));
    answer = localCoach(q);
  }

  S.chats.push({ role: 'ai', text: answer, at: Date.now() });
  save(); render();
  const c2 = $('#chat');
  if (c2) c2.scrollIntoView({ block: 'end' });
}

function coachContext() {
  const p = S.profile;
  const recent = sortedSessions().slice(0, 4).map(s =>
    `- ${new Date(s.date).toLocaleDateString('zh-CN')} ${s.title}：${s.exercises.slice(0, 3).map(e => e.name + ' ' + e.sets.length + '组').join('、')}`
  ).join('\n');
  const nut = nutritionToday();
  return `用户：${p.name}，${p.age} 岁，${p.h}cm / ${p.w}kg，目标 ${p.goal}，每周 ${p.days} 练。
最近训练：
${recent || '无'}
今日摄入：${Math.round(nut.kcal)} kcal / 蛋白 ${Math.round(nut.p)}g（目标 ${p.kcalGoal} kcal）`;
}

async function callAI(q) {
  const base = S.ai.base.replace(/\/$/, '');
  const url = base.endsWith('/chat/completions') ? base : base + '/chat/completions';
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + S.ai.key },
    body: JSON.stringify({
      model: S.ai.model,
      temperature: 0.6,
      max_tokens: 600,
      messages: [
        { role: 'system', content: '你是一名严谨的力量训练教练，中文回答，直接、不客套，建议要具体到重量次数组数，120 字以内。' },
        { role: 'user', content: coachContext() + '\n\n用户说：' + q }
      ]
    })
  });
  if (!res.ok) throw new Error('HTTP ' + res.status);
  const data = await res.json();
  return data.choices[0].message.content.trim();
}

function localCoach(q) {
  if (/痛|疼|伤/.test(q)) {
    return '先分清两件事：关节的锐痛 → 今天换动作，别硬顶；肌肉的酸胀 → 可以练但降 20% 负荷。\n替代方案：卧推痛肩 → 改哑铃中立握；深蹲痛膝 → 改箱式深蹲。\n连续 3 天不缓解就去看看，别在 App 里赌。';
  }
  if (/睡|累|疲|没劲/.test(q)) {
    const wv = weeklyVolume().map(x => x.v);
    if (wv.length >= 2 && wv[wv.length - 1] < wv[wv.length - 2] * 0.75) {
      return '这周训练量比上周掉了 ' + Math.round((1 - wv[wv.length - 1] / wv[wv.length - 2]) * 100) + '%，确实是该减载的信号。\n这周所有主动作降到 70% 重量、组数砍一半，把睡眠补回来。';
    }
    return '状态差就别硬上大重量。今天做主项 3 组 × 6 次，重量取平时 80%，做完还有余力就收工。';
  }
  for (const n of ['卧推', '深蹲', '硬拉', '划船', '推举', '引体']) {
    if (q.includes(n)) {
      const h = historyOf(n);
      if (!h.length) return '还没有' + n + '的记录。第一次做 3 组 × 8 次，留 2 次余力，我记下来再给建议。';
      const last = h[h.length - 1];
      const best = Math.max(...h.map(x => x.e1rm));
      const w = Math.round(last.e1rm * 0.78 / 2.5) * 2.5;
      return `${n}：上次估算 1RM ${Math.round(last.e1rm)} kg，历史最好 ${Math.round(best)} kg。\n这次建议 4 组 × 8 次 @ ${fmt1(w)} kg。\n上次做满且 RPE ≤ 8.5 就加 2.5 kg，没做满就减次数保质量。`;
    }
  }
  if (/今天|练什么/.test(q)) {
    const p = todaysPlan();
    if (p) return '今天计划是「' + p.title + '」：' + p.items.slice(0, 4).map(i => i.name + ' ' + i.sets + '×' + i.reps).join('，') + '。组间休息 90 秒，主动作 150 秒。';
    return '今天没排训练。要么 20 分钟快走 + 活动度，要么把明天的提前——别连着两天全休。';
  }
  if (/吃|热量|蛋白/.test(q)) {
    const n = nutritionToday(), p = S.profile;
    return `今天已摄入 ${Math.round(n.kcal)} kcal，还剩 ${Math.max(0, p.kcalGoal - Math.round(n.kcal))} kcal；蛋白差 ${Math.max(0, Math.round(p.w * 2 - n.p))}g。\n补法：约 ${Math.round(Math.max(0, p.w * 2 - n.p) / 0.22)}g 鸡胸，或 3 勺乳清。`;
  }
  const w = weekSessions();
  const sets = w.reduce((a, s) => a + totalSets(s), 0);
  return `本周 ${w.length} 练、${sets} 组。\n想问具体动作就把重量和次数丢给我，比如「卧推 62.5 做了 8 次」。`;
}

/* ---------------- AI 设置 ---------------- */
function openAI() {
  openSheet(`
  <div class="pw-head">
    <button class="icon-btn l" data-act="close">${I.x}</button>
    <div class="t" style="font-size:17px;">AI 服务</div><div></div>
  </div>
  <div class="sheet-body"><div class="pw">
    <div class="card" style="background:rgba(107,168,255,.07);border-color:rgba(107,168,255,.2);display:flex;gap:9px;">
      <span style="color:var(--blue)">${I.info}</span>
      <div class="faint" style="flex:1;">不填也能用：教练走本地规则引擎。填好之后走真模型。浏览器直连可能被 CORS 拦，建议用自己的网关。</div>
    </div>
    <div class="field">
      <label>接口地址</label>
      <input id="ai-base" value="${S.ai.base}" placeholder="https://api.openai.com/v1">
      <div class="hint">OpenAI 兼容端点</div>
    </div>
    <div class="field">
      <label>API Key</label>
      <input id="ai-key" type="password" value="${S.ai.key}" placeholder="sk-...">
      <div class="hint">只存在本机 localStorage</div>
    </div>
    <div class="field">
      <label>模型</label>
      <input id="ai-model" value="${S.ai.model}" placeholder="gpt-4o-mini">
    </div>
    <button class="btn" data-act="save-ai">保存</button>
    <div style="height:20px;"></div>
  </div></div>
  `);
}
function saveAI() {
  S.ai = {
    base: $('#ai-base').value.trim() || 'https://api.openai.com/v1',
    key: $('#ai-key').value.trim(),
    model: $('#ai-model').value.trim() || 'gpt-4o-mini'
  };
  save(); closeSheet(); render(); toast('已保存');
}

/* ---------------- 资料 ---------------- */
function openProfile() {
  const p = S.profile;
  openSheet(`
  <div class="pw-head">
    <button class="icon-btn l" data-act="close">${I.x}</button>
    <div class="t" style="font-size:17px;">我的资料</div><div></div>
  </div>
  <div class="sheet-body"><div class="pw">
    <div class="field"><label>昵称</label><input id="p-name" value="${p.name}"></div>
    <div class="field">
      <label>目标</label>
      <div class="seg" id="p-goal">
        ${['减脂', '重塑', '增肌', '耐力'].map(g => `<button class="${p.goal === g ? 'on' : ''}" data-v="${g}">${g}</button>`).join('')}
      </div>
    </div>
    <div class="field">
      <label>每周训练</label>
      <div class="seg" id="p-days">
        ${[3, 4, 5, 6].map(d => `<button class="${p.days === d ? 'on' : ''}" data-v="${d}">${d} 天</button>`).join('')}
      </div>
    </div>
    <div class="hstack" style="gap:12px;">
      <div class="field" style="flex:1;"><label>身高 cm</label><input id="p-h" type="number" value="${p.h}"></div>
      <div class="field" style="flex:1;"><label>体重 kg</label><input id="p-w" type="number" value="${p.w}"></div>
    </div>
    <div class="field" style="background:var(--card-soft);">
      <div class="hstack"><span class="faint">建议摄入</span><span class="spacer"></span><b id="p-kcal">${p.kcalGoal} kcal</b></div>
    </div>
    <button class="btn" data-act="save-profile">保存</button>
    <div style="height:20px;"></div>
  </div></div>
  `);

  let goal = p.goal, days = p.days;
  $$('#p-goal button').forEach(b => b.addEventListener('click', () => {
    goal = b.dataset.v; $$('#p-goal button').forEach(x => x.classList.toggle('on', x === b));
  }));
  $$('#p-days button').forEach(b => b.addEventListener('click', () => {
    days = +b.dataset.v; $$('#p-days button').forEach(x => x.classList.toggle('on', x === b));
  }));
  const recalc = () => {
    const h = num($('#p-h').value, 178), w = num($('#p-w').value, 76);
    const bmr = 10 * w + 6.25 * h - 5 * 30 + 5;
    const kcal = Math.round(bmr * 1.45 * (goal === '减脂' ? .85 : goal === '增肌' ? 1.1 : 1));
    $('#p-kcal').textContent = kcal + ' kcal';
    return { h, w, kcal };
  };
  ['#p-h', '#p-w'].forEach(s => $(s).addEventListener('input', recalc));

  saveProfile = () => {
    const { h, w, kcal } = recalc();
    S.profile = { ...S.profile, name: $('#p-name').value.trim() || 'YG', goal, days, h, w, kcalGoal: kcal };
    save(); closeSheet(); render(); toast('资料已保存');
  };
}
let saveProfile = () => { };

/* ---------------- 计划 ---------------- */
function openPlanSheet() {
  openSheet(`
  <div class="pw-head">
    <button class="icon-btn l" data-act="close">${I.x}</button>
    <div class="t" style="font-size:17px;">训练计划</div><div></div>
  </div>
  <div class="sheet-body"><div class="pw">
    ${S.plan.items.map(d => `
      <div class="card" style="padding:16px;">
        <div class="hstack" style="margin-bottom:10px;">
          <span class="pill ${d.rest ? 'grey' : ''}">周${WEEK_CN[(d.wd + 1) % 7]}</span>
          <span style="font-weight:600;">${d.title}</span>
        </div>
        ${d.items.map(i => `<div class="goal-row"><span style="font-size:13.5px;">${i.name}</span><span class="gr-r">${i.sets} × ${i.reps}</span></div>`).join('')}
      </div>`).join('')}
    <button class="btn" data-act="replan">${I.sparkles} 重新生成</button>
    <div style="height:20px;"></div>
  </div></div>
  `);
}

/* ---------------- 歌单 / 歌词 / 工具 ---------------- */
function openPlaylist() {
  openSheet(`
  <div class="pw-head">
    <button class="icon-btn l" data-act="close">${I.x}</button>
    <div class="t" style="font-size:17px;">歌单导入</div><div></div>
  </div>
  <div class="sheet-body"><div class="pw">
    <div class="field">
      <label>粘贴歌单链接</label>
      <input id="pl-link" placeholder="https://music.apple.com/… 或 open.spotify.com/…">
      <button class="btn ghost sm" style="margin-top:8px;" data-act="parse-link">解析</button>
      <div class="hint" id="pl-info"></div>
    </div>
    <div class="field">
      <label>曲目列表（每行一首，行尾可写 BPM）</label>
      <textarea id="pl-tracks" placeholder="Neon Pulse 128&#10;Warm Up 96&#10;Final Sprint 160"></textarea>
    </div>
    <div id="pl-bands"></div>
    <button class="btn" data-act="save-playlist">保存这份歌单</button>
    <div style="height:20px;"></div>
  </div></div>
  `);
}

function parseLink() {
  const v = $('#pl-link').value.trim();
  let host = '未知来源';
  try {
    const u = new URL(v);
    host = u.host.includes('apple') ? 'Apple Music'
      : u.host.includes('spotify') ? 'Spotify'
        : u.host.includes('163') ? '网易云音乐'
          : u.host.includes('qq') ? 'QQ 音乐' : u.host;
    $('#pl-info').textContent = `来源 ${host} · ID ${u.pathname.split('/').filter(Boolean).pop() || '—'}`;
  } catch (e) {
    $('#pl-info').textContent = '链接格式不对';
    return;
  }
  const lines = $('#pl-tracks').value.split('\n').map(s => s.trim()).filter(Boolean);
  const tracks = lines.map(l => {
    const m = l.match(/(\d{2,3})\s*$/);
    return { name: l.replace(/\d+\s*$/, '').replace(/bpm/ig, '').trim() || '未命名', bpm: m ? +m[1] : 120 };
  }).sort((a, b) => a.bpm - b.bpm);
  const band = t => t.bpm < 120 ? '热身' : t.bpm < 150 ? '主训' : '冲刺';
  const groups = { 热身: [], 主训: [], 冲刺: [] };
  tracks.forEach(t => groups[band(t)].push(t));
  $('#pl-bands').innerHTML = Object.entries(groups).filter(([, v]) => v.length).map(([g, v]) => `
    <div class="card" style="padding:14px;margin-bottom:10px;">
      <div style="font-weight:700;color:${g === '主训' ? 'var(--green)' : 'var(--dim)'};margin-bottom:6px;">${g}</div>
      ${v.map(t => `<div class="goal-row"><span style="font-size:13px;">${t.name}</span><span class="gr-r">${t.bpm}</span></div>`).join('')}
    </div>`).join('');
  toast('已解析 ' + host);
}

function savePlaylist() {
  S.playlists.unshift({ id: uid(), name: '训练歌单', at: Date.now(), tracks: $('#pl-tracks').value.split('\n').filter(Boolean).length });
  save(); closeSheet(); toast('已保存');
}

let lyrics = [];
let lyricTimer = null;
let lyricT = 0;

function openLyrics() {
  openSheet(`
  <div class="pw-head">
    <button class="icon-btn l" data-act="close">${I.x}</button>
    <div class="t" style="font-size:17px;">歌词同步</div><div></div>
  </div>
  <div class="sheet-body"><div class="pw">
    <div class="field">
      <label>粘贴 .lrc（格式 [mm:ss.xx]歌词）</label>
      <textarea id="lyr-in">[00:00.00]Stride 训练歌单
[00:06.00]把手机架稳
[00:11.50]第一组，找感觉
[00:17.00]离心三秒，别抢
[00:23.00]呼吸跟上节奏
[00:29.00]还差两次
[00:35.00]顶住
[00:41.00]落地稳住
[00:47.00]这一组结束
[00:53.00]休息九十秒
[01:00.00]下一组，加两公斤</textarea>
    </div>
    <button class="btn ghost" data-act="lyr-parse">解析</button>
    <div id="lyr-view"></div>
    <button class="btn" data-act="lyr-play">${I.play} 跟着走</button>
    <div style="height:20px;"></div>
  </div></div>
  `);
}

function parseLyrics() {
  const raw = $('#lyr-in').value;
  lyrics = [];
  raw.split('\n').forEach(line => {
    const m = [...line.matchAll(/\[(\d+):(\d+(?:\.\d+)?)\]/g)];
    const text = line.replace(/\[[^\]]*\]/g, '').trim();
    if (!text || !m.length) return;
    m.forEach(x => lyrics.push({ t: +x[1] * 60 + +x[2], text }));
  });
  lyrics.sort((a, b) => a.t - b.t);
  renderLyrics(0);
  toast('解析 ' + lyrics.length + ' 行');
}

function renderLyrics(idx) {
  const box = $('#lyr-view');
  if (!box) return;
  box.innerHTML = `<div class="card" style="max-height:300px;overflow-y:auto;padding:16px;">
    ${lyrics.map((l, i) => `<div style="padding:6px 0;font-size:${i === idx ? 20 : 15}px;font-weight:${i === idx ? 800 : 400};color:${i === idx ? '#fff' : 'var(--faint)'};transition:.2s;">${l.text}</div>`).join('')}
  </div>`;
}

function toggleLyrics() {
  if (lyricTimer) {
    clearInterval(lyricTimer); lyricTimer = null;
    toast('已暂停');
    return;
  }
  lyricTimer = setInterval(() => {
    lyricT += 0.25;
    const idx = lyrics.reduce((a, l, i) => l.t <= lyricT ? i : a, -1);
    renderLyrics(idx);
    if (lyricT > (lyrics.slice(-1)[0]?.t || 0) + 3) { clearInterval(lyricTimer); lyricTimer = null; }
  }, 250);
}

function openPlugins() {
  openSheet(`
  <div class="pw-head">
    <button class="icon-btn l" data-act="close">${I.x}</button>
    <div class="t" style="font-size:17px;">插件市场</div><div></div>
  </div>
  <div class="sheet-body"><div class="pw">
    <div class="faint">全部小工具免费，不订阅也能用。</div>

    <div class="tool">
      <div class="tool-head"><span class="ti" style="background:rgba(92,224,143,.12);color:var(--green);">${I.fn}</span><h4>1RM 计算</h4></div>
      <div class="hstack">
        <div class="num-box"><label>重量 kg</label><input id="rm-w" type="number" value="80"></div>
        <div class="num-box"><label>次数</label><input id="rm-r" type="number" value="5"></div>
      </div>
      <div class="hstack"><span class="faint">估算 1RM</span><span class="spacer"></span><b id="rm-out" style="font-size:22px;color:var(--green);">93 kg</b></div>
    </div>

    <div class="tool">
      <div class="tool-head"><span class="ti" style="background:rgba(107,168,255,.12);color:var(--blue);">${I.plate}</span><h4>杠铃片</h4></div>
      <div class="hstack">
        <div class="num-box"><label>目标总重</label><input id="pl-t" type="number" value="100"></div>
        <div class="num-box"><label>空杆</label><input id="pl-b" type="number" value="20"></div>
      </div>
      <div id="pl-out" class="faint">每侧：25 ×1</div>
    </div>

    <div class="tool">
      <div class="tool-head"><span class="ti" style="background:rgba(255,184,107,.12);color:var(--amber);">${I.timer}</span><h4>休息计时</h4></div>
      <div class="mode-tabs" id="rest-presets">
        ${[45, 60, 90, 120, 180].map(s => `<button data-v="${s}">${s}″</button>`).join('')}
      </div>
      <div class="hstack"><b id="rest-out" style="font-size:32px;font-variant-numeric:tabular-nums;">0:00</b><span class="spacer"></span>
        <button class="btn sm green" id="rest-btn" style="width:auto;padding:9px 16px;">开始</button></div>
    </div>

    <div class="tool">
      <div class="tool-head"><span class="ti" style="background:rgba(255,135,183,.12);color:var(--pink);">${I.music}</span><h4>音乐节奏 → 动作节奏</h4></div>
      <div class="hstack"><span class="faint">BPM</span><span class="spacer"></span><b id="bpm-out">128</b></div>
      <input id="bpm" type="range" min="60" max="180" value="128" style="width:100%;accent-color:var(--pink);">
      <div class="faint" id="bpm-hint">每拍 0.47 秒，一次动作约 11 拍。</div>
    </div>
    <div style="height:20px;"></div>
  </div></div>
  `);

  const rm = () => {
    const w = num($('#rm-w').value), r = num($('#rm-r').value, 1);
    $('#rm-out').textContent = Math.round(e1rm(w, r)) + ' kg';
  };
  ['#rm-w', '#rm-r'].forEach(s => $(s).addEventListener('input', rm));

  const plates = () => {
    let rest = Math.max(0, (num($('#pl-t').value) - num($('#pl-b').value)) / 2);
    const out = [];
    [25, 20, 15, 10, 5, 2.5, 1.25].forEach(p => {
      const n = Math.floor(rest / p);
      if (n > 0) { out.push(p + ' ×' + n); rest -= n * p; }
    });
    $('#pl-out').textContent = out.length ? '每侧：' + out.join(' · ') : '只有空杆';
  };
  ['#pl-t', '#pl-b'].forEach(s => $(s).addEventListener('input', plates));

  let restLeft = 0, restTimer = null;
  $$('#rest-presets button').forEach(b => b.addEventListener('click', () => {
    $$('#rest-presets button').forEach(x => x.classList.toggle('on', x === b));
    restLeft = +b.dataset.v;
    $('#rest-out').textContent = Math.floor(restLeft / 60) + ':' + pad(restLeft % 60);
  }));
  $('#rest-btn').addEventListener('click', () => {
    if (restTimer) { clearInterval(restTimer); restTimer = null; $('#rest-btn').textContent = '继续'; return; }
    if (!restLeft) restLeft = 90;
    $('#rest-btn').textContent = '暂停';
    restTimer = setInterval(() => {
      restLeft--;
      $('#rest-out').textContent = Math.floor(Math.max(0, restLeft) / 60) + ':' + pad(Math.max(0, restLeft) % 60);
      if (restLeft <= 0) { clearInterval(restTimer); restTimer = null; $('#rest-btn').textContent = '开始'; }
    }, 1000);
  });

  $('#bpm').addEventListener('input', e => {
    const b = +e.target.value, beat = 60 / b;
    $('#bpm-out').textContent = b;
    $('#bpm-hint').textContent = `每拍 ${beat.toFixed(2)} 秒，一次动作约 ${Math.round(5 / beat)} 拍。`;
  });
}

/* ---------------- 手动计数 ---------------- */
let counterReps = 0;

function openCounter() {
  counterReps = 0;
  renderCounter();
}
function renderCounter() {
  openSheet(`
  <div class="pw-head">
    <button class="icon-btn l" data-act="close">${I.x}</button>
    <div class="t" style="font-size:17px;">动作计数</div><div></div>
  </div>
  <div class="sheet-body"><div class="pw" style="align-items:center;padding-top:40px;">
    <div style="font-size:96px;font-weight:900;font-variant-numeric:tabular-nums;letter-spacing:-4px;">${counterReps}</div>
    <div class="faint" style="margin-top:-6px;">次</div>
    <div class="faint" style="text-align:center;margin:18px 0;">每完成一次点一下。Web 版没有相机骨骼识别，<br>原生版用的是 Vision 关节角。</div>
    <button class="btn" style="max-width:280px;" data-act="tool-counter">记一次</button>
    <button class="btn ghost" style="max-width:280px;" data-act="tool-counter-reset">归零</button>
  </div></div>
  `);
}

/* ---------------- 启动 ---------------- */
function initTabs() {
  const map = { today: ['sun', '今日'], training: ['dumbbell', '训练'], progress: ['chart', '进度'], coach: ['chat', '教练'], me: ['person', '我的'] };
  $$('.tab').forEach(b => {
    const [ic, label] = map[b.dataset.tab];
    b.innerHTML = I[ic] + `<span>${label}</span>`;
  });
}

function initComposer() {
  // 教练页的输入条是固定的，切页时挂载/卸载
  const old = $('#composer');
  if (old) old.remove();
  const sc0 = $('#screen');
  if (sc0) sc0.style.paddingBottom = '';
  if (TAB !== 'coach') return;
  const bar = document.createElement('div');
  bar.className = 'composer';
  bar.id = 'composer';
  bar.innerHTML = `
    <input id="composer-input" placeholder="问点具体的，比如「深蹲该加多少」">
    <button class="send" id="composer-send">${I.arrowUp}</button>`;
  document.body.appendChild(bar);
  const send = () => askCoach();
  $('#composer-send').addEventListener('click', send);
  $('#composer-input').addEventListener('keydown', e => { if (e.key === 'Enter') send(); });
  const sc = $('#screen');
  if (sc) sc.style.paddingBottom = '70px';
}

const _render = render;
render = function () {
  _render();
  initComposer();
  if (TAB === 'coach') {
    const c = $('#chat');
    if (c) window.scrollTo(0, document.body.scrollHeight);
  }
};

initTabs();
render();
