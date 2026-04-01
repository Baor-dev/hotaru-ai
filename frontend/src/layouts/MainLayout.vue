<template>
  <q-layout view="lHh Lpr lFf" class="bg-grey-1">

    <q-header class="main-header">
      <q-toolbar class="q-px-lg" style="height: 56px;">

        <!-- Logo -->
        <div
          class="logo-wrap row items-center cursor-pointer non-selectable"
          @click="$router.push('/')"
        >
          <div class="logo-icon-wrap q-mr-sm">
            <q-icon name="auto_awesome" color="white" size="1.1rem" />
          </div>
          <span class="logo-text">HOTARU AI</span>
        </div>

        <q-space />

        <!-- LOGGED IN: User chip + Logout -->
        <div v-if="isLoggedIn" class="row items-center q-gutter-sm">
          <div class="user-chip row items-center q-gutter-xs">
            <q-avatar size="26px" color="primary" text-color="white" style="font-size: 0.72rem; font-weight: 700;">
              {{ userInitial }}
            </q-avatar>
            <span class="user-chip-label">{{ userEmail }}</span>
          </div>

          <q-btn
            flat
            round
            dense
            icon="logout"
            color="grey-5"
            size="sm"
            class="logout-btn"
            @click="handleLogout"
          >
            <q-tooltip class="bg-dark">Đăng xuất</q-tooltip>
          </q-btn>
        </div>

        <!-- LOGGED OUT: Login + Register buttons -->
        <div v-else class="row items-center q-gutter-sm">
          <q-btn
            flat
            dense
            label="Đăng nhập"
            color="grey-7"
            class="auth-nav-btn"
            @click="$router.push('/auth')"
          />
          <q-btn
            unelevated
            dense
            label="Đăng ký"
            color="primary"
            class="auth-nav-btn auth-nav-btn--primary"
            @click="goToRegister"
          />
        </div>

      </q-toolbar>
    </q-header>

    <q-page-container>
      <router-view />
    </q-page-container>

  </q-layout>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useQuasar } from 'quasar'

const router = useRouter()
const route = useRoute()
const $q = useQuasar()

// ==========================================
// REACTIVE AUTH STATE
// ==========================================
const isLoggedIn = ref(false)
const userEmail = ref('')

// Lấy chữ cái đầu làm avatar
const userInitial = computed(() => {
  return userEmail.value ? userEmail.value.charAt(0).toUpperCase() : 'U'
})

// Kiểm tra trạng thái đăng nhập
const checkAuth = () => {
  const token = localStorage.getItem('access_token')
  const email = localStorage.getItem('user_email') || ''
  isLoggedIn.value = !!token
  userEmail.value = email
}

// Re-check mỗi khi route thay đổi (sau login/logout)
onMounted(checkAuth)
watch(() => route.path, checkAuth)

// ==========================================
// ĐĂNG XUẤT
// ==========================================
const handleLogout = () => {
  $q.dialog({
    title: 'Xác nhận đăng xuất',
    message: 'Bạn có chắc chắn muốn đăng xuất?',
    cancel: { flat: true, color: 'grey-7', label: 'Hủy' },
    ok: { color: 'negative', label: 'Đăng xuất', unelevated: true },
    persistent: true,
  }).onOk(() => {
    localStorage.removeItem('access_token')
    localStorage.removeItem('user_email')
    isLoggedIn.value = false
    userEmail.value = ''
    $q.notify({ type: 'info', message: 'Đã đăng xuất an toàn.', icon: 'logout' })
    router.push('/auth')
  })
}

// ==========================================
// CHUYỂN ĐẾN TRANG ĐĂNG KÝ
// ==========================================
const goToRegister = () => {
  // Dùng router để push đến /auth, AuthPage sẽ tự mở tab register
  router.push({ path: '/auth', query: { tab: 'register' } })
}
</script>

<style scoped>
/* Header */
.main-header {
  background: rgba(255, 255, 255, 0.95) !important;
  backdrop-filter: blur(12px);
  border-bottom: 1px solid #e8eaed;
  box-shadow: 0 1px 10px rgba(0, 0, 0, 0.06) !important;
  color: #1a1a1a !important;
}

/* Logo */
.logo-wrap {
  transition: opacity 0.15s;
}
.logo-wrap:hover { opacity: 0.8; }

.logo-icon-wrap {
  width: 34px;
  height: 34px;
  border-radius: 9px;
  background: linear-gradient(135deg, #1976d2, #1565c0);
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 3px 10px rgba(25, 118, 210, 0.3);
  flex-shrink: 0;
}

.logo-text {
  font-size: 1rem;
  font-weight: 800;
  color: #1565c0;
  letter-spacing: -0.3px;
}

/* User chip */
.user-chip {
  background: #f0f6ff;
  border: 1px solid #bbdefb;
  border-radius: 20px;
  padding: 3px 10px 3px 4px;
}
.user-chip-label {
  font-size: 0.8rem;
  font-weight: 500;
  color: #1976d2;
  max-width: 160px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* Logout btn */
.logout-btn {
  opacity: 0.6;
  transition: opacity 0.15s, transform 0.15s;
}
.logout-btn:hover {
  opacity: 1;
  transform: scale(1.1);
}

/* Auth nav buttons */
.auth-nav-btn {
  border-radius: 8px !important;
  font-size: 0.85rem !important;
  font-weight: 600 !important;
  height: 34px;
  padding: 0 14px !important;
}
.auth-nav-btn--primary {
  box-shadow: 0 3px 12px rgba(25, 118, 210, 0.28) !important;
  transition: transform 0.15s, box-shadow 0.15s !important;
}
.auth-nav-btn--primary:hover {
  transform: translateY(-1px);
  box-shadow: 0 5px 18px rgba(25, 118, 210, 0.38) !important;
}
</style>