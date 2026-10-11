const api = require('../../utils/api');
const socket = require('../../utils/socket');
const fmt = require('../../utils/format');

function decorate(g) {
  return { ...g, agoText: fmt.ago(g.lastMessageAt) };
}

Page({
  data: {
    groups: [],
    loading: true,
    connected: false,
  },

  onShow() {
    if (typeof this.getTabBar === 'function' && this.getTabBar()) {
      this.getTabBar().setSelected(1);
    }
    if (!getApp().isLoggedIn()) {
      wx.reLaunch({ url: '/pages/login/login' });
      return;
    }
    this.load();
    this._offConn = socket.onConnection((on) => this.setData({ connected: on }));
    this._offEvent = socket.onEvent((frame) => {
      // 新消息 / 已读回执都刷新一遍列表，口径简单、代价可接受
      if (frame && (frame.type === 'chat' || frame.type === 'ack')) {
        this.load();
      }
    });
    this.setData({ connected: socket.isConnected() });
  },

  onHide() {
    if (this._offConn) this._offConn();
    if (this._offEvent) this._offEvent();
  },

  async load() {
    try {
      const groups = await api.get('/api/chat/groups');
      this.setData({ groups: groups.map(decorate), loading: false });
      // 未读总数喂给自定义 tab bar 的徽标
      try {
        const n = await api.get('/api/chat/unread');
        getApp().globalData.unreadTotal = Number(n) || 0;
        if (typeof this.getTabBar === 'function' && this.getTabBar()) {
          this.getTabBar().refreshUnread();
        }
      } catch (e) {
        /* 未读接口失败不影响列表展示 */
      }
    } catch (e) {
      this.setData({ loading: false });
      wx.showToast({ title: e.message, icon: 'none' });
    }
  },

  openRoom(e) {
    const g = e.currentTarget.dataset.g;
    wx.navigateTo({
      url: `/pages/chat-room/chat-room?groupId=${g.id}&title=${encodeURIComponent(g.name)}`,
    });
  },
});
