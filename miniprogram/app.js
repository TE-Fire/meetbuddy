// 全局状态：登录态恢复 + WS 连接生命周期。
// 与 Flutter 端 _RootGate 同一职责：全 App 唯一知道"登录态变了要重连 WS"的地方。
const api = require('./utils/api');
const socket = require('./utils/socket');

App({
  globalData: {
    me: null,
    connected: false,
    // tab 徽标 = 聊天未读 + 通知未读，分别由 chat-list / notification 页维护
    unreadChat: 0,
    unreadNotif: 0,
  },

  onLaunch() {
    this.restore();
  },

  /** 本地有令牌就先当已登录，再拉 /api/user/me 校验；令牌失效则清掉。 */
  async restore() {
    const token = api.getToken();
    if (!token) return;
    try {
      const me = await api.get('/api/user/me');
      this.globalData.me = me;
      this.connectSocket(token);
    } catch (e) {
      api.setToken('');
      this.globalData.me = null;
    }
  },

  isLoggedIn() {
    return !!this.globalData.me && !!api.getToken();
  },

  setSession(token, me) {
    api.setToken(token);
    this.globalData.me = me;
    this.connectSocket(token);
  },

  connectSocket(token) {
    socket
      .connect(token)
      .then(() => {
        this.globalData.connected = true;
      })
      .catch(() => {
        this.globalData.connected = false;
      });
  },

  async logout() {
    try {
      await api.post('/api/auth/logout');
    } catch (e) {
      /* 后端不可达也要把本地清干净 */
    }
    api.setToken('');
    this.globalData.me = null;
    socket.close();
  },
});
