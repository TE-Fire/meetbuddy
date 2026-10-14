<template>
  <div class="dash">
    <!-- 核心数字卡 -->
    <div class="stat-row">
      <div v-for="(s, i) in stats" :key="i" class="stat-card panel lift" :class="s.grad">
        <div class="stat-icon"><el-icon :size="22"><component :is="s.icon" /></el-icon></div>
        <div class="stat-body">
          <div class="stat-num grad-text">{{ s.value }}</div>
          <div class="stat-label">{{ s.label }}</div>
        </div>
      </div>
    </div>

    <div class="grid">
      <div class="panel chart-card">
        <div class="card-head">
          <span class="card-title">近 7 天趋势</span>
          <span class="card-tip">新增活动 / 报名 / 消息</span>
        </div>
        <div ref="trendEl" class="chart"></div>
      </div>

      <div class="panel chart-card">
        <div class="card-head"><span class="card-title">活动分类分布</span></div>
        <div ref="catEl" class="chart"></div>
      </div>
    </div>

    <div class="panel chart-card">
      <div class="card-head">
        <span class="card-title">用户地域分布</span>
        <span class="card-tip">按最近坐标就近归类到预设城市围栏</span>
      </div>
      <div class="region">
        <div v-for="r in regions" :key="r.region" class="region-item">
          <span class="region-name">{{ r.region }}</span>
          <div class="region-bar"><div class="region-fill" :style="{ width: pct(r.count) + '%' }"></div></div>
          <span class="region-num">{{ r.count }}</span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onBeforeUnmount, watch, computed } from 'vue'
import * as echarts from 'echarts'
import { getDashboard } from '../api/admin'
import { useThemeStore } from '../stores/theme'
import { User, Calendar, Promotion, Warning } from '@element-plus/icons-vue'

const theme = useThemeStore()
const data = ref(null)
const trendEl = ref(null)
const catEl = ref(null)
let trendChart = null
let catChart = null

const stats = computed(() => [
  { label: '用户总数', value: data.value?.totalUsers ?? '—', grad: 'grad-sky', icon: 'User' },
  { label: '活动总数', value: data.value?.totalActivities ?? '—', grad: 'grad-grass', icon: 'Calendar' },
  { label: '进行中（未下架）', value: data.value?.openActivities ?? '—', grad: 'grad-violet', icon: 'Promotion' },
  { label: '待处理举报', value: data.value?.pendingReports ?? '—', grad: 'grad-warm', icon: 'Warning' }
])
const regions = computed(() => data.value?.regions || [])
const maxRegion = computed(() => Math.max(1, ...regions.value.map((r) => r.count)))
function pct(c) { return Math.round((c / maxRegion.value) * 100) }

function brand() {
  return getComputedStyle(document.documentElement).getPropertyValue('--brand').trim() || '#38B2F2'
}
function textColor() {
  return getComputedStyle(document.documentElement).getPropertyValue('--text-soft').trim() || '#6b7a90'
}

function renderTrend() {
  if (!trendEl.value || !data.value) return
  const t = data.value.trend || []
  const dates = t.map((d) => d.date)
  trendChart = echarts.init(trendEl.value)
  trendChart.setOption({
    color: [brand(), '#2DBE8B', '#FF9F43'],
    tooltip: { trigger: 'axis' },
    legend: { data: ['活动', '报名', '消息'], textStyle: { color: textColor() }, right: 10, top: 0 },
    grid: { left: 40, right: 20, top: 40, bottom: 30 },
    xAxis: { type: 'category', data: dates, axisLine: { lineStyle: { color: textColor() } }, axisLabel: { color: textColor() } },
    yAxis: { type: 'value', splitLine: { lineStyle: { color: 'rgba(128,128,128,0.15)' } }, axisLabel: { color: textColor() } },
    series: [
      mkLine('活动', t.map((d) => d.activityCount), 0.35),
      mkLine('报名', t.map((d) => d.signupCount), 0.35),
      mkLine('消息', t.map((d) => d.messageCount), 0.35)
    ]
  })
}
function mkLine(name, vals, op) {
  return {
    name, type: 'line', smooth: true, symbol: 'circle', symbolSize: 7, data: vals,
    lineStyle: { width: 3 },
    areaStyle: {
      opacity: op,
      color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
        { offset: 0, color: brand() }, { offset: 1, color: 'rgba(255,255,255,0)' }
      ])
    }
  }
}
function renderCat() {
  if (!catEl.value || !data.value) return
  const c = data.value.categories || []
  catChart = echarts.init(catEl.value)
  catChart.setOption({
    tooltip: { trigger: 'item' },
    legend: { bottom: 0, textStyle: { color: textColor() } },
    color: ['#38B2F2', '#2DBE8B', '#FF9F43', '#8B7CF6', '#FF6B9A', '#36CFC9'],
    series: [{
      type: 'pie', radius: ['42%', '70%'], center: ['50%', '45%'],
      avoidLabelOverlap: true, itemStyle: { borderRadius: 8, borderColor: 'var(--panel)', borderWidth: 2 },
      label: { color: textColor() },
      data: c.map((x) => ({ name: x.category, value: x.count }))
    }]
  })
}

async function load() {
  data.value = await getDashboard()
  renderTrend()
  renderCat()
}

function resize() { trendChart?.resize(); catChart?.resize() }
onMounted(() => { load(); window.addEventListener('resize', resize) })
onBeforeUnmount(() => { window.removeEventListener('resize', resize); trendChart?.dispose(); catChart?.dispose() })

// 换肤时重绘配色
watch(() => [theme.brand, theme.mode], () => { renderTrend(); renderCat() })
</script>

<style scoped>
.dash { display: flex; flex-direction: column; gap: 18px; }
.stat-row { display: grid; grid-template-columns: repeat(4, 1fr); gap: 18px; }
.stat-card {
  display: flex; align-items: center; gap: 16px; padding: 20px 22px; border-radius: 16px;
}
.stat-icon {
  width: 50px; height: 50px; border-radius: 14px; flex: none;
  background: rgba(255, 255, 255, 0.22); color: #fff;
  display: flex; align-items: center; justify-content: center;
}
.stat-num { font-size: 30px; font-weight: 800; line-height: 1; }
.stat-label { font-size: 13px; color: rgba(255, 255, 255, 0.85); margin-top: 6px; }

.grid { display: grid; grid-template-columns: 1.6fr 1fr; gap: 18px; }
.chart-card { padding: 18px 20px; border-radius: 16px; }
.card-head { display: flex; align-items: baseline; justify-content: space-between; margin-bottom: 8px; }
.card-title { font-size: 16px; font-weight: 700; }
.card-tip { font-size: 12px; color: var(--text-soft); }
.chart { width: 100%; height: 300px; }

.region { display: flex; flex-direction: column; gap: 14px; padding: 6px 4px; }
.region-item { display: flex; align-items: center; gap: 14px; }
.region-name { width: 48px; font-size: 14px; color: var(--text); }
.region-bar { flex: 1; height: 12px; border-radius: 8px; background: var(--panel-2); overflow: hidden; }
.region-fill {
  height: 100%; border-radius: 8px;
  background: linear-gradient(90deg, var(--brand), #6FD0FF);
  transition: width 0.9s var(--ease);
}
.region-num { width: 36px; text-align: right; font-weight: 700; color: var(--brand); }

@media (max-width: 1100px) {
  .stat-row { grid-template-columns: repeat(2, 1fr); }
  .grid { grid-template-columns: 1fr; }
}
</style>
