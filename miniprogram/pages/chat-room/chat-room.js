const api = require('../../utils/api');
const socket = require('../../utils/socket');
const fmt = require('../../utils/format');

Page({
  data: {
    groupId: 0,
    title: '',
    readonly: false,
    connected: false,
    messages: [],
    input: '',
    sending: false,
    scrollInto: '',
  },

  onLoad(options) {
    this.setData({
      groupId: Number(options.groupId),
      title: decodeURIComponent(options.title || ''),
      readonly: options.readonly === '1',
    });
    wx.setNavigationBarTitle({ title: decodeURIComponent(options.title || '') });
  },

  onReady() {
    this._offConn = socket.onConnection((on) => this.setData({ connected: on }));
    this._offEvent = socket.onEvent((frame) => this.onFrame(frame));
    this.setData({ connected: socket.isConnected() });
    this.loadHistory();
  },

  onUnload() {
    if (this._offConn) this._offConn();
    if (this._offEvent) this._offEvent();
  },

  async loadHistory() {
    try {
      const data = await api.get(`/api/chat/group/${this.data.groupId}/messages`, { size: 50 });
      const me = getApp().globalData.me;
      const raw = (data && data.list) || [];
      const messages = raw
        .map((m) => this.decorate(m, me ? me.id : -1))
        .filter((m) => !m.isSystem);
      // 进群把最后一条标为已读（后端按 msgId 记已读水位）
      const last = raw.length ? raw[raw.length - 1] : null;
      if (last) socket.markRead(last.id);
      this.setData({ messages, scrollInto: messages.length ? `m${messages.length - 1}` : '' });
    } catch (e) {
      wx.showToast({ title: e.message, icon: 'none' });
    }
  },

  decorate(m, myId) {
    return {
      ...m,
      mine: m.senderId === myId,
      isSystem: m.msgType === 'SYSTEM',
      hm: fmt.fmtHm(m.createdAt),
      sender: m.senderNickname || '匿名用户',
      first: (m.senderNickname || '?')[0],
    };
  },

  onFrame(frame) {
    if (!frame) return;
    const me = getApp().globalData.me;
    const myId = me ? me.id : -1;
    if (frame.type === 'chat' && frame.message && frame.message.groupId === this.data.groupId) {
      const m = this.decorate(frame.message, myId);
      const messages = this.data.messages.filter((x) => !x.pending || x.content !== m.content).concat(m);
      this.setData({ messages, scrollInto: `m${messages.length - 1}` });
      socket.markRead(m.id);
    } else if (frame.type === 'ack') {
      // 已落库：把最后一条还在 pending 的自己的消息标成已确认
      const messages = this.data.messages.slice();
      for (let i = messages.length - 1; i >= 0; i--) {
        if (messages[i].mine && messages[i].pending) {
          messages[i] = { ...messages[i], pending: false };
          break;
        }
      }
      this.setData({ messages });
    } else if (frame.type === 'error') {
      wx.showToast({ title: frame.errorMessage || '发送失败', icon: 'none' });
      // 3104 只读：同步置灰输入框
      if (frame.code === 3104) {
        this.setData({ readonly: true });
      }
      const messages = this.data.messages.slice();
      for (let i = messages.length - 1; i >= 0; i--) {
        if (messages[i].mine && messages[i].pending) {
          messages[i] = { ...messages[i], pending: false, failed: true };
          break;
        }
      }
      this.setData({ messages });
    }
  },

  onInput(e) {
    this.setData({ input: e.detail.value });
  },

  send() {
    const content = this.data.input.trim();
    if (!content || this.data.readonly) return;
    const me = getApp().globalData.me;
    const optimistic = {
      id: -Date.now(),
      groupId: this.data.groupId,
      senderId: me ? me.id : -1,
      senderNickname: me ? me.nickname : '',
      content,
      msgType: 'TEXT',
      createdAt: new Date().toISOString(),
      mine: true,
      pending: true,
      hm: '',
    };
    const messages = this.data.messages.concat(optimistic);
    this.setData({ messages, input: '', scrollInto: `m${messages.length - 1}` });
    const ok = socket.sendToGroup(this.data.groupId, content);
    if (!ok) {
      wx.showToast({ title: '连接已断开，返回消息页重连', icon: 'none' });
    }
  },
});
