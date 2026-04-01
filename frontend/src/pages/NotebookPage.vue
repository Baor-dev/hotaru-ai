<template>
  <q-page class="chat-page row q-col-gutter-md" style="height: calc(100vh - 50px); overflow: hidden;">

    <!-- ==================== LEFT PANEL: TÀI LIỆU ==================== -->
    <div class="col-12 col-md-4 col-lg-3 flex column">
      <q-card class="doc-panel shadow-4 column full-height" style="overflow: hidden; border-radius: 16px;">

        <!-- Header -->
        <q-card-section class="doc-panel-header row items-center justify-between q-py-md q-px-lg">
          <div class="row items-center q-gutter-sm">
            <q-icon name="auto_stories" size="1.3rem" color="white" />
            <span class="text-subtitle1 text-weight-bold text-white" style="letter-spacing: 0.3px;">Tài liệu của bạn</span>
          </div>
          <q-btn
            icon="add"
            flat
            round
            dense
            color="white"
            class="add-btn"
            @click="openUploadDialog"
          >
            <q-tooltip class="bg-dark">Thêm tài liệu mới</q-tooltip>
          </q-btn>
        </q-card-section>

        <!-- Select All Bar -->
        <div v-if="documents.length > 0" class="select-all-bar row items-center q-px-lg q-py-xs">
          <q-checkbox
            v-model="isAllSelected"
            color="primary"
            dense
            label=""
          />
          <span class="text-caption text-weight-medium text-grey-7 q-ml-xs">
            Chọn tất cả
            <q-badge
              color="primary"
              rounded
              class="q-ml-xs"
              style="font-size: 0.65rem;"
            >{{ selectedDocs.length }}/{{ documents.length }}</q-badge>
          </span>
        </div>

        <q-separator v-if="documents.length > 0" />

        <!-- Document List -->
        <q-card-section class="col scroll q-pa-md" style="gap: 8px; display: flex; flex-direction: column;">
          <div
            v-for="doc in documents"
            :key="doc.id"
            class="doc-item row items-center no-wrap"
            :class="{ 'doc-item--selected': selectedDocs.includes(doc.name) }"
            @click="openPreview(doc.id)"
          >
            <!-- Checkbox -->
            <div @click.stop class="q-mr-sm">
              <q-checkbox v-model="selectedDocs" :val="doc.name" color="primary" dense />
            </div>

            <!-- Icon -->
            <div class="doc-icon-wrap q-mr-sm">
              <q-icon
                :name="doc.type === 'pdf' ? 'picture_as_pdf' : doc.type === 'youtube' ? 'smart_display' : 'description'"
                :color="doc.type === 'pdf' ? 'red-5' : doc.type === 'youtube' ? 'red-6' : 'blue-6'"
                size="1.1rem"
              />
            </div>

            <!-- Name & Type -->
            <div class="col overflow-hidden">
              <div class="doc-name ellipsis" :title="doc.name">{{ doc.name }}</div>
              <div class="doc-type text-uppercase">{{ doc.type }}</div>
            </div>

            <!-- Menu -->
            <div @click.stop>
              <q-btn icon="more_vert" flat round dense color="grey-5" size="xs">
                <q-menu cover auto-close anchor="bottom right" self="top right" class="rounded-menu">
                  <q-list style="min-width: 150px;">
                    <q-item clickable @click="deleteDocument(doc.id)" class="text-red-5">
                      <q-item-section avatar class="q-pr-none" style="min-width: 32px;">
                        <q-icon name="delete_outline" color="red-5" size="sm" />
                      </q-item-section>
                      <q-item-section class="text-weight-medium" style="font-size: 0.88rem;">Xóa tài liệu</q-item-section>
                    </q-item>
                  </q-list>
                </q-menu>
              </q-btn>
            </div>
          </div>

          <!-- Empty State -->
          <div v-if="documents.length === 0" class="empty-state column items-center justify-center q-py-xl">
            <q-icon name="cloud_upload" size="3rem" color="grey-4" class="q-mb-md" />
            <div class="text-grey-5 text-body2 text-center" style="font-size: 0.85rem;">
              Chưa có tài liệu nào.<br>Bấm <strong>+</strong> để thêm nhé!
            </div>
          </div>
        </q-card-section>

      </q-card>
    </div>

    <!-- ==================== RIGHT PANEL: CHAT ==================== -->
    <div class="col-12 col-md-8 col-lg-9 flex column" style="height: 100%">
      <q-card class="chat-panel shadow-4 column full-height" style="overflow: hidden; border-radius: 16px;">

        <!-- Chat Header -->
        <q-card-section class="chat-header row items-center justify-between q-py-sm q-px-lg">
          <div class="row items-center q-gutter-sm">
            <q-btn icon="arrow_back" flat round dense color="grey-7" size="sm" @click="router.push('/')" class="back-btn" />
            <div>
              <div class="text-subtitle1 text-weight-bold text-grey-9" style="line-height: 1.2; letter-spacing: -0.2px;">
                Hotaru AI
              </div>
              <div class="row items-center q-gutter-xs">
                <span class="online-dot"></span>
                <span class="text-caption text-grey-5" style="font-size: 0.72rem;">{{ notebookName }} · Đang hoạt động</span>
              </div>
            </div>
          </div>
          <div class="row items-center q-gutter-sm">
            <q-chip
              v-if="selectedDocs.length > 0"
              dense
              color="blue-1"
              text-color="primary"
              icon="folder_open"
              style="font-size: 0.75rem; height: 26px;"
            >
              {{ selectedDocs.length }} tài liệu
            </q-chip>
            <q-chip
              v-else
              dense
              color="orange-1"
              text-color="orange-8"
              icon="warning"
              style="font-size: 0.75rem; height: 26px;"
            >
              Chưa chọn
            </q-chip>
          </div>
        </q-card-section>

        <q-separator />

        <!-- Chat Messages -->
        <q-card-section
          class="col chat-body q-pa-lg"
          ref="chatScroll"
          style="flex-grow: 1; overflow-y: auto;"
        >
          <div class="q-gutter-y-lg">

            <div
              v-for="(msg, index) in chatHistory"
              :key="index"
              class="msg-row"
              :class="msg.role === 'user' ? 'msg-row--user' : 'msg-row--ai'"
            >
              <!-- AI Avatar -->
              <div v-if="msg.role !== 'user'" class="msg-avatar">
                <q-avatar size="32px" color="primary" text-color="white" style="font-size: 0.8rem; font-weight: 700;">AI</q-avatar>
              </div>

              <!-- Bubble -->
              <div
                class="msg-bubble"
                :class="msg.role === 'user' ? 'msg-bubble--user' : 'msg-bubble--ai'"
              >
                <div class="msg-content" style="white-space: pre-wrap; line-height: 1.65;">
                  <template v-for="(part, pIdx) in parseContent(msg.content, msg.sources)" :key="pIdx">
                    <span v-if="part.type === 'text'">{{ part.content }}</span>
                    <q-badge
                      v-else-if="part.type === 'source'"
                      rounded
                      color="blue-8"
                      text-color="white"
                      class="cursor-pointer citation-badge q-mx-xs"
                      @click="openPreview(part.docId)"
                    >
                      {{ part.refId }}
                      <q-tooltip class="bg-dark text-white">Xem: {{ part.filename }}</q-tooltip>
                    </q-badge>
                  </template>
                </div>

                <!-- Sources Footer -->
                <div v-if="msg.sources && msg.sources.length > 0" class="msg-sources row items-center q-gutter-xs q-mt-sm">
                  <q-icon name="link" size="0.8rem" color="blue-5" />
                  <span
                    v-for="src in msg.sources.slice(0, 3)"
                    :key="src.id"
                    class="source-chip cursor-pointer"
                    @click="openPreview(src.id)"
                  >
                    {{ src.filename }}
                  </span>
                </div>
              </div>

              <!-- User Avatar -->
              <div v-if="msg.role === 'user'" class="msg-avatar">
                <q-avatar size="32px" color="grey-3" text-color="grey-7" icon="person" style="font-size: 1rem;" />
              </div>
            </div>

            <!-- Typing Indicator -->
            <div v-if="isTyping" class="msg-row msg-row--ai">
              <q-avatar size="32px" color="primary" text-color="white" style="font-size: 0.8rem; font-weight: 700;">AI</q-avatar>
              <div class="msg-bubble msg-bubble--ai typing-bubble">
                <span class="typing-dot"></span>
                <span class="typing-dot"></span>
                <span class="typing-dot"></span>
              </div>
            </div>

          </div>
        </q-card-section>

        <!-- Input Area -->
        <div class="chat-input-area">
          <div class="chat-input-inner row items-end q-col-gutter-sm">
            <div class="col">
              <q-input
                v-model="newMessage"
                outlined
                dense
                autogrow
                :rows="1"
                placeholder="Hỏi AI về tài liệu của bạn..."
                :disable="isTyping"
                class="chat-input"
                @keyup.enter.exact="sendMessage"
                @keydown.enter.shift.prevent
              >
                <template v-slot:prepend>
                  <q-icon name="chat_bubble_outline" color="grey-4" size="1rem" />
                </template>
              </q-input>
            </div>
            <div class="col-auto q-pb-xs">
              <q-btn
                round
                color="primary"
                icon="send"
                size="md"
                :disable="!newMessage.trim() || isTyping"
                class="send-btn"
                @click="sendMessage"
              >
                <q-tooltip>Gửi (Enter)</q-tooltip>
              </q-btn>
            </div>
          </div>
          <div class="text-caption text-grey-4 text-center q-mt-xs" style="font-size: 0.68rem;">
            Nhấn Enter để gửi · Shift+Enter để xuống dòng
          </div>
        </div>

      </q-card>
    </div>

    <!-- Hidden File Input -->
    <input type="file" ref="fileInput" accept=".pdf, .docx, .txt" style="display: none" @change="handleFileUpload" />

    <!-- ==================== DIALOG: UPLOAD ==================== -->
    <q-dialog v-model="uploadDialog" position="top" transition-show="slide-down" transition-hide="slide-up">
      <q-card class="upload-dialog" style="width: 560px; max-width: 92vw; border-radius: 20px; overflow: hidden; margin-top: 56px;">

        <q-btn icon="close" flat round dense v-close-popup class="absolute-top-right z-top q-ma-sm text-grey-6" />

        <!-- Main View -->
        <q-card-section v-if="uploadView === 'main'" class="q-pt-xl q-pb-lg q-px-xl">
          <div class="text-h6 text-weight-bold text-grey-9 text-center q-mb-xs" style="letter-spacing: -0.3px;">
            Thêm nguồn kiến thức
          </div>
          <div class="text-caption text-grey-5 text-center q-mb-lg">Dán văn bản, link YouTube, hoặc tải file lên</div>

          <q-input
            v-model="pastedText"
            type="textarea"
            outlined
            placeholder="Dán văn bản trực tiếp vào đây..."
            rows="5"
            class="q-mb-sm paste-area"
            style="border-radius: 12px;"
          />

          <q-slide-transition>
            <div v-show="pastedText.trim().length > 0">
              <q-btn
                color="primary"
                class="full-width q-mb-lg"
                label="Lưu"
                icon="save_alt"
                :loading="isUploadingText"
                @click="uploadTextData"
                style="border-radius: 10px; height: 42px; font-weight: 600;"
              />
            </div>
          </q-slide-transition>

          <div class="row items-center q-gutter-sm q-my-md">
            <div class="col"><q-separator /></div>
            <div class="text-caption text-grey-4">hoặc</div>
            <div class="col"><q-separator /></div>
          </div>

          <div class="row q-col-gutter-md">
            <div class="col-6">
              <q-btn
                class="full-width upload-option-btn"
                outline
                color="red-6"
                icon="ondemand_video"
                label="YouTube"
                @click="uploadView = 'youtube'"
                style="border-radius: 10px; height: 44px;"
              />
            </div>
            <div class="col-6">
              <q-btn
                class="full-width upload-option-btn"
                outline
                color="primary"
                icon="upload_file"
                label="Tải File"
                @click="triggerUpload"
                style="border-radius: 10px; height: 44px;"
              />
            </div>
          </div>
          <div class="text-caption text-grey-4 text-center q-mt-sm">.pdf · .docx · .txt được hỗ trợ</div>
        </q-card-section>

        <!-- YouTube View -->
        <q-card-section v-if="uploadView === 'youtube'" class="q-pt-xl q-pb-lg q-px-xl">
          <q-btn icon="arrow_back" flat dense color="grey-6" size="sm" label="Quay lại" class="absolute-top-left q-ma-sm" @click="uploadView = 'main'" />

          <div class="text-h6 text-weight-bold text-red-6 text-center q-mb-xs" style="letter-spacing: -0.3px;">Phân tích YouTube</div>
          <div class="text-caption text-grey-5 text-center q-mb-lg">AI sẽ đọc toàn bộ phụ đề video</div>

          <q-input
            v-model="youtubeLink"
            outlined
            placeholder="https://youtube.com/watch?v=..."
            class="q-mb-md"
            autofocus
            @keyup.enter="uploadYoutubeData"
            style="border-radius: 10px;"
          >
            <template v-slot:prepend>
              <q-icon name="link" color="red-4" />
            </template>
          </q-input>

          <q-btn
            color="red-6"
            class="full-width"
            label="Phân tích nội dung video"
            :loading="isUploadingYoutube"
            :disable="!youtubeLink.trim()"
            @click="uploadYoutubeData"
            style="border-radius: 10px; height: 44px; font-weight: 600;"
          />
        </q-card-section>

      </q-card>
    </q-dialog>

    <!-- ==================== DIALOG: PREVIEW ==================== -->
    <q-dialog v-model="previewDialog" transition-show="scale" transition-hide="scale">
      <q-card class="preview-dialog column" style="width: 680px; max-width: 92vw; border-radius: 20px; height: 78vh; overflow: hidden;">

        <q-card-section class="preview-header row items-center justify-between q-py-sm q-px-lg">
          <div class="row items-center q-gutter-sm overflow-hidden">
            <q-icon name="visibility" color="white" size="1.1rem" />
            <span class="text-subtitle2 text-white text-weight-bold ellipsis" style="max-width: 380px;">{{ previewDoc.filename }}</span>
          </div>
          <q-btn icon="close" flat round dense color="white" v-close-popup size="sm" />
        </q-card-section>

        <q-separator />

        <q-card-section class="col scroll q-pa-xl bg-grey-1">
          <div v-if="isLoadingPreview" class="column items-center justify-center full-height q-pa-xl text-grey-5">
            <q-spinner-mat color="primary" size="2.5rem" class="q-mb-md" />
            <div class="text-caption">Đang trích xuất nội dung...</div>
          </div>

          <div
            v-else
            class="preview-content"
            style="white-space: pre-wrap; line-height: 1.85; font-size: 0.92rem; color: #374151;"
          >
            {{ previewDoc.content || 'Tài liệu này không có nội dung văn bản để hiển thị.' }}
          </div>
        </q-card-section>

        <q-separator />
        <q-card-section class="q-pa-sm bg-white row items-center justify-between">
          <div class="text-caption text-grey-5 q-ml-sm">
            <q-icon name="info_outline" size="0.8rem" class="q-mr-xs" />
            {{ previewDoc.filetype === 'youtube' ? 'Nguồn: Video YouTube' : 'Nguồn: Tài liệu tải lên' }}
          </div>
          <q-btn flat color="primary" dense label="Đóng" v-close-popup style="font-size: 0.82rem;" />
        </q-card-section>
      </q-card>
    </q-dialog>

  </q-page>
</template>

<script setup>
import { ref, onMounted, computed, nextTick } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useQuasar } from 'quasar'
import { api } from 'boot/axios'

const route = useRoute()
const router = useRouter()
const $q = useQuasar()

const notebookId = ref(route.params.id)
const isTyping = ref(false)
const documents = ref([])
const selectedDocs = ref([])
const previewDialog = ref(false)
const isLoadingPreview = ref(false)
const previewDoc = ref({ filename: '', content: '', filetype: '' })

const parseContent = (text, sources) => {
  if (!sources || sources.length === 0 || !text) return [{ type: 'text', content: text }]
  const parts = text.split(/\[(\d+)\]/g)
  const result = []
  for (let i = 0; i < parts.length; i++) {
    if (i % 2 === 0) {
      if (parts[i]) result.push({ type: 'text', content: parts[i] })
    } else {
      const refId = parseInt(parts[i])
      const source = sources.find(s => s.ref_id === refId)
      if (source) result.push({ type: 'source', refId, docId: source.id, filename: source.filename })
      else result.push({ type: 'text', content: `[${parts[i]}]` })
    }
  }
  return result
}

const openPreview = async (docId) => {
  if (!docId) return
  previewDoc.value = { filename: 'Đang tải...', content: '', filetype: '' }
  previewDialog.value = true
  isLoadingPreview.value = true
  try {
    const response = await api.get(`/documents/${docId}`)
    previewDoc.value = response.data
  } catch (error) {
    console.error("Lỗi lấy preview:", error)
    $q.notify({ type: 'negative', message: 'Không thể xem trước nội dung tài liệu này.' })
    previewDialog.value = false
  } finally {
    isLoadingPreview.value = false
  }
}

const isAllSelected = computed({
  get: () => {
    if (documents.value.length === 0) return false
    return selectedDocs.value.length === documents.value.length
  },
  set: (val) => {
    selectedDocs.value = val ? documents.value.map(doc => doc.name) : []
  }
})

const fetchDocuments = async () => {
  try {
    const response = await api.get(`/notebooks/${notebookId.value}/documents/`)
    documents.value = response.data.documents
    selectedDocs.value = documents.value.map(doc => doc.name)
  } catch (error) {
    console.error("Lỗi lấy danh sách file:", error)
  }
}

const fetchChatHistory = async () => {
  try {
    const response = await api.get(`/notebooks/${notebookId.value}/history/`)
    const historyData = response.data.history
    if (historyData && historyData.length > 0) {
      chatHistory.value = []
      historyData.forEach(pair => {
        chatHistory.value.push({ role: 'user', content: pair.question })
        chatHistory.value.push({ role: 'ai', content: pair.answer, sources: pair.sources || [] })
      })
      scrollToBottom()
    }
  } catch (error) {
    console.error("Lỗi lấy lịch sử chat:", error)
  }
}

onMounted(() => {
  fetchDocuments()
  fetchChatHistory()
})

const chatHistory = ref([
  { role: 'ai', content: 'Để bắt đầu, vui lòng tải lên tài liệu cho notebook này.' }
])
const newMessage = ref('')
const fileInput = ref(null)
const isUploading = ref(false)
const chatScroll = ref(null)

const scrollToBottom = async () => {
  await nextTick()
  setTimeout(() => {
    if (chatScroll.value) {
      const target = chatScroll.value.$el || chatScroll.value
      target.scrollTo({ top: target.scrollHeight, behavior: 'smooth' })
    }
  }, 50)
}

const sendMessage = async () => {
  if (!newMessage.value.trim() || isTyping.value) return
  const userText = newMessage.value.trim()
  chatHistory.value.push({ role: 'user', content: userText })
  newMessage.value = ''
  isTyping.value = true
  scrollToBottom()

  if (selectedDocs.value.length === 0) {
    chatHistory.value.push({ role: 'ai', content: 'Bạn chưa chọn tài liệu. Vui lòng chọn ít nhất một tài liệu để tiếp tục.' })
    isTyping.value = false
    scrollToBottom()
    return
  }

  try {
    const payload = {
      notebook_id: parseInt(notebookId.value),
      query: userText,
      selected_docs: selectedDocs.value
    }
    const response = await api.post('/chat/', payload)
    chatHistory.value.push({
      role: 'ai',
      content: response.data.answer,
      sources: response.data.sources
    })
  } catch (error) {
    chatHistory.value.push({ role: 'ai', content: '❌ Lỗi kết nối đến Server AI. Vui lòng kiểm tra lại Backend.' })
    console.error(error)
  } finally {
    isTyping.value = false
    scrollToBottom()
  }
}

const uploadDialog = ref(false)
const uploadView = ref('main')
const pastedText = ref('')
const youtubeLink = ref('')
const isUploadingText = ref(false)
const isUploadingYoutube = ref(false)

const openUploadDialog = () => {
  uploadView.value = 'main'
  pastedText.value = ''
  youtubeLink.value = ''
  uploadDialog.value = true
}

const uploadTextData = async () => {
  if (!pastedText.value.trim()) return
  isUploadingText.value = true
  try {
    const response = await api.post('/upload-text', { notebook_id: parseInt(notebookId.value), text: pastedText.value })
    $q.notify({ type: 'positive', message: response.data.message || 'Đã lưu văn bản thành công!' })
    uploadDialog.value = false
    fetchDocuments()
  } catch (error) {
    const errorMsg = error.response?.data?.error || error.response?.data?.detail || 'Lỗi khi lưu văn bản'
    $q.notify({ type: 'negative', message: errorMsg })
  } finally {
    isUploadingText.value = false
  }
}

const uploadYoutubeData = async () => {
  if (!youtubeLink.value.trim()) return
  isUploadingYoutube.value = true
  $q.notify({ type: 'info', message: 'Đang cào phụ đề YouTube, vui lòng đợi...', timeout: 3000 })
  try {
    const response = await api.post('/upload-youtube', { notebook_id: notebookId.value, url: youtubeLink.value })
    $q.notify({ type: 'positive', message: response.data.message || 'Học xong video YouTube!' })
    uploadDialog.value = false
    fetchDocuments()
  } catch (error) {
    const errorMsg = error.response?.data?.detail || 'Lỗi khi phân tích Video YouTube'
    $q.notify({ type: 'negative', message: errorMsg })
  } finally {
    isUploadingYoutube.value = false
  }
}

const deleteDocument = (docId) => {
  $q.dialog({
    title: 'Xác nhận xóa tài liệu',
    message: 'Bạn có chắc chắn muốn xóa? Toàn bộ kiến thức AI về tài liệu này sẽ bị xóa sạch.',
    cancel: { flat: true, color: 'grey-7', label: 'Hủy' },
    ok: { color: 'negative', label: 'Xóa', unelevated: true },
    persistent: true,
  }).onOk(async () => {
    try {
      await api.delete(`/notebooks/${notebookId.value}/documents/${docId}`)
      $q.notify({ type: 'positive', message: 'Đã xóa tài liệu và dọn dẹp bộ nhớ AI!' })
      fetchDocuments()
    } catch (error) {
      const errorMsg = error.response?.data?.detail || 'Lỗi hệ thống khi xóa tài liệu'
      $q.notify({ type: 'negative', message: errorMsg })
    }
  })
}

const triggerUpload = () => { fileInput.value.click() }

const handleFileUpload = async (event) => {
  const file = event.target.files[0]
  if (!file) return
  isUploading.value = true
  $q.notify({ type: 'info', message: 'Đang tải lên và phân tích tài liệu...', timeout: 3000 })
  try {
    const formData = new FormData()
    formData.append('file', file)
    const response = await api.post(`/notebooks/${notebookId.value}/upload/`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' }
    })
    if (response.data.error) {
      $q.notify({ type: 'negative', message: response.data.error })
    } else {
      $q.notify({ type: 'positive', message: response.data.message || 'Tải tài liệu thành công!' })
      fetchDocuments()
    }
    event.target.value = ''
  } catch (error) {
    const errorMsg = error.response?.data?.detail || 'Lỗi hệ thống khi tải file'
    $q.notify({ type: 'negative', message: errorMsg })
  } finally {
    isUploading.value = false
  }
}
</script>

<style scoped>
/* =====================
   PAGE BACKGROUND
   ===================== */
.chat-page {
  background: #f0f2f5;
  padding: 16px;
}

/* =====================
   LEFT PANEL
   ===================== */
.doc-panel {
  border-radius: 16px !important;
  border: 1px solid rgba(0,0,0,0.06);
}

.doc-panel-header {
  background: linear-gradient(135deg, #1976d2 0%, #1565c0 100%);
  padding: 14px 20px;
}

.add-btn {
  background: rgba(255,255,255,0.15) !important;
  transition: background 0.2s;
}
.add-btn:hover {
  background: rgba(255,255,255,0.28) !important;
}

.select-all-bar {
  background: #fafbfc;
  padding: 6px 20px;
  border-bottom: 1px solid #f0f0f0;
}

/* Document Item */
.doc-item {
  background: #fff;
  border: 1.5px solid #e8eaed;
  border-radius: 10px;
  padding: 8px 10px;
  cursor: pointer;
  transition: all 0.18s ease;
  margin-bottom: 6px;
}
.doc-item:hover {
  border-color: #1976d2;
  background: #f0f6ff;
  transform: translateY(-1px);
  box-shadow: 0 3px 10px rgba(25, 118, 210, 0.1);
}
.doc-item--selected {
  border-color: #bbdefb;
  background: #f5f9ff;
}

.doc-icon-wrap {
  width: 28px;
  height: 28px;
  border-radius: 6px;
  background: #f5f5f5;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.doc-name {
  font-size: 0.84rem;
  font-weight: 500;
  color: #2d3748;
  max-width: 150px;
}
.doc-type {
  font-size: 0.65rem;
  font-weight: 600;
  color: #9e9e9e;
  letter-spacing: 0.5px;
  margin-top: 1px;
}

.empty-state {
  min-height: 180px;
}

/* =====================
   RIGHT PANEL
   ===================== */
.chat-panel {
  border: 1px solid rgba(0,0,0,0.06);
}

.chat-header {
  background: #fff;
  border-bottom: 1px solid #f0f0f0;
}

.back-btn {
  opacity: 0.7;
  transition: opacity 0.15s;
}
.back-btn:hover { opacity: 1; }

.online-dot {
  display: inline-block;
  width: 7px;
  height: 7px;
  border-radius: 50%;
  background: #4caf50;
  animation: pulse-green 2s infinite;
}
@keyframes pulse-green {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.4; }
}

/* =====================
   CHAT MESSAGES
   ===================== */
.chat-body {
  background: #f7f8fa;
}

.msg-row {
  display: flex;
  align-items: flex-end;
  gap: 10px;
}
.msg-row--user {
  flex-direction: row-reverse;
}
.msg-row--ai {
  flex-direction: row;
}

.msg-avatar {
  flex-shrink: 0;
  margin-bottom: 2px;
}

.msg-bubble {
  max-width: 72%;
  padding: 12px 16px;
  border-radius: 18px;
  font-size: 0.9rem;
  line-height: 1.6;
  animation: fadeInUp 0.25s ease;
}
@keyframes fadeInUp {
  from { opacity: 0; transform: translateY(8px); }
  to   { opacity: 1; transform: translateY(0); }
}

.msg-bubble--user {
  background: linear-gradient(135deg, #1976d2, #1565c0);
  color: #fff;
  border-bottom-right-radius: 4px;
  box-shadow: 0 2px 12px rgba(25, 118, 210, 0.22);
}

.msg-bubble--ai {
  background: #ffffff;
  color: #2d3748;
  border-bottom-left-radius: 4px;
  border: 1px solid #e8eaed;
  box-shadow: 0 1px 6px rgba(0,0,0,0.05);
}

/* Typing animation */
.typing-bubble {
  display: flex;
  align-items: center;
  gap: 5px;
  padding: 14px 18px;
  min-width: 56px;
}
.typing-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: #bbb;
  animation: bounce 1.3s infinite;
}
.typing-dot:nth-child(2) { animation-delay: 0.18s; }
.typing-dot:nth-child(3) { animation-delay: 0.36s; }
@keyframes bounce {
  0%, 60%, 100% { transform: translateY(0); background: #bbb; }
  30% { transform: translateY(-6px); background: #1976d2; }
}

/* Source chips below AI message */
.msg-sources {
  border-top: 1px solid #f0f0f0;
  padding-top: 8px;
  margin-top: 8px;
  flex-wrap: wrap;
}
.source-chip {
  background: #f0f6ff;
  color: #1976d2;
  font-size: 0.7rem;
  font-weight: 500;
  padding: 2px 8px;
  border-radius: 20px;
  border: 1px solid #bbdefb;
  transition: background 0.15s;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  max-width: 140px;
}
.source-chip:hover {
  background: #1976d2;
  color: #fff;
  border-color: #1976d2;
}

/* Citation badge */
.citation-badge {
  font-size: 0.68rem !important;
  padding: 1px 5px !important;
  vertical-align: super;
  transition: transform 0.1s;
}
.citation-badge:hover { transform: scale(1.15); }

/* =====================
   INPUT AREA
   ===================== */
.chat-input-area {
  background: #fff;
  border-top: 1px solid #eee;
  padding: 12px 16px 10px;
}

.chat-input-inner {
  align-items: flex-end;
}

.chat-input :deep(.q-field__control) {
  border-radius: 12px !important;
  background: #f7f8fa;
  font-size: 0.9rem;
}

.send-btn {
  box-shadow: 0 3px 12px rgba(25, 118, 210, 0.3) !important;
  transition: transform 0.1s, box-shadow 0.15s;
}
.send-btn:hover {
  transform: scale(1.06);
  box-shadow: 0 5px 18px rgba(25, 118, 210, 0.4) !important;
}
.send-btn:active { transform: scale(0.96); }

/* =====================
   DIALOGS
   ===================== */
.upload-dialog {
  box-shadow: 0 20px 60px rgba(0,0,0,0.15) !important;
}

.paste-area :deep(.q-field__control) {
  border-radius: 12px !important;
  background: #fafafa;
}

.preview-header {
  background: linear-gradient(135deg, #1976d2 0%, #1565c0 100%);
}

.preview-content {
  font-family: 'Georgia', serif;
  color: #374151;
}

/* =====================
   ROUNDED MENU
   ===================== */
.rounded-menu {
  border-radius: 12px !important;
}

/* Scrollbar */
.scroll::-webkit-scrollbar { width: 5px; }
.scroll::-webkit-scrollbar-track { background: transparent; }
.scroll::-webkit-scrollbar-thumb { background: #ddd; border-radius: 4px; }
.scroll::-webkit-scrollbar-thumb:hover { background: #bbb; }
</style>