<template>
  <el-container class="layout">
    <!-- 侧栏：图标 + 文字，可收起成纯图标 -->
    <el-aside :width="theme.collapsed ? '76px' : '224px'" class="sidebar">
      <div class="brand" :class="{ center: theme.collapsed }">
        <div class="logo">M</div>
        <span v-show="!theme.collapsed" class="brand-name">MeetBuddy</span>
      </div>

      <nav class="nav">
        <router-link
          v-for="item in menus"
          :key="item.path"
          :to="item.path"
          class="nav-item clickable"
          v-ripple
          :class="{ active: isActive(item.path) }"
        >
          <el-icon class="nav-icon"><component :is="item.icon" /></el-icon>
          <span v-show="!theme.collapsed" class="nav-label">{{ item.title }}</span>
        </router-link>
      </nav>

      <div class="collapse-btn clickable" v-ripple @click="theme.toggleCollapsed()">
        <el-icon><component :is="theme.collapsed ? 'Expand' : 'Fold'" /></el-icon>
        <span v-show="!theme.collapsed">收起菜单</span>
      </div>
    </el-aside>

    <!-- 主区：顶栏 + 内容 -->
    <el-container>
      <el-header class="topbar">
        <div class="top-title">{{ currentTitle }}</div>
        <div class="top-actions">
          <el-input
            v-model="search"
            class="top-search"
            placeholder="搜索活动 / 用户…"
            :prefix-icon="Search"
            clearable
          />
          <el-badge :value="pendingCount" :hidden="pendingCount === 0" class="top-bell">
            <el-button circle text v-ripple @click="goReports">
              <el-icon :size="18"><Bell /></el-icon>
            </el-button>
          </el-badge>

          <ThemeSwitch />

          <el-dropdown @command="onCommand">
            <span class="avatar-wrap clickable">
              <el-avatar :size="34" class="avatar">{{ avatarText }}</el-avatar>
              <span class="who">{{ auth.user?.nickname || '管理员' }}</span>
              <el-icon><ArrowDown /></el-icon>
            </span>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item command="role">
                  <el-icon><User /></el-icon> 角色：{{ auth.user?.role === 1 ? '管理员' : '普通用户' }}
                </el-dropdown-item>
                <el-dropdown-item command="logout" divided>
                  <el-icon><SwitchButton /></el-icon> 退出登录
                </el-dropdown-item>
              </el-dropdown-menu>
            </template>
          </el-dropdown>
        </div>
      </el-header>

      <el-main class="content">
        <transition name="fade" mode="out-in">
          <router-view />
        </transition>
      </el-main>
    </el-container>
  </el-container>
</template>

<script setup>
import { computed, ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useThemeStore } from '../stores/theme'
import { useAuthStore } from '../stores/auth'
import { getDashboard } from '../api/admin'
import { ArrowDown, Search, Bell, User, SwitchButton } from '@element-plus/icons-vue'
import ThemeSwitch from '../components/ThemeSwitch.vue'

const theme = useThemeStore()
const auth = useAuthStore()
const route = useRoute()
const router = useRouter()
const search = ref('')
const pendingCount = ref(0)

const menus = [
  { path: '/dashboard', title: '数据看板', icon: 'DataLine' },
  { path: '/activities', title: '活动管理', icon: 'Calendar' },
  { path: '/reports', title: '举报处理', icon: 'Warning' },
  { path: '/users', title: '用户管理', icon: 'User' }
]

const currentTitle = computed(() => route.meta.title || '管理端')
const avatarText = computed(() => (auth.user?.nickname || '管').slice(0, 1))

function isActive(path) {
  return route.path.startsWith(path)
}
function goReports() {
  router.push('/reports')
}
function onCommand(cmd) {
  if (cmd === 'logout') {
    auth.logout()
    router.push('/login')
  }
}

onMounted(async () => {
  try {
    const d = await getDashboard()
    pendingCount.value = d.pendingReports || 0
  } catch { /* 权限/网络问题静默 */ }
})
</script>

<style scoped>
.layout { height: 100vh; }

.sidebar {
  background: var(--panel);
  border-right: 1px solid var(--border);
  display: flex;
  flex-direction: column;
  transition: width 0.3s var(--ease);
  overflow: hidden;
}
.brand {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 20px 18px;
  height: 64px;
}
.brand.center { justify-content: center; padding: 20px 0; }
.logo {
  width: 38px; height: 38px; border-radius: 11px; flex: none;
  background: linear-gradient(135deg, #38B2F2, #6FD0FF);
  color: #fff; font-weight: 700; font-size: 20px;
  display: flex; align-items: center; justify-content: center;
  box-shadow: var(--shadow-sm);
}
.brand-name { font-weight: 700; font-size: 17px; letter-spacing: 0.5px; }

.nav { flex: 1; padding: 8px 12px; display: flex; flex-direction: column; gap: 4px; }
.nav-item {
  display: flex; align-items: center; gap: 12px;
  height: 46px; padding: 0 14px; border-radius: 11px;
  color: var(--text-soft); text-decoration: none;
  transition: background 0.25s var(--ease), color 0.25s var(--ease), transform 0.2s var(--ease);
}
.nav-item:hover { background: var(--brand-soft); color: var(--brand); transform: translateX(2px); }
.nav-item.active {
  background: var(--brand-soft);
  color: var(--brand);
  font-weight: 600;
  animation: breath 2.6s ease-in-out infinite;
}
.nav-icon { font-size: 19px; }
.nav-label { font-size: 14.5px; white-space: nowrap; }

.collapse-btn {
  display: flex; align-items: center; gap: 10px;
  margin: 12px; padding: 10px 14px; border-radius: 11px;
  color: var(--text-soft); font-size: 13.5px;
  transition: background 0.25s var(--ease);
}
.collapse-btn:hover { background: var(--brand-soft); color: var(--brand); }

.topbar {
  display: flex; align-items: center; justify-content: space-between;
  height: 64px; padding: 0 22px;
  background: var(--panel); border-bottom: 1px solid var(--border);
}
.top-title { font-size: 18px; font-weight: 700; }
.top-actions { display: flex; align-items: center; gap: 16px; }
.top-search { width: 240px; }
.top-bell :deep(.el-button) { color: var(--text-soft); }
.avatar-wrap {
  display: flex; align-items: center; gap: 8px;
  padding: 4px 10px 4px 4px; border-radius: 22px;
  transition: background 0.25s var(--ease);
}
.avatar-wrap:hover { background: var(--brand-soft); }
.avatar { background: linear-gradient(135deg, #38B2F2, #6FD0FF); color: #fff; font-weight: 600; }
.who { font-size: 14px; color: var(--text); }

.content {
  background: var(--bg);
  padding: 22px;
  overflow-y: auto;
}
</style>
