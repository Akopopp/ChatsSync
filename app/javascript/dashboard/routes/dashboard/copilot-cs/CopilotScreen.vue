<script setup>
import { nextTick, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAccount } from 'dashboard/composables/useAccount';
import CopilotAPI from 'dashboard/api/copilot';
import ButtonV4 from 'next/button/Button.vue';

const { t } = useI18n();
const router = useRouter();
const { accountId } = useAccount();

const messages = ref([]);
const draft = ref('');
const isThinking = ref(false);
const pendingAction = ref(null);
const listRef = ref(null);
const fileInput = ref(null);
// Pictures picked but not sent yet: { file, preview }
const pickedFiles = ref([]);
// Pictures already sent in this chat: { img1: signedId }, so Copilot can save them later
const uploads = ref({});

const SUGGESTIONS = [
  'COPILOT.SUGGESTIONS.TODAY',
  'COPILOT.SUGGESTIONS.UNANSWERED',
  'COPILOT.SUGGESTIONS.TEAM',
  'COPILOT.SUGGESTIONS.FAQS',
];

const scrollDown = async () => {
  await nextTick();
  if (listRef.value) listRef.value.scrollTop = listRef.value.scrollHeight;
};

const addMessage = (role, content, images = []) => {
  if (content) messages.value.push({ role, content, images });
  scrollDown();
};

const pickFiles = event => {
  const files = [...event.target.files].filter(file =>
    file.type.startsWith('image/')
  );
  pickedFiles.value.push(
    ...files.map(file => ({ file, preview: URL.createObjectURL(file) }))
  );
  event.target.value = '';
};

const removePicked = index => {
  pickedFiles.value.splice(index, 1);
};

// Uploads the picked pictures and returns the note Copilot reads, e.g. "img1 (shoe.jpg)".
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
};

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
    addMessage(
      'assistant',
      error?.response?.data?.error || t('COPILOT.UPLOAD_FAILED')
    );
    return;
  }
  const previews = pickedFiles.value.map(item => item.preview);
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
    addMessage('assistant', error?.response?.data?.error || t('COPILOT.ERROR'));
  } finally {
    isThinking.value = false;
    scrollDown();
  }
};

const confirmAction = async () => {
  const action = pendingAction.value;
  pendingAction.value = null;
  isThinking.value = true;
  try {
    const response = await CopilotAPI.confirm(action);
    addMessage('assistant', response.data.reply);
  } catch (error) {
    addMessage('assistant', error?.response?.data?.error || t('COPILOT.ERROR'));
  } finally {
    isThinking.value = false;
  }
};

const cancelAction = () => {
  pendingAction.value = null;
  addMessage('assistant', t('COPILOT.CANCELLED'));
};

// "#12" in a reply opens that chat.
const openChat = event => {
  const match = event.target?.textContent?.match(/^#(\d+)$/);
  if (!match) return;
  router.push({
    name: 'inbox_conversation',
    params: { accountId: accountId.value, conversation_id: match[1] },
  });
};

// Replies are plain text; drop any markdown bold markers the model still adds,
// and hide the attached-pictures note (the pictures themselves are shown).
const parts = content =>
  content
    .replace(/\*\*/g, '')
    .replace(/\n?\[Attached images: [^\]]*\]/g, '')
    .split(/(#\d+)/g)
    .map(text => ({ text, chat: /^#\d+$/.test(text) }));

const onKey = event => {
  if (event.key === 'Enter' && !event.shiftKey) {
    event.preventDefault();
    send();
  }
};
</script>

<template>
  <section class="flex flex-col w-full h-full bg-n-background">
    <header class="px-6 py-4 border-b border-n-weak">
      <h1 class="text-lg font-medium text-n-slate-12">
        {{ $t('COPILOT.TITLE') }}
      </h1>
      <p class="text-sm text-n-slate-11">{{ $t('COPILOT.DESCRIPTION') }}</p>
    </header>

    <div
      ref="listRef"
      class="flex-1 overflow-y-auto px-6 py-4 grid content-start gap-3"
    >
      <div v-if="!messages.length" class="grid gap-2">
        <p class="text-sm text-n-slate-11">{{ $t('COPILOT.TRY') }}</p>
        <button
          v-for="key in SUGGESTIONS"
          :key="key"
          class="text-left text-sm px-3 py-2 rounded-lg border border-n-weak hover:bg-n-alpha-1 text-n-slate-12"
          @click="send($t(key))"
        >
          {{ $t(key) }}
        </button>
      </div>

      <div
        v-for="(message, index) in messages"
        :key="index"
        class="max-w-2xl px-4 py-2 rounded-xl text-sm whitespace-pre-line"
        :class="
          message.role === 'user'
            ? 'justify-self-end bg-n-brand text-white'
            : 'justify-self-start bg-n-alpha-2 text-n-slate-12'
        "
      >
        <div v-if="message.images?.length" class="flex flex-wrap gap-2 mb-1">
          <img
            v-for="image in message.images"
            :key="image"
            :src="image"
            class="size-20 object-cover rounded-lg"
          />
        </div>
        <template
          v-for="(part, partIndex) in parts(message.content)"
          :key="partIndex"
        >
          <button
            v-if="part.chat && message.role === 'assistant'"
            class="text-n-blue-11 underline"
            @click="openChat"
          >
            {{ part.text }}
          </button>
          <span v-else>{{ part.text }}</span>
        </template>
      </div>

      <div
        v-if="pendingAction"
        class="max-w-2xl justify-self-start grid gap-2 p-3 rounded-xl border border-n-amber-7 bg-n-amber-2"
      >
        <span class="text-sm text-n-slate-12">{{ pendingAction.summary }}</span>
        <div class="flex gap-2">
          <ButtonV4 sm solid blue @click="confirmAction">
            {{ $t('COPILOT.CONFIRM') }}
          </ButtonV4>
          <ButtonV4 sm faded slate @click="cancelAction">
            {{ $t('COPILOT.CANCEL') }}
          </ButtonV4>
        </div>
      </div>

      <div v-if="isThinking" class="justify-self-start text-sm text-n-slate-11">
        {{ $t('COPILOT.THINKING') }}
      </div>
    </div>

    <div v-if="pickedFiles.length" class="px-6 pt-3 flex flex-wrap gap-2">
      <div
        v-for="(item, index) in pickedFiles"
        :key="item.preview"
        class="relative"
      >
        <img :src="item.preview" class="size-16 object-cover rounded-lg" />
        <button
          class="absolute -top-2 -right-2 size-5 rounded-full bg-n-slate-12 text-n-background text-xs"
          :title="$t('COPILOT.REMOVE_PICTURE')"
          @click="removePicked(index)"
        >
          <span class="i-lucide-x size-3" />
        </button>
      </div>
    </div>

    <footer class="px-6 py-3 border-t border-n-weak flex gap-2 items-end">
      <input
        ref="fileInput"
        type="file"
        accept="image/*"
        multiple
        class="hidden"
        @change="pickFiles"
      />
      <ButtonV4
        faded
        slate
        icon="i-lucide-image-plus"
        :title="$t('COPILOT.ATTACH')"
        :disabled="isThinking"
        @click="fileInput.click()"
      />
      <textarea
        v-model="draft"
        rows="2"
        class="flex-1 resize-none"
        :placeholder="$t('COPILOT.PLACEHOLDER')"
        @keydown="onKey"
      />
      <ButtonV4 solid blue :is-loading="isThinking" @click="send()">
        {{ $t('COPILOT.SEND') }}
      </ButtonV4>
    </footer>
  </section>
</template>
