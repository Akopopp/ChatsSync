<script setup>
import { computed, nextTick, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import AiAgentAPI from 'dashboard/api/aiAgent';

defineProps({
  agentName: { type: String, default: '' },
});

const emit = defineEmits(['tested']);

const { t } = useI18n();

const message = ref('');
const turns = ref([]);
const isTyping = ref(false);
const scroller = ref(null);

const suggestions = computed(() => [
  t('AI_AGENT.PREVIEW.SUGGESTION_1'),
  t('AI_AGENT.PREVIEW.SUGGESTION_2'),
  t('AI_AGENT.PREVIEW.SUGGESTION_3'),
]);

const scrollDown = async () => {
  await nextTick();
  if (scroller.value) scroller.value.scrollTop = scroller.value.scrollHeight;
};

const ask = async text => {
  const question = (text ?? message.value).trim();
  if (!question || isTyping.value) return;
  message.value = '';
  turns.value.push({ from: 'customer', text: question });
  isTyping.value = true;
  scrollDown();
  try {
    const response = await AiAgentAPI.preview(question);
    turns.value.push({ from: 'ai', text: response.data.reply });
    emit('tested');
  } catch (error) {
    turns.value.push({
      from: 'error',
      text: error?.response?.data?.error || t('AI_AGENT.ERROR'),
    });
  } finally {
    isTyping.value = false;
    scrollDown();
  }
};
</script>

<template>
  <div
    class="flex flex-col h-full min-h-[28rem] rounded-xl outline outline-1 outline-n-weak bg-n-solid-1 overflow-hidden"
  >
    <div
      class="flex items-center justify-between gap-3 px-4 py-3 border-b border-n-weak"
    >
      <div class="flex items-center gap-2 min-w-0">
        <span
          class="grid place-items-center size-8 rounded-full bg-n-blue-3 text-n-blue-11 shrink-0"
        >
          <span class="i-lucide-sparkles size-4" />
        </span>
        <div class="grid min-w-0">
          <span class="text-sm font-medium text-n-slate-12 truncate">
            {{ $t('AI_AGENT.PREVIEW.TITLE') }}
          </span>
          <span class="text-xs text-n-slate-11 truncate">
            {{ agentName || $t('AI_AGENT.HERO.DEFAULT_NAME') }}
          </span>
        </div>
      </div>
      <button
        v-if="turns.length"
        class="text-xs text-n-slate-11 hover:text-n-slate-12 flex items-center gap-1"
        @click="turns = []"
      >
        <span class="i-lucide-rotate-ccw size-3.5" />
        {{ $t('AI_AGENT.PREVIEW.CLEAR') }}
      </button>
    </div>

    <div
      ref="scroller"
      class="flex-1 overflow-y-auto px-4 py-4 grid content-start gap-3 bg-n-alpha-1"
    >
      <div v-if="!turns.length" class="grid gap-3 py-6 text-center">
        <p class="text-sm text-n-slate-11 mx-auto max-w-xs">
          {{ $t('AI_AGENT.PREVIEW.EMPTY') }}
        </p>
        <span class="text-xs font-medium text-n-slate-10">
          {{ $t('AI_AGENT.PREVIEW.TRY') }}
        </span>
        <div class="flex flex-wrap justify-center gap-2">
          <button
            v-for="suggestion in suggestions"
            :key="suggestion"
            class="px-3 py-1.5 text-xs rounded-full bg-n-solid-1 outline outline-1 outline-n-weak text-n-slate-12 hover:outline-n-strong"
            @click="ask(suggestion)"
          >
            {{ suggestion }}
          </button>
        </div>
      </div>

      <div
        v-for="(turn, index) in turns"
        :key="index"
        class="flex"
        :class="turn.from === 'customer' ? 'justify-end' : 'justify-start'"
      >
        <div
          class="max-w-[85%] px-3 py-2 rounded-2xl text-sm whitespace-pre-line break-words"
          :class="{
            'bg-n-blue-9 text-white rounded-br-md': turn.from === 'customer',
            'bg-n-solid-1 text-n-slate-12 outline outline-1 outline-n-weak rounded-bl-md':
              turn.from === 'ai',
            'bg-n-ruby-3 text-n-ruby-11': turn.from === 'error',
          }"
        >
          {{ turn.text }}
        </div>
      </div>

      <div v-if="isTyping" class="flex justify-start">
        <div
          class="px-3 py-2 rounded-2xl rounded-bl-md text-sm bg-n-solid-1 outline outline-1 outline-n-weak text-n-slate-11 flex items-center gap-2"
        >
          <span class="i-lucide-loader-circle size-3.5 animate-spin" />
          {{ $t('AI_AGENT.PREVIEW.TYPING') }}
        </div>
      </div>
    </div>

    <form
      class="flex items-center gap-2 p-3 border-t border-n-weak"
      @submit.prevent="ask()"
    >
      <input
        v-model="message"
        type="text"
        maxlength="1000"
        class="flex-1 !mb-0 !rounded-full !px-4"
        :placeholder="$t('AI_AGENT.PREVIEW.PLACEHOLDER')"
      />
      <button
        type="submit"
        class="grid place-items-center size-9 rounded-full bg-n-blue-9 text-white disabled:opacity-50 shrink-0"
        :disabled="!message.trim() || isTyping"
        :aria-label="$t('AI_AGENT.PREVIEW.SEND')"
      >
        <span class="i-lucide-send-horizontal size-4" />
      </button>
    </form>
  </div>
</template>
