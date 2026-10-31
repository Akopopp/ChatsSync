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

const addMessage = (role, content) => {
  if (content) messages.value.push({ role, content });
  scrollDown();
};

const handleResult = data => {
  addMessage('assistant', data.reply);
  pendingAction.value = data.pending_action || null;
};

const send = async text => {
  const content = (text || draft.value).trim();
  if (!content || isThinking.value) return;
  draft.value = '';
  pendingAction.value = null;
  addMessage('user', content);
  isThinking.value = true;
  try {
    const response = await CopilotAPI.chat(messages.value);
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

// Replies are plain text; drop any markdown bold markers the model still adds.
const parts = content =>
  content
    .replace(/\*\*/g, '')
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

    <footer class="px-6 py-3 border-t border-n-weak flex gap-2 items-end">
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
