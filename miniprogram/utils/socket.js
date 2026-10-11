// WebSocket 通道。帧协议与后端一致：
//   上行 {type:'chat', groupId, content} / {type:'heartbeat'} / {type:'read', msgId}
//   下行 chat / ack / offline / pong / error
//
// 与 Flutter 端 RealChatSocket 的差异：wx.connectSocket 回调风格不同，这里用
// Promise 包装打开动作；心跳改用 setInterval；重连策略放在页面层（令牌失效重连无意义）。
const { wsBase } = require('../config/env');

let task = null;
let heartbeatTimer = null;
let open = false;

const listeners = { event: [], conn: [] };

function connect(token) {
  return new Promise((resolve, reject) => {
    if (open) {
      resolve();
      return;
    }
    task = wx.connectSocket({ url: `${wsBase}/ws?token=${encodeURIComponent(token)}` });
    let settled = false;

    task.onOpen(() => {
      open = true;
      settled = true;
      startHeartbeat();
      listeners.conn.forEach((fn) => fn(true));
      resolve();
    });
    task.onError((err) => {
      if (!settled) {
        settled = true;
        reject(new Error((err && err.errMsg) || 'WebSocket 连接失败'));
      }
      teardown();
    });
    task.onClose(() => {
      if (open) {
        open = false;
        stopHeartbeat();
        listeners.conn.forEach((fn) => fn(false));
      }
    });
    task.onMessage((res) => {
      let frame = null;
      try {
        frame = JSON.parse(res.data);
      } catch (e) {
        return; // 单帧解析失败丢掉即可
      }
      listeners.event.forEach((fn) => fn(frame));
    });
  });
}

function send(frame) {
  if (!task || !open) return false;
  task.send({ data: JSON.stringify(frame) });
  return true;
}

function sendToGroup(groupId, content) {
  return send({ type: 'chat', groupId, content });
}

function markRead(msgId) {
  return send({ type: 'read', msgId });
}

function startHeartbeat() {
  stopHeartbeat();
  heartbeatTimer = setInterval(() => send({ type: 'heartbeat' }), 30000);
}

function stopHeartbeat() {
  if (heartbeatTimer) {
    clearInterval(heartbeatTimer);
    heartbeatTimer = null;
  }
}

function close() {
  stopHeartbeat();
  if (task) {
    try {
      task.close({ code: 1000 });
    } catch (e) {
      /* 已断开时 close 会抛，忽略 */
    }
  }
  task = null;
  open = false;
}

function teardown() {
  stopHeartbeat();
  task = null;
  open = false;
}

function onEvent(fn) {
  listeners.event.push(fn);
  return () => {
    const i = listeners.event.indexOf(fn);
    if (i >= 0) listeners.event.splice(i, 1);
  };
}

function onConnection(fn) {
  listeners.conn.push(fn);
  return () => {
    const i = listeners.conn.indexOf(fn);
    if (i >= 0) listeners.conn.splice(i, 1);
  };
}

function isConnected() {
  return open;
}

module.exports = { connect, close, sendToGroup, markRead, onEvent, onConnection, isConnected };
