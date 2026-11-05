<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import AiAgentAPI from 'dashboard/api/aiAgent';
import AiKnowledgeItemsAPI from 'dashboard/api/aiKnowledgeItems';
import PlanUsageAPI from 'dashboard/api/planUsage';

import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import ButtonV4 from 'next/button/Button.vue';
import Switch from 'next/switch/Switch.vue';
import Checkbox from 'next/checkbox/Checkbox.vue';
import RadioCard from 'next/radioCard/RadioCard.vue';
import TabBar from 'next/tabbar/TabBar.vue';
import PreviewChat from './components/PreviewChat.vue';
import FaqsPanel from './components/FaqsPanel.vue';
import MediaPanel from './components/MediaPanel.vue';

const { t } = useI18n();

const SAVE_FIELDS = [
  'enabled',
  'reply_scope',
  'inbox_ids',
  'business_name',
  'business_info',
  'instructions',
  'handoff_message',
  'tone',
  'agent_name',
  'reply_examples',
  'policies',
  'always_rules',
  'never_rules',
  'handoff_rules',
  'goal',
  'lead_fields',
  'reply_length',
  'use_emoji',
  'reply_language',
];
const POLICY_KEYS = [
  'delivery',
  'payment',
  'returns',
  'warranty',
  'timings',
  'location',
];
const GOALS = ['answer', 'sell', 'book', 'leads'];
const TONES = ['professional', 'friendly', 'formal'];
const LANGUAGES = ['match', 'roman_urdu', 'english', 'urdu'];
const CHANNEL_ICONS = {
  'Channel::Whatsapp': 'i-ri-whatsapp-line',
  'Channel::FacebookPage': 'i-ri-messenger-line',
  'Channel::Instagram': 'i-ri-instagram-line',
  'Channel::WebWidget': 'i-lucide-globe',
  'Channel::Api': 'i-lucide-plug',
};

const isLoading = ref(true);
const isSaving = ref(false);
const isGenerating = ref(false);
const agent = ref(null);
const saved = ref('');
const items = ref([]);
const usage = ref({});
const activeTab = ref(0);
const tested = ref(false);

const pick = value =>
  JSON.stringify(Object.fromEntries(SAVE_FIELDS.map(key => [key, value[key]])));

const faqs = computed(() => items.value.filter(item => item.kind === 'faq'));
const media = computed(() => items.value.filter(item => item.kind === 'image'));
const isDirty = computed(() => !!agent.value && pick(agent.value) !== saved.value);
const canReplyToAllChats = computed(
  () => !!agent.value?.features?.ai_on_paid_chats
);

const tabs = computed(() => [
  { key: 'setup', label: t('AI_AGENT.TABS.SETUP') },
  { key: 'business', label: t('AI_AGENT.TABS.BUSINESS') },
  { key: 'behaviour', label: t('AI_AGENT.TABS.BEHAVIOUR') },
  { key: 'faqs', label: t('AI_AGENT.TABS.FAQS'), count: faqs.value.length },
  { key: 'media', label: t('AI_AGENT.TABS.MEDIA'), count: media.value.length },
]);
const currentTab = computed(() => tabs.value[activeTab.value].key);

const checklist = computed(() => {
  if (!agent.value) return [];
  return [
    {
      key: 'BUSINESS',
      done: (agent.value.business_info || '').trim().length >= 80,
      tab: 1,
    },
    { key: 'FAQS', done: faqs.value.length >= 5, tab: 3 },
    { key: 'MEDIA', done: media.value.length > 0, tab: 4 },
    { key: 'TEST', done: tested.value, tab: null },
    { key: 'ENABLE', done: !!agent.value.enabled, tab: 0 },
  ];
});
const doneCount = computed(
  () => checklist.value.filter(step => step.done).length
);

const usageStat = key => usage.value?.[key] || { used: 0, limit: null };
const formatNumber = value => Number(value || 0).toLocaleString();

const errorMessage = error =>
  error?.response?.data?.message ||
  error?.response?.data?.error ||
  t('AI_AGENT.ERROR');

const fetchItems = async () => {
  const response = await AiKnowledgeItemsAPI.get();
  items.value = response.data;
};

const fetchUsage = async () => {
  try {
    const response = await PlanUsageAPI.get();
    usage.value = response.data.usage || {};
  } catch {
    usage.value = {};
  }
};

const setAgent = data => {
  agent.value = { ...data, policies: { ...(data.policies || {}) } };
  saved.value = pick(agent.value);
};

const fetchAll = async () => {
  try {
    const response = await AiAgentAPI.get();
    setAgent(response.data);
    await Promise.all([fetchItems(), fetchUsage()]);
  } finally {
    isLoading.value = false;
  }
};

const save = async () => {
  isSaving.value = true;
  try {
    const response = await AiAgentAPI.update(JSON.parse(pick(agent.value)));
    setAgent(response.data);
    useAlert(t('AI_AGENT.SAVED'));
  } catch (error) {
    useAlert(errorMessage(error));
  } finally {
    isSaving.value = false;
  }
};

const discard = () => {
  agent.value = { ...agent.value, ...JSON.parse(saved.value) };
};

// The on/off switch saves at once, without saving other unsaved edits.
const toggleEnabled = async () => {
  const { enabled } = agent.value;
  try {
    await AiAgentAPI.update({ enabled });
    saved.value = JSON.stringify({ ...JSON.parse(saved.value), enabled });
    useAlert(t('AI_AGENT.SAVED'));
  } catch (error) {
    agent.value.enabled = !enabled;
    useAlert(errorMessage(error));
  }
};

const toggleInbox = id => {
  const ids = agent.value.inbox_ids || [];
  agent.value.inbox_ids = ids.includes(id)
    ? ids.filter(inboxId => inboxId !== id)
    : [...ids, id];
};

const generateFaqs = async () => {
  isGenerating.value = true;
  try {
    if (isDirty.value) await save();
    const response = await AiAgentAPI.generateFaqs();
    await fetchItems();
    useAlert(t('AI_AGENT.FAQS.GENERATED', { count: response.data.created }));
  } catch (error) {
    useAlert(errorMessage(error));
  } finally {
    isGenerating.value = false;
  }
};

const openStep = step => {
  if (step.tab !== null) activeTab.value = step.tab;
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
      <section v-if="agent" class="grid gap-5 pb-20">
        <div
          v-if="!agent.ai_configured"
          class="flex items-center gap-2 px-4 py-3 rounded-xl bg-n-amber-3 text-n-amber-11 text-sm"
        >
          <span class="i-lucide-triangle-alert size-4 shrink-0" />
          {{ $t('AI_AGENT.NOT_CONFIGURED') }}
        </div>

        <!-- Status, usage and setup progress -->
        <div
          class="grid gap-5 p-5 rounded-2xl outline outline-1 outline-n-weak bg-n-solid-1"
        >
          <div class="flex flex-wrap items-center justify-between gap-4">
            <div class="flex items-center gap-3 min-w-0">
              <span
                class="grid place-items-center size-12 rounded-2xl shrink-0"
                :class="
                  agent.enabled
                    ? 'bg-n-teal-3 text-n-teal-11'
                    : 'bg-n-alpha-2 text-n-slate-10'
                "
              >
                <span class="i-lucide-bot size-6" />
              </span>
              <div class="grid min-w-0">
                <div class="flex items-center gap-2">
                  <h2
                    class="text-base font-semibold text-n-slate-12 truncate"
                  >
                    {{ agent.agent_name || $t('AI_AGENT.HERO.DEFAULT_NAME') }}
                  </h2>
                  <span
                    class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium"
                    :class="
                      agent.enabled
                        ? 'bg-n-teal-3 text-n-teal-11'
                        : 'bg-n-alpha-2 text-n-slate-11'
                    "
                  >
                    <span
                      class="size-1.5 rounded-full"
                      :class="agent.enabled ? 'bg-n-teal-9' : 'bg-n-slate-9'"
                    />
                    {{
                      agent.enabled
                        ? $t('AI_AGENT.HERO.LIVE')
                        : $t('AI_AGENT.HERO.OFF')
                    }}
                  </span>
                </div>
                <span class="text-sm text-n-slate-11 truncate">
                  {{ agent.business_name }}
                </span>
              </div>
            </div>
            <label
              class="flex items-center gap-3 px-3 py-2 rounded-xl bg-n-alpha-1 cursor-pointer"
            >
              <span class="text-sm font-medium text-n-slate-12">
                {{ $t('AI_AGENT.HERO.SWITCH') }}
              </span>
              <Switch v-model="agent.enabled" @change="toggleEnabled" />
            </label>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-3 gap-3">
            <div
              v-for="stat in [
                { key: 'ai_replies_daily', label: 'REPLIES_TODAY' },
                { key: 'ai_replies_monthly', label: 'REPLIES_MONTH' },
              ]"
              :key="stat.key"
              class="grid gap-1 p-3 rounded-xl bg-n-alpha-1"
            >
              <span class="text-xs text-n-slate-11">
                {{ $t(`AI_AGENT.HERO.${stat.label}`) }}
              </span>
              <span
                class="text-xl font-semibold text-n-slate-12 tabular-nums"
              >
                {{ formatNumber(usageStat(stat.key).used) }}
              </span>
              <span class="text-xs text-n-slate-10">
                {{
                  usageStat(stat.key).limit
                    ? $t('AI_AGENT.HERO.OF_LIMIT', {
                        limit: formatNumber(usageStat(stat.key).limit),
                      })
                    : $t('AI_AGENT.HERO.NO_LIMIT')
                }}
              </span>
            </div>
            <div class="grid gap-1 p-3 rounded-xl bg-n-alpha-1">
              <span class="text-xs text-n-slate-11">
                {{ $t('AI_AGENT.HERO.KNOWLEDGE') }}
              </span>
              <span
                class="text-xl font-semibold text-n-slate-12 tabular-nums"
              >
                {{ formatNumber(faqs.length + media.length) }}
              </span>
              <span class="text-xs text-n-slate-10">
                {{
                  $t('AI_AGENT.HERO.KNOWLEDGE_VALUE', {
                    faqs: faqs.length,
                    media: media.length,
                  })
                }}
              </span>
            </div>
          </div>

          <div v-if="doneCount < checklist.length" class="grid gap-3">
            <div class="flex items-center justify-between gap-3">
              <span class="text-sm font-medium text-n-slate-12">
                {{ $t('AI_AGENT.CHECKLIST.TITLE') }}
              </span>
              <span class="text-xs text-n-slate-11 tabular-nums">
                {{
                  $t('AI_AGENT.CHECKLIST.PROGRESS', {
                    done: doneCount,
                    total: checklist.length,
                  })
                }}
              </span>
            </div>
            <div class="h-1.5 rounded-full bg-n-alpha-2 overflow-hidden">
              <div
                class="h-full rounded-full bg-n-teal-9 transition-all duration-500"
                :style="{ width: `${(doneCount / checklist.length) * 100}%` }"
              />
            </div>
            <div class="flex flex-wrap gap-2">
              <button
                v-for="step in checklist"
                :key="step.key"
                class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs outline outline-1"
                :class="
                  step.done
                    ? 'outline-transparent bg-n-teal-3 text-n-teal-11'
                    : 'outline-n-weak text-n-slate-12 hover:outline-n-strong'
                "
                @click="openStep(step)"
              >
                <span
                  class="size-3.5"
                  :class="step.done ? 'i-lucide-circle-check' : 'i-lucide-circle'"
                />
                {{ $t(`AI_AGENT.CHECKLIST.${step.key}`) }}
              </button>
            </div>
          </div>
        </div>

        <div
          class="grid gap-5 lg:grid-cols-[minmax(0,1fr)_20rem] items-start"
        >
          <div class="grid gap-4 min-w-0">
            <div class="overflow-x-auto">
              <TabBar
                :tabs="tabs"
                :initial-active-tab="activeTab"
                @tab-changed="tab => (activeTab = tabs.indexOf(tab))"
              />
            </div>

            <!-- Setup -->
            <div v-if="currentTab === 'setup'" class="grid gap-5">
              <div class="grid gap-3">
                <h3 class="text-sm font-medium text-n-slate-12">
                  {{ $t('AI_AGENT.SCOPE.TITLE') }}
                </h3>
                <div class="grid sm:grid-cols-2 gap-3">
                  <RadioCard
                    id="scope-ad-leads"
                    :label="$t('AI_AGENT.SCOPE.AD_TITLE')"
                    :description="$t('AI_AGENT.SCOPE.AD_LEADS_NOTE')"
                    :is-active="agent.reply_scope === 'ad_leads'"
                    @select="agent.reply_scope = 'ad_leads'"
                  />
                  <RadioCard
                    id="scope-all"
                    :label="$t('AI_AGENT.SCOPE.ALL_TITLE')"
                    :description="$t('AI_AGENT.SCOPE.ALL_NOTE')"
                    :is-active="agent.reply_scope === 'all'"
                    :disabled="!canReplyToAllChats"
                    :disabled-label="$t('AI_AGENT.SCOPE.NOT_IN_PLAN_SHORT')"
                    :disabled-message="$t('AI_AGENT.SCOPE.NOT_IN_PLAN')"
                    @select="agent.reply_scope = 'all'"
                  />
                </div>
              </div>

              <div class="grid gap-3">
                <div class="grid gap-0.5">
                  <h3 class="text-sm font-medium text-n-slate-12">
                    {{ $t('AI_AGENT.INBOXES.TITLE') }}
                  </h3>
                  <p class="text-xs text-n-slate-11">
                    {{ $t('AI_AGENT.INBOXES.NOTE') }}
                  </p>
                </div>
                <div
                  class="divide-y divide-n-weak rounded-xl outline outline-1 outline-n-weak"
                >
                  <label
                    v-for="inbox in agent.inboxes"
                    :key="inbox.id"
                    class="flex items-center gap-3 px-4 py-3 cursor-pointer hover:bg-n-alpha-1"
                  >
                    <Checkbox
                      :model-value="(agent.inbox_ids || []).includes(inbox.id)"
                      @change="toggleInbox(inbox.id)"
                    />
                    <span
                      class="size-4 text-n-slate-11"
                      :class="
                        CHANNEL_ICONS[inbox.channel_type] || 'i-lucide-inbox'
                      "
                    />
                    <span class="text-sm text-n-slate-12 truncate">
                      {{ inbox.name }}
                    </span>
                  </label>
                </div>
              </div>

              <div class="grid gap-3">
                <div class="grid gap-0.5">
                  <h3 class="text-sm font-medium text-n-slate-12">
                    {{ $t('AI_AGENT.SKILLS.TITLE') }}
                  </h3>
                  <p class="text-xs text-n-slate-11">
                    {{ $t('AI_AGENT.SKILLS.DESCRIPTION') }}
                  </p>
                </div>
                <div class="grid sm:grid-cols-2 gap-3">
                  <router-link
                    v-for="skill in [
                      {
                        route: 'appointments_settings',
                        icon: 'i-lucide-calendar-days',
                        key: 'APPOINTMENTS',
                      },
                      {
                        route: 'catalog_settings',
                        icon: 'i-lucide-shopping-bag',
                        key: 'CATALOG',
                      },
                    ]"
                    :key="skill.key"
                    :to="{ name: skill.route }"
                    class="group flex items-start gap-3 p-4 rounded-xl outline outline-1 outline-n-weak hover:outline-n-strong bg-n-solid-1"
                  >
                    <span
                      class="grid place-items-center size-9 rounded-lg bg-n-blue-3 text-n-blue-11 shrink-0"
                    >
                      <span class="size-5" :class="skill.icon" />
                    </span>
                    <span class="grid gap-0.5 min-w-0">
                      <span class="text-sm font-medium text-n-slate-12">
                        {{ $t(`AI_AGENT.SKILLS.${skill.key}`) }}
                      </span>
                      <span class="text-xs text-n-slate-11">
                        {{ $t(`AI_AGENT.SKILLS.${skill.key}_NOTE`) }}
                      </span>
                      <span
                        class="text-xs font-medium text-n-blue-11 flex items-center gap-1 pt-1"
                      >
                        {{ $t('AI_AGENT.SKILLS.OPEN') }}
                        <span
                          class="i-lucide-arrow-right size-3 transition-transform group-hover:translate-x-0.5"
                        />
                      </span>
                    </span>
                  </router-link>
                </div>
              </div>
            </div>

            <!-- Business -->
            <div v-else-if="currentTab === 'business'" class="grid gap-4">
              <p class="text-sm text-n-slate-11">
                {{ $t('AI_AGENT.BUSINESS.DESCRIPTION') }}
              </p>
              <div class="grid sm:grid-cols-2 gap-3">
                <label class="grid gap-1 text-sm text-n-slate-12">
                  {{ $t('AI_AGENT.BUSINESS.NAME') }}
                  <input
                    v-model="agent.business_name"
                    type="text"
                    maxlength="120"
                    class="w-full !mb-0"
                  />
                </label>
                <label class="grid gap-1 text-sm text-n-slate-12">
                  {{ $t('AI_AGENT.BUSINESS.AGENT_NAME') }}
                  <input
                    v-model="agent.agent_name"
                    type="text"
                    maxlength="60"
                    class="w-full !mb-0"
                    :placeholder="$t('AI_AGENT.BUSINESS.AGENT_NAME_PLACEHOLDER')"
                  />
                </label>
              </div>
              <div class="grid gap-2">
                <span class="text-sm text-n-slate-12">
                  {{ $t('AI_AGENT.BUSINESS.TONE') }}
                </span>
                <div class="flex flex-wrap gap-2">
                  <button
                    v-for="tone in TONES"
                    :key="tone"
                    class="px-3 py-1.5 rounded-lg text-sm outline outline-1"
                    :class="
                      agent.tone === tone
                        ? 'outline-n-blue-9 bg-n-blue-2 text-n-blue-11'
                        : 'outline-n-weak text-n-slate-12 hover:outline-n-strong'
                    "
                    @click="agent.tone = tone"
                  >
                    {{ $t(`AI_AGENT.BUSINESS.TONES.${tone.toUpperCase()}`) }}
                  </button>
                </div>
              </div>
              <label class="grid gap-1 text-sm text-n-slate-12">
                <span class="flex items-center justify-between gap-2">
                  {{ $t('AI_AGENT.BUSINESS.INFO') }}
                  <span class="text-xs text-n-slate-10 tabular-nums">
                    {{ (agent.business_info || '').length }} / 8000
                  </span>
                </span>
                <textarea
                  v-model="agent.business_info"
                  rows="10"
                  maxlength="8000"
                  class="w-full !mb-0"
                  :placeholder="$t('AI_AGENT.BUSINESS.INFO_PLACEHOLDER')"
                />
              </label>
              <label class="grid gap-1 text-sm text-n-slate-12">
                {{ $t('AI_AGENT.BUSINESS.INSTRUCTIONS') }}
                <textarea
                  v-model="agent.instructions"
                  rows="3"
                  maxlength="3000"
                  class="w-full !mb-0"
                  :placeholder="$t('AI_AGENT.BUSINESS.INSTRUCTIONS_PLACEHOLDER')"
                />
              </label>
              <label class="grid gap-1 text-sm text-n-slate-12">
                {{ $t('AI_AGENT.BUSINESS.EXAMPLES') }}
                <textarea
                  v-model="agent.reply_examples"
                  rows="4"
                  maxlength="3000"
                  class="w-full !mb-0"
                  :placeholder="$t('AI_AGENT.BUSINESS.EXAMPLES_PLACEHOLDER')"
                />
              </label>
              <label class="grid gap-1 text-sm text-n-slate-12">
                {{ $t('AI_AGENT.BUSINESS.HANDOFF') }}
                <input
                  v-model="agent.handoff_message"
                  type="text"
                  maxlength="500"
                  class="w-full !mb-0"
                  :placeholder="$t('AI_AGENT.BUSINESS.HANDOFF_PLACEHOLDER')"
                />
              </label>
            </div>

            <!-- Behaviour -->
            <div v-else-if="currentTab === 'behaviour'" class="grid gap-5">
              <div class="grid gap-2">
                <span class="text-sm font-medium text-n-slate-12">
                  {{ $t('AI_AGENT.PROFILE.GOAL') }}
                </span>
                <div class="grid sm:grid-cols-2 gap-2">
                  <button
                    v-for="goal in GOALS"
                    :key="goal"
                    class="flex items-center gap-2 px-3 py-2.5 rounded-xl text-sm text-start outline outline-1"
                    :class="
                      agent.goal === goal
                        ? 'outline-n-blue-9 bg-n-blue-2 text-n-blue-11'
                        : 'outline-n-weak text-n-slate-12 hover:outline-n-strong'
                    "
                    @click="agent.goal = goal"
                  >
                    <span
                      class="size-4 shrink-0"
                      :class="
                        agent.goal === goal
                          ? 'i-lucide-circle-dot'
                          : 'i-lucide-circle'
                      "
                    />
                    {{ $t(`AI_AGENT.PROFILE.GOALS.${goal.toUpperCase()}`) }}
                  </button>
                </div>
                <label
                  v-if="agent.goal === 'leads'"
                  class="grid gap-1 text-sm text-n-slate-12 pt-1"
                >
                  {{ $t('AI_AGENT.PROFILE.LEAD_FIELDS') }}
                  <input
                    v-model="agent.lead_fields"
                    type="text"
                    maxlength="200"
                    class="w-full !mb-0"
                    :placeholder="$t('AI_AGENT.PROFILE.LEAD_FIELDS_PLACEHOLDER')"
                  />
                </label>
              </div>

              <div class="grid gap-2">
                <span class="text-sm font-medium text-n-slate-12">
                  {{ $t('AI_AGENT.PROFILE.POLICIES') }}
                </span>
                <div class="grid sm:grid-cols-2 gap-3">
                  <label
                    v-for="key in POLICY_KEYS"
                    :key="key"
                    class="grid gap-1 text-sm text-n-slate-12"
                  >
                    {{ $t(`AI_AGENT.PROFILE.POLICY.${key.toUpperCase()}`) }}
                    <textarea
                      v-model="agent.policies[key]"
                      rows="2"
                      maxlength="600"
                      class="w-full !mb-0"
                      :placeholder="
                        $t(`AI_AGENT.PROFILE.POLICY.${key.toUpperCase()}_HINT`)
                      "
                    />
                  </label>
                </div>
              </div>

              <div class="grid gap-2">
                <span class="text-sm font-medium text-n-slate-12">
                  {{ $t('AI_AGENT.PROFILE.RULES') }}
                </span>
                <div class="grid sm:grid-cols-2 gap-3">
                  <label class="grid gap-1 text-sm text-n-slate-12">
                    <span class="flex items-center gap-1.5">
                      <span class="i-lucide-circle-check size-4 text-n-teal-10" />
                      {{ $t('AI_AGENT.PROFILE.ALWAYS') }}
                    </span>
                    <textarea
                      v-model="agent.always_rules"
                      rows="4"
                      maxlength="2000"
                      class="w-full !mb-0"
                      :placeholder="$t('AI_AGENT.PROFILE.ALWAYS_HINT')"
                    />
                  </label>
                  <label class="grid gap-1 text-sm text-n-slate-12">
                    <span class="flex items-center gap-1.5">
                      <span class="i-lucide-circle-x size-4 text-n-ruby-10" />
                      {{ $t('AI_AGENT.PROFILE.NEVER') }}
                    </span>
                    <textarea
                      v-model="agent.never_rules"
                      rows="4"
                      maxlength="2000"
                      class="w-full !mb-0"
                      :placeholder="$t('AI_AGENT.PROFILE.NEVER_HINT')"
                    />
                  </label>
                </div>
                <label class="grid gap-1 text-sm text-n-slate-12">
                  {{ $t('AI_AGENT.PROFILE.HANDOFF') }}
                  <textarea
                    v-model="agent.handoff_rules"
                    rows="3"
                    maxlength="2000"
                    class="w-full !mb-0"
                    :placeholder="$t('AI_AGENT.PROFILE.HANDOFF_HINT')"
                  />
                </label>
              </div>

              <div class="grid gap-2">
                <span class="text-sm font-medium text-n-slate-12">
                  {{ $t('AI_AGENT.PROFILE.STYLE') }}
                </span>
                <div class="grid sm:grid-cols-2 gap-3">
                  <label class="grid gap-1 text-sm text-n-slate-12">
                    {{ $t('AI_AGENT.PROFILE.LENGTH') }}
                    <select v-model="agent.reply_length" class="w-full !mb-0">
                      <option value="short">
                        {{ $t('AI_AGENT.PROFILE.LENGTHS.SHORT') }}
                      </option>
                      <option value="detailed">
                        {{ $t('AI_AGENT.PROFILE.LENGTHS.DETAILED') }}
                      </option>
                    </select>
                  </label>
                  <label class="grid gap-1 text-sm text-n-slate-12">
                    {{ $t('AI_AGENT.PROFILE.LANGUAGE') }}
                    <select v-model="agent.reply_language" class="w-full !mb-0">
                      <option
                        v-for="language in LANGUAGES"
                        :key="language"
                        :value="language"
                      >
                        {{
                          $t(
                            `AI_AGENT.PROFILE.LANGUAGES.${language.toUpperCase()}`
                          )
                        }}
                      </option>
                    </select>
                  </label>
                </div>
                <label
                  class="flex items-center justify-between gap-3 px-4 py-3 rounded-xl outline outline-1 outline-n-weak cursor-pointer"
                >
                  <span class="text-sm text-n-slate-12">
                    {{ $t('AI_AGENT.PROFILE.EMOJI') }}
                  </span>
                  <Switch v-model="agent.use_emoji" />
                </label>
              </div>
            </div>

            <FaqsPanel
              v-else-if="currentTab === 'faqs'"
              :faqs="faqs"
              :is-generating="isGenerating"
              @refresh="fetchItems"
              @generate="generateFaqs"
            />

            <MediaPanel
              v-else-if="currentTab === 'media'"
              :media="media"
              @refresh="fetchItems"
            />
          </div>

          <div class="lg:sticky lg:top-0 lg:h-[calc(100vh-7rem)]">
            <PreviewChat
              :agent-name="agent.agent_name"
              @tested="tested = true"
            />
          </div>
        </div>

        <!-- One save bar for every tab -->
        <div
          v-if="isDirty"
          class="sticky bottom-0 z-10 flex flex-wrap items-center justify-between gap-3 px-4 py-3 rounded-xl bg-n-solid-2 outline outline-1 outline-n-strong shadow-lg"
        >
          <span class="flex items-center gap-2 text-sm text-n-slate-12">
            <span class="size-2 rounded-full bg-n-amber-9" />
            {{ $t('AI_AGENT.UNSAVED') }}
          </span>
          <div class="flex gap-2">
            <ButtonV4 sm ghost slate @click="discard">
              {{ $t('AI_AGENT.DISCARD') }}
            </ButtonV4>
            <ButtonV4 sm solid blue :is-loading="isSaving" @click="save">
              {{ $t('AI_AGENT.SAVE') }}
            </ButtonV4>
          </div>
        </div>
      </section>
    </template>
  </SettingsLayout>
</template>
