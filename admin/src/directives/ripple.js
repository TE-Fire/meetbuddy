// 呼吸感核心：点击涟漪指令 v-ripple
// 用法：<button v-ripple> 或 <div class="clickable" v-ripple>
// 在指针按下处生成一个扩散圆，0.6s 后淡出。颜色取元素 --ripple 变量。
export const ripple = {
  mounted(el) {
    if (!el.classList.contains('clickable') && getComputedStyle(el).position === 'static') {
      el.style.position = 'relative'
    }
    el.style.overflow = 'hidden'
    el._rippleHandler = (e) => {
      const rect = el.getBoundingClientRect()
      const size = Math.max(rect.width, rect.height)
      const x = (e.clientX ?? rect.left + rect.width / 2) - rect.left - size / 2
      const y = (e.clientY ?? rect.top + rect.height / 2) - rect.top - size / 2
      const span = document.createElement('span')
      span.className = 'ripple'
      span.style.width = span.style.height = size + 'px'
      span.style.left = x + 'px'
      span.style.top = y + 'px'
      el.appendChild(span)
      span.addEventListener('animationend', () => span.remove())
    }
    el.addEventListener('pointerdown', el._rippleHandler)
  },
  unmounted(el) {
    if (el._rippleHandler) el.removeEventListener('pointerdown', el._rippleHandler)
  }
}
