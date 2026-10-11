const api = require('../../utils/api');
const fmt = require('../../utils/format');

const CATEGORY_ICONS = { 剧本杀: '🎭', 运动: '🏸', 探店: '🍜', 桌游: '🎲', 户外: '⛰️', 观影: '🎬', 其他: '✨' };

const CATEGORIES = Object.keys(CATEGORY_ICONS);

function mapActivity(a, distanceKm) {
  return {
    ...a,
    icon: CATEGORY_ICONS[a.category] || '✨',
    timeBadge: fmt.timeBadge(a.startTime),
    isToday: (a.startTime || '').slice(0, 10) === new Date().toISOString().slice(0, 10),
    addrShort: fmt.shortAddr(distanceKm == null ? a.address : `${fmt.shortAddr(a.address)} · ${fmt.km(distanceKm)}`),
    statusText: a.statusLabel || a.status,
    statusTone: fmt.statusTone(a.status),
    ratio: a.maxParticipants > 0 ? Math.min(1, a.currentParticipants / a.maxParticipants) : 0,
    full: a.currentParticipants >= a.maxParticipants,
    whoFirst: a.participants && a.participants.length
      ? a.participants[0].nickname
      : (a.organizerNickname || ''),
  };
}

Page({
  data: {
    me: null,
    categories: CATEGORIES,
    category: '',
    feed: [],
    loading: false,
    error: '',
    page: 1,
    hasMore: false,
    geoEnabled: false,
    radius: 10,
  },

  onLoad() {
    this.load(true);
  },

  onShow() {
    if (typeof this.getTabBar === 'function' && this.getTabBar()) {
      this.getTabBar().setSelected(0);
    }
    const app = getApp();
    if (!app.isLoggedIn()) {
      wx.reLaunch({ url: '/pages/login/login' });
      return;
    }
    this.setData({ me: app.globalData.me });
    // 从详情页回来可能报了名/取消了，刷新一次避免数字是旧的
    if (this._dirty) {
      this._dirty = false;
      this.load(true);
    }
  },

  onHide() {
    // 有交互发生就标记脏，回来自刷
    this._dirty = true;
  },

  async load(reset) {
    if (this.data.loading) return;
    const page = reset ? 1 : this.data.page + 1;
    this.setData({ loading: true, error: '' });
    const query = { page, size: 20, category: this.data.category || undefined };
    if (this.data.geoEnabled) {
      // 演示坐标：北京国贸
      query.lng = 116.461;
      query.lat = 39.9088;
      query.radius = this.data.radius;
    }
    try {
      const data = await api.get('/api/activity', query);
      const items = (data.list || data.items || []).map((a) => mapActivity(a, this.distanceFrom(a)));
      this.setData({
        feed: reset ? items : this.data.feed.concat(items),
        page,
        hasMore: items.length >= 20,
        loading: false,
      });
    } catch (e) {
      this.setData({ loading: false, error: e.message, feed: reset ? [] : this.data.feed });
    }
  },

  distanceFrom(a) {
    if (!this.data.geoEnabled || !a.lng || !a.lat) return null;
    const R = 6371;
    const dLat = ((a.lat - 39.9088) * Math.PI) / 180;
    const dLng = ((a.lng - 116.461) * Math.PI) / 180;
    const s =
      Math.sin(dLat / 2) ** 2 +
      Math.cos((39.9088 * Math.PI) / 180) * Math.cos((a.lat * Math.PI) / 180) * Math.sin(dLng / 2) ** 2;
    return 2 * R * Math.asin(Math.sqrt(s));
  },

  onCategory(e) {
    const c = e.currentTarget.dataset.c || '';
    if (c === this.data.category) return;
    this.setData({ category: c });
    this.load(true);
  },

  toggleGeo() {
    this.setData({ geoEnabled: !this.data.geoEnabled });
    this.load(true);
  },

  onReachBottom() {
    if (this.data.hasMore && !this.data.loading) {
      this.load(false);
    }
  },

  onPullDownRefresh() {
    this.load(true).then(() => wx.stopPullDownRefresh());
  },

  openDetail(e) {
    wx.navigateTo({ url: `/pages/detail/detail?id=${e.currentTarget.dataset.id}` });
  },

  openCreate() {
    wx.navigateTo({ url: '/pages/create/create' });
  },

  searchTip() {
    wx.showToast({ title: '搜索还在路上，先用分类逛逛', icon: 'none' });
  },
});
