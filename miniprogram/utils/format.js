// 展示层的小工具函数，与 Flutter 端 ActivityCard/_timeText 的口径保持一致。
function pad2(v) {
  return String(v).padStart(2, '0');
}

/** 时间徽标文案：今天 19:30 / 明天 09:00 / 10月17日 14:00 */
function timeBadge(iso) {
  if (!iso) return '时间待定';
  const t = new Date(iso);
  if (Number.isNaN(t.getTime())) return '时间待定';
  const now = new Date();
  const sameDay = t.getFullYear() === now.getFullYear() && t.getMonth() === now.getMonth() && t.getDate() === now.getDate();
  const tomorrow = new Date(now.getTime() + 86400000);
  const isTomorrow = t.getFullYear() === tomorrow.getFullYear() && t.getMonth() === tomorrow.getMonth() && t.getDate() === tomorrow.getDate();
  const hm = `${pad2(t.getHours())}:${pad2(t.getMinutes())}`;
  if (sameDay) return `今天 ${hm}`;
  if (isTomorrow) return `明天 ${hm}`;
  return `${t.getMonth() + 1}月${t.getDate()}日 ${hm}`;
}

function fmtTime(iso) {
  if (!iso) return '待定';
  const t = new Date(iso);
  if (Number.isNaN(t.getTime())) return '待定';
  return `${t.getMonth() + 1}月${t.getDate()}日 ${pad2(t.getHours())}:${pad2(t.getMinutes())}`;
}

function fmtHm(iso) {
  if (!iso) return '';
  const t = new Date(iso);
  if (Number.isNaN(t.getTime())) return '';
  return `${pad2(t.getHours())}:${pad2(t.getMinutes())}`;
}

function ago(iso) {
  if (!iso) return '';
  const t = new Date(iso).getTime();
  if (Number.isNaN(t)) return '';
  const d = Date.now() - t;
  const m = Math.floor(d / 60000);
  if (m < 1) return '刚刚';
  if (m < 60) return `${m} 分钟前`;
  if (m < 1440) return `${Math.floor(m / 60)} 小时前`;
  return `${Math.floor(m / 1440)} 天前`;
}

function km(v) {
  return v < 1 ? `${Math.round(v * 1000)}m` : `${v.toFixed(1)}km`;
}

/** 地址太长只留最后一段（"朝阳区建国门外大街 1 号" → "建国门外大街 1 号"） */
function shortAddr(address) {
  if (!address) return '';
  const parts = String(address).split('·').map((s) => s.trim()).filter(Boolean);
  const tail = parts.length ? parts[parts.length - 1] : address;
  return tail.length <= 14 ? tail : `${tail.slice(0, 13)}…`;
}

/** 状态 → 软标签色调 */
function statusTone(status) {
  if (status === 'OPEN') return 'grass';
  if (status === 'FULL') return 'warm';
  return 'plain';
}

module.exports = { timeBadge, fmtTime, fmtHm, ago, km, shortAddr, statusTone, pad2 };
