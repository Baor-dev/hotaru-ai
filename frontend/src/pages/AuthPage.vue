<template>
  <q-page class="auth-page flex flex-center">

    <!-- Background decoration -->
    <div class="auth-bg-blob auth-bg-blob--1"></div>
    <div class="auth-bg-blob auth-bg-blob--2"></div>

    <div class="auth-wrapper column items-center">

      <!-- Logo -->
      <div class="auth-logo column items-center q-mb-xl">
        <div class="logo-icon-wrap q-mb-md">
          <q-icon name="auto_awesome" color="white" size="2rem" />
        </div>
        <div class="text-h4 text-weight-bolder text-grey-9" style="letter-spacing: -1px;">HOTARU AI</div>
        <div class="text-caption text-grey-5 q-mt-xs" style="letter-spacing: 0.5px;">Trợ lý học tập thông minh</div>
      </div>

      <!-- Card -->
      <q-card class="auth-card" flat>

        <!-- Tab Switcher -->
        <div class="tab-switcher row q-mb-lg">
          <button
            class="tab-btn col"
            :class="{ 'tab-btn--active': tab === 'login' }"
            @click="tab = 'login'"
          >
            Đăng Nhập
          </button>
          <button
            class="tab-btn col"
            :class="{ 'tab-btn--active': tab === 'register' }"
            @click="tab = 'register'"
          >
            Đăng Ký
          </button>
        </div>

        <!-- LOGIN -->
        <transition name="slide-fade" mode="out-in">
          <div v-if="tab === 'login'" key="login" class="q-gutter-y-md">
            <div>
              <div class="field-label">Email</div>
              <q-input
                v-model="email"
                outlined
                dense
                type="email"
                placeholder="you@example.com"
                class="auth-input"
                @keyup.enter="handleLogin"
              >
                <template v-slot:prepend>
                  <q-icon name="mail_outline" color="grey-4" size="1rem" />
                </template>
              </q-input>
            </div>
            <div>
              <div class="field-label">Mật khẩu</div>
              <q-input
                v-model="password"
                outlined
                dense
                :type="showPass ? 'text' : 'password'"
                placeholder="••••••••"
                class="auth-input"
                @keyup.enter="handleLogin"
              >
                <template v-slot:prepend>
                  <q-icon name="lock_outline" color="grey-4" size="1rem" />
                </template>
                <template v-slot:append>
                  <q-icon
                    :name="showPass ? 'visibility' : 'visibility_off'"
                    color="grey-4"
                    size="1rem"
                    class="cursor-pointer"
                    @click="showPass = !showPass"
                  />
                </template>
              </q-input>
            </div>

            <q-btn
              label="Đăng Nhập"
              color="primary"
              unelevated
              class="auth-submit-btn full-width q-mt-sm"
              :loading="loading"
              @click="handleLogin"
            >
              <template v-slot:loading>
                <q-spinner-dots size="1.2rem" color="white" />
              </template>
            </q-btn>
          </div>

          <!-- REGISTER -->
          <div v-else key="register" class="q-gutter-y-md">
            <div>
              <div class="field-label">Họ và tên</div>
              <q-input
                v-model="username"
                outlined
                dense
                placeholder="Nguyễn Văn A"
                class="auth-input"
              >
                <template v-slot:prepend>
                  <q-icon name="person_outline" color="grey-4" size="1rem" />
                </template>
              </q-input>
            </div>
            <div>
              <div class="field-label">Email</div>
              <q-input
                v-model="email"
                outlined
                dense
                type="email"
                placeholder="you@example.com"
                class="auth-input"
              >
                <template v-slot:prepend>
                  <q-icon name="mail_outline" color="grey-4" size="1rem" />
                </template>
              </q-input>
            </div>
            <div>
              <div class="field-label">Mật khẩu</div>
              <q-input
                v-model="password"
                outlined
                dense
                :type="showPass ? 'text' : 'password'"
                placeholder="••••••••"
                class="auth-input"
                @keyup.enter="handleRegister"
              >
                <template v-slot:prepend>
                  <q-icon name="lock_outline" color="grey-4" size="1rem" />
                </template>
                <template v-slot:append>
                  <q-icon
                    :name="showPass ? 'visibility' : 'visibility_off'"
                    color="grey-4"
                    size="1rem"
                    class="cursor-pointer"
                    @click="showPass = !showPass"
                  />
                </template>
              </q-input>
            </div>

            <q-btn
              label="Tạo tài khoản"
              color="primary"
              unelevated
              class="auth-submit-btn full-width q-mt-sm"
              :loading="loading"
              @click="handleRegister"
            >
              <template v-slot:loading>
                <q-spinner-dots size="1.2rem" color="white" />
              </template>
            </q-btn>
          </div>
        </transition>

        <!-- Footer note -->
        <div class="text-caption text-grey-4 text-center q-mt-lg" style="font-size: 0.72rem; line-height: 1.5;">
          Bằng cách tiếp tục, bạn đồng ý với<br>
          <span class="text-primary cursor-pointer">Điều khoản sử dụng</span> của Hotaru AI
        </div>
      </q-card>

    </div>
  </q-page>
</template>

<script setup>
import { ref } from 'vue'
import { api } from 'boot/axios'
import { useQuasar } from 'quasar'
import { useRouter } from 'vue-router'

const $q = useQuasar()
const router = useRouter()

const tab = ref('login')
const loading = ref(false)
const showPass = ref(false)

const username = ref('')
const email = ref('')
const password = ref('')

const handleLogin = async () => {
  if (!email.value || !password.value) {
    $q.notify({ type: 'warning', message: 'Vui lòng nhập đầy đủ thông tin!' })
    return
  }
  loading.value = true
  try {
    const response = await api.post('/login', { email: email.value, password: password.value })
    localStorage.setItem('access_token', response.data.access_token)
    $q.notify({ type: 'positive', message: 'Đăng nhập thành công!' })
    router.push('/')
  } catch (error) {
    const errorMsg = error.response?.data?.detail || 'Sai tài khoản hoặc mật khẩu!'
    $q.notify({ type: 'negative', message: errorMsg })
  } finally {
    loading.value = false
  }
}

const handleRegister = async () => {
  if (!username.value || !email.value || !password.value) {
    $q.notify({ type: 'warning', message: 'Vui lòng nhập đầy đủ thông tin!' })
    return
  }
  loading.value = true
  try {
    await api.post('/register', { username: username.value, email: email.value, password: password.value })
    $q.notify({ type: 'positive', message: 'Đăng ký thành công! Vui lòng đăng nhập.', timeout: 4000 })
    tab.value = 'login'
    password.value = ''
  } catch (error) {
    const errorMsg = error.response?.data?.detail || 'Lỗi đăng ký!'
    $q.notify({ type: 'negative', message: errorMsg })
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
/* Page */
.auth-page {
  background: #f0f2f5;
  min-height: 100vh;
  overflow: hidden;
  position: relative;
}

/* Background blobs */
.auth-bg-blob {
  position: fixed;
  border-radius: 50%;
  filter: blur(80px);
  opacity: 0.25;
  pointer-events: none;
}
.auth-bg-blob--1 {
  width: 500px;
  height: 500px;
  background: #1976d2;
  top: -180px;
  right: -120px;
}
.auth-bg-blob--2 {
  width: 400px;
  height: 400px;
  background: #0288d1;
  bottom: -160px;
  left: -100px;
}

/* Wrapper */
.auth-wrapper {
  position: relative;
  z-index: 1;
  width: 100%;
  max-width: 400px;
  padding: 24px 16px;
}

/* Logo */
.logo-icon-wrap {
  width: 64px;
  height: 64px;
  border-radius: 20px;
  background: linear-gradient(135deg, #1976d2, #1565c0);
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 8px 24px rgba(25, 118, 210, 0.35);
}

/* Card */
.auth-card {
  width: 100%;
  border-radius: 20px !important;
  border: 1.5px solid rgba(255,255,255,0.8);
  background: rgba(255,255,255,0.92);
  backdrop-filter: blur(20px);
  padding: 28px 28px 24px;
  box-shadow: 0 8px 40px rgba(0,0,0,0.1) !important;
}

/* Tab Switcher */
.tab-switcher {
  background: #f0f2f5;
  border-radius: 10px;
  padding: 4px;
  gap: 4px;
}
.tab-btn {
  border: none;
  background: transparent;
  border-radius: 8px;
  padding: 8px 0;
  font-size: 0.88rem;
  font-weight: 500;
  color: #9e9e9e;
  cursor: pointer;
  transition: all 0.2s ease;
  outline: none;
}
.tab-btn--active {
  background: #ffffff;
  color: #1976d2;
  font-weight: 700;
  box-shadow: 0 2px 8px rgba(0,0,0,0.08);
}

/* Field label */
.field-label {
  font-size: 0.8rem;
  font-weight: 600;
  color: #4b5563;
  margin-bottom: 5px;
  letter-spacing: 0.1px;
}

/* Input */
.auth-input :deep(.q-field__control) {
  border-radius: 10px !important;
  background: #f9fafb !important;
  font-size: 0.9rem;
  transition: box-shadow 0.18s;
}
.auth-input :deep(.q-field__control:hover) {
  background: #f3f6fd !important;
}
.auth-input :deep(.q-field--focused .q-field__control) {
  box-shadow: 0 0 0 3px rgba(25, 118, 210, 0.12) !important;
}

/* Submit button */
.auth-submit-btn {
  height: 46px !important;
  border-radius: 12px !important;
  font-size: 0.92rem !important;
  font-weight: 700 !important;
  letter-spacing: 0.2px;
  box-shadow: 0 4px 16px rgba(25, 118, 210, 0.3) !important;
  transition: transform 0.15s, box-shadow 0.15s !important;
}
.auth-submit-btn:hover {
  transform: translateY(-1px);
  box-shadow: 0 6px 22px rgba(25, 118, 210, 0.4) !important;
}
.auth-submit-btn:active {
  transform: translateY(0);
}

/* Slide transition */
.slide-fade-enter-active,
.slide-fade-leave-active {
  transition: all 0.2s ease;
}
.slide-fade-enter-from {
  opacity: 0;
  transform: translateX(12px);
}
.slide-fade-leave-to {
  opacity: 0;
  transform: translateX(-12px);
}
</style>