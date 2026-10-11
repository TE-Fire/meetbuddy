const api = require('../../utils/api');

const app = getApp();

Page({
  data: {
    mode: 'password', // password | sms | register
    phone: '',
    password: '',
    nickname: '',
    code: '',
    countdown: 0,
    error: '',
    busy: false,
    usingMock: false,
  },

  onLoad() {
    this.setData({ usingMock: !!wx.getStorageSync('mb_use_mock') });
    this._timer = null;
  },

  onUnload() {
    if (this._timer) clearInterval(this._timer);
  },

  onPhone(e) {
    this.setData({ phone: e.detail.value, error: '' });
  },
  onPassword(e) {
    this.setData({ password: e.detail.value, error: '' });
  },
  onNickname(e) {
    this.setData({ nickname: e.detail.value, error: '' });
  },
  onCode(e) {
    this.setData({ code: e.detail.value, error: '' });
  },

  switchMode(e) {
    this.setData({ mode: e.currentTarget.dataset.mode, error: '' });
  },

  async sendCode() {
    const { phone, countdown } = this.data;
    if (countdown > 0) return;
    this.setData({ error: '' });
    try {
      await api.post('/api/auth/sms/send', { phone: phone.trim() });
      this.startCountdown();
      wx.showToast({ title: '验证码已发送（开发期固定 123456）', icon: 'none' });
    } catch (e) {
      this.setData({ error: e.message });
    }
  },

  startCountdown() {
    if (this._timer) clearInterval(this._timer);
    this.setData({ countdown: 60 });
    this._timer = setInterval(() => {
      const n = this.data.countdown - 1;
      this.setData({ countdown: n });
      if (n <= 0) clearInterval(this._timer);
    }, 1000);
  },

  async submit() {
    if (this.data.busy) return;
    const { mode, phone, password, nickname, code } = this.data;
    if (phone.trim().length !== 11) {
      this.setData({ error: '请输入 11 位手机号' });
      return;
    }
    this.setData({ busy: true, error: '' });
    try {
      let data;
      if (mode === 'password') {
        data = await api.post('/api/auth/login/password', { phone: phone.trim(), password });
      } else if (mode === 'sms') {
        data = await api.post('/api/auth/sms/login', { phone: phone.trim(), smsCode: code.trim() });
      } else {
        if (!nickname.trim()) {
          this.setData({ error: '给自己起个昵称吧', busy: false });
          return;
        }
        data = await api.post('/api/auth/register', {
          phone: phone.trim(),
          password,
          nickname: nickname.trim(),
          smsCode: code.trim(),
        });
      }
      app.setSession(data.accessToken, data.user || null);
      // 若后端登录响应里没带 user，补拉一次
      if (!app.globalData.me) {
        app.globalData.me = await api.get('/api/user/me');
      }
      wx.reLaunch({ url: '/pages/feed/feed' });
    } catch (e) {
      this.setData({ error: e.message, busy: false });
    }
  },
});
