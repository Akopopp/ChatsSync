<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import AiKnowledgeItemsAPI from 'dashboard/api/aiKnowledgeItems';
import ButtonV4 from 'next/button/Button.vue';
import Switch from 'next/switch/Switch.vue';

const props = defineProps({
  faqs: { type: Array, default: () => [] },
  isGenerating: { type: Boolean, default: false },
});

const emit = defineEmits(['refresh', 'generate']);

const { t } = useI18n();

const search = ref('');
const showForm = ref(false);
const isAdding = ref(false);
const draft = ref({ question: '', answer: '' });

const filtered = computed(() => {
  const query = search.value.trim().toLowerCase();
  if (!query) return props.faqs;
  return props.faqs.filter(faq =>
    `${faq.question} ${faq.answer}`.toLowerCase().includes(query)
  );
});

const fail = error =>
  useAlert(error?.response?.data?.message || t('AI_AGENT.ERROR'));

const add = async () => {
  if (!draft.value.question.trim() || !draft.value.answer.trim()) return;
  isAdding.value = true;
  try {
    await AiKnowledgeItemsAPI.create({ kind: 'faq', ...draft.value });
    draft.value = { question: '', answer: '' };
    showForm.value = false;
    emit('refresh');
  } catch (error) {
    fail(error);
  } finally {
    isAdding.value = false;
  }
};

const toggle = async faq => {
  try {
    await AiKnowledgeItemsAPI.update(faq.id, { enabled: !faq.enabled });
    emit('refresh');
  } catch (error) {
    fail(error);
  }
};

const remove = async faq => {
  try {
    await AiKnowledgeItemsAPI.delete(faq.id);
    emit('refresh');
  } catch (error) {
    fail(error);
  }
};
</script>

<template>
  <div class="grid gap-4">
    <div class="flex flex-wrap items-center gap-2">
      <div class="relative flex-1 min-w-48">
        <span
          class="i-lucide-search size-4 absolute ltr:left-3 rtl:right-3 top-1/2 -translate-y-1/2 text-n-slate-10"
        />
        <input
          v-model="search"
          type="search"
          class="w-full !mb-0 ltr:!pl-9 rtl:!pr-9"
          :placeholder="$t('AI_AGENT.FAQS.SEARCH')"
        />
      </div>
      <ButtonV4
        sm
        faded
        slate
        icon="i-lucide-sparkles"
        :is-loading="isGenerating"
        @click="emit('generate')"
      >
        {{ $t('AI_AGENT.FAQS.GENERATE') }}
      </ButtonV4>
      <ButtonV4 sm solid blue icon="i-lucide-plus" @click="showForm = true">
        {{ $t('AI_AGENT.FAQS.NEW') }}
      </ButtonV4>
    </div>

    <form
      v-if="showForm"
      class="grid gap-2 p-4 rounded-xl outline outline-1 outline-n-blue-7 bg-n-blue-1"
      @submit.prevent="add"
    >
      <input
        v-model="draft.question"
        type="text"
        maxlength="500"
        class="w-full !mb-0"
        :placeholder="$t('AI_AGENT.FAQS.QUESTION')"
      />
      <textarea
        v-model="draft.answer"
        rows="3"
        maxlength="2000"
        class="w-full !mb-0"
        :placeholder="$t('AI_AGENT.FAQS.ANSWER')"
      />
      <div class="flex justify-end gap-2">
        <ButtonV4 sm ghost slate type="button" @click="showForm = false">
          {{ $t('AI_AGENT.DISCARD') }}
        </ButtonV4>
        <ButtonV4 sm solid blue type="submit" :is-loading="isAdding">
          {{ $t('AI_AGENT.FAQS.ADD') }}
        </ButtonV4>
      </div>
    </form>

    <p
      v-if="!faqs.length"
      class="py-10 text-center text-sm text-n-slate-11 rounded-xl border border-dashed border-n-weak"
    >
      {{ $t('AI_AGENT.FAQS.EMPTY') }}
    </p>
    <p
      v-else-if="!filtered.length"
      class="py-6 text-center text-sm text-n-slate-11"
    >
      {{ $t('AI_AGENT.FAQS.NO_MATCH') }}
    </p>

    <ul
      v-else
      class="divide-y divide-n-weak rounded-xl outline outline-1 outline-n-weak"
    >
      <li
        v-for="faq in filtered"
        :key="faq.id"
        class="flex items-start gap-3 px-4 py-3"
      >
        <div class="grid gap-1 flex-1 min-w-0">
          <span
            class="text-sm font-medium break-words"
            :class="faq.enabled ? 'text-n-slate-12' : 'text-n-slate-10'"
          >
            {{ faq.question }}
          </span>
          <span
            class="text-sm text-n-slate-11 whitespace-pre-line break-words"
          >
            {{ faq.answer }}
          </span>
        </div>
        <div class="flex items-center gap-2 shrink-0 pt-0.5">
          <Switch
            :model-value="faq.enabled"
            :aria-label="
              faq.enabled ? $t('AI_AGENT.DISABLE') : $t('AI_AGENT.ENABLE')
            "
            @change="toggle(faq)"
          />
          <ButtonV4
            xs
            ghost
            ruby
            icon="i-lucide-trash-2"
            :title="$t('AI_AGENT.DELETE')"
            @click="remove(faq)"
          />
        </div>
      </li>
    </ul>
  </div>
</template>
