const api = require('../../utils/api');
const socket = require('../../utils/socket');
const fmt = require('../../utils/format');

function decorate(g) {
  return { ...g, agoText: fmt.ago(g.lastMessageAt) };
}

function decorateSession(s) {
  return {
    ...s,
    agoText: fmt.ago(s.lastMessageAt),
    first: (s.peerNickname || '?')[0],
    avatarUrl: fmt.imgUrl(s.peerAvatar),
    // 我发的最后一条加“我:”前缀，对方发的直接显示内容
    lastText: (s.selfLast ? '我: ' : '') + (s.lastMessage || ''),
  };
}

Page({
  data: {
    groups: [],
    sessions: [],
    notifUnread: 0,
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
      // 新消息 / 已读回执刷新会话列表；notify 帧只刷通知未读（列表在通知页自己拉）
      if (frame && (frame.type === 'chat' || frame.type === 'ack')) {
        this.load();
      } else if (frame && frame.type === 'notify') {
        this.loadNotifUnread();
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
      const [groups, sessions] = await Promise.all([
        api.get('/api/chat/groups'),
        api.get('/api/chat/sessions'),
      ]);
      this.setData({
        groups: groups.map(decorate),
        sessions: sessions.map(decorateSession),
        loading: false,
      });
      // 未读总数喂给自定义 tab bar 的徽标（聊天未读单独存，通知未读由通知页维护）
      try {
        const [chatUnread, notifUnread] = await Promise.all([
          api.get('/api/chat/unread'),
          api.get('/api/notification/unread'),
        ]);
        const app = getApp();
        app.globalData.unreadChat = Number(chatUnread) || 0;
        this.setData({ notifUnread: Number(notifUnread) || 0 });
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

  async loadNotifUnread() {
    try {
      const n = await api.get('/api/notification/unread');
      this.setData({ notifUnread: Number(n) || 0 });
      const app = getApp();
      app.globalData.unreadNotif = Number(n) || 0;
      if (typeof this.getTabBar === 'function' && this.getTabBar()) {
        this.getTabBar().refreshUnread();
      }
    } catch (e) {
      /* 忽略：下次 onShow 会纠正 */
    }
  },

  openNotifications() {
    wx.navigateTo({ url: '/pages/notification/notification' });
  },

  openRoom(e) {
    const g = e.currentTarget.dataset.g;
    wx.navigateTo({
      url: `/pages/chat-room/chat-room?groupId=${g.id}&title=${encodeURIComponent(g.name)}`,
    });
  },

  openSession(e) {
    const s = e.currentTarget.dataset.s;
    wx.navigateTo({
      url: `/pages/chat-room/chat-room?peerId=${s.peerId}&title=${encodeURIComponent(s.peerNickname || '私聊')}`,
    });
  },

  /** 私聊头像单可点（catchtap 不冒泡到整行的 openSession），进对方主页 */
  openPeerProfile(e) {
    const id = e.currentTarget.dataset.id;
    if (!id) return;
    wx.navigateTo({ url: `/pages/user-profile/user-profile?id=${id}` });
  },
});
