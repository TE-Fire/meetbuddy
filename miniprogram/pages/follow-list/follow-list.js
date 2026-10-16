// 关注 / 粉丝列表。规则见 docs/13-关注关系.md。
// 入口：他人主页「关注 / 粉丝」计数。tab 切换在两个已存在的接口间切换。
const api = require('../../utils/api');
const fmt = require('../../utils/format');

Page({
  data: {
    id: 0,
    tab: 'following',
    tabs: [
      { k: 'following', l: '关注' },
      { k: 'followers', l: '粉丝' },
    ],
    list: [],
    page: 1,
    size: 20,
    loading: true,
    finished: false,
  },

  onLoad(options) {
    this.setData({
      id: Number(options.id),
      tab: options.tab === 'followers' ? 'followers' : 'following',
    });
    this.load(true);
  },

  switchTab(e) {
    const tab = e.currentTarget.dataset.k;
    if (tab === this.data.tab) return;
    this.setData({ tab });
    this.load(true);
  },

  async load(reset) {
    const page = reset ? 1 : this.data.page;
    this.setData({ loading: true });
    try {
      const res = await api.get(`/api/user/${this.data.id}/${this.data.tab}`, {
        page,
        size: this.data.size,
      });
      const rows = (res.list || []).map((u) => ({
        ...u,
        first: (u.nickname || '?')[0],
        avatarUrl: fmt.imgUrl(u.avatar),
      }));
      this.setData({
        list: reset ? rows : this.data.list.concat(rows),
        page: page + 1,
        finished: rows.length < this.data.size,
        loading: false,
      });
    } catch (e) {
      this.setData({ loading: false });
      wx.showToast({ title: e.message, icon: 'none' });
    }
  },

  onReachBottom() {
    if (!this.data.finished && !this.data.loading) {
      this.load(false);
    }
  },

  openUser(e) {
    wx.navigateTo({ url: `/pages/user-profile/user-profile?id=${e.currentTarget.dataset.id}` });
  },
});
