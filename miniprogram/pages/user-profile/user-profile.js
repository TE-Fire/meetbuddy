// 他人个人主页。规则见 docs/06-成就勋章与个人主页.md 第四节。
// 入口：活动详情的组织者卡 / 已报名人头像、消息页私聊头像。自己点自己也进得来。
const api = require('../../utils/api');
const fmt = require('../../utils/format');

const STATUS_TEXT = {
  OPEN: '报名中', FULL: '已满', ONGOING: '进行中', FINISHED: '已结束', CANCELLED: '已取消',
};

Page({
  data: {
    u: null,
    loading: true,
    acting: false,
  },

  onLoad(options) {
    this.userId = options.id;
    this.load();
  },

  onShow() {
    // 从关注列表返回时刷新计数
    if (this.data.u) this.load();
  },

  async load() {
    try {
      const u = await api.get(`/api/user/${this.userId}/profile`);
      const me = getApp().globalData.me;
      this.setData({
        u: {
          ...u,
          first: (u.nickname || '?')[0],
          avatarUrl: fmt.imgUrl(u.avatar),
          badges: u.badges || [],
          tags: u.tags || [],
          recent: (u.recentActivities || []).map((a) => ({
            ...a,
            cover: fmt.imgUrl(a.coverUrl),
            statusText: STATUS_TEXT[a.status] || a.status,
            timeText: fmt.timeBadge(a.startTime),
            roleText: a.role === 'ORGANIZER' ? '组织' : '参与',
          })),
          self: !!me && me.id === u.userId,
        },
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

  /** 关注 / 取关：乐观更新翻转状态并同步粉丝数，失败再回滚提示 */
  toggleFollow() {
    const { u, acting } = this.data;
    if (!u || acting || u.self) return;
    const on = !u.following;
    const prevCount = u.followerCount || 0;
    this.setData({
      acting: true,
      'u.following': on,
      'u.followerCount': Math.max(0, prevCount + (on ? 1 : -1)),
    });
    const req = on
      ? api.post(`/api/user/${u.userId}/follow`)
      : api.del(`/api/user/${u.userId}/follow`);
    req
      .then(() => wx.showToast({ title: on ? '已关注' : '已取消关注', icon: 'none' }))
      .catch((e) => {
        // 回滚
        this.setData({ 'u.following': !on, 'u.followerCount': prevCount });
        wx.showToast({ title: e.message, icon: 'none' });
      })
      .then(() => this.setData({ acting: false }));
  },

  /** 关注 / 粉丝列表 */
  openFollowList(e) {
    const tab = e.currentTarget.dataset.tab || 'following';
    wx.navigateTo({ url: `/pages/follow-list/follow-list?id=${this.userId}&tab=${tab}` });
  },
});
