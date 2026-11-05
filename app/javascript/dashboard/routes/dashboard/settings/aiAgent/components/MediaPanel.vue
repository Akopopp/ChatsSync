<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import AiKnowledgeItemsAPI from 'dashboard/api/aiKnowledgeItems';
import ButtonV4 from 'next/button/Button.vue';
import Switch from 'next/switch/Switch.vue';

defineProps({
  media: { type: Array, default: () => [] },
});

const emit = defineEmits(['refresh']);

const { t } = useI18n();

const fileInput = ref(null);
const isAdding = ref(false);
const draft = ref({ question: '', answer: '', file: null });

const fail = error =>
  useAlert(error?.response?.data?.message || t('AI_AGENT.ERROR'));

const onFile = event => {
  [draft.value.file] = event.target.files;
};

const add = async () => {
  if (!draft.value.question.trim() || !draft.value.file) return;
  isAdding.value = true;
  try {
    await AiKnowledgeItemsAPI.createWithImage({
      question: draft.value.question,
      answer: draft.value.answer,
      image: draft.value.file,
    });
    draft.value = { question: '', answer: '', file: null };
    fileInput.value.value = '';
    emit('refresh');
  } catch (error) {
    fail(error);
  } finally {
    isAdding.value = false;
  }
};

const toggle = async item => {
  try {
    await AiKnowledgeItemsAPI.update(item.id, { enabled: !item.enabled });
    emit('refresh');
  } catch (error) {
    fail(error);
  }
};

const remove = async item => {
  try {
    await AiKnowledgeItemsAPI.delete(item.id);
    emit('refresh');
  } catch (error) {
    fail(error);
  }
};
</script>

<template>
  <div class="grid gap-4">
    <p class="text-sm text-n-slate-11">
      {{ $t('AI_AGENT.IMAGES.DESCRIPTION') }}
    </p>

    <form
      class="grid sm:grid-cols-[10rem_minmax(0,1fr)] gap-3 p-4 rounded-xl outline outline-1 outline-n-weak bg-n-alpha-1"
      @submit.prevent="add"
    >
      <label
        class="grid place-items-center gap-1 h-28 sm:h-full min-h-28 rounded-lg border border-dashed border-n-strong bg-n-solid-1 cursor-pointer text-center px-2 hover:border-n-blue-9"
      >
        <span class="i-lucide-image-plus size-6 text-n-slate-10" />
        <span class="text-xs text-n-slate-11 break-all line-clamp-2">
          {{ draft.file ? draft.file.name : $t('AI_AGENT.IMAGES.CHOOSE') }}
        </span>
        <input
          ref="fileInput"
          type="file"
          class="sr-only"
          accept="image/*,video/mp4,video/3gpp"
          @change="onFile"
        />
      </label>
      <div class="grid gap-2 content-start">
        <span class="text-sm font-medium text-n-slate-12">
          {{ $t('AI_AGENT.IMAGES.NEW') }}
        </span>
        <input
          v-model="draft.question"
          type="text"
          maxlength="200"
          class="w-full !mb-0"
          :placeholder="$t('AI_AGENT.IMAGES.NAME')"
        />
        <input
          v-model="draft.answer"
          type="text"
          maxlength="500"
          class="w-full !mb-0"
          :placeholder="$t('AI_AGENT.IMAGES.DETAILS')"
        />
        <ButtonV4
          sm
          solid
          blue
          type="submit"
          class="w-fit"
          icon="i-lucide-upload"
          :is-loading="isAdding"
          :disabled="!draft.file || !draft.question.trim()"
        >
          {{ $t('AI_AGENT.IMAGES.ADD') }}
        </ButtonV4>
      </div>
    </form>

    <p
      v-if="!media.length"
      class="py-10 text-center text-sm text-n-slate-11 rounded-xl border border-dashed border-n-weak"
    >
      {{ $t('AI_AGENT.IMAGES.EMPTY') }}
    </p>

    <div v-else class="grid grid-cols-2 md:grid-cols-3 gap-3">
      <div
        v-for="item in media"
        :key="item.id"
        class="grid content-start rounded-xl outline outline-1 outline-n-weak overflow-hidden bg-n-solid-1"
      >
        <div class="relative aspect-[4/3] bg-n-alpha-2">
          <video
            v-if="item.image_url && item.video"
            :src="item.image_url"
            controls
            preload="metadata"
            class="absolute inset-0 size-full object-cover"
          />
          <img
            v-else-if="item.image_url"
            :src="item.image_url"
            :alt="item.question"
            class="absolute inset-0 size-full object-cover"
            :class="{ 'opacity-40': !item.enabled }"
          />
        </div>
        <div class="grid gap-1 p-3">
          <span class="text-sm font-medium text-n-slate-12 truncate">
            {{ item.question }}
          </span>
          <span class="text-xs text-n-slate-11 line-clamp-2 min-h-8">
            {{ item.answer }}
          </span>
          <div class="flex items-center justify-between pt-1">
            <Switch
              :model-value="item.enabled"
              :aria-label="
                item.enabled ? $t('AI_AGENT.DISABLE') : $t('AI_AGENT.ENABLE')
              "
              @change="toggle(item)"
            />
            <ButtonV4
              xs
              ghost
              ruby
              icon="i-lucide-trash-2"
              :title="$t('AI_AGENT.DELETE')"
              @click="remove(item)"
            />
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
