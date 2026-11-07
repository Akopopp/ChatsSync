<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { downloadCsvFile } from 'dashboard/helper/downloadHelper';
import WhatsappFormsAPI from 'dashboard/api/whatsappForms';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import ButtonV4 from 'next/button/Button.vue';
import Switch from 'next/switch/Switch.vue';

const { t } = useI18n();

// WhatsApp's own limits for a form.
const MAX_FIELDS = 10;
const LABEL_LENGTH = 20;
const TYPES = [
  'text',
  'long_text',
  'number',
  'email',
  'phone',
  'choice',
  'date',
];

const isLoading = ref(true);
const isSaving = ref(false);
const forms = ref([]);
const editing = ref(null);

const blankField = () => ({
  label: '',
  type: 'text',
  required: true,
  options: '',
});
const blankForm = () => ({
  id: null,
  name: '',
  title: '',
  intro: '',
  button_label: t('WHATSAPP_FORMS.DEFAULTS.BUTTON'),
  submit_label: t('WHATSAPP_FORMS.DEFAULTS.SUBMIT'),
  enabled: true,
  fields: [blankField()],
});

const errorMessage = error =>
  error?.response?.data?.message ||
  error?.response?.data?.error ||
  t('WHATSAPP_FORMS.ERROR');

const load = async () => {
  try {
    const { data } = await WhatsappFormsAPI.all();
    forms.value = data.payload;
  } catch (error) {
    useAlert(errorMessage(error));
  } finally {
    isLoading.value = false;
  }
};

const startNew = () => {
  editing.value = blankForm();
};

const startEdit = form => {
  editing.value = {
    ...form,
    intro: form.intro || '',
    fields: form.fields.map(field => ({
      label: field.label,
      type: field.type,
      required: field.required,
      options: (field.options || []).join('\n'),
    })),
  };
};

const addField = () => {
  if (editing.value.fields.length < MAX_FIELDS) {
    editing.value.fields.push(blankField());
  }
};

const removeField = index => editing.value.fields.splice(index, 1);

const moveField = (index, step) => {
  const list = editing.value.fields;
  const target = index + step;
  if (target < 0 || target >= list.length) return;
  [list[index], list[target]] = [list[target], list[index]];
};

const canSave = computed(
  () =>
    editing.value &&
    editing.value.name.trim() &&
    editing.value.title.trim() &&
    editing.value.fields.length &&
    editing.value.fields.every(field => field.label.trim())
);

const save = async () => {
  const { id, ...form } = editing.value;
  isSaving.value = true;
  try {
    if (id) await WhatsappFormsAPI.update(id, form);
    else await WhatsappFormsAPI.create(form);
    editing.value = null;
    useAlert(t('WHATSAPP_FORMS.SAVED'));
    await load();
  } catch (error) {
    useAlert(errorMessage(error));
  } finally {
    isSaving.value = false;
  }
};

const toggleEnabled = async form => {
  try {
    await WhatsappFormsAPI.update(form.id, { enabled: !form.enabled });
    form.enabled = !form.enabled;
  } catch (error) {
    useAlert(errorMessage(error));
  }
};

const remove = async form => {
  // eslint-disable-next-line no-alert
  if (!window.confirm(t('WHATSAPP_FORMS.DELETE_CONFIRM', { name: form.name })))
    return;
  try {
    await WhatsappFormsAPI.delete(form.id);
    forms.value = forms.value.filter(item => item.id !== form.id);
  } catch (error) {
    useAlert(errorMessage(error));
  }
};

const download = async form => {
  try {
    const { data } = await WhatsappFormsAPI.responsesCsv(form.id);
    downloadCsvFile(`${form.name.replace(/\W+/g, '-')}-responses.csv`, data);
  } catch (error) {
    useAlert(errorMessage(error));
  }
};

onMounted(load);
</script>

<template>
  <SettingsLayout
    :is-loading="isLoading"
    :loading-message="$t('WHATSAPP_FORMS.LOADING')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('WHATSAPP_FORMS.TITLE')"
        :description="$t('WHATSAPP_FORMS.DESCRIPTION')"
      >
        <template #actions>
          <ButtonV4 v-if="!editing" icon="i-lucide-plus" @click="startNew">
            {{ $t('WHATSAPP_FORMS.NEW') }}
          </ButtonV4>
        </template>
      </BaseSettingsHeader>
    </template>
    <template #body>
      <section class="grid gap-4 pb-20 text-sm">
        <div
          v-if="editing"
          class="grid gap-4 p-5 rounded-2xl outline outline-1 outline-n-weak bg-n-solid-1"
        >
          <div class="grid gap-3 sm:grid-cols-2">
            <label class="grid gap-1 text-n-slate-12">
              {{ $t('WHATSAPP_FORMS.FORM.NAME') }}
              <input
                v-model="editing.name"
                type="text"
                maxlength="60"
                class="!mb-0"
                :placeholder="$t('WHATSAPP_FORMS.FORM.NAME_PLACEHOLDER')"
              />
            </label>
            <label class="grid gap-1 text-n-slate-12">
              {{ $t('WHATSAPP_FORMS.FORM.HEADING') }}
              <input
                v-model="editing.title"
                type="text"
                maxlength="30"
                class="!mb-0"
                :placeholder="$t('WHATSAPP_FORMS.FORM.HEADING_PLACEHOLDER')"
              />
            </label>
          </div>
          <label class="grid gap-1 text-n-slate-12">
            {{ $t('WHATSAPP_FORMS.FORM.INTRO') }}
            <textarea
              v-model="editing.intro"
              rows="2"
              maxlength="1000"
              class="!mb-0"
              :placeholder="$t('WHATSAPP_FORMS.FORM.INTRO_PLACEHOLDER')"
            />
          </label>
          <div class="grid gap-3 sm:grid-cols-2">
            <label class="grid gap-1 text-n-slate-12">
              {{ $t('WHATSAPP_FORMS.FORM.BUTTON') }}
              <input
                v-model="editing.button_label"
                type="text"
                maxlength="20"
                class="!mb-0"
              />
            </label>
            <label class="grid gap-1 text-n-slate-12">
              {{ $t('WHATSAPP_FORMS.FORM.SUBMIT') }}
              <input
                v-model="editing.submit_label"
                type="text"
                maxlength="30"
                class="!mb-0"
              />
            </label>
          </div>

          <div class="grid gap-2">
            <span class="font-medium text-n-slate-12">
              {{
                $t('WHATSAPP_FORMS.FORM.QUESTIONS', {
                  count: editing.fields.length,
                  max: MAX_FIELDS,
                })
              }}
            </span>
            <div
              v-for="(field, index) in editing.fields"
              :key="index"
              class="grid gap-2 p-3 rounded-lg bg-n-alpha-1"
            >
              <div class="flex flex-wrap items-center gap-2">
                <input
                  v-model="field.label"
                  type="text"
                  :maxlength="LABEL_LENGTH"
                  class="!mb-0 flex-1 min-w-40"
                  :placeholder="$t('WHATSAPP_FORMS.FORM.LABEL_PLACEHOLDER')"
                />
                <select v-model="field.type" class="!mb-0 !w-auto">
                  <option v-for="type in TYPES" :key="type" :value="type">
                    {{ $t(`WHATSAPP_FORMS.TYPES.${type.toUpperCase()}`) }}
                  </option>
                </select>
                <label class="flex items-center gap-1 text-n-slate-11">
                  <input v-model="field.required" type="checkbox" />
                  {{ $t('WHATSAPP_FORMS.FORM.REQUIRED') }}
                </label>
                <button
                  class="i-lucide-arrow-up size-4 text-n-slate-11"
                  :aria-label="$t('WHATSAPP_FORMS.FORM.UP')"
                  @click="moveField(index, -1)"
                />
                <button
                  class="i-lucide-arrow-down size-4 text-n-slate-11"
                  :aria-label="$t('WHATSAPP_FORMS.FORM.DOWN')"
                  @click="moveField(index, 1)"
                />
                <button
                  class="i-lucide-trash-2 size-4 text-n-ruby-11"
                  :aria-label="$t('WHATSAPP_FORMS.DELETE')"
                  @click="removeField(index)"
                />
              </div>
              <textarea
                v-if="field.type === 'choice'"
                v-model="field.options"
                rows="3"
                class="!mb-0"
                :placeholder="$t('WHATSAPP_FORMS.FORM.OPTIONS_PLACEHOLDER')"
              />
            </div>
            <span class="text-xs text-n-slate-10">
              {{ $t('WHATSAPP_FORMS.FORM.LIMITS') }}
            </span>
            <div>
              <ButtonV4
                sm
                faded
                slate
                icon="i-lucide-plus"
                :disabled="editing.fields.length >= MAX_FIELDS"
                @click="addField"
              >
                {{ $t('WHATSAPP_FORMS.FORM.ADD_QUESTION') }}
              </ButtonV4>
            </div>
          </div>

          <div class="flex justify-end gap-2">
            <ButtonV4 sm faded slate @click="editing = null">
              {{ $t('WHATSAPP_FORMS.CANCEL') }}
            </ButtonV4>
            <ButtonV4
              sm
              solid
              blue
              :is-loading="isSaving"
              :disabled="!canSave"
              @click="save"
            >
              {{ $t('WHATSAPP_FORMS.SAVE') }}
            </ButtonV4>
          </div>
        </div>

        <p
          v-if="!forms.length && !editing"
          class="px-4 py-3 rounded-xl bg-n-alpha-1 text-n-slate-11"
        >
          {{ $t('WHATSAPP_FORMS.EMPTY') }}
        </p>
        <div
          v-for="form in forms"
          :key="form.id"
          class="flex flex-wrap items-center gap-3 px-5 py-4 rounded-2xl outline outline-1 outline-n-weak bg-n-solid-1"
        >
          <div class="grid gap-0.5 flex-1 min-w-0 basis-full sm:basis-0">
            <span class="font-medium text-n-slate-12 truncate">
              {{ form.name }}
            </span>
            <span class="text-xs text-n-slate-11">
              {{
                $t('WHATSAPP_FORMS.SUMMARY', {
                  questions: form.fields.length,
                  responses: form.responses_count,
                })
              }}
            </span>
          </div>
          <Switch
            :model-value="form.enabled"
            :aria-label="$t('WHATSAPP_FORMS.ENABLED')"
            @change="toggleEnabled(form)"
          />
          <ButtonV4 sm faded slate @click="startEdit(form)">
            {{ $t('WHATSAPP_FORMS.EDIT') }}
          </ButtonV4>
          <ButtonV4
            sm
            faded
            slate
            icon="i-lucide-download"
            :disabled="!form.responses_count"
            @click="download(form)"
          >
            {{ $t('WHATSAPP_FORMS.DOWNLOAD') }}
          </ButtonV4>
          <ButtonV4
            sm
            faded
            ruby
            icon="i-lucide-trash-2"
            @click="remove(form)"
          />
        </div>
      </section>
    </template>
  </SettingsLayout>
</template>
