const api = require('../../utils/api');
const socket = require('../../utils/socket');
const fmt = require('../../utils/format');

Page({
  data: {
    groupId: 0,
    peerId: 0,
    peerName: '',
    title: '',
    readonly: false,
    connected: false,
    messages: [],
    input: '',
    sending: false,
    scrollInto: '',
  },

  onLoad(options) {
    // 两种模式：groupId 群聊 / peerId 单聊。搭子匹配页的「私聊 TA」走后者，
    // 后端 sendToUser 链路早已就绪，这里只补前端入口
    const peerId = Number(options.peerId || 0);
    this.setData({
      groupId: Number(options.groupId || 0),
      peerId,
      peerName: decodeURIComponent(options.peerName || ''),
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
      // 单聊走 session 接口，群聊走 group 接口；两者返回同一结构
      const path = this.data.peerId
        ? `/api/chat/session/${this.data.peerId}/messages`
        : `/api/chat/group/${this.data.groupId}/messages`;
      const data = await api.get(path, { size: 50 });
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
    } else if (frame.type === 'chat' && frame.message && this.data.peerId
        && frame.message.receiverId === myId && frame.message.senderId === this.data.peerId) {
      // 单聊只推给接收方，自己发的走 ack 确认，不会重复
      const m = this.decorate(frame.message, myId);
      const messages = this.data.messages.concat(m);
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
      receiverId: this.data.peerId || undefined,
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
    const ok = this.data.peerId
      ? socket.sendToUser(this.data.peerId, content)
      : socket.sendToGroup(this.data.groupId, content);
    if (!ok) {
      wx.showToast({ title: '连接已断开，返回消息页重连', icon: 'none' });
    }
  },
});
