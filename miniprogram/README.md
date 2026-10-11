# meetbuddy 微信小程序端

与 Flutter 用户端共用同一个后端（`server/`，默认 `http://127.0.0.1:8099`），完整覆盖
「密码/验证码登录 → 发现活动流 → 活动详情/报名 → 发布组局 → 群聊（WebSocket 实时）→ 我的」主链路。

## 视觉

与移动端 v2 方向稿同源（参照「圆周旅迹」风格）：天空蓝 `#38B2F2` + 草地绿 `#C4ECA6`
+ 黑胶囊主按钮 `#171A1D` + 大圆角白卡 + 地图化插画（草地形 / 蓝色虚线路线 / 白图钉 / 贴纸）。
设计令牌集中在 `app.wxss` 的 `page` 选择器里，组件只用类名。

## 运行

1. 用微信开发者工具「导入项目」选择本目录（`miniprogram/`）。
2. 详情 → 本地设置 → 勾选 **不校验合法域名**（本地 http/ws 才能通）。
3. 后端地址在 `config/env.js` 的 `apiBase`：
   - 模拟器里用 `http://127.0.0.1:8099`；
   - 真机预览改成电脑局域网 IP（如 `http://192.168.1.5:8099`）。
4. 正式发布前：换成 https/wss 域名，并在 mp 后台配置 request / socket 合法域名。

## 结构

```
config/env.js          后端地址（唯一需要改的地方）
utils/api.js           统一请求层：拼 URL、注入 Bearer、拆 {code,message,data} 信封
utils/socket.js        WebSocket 通道：ws://…/ws?token=，30s 心跳，chat/ack/offline/error 帧分发
utils/format.js        时间徽标 / 相对时间 / 距离等展示口径（与 Flutter 端一致）
components/map-scene/  地图插画组件（纯 CSS + base64 SVG 虚线路线）
custom-tab-bar/        自定义黑胶囊底部导航（发现 / 消息 / 我的）
pages/login            登录（密码 / 验证码 / 注册）
pages/feed             发现：分类 chips + 活动卡（地图封面 + 名额进度）
pages/detail           详情：信息卡 + 报名/取消 + 群聊入口（悬浮报名条）
pages/create           发布：分卡表单 + 标签选择（地标下拉决定经纬度）
pages/chat-list        消息列表（未读徽标喂给自定义 tab bar）
pages/chat-room        群聊：乐观发送 + ack 确认 + 只读降级（错误码 3104）
pages/profile          我的：数据卡 + 我发起的 / 我报名的
```

## 与 Flutter 端的已知差异

- 登录没有「微信一键登录」按钮：后端还没有微信 code 换登录态的接口，放一个假按钮是骗人，等后端支持后再加。
- 发布页的时间选择用一次可编辑弹窗（格式 `10月17日 14:00`，留空用默认值），
  替代小程序原生"日期 + 时间"两次弹窗，减少打断；解析失败自动回落默认时间。
- 发布页的人数/信用分用步进器（小程序 slider 在真机上的触达体验一般）。
- 就近筛选固定演示坐标（北京国贸），与 Flutter 端一致。

## 约定

- 页面永远不碰 `code`：`utils/api.js` 里非 0 一律 reject `{code, message}`，页面只管提示。
- tab 页 `onShow` 里先做登录守卫（未登录 `reLaunch` 到登录页），再 `setSelected(n)` 同步底部导航。
- WS 连接生命周期只在 `app.js` 管理，页面只订阅事件。
