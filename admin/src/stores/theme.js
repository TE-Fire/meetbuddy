import { defineStore } from 'pinia'

const BRANDS = {
  sky:   { name: '天空蓝', hex: '#38B2F2' },
  grass: { name: '草地绿', hex: '#2DBE8B' },
  warm:  { name: '暖橙色', hex: '#FF9F43' }
}

function hexToRgb(hex) {
  const h = hex.replace('#', '')
  return [
    parseInt(h.substring(0, 2), 16),
    parseInt(h.substring(2, 4), 16),
    parseInt(h.substring(4, 6), 16)
  ]
}
function mix(hex, target, weight) {
  const [r, g, b] = hexToRgb(hex)
  const [tr, tg, tb] = target
  const m = (c, t) => Math.round(c + (t - c) * weight)
  return `rgb(${m(r, tr)}, ${m(g, tg)}, ${m(b, tb)})`
}
const WHITE = [255, 255, 255]
const BLACK = [0, 0, 0]

// 把品牌色铺成 Element Plus 需要的 9 档主色（primary + light-3/5/7/8/9 + dark-2）
function applyBrand(hex) {
  const root = document.documentElement
  root.style.setProperty('--brand', hex)
  root.style.setProperty('--el-color-primary', hex)
  root.style.setProperty('--el-color-primary-light-3', mix(hex, WHITE, 0.3))
  root.style.setProperty('--el-color-primary-light-5', mix(hex, WHITE, 0.5))
  root.style.setProperty('--el-color-primary-light-7', mix(hex, WHITE, 0.7))
  root.style.setProperty('--el-color-primary-light-8', mix(hex, WHITE, 0.8))
  root.style.setProperty('--el-color-primary-light-9', mix(hex, WHITE, 0.9))
  root.style.setProperty('--el-color-primary-dark-2', mix(hex, BLACK, 0.2))
  // 软色（呼吸光晕用）
  root.style.setProperty('--brand-soft', mix(hex, hex, 0)) // placeholder, replaced below
  root.style.setProperty('--brand-soft', `rgba(${hexToRgb(hex).join(',')}, 0.14)`)
}

export const useThemeStore = defineStore('theme', {
  state: () => {
    let saved = {}
    try { saved = JSON.parse(localStorage.getItem('mb-theme') || '{}') } catch { /* ignore */ }
    return {
      mode: saved.mode || 'light',       // light | dark | system
      brand: saved.brand || 'sky',       // sky | grass | warm
      collapsed: saved.collapsed || false
    }
  },
  getters: {
    isDark(state) {
      if (state.mode === 'dark') return true
      if (state.mode === 'system') return window.matchMedia('(prefers-color-scheme: dark)').matches
      return false
    },
    brandMeta: (state) => BRANDS[state.brand] || BRANDS.sky
  },
  actions: {
    persist() {
      localStorage.setItem('mb-theme', JSON.stringify({
        mode: this.mode, brand: this.brand, collapsed: this.collapsed
      }))
    },
    apply() {
      const dark = this.isDark
      document.documentElement.classList.toggle('dark', dark)
      applyBrand((BRANDS[this.brand] || BRANDS.sky).hex)
      this.persist()
    },
    setMode(mode) { this.mode = mode; this.apply() },
    setBrand(brand) { this.brand = brand; this.apply() },
    toggleCollapsed() { this.collapsed = !this.collapsed; this.persist() },
    init() {
      this.apply()
      // 跟随系统主题变化时实时切换
      window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => {
        if (this.mode === 'system') this.apply()
      })
    }
  }
})

export { BRANDS }
