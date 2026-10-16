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
  lifetimes: {
    // 首帧就按当前路由定好选中态。组件默认 selected=0，若只靠页面 onShow 事后
    // setData，切到第 2/3 个 tab 时会先渲染成"发现"高亮、下一帧才闪一下修正。
    attached() {
      const pages = getCurrentPages();
      const cur = pages[pages.length - 1];
      const route = cur && cur.route ? `/${cur.route}` : '';
      const i = this.data.tabs.findIndex((t) => t.pagePath === route);
      if (i > 0) {
        this.setData({ selected: i });
      }
      this.refreshUnread();
    },
  },
  methods: {
    setSelected(i) {
      this.setData({ selected: i });
      this.refreshUnread();
    },
    refreshUnread() {
      // 徽标 = 聊天未读 + 通知未读，两者分别由 chat-list / notification 页写进全局，
      // 各自只更新自己那一半，避免两个页面互相覆盖。
      const app = getApp();
      const total = (app.globalData.unreadChat || 0) + (app.globalData.unreadNotif || 0);
      this.setData({ unread: total });
    },
    onTap(e) {
      const i = Number(e.currentTarget.dataset.index);
      const tab = this.data.tabs[i];
      if (i === this.data.selected) return;
      wx.switchTab({ url: tab.pagePath });
    },
  },
});
