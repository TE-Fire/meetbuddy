const api = require('../../utils/api');
const fmt = require('../../utils/format');

const CATEGORY_ICONS = { 剧本杀: '🎭', 运动: '🏸', 探店: '🍜', 桌游: '🎲', 户外: '⛰️', 观影: '🎬', 其他: '✨' };

function mapCard(a) {
  return {
    ...a,
    icon: CATEGORY_ICONS[a.category] || '✨',
    timeBadge: fmt.timeBadge(a.startTime),
    addrShort: fmt.shortAddr(a.address),
    ratio: a.maxParticipants > 0 ? Math.min(1, a.currentParticipants / a.maxParticipants) : 0,
    full: a.currentParticipants >= a.maxParticipants,
  };
}

Page({
  data: {
    me: null,
    organized: [],
    joined: [],
    connected: false,
    loading: true,

    // —— 编辑资料面板 ——
    showEdit: false,
    saving: false,
    editForm: { nickname: '', bio: '', gender: 0 },
    genderLabels: ['保密', '男', '女'],
  },

  onShow() {
    if (typeof this.getTabBar === 'function' && this.getTabBar()) {
      this.getTabBar().setSelected(2);
    }
    const app = getApp();
    if (!app.isLoggedIn()) {
      wx.reLaunch({ url: '/pages/login/login' });
      return;
    }
    const me = app.globalData.me;
    this.setData({ me: me ? { ...me, first: (me.nickname || '?')[0] } : null, connected: socketIsOn() });
    this.load();
  },

  async load() {
    try {
      const [organized, joined] = await Promise.all([
        api.get('/api/activity/mine/organized', { page: 1, size: 20 }),
        api.get('/api/activity/mine/joined', { page: 1, size: 20 }),
      ]);
      const list = (x) => ((x && x.list) || []).map(mapCard);
      this.setData({
        organized: list(organized),
        joined: list(joined),
        loading: false,
      });
    } catch (e) {
      this.setData({ loading: false });
      wx.showToast({ title: e.message, icon: 'none' });
    }
  },

  openDetail(e) {
    wx.navigateTo({ url: `/pages/detail/detail?id=${e.currentTarget.dataset.id}` });
  },

  /** 菜单卡前两行：数据就在本页下方，滚过去比再开一页少一步跳转 */
  jumpTo(e) {
    wx.pageScrollTo({ selector: `#${e.currentTarget.dataset.target}`, duration: 300 });
  },

  openCreditLog() {
    wx.navigateTo({ url: '/pages/credit-log/credit-log' });
  },

  openBuddy() {
    wx.navigateTo({ url: '/pages/buddy/buddy' });
  },

  // ============ 编辑资料 ============
  editProfile() {
    const me = this.data.me;
    if (!me) return;
    this.setData({
      showEdit: true,
      editForm: {
        nickname: me.nickname || '',
        bio: me.bio || '',
        gender: me.gender || 0,
      },
    });
  },
  closeEdit() {
    this.setData({ showEdit: false });
  },
  onEditNick(e) {
    this.setData({ 'editForm.nickname': e.detail.value });
  },
  onEditBio(e) {
    this.setData({ 'editForm.bio': e.detail.value });
  },
  onEditGender(e) {
    this.setData({ 'editForm.gender': Number(e.detail.value) });
  },
  async saveProfile() {
    if (this.data.saving) return;
    const f = this.data.editForm;
    if (!f.nickname.trim()) {
      wx.showToast({ title: '昵称不能为空', icon: 'none' });
      return;
    }
    this.setData({ saving: true });
    try {
      const updated = await api.put('/api/user/profile', {
        nickname: f.nickname,
        bio: f.bio,
        gender: f.gender,
      });
      // 本页与全局缓存一起刷新，避免 onShow 时又被旧缓存覆盖
      const me = { ...updated, first: (updated.nickname || '?')[0] };
      getApp().globalData.me = updated;
      this.setData({ me, showEdit: false, saving: false });
      wx.showToast({ title: '已保存', icon: 'none' });
    } catch (e) {
      this.setData({ saving: false });
      wx.showToast({ title: e.message, icon: 'none' });
    }
  },

  /** 数据源那一行点开显示真实地址——真机联调时能直接看清它连的是哪个 host */
  showSource() {
    const env = require('../../config/env');
    wx.showModal({
      title: '当前数据源',
      content: `${env.apiBase}\n实时通道：${this.data.connected ? '已连接' : '未连接'}`,
      showCancel: false,
      confirmText: '知道了',
    });
  },

  async logout() {
    const res = await new Promise((resolve) => {
      wx.showModal({
        title: '退出登录？',
        content: '会断开实时连接，本地保存的令牌一并清掉。',
        confirmText: '退出',
        cancelText: '取消',
        success: resolve,
      });
    });
    if (!res.confirm) return;
    await getApp().logout();
    wx.reLaunch({ url: '/pages/login/login' });
  },
});

function socketIsOn() {
  // 避免顶部重复引入 socket 模块造成循环依赖，这里延迟 require
  return require('../../utils/socket').isConnected();
}
