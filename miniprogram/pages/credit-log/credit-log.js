const api = require('../../utils/api');
const fmt = require('../../utils/format');

// 规则说明文案：把"分从哪来、到哪去"一次讲清，少一半客服提问。
const RULES = [
  '新用户初始 100 分，正常履约不掉分；',
  '报名未取消且未出席，扣 10 分；',
  '发布违规活动被举报成立，扣 30 分；',
  '被他人举报且查实，扣 20 分；',
  '信用分低于活动门槛时将无法报名该活动。',
];

function mapLog(l) {
  return {
    ...l,
    plus: (l.changeValue || 0) > 0,
    timeText: fmt.fmtTime(l.createdAt),
  };
}

Page({
  data: {
    score: null,
    logs: [],
    page: 1,
    hasMore: false,
    loading: false,
    rules: RULES,
  },

  onLoad() {
    const app = getApp();
    const me = app.globalData.me;
    this.setData({ score: me ? me.creditScore : null });
    this.load(true);
  },

  async load(reset) {
    if (this.data.loading) return;
    const page = reset ? 1 : this.data.page + 1;
    this.setData({ loading: true });
    try {
      const data = await api.get('/api/user/credit/logs', { page, size: 20 });
      const items = (data.list || []).map(mapLog);
      this.setData({
        logs: reset ? items : this.data.logs.concat(items),
        page,
        hasMore: items.length >= 20,
        loading: false,
      });
    } catch (e) {
      this.setData({ loading: false });
      wx.showToast({ title: e.message, icon: 'none' });
    }
  },

  onReachBottom() {
    if (this.data.hasMore && !this.data.loading) {
      this.load(false);
    }
  },

  onPullDownRefresh() {
    this.load(true).then(() => wx.stopPullDownRefresh());
  },
});
