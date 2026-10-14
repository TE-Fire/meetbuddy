import { createRouter, createWebHistory } from 'vue-router'
import { ElMessage } from 'element-plus'
import { useAuthStore } from '../stores/auth'

const routes = [
  {
    path: '/login',
    name: 'login',
    component: () => import('../views/Login.vue'),
    meta: { public: true }
  },
  {
    path: '/',
    component: () => import('../layout/AdminLayout.vue'),
    redirect: '/dashboard',
    children: [
      { path: 'dashboard', name: 'dashboard', component: () => import('../views/Dashboard.vue'), meta: { title: '数据看板' } },
      { path: 'activities', name: 'activities', component: () => import('../views/Activities.vue'), meta: { title: '活动管理' } },
      { path: 'reports', name: 'reports', component: () => import('../views/Reports.vue'), meta: { title: '举报处理' } },
      { path: 'users', name: 'users', component: () => import('../views/Users.vue'), meta: { title: '用户管理' } }
    ]
  },
  { path: '/:pathMatch(.*)*', redirect: '/dashboard' }
]

const router = createRouter({ history: createWebHistory(), routes })

router.beforeEach((to) => {
  const auth = useAuthStore()
  if (to.meta.public) {
    if (auth.isLoggedIn && auth.isAdmin) return '/dashboard'
    return true
  }
  if (!auth.isLoggedIn) {
    return { path: '/login', query: { redirect: to.fullPath } }
  }
  if (!auth.isAdmin) {
    ElMessage.warning('当前账号无管理权限')
    return '/login'
  }
  return true
})

export default router
