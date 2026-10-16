const api = require('../../utils/api');
const fmt = require('../../utils/format');

const CATEGORY_ICONS = { 剧本杀: '🎭', 运动: '🏸', 探店: '🍜', 桌游: '🎲', 户外: '⛰️', 观影: '🎬', 其他: '✨' };

function pad2(v) {
  return String(v).padStart(2, '0');
}

function dateKey(iso) {
  const t = new Date(iso);
  return `${t.getFullYear()}-${pad2(t.getMonth() + 1)}-${pad2(t.getDate())}`;
}

function dateLabel(iso) {
  const t = new Date(iso);
  const now = new Date();
  const a = new Date(t.getFullYear(), t.getMonth(), t.getDate());
  const b = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const diff = Math.round((a - b) / 86400000);
  if (diff === 0) return '今天';
  if (diff === 1) return '明天';
  if (diff === 2) return '后天';
  if (diff > 2 && diff < 7) return '周' + '日一二三四五六'[t.getDay()];
  return `${t.getMonth() + 1}月${t.getDate()}日`;
}

function mapCard(a, role) {
  const start = new Date(a.startTime).getTime();
  const end = a.endTime ? new Date(a.endTime).getTime() : start;
  return {
    ...a,
    icon: CATEGORY_ICONS[a.category] || '✨',
    timeLabel: fmt.fmtHm(a.startTime),
    dateKey: dateKey(a.startTime),
    dateLabel: dateLabel(a.startTime),
    addrShort: fmt.shortAddr(a.address),
    ratio: a.maxParticipants > 0 ? Math.min(1, a.currentParticipants / a.maxParticipants) : 0,
    full: a.currentParticipants >= a.maxParticipants,
    statusLabel: fmt.statusLabel(a.status),
    // 结束时间已过才算「已过去」，进行中(ONGOING)的活动不灰显
    past: end < Date.now(),
    role,
    roleLabel: role === 'host' ? '我发起' : '我报名',
  };
}

Page({
  data: {
    groups: [],
    filter: 'all',
    loading: true,
  },

  onShow() {
    this.load();
  },

  async load() {
    this.setData({ loading: true });
    try {
      const [org, jnd] = await Promise.all([
        api.get('/api/activity/mine/organized', { page: 1, size: 100 }),
        api.get('/api/activity/mine/joined', { page: 1, size: 100 }),
      ]);
      const byId = new Map();
      ((org && org.list) || []).forEach((a) => {
        if (!byId.has(a.id)) byId.set(a.id, mapCard(a, 'host'));
      });
      ((jnd && jnd.list) || []).forEach((a) => {
        if (!byId.has(a.id)) byId.set(a.id, mapCard(a, 'join'));
      });
      this._all = Array.from(byId.values());
      this.applyFilter();
    } catch (e) {
      this.setData({ loading: false });
      wx.showToast({ title: e.message, icon: 'none' });
    }
  },

  onFilter(e) {
    this.setData({ filter: e.currentTarget.dataset.f });
    this.applyFilter();
  },

  applyFilter() {
    const f = this.data.filter;
    let list = this._all || [];
    if (f === 'host') list = list.filter((a) => a.role === 'host');
    else if (f === 'join') list = list.filter((a) => a.role === 'join');

    const map = new Map();
    list.forEach((a) => {
      if (!map.has(a.dateKey)) map.set(a.dateKey, []);
      map.get(a.dateKey).push(a);
    });
    const todayKey = dateKey(new Date());
    const future = [];
    const past = [];
    for (const [k, items] of map) {
      items.sort((x, y) => new Date(x.startTime) - new Date(y.startTime));
      const grp = { key: k, label: items[0].dateLabel, past: items[0].past, items };
      if (k >= todayKey) future.push(grp);
      else past.push(grp);
    }
    future.sort((a, b) => (a.key < b.key ? -1 : 1));
    past.sort((a, b) => (a.key < b.key ? 1 : -1)); // 最近的过去排在前
    this.setData({ groups: future.concat(past), loading: false });
  },

  openDetail(e) {
    wx.navigateTo({ url: `/pages/detail/detail?id=${e.currentTarget.dataset.id}` });
  },

  onPullDownRefresh() {
    this.load().then(() => wx.stopPullDownRefresh());
  },
});
