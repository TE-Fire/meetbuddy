import axios from 'axios'
import { ElMessage } from 'element-plus'

// 同源：开发期经 Vite 代理转发到本地后端 8099，无需 CORS。
const http = axios.create({ baseURL: '', timeout: 15000 })

function getToken() {
  try {
    const raw = localStorage.getItem('mb-auth')
    return raw ? JSON.parse(raw).token : ''
  } catch {
    return ''
  }
}

http.interceptors.request.use((cfg) => {
  const t = getToken()
  if (t) cfg.headers.Authorization = `Bearer ${t}`
  return cfg
})

// 后端统一信封 { code, message, data }，HTTP 恒为 200。
http.interceptors.response.use(
  (resp) => {
    const body = resp.data
    if (body && typeof body.code === 'number') {
      if (body.code === 0) return body.data
      if (body.code === 401) {
        localStorage.removeItem('mb-auth')
        ElMessage.error('登录已过期，请重新登录')
        window.location.href = '/login'
        return Promise.reject(new Error(body.message || 'unauthorized'))
      }
      if (body.code === 403) {
        ElMessage.warning('无权限访问该资源')
        return Promise.reject(new Error(body.message || 'forbidden'))
      }
      ElMessage.error(body.message || '请求失败')
      return Promise.reject(new Error(body.message || 'error'))
    }
    return body
  },
  (err) => {
    ElMessage.error('网络异常，请检查后端是否启动')
    return Promise.reject(err)
  }
)

export default http
