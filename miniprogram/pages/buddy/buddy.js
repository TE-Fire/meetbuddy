const api = require('../../utils/api');
const fmt = require('../../utils/format');

const CATEGORIES = ['剧本杀', '运动', '探店', '桌游', '户外', '观影', '其他'];
const TAG_POOL = ['新手友好', '硬核', '深夜局', 'AA制', '免费', '带装备', '轻运动', '拍照'];
const RADIUS_OPTIONS = [5, 10, 25, 50];

// 演示坐标与 feed 就近筛选同源（北京国贸）。小程序整体未接真实定位，
// 匹配页沿用同一坐标，两边的"附近"才是一致的
const DEMO_LNG = 116.461;
const DEMO_LAT = 39.9088;

Page({
  data: {
    tab: 'match',
    radius: 10,
    matches: [],
    matchLoading: false,
    mine: [],
    mineLoading: false,
    categories: CATEGORIES,
    tagPool: TAG_POOL,
    showPublish: false,
    publishing: false,
    form: { title: '', category: CATEGORIES[0], timeRange: '', tags: [], description: '' },
  },

  onShow() {
    // 每次回到本页都刷新：从聊天页返回时，匹配结果或我的需求可能已变
    if (this.data.tab === 'match') this.loadMatches();
    else this.loadMine();
  },

  switchTab(e) {
    const t = e.currentTarget.dataset.t;
    if (t === this.data.tab) return;
    this.setData({ tab: t });
    if (t === 'match') this.loadMatches();
    else this.loadMine();
  },

  async loadMatches() {
    if (this.data.matchLoading) return;
    this.setData({ matchLoading: true });
    try {
      const list = await api.get('/api/buddy/match', {
        lng: DEMO_LNG,
        lat: DEMO_LAT,
        radius: this.data.radius,
        limit: 20,
      });
      this.setData({
        matches: (list || []).map((m) => ({
          ...m,
          // score 是 [0,1] 的小数，直接显示两位小数太技术化，转成百分比
          scorePct: Math.round((m.score || 0) * 100) + '%',
          distanceText: m.distance < 1 ? `${Math.round(m.distance * 1000)} m` : `${m.distance.toFixed(1)} km`,
          avatarUrl: fmt.imgUrl(m.avatar),
        })),
        matchLoading: false,
      });
    } catch (e) {
      this.setData({ matchLoading: false });
      wx.showToast({ title: e.message, icon: 'none' });
    }
  },

  async loadMine() {
    if (this.data.mineLoading) return;
    this.setData({ mineLoading: true });
    try {
      const list = await api.get('/api/buddy');
      this.setData({
        mine: (list || []).map((b) => ({ ...b, timeText: fmt.fmtTime(b.createdAt) })),
        mineLoading: false,
      });
    } catch (e) {
      this.setData({ mineLoading: false });
      wx.showToast({ title: e.message, icon: 'none' });
    }
  },

  changeRadius() {
    wx.showActionSheet({
      itemList: RADIUS_OPTIONS.map((r) => `${r} 公里`),
      success: (res) => {
        this.setData({ radius: RADIUS_OPTIONS[res.tapIndex] }, () => this.loadMatches());
      },
    });
  },

  /** 私聊：chat-room 的 peerId 模式（后端 sendToUser 链路早已就绪） */
  dm(e) {
    const { id, name } = e.currentTarget.dataset;
    if (!id) return;
    wx.navigateTo({
      url: `/pages/chat-room/chat-room?peerId=${id}&title=${encodeURIComponent(name || '私聊')}`,
    });
  },

  closeRequest(e) {
    const id = e.currentTarget.dataset.id;
    wx.showModal({
      title: '关闭需求',
      content: '关闭后不再参与匹配，确定吗？',
      confirmText: '关闭',
      confirmColor: '#eb4d5c',
      success: async (res) => {
        if (!res.confirm) return;
        try {
          await api.put(`/api/buddy/${id}/close`);
          wx.showToast({ title: '已关闭', icon: 'none' });
          this.loadMine();
        } catch (err) {
          wx.showToast({ title: err.message, icon: 'none' });
        }
      },
    });
  },

  // ============ 发布需求 ============
  openPublish() {
    this.setData({
      showPublish: true,
      form: { title: '', category: CATEGORIES[0], timeRange: '', tags: [], description: '' },
    });
  },
  closePublish() {
    this.setData({ showPublish: false });
  },
  onFormTitle(e) {
    this.setData({ 'form.title': e.detail.value });
  },
  onFormTime(e) {
    this.setData({ 'form.timeRange': e.detail.value });
  },
  onFormDesc(e) {
    this.setData({ 'form.description': e.detail.value });
  },
  pickFormCategory(e) {
    this.setData({ 'form.category': e.currentTarget.dataset.c });
  },
  toggleFormTag(e) {
    const t = e.currentTarget.dataset.t;
    const tags = this.data.form.tags.slice();
    const i = tags.indexOf(t);
    if (i >= 0) tags.splice(i, 1);
    else tags.push(t);
    this.setData({ 'form.tags': tags });
  },
  async submitPublish() {
    if (this.data.publishing) return;
    const f = this.data.form;
    if (f.title.trim().length < 2) {
      wx.showToast({ title: '至少写两个字', icon: 'none' });
      return;
    }
    this.setData({ publishing: true });
    try {
      await api.post('/api/buddy', {
        title: f.title.trim(),
        category: f.category,
        description: f.description.trim() || null,
        lng: DEMO_LNG,
        lat: DEMO_LAT,
        timeRange: f.timeRange.trim() || null,
        tags: f.tags,
      });
      this.setData({ showPublish: false, publishing: false, tab: 'mine' });
      wx.showToast({ title: '需求已发布', icon: 'none' });
      this.loadMine();
    } catch (e) {
      this.setData({ publishing: false });
      wx.showToast({ title: e.message, icon: 'none' });
    }
  },
  noop() {},
});
