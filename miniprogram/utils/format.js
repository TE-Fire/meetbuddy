// 展示层的小工具函数，与 Flutter 端 ActivityCard/_timeText 的口径保持一致。
// imgUrl 依赖 config/env（当前环境的后端地址），故在此引入。
const env = require('../config/env');

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

/**
 * 状态 → 中文文案。后端 ActivityVO 只给 status 枚举，没有 statusLabel；
 * Flutter 端是模型上的 getter 算的，这里必须同口径补一个，否则界面会漏出 OPEN/FULL。
 */
function statusLabel(status) {
  const map = {
    OPEN: '报名中',
    FULL: '已满',
    ONGOING: '进行中',
    FINISHED: '已结束',
    CANCELLED: '已取消',
  };
  return map[status] || status || '';
}

/** 状态 → 软标签色调 */
function statusTone(status) {
  if (status === 'OPEN') return 'grass';
  if (status === 'FULL') return 'warm';
  return 'plain';
}

/**
 * 网络图片地址归一化。上传接口按「请求 Host」生成绝对地址存库，于是：
 *   模拟器上传 → 库里是 http://127.0.0.1:8099/…
 *   真机上传   → 库里是 http://10.24.119.1:8099/…（换 WiFi 后这个 IP 就过期）
 *   curl 上传  → 库里是 http://localhost:8099/…（手机上看等于指手机自己）
 * 三类地址换台设备就看不了，所以在渲染侧统一按当前环境重写，旧数据自愈：
 *   /uploads/…             → 拼当前 apiBase（后端静态目录）
 *   /images/… 等包内路径    → 原样返回（小程序包内资源，不能拼服务器地址）
 *   http://任意主机/…       → 换成当前 apiBase 的 origin（本项目的 http 图片只可能是后端上传的）
 *   https://…、data:、wxfile: → 原样返回（外链/本地临时文件不受影响）
 */
function imgUrl(u) {
  if (!u || typeof u !== 'string') return '';
  if (u.indexOf('/uploads/') === 0) return env.apiBase + u;
  if (u.charAt(0) === '/') return u;
  const m = u.match(/^http:\/\/[^/]+(\/.*)?$/);
  if (m) return env.apiBase.replace(/\/+$/, '') + (m[1] || '');
  return u;
}

module.exports = { timeBadge, fmtTime, fmtHm, ago, km, shortAddr, statusLabel, statusTone, imgUrl, pad2 };
