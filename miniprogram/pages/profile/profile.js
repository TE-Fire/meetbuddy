const api = require('../../utils/api');
const fmt = require('../../utils/format');
const env = require('../../config/env');

const CATEGORY_ICONS = { 剧本杀: '🎭', 运动: '🏸', 探店: '🍜', 桌游: '🎲', 户外: '⛰️', 观影: '🎬', 其他: '✨' };

// 兴趣标签建议池：规范性由前端负责（docs/02），不进字典表。覆盖活动与搭子主流品类。
const TAG_SUGGESTIONS = [
  '剧本杀', '桌游', '飞盘', '篮球', '跑步', '健身', '探店', '美食', '咖啡',
  '露营', '徒步', '户外', '观影', '演唱会', '读书', '考研自习', '摄影', '绘画',
  '音乐', '旅行', '宠物', '汉服', '动漫', '电竞', 'K歌', '麻将',
];
const TAG_MAX = 20;

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
    // 自己的关注/粉丝数：复用他人主页接口取（后端对 self 也返回，就不污染 UserVO）
    follow: { following: 0, followers: 0 },
    connected: false,
    loading: true,

    // —— 编辑资料面板 ——
    showEdit: false,
    saving: false,
    tagInput: '',
    suggestedTags: TAG_SUGGESTIONS.map((t) => ({ name: t, on: false })),
    editForm: { nickname: '', bio: '', gender: 0, tags: [] },
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
    this.setData({ me: me ? { ...me, first: (me.nickname || '?')[0], avatarUrl: fmt.imgUrl(me.avatar), tags: me.tags || [] } : null, connected: socketIsOn() });
    this.load();
  },

  async load() {
    const me = this.data.me;
    try {
      const [organized, joined, profile] = await Promise.all([
        api.get('/api/activity/mine/organized', { page: 1, size: 20 }),
        api.get('/api/activity/mine/joined', { page: 1, size: 20 }),
        // 关注/粉丝数走 profile 接口（对 self 同样返回，且已有 self 语义）；
        // 取不到就保留上一次的值，不把已有数字打回 0
        me ? api.get(`/api/user/${me.id}/profile`).catch(() => null) : null,
      ]);
      const list = (x) => ((x && x.list) || []).map(mapCard);
      this.setData({
        organized: list(organized),
        joined: list(joined),
        follow: profile
          ? { following: profile.followingCount || 0, followers: profile.followerCount || 0 }
          : this.data.follow,
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

  openBadges() {
    wx.navigateTo({ url: '/pages/badge/badge' });
  },

  openSchedule() {
    wx.navigateTo({ url: '/pages/schedule/schedule' });
  },

  /** 自己的关注 / 粉丝列表（复用他人主页那套列表页，id 传自己） */
  openFollowList(e) {
    const me = this.data.me;
    if (!me || !me.id) return;
    const tab = e.currentTarget.dataset.tab === 'followers' ? 'followers' : 'following';
    wx.navigateTo({ url: `/pages/follow-list/follow-list?id=${me.id}&tab=${tab}` });
  },

  openBuddy() {
    wx.navigateTo({ url: '/pages/buddy/buddy' });
  },

  // ============ 编辑资料 ============
  chooseAvatar() {
    wx.chooseMedia({
      count: 1,
      mediaType: ['image'],
      sourceType: ['album', 'camera'],
      sizeType: ['compressed'],
      success: async (res) => {
        const temp = res.tempFiles[0].tempFilePath;
        try {
          const url = await this.uploadAvatar(temp);
          this.setData({ 'editForm.avatar': url, 'editForm.avatarUrl': url });
        } catch (e) {
          wx.showToast({ title: e.message || '上传失败', icon: 'none' });
        }
      },
    });
  },
  uploadAvatar(tempPath) {
    return new Promise((resolve, reject) => {
      const token = getApp().globalData.token;
      wx.uploadFile({
        url: env.apiBase + '/api/upload/image',
        filePath: tempPath,
        name: 'file',
        header: token ? { Authorization: 'Bearer ' + token } : {},
        success: (r) => {
          try {
            const body = JSON.parse(r.data);
            if (body.code === 0 && body.data) resolve(body.data);
            else reject(new Error(body.message || '上传失败'));
          } catch (e) {
            reject(new Error('上传失败'));
          }
        },
        fail: () => reject(new Error('上传失败')),
      });
    });
  },
  editProfile() {
    const me = this.data.me;
    if (!me) return;
    const tags = (me.tags || []).slice();
    this.setData({
      showEdit: true,
      tagInput: '',
      editForm: {
        nickname: me.nickname || '',
        bio: me.bio || '',
        gender: me.gender || 0,
        avatar: me.avatar || '',
        avatarUrl: fmt.imgUrl(me.avatar),
        tags,
      },
      suggestedTags: TAG_SUGGESTIONS.map((t) => ({ name: t, on: tags.includes(t) })),
    });
  },
  closeEdit() {
    this.setData({ showEdit: false });
  },
  /** 弹层空档处拦截触摸移动，防止滚动穿透到底下页面（滚动手感由 sheet-body 自己负责） */
  noop() {},
  onEditNick(e) {
    this.setData({ 'editForm.nickname': e.detail.value });
  },
  onEditBio(e) {
    this.setData({ 'editForm.bio': e.detail.value });
  },
  onEditGender(e) {
    this.setData({ 'editForm.gender': Number(e.detail.value) });
  },

  // ============ 兴趣标签 ============
  onTagInput(e) {
    this.setData({ tagInput: e.detail.value });
  },
  /** 统一回写选中标签 + 同步建议池高亮，避免 WXML 里调数组方法 */
  _commitTags(tags) {
    this.setData({
      'editForm.tags': tags,
      suggestedTags: TAG_SUGGESTIONS.map((t) => ({ name: t, on: tags.includes(t) })),
    });
  },
  toggleTag(e) {
    const t = e.currentTarget.dataset.t;
    const tags = this.data.editForm.tags.slice();
    const i = tags.indexOf(t);
    if (i >= 0) tags.splice(i, 1);
    else {
      if (tags.length >= TAG_MAX) {
        wx.showToast({ title: `最多 ${TAG_MAX} 个`, icon: 'none' });
        return;
      }
      tags.push(t);
    }
    this._commitTags(tags);
  },
  removeTag(e) {
    const t = e.currentTarget.dataset.t;
    this._commitTags(this.data.editForm.tags.filter((x) => x !== t));
  },
  addCustomTag() {
    const raw = (this.data.tagInput || '').trim();
    if (!raw) return;
    if (raw.length > 10) {
      wx.showToast({ title: '标签最多 10 字', icon: 'none' });
      return;
    }
    const tags = this.data.editForm.tags.slice();
    if (tags.includes(raw)) {
      this.setData({ tagInput: '' });
      return;
    }
    if (tags.length >= TAG_MAX) {
      wx.showToast({ title: `最多 ${TAG_MAX} 个`, icon: 'none' });
      return;
    }
    tags.push(raw);
    this.setData({ tagInput: '' });
    this._commitTags(tags);
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
        avatar: f.avatar || null,
      });
      // 标签走独立覆盖式端点，与基础资料一起存；失败则回滚 saving 并提示，不破坏已存资料
      try {
        await api.put('/api/user/tags', { tags: f.tags || [] });
      } catch (te) {
        this.setData({ saving: false });
        wx.showToast({ title: te.message || '标签保存失败', icon: 'none' });
        return;
      }
      // 本页与全局缓存一起刷新，避免 onShow 时又被旧缓存覆盖
      const merged = { ...updated, tags: (f.tags || []).slice() };
      const me = { ...merged, first: (merged.nickname || '?')[0], avatarUrl: fmt.imgUrl(merged.avatar) };
      getApp().globalData.me = merged;
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
