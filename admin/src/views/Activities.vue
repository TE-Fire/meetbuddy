<template>
  <div class="page">
    <div class="toolbar panel">
      <el-select v-model="filters.status" placeholder="全部状态" clearable class="w150">
        <el-option v-for="s in statusOpts" :key="s" :label="s" :value="s" />
      </el-select>
      <el-input v-model="filters.keyword" placeholder="搜索活动标题" clearable class="w220" :prefix-icon="Search" @keyup.enter="reload" />
      <el-button type="primary" v-ripple :icon="Search" @click="reload">查询</el-button>
      <el-button v-ripple @click="reset">重置</el-button>
    </div>

    <div class="panel table-card">
      <el-table :data="rows" v-loading="loading" stripe style="width: 100%">
        <el-table-column prop="id" label="ID" width="80" />
        <el-table-column prop="title" label="标题" min-width="180" show-overflow-tooltip />
        <el-table-column prop="category" label="分类" width="100" />
        <el-table-column prop="organizerNickname" label="组织者" width="110" />
        <el-table-column label="状态" width="150">
          <template #default="{ row }">
            <el-tag :type="statusType(row.status)" effect="light" round>{{ row.status }}</el-tag>
            <el-tag v-if="row.adminStatus === 1" type="danger" effect="dark" round size="small" style="margin-left:6px">已下架</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="时间" min-width="170">
          <template #default="{ row }">{{ fmt(row.startTime) }} → {{ fmt(row.endTime) }}</template>
        </el-table-column>
        <el-table-column label="人数" width="100">
          <template #default="{ row }">{{ row.currentParticipants }}/{{ row.maxParticipants }}</template>
        </el-table-column>
        <el-table-column label="操作" width="200" fixed="right">
          <template #default="{ row }">
            <el-button link type="primary" v-ripple @click="openDetail(row)">详情</el-button>
            <el-button v-if="row.adminStatus !== 1" link type="danger" v-ripple @click="takedown(row)">下架</el-button>
            <el-button v-else link type="success" v-ripple @click="restore(row)">恢复</el-button>
          </template>
        </el-table-column>
      </el-table>

      <div class="pager">
        <el-pagination
          v-model:current-page="page"
          v-model:page-size="size"
          :total="total"
          :page-sizes="[10, 20, 50]"
          layout="total, sizes, prev, pager, next"
          background
          @current-change="reload"
          @size-change="reload"
        />
      </div>
    </div>

    <el-dialog v-model="detailVisible" title="活动详情" width="480px">
      <div v-if="detail" class="detail">
        <div class="d-row"><span>标题</span><b>{{ detail.title }}</b></div>
        <div class="d-row"><span>分类</span><b>{{ detail.category }}</b></div>
        <div class="d-row"><span>组织者</span><b>{{ detail.organizerNickname }}</b></div>
        <div class="d-row"><span>地点</span><b>{{ detail.address }}</b></div>
        <div class="d-row"><span>时间</span><b>{{ fmt(detail.startTime) }} → {{ fmt(detail.endTime) }}</b></div>
        <div class="d-row"><span>状态</span><b>{{ detail.status }} / {{ detail.adminStatus === 1 ? '已下架' : '正常' }}</b></div>
      </div>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Search } from '@element-plus/icons-vue'
import { listActivities, takedownActivity, restoreActivity } from '../api/admin'

const statusOpts = ['OPEN', 'FULL', 'ONGOING', 'FINISHED', 'CANCELLED']
const rows = ref([])
const total = ref(0)
const page = ref(1)
const size = ref(10)
const loading = ref(false)
const filters = reactive({ status: '', keyword: '' })
const detailVisible = ref(false)
const detail = ref(null)

function statusType(s) {
  return { OPEN: 'success', FULL: 'warning', ONGOING: 'primary', FINISHED: 'info', CANCELLED: 'danger' }[s] || 'info'
}
function fmt(d) {
  if (!d) return '—'
  return new Date(d).toLocaleString('zh-CN', { month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' })
}

async function reload() {
  loading.value = true
  try {
    const r = await listActivities({
      status: filters.status || undefined,
      keyword: filters.keyword || undefined,
      page: page.value, size: size.value
    })
    rows.value = r.list
    total.value = r.total
  } finally {
    loading.value = false
  }
}
function reset() {
  filters.status = ''
  filters.keyword = ''
  page.value = 1
  reload()
}
function openDetail(row) { detail.value = row; detailVisible.value = true }
async function takedown(row) {
  try {
    const { value } = await ElMessageBox.prompt('请输入下架原因（必填）', '下架活动', {
      inputType: 'textarea', inputValidator: (v) => !!v && v.trim().length > 0 || '原因不能为空'
    })
    await takedownActivity(row.id, value.trim())
    ElMessage.success('已下架')
    reload()
  } catch (e) { if (e !== 'cancel') ElMessage.error('操作失败') }
}
async function restore(row) {
  await ElMessageBox.confirm(`确认恢复活动「${row.title}」？`, '恢复展示', { type: 'warning' })
  await restoreActivity(row.id)
  ElMessage.success('已恢复')
  reload()
}

onMounted(reload)
</script>

<style scoped>
.page { display: flex; flex-direction: column; gap: 16px; }
.toolbar { display: flex; gap: 12px; padding: 16px; border-radius: 14px; }
.w150 { width: 150px; }
.w220 { width: 220px; }
.table-card { padding: 8px 8px 16px; border-radius: 14px; }
.pager { display: flex; justify-content: flex-end; padding: 14px 14px 4px; }
.detail { display: flex; flex-direction: column; gap: 12px; }
.d-row { display: flex; justify-content: space-between; font-size: 14px; color: var(--text-soft); }
.d-row b { color: var(--text); font-weight: 600; }
</style>
