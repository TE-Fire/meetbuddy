// 通知列表页。规则见 docs/05-通知与提醒.md。
// 三种类型：SIGNUP_NEW（有人报名，组织者视角）/ ACTIVITY_CANCELLED（活动被取消，参与者视角）
// / ACTIVITY_REMINDER（开始前提醒）。都带 bizId，点击跳活动详情。
const api = require('../../utils/api');
const socket = require('../../utils/socket');
const fmt = require('../../utils/format');

const TYPE_META = {
  SIGNUP_NEW: { icon: '🙋', tint: 'grass' },
  ACTIVITY_CANCELLED: { icon: '🚫', tint: 'warm' },
  ACTIVITY_REMINDER: { icon: '⏰', tint: 'sky' },
  ACTIVITY_TAKEDOWN: { icon: '🛑', tint: 'warm' },
  REPORT_HANDLED: { icon: '📋', tint: 'sky' },
  BADGE_UNLOCKED: { icon: '🎖️', tint: 'warm' },
  USER_FOLLOWED: { icon: '👥', tint: 'sky' },
};

// 活动类通知跳活动详情；USER_FOLLOWED 跳关注你的人的主页；其余（如 REPORT_HANDLED）不可跳
const ACTIVITY_TYPES = ['SIGNUP_NEW', 'ACTIVITY_CANCELLED', 'ACTIVITY_REMINDER', 'ACTIVITY_TAKEDOWN'];
const USER_TYPES = ['USER_FOLLOWED'];

function decorate(n) {
  const meta = TYPE_META[n.type] || { icon: '🔔', tint: 'plain' };
  return {
    ...n,
    icon: meta.icon,
    tint: meta.tint,
    // 只有活动类通知跳活动详情
    jumpable: !!n.bizId && ACTIVITY_TYPES.indexOf(n.type) >= 0,
    // USER_FOLLOWED 的 bizId 是关注者 id，点了跳对方主页
    userJumpable: !!n.bizId && USER_TYPES.indexOf(n.type) >= 0,
    agoText: fmt.ago(n.createdAt),
  };
}

Page({
  data: {
    list: [],
    unread: 0,
    page: 1,
    size: 20,
    loading: true,
    finished: false,
  },

  onShow() {
    // 从详情页返回时要刷新已读态，所以放在 onShow 而不是 onLoad
    this.setData({ page: 1, finished: false });
    this.load();
    // 后端有新通知时会推 notify 帧，页面在前台就地刷新
    this._offEvent = socket.onEvent((frame) => {
      if (frame && frame.type === 'notify') {
        this.setData({ page: 1, finished: false });
        this.load();
      }
    });
  },

  onHide() {
    if (this._offEvent) this._offEvent();
  },

  async load() {
    const { page, size } = this.data;
    try {
      // 列表与未读数分两个接口：PageVO 不带统计字段（与 chat-list 同款口径）
      const [res, unread] = await Promise.all([
        api.get('/api/notification', { page, size }),
        api.get('/api/notification/unread'),
      ]);
      const rows = (res.list || []).map(decorate);
      this.setData({
        list: page === 1 ? rows : this.data.list.concat(rows),
        unread: Number(unread) || 0,
        loading: false,
        finished: rows.length < size,
        page: page + 1,
      });
      // 回写全局未读，让消息 tab 的徽标与这里一致
      this._syncGlobalUnread();
    } catch (e) {
      this.setData({ loading: false });
      wx.showToast({ title: e.message, icon: 'none' });
    }
  },

  _syncGlobalUnread() {
    // 通知未读单独存一份，tab bar 徽标 = 聊天未读 + 通知未读（见 custom-tab-bar）
    const app = getApp();
    app.globalData.unreadNotif = this.data.unread;
    if (typeof this.getTabBar === 'function' && this.getTabBar()) {
      this.getTabBar().refreshUnread();
    }
  },

  onReachBottom() {
    if (!this.data.finished && !this.data.loading) {
      this.load();
    }
  },

  async tapItem(e) {
    const n = e.currentTarget.dataset.n;
    // 未读的先标已读，失败不拦跳转（红点下次进页面自愈）
    if (!n.readStatus) {
      try {
        await api.post(`/api/notification/${n.id}/read`);
      } catch (err) {
        /* 忽略：已读状态下次加载会纠正 */
      }
      const list = this.data.list.map((x) => (x.id === n.id ? { ...x, readStatus: 1 } : x));
      const unread = Math.max(0, this.data.unread - 1);
      this.setData({ list, unread });
      this._syncGlobalUnread();
    }
    if (n.jumpable) {
      wx.navigateTo({ url: `/pages/detail/detail?id=${n.bizId}` });
    } else if (n.userJumpable) {
      wx.navigateTo({ url: `/pages/user-profile/user-profile?id=${n.bizId}` });
    }
  },

  async markAll() {
    try {
      await api.post('/api/notification/read-all');
      const list = this.data.list.map((x) => ({ ...x, readStatus: 1 }));
      this.setData({ list, unread: 0 });
      this._syncGlobalUnread();
      wx.showToast({ title: '已全部标为已读', icon: 'success' });
    } catch (e) {
      wx.showToast({ title: e.message, icon: 'none' });
    }
  },
});
