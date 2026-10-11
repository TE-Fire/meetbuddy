const api = require('../../utils/api');
const fmt = require('../../utils/format');

const CATEGORY_ICONS = { 剧本杀: '🎭', 运动: '🏸', 探店: '🍜', 桌游: '🎲', 户外: '⛰️', 观影: '🎬', 其他: '✨' };

function decorate(a) {
  const start = fmt.fmtTime(a.startTime);
  const end = fmt.fmtHm(a.endTime);
  return {
    ...a,
    icon: CATEGORY_ICONS[a.category] || '✨',
    timeText: a.endTime ? `${start} — ${end}` : start,
    statusText: a.statusLabel || a.status,
    statusTone: fmt.statusTone(a.status),
    ratio: a.maxParticipants > 0 ? Math.min(1, a.currentParticipants / a.maxParticipants) : 0,
    full: a.currentParticipants >= a.maxParticipants,
    organizerFirst: a.organizerNickname ? a.organizerNickname[0] : '?',
    slotsLeft: Math.max(0, (a.maxParticipants || 0) - (a.currentParticipants || 0)),
    participants: (a.participants || []).map((p) => ({
      ...p,
      first: (p.nickname || '?')[0],
    })),
  };
}

Page({
  data: {
    a: null,
    error: '',
    loading: true,
    acting: false,
  },

  onLoad(options) {
    this.id = Number(options.id);
  },

  onShow() {
    this.load();
  },

  async load() {
    this.setData({ loading: true, error: '' });
    try {
      const a = await api.get(`/api/activity/${this.id}`);
      this.setData({ a: decorate(a), loading: false });
    } catch (e) {
      this.setData({ error: e.message, loading: false });
    }
  },

  toggleFav() {
    const { a, acting } = this.data;
    if (!a || acting) return;
    const on = !a.favorited;
    this.setData({ acting: true });
    const req = on ? api.post(`/api/activity/${a.id}/favorite`) : api.del(`/api/activity/${a.id}/favorite`);
    req
      .then(() => {
        wx.showToast({ title: on ? '已收藏' : '已取消收藏', icon: 'none' });
        this.load();
      })
      .catch((e) => wx.showToast({ title: e.message, icon: 'none' }))
      .then(() => this.setData({ acting: false }));
  },

  signUp() {
    const { a, acting } = this.data;
    if (!a || acting) return;
    this.setData({ acting: true });
    api
      .post(`/api/activity/${a.id}/signup`, { remark: null })
      .then(() => {
        wx.showToast({ title: '报名成功，已加入群聊', icon: 'none' });
        this.load();
      })
      .catch((e) => wx.showToast({ title: e.message, icon: 'none' }))
      .then(() => this.setData({ acting: false }));
  },

  cancelSignUp() {
    const { a, acting } = this.data;
    if (!a || acting) return;
    wx.showModal({
      title: '取消报名？',
      content: '名额会立刻释放给其他人。',
      confirmText: '取消报名',
      cancelText: '再想想',
      success: (res) => {
        if (!res.confirm) return;
        this.setData({ acting: true });
        api
          .del(`/api/activity/${a.id}/signup`)
          .then(() => {
            wx.showToast({ title: '已取消报名', icon: 'none' });
            this.load();
          })
          .catch((e) => wx.showToast({ title: e.message, icon: 'none' }))
          .then(() => this.setData({ acting: false }));
      },
    });
  },

  cancelActivity() {
    const { a, acting } = this.data;
    if (!a || acting) return;
    wx.showModal({
      title: '取消这个活动？',
      content: '群聊不会被解散，但会转为只读，所有成员会收到通知。',
      confirmText: '确认取消',
      cancelText: '再想想',
      success: (res) => {
        if (!res.confirm) return;
        this.setData({ acting: true });
        api
          .post(`/api/activity/${a.id}/cancel`)
          .then(() => {
            wx.showToast({ title: '活动已取消，群聊转为只读', icon: 'none' });
            this.load();
          })
          .catch((e) => wx.showToast({ title: e.message, icon: 'none' }))
          .then(() => this.setData({ acting: false }));
      },
    });
  },

  openChat() {
    const { a } = this.data;
    if (!a || !a.groupId) return;
    wx.navigateTo({
      url: `/pages/chat-room/chat-room?groupId=${a.groupId}&title=${encodeURIComponent(a.title)}&readonly=${a.status === 'CANCELLED' || a.status === 'FINISHED' ? 1 : 0}`,
    });
  },
});
