import http from './http'

// ---- 认证（复用用户端登录，管理员身份由 JWT role 区分）----
export function loginByPassword(phone, password) {
  return http.post('/api/auth/login/password', { phone, password })
}

// ---- 看板 ----
export function getDashboard() {
  return http.get('/admin/dashboard')
}

// ---- 活动管理 ----
export function listActivities(params) {
  return http.get('/admin/activity', { params })
}
export function takedownActivity(id, reason) {
  return http.post(`/admin/activity/${id}/takedown`, { reason })
}
export function restoreActivity(id) {
  return http.post(`/admin/activity/${id}/restore`)
}

// ---- 举报处理 ----
export function listReports(params) {
  return http.get('/admin/report', { params })
}
export function handleReport(id, approved, handleResult) {
  return http.post(`/admin/report/${id}/handle`, { approved, handleResult })
}

// ---- 用户管理 ----
export function listUsers(params) {
  return http.get('/admin/user', { params })
}
export function getUserDetail(id) {
  return http.get(`/admin/user/${id}`)
}
export function banUser(id, reason) {
  return http.post(`/admin/user/${id}/ban`, { reason })
}
export function unbanUser(id) {
  return http.post(`/admin/user/${id}/unban`)
}
export function adjustCredit(id, changeValue, reason) {
  return http.post(`/admin/user/${id}/credit`, { changeValue, reason })
}

// ---- 用户端举报入口（M6 决策 3）----
export function submitReport(payload) {
  return http.post('/api/report', payload)
}
