<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import AiAgentAPI from 'dashboard/api/aiAgent';
import AiKnowledgeItemsAPI from 'dashboard/api/aiKnowledgeItems';

import BillingCard from '../billing/components/BillingCard.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import ButtonV4 from 'next/button/Button.vue';

const { t } = useI18n();

const isLoading = ref(true);
const isSaving = ref(false);
const isGenerating = ref(false);
const isPreviewing = ref(false);
const agent = ref(null);
const items = ref([]);
const newFaq = ref({ question: '', answer: '' });
const newImage = ref({ question: '', answer: '', file: null });
const previewMessage = ref('');
const previewReply = ref('');

const faqs = computed(() => items.value.filter(item => item.kind === 'faq'));
const images = computed(() =>
  items.value.filter(item => item.kind === 'image')
);
const canReplyToAllChats = computed(
  () => !!agent.value?.features?.ai_on_paid_chats
);

const errorMessage = error =>
  error?.response?.data?.message ||
  error?.response?.data?.error ||
  t('AI_AGENT.ERROR');

const fetchItems = async () => {
  const response = await AiKnowledgeItemsAPI.get();
  items.value = response.data;
};

const fetchAll = async () => {
  try {
    const response = await AiAgentAPI.get();
    agent.value = response.data;
    await fetchItems();
  } finally {
    isLoading.value = false;
  }
};

const save = async () => {
  isSaving.value = true;
  try {
    const { enabled, reply_scope, inbox_ids, business_name } = agent.value;
    const { business_info, instructions, handoff_message } = agent.value;
    const { tone, agent_name, reply_examples } = agent.value;
    const response = await AiAgentAPI.update({
      enabled,
      reply_scope,
      inbox_ids,
      business_name,
      business_info,
      instructions,
      handoff_message,
      tone,
      agent_name,
      reply_examples,
    });
    agent.value = response.data;
    useAlert(t('AI_AGENT.SAVED'));
  } catch (error) {
    useAlert(errorMessage(error));
  } finally {
    isSaving.value = false;
  }
};

const toggleInbox = id => {
  const ids = agent.value.inbox_ids || [];
  agent.value.inbox_ids = ids.includes(id)
    ? ids.filter(inboxId => inboxId !== id)
    : [...ids, id];
};

const addFaq = async () => {
  if (!newFaq.value.question || !newFaq.value.answer) return;
  try {
    await AiKnowledgeItemsAPI.create({ kind: 'faq', ...newFaq.value });
    newFaq.value = { question: '', answer: '' };
    await fetchItems();
  } catch (error) {
    useAlert(errorMessage(error));
  }
};

const imageInput = ref(null);

const addImage = async () => {
  if (!newImage.value.question || !newImage.value.file) return;
  try {
    await AiKnowledgeItemsAPI.createWithImage({
      question: newImage.value.question,
      answer: newImage.value.answer,
      image: newImage.value.file,
    });
    newImage.value = { question: '', answer: '', file: null };
    imageInput.value.value = '';
    await fetchItems();
  } catch (error) {
    useAlert(errorMessage(error));
  }
};

const onImageSelected = event => {
  [newImage.value.file] = event.target.files;
};

const toggleItem = async item => {
  await AiKnowledgeItemsAPI.update(item.id, { enabled: !item.enabled });
  await fetchItems();
};

const removeItem = async item => {
  await AiKnowledgeItemsAPI.delete(item.id);
  await fetchItems();
};

const generateFaqs = async () => {
  isGenerating.value = true;
  try {
    await save();
    const response = await AiAgentAPI.generateFaqs();
    await fetchItems();
    useAlert(t('AI_AGENT.FAQS.GENERATED', { count: response.data.created }));
  } catch (error) {
    useAlert(errorMessage(error));
  } finally {
    isGenerating.value = false;
  }
};

const runPreview = async () => {
  if (!previewMessage.value) return;
  isPreviewing.value = true;
  previewReply.value = '';
  try {
    const response = await AiAgentAPI.preview(previewMessage.value);
    previewReply.value = response.data.reply;
  } catch (error) {
    previewReply.value = errorMessage(error);
  } finally {
    isPreviewing.value = false;
  }
};

onMounted(fetchAll);
</script>

<template>
  <SettingsLayout
    :is-loading="isLoading"
    :loading-message="$t('AI_AGENT.LOADING')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('AI_AGENT.TITLE')"
        :description="$t('AI_AGENT.DESCRIPTION')"
      />
    </template>
    <template #body>
      <section v-if="agent" class="grid gap-4">
        <div
          v-if="!agent.ai_configured"
          class="px-4 py-3 rounded-lg bg-n-amber-3 text-n-amber-11 text-sm"
        >
          {{ $t('AI_AGENT.NOT_CONFIGURED') }}
        </div>

        <BillingCard
          :title="$t('AI_AGENT.STATUS.TITLE')"
          :description="$t('AI_AGENT.STATUS.DESCRIPTION')"
        >
          <template #action>
            <ButtonV4 sm solid blue :is-loading="isSaving" @click="save">
              {{ $t('AI_AGENT.SAVE') }}
            </ButtonV4>
          </template>
          <div class="px-5 grid gap-4 text-sm text-n-slate-12">
            <label class="flex items-center gap-2">
              <input v-model="agent.enabled" type="checkbox" />
              {{ $t('AI_AGENT.STATUS.ENABLED') }}
            </label>
            <div class="grid gap-2">
              <span class="font-medium">{{ $t('AI_AGENT.SCOPE.TITLE') }}</span>
              <label class="flex items-center gap-2">
                <input
                  v-model="agent.reply_scope"
                  type="radio"
                  value="ad_leads"
                />
                {{ $t('AI_AGENT.SCOPE.AD_LEADS') }}
              </label>
              <label class="flex items-center gap-2">
                <input
                  v-model="agent.reply_scope"
                  type="radio"
                  value="all"
                  :disabled="!canReplyToAllChats"
                />
                {{ $t('AI_AGENT.SCOPE.ALL') }}
              </label>
              <span class="text-xs text-n-slate-11">
                {{
                  canReplyToAllChats
                    ? $t('AI_AGENT.SCOPE.ALL_NOTE')
                    : $t('AI_AGENT.SCOPE.NOT_IN_PLAN')
                }}
              </span>
            </div>
            <div class="grid gap-2">
              <span class="font-medium">{{
                $t('AI_AGENT.INBOXES.TITLE')
              }}</span>
              <span class="text-xs text-n-slate-11">
                {{ $t('AI_AGENT.INBOXES.NOTE') }}
              </span>
              <label
                v-for="inbox in agent.inboxes"
                :key="inbox.id"
                class="flex items-center gap-2"
              >
                <input
                  type="checkbox"
                  :checked="(agent.inbox_ids || []).includes(inbox.id)"
                  @change="toggleInbox(inbox.id)"
                />
                {{ inbox.name }}
              </label>
            </div>
          </div>
        </BillingCard>

        <BillingCard
          :title="$t('AI_AGENT.SKILLS.TITLE')"
          :description="$t('AI_AGENT.SKILLS.DESCRIPTION')"
        >
          <div class="px-5 grid sm:grid-cols-2 gap-3 text-sm">
            <router-link
              :to="{ name: 'appointments_settings' }"
              class="flex items-center gap-3 p-3 rounded-lg border border-n-weak hover:bg-n-alpha-1"
            >
              <span class="i-lucide-calendar-days size-5 text-n-blue-11" />
              <span class="grid">
                <span class="font-medium text-n-slate-12">
                  {{ $t('AI_AGENT.SKILLS.APPOINTMENTS') }}
                </span>
                <span class="text-xs text-n-slate-11">
                  {{ $t('AI_AGENT.SKILLS.APPOINTMENTS_NOTE') }}
                </span>
              </span>
            </router-link>
            <router-link
              :to="{ name: 'catalog_settings' }"
              class="flex items-center gap-3 p-3 rounded-lg border border-n-weak hover:bg-n-alpha-1"
            >
              <span class="i-lucide-shopping-bag size-5 text-n-blue-11" />
              <span class="grid">
                <span class="font-medium text-n-slate-12">
                  {{ $t('AI_AGENT.SKILLS.CATALOG') }}
                </span>
                <span class="text-xs text-n-slate-11">
                  {{ $t('AI_AGENT.SKILLS.CATALOG_NOTE') }}
                </span>
              </span>
            </router-link>
          </div>
        </BillingCard>
        <BillingCard
          :title="$t('AI_AGENT.BUSINESS.TITLE')"
          :description="$t('AI_AGENT.BUSINESS.DESCRIPTION')"
        >
          <template #action>
            <ButtonV4 sm solid blue :is-loading="isSaving" @click="save">
              {{ $t('AI_AGENT.SAVE') }}
            </ButtonV4>
          </template>
          <div class="px-5 grid gap-3 text-sm">
            <label class="grid gap-1">
              {{ $t('AI_AGENT.BUSINESS.NAME') }}
              <input v-model="agent.business_name" type="text" class="w-full" />
            </label>
            <div class="grid sm:grid-cols-2 gap-3">
              <label class="grid gap-1">
                {{ $t('AI_AGENT.BUSINESS.AGENT_NAME') }}
                <input
                  v-model="agent.agent_name"
                  type="text"
                  maxlength="60"
                  class="w-full"
                  :placeholder="$t('AI_AGENT.BUSINESS.AGENT_NAME_PLACEHOLDER')"
                />
              </label>
              <label class="grid gap-1">
                {{ $t('AI_AGENT.BUSINESS.TONE') }}
                <select v-model="agent.tone" class="w-full">
                  <option value="professional">
                    {{ $t('AI_AGENT.BUSINESS.TONES.PROFESSIONAL') }}
                  </option>
                  <option value="friendly">
                    {{ $t('AI_AGENT.BUSINESS.TONES.FRIENDLY') }}
                  </option>
                  <option value="formal">
                    {{ $t('AI_AGENT.BUSINESS.TONES.FORMAL') }}
                  </option>
                </select>
              </label>
            </div>
            <label class="grid gap-1">
              {{ $t('AI_AGENT.BUSINESS.INFO') }}
              <textarea
                v-model="agent.business_info"
                rows="8"
                maxlength="8000"
                class="w-full"
                :placeholder="$t('AI_AGENT.BUSINESS.INFO_PLACEHOLDER')"
              />
            </label>
            <label class="grid gap-1">
              {{ $t('AI_AGENT.BUSINESS.INSTRUCTIONS') }}
              <textarea
                v-model="agent.instructions"
                rows="3"
                maxlength="3000"
                class="w-full"
                :placeholder="$t('AI_AGENT.BUSINESS.INSTRUCTIONS_PLACEHOLDER')"
              />
            </label>
            <label class="grid gap-1">
              {{ $t('AI_AGENT.BUSINESS.EXAMPLES') }}
              <textarea
                v-model="agent.reply_examples"
                rows="4"
                maxlength="3000"
                class="w-full"
                :placeholder="$t('AI_AGENT.BUSINESS.EXAMPLES_PLACEHOLDER')"
              />
            </label>
            <label class="grid gap-1">
              {{ $t('AI_AGENT.BUSINESS.HANDOFF') }}
              <input
                v-model="agent.handoff_message"
                type="text"
                maxlength="500"
                class="w-full"
                :placeholder="$t('AI_AGENT.BUSINESS.HANDOFF_PLACEHOLDER')"
              />
            </label>
          </div>
        </BillingCard>

        <BillingCard
          :title="$t('AI_AGENT.FAQS.TITLE')"
          :description="$t('AI_AGENT.FAQS.DESCRIPTION')"
        >
          <template #action>
            <ButtonV4
              sm
              solid
              blue
              :is-loading="isGenerating"
              @click="generateFaqs"
            >
              {{ $t('AI_AGENT.FAQS.GENERATE') }}
            </ButtonV4>
          </template>
          <div class="px-5 grid gap-3 text-sm">
            <div
              v-for="faq in faqs"
              :key="faq.id"
              class="grid gap-1 p-3 rounded-lg border border-n-weak"
              :class="{ 'opacity-50': !faq.enabled }"
            >
              <div class="font-medium text-n-slate-12">{{ faq.question }}</div>
              <div class="text-n-slate-11 whitespace-pre-line">
                {{ faq.answer }}
              </div>
              <div class="flex gap-3 text-xs">
                <button class="text-n-blue-11" @click="toggleItem(faq)">
                  {{
                    faq.enabled ? $t('AI_AGENT.DISABLE') : $t('AI_AGENT.ENABLE')
                  }}
                </button>
                <button class="text-n-ruby-11" @click="removeItem(faq)">
                  {{ $t('AI_AGENT.DELETE') }}
                </button>
              </div>
            </div>
            <div class="grid gap-2 p-3 rounded-lg bg-n-alpha-1">
              <input
                v-model="newFaq.question"
                type="text"
                class="w-full"
                :placeholder="$t('AI_AGENT.FAQS.QUESTION')"
              />
              <textarea
                v-model="newFaq.answer"
                rows="2"
                class="w-full"
                :placeholder="$t('AI_AGENT.FAQS.ANSWER')"
              />
              <ButtonV4 sm solid blue class="w-fit" @click="addFaq">
                {{ $t('AI_AGENT.FAQS.ADD') }}
              </ButtonV4>
            </div>
          </div>
        </BillingCard>

        <BillingCard
          :title="$t('AI_AGENT.IMAGES.TITLE')"
          :description="$t('AI_AGENT.IMAGES.DESCRIPTION')"
        >
          <div class="px-5 grid gap-3 text-sm">
            <div class="grid grid-cols-2 sm:grid-cols-4 gap-3">
              <div
                v-for="image in images"
                :key="image.id"
                class="grid gap-1 p-2 rounded-lg border border-n-weak"
                :class="{ 'opacity-50': !image.enabled }"
              >
                <video
                  v-if="image.image_url && image.video"
                  :src="image.image_url"
                  controls
                  preload="metadata"
                  class="w-full h-24 object-cover rounded"
                />
                <img
                  v-else-if="image.image_url"
                  :src="image.image_url"
                  class="w-full h-24 object-cover rounded"
                />
                <div class="font-medium text-n-slate-12">
                  {{ image.question }}
                </div>
                <div class="text-xs text-n-slate-11">{{ image.answer }}</div>
                <button
                  class="text-xs text-n-ruby-11 w-fit"
                  @click="removeItem(image)"
                >
                  {{ $t('AI_AGENT.DELETE') }}
                </button>
              </div>
            </div>
            <div class="grid gap-2 p-3 rounded-lg bg-n-alpha-1">
              <input
                ref="imageInput"
                type="file"
                accept="image/*,video/mp4,video/3gpp"
                @change="onImageSelected"
              />
              <input
                v-model="newImage.question"
                type="text"
                class="w-full"
                :placeholder="$t('AI_AGENT.IMAGES.NAME')"
              />
              <input
                v-model="newImage.answer"
                type="text"
                class="w-full"
                :placeholder="$t('AI_AGENT.IMAGES.DETAILS')"
              />
              <ButtonV4 sm solid blue class="w-fit" @click="addImage">
                {{ $t('AI_AGENT.IMAGES.ADD') }}
              </ButtonV4>
            </div>
          </div>
        </BillingCard>

        <BillingCard
          :title="$t('AI_AGENT.PREVIEW.TITLE')"
          :description="$t('AI_AGENT.PREVIEW.DESCRIPTION')"
        >
          <div class="px-5 grid gap-2 text-sm">
            <input
              v-model="previewMessage"
              type="text"
              class="w-full"
              :placeholder="$t('AI_AGENT.PREVIEW.PLACEHOLDER')"
              @keyup.enter="runPreview"
            />
            <ButtonV4
              sm
              solid
              blue
              class="w-fit"
              :is-loading="isPreviewing"
              @click="runPreview"
            >
              {{ $t('AI_AGENT.PREVIEW.BUTTON') }}
            </ButtonV4>
            <div
              v-if="previewReply"
              class="p-3 rounded-lg bg-n-alpha-1 whitespace-pre-line text-n-slate-12"
            >
              {{ previewReply }}
            </div>
          </div>
        </BillingCard>
      </section>
    </template>
  </SettingsLayout>
</template>
