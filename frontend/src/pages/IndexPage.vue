<template>
  <q-page class="dashboard-page q-pa-lg">

    <!-- Header -->
    <div class="row items-center justify-between q-mb-xl">
      <div>
        <div class="text-h5 text-weight-bold text-grey-9" style="letter-spacing: -0.5px;">Không gian học tập</div>
        <div class="text-caption text-grey-5 q-mt-xs">{{ notebooks.length }} notebook đang hoạt động</div>
      </div>
      <q-btn
        color="primary"
        icon="add"
        label="Tạo Notebook"
        unelevated
        class="create-btn"
        @click="createNewNotebook"
      />
    </div>

    <!-- Empty State -->
    <div v-if="notebooks.length === 0" class="empty-state column items-center justify-center q-py-xl">
      <div class="empty-icon-wrap q-mb-lg">
        <q-icon name="library_books" size="3.5rem" color="blue-3" />
      </div>
      <div class="text-subtitle1 text-weight-bold text-grey-7 q-mb-xs">Chưa có Notebook nào</div>
      <div class="text-caption text-grey-4 q-mb-lg text-center">Tạo notebook đầu tiên để bắt đầu học cùng AI</div>
      <q-btn color="primary" icon="add" label="Tạo ngay" unelevated @click="createNewNotebook" style="border-radius: 10px;" />
    </div>

    <!-- Notebook Grid -->
    <div class="row q-col-gutter-md">
      <div
        class="col-12 col-sm-6 col-md-4 col-lg-3"
        v-for="(notebook, index) in notebooks"
        :key="notebook.id"
      >
        <q-card
          class="notebook-card cursor-pointer"
          :style="`animation-delay: ${index * 60}ms`"
          @click="openNotebook(notebook.id)"
        >
          <!-- Color Banner -->
          <div class="nb-banner" :class="`nb-banner--${index % 5}`">
            <div class="nb-icon-wrap">
              <q-icon name="menu_book" size="2rem" color="white" />
            </div>
            <!-- Actions (top-right) -->
            <div class="nb-actions row q-gutter-xs" @click.stop>
              <q-btn
                icon="edit"
                flat round dense
                color="white"
                size="sm"
                class="nb-action-btn"
                @click.stop="handleRenameNotebook(notebook)"
              >
                <q-tooltip class="bg-dark">Đổi tên</q-tooltip>
              </q-btn>
              <q-btn
                icon="delete_outline"
                flat round dense
                color="white"
                size="sm"
                class="nb-action-btn"
                @click.stop="handleDeleteNotebook(notebook)"
              >
                <q-tooltip class="bg-dark">Xóa vĩnh viễn</q-tooltip>
              </q-btn>
            </div>
          </div>

          <!-- Content -->
          <q-card-section class="q-pa-md">
            <div class="text-subtitle2 text-weight-bold text-grey-9 ellipsis q-mb-xs" style="font-size: 0.92rem;">
              {{ notebook.title }}
            </div>
            <div class="row items-center q-gutter-xs">
              <q-icon name="schedule" size="0.75rem" color="grey-4" />
              <span class="text-caption text-grey-4" style="font-size: 0.72rem;">{{ notebook.created_at }}</span>
            </div>
          </q-card-section>

          <!-- Footer -->
          <div class="nb-footer row items-center justify-between q-px-md q-pb-md">
            <q-chip
              dense
              color="blue-1"
              text-color="primary"
              icon="folder_open"
              style="font-size: 0.68rem; height: 22px;"
            >
              Mở notebook
            </q-chip>
            <q-icon name="chevron_right" color="grey-4" size="1rem" />
          </div>
        </q-card>
      </div>
    </div>

  </q-page>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useQuasar } from 'quasar'
import { api } from 'boot/axios'

const router = useRouter()
const $q = useQuasar()
const notebooks = ref([])

onMounted(() => {
  const token = localStorage.getItem('access_token')
  if (!token) {
    router.push('/auth')
  } else {
    fetchNotebooks()
  }
})

const fetchNotebooks = async () => {
  try {
    const response = await api.get('/notebooks/')
    notebooks.value = response.data.notebooks
  } catch (error) {
    if (error.response?.status === 401) {
      $q.notify({ type: 'negative', message: 'Phiên đăng nhập hết hạn!' })
      localStorage.removeItem('access_token')
      router.push('/auth')
    } else {
      $q.notify({ type: 'negative', message: 'Lỗi tải danh sách Notebook' })
    }
  }
}

const openNotebook = (id) => {
  router.push(`/notebook/${id}`)
}

const createNewNotebook = () => {
  $q.dialog({
    title: 'Tạo Notebook mới',
    message: 'Nhập tên chủ đề bạn muốn học:',
    prompt: { model: '', type: 'text', placeholder: 'VD: Tài liệu Odoo, Đề cương C++...' },
    cancel: { flat: true, color: 'grey-7', label: 'Hủy' },
    ok: { color: 'primary', label: 'Tạo', unelevated: true },
    persistent: true,
  }).onOk(async (title) => {
    if (!title || title.trim() === '') {
      $q.notify({ type: 'warning', message: 'Tên Notebook không được để trống!' })
      return
    }
    try {
      await api.post('/notebooks/', { title: title.trim() })
      $q.notify({ type: 'positive', message: 'Tạo Notebook thành công!' })
      fetchNotebooks()
    } catch (error) {
      const errorMsg = error.response?.data?.detail || 'Lỗi khi tạo Notebook mới'
      $q.notify({ type: 'negative', message: errorMsg })
    }
  })
}

const handleRenameNotebook = (notebook) => {
  $q.dialog({
    title: 'Đổi tên Notebook',
    message: 'Nhập tên mới:',
    prompt: { model: notebook.title, type: 'text' },
    cancel: { flat: true, color: 'grey-7', label: 'Hủy' },
    ok: { color: 'primary', label: 'Lưu', unelevated: true },
    persistent: true,
  }).onOk(async (newTitle) => {
    if (!newTitle || newTitle.trim() === '' || newTitle.trim() === notebook.title) return
    try {
      const response = await api.post(`/notebooks/${notebook.id}/rename/`, { title: newTitle.trim() })
      $q.notify({ type: 'positive', message: response.data.message || 'Đổi tên thành công!' })
      fetchNotebooks()
    } catch (error) {
      const errorMsg = error.response?.data?.detail || 'Lỗi khi đổi tên Notebook'
      $q.notify({ type: 'negative', message: errorMsg })
    }
  })
}

const handleDeleteNotebook = (notebook) => {
  $q.dialog({
    title: 'Xóa vĩnh viễn?',
    message: `Notebook <strong>${notebook.title}</strong> và toàn bộ dữ liệu sẽ bị xóa. Không thể khôi phục.`,
    html: true,
    cancel: { flat: true, color: 'grey-7', label: 'Hủy' },
    ok: { color: 'negative', label: 'Xóa vĩnh viễn', unelevated: true },
    persistent: true,
  }).onOk(async () => {
    try {
      const response = await api.delete(`/notebooks/${notebook.id}`)
      $q.notify({ type: 'positive', message: response.data.message || 'Đã xóa Notebook!' })
      fetchNotebooks()
    } catch (error) {
      const errorMsg = error.response?.data?.detail || 'Lỗi hệ thống khi xóa Notebook'
      $q.notify({ type: 'negative', message: errorMsg })
    }
  })
}
</script>

<style scoped>
.dashboard-page {
  background: #f0f2f5;
  min-height: 100%;
}

.create-btn {
  border-radius: 10px;
  height: 40px;
  font-weight: 600;
  font-size: 0.88rem;
  letter-spacing: 0.2px;
  padding: 0 20px;
  box-shadow: 0 4px 14px rgba(25, 118, 210, 0.3) !important;
  transition: transform 0.15s, box-shadow 0.15s;
}
.create-btn:hover {
  transform: translateY(-1px);
  box-shadow: 0 6px 20px rgba(25, 118, 210, 0.4) !important;
}

/* Empty State */
.empty-state {
  min-height: 320px;
}
.empty-icon-wrap {
  width: 80px;
  height: 80px;
  background: #e3f0ff;
  border-radius: 24px;
  display: flex;
  align-items: center;
  justify-content: center;
}

/* Notebook Card */
.notebook-card {
  border-radius: 16px !important;
  border: 1.5px solid #e8eaed;
  overflow: hidden;
  box-shadow: 0 2px 8px rgba(0,0,0,0.05) !important;
  transition: transform 0.2s ease, box-shadow 0.2s ease, border-color 0.2s;
  animation: cardIn 0.35s ease both;
}
@keyframes cardIn {
  from { opacity: 0; transform: translateY(16px); }
  to   { opacity: 1; transform: translateY(0); }
}
.notebook-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 12px 28px rgba(0,0,0,0.1) !important;
  border-color: #bbdefb;
}

/* Banner Variants */
.nb-banner {
  position: relative;
  height: 80px;
  display: flex;
  align-items: center;
  justify-content: center;
}
.nb-banner--0 { background: linear-gradient(135deg, #1976d2, #1565c0); }
.nb-banner--1 { background: linear-gradient(135deg, #0288d1, #0277bd); }
.nb-banner--2 { background: linear-gradient(135deg, #00838f, #006064); }
.nb-banner--3 { background: linear-gradient(135deg, #5c6bc0, #3949ab); }
.nb-banner--4 { background: linear-gradient(135deg, #1e88e5, #0d47a1); }

.nb-icon-wrap {
  width: 52px;
  height: 52px;
  background: rgba(255,255,255,0.18);
  border-radius: 14px;
  display: flex;
  align-items: center;
  justify-content: center;
  backdrop-filter: blur(4px);
}

.nb-actions {
  position: absolute;
  top: 8px;
  right: 8px;
  opacity: 0;
  transition: opacity 0.18s;
}
.notebook-card:hover .nb-actions { opacity: 1; }

.nb-action-btn {
  background: rgba(0,0,0,0.2) !important;
  backdrop-filter: blur(4px);
}
.nb-action-btn:hover {
  background: rgba(0,0,0,0.35) !important;
}

.nb-footer {
  border-top: 1px solid #f3f4f6;
}
</style>