// 环境配置。
//
// 小程序没有编译期 --dart-define，改用「自动切换 + 本地默认」：
//   开发者工具（模拟器）→ 127.0.0.1，就是这台电脑，简单可靠；
//   真机（预览 / 真机调试）→ 电脑的局域网 IP，因为手机上的 127.0.0.1 指手机自己。
//
// 换 AppID 不影响这里，但真机联调有三件事要一起对上（详见 README「真机联调」）：
//   1) 手机与电脑连同一个 WiFi，且路由器没开「AP 隔离」；
//   2) Windows 防火墙放行后端进程（本机已有 java.exe 的入站放行规则）；
//   3) 预览扫码要在手机上打开「开发调试」，真机调试则默认免校验。

// 电脑的局域网 IP：cmd 执行 ipconfig，找「无线局域网适配器 WLAN」下的 IPv4 地址。
// 换 WiFi / 电脑重启后 IP 变了，改这里。
const LAN_IP = '172.19.234.1';
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
