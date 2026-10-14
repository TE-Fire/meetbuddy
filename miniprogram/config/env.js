// 环境配置。
//
// 小程序没有编译期 --dart-define，改用「自动切换 + 本地默认」：
//   开发者工具（模拟器）→ 127.0.0.1，就是这台电脑，简单可靠；
//   真机（预览 / 真机调试）→ 电脑的局域网 IP，因为手机上的 127.0.0.1 指手机自己。
//
// 换 AppID 不影响这里，但真机联调有三件事要一起对上（详见 README「真机联调」）：
//   1) 手机与电脑要在同一局域网，且是微信认可的那种。最稳的是都连同一个路由器 WiFi，
//      或「电脑开热点、手机连」。反过来「手机开热点、电脑连热点」时，手机自身网络类型
//      是蜂窝流量，微信常判定为"不在局域网"，IP 型 URL 会被直接拦下（ping 通也没用）；
//   2) Windows 防火墙放行后端进程（本机已有 java.exe 的入站放行规则）；
//   3) 工具「详情 → 本地设置」要勾上「不校验合法域名」——默认可能是关的，
//      模拟器 / 预览 / 真机调试都依赖它，没勾 http+IP 就发不出去。

// 电脑的局域网 IP：cmd 执行 ipconfig，找「无线局域网适配器 WLAN」下的 IPv4 地址。
// 换 WiFi / 电脑重启后 IP 变了，改这里。
// 2026-10-13 22:26 实测 WLAN = 10.24.119.1（电脑当前所连 WiFi 网段）。
const LAN_IP = '10.24.119.1';
const PORT = 8099;

// 只有模拟器用 127.0.0.1；拿不到环境信息时按模拟器兜底（至少本机可通）。
const IS_DEVTOOLS = (() => {
  try {
    return wx.getSystemInfoSync().platform === 'devtools';
  } catch (e) {
    return true;
  }
})();

const apiBase = `http://${IS_DEVTOOLS ? '127.0.0.1' : LAN_IP}:${PORT}`;

console.log(`[env] apiBase = ${apiBase}（${IS_DEVTOOLS ? '模拟器' : '真机'}）`);

module.exports = {
  LAN_IP,
  PORT,
  apiBase,
  get wsBase() {
    return this.apiBase.replace(/^http/, 'ws');
  },
};
