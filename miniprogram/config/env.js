// 环境配置。
//
// 小程序没有编译期 --dart-define，改用「本地开发默认 + 覆盖文件」：
// 真机调试或换后端地址时，改这一个文件即可。
// 注意：微信开发者工具里需勾选「不校验合法域名」（本地 http/ws 才能通）；
// 正式发布必须换成 https/wss 并在 mp 后台配置 request/socket 合法域名。
module.exports = {
  // 本机后端。真机预览时改成电脑的局域网 IP，例如 http://192.168.1.5:8099
  apiBase: 'http://127.0.0.1:8099',

  get wsBase() {
    return this.apiBase.replace(/^http/, 'ws');
  },
};
