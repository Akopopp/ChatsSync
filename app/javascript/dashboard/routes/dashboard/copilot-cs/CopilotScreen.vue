<script setup>
import { computed, nextTick, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAccount } from 'dashboard/composables/useAccount';
import { useMapGetter } from 'dashboard/composables/store';
import CopilotAPI from 'dashboard/api/copilot';
import ButtonV4 from 'next/button/Button.vue';

const { t } = useI18n();
const router = useRouter();
const { accountId } = useAccount();
const currentUser = useMapGetter('getCurrentUser');

const messages = ref([]);
const draft = ref('');
const isThinking = ref(false);
const pendingAction = ref(null);
const listRef = ref(null);
const fileInput = ref(null);
const copiedIndex = ref(null);
// Pictures/videos picked but not sent yet: { file, preview, video }
const pickedFiles = ref([]);
// Files already sent in this chat: { img1: signedId }, so Copilot can save them later
const uploads = ref({});

const firstName = computed(
  () =>
    (currentUser.value?.available_name || currentUser.value?.name || '').split(
      ' '
    )[0]
);

const suggestions = computed(() => [
  {
    icon: 'i-lucide-chart-column',
    title: t('COPILOT.SUGGESTIONS.TODAY.TITLE'),
    prompt: t('COPILOT.SUGGESTIONS.TODAY.PROMPT'),
  },
  {
    icon: 'i-lucide-message-circle-warning',
    title: t('COPILOT.SUGGESTIONS.UNANSWERED.TITLE'),
    prompt: t('COPILOT.SUGGESTIONS.UNANSWERED.PROMPT'),
  },
  {
    icon: 'i-lucide-users-round',
    title: t('COPILOT.SUGGESTIONS.TEAM.TITLE'),
    prompt: t('COPILOT.SUGGESTIONS.TEAM.PROMPT'),
  },
  {
    icon: 'i-lucide-sparkles',
    title: t('COPILOT.SUGGESTIONS.FAQS.TITLE'),
    prompt: t('COPILOT.SUGGESTIONS.FAQS.PROMPT'),
  },
  {
    icon: 'i-lucide-image-plus',
    title: t('COPILOT.SUGGESTIONS.MEDIA.TITLE'),
    prompt: t('COPILOT.SUGGESTIONS.MEDIA.PROMPT'),
  },
  {
    icon: 'i-lucide-gauge',
    title: t('COPILOT.SUGGESTIONS.PLAN.TITLE'),
    prompt: t('COPILOT.SUGGESTIONS.PLAN.PROMPT'),
  },
]);

// The chat is kept in this browser, so it is still there after opening another page.
const storageKey = computed(() => `chatssync_copilot_${accountId.value}`);

const saveChat = () => {
  try {
    const saved = messages.value.map(({ role, content }) => ({
      role,
      content,
    }));
    localStorage.setItem(
      storageKey.value,
      JSON.stringify({ messages: saved.slice(-40), uploads: uploads.value })
    );
  } catch (e) {
    // Storage can be full or blocked; the chat still works without it.
  }
};

const loadChat = () => {
  try {
    const saved = JSON.parse(localStorage.getItem(storageKey.value) || '{}');
    messages.value = saved.messages || [];
    uploads.value = saved.uploads || {};
  } catch (e) {
    messages.value = [];
  }
};

const scrollDown = async () => {
  await nextTick();
  if (listRef.value) listRef.value.scrollTop = listRef.value.scrollHeight;
};

const addMessage = (role, content, images = []) => {
  if (content) messages.value.push({ role, content, images });
  saveChat();
  scrollDown();
};

const newChat = () => {
  messages.value = [];
  uploads.value = {};
  pendingAction.value = null;
  pickedFiles.value = [];
  saveChat();
};

const pickFiles = event => {
  const files = [...event.target.files].filter(
    file => file.type.startsWith('image/') || file.type.startsWith('video/')
  );
  pickedFiles.value.push(
    ...files.map(file => ({
      file,
      preview: URL.createObjectURL(file),
      video: file.type.startsWith('video/'),
    }))
  );
  event.target.value = '';
};

const removePicked = index => {
  pickedFiles.value.splice(index, 1);
};

// Uploads the picked files and returns the note Copilot reads, e.g. "img1 (shoe.jpg)".
const uploadPicked = async () => {
  const names = [];
  await Promise.all(
    pickedFiles.value.map(async ({ file }, index) => {
      const label = `img${Object.keys(uploads.value).length + index + 1}`;
      const { data } = await CopilotAPI.upload(file);
      uploads.value[label] = data.signed_id;
      names[index] = `${label} (${data.filename})`;
    })
  );
  return names.length ? `[Attached images: ${names.join(', ')}]` : '';
};

const handleResult = data => {
  addMessage('assistant', data.reply);
  pendingAction.value = data.pending_action || null;
  scrollDown();
};

const errorText = (error, fallback) =>
  error?.response?.data?.error || t(fallback);

const send = async text => {
  const typed = (text || draft.value).trim();
  if ((!typed && !pickedFiles.value.length) || isThinking.value) return;
  isThinking.value = true;
  pendingAction.value = null;
  let note = '';
  try {
    note = await uploadPicked();
  } catch (error) {
    isThinking.value = false;
    addMessage('assistant', errorText(error, 'COPILOT.UPLOAD_FAILED'));
    return;
  }
  const previews = pickedFiles.value.map(({ preview, video }) => ({
    preview,
    video,
  }));
  pickedFiles.value = [];
  draft.value = '';
  addMessage('user', [typed, note].filter(Boolean).join('\n'), previews);
  try {
    const history = messages.value.map(({ role, content }) => ({
      role,
      content,
    }));
    const response = await CopilotAPI.chat(history, uploads.value);
    handleResult(response.data);
  } catch (error) {
    addMessage('assistant', errorText(error, 'COPILOT.ERROR'));
  } finally {
    isThinking.value = false;
    scrollDown();
  }
};

const confirmAction = async () => {
  const action = pendingAction.value;
  pendingAction.value = null;
  isThinking.value = true;
  scrollDown();
  try {
    const response = await CopilotAPI.confirm(action);
    addMessage('assistant', response.data.reply);
  } catch (error) {
    addMessage('assistant', errorText(error, 'COPILOT.ERROR'));
  } finally {
    isThinking.value = false;
  }
};

const cancelAction = () => {
  pendingAction.value = null;
  addMessage('assistant', t('COPILOT.CANCELLED'));
};

const copyMessage = async (content, index) => {
  try {
    await navigator.clipboard.writeText(content);
    copiedIndex.value = index;
    setTimeout(() => {
      copiedIndex.value = null;
    }, 1500);
  } catch (e) {
    // Clipboard can be blocked by the browser; nothing else to do.
  }
};

// "#12" in a reply opens that chat.
const openChat = id => {
  router.push({
    name: 'inbox_conversation',
    params: { accountId: accountId.value, conversation_id: id },
  });
};

// Replies are plain text; drop markdown bold markers the model may still add,
// and hide the attached-files note (the files themselves are shown).
const cleanText = content =>
  content
    .replace(/\*\*/g, '')
    .replace(/\n?\[Attached images: [^\]]*\]/g, '')
    .trim();

const parts = content =>
  cleanText(content)
    .split(/(#\d+)/g)
    .map(text => ({ text, chat: /^#\d+$/.test(text) }));

const attachedCount = content =>
  (content.match(/\[Attached images: ([^\]]*)\]/)?.[1] || '')
    .split(',')
    .filter(Boolean).length;

const draftRows = computed(() =>
  Math.min(6, Math.max(1, draft.value.split('\n').length))
);

const canSend = computed(
  () =>
    !isThinking.value && (!!draft.value.trim() || !!pickedFiles.value.length)
);

const onKey = event => {
  if (event.key === 'Enter' && !event.shiftKey) {
    event.preventDefault();
    send();
  }
};

watch(accountId, loadChat);

onMounted(() => {
  loadChat();
  scrollDown();
});
</script>

<template>
  <section class="flex flex-col w-full h-full bg-n-background">
    <header
      class="flex items-center justify-between gap-3 px-4 sm:px-6 py-3 border-b border-n-weak"
    >
      <div class="flex items-center gap-3 min-w-0">
        <div
          class="flex items-center justify-center size-9 rounded-xl bg-gradient-to-br from-n-brand to-n-blue-9 text-white shrink-0"
        >
          <span class="i-lucide-sparkles size-5" />
        </div>
        <div class="min-w-0">
          <h1 class="text-base font-semibold text-n-slate-12 leading-tight">
            {{ $t('COPILOT.TITLE') }}
          </h1>
          <p class="text-xs text-n-slate-11 truncate">
            {{ $t('COPILOT.SUBTITLE') }}
          </p>
        </div>
      </div>
      <ButtonV4
        v-if="messages.length"
        sm
        faded
        slate
        icon="i-lucide-square-pen"
        :label="$t('COPILOT.NEW_CHAT')"
        :disabled="isThinking"
        @click="newChat"
      />
    </header>

    <div ref="listRef" class="flex-1 overflow-y-auto">
      <div class="mx-auto w-full max-w-3xl px-4 sm:px-6 py-6 grid gap-5">
        <div v-if="!messages.length" class="grid gap-6 pt-6 sm:pt-12">
          <div class="grid gap-3 justify-items-center text-center">
            <div
              class="flex items-center justify-center size-14 rounded-2xl bg-gradient-to-br from-n-brand to-n-blue-9 text-white shadow-sm"
            >
              <span class="i-lucide-sparkles size-7" />
            </div>
            <h2 class="text-xl sm:text-2xl font-semibold text-n-slate-12">
              {{ $t('COPILOT.GREETING', { name: firstName }) }}
            </h2>
            <p class="max-w-lg text-sm text-n-slate-11">
              {{ $t('COPILOT.DESCRIPTION') }}
            </p>
          </div>
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <button
              v-for="item in suggestions"
              :key="item.title"
              class="flex items-start gap-3 p-3 text-left rounded-xl border border-n-weak bg-n-solid-1 hover:bg-n-alpha-1 hover:border-n-strong transition-colors"
              @click="send(item.prompt)"
            >
              <span
                class="flex items-center justify-center size-8 rounded-lg bg-n-alpha-2 text-n-brand shrink-0"
              >
                <span class="size-4" :class="item.icon" />
              </span>
              <span class="grid gap-0.5 min-w-0">
                <span class="text-sm font-medium text-n-slate-12">
                  {{ item.title }}
                </span>
                <span class="text-xs text-n-slate-11 line-clamp-2">
                  {{ item.prompt }}
                </span>
              </span>
            </button>
          </div>
        </div>

        <template v-for="(message, index) in messages" :key="index">
          <div v-if="message.role === 'user'" class="flex justify-end">
            <div class="grid gap-2 justify-items-end max-w-[85%]">
              <div
                v-if="message.images?.length"
                class="flex flex-wrap justify-end gap-2"
              >
                <template v-for="media in message.images" :key="media.preview">
                  <video
                    v-if="media.video"
                    :src="media.preview"
                    controls
                    class="w-48 rounded-xl border border-n-weak"
                  />
                  <img
                    v-else
                    :src="media.preview"
                    class="size-24 object-cover rounded-xl border border-n-weak"
                  />
                </template>
              </div>
              <span
                v-else-if="attachedCount(message.content)"
                class="flex items-center gap-1 text-xs text-n-slate-11"
              >
                <span class="i-lucide-paperclip size-3" />
                {{
                  $t('COPILOT.FILES_ATTACHED', {
                    count: attachedCount(message.content),
                  })
                }}
              </span>
              <div
                v-if="cleanText(message.content)"
                class="px-4 py-2.5 rounded-2xl rounded-tr-md bg-n-brand text-white text-sm whitespace-pre-line break-words"
              >
                {{ cleanText(message.content) }}
              </div>
            </div>
          </div>

          <div v-else class="group flex items-start gap-3">
            <div
              class="flex items-center justify-center size-7 mt-0.5 rounded-lg bg-gradient-to-br from-n-brand to-n-blue-9 text-white shrink-0"
            >
              <span class="i-lucide-sparkles size-3.5" />
            </div>
            <div class="grid gap-1 min-w-0 max-w-[85%]">
              <div
                class="px-4 py-2.5 rounded-2xl rounded-tl-md bg-n-solid-2 border border-n-weak text-sm text-n-slate-12 whitespace-pre-line break-words leading-relaxed"
              >
                <template
                  v-for="(part, partIndex) in parts(message.content)"
                  :key="partIndex"
                >
                  <button
                    v-if="part.chat"
                    class="font-medium text-n-blue-11 hover:underline"
                    @click="openChat(part.text.slice(1))"
                  >
                    {{ part.text }}
                  </button>
                  <span v-else>{{ part.text }}</span>
                </template>
              </div>
              <button
                class="flex items-center gap-1 w-fit text-xs text-n-slate-10 hover:text-n-slate-12 opacity-0 group-hover:opacity-100 transition-opacity"
                @click="copyMessage(cleanText(message.content), index)"
              >
                <span
                  class="size-3"
                  :class="
                    copiedIndex === index ? 'i-lucide-check' : 'i-lucide-copy'
                  "
                />
                {{
                  copiedIndex === index
                    ? $t('COPILOT.COPIED')
                    : $t('COPILOT.COPY')
                }}
              </button>
            </div>
          </div>
        </template>

        <div v-if="pendingAction" class="flex items-start gap-3">
          <div class="size-7 shrink-0" />
          <div
            class="grid gap-3 p-4 max-w-[85%] rounded-2xl border border-n-amber-6 bg-n-amber-2"
          >
            <div class="flex items-start gap-2">
              <span
                class="i-lucide-shield-check size-4 mt-0.5 text-n-amber-11 shrink-0"
              />
              <div class="grid gap-1">
                <span class="text-sm font-medium text-n-slate-12">
                  {{ $t('COPILOT.CONFIRM_TITLE') }}
                </span>
                <span class="text-sm text-n-slate-11">
                  {{ pendingAction.summary }}
                </span>
              </div>
            </div>
            <div class="flex gap-2">
              <ButtonV4
                sm
                solid
                blue
                icon="i-lucide-check"
                :label="$t('COPILOT.CONFIRM')"
                @click="confirmAction"
              />
              <ButtonV4
                sm
                faded
                slate
                :label="$t('COPILOT.CANCEL')"
                @click="cancelAction"
              />
            </div>
          </div>
        </div>

        <div v-if="isThinking" class="flex items-center gap-3">
          <div
            class="flex items-center justify-center size-7 rounded-lg bg-gradient-to-br from-n-brand to-n-blue-9 text-white shrink-0"
          >
            <span class="i-lucide-sparkles size-3.5" />
          </div>
          <div
            class="flex items-center gap-1 px-4 py-3 rounded-2xl rounded-tl-md bg-n-solid-2 border border-n-weak"
          >
            <span class="size-1.5 rounded-full bg-n-slate-10 animate-bounce" />
            <span
              class="size-1.5 rounded-full bg-n-slate-10 animate-bounce [animation-delay:150ms]"
            />
            <span
              class="size-1.5 rounded-full bg-n-slate-10 animate-bounce [animation-delay:300ms]"
            />
          </div>
        </div>
      </div>
    </div>

    <footer class="px-4 sm:px-6 pb-4 pt-2">
      <div
        class="mx-auto w-full max-w-3xl rounded-2xl border border-n-weak bg-n-solid-1 shadow-sm focus-within:border-n-brand transition-colors"
      >
        <div v-if="pickedFiles.length" class="flex flex-wrap gap-2 px-3 pt-3">
          <div
            v-for="(item, index) in pickedFiles"
            :key="item.preview"
            class="relative"
          >
            <video
              v-if="item.video"
              :src="item.preview"
              class="size-16 object-cover rounded-lg border border-n-weak"
            />
            <img
              v-else
              :src="item.preview"
              class="size-16 object-cover rounded-lg border border-n-weak"
            />
            <span
              v-if="item.video"
              class="absolute bottom-1 left-1 i-lucide-video size-3.5 text-white"
            />
            <button
              class="absolute -top-1.5 -right-1.5 flex items-center justify-center size-5 rounded-full bg-n-slate-12 text-n-background"
              :title="$t('COPILOT.REMOVE_PICTURE')"
              @click="removePicked(index)"
            >
              <span class="i-lucide-x size-3" />
            </button>
          </div>
        </div>
        <textarea
          v-model="draft"
          :rows="draftRows"
          class="block w-full resize-none !m-0 !border-0 !bg-transparent !shadow-none !outline-none focus:!ring-0 px-4 pt-3 pb-1 text-sm text-n-slate-12 placeholder:text-n-slate-10"
          :placeholder="$t('COPILOT.PLACEHOLDER')"
          @keydown="onKey"
        />
        <div class="flex items-center justify-between gap-2 px-2 pb-2">
          <input
            ref="fileInput"
            type="file"
            accept="image/*,video/mp4,video/3gpp"
            multiple
            class="hidden"
            @change="pickFiles"
          />
          <ButtonV4
            sm
            ghost
            slate
            icon="i-lucide-paperclip"
            :title="$t('COPILOT.ATTACH')"
            :disabled="isThinking"
            @click="fileInput.click()"
          />
          <span class="hidden sm:block text-xs text-n-slate-10 truncate">
            {{ $t('COPILOT.HINT') }}
          </span>
          <ButtonV4
            sm
            solid
            blue
            icon="i-lucide-arrow-up"
            :title="$t('COPILOT.SEND')"
            :is-loading="isThinking"
            :disabled="!canSend"
            @click="send()"
          />
        </div>
      </div>
    </footer>
  </section>
</template>
