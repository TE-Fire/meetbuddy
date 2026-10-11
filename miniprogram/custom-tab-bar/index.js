// 自定义底部导航：悬浮黑胶囊条。与 Flutter 端 _NavDock 同款。
// 每个标签页在 onShow 里 setSelected(index) 同步选中态。
Component({
  options: { addGlobalClass: true },
  data: {
    selected: 0,
    unread: 0,
    tabs: [
      { pagePath: '/pages/feed/feed', text: '发现', icon: '🧭' },
      { pagePath: '/pages/chat-list/chat-list', text: '消息', icon: '💬' },
      { pagePath: '/pages/profile/profile', text: '我的', icon: '🙂' },
    ],
  },
  methods: {
    setSelected(i) {
      this.setData({ selected: i });
      this.refreshUnread();
    },
    refreshUnread() {
      // 未读数从全局缓存里取，避免每个 tab 都打一遍接口；
      // chat-list 页每次 onShow 会调 /api/chat/unread 后写回这里。
      const app = getApp();
      this.setData({ unread: app.globalData.unreadTotal || 0 });
    },
    onTap(e) {
      const i = Number(e.currentTarget.dataset.index);
      const tab = this.data.tabs[i];
      if (i === this.data.selected) return;
      wx.switchTab({ url: tab.pagePath });
    },
  },
});
