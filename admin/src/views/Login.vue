<template>
  <div class="login-wrap">
    <div class="login-card panel lift">
      <div class="login-brand">
        <div class="login-logo">M</div>
        <div>
          <div class="login-title">MeetBuddy 管理端</div>
          <div class="login-sub">同城活动组局 · 运营管理后台</div>
        </div>
      </div>

      <el-form @submit.prevent="onSubmit" label-position="top">
        <el-form-item label="管理员手机号">
          <el-input v-model="phone" size="large" placeholder="13900000001" :prefix-icon="Iphone" />
        </el-form-item>
        <el-form-item label="密码">
          <el-input
            v-model="password"
            type="password"
            size="large"
            show-password
            placeholder="123456"
            :prefix-icon="Lock"
            @keyup.enter="onSubmit"
          />
        </el-form-item>
        <el-button
          type="primary"
          size="large"
          class="login-btn"
          v-ripple
          :loading="loading"
          @click="onSubmit"
        >
          登 录
        </el-button>
      </el-form>

      <div class="login-hint">演示账号：13900000001 / 123456</div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { Iphone, Lock } from '@element-plus/icons-vue'
import { useAuthStore } from '../stores/auth'

const auth = useAuthStore()
const router = useRouter()
const route = useRoute()

const phone = ref('13900000001')
const password = ref('123456')
const loading = ref(false)

async function onSubmit() {
  if (!phone.value || !password.value) {
    ElMessage.warning('请填写手机号和密码')
    return
  }
  loading.value = true
  try {
    const user = await auth.login(phone.value.trim(), password.value)
    if (user.role !== 1) {
      ElMessage.error('该账号不是管理员')
      auth.logout()
      return
    }
    ElMessage.success('欢迎回来，管理员')
    router.replace(route.query.redirect || '/dashboard')
  } catch (e) {
    ElMessage.error('登录失败：' + (e?.message || '账号或密码错误'))
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.login-wrap {
  height: 100vh; display: flex; align-items: center; justify-content: center;
  background: radial-gradient(1200px 600px at 70% -10%, var(--brand-soft), transparent),
              linear-gradient(135deg, #eaf4ff, #f6fbff);
  transition: background 0.4s var(--ease);
}
html.dark .login-wrap {
  background: radial-gradient(1200px 600px at 70% -10%, rgba(56,178,242,.10), transparent),
              linear-gradient(135deg, #0f141c, #121a25);
}
.login-card { width: 380px; padding: 34px 30px; border-radius: 20px; }
.login-brand { display: flex; align-items: center; gap: 14px; margin-bottom: 26px; }
.login-logo {
  width: 46px; height: 46px; border-radius: 13px; flex: none;
  background: linear-gradient(135deg, #38B2F2, #6FD0FF); color: #fff;
  font-weight: 700; font-size: 24px; display: flex; align-items: center; justify-content: center;
  box-shadow: var(--shadow-sm);
}
.login-title { font-size: 19px; font-weight: 700; }
.login-sub { font-size: 12.5px; color: var(--text-soft); margin-top: 3px; }
.login-btn { width: 100%; margin-top: 6px; letter-spacing: 4px; }
.login-hint { text-align: center; font-size: 12px; color: var(--text-soft); margin-top: 16px; }
</style>
