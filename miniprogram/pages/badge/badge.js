// 我的勋章墙。规则见 docs/06-成就勋章与个人主页.md。
// 后端返回全部徽章（含未解锁），未解锁的按 group 决定是否显示进度条：
// NONE 组是"首次"型一次性徽章，只显示"未解锁"；其余组显示 n/target。
const api = require('../../utils/api');
const fmt = require('../../utils/format');

Page({
  data: {
    badges: [],
    earned: 0,
    total: 0,
    loading: true,
  },

  onLoad() {
    this.load();
  },

  async load() {
    try {
      const list = await api.get('/api/badge/mine');
      const rows = (list || []).map((b) => ({
        ...b,
        dateText: b.unlocked ? fmt.fmtTime(b.unlockedAt) : '',
        // NONE 组不展示进度；FULL 组 target=1 也要展示 0/1
        showProgress: !b.unlocked && b.group !== 'NONE',
        pct: b.target > 0 ? Math.min(100, Math.round((b.progress / b.target) * 100)) : 0,
      }));
      this.setData({
        badges: rows,
        earned: rows.filter((b) => b.unlocked).length,
        total: rows.length,
        loading: false,
      });
    } catch (e) {
      this.setData({ loading: false });
      wx.showToast({ title: e.message, icon: 'none' });
    }
  },

  onPullDownRefresh() {
    this.load().then(() => wx.stopPullDownRefresh());
  },
});
