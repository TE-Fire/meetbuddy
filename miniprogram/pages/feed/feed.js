const api = require('../../utils/api');
const fmt = require('../../utils/format');

const CATEGORY_ICONS = { 剧本杀: '🎭', 运动: '🏸', 探店: '🍜', 桌游: '🎲', 户外: '⛰️', 观影: '🎬', 其他: '✨' };

const CATEGORIES = Object.keys(CATEGORY_ICONS);

function mapActivity(a, distanceKm) {
  return {
    ...a,
    icon: CATEGORY_ICONS[a.category] || '✨',
    // 封面地址归一化后再进渲染层（见 fmt.imgUrl 注释）：换设备、换 WiFi 都能自愈
    coverSrc: fmt.imgUrl(a.coverUrl),
    timeBadge: fmt.timeBadge(a.startTime),
    isToday: (a.startTime || '').slice(0, 10) === new Date().toISOString().slice(0, 10),
    addrShort: fmt.shortAddr(distanceKm == null ? a.address : `${fmt.shortAddr(a.address)} · ${fmt.km(distanceKm)}`),
    statusText: fmt.statusLabel(a.status),
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
    // —— 排序 tab：最新 / 最热 / 最近（最近仅在开启就近时生效）——
    sorts: [
      { key: 'latest', label: '最新' },
      { key: 'hot', label: '最热' },
      { key: 'distance', label: '最近' },
    ],
    sortBy: 'latest',
    feed: [],
    loading: false,
    error: '',
    page: 1,
    hasMore: false,
    geoEnabled: false,
    radius: 10,

    // —— 搜索态 ——
    searching: false,
    searchFocus: false,
    keyword: '',
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
    if (this.data.keyword) query.keyword = this.data.keyword.trim();
    // 最近排序依赖坐标，未开就近时传 latest，后端也会再降级一次，双保险
    if (this.data.sortBy === 'distance' && !this.data.geoEnabled) {
      query.sortBy = 'latest';
    } else if (this.data.sortBy !== 'latest') {
      query.sortBy = this.data.sortBy;
    }
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

  onSort(e) {
    const s = e.currentTarget.dataset.s || 'latest';
    if (s === this.data.sortBy) return;
    this.setData({ sortBy: s });
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

  // ============ 搜索 ============
  openSearch() {
    this.setData({ searching: true, searchFocus: true });
  },
  onKeyword(e) {
    this.setData({ keyword: e.detail.value });
    // 清空输入时自动回到完整列表，不用再点一次搜索
    if (!e.detail.value.trim() && this._wasSearch) {
      this._wasSearch = false;
      this.load(true);
    }
  },
  /** 键盘确认键 / 回车触发 */
  doSearch() {
    const kw = (this.data.keyword || '').trim();
    if (!kw) {
      wx.showToast({ title: '先输入点关键词', icon: 'none' });
      return;
    }
    this._wasSearch = true;
    this.load(true);
  },
  closeSearch() {
    const wasSearch = this._wasSearch;
    this._wasSearch = false;
    this.setData({ searching: false, searchFocus: false, keyword: '' });
    // 从搜索结果退出时，恢复完整列表
    if (wasSearch) this.load(true);
  },
});
