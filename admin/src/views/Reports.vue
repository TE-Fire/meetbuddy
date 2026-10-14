<template>
  <div class="page">
    <div class="toolbar panel">
      <el-select v-model="filters.status" placeholder="全部状态" clearable class="w150" @change="reload">
        <el-option label="待处理" value="PENDING" />
        <el-option label="已成立" value="APPROVED" />
        <el-option label="已驳回" value="REJECTED" />
      </el-select>
      <el-tag type="warning" effect="light" round>待处理 {{ pending }}</el-tag>
    </div>

    <div class="panel table-card">
      <el-table :data="rows" v-loading="loading" stripe style="width: 100%">
        <el-table-column prop="id" label="ID" width="70" />
        <el-table-column prop="reporterNickname" label="举报人" width="110" />
        <el-table-column label="对象" width="150">
          <template #default="{ row }">
            <el-tag size="small" effect="plain">{{ row.targetType }}</el-tag>
            <span style="margin-left:6px">{{ row.targetTitle || '#' + row.targetId }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="reason" label="举报理由" min-width="180" show-overflow-tooltip />
        <el-table-column label="证据" width="90">
          <template #default="{ row }">
            <el-button v-if="row.evidence" link type="primary" v-ripple @click="viewEvidence(row)">查看</el-button>
            <span v-else style="color:var(--text-soft)">无</span>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="110">
          <template #default="{ row }">
            <el-tag :type="row.status === 'PENDING' ? 'warning' : row.status === 'APPROVED' ? 'success' : 'info'" effect="light" round>
              {{ statusText(row.status) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="createdAt" label="时间" width="160">
          <template #default="{ row }">{{ fmt(row.createdAt) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="170" fixed="right">
          <template #default="{ row }">
            <template v-if="row.status === 'PENDING'">
              <el-button link type="success" v-ripple @click="approve(row)">判成立</el-button>
              <el-button link type="danger" v-ripple @click="reject(row)">驳回</el-button>
            </template>
            <span v-else style="color:var(--text-soft);font-size:13px">{{ row.handleResult }}</span>
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

    <el-dialog v-model="evVisible" title="举报证据" width="560px">
      <div class="evidence">
        <img v-for="(u, i) in evidenceList" :key="i" :src="u" class="ev-img" />
      </div>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { listReports, handleReport } from '../api/admin'

const rows = ref([])
const total = ref(0)
const pending = ref(0)
const page = ref(1)
const size = ref(10)
const loading = ref(false)
const filters = reactive({ status: '' })
const evVisible = ref(false)
const evidenceList = ref([])

function statusText(s) { return { PENDING: '待处理', APPROVED: '已成立', REJECTED: '已驳回' }[s] || s }
function fmt(d) { return d ? new Date(d).toLocaleString('zh-CN', { hour12: false }) : '—' }

async function reload() {
  loading.value = true
  try {
    const r = await listReports({ status: filters.status || undefined, page: page.value, size: size.value })
    rows.value = r.list
    total.value = r.total
    const all = await listReports({ status: 'PENDING', page: 1, size: 1 })
    pending.value = all.total
  } finally {
    loading.value = false
  }
}
function viewEvidence(row) { evidenceList.value = (row.evidence || '').split(',').filter(Boolean); evVisible.value = true }

async function approve(row) {
  try {
    const { value } = await ElMessageBox.prompt('请输入处置结论（判成立后系统将自动下架活动/扣分）', '判成立', {
      inputType: 'textarea', inputValidator: (v) => !!v && v.trim().length > 0 || '结论不能为空'
    })
    await handleReport(row.id, true, value.trim())
    ElMessage.success('已判成立，连带处置已执行')
    reload()
  } catch (e) { if (e !== 'cancel') ElMessage.error('操作失败') }
}
async function reject(row) {
  try {
    const { value } = await ElMessageBox.prompt('请输入驳回理由', '驳回举报', {
      inputType: 'textarea', inputValidator: (v) => !!v && v.trim().length > 0 || '理由不能为空'
    })
    await handleReport(row.id, false, value.trim())
    ElMessage.success('已驳回')
    reload()
  } catch (e) { if (e !== 'cancel') ElMessage.error('操作失败') }
}

onMounted(reload)
</script>

<style scoped>
.page { display: flex; flex-direction: column; gap: 16px; }
.toolbar { display: flex; align-items: center; gap: 12px; padding: 16px; border-radius: 14px; }
.w150 { width: 150px; }
.table-card { padding: 8px 8px 16px; border-radius: 14px; }
.pager { display: flex; justify-content: flex-end; padding: 14px 14px 4px; }
.evidence { display: flex; flex-wrap: wrap; gap: 10px; }
.ev-img { width: 160px; height: 160px; object-fit: cover; border-radius: 10px; border: 1px solid var(--border); }
</style>
