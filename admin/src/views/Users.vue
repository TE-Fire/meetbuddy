<template>
  <div class="page">
    <div class="toolbar panel">
      <el-input v-model="filters.keyword" placeholder="手机号 / 昵称" clearable class="w240" :prefix-icon="Search" @keyup.enter="reload" />
      <el-button type="primary" v-ripple :icon="Search" @click="reload">查询</el-button>
      <el-button v-ripple @click="reset">重置</el-button>
    </div>

    <div class="panel table-card">
      <el-table :data="rows" v-loading="loading" stripe style="width: 100%">
        <el-table-column prop="id" label="ID" width="70" />
        <el-table-column prop="nickname" label="昵称" width="130" />
        <el-table-column prop="phone" label="手机号" width="130" />
        <el-table-column label="性别" width="80">
          <template #default="{ row }">{{ ['未知', '男', '女'][row.gender] || '未知' }}</template>
        </el-table-column>
        <el-table-column label="信用分" width="100">
          <template #default="{ row }">
            <span :class="row.creditScore < 60 ? 'low' : 'ok'">{{ row.creditScore }}</span>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="100">
          <template #default="{ row }">
            <el-tag :type="row.status === 1 ? 'danger' : 'success'" effect="light" round>
              {{ row.status === 1 ? '已封禁' : '正常' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="lastActiveAt" label="最近活跃" min-width="160">
          <template #default="{ row }">{{ fmt(row.lastActiveAt) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="240" fixed="right">
          <template #default="{ row }">
            <el-button link type="primary" v-ripple @click="openDetail(row)">详情</el-button>
            <el-button v-if="row.status !== 1" link type="danger" v-ripple @click="ban(row)">封禁</el-button>
            <el-button v-else link type="success" v-ripple @click="unban(row)">解封</el-button>
            <el-button link type="warning" v-ripple @click="credit(row)">调分</el-button>
          </template>
        </el-table-column>
      </el-table>

      <div class="pager">
        <el-pagination
          v-model:current-page="page" v-model:page-size="size" :total="total"
          :page-sizes="[10, 20, 50]" layout="total, sizes, prev, pager, next"
          background @current-change="reload" @size-change="reload"
        />
      </div>
    </div>

    <el-drawer v-model="drawer" :title="`用户详情 · ${cur?.nickname || ''}`" size="440px">
      <template v-if="cur">
        <div class="info panel">
          <div class="info-row"><span>手机号</span><b>{{ cur.phone }}</b></div>
          <div class="info-row"><span>信用分</span><b :class="cur.creditScore < 60 ? 'low' : 'ok'">{{ cur.creditScore }}</b></div>
          <div class="info-row"><span>状态</span><b>{{ cur.status === 1 ? '已封禁' : '正常' }}</b></div>
          <div class="info-row"><span>角色</span><b>{{ cur.role === 1 ? '管理员' : '普通用户' }}</b></div>
        </div>

        <div class="sec-title">信用分流水</div>
        <el-table :data="logs" size="small" max-height="220">
          <el-table-column prop="changeValue" label="变动" width="70">
            <template #default="{ row }">
              <span :class="row.changeValue < 0 ? 'low' : 'ok'">{{ row.changeValue > 0 ? '+' : '' }}{{ row.changeValue }}</span>
            </template>
          </el-table-column>
          <el-table-column prop="reason" label="原因" min-width="140" show-overflow-tooltip />
          <el-table-column prop="balanceAfter" label="余额" width="70" />
        </el-table>

        <div class="sec-title">举报历史</div>
        <div v-if="reports.length === 0" class="empty">暂无举报记录</div>
        <div v-for="r in reports" :key="r.id" class="rep">
          <el-tag size="small" effect="plain">{{ r.targetType }}</el-tag>
          <span class="rep-reason">{{ r.reason }}</span>
          <el-tag size="small" :type="r.status === 'PENDING' ? 'warning' : r.status === 'APPROVED' ? 'success' : 'info'" effect="light">
            {{ { PENDING: '待处理', APPROVED: '已成立', REJECTED: '已驳回' }[r.status] }}
          </el-tag>
        </div>
      </template>
    </el-drawer>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Search } from '@element-plus/icons-vue'
import { listUsers, getUserDetail, banUser, unbanUser, adjustCredit } from '../api/admin'

const rows = ref([])
const total = ref(0)
const page = ref(1)
const size = ref(10)
const loading = ref(false)
const filters = reactive({ keyword: '' })
const drawer = ref(false)
const cur = ref(null)
const logs = ref([])
const reports = ref([])

function fmt(d) { return d ? new Date(d).toLocaleString('zh-CN', { hour12: false }) : '—' }

async function reload() {
  loading.value = true
  try {
    const r = await listUsers({ keyword: filters.keyword || undefined, page: page.value, size: size.value })
    rows.value = r.list
    total.value = r.total
  } finally {
    loading.value = false
  }
}
function reset() { filters.keyword = ''; page.value = 1; reload() }

async function openDetail(row) {
  cur.value = row
  drawer.value = true
  const d = await getUserDetail(row.id)
  logs.value = d.creditLogs || []
  reports.value = d.reports || []
}
async function ban(row) {
  try {
    const { value } = await ElMessageBox.prompt('请输入封禁原因（必填）', '封禁用户', {
      inputType: 'textarea', inputValidator: (v) => !!v && v.trim().length > 0 || '原因不能为空'
    })
    await banUser(row.id, value.trim())
    ElMessage.success('已封禁，该用户将被即时拦截')
    reload()
  } catch (e) { if (e !== 'cancel') ElMessage.error('操作失败') }
}
async function unban(row) {
  await ElMessageBox.confirm(`确认解封 ${row.nickname}？`, '解封', { type: 'warning' })
  await unbanUser(row.id)
  ElMessage.success('已解封')
  reload()
}
async function credit(row) {
  try {
    const { value } = await ElMessageBox.prompt('请输入分值变动（正数加分，负数扣分）', '调整信用分', {
      inputType: 'number', inputValidator: (v) => /^-?\d+$/.test(v) || '请输入整数'
    })
    const changeValue = parseInt(value, 10)
    const { value: reason } = await ElMessageBox.prompt('请输入调整原因', '调整信用分', {
      inputType: 'textarea', inputValidator: (v) => !!v && v.trim().length > 0 || '原因不能为空'
    })
    await adjustCredit(row.id, changeValue, reason.trim())
    ElMessage.success('信用分已调整')
    reload()
  } catch (e) { if (e !== 'cancel') ElMessage.error('操作失败') }
}

onMounted(reload)
</script>

<style scoped>
.page { display: flex; flex-direction: column; gap: 16px; }
.toolbar { display: flex; gap: 12px; padding: 16px; border-radius: 14px; }
.w240 { width: 240px; }
.table-card { padding: 8px 8px 16px; border-radius: 14px; }
.pager { display: flex; justify-content: flex-end; padding: 14px 14px 4px; }
.ok { color: #2DBE8B; font-weight: 700; }
.low { color: #f56c6c; font-weight: 700; }
.info { padding: 14px 16px; border-radius: 12px; display: flex; flex-direction: column; gap: 10px; margin-bottom: 16px; }
.info-row { display: flex; justify-content: space-between; font-size: 14px; color: var(--text-soft); }
.info-row b { color: var(--text); }
.sec-title { font-weight: 700; font-size: 14px; margin: 18px 0 10px; }
.empty { color: var(--text-soft); font-size: 13px; padding: 8px 0; }
.rep { display: flex; align-items: center; gap: 10px; padding: 8px 0; border-bottom: 1px solid var(--border); font-size: 13px; }
.rep-reason { flex: 1; color: var(--text); }
</style>
