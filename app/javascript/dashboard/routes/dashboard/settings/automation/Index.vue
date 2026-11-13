<script setup>
import { useAlert } from 'dashboard/composables';
import AddAutomationRule from './AddAutomationRule.vue';
import EditAutomationRule from './EditAutomationRule.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStoreGetters, useStore } from 'dashboard/composables/store';
import { picoSearch } from '@scmmishra/pico-search';
import AutomationRuleRow from './AutomationRuleRow.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import { BaseTable } from 'dashboard/components-next/table';

const getters = useStoreGetters();
const store = useStore();
const { t } = useI18n();
const confirmDialog = ref(null);

const loading = ref({});
const addDialogRef = ref(null);
const editDialogRef = ref(null);
const showDeleteConfirmationPopup = ref(false);
const selectedAutomation = ref({});
const searchQuery = ref('');
const toggleModalTitle = ref(t('AUTOMATION.TOGGLE.ACTIVATION_TITLE'));
const toggleModalDescription = ref(
  t('AUTOMATION.TOGGLE.ACTIVATION_DESCRIPTION')
);

const records = computed(() => getters['automations/getAutomations'].value);

const filteredRecords = computed(() => {
  const query = searchQuery.value.trim();
  if (!query) return records.value;
  return picoSearch(records.value, query, ['name', 'description']);
});
const uiFlags = computed(() => getters['automations/getUIFlags'].value);
const accountId = computed(() => getters.getCurrentAccountId.value);

const deleteConfirmText = computed(
  () => `${t('AUTOMATION.DELETE.CONFIRM.YES')} ${selectedAutomation.value.name}`
);

const deleteRejectText = computed(
  () => `${t('AUTOMATION.DELETE.CONFIRM.NO')} ${selectedAutomation.value.name}`
);

const deleteMessage = computed(() => ` ${selectedAutomation.value.name}?`);

const isSLAEnabled = computed(() =>
  getters['accounts/isFeatureEnabledonAccount'].value(accountId.value, 'sla')
);

onMounted(() => {
  store.dispatch('inboxes/get');
  store.dispatch('agents/get');
  store.dispatch('contacts/get');
  store.dispatch('teams/get');
  store.dispatch('labels/get');
  store.dispatch('campaigns/get');
  store.dispatch('automations/get');
  if (isSLAEnabled.value) {
    store.dispatch('sla/get');
  }
});

const openAddPopup = () => {
  addDialogRef.value?.open();
};
const hideAddPopup = () => {
  addDialogRef.value?.close();
};

const openEditPopup = response => {
  selectedAutomation.value = { ...response };
  editDialogRef.value?.open();
};
const hideEditPopup = () => {
  editDialogRef.value?.close();
};

const openDeletePopup = response => {
  showDeleteConfirmationPopup.value = true;
  selectedAutomation.value = response;
};
const closeDeletePopup = () => {
  showDeleteConfirmationPopup.value = false;
};

const deleteAutomation = async id => {
  try {
    await store.dispatch('automations/delete', id);
    useAlert(t('AUTOMATION.DELETE.API.SUCCESS_MESSAGE'));
  } catch (error) {
    useAlert(t('AUTOMATION.DELETE.API.ERROR_MESSAGE'));
  } finally {
    loading.value[selectedAutomation.value.id] = false;
  }
};
const confirmDeletion = () => {
  loading.value[selectedAutomation.value.id] = true;
  closeDeletePopup();
  deleteAutomation(selectedAutomation.value.id);
};
const cloneAutomation = async ({ id }) => {
  try {
    await store.dispatch('automations/clone', id);
    useAlert(t('AUTOMATION.CLONE.API.SUCCESS_MESSAGE'));
    store.dispatch('automations/get');
  } catch (error) {
    useAlert(t('AUTOMATION.CLONE.API.ERROR_MESSAGE'));
  } finally {
    loading.value[selectedAutomation.value.id] = false;
  }
};

// Ready-made automations: one click adds a working rule, which can then be edited like any other.
const incoming = {
  attribute_key: 'message_type',
  filter_operator: 'equal_to',
  values: ['incoming'],
  query_operator: null,
};
const says = words => ({
  attribute_key: 'content',
  filter_operator: 'contains',
  values: words,
  query_operator: 'and',
});
const READY = [
  {
    key: 'ORDER_EMAIL',
    icon: 'i-lucide-shopping-bag',
    event_name: 'order_created',
    conditions: [],
    actions: [{ action_name: 'email_admins', action_params: ['New order'] }],
  },
  {
    key: 'FORM_EMAIL',
    icon: 'i-lucide-clipboard-list',
    event_name: 'form_submitted',
    conditions: [],
    actions: [
      {
        action_name: 'email_admins',
        action_params: ['A customer filled a WhatsApp form'],
      },
    ],
  },
  {
    key: 'HUMAN',
    icon: 'i-lucide-user-round',
    event_name: 'message_created',
    conditions: [
      says(['agent', 'human', 'manager', 'call me', 'insaan']),
      incoming,
    ],
    actions: [
      { action_name: 'turn_off_ai', action_params: [] },
      {
        action_name: 'email_admins',
        action_params: ['Customer wants a person'],
      },
    ],
  },
  {
    key: 'PRICE',
    icon: 'i-lucide-tag',
    event_name: 'message_created',
    conditions: [
      says(['price', 'rate', 'qeemat', 'kitne ka', 'kitnay']),
      incoming,
    ],
    actions: [{ action_name: 'add_label', action_params: ['price'] }],
  },
  {
    key: 'COMPLAINT',
    icon: 'i-lucide-triangle-alert',
    event_name: 'message_created',
    conditions: [
      says(['complaint', 'refund', 'return', 'shikayat', 'kharab']),
      incoming,
    ],
    actions: [
      { action_name: 'add_label', action_params: ['complaint'] },
      { action_name: 'email_admins', action_params: ['Complaint or refund'] },
    ],
  },
  {
    key: 'BOOKING_LABEL',
    icon: 'i-lucide-calendar-check',
    event_name: 'appointment_booked',
    conditions: [],
    actions: [{ action_name: 'add_label', action_params: ['booked'] }],
  },
  {
    key: 'FOLLOW_UP',
    icon: 'i-lucide-clock-alert',
    event_name: 'customer_silent',
    trigger_value: '24',
    conditions: [],
    actions: [{ action_name: 'add_label', action_params: ['follow-up'] }],
  },
];
const readyAdded = key =>
  records.value.some(
    rule => rule.name === t(`AUTOMATION.READY.ITEMS.${key}.TITLE`)
  );
const addReady = async item => {
  try {
    await store.dispatch('automations/create', {
      name: t(`AUTOMATION.READY.ITEMS.${item.key}.TITLE`),
      description: t(`AUTOMATION.READY.ITEMS.${item.key}.TEXT`),
      event_name: item.event_name,
      trigger_value: item.trigger_value,
      conditions: item.conditions,
      actions: item.actions,
    });
    useAlert(t('AUTOMATION.ADD.API.SUCCESS_MESSAGE'));
  } catch (error) {
    useAlert(t('AUTOMATION.ADD.API.ERROR_MESSAGE'));
  }
};

const submitAutomation = async (payload, mode) => {
  try {
    const action =
      mode === 'edit' ? 'automations/update' : 'automations/create';
    const successMessage =
      mode === 'edit'
        ? t('AUTOMATION.EDIT.API.SUCCESS_MESSAGE')
        : t('AUTOMATION.ADD.API.SUCCESS_MESSAGE');
    await store.dispatch(action, payload);
    useAlert(successMessage);
    hideAddPopup();
    hideEditPopup();
  } catch (error) {
    const errorMessage =
      mode === 'edit'
        ? t('AUTOMATION.EDIT.API.ERROR_MESSAGE')
        : t('AUTOMATION.ADD.API.ERROR_MESSAGE');
    useAlert(errorMessage);
  }
};
const toggleAutomation = async ({ id, name, status }) => {
  try {
    if (status) {
      toggleModalTitle.value = t('AUTOMATION.TOGGLE.DEACTIVATION_TITLE');
      toggleModalDescription.value = t(
        'AUTOMATION.TOGGLE.DEACTIVATION_DESCRIPTION',
        {
          automationName: name,
        }
      );
    } else {
      toggleModalTitle.value = t('AUTOMATION.TOGGLE.ACTIVATION_TITLE');
      toggleModalDescription.value = t(
        'AUTOMATION.TOGGLE.ACTIVATION_DESCRIPTION',
        {
          automationName: name,
        }
      );
    }

    const ok = await confirmDialog.value.showConfirmation();
    if (ok) {
      await store.dispatch('automations/update', {
        id: id,
        active: !status,
      });
      const message = status
        ? t('AUTOMATION.TOGGLE.DEACTIVATION_SUCCESFUL')
        : t('AUTOMATION.TOGGLE.ACTIVATION_SUCCESFUL');
      useAlert(message);
    }
  } catch (error) {
    useAlert(t('AUTOMATION.EDIT.API.ERROR_MESSAGE'));
  }
};

const tableHeaders = computed(() => {
  return [
    t('AUTOMATION.LIST.TABLE_HEADER.NAME'),
    t('AUTOMATION.LIST.TABLE_HEADER.ACTIVE'),
    t('AUTOMATION.LIST.TABLE_HEADER.CREATED_ON'),
    t('AUTOMATION.LIST.TABLE_HEADER.ACTIONS'),
  ];
});
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.isFetching"
    :loading-message="$t('AUTOMATION.LOADING')"
    :no-records-found="!records.length"
    :no-records-message="$t('AUTOMATION.LIST.404')"
  >
    <template #header>
      <BaseSettingsHeader
        v-model:search-query="searchQuery"
        :title="$t('AUTOMATION.HEADER')"
        :description="$t('AUTOMATION.DESCRIPTION')"
        :link-text="$t('AUTOMATION.LEARN_MORE')"
        :search-placeholder="$t('AUTOMATION.SEARCH_PLACEHOLDER')"
        feature-name="automation"
      >
        <template v-if="records?.length" #count>
          <span class="text-body-main text-n-slate-11">
            {{ $t('AUTOMATION.COUNT', { n: records.length }) }}
          </span>
        </template>
        <template #actions>
          <Button
            :label="$t('AUTOMATION.HEADER_BTN_TXT')"
            size="sm"
            @click="openAddPopup"
          />
        </template>
      </BaseSettingsHeader>
    </template>
    <template #preBody>
      <section class="grid gap-3 mb-6">
        <div class="grid gap-0.5">
          <h3 class="m-0 text-base font-semibold text-n-slate-12">
            {{ $t('AUTOMATION.READY.TITLE') }}
          </h3>
          <p class="m-0 text-sm text-n-slate-11">
            {{ $t('AUTOMATION.READY.TEXT') }}
          </p>
        </div>
        <div class="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
          <div
            v-for="item in READY"
            :key="item.key"
            class="flex flex-col gap-3 p-4 rounded-2xl outline outline-1 outline-n-weak bg-n-solid-1"
          >
            <div class="flex items-start gap-3">
              <span
                class="flex items-center justify-center rounded-xl size-10 shrink-0 bg-n-brand/10 text-n-brand"
              >
                <span :class="item.icon" class="size-5" />
              </span>
              <div class="grid flex-1 min-w-0 gap-1">
                <span class="text-sm font-semibold text-n-slate-12">
                  {{ $t(`AUTOMATION.READY.ITEMS.${item.key}.TITLE`) }}
                </span>
                <span class="text-sm text-n-slate-11">
                  {{ $t(`AUTOMATION.READY.ITEMS.${item.key}.TEXT`) }}
                </span>
              </div>
            </div>
            <div class="flex justify-end mt-auto">
              <span
                v-if="readyAdded(item.key)"
                class="px-2.5 py-1 text-xs font-semibold rounded-full bg-n-teal-3 text-n-teal-11"
              >
                {{ $t('AUTOMATION.READY.ADDED') }}
              </span>
              <Button
                v-else
                size="sm"
                :label="$t('AUTOMATION.READY.ADD')"
                @click="addReady(item)"
              />
            </div>
          </div>
        </div>
      </section>
    </template>
    <template #body>
      <BaseTable
        :headers="tableHeaders"
        :items="filteredRecords"
        :no-data-message="
          searchQuery ? $t('AUTOMATION.NO_RESULTS') : $t('AUTOMATION.LIST.404')
        "
      >
        <template #row="{ items }">
          <AutomationRuleRow
            v-for="automation in items"
            :key="automation.id"
            :automation="automation"
            :loading="loading[automation.id]"
            @clone="cloneAutomation"
            @toggle="toggleAutomation"
            @edit="openEditPopup"
            @delete="openDeletePopup"
          />
        </template>
      </BaseTable>
    </template>

    <AddAutomationRule ref="addDialogRef" @save-automation="submitAutomation" />

    <woot-delete-modal
      v-model:show="showDeleteConfirmationPopup"
      :on-close="closeDeletePopup"
      :on-confirm="confirmDeletion"
      :title="$t('LABEL_MGMT.DELETE.CONFIRM.TITLE')"
      :message="$t('AUTOMATION.DELETE.CONFIRM.MESSAGE')"
      :message-value="deleteMessage"
      :confirm-text="deleteConfirmText"
      :reject-text="deleteRejectText"
    />

    <EditAutomationRule
      ref="editDialogRef"
      :selected-response="selectedAutomation"
      @save-automation="submitAutomation"
    />
    <woot-confirm-modal
      ref="confirmDialog"
      :title="toggleModalTitle"
      :description="toggleModalDescription"
    />
  </SettingsLayout>
</template>
