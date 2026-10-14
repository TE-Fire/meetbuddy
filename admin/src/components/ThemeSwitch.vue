<template>
  <el-popover :width="240" trigger="click" placement="bottom-end">
    <template #reference>
      <el-button circle text class="theme-trigger" v-ripple>
        <el-icon :size="18"><component :is="icon" /></el-icon>
      </el-button>
    </template>

    <div class="theme-panel">
      <div class="tp-title">外观主题</div>
      <div class="seg">
        <button
          v-for="m in modes"
          :key="m.key"
          class="seg-item clickable"
          v-ripple
          :class="{ on: theme.mode === m.key }"
          @click="theme.setMode(m.key)"
        >
          <el-icon><component :is="m.icon" /></el-icon>
          <span>{{ m.label }}</span>
        </button>
      </div>

      <div class="tp-subtitle">品牌色</div>
      <div class="brands">
        <button
          v-for="(b, key) in BRANDS"
          :key="key"
          class="brand-dot clickable"
          v-ripple
          :class="{ on: theme.brand === key }"
          :style="{ background: b.hex }"
          :title="b.name"
          @click="theme.setBrand(key)"
        >
          <el-icon v-if="theme.brand === key"><Check /></el-icon>
        </button>
      </div>
    </div>
  </el-popover>
</template>

<script setup>
import { computed } from 'vue'
import { useThemeStore, BRANDS } from '../stores/theme'
import { Check, Sunny, Moon, Monitor } from '@element-plus/icons-vue'

const theme = useThemeStore()

const modes = [
  { key: 'light', label: '浅色', icon: 'Sunny' },
  { key: 'dark', label: '暗黑', icon: 'Moon' },
  { key: 'system', label: '跟随系统', icon: 'Monitor' }
]

const icon = computed(() =>
  theme.mode === 'dark' ? Moon : theme.mode === 'system' ? Monitor : Sunny
)
</script>

<style scoped>
.theme-trigger { color: var(--text-soft); }
.theme-panel { padding: 4px; }
.tp-title { font-weight: 600; font-size: 14px; margin-bottom: 12px; }
.tp-subtitle { font-size: 12.5px; color: var(--text-soft); margin: 16px 0 10px; }

.seg { display: flex; gap: 8px; }
.seg-item {
  flex: 1; display: flex; flex-direction: column; align-items: center; gap: 5px;
  padding: 10px 0; border: 1px solid var(--border); border-radius: 11px;
  background: var(--panel-2); color: var(--text-soft); font-size: 12.5px;
  transition: all 0.25s var(--ease);
}
.seg-item:hover { transform: translateY(-2px); color: var(--brand); }
.seg-item.on {
  border-color: var(--brand);
  color: var(--brand);
  background: var(--brand-soft);
  box-shadow: 0 0 0 3px var(--brand-soft);
}

.brands { display: flex; gap: 12px; }
.brand-dot {
  width: 30px; height: 30px; border-radius: 50%; border: none;
  color: #fff; display: flex; align-items: center; justify-content: center;
  transition: transform 0.25s var(--ease), box-shadow 0.25s var(--ease);
}
.brand-dot:hover { transform: scale(1.15); }
.brand-dot.on { box-shadow: 0 0 0 3px var(--panel), 0 0 0 5px currentColor; }
</style>
