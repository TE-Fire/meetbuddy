// 统一请求层。只管三件事：拼 URL、注入 Bearer、拆统一信封。
// 契约与 Flutter 端 ApiClient 一致：HTTP 状态码只表达传输层，业务成败看 code。
const { apiBase } = require('../config/env');

const TOKEN_KEY = 'mb_token';

function getToken() {
  return wx.getStorageSync(TOKEN_KEY) || '';
}

function setToken(token) {
  if (token) {
    wx.setStorageSync(TOKEN_KEY, token);
  } else {
    wx.removeStorageSync(TOKEN_KEY);
  }
}

/**
 * 发请求。resolve 业务数据（envelope.data），reject { code, message }。
 * 网络层失败 code 统一 -1。
 */
function request(method, path, { body, query } = {}) {
  let url = apiBase + path;
  if (query) {
    const qs = Object.keys(query)
      .filter((k) => query[k] !== undefined && query[k] !== null && query[k] !== '')
      .map((k) => `${encodeURIComponent(k)}=${encodeURIComponent(query[k])}`)
      .join('&');
    if (qs) url += `?${qs}`;
  }

  return new Promise((resolve, reject) => {
    wx.request({
      url,
      method,
      data: body,
      timeout: 15000,
      header: {
        'Content-Type': 'application/json; charset=utf-8',
        Accept: 'application/json',
        Authorization: getToken() ? `Bearer ${getToken()}` : '',
      },
      success(res) {
        const envelope = res.data;
        if (!envelope || typeof envelope !== 'object' || typeof envelope.code === 'undefined') {
          reject({ code: -1, message: `响应不是合法信封（HTTP ${res.statusCode}）` });
          return;
        }
        if (envelope.code !== 0) {
          reject({ code: envelope.code, message: envelope.message || '请求失败' });
          return;
        }
        resolve(envelope.data);
      },
      fail(err) {
        reject({ code: -1, message: `连不上后端 ${apiBase}：${err.errMsg || ''}` });
      },
    });
  });
}

const get = (path, query) => request('GET', path, { query });
const post = (path, body) => request('POST', path, { body });
const put = (path, body) => request('PUT', path, { body });
const del = (path, body) => request('DELETE', path, { body });

module.exports = { request, get, post, put, del, getToken, setToken, TOKEN_KEY };
