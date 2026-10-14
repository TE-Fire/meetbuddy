import { defineStore } from 'pinia'
import { loginByPassword } from '../api/admin'

export const useAuthStore = defineStore('auth', {
  state: () => {
    let token = ''
    let user = null
    try {
      const raw = localStorage.getItem('mb-auth')
      if (raw) { const p = JSON.parse(raw); token = p.token || ''; user = p.user || null }
    } catch { /* ignore */ }
    return { token, user }
  },
  getters: {
    isLoggedIn: (s) => !!s.token,
    isAdmin: (s) => s.user && s.user.role === 1
  },
  actions: {
    persist() {
      localStorage.setItem('mb-auth', JSON.stringify({ token: this.token, user: this.user }))
    },
    setToken(token) { this.token = token; this.persist() },
    setUser(user) { this.user = user; this.persist() },
    async login(phone, password) {
      const data = await loginByPassword(phone, password)
      this.token = data.accessToken
      this.user = data.user
      this.persist()
      return data.user
    },
    logout() {
      this.token = ''
      this.user = null
      localStorage.removeItem('mb-auth')
    }
  }
})
