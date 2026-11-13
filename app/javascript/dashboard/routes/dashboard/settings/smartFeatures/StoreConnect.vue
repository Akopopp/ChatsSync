<script setup>
// Online store page, "Your store": the store's website (to import products into the catalog) and,
// optionally, its API key so orders confirmed or cancelled on WhatsApp are marked in the store too.
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import OnlineStoreAPI from 'dashboard/api/onlineStore';
import NextButton from 'dashboard/components-next/button/Button.vue';
import HelpTip from 'dashboard/components-next/helpTip/HelpTip.vue';

const { t } = useI18n();

const store = ref({ platform: 'shopify', url: '', key_saved: false });
const url = ref('');
const token = ref('');
const secret = ref('');
const isSaving = ref(false);
const isImporting = ref(false);

const isWoo = computed(() => store.value.platform === 'woocommerce');
const importedText = computed(() =>
  store.value.imported_at
    ? t('SMART_FEATURES.STORE_CONNECT.IMPORTED', {
        count: store.value.imported || 0,
        time: new Date(store.value.imported_at).toLocaleString([], {
          dateStyle: 'medium',
          timeStyle: 'short',
        }),
      })
    : ''
);

const apply = data => {
  store.value = { ...data, platform: data.platform || 'shopify' };
  url.value = data.url || '';
  token.value = '';
  secret.value = '';
};

const save = async changes => {
  isSaving.value = true;
  try {
    const { data } = await OnlineStoreAPI.update(changes);
    apply(data);
    useAlert(t('SMART_FEATURES.SAVED'));
  } catch (error) {
    useAlert(t('SMART_FEATURES.ERROR'));
  } finally {
    isSaving.value = false;
  }
};

const setPlatform = platform => save({ platform });

const saveStore = () => {
  const changes = { platform: store.value.platform, url: url.value.trim() };
  if (token.value.trim()) changes.token = token.value.trim();
  if (secret.value.trim()) changes.secret = secret.value.trim();
  save(changes);
};

const removeKey = () => save({ remove_key: true });

const importProducts = async () => {
  isImporting.value = true;
  try {
    await OnlineStoreAPI.importProducts();
    useAlert(t('SMART_FEATURES.STORE_CONNECT.IMPORT_STARTED'));
  } catch (error) {
    useAlert(
      error?.response?.data?.error || t('SMART_FEATURES.STORE_CONNECT.NO_URL')
    );
  } finally {
    isImporting.value = false;
  }
};

onMounted(async () => {
  try {
    const { data } = await OnlineStoreAPI.get();
    apply(data);
  } catch (error) {
    // The card still works; saving shows any error.
  }
});
</script>

<template>
  <section
    class="grid gap-4 p-5 rounded-2xl outline outline-1 outline-n-weak bg-n-solid-1"
  >
    <div class="flex items-start gap-3">
      <span
        class="flex items-center justify-center rounded-xl size-10 shrink-0 bg-n-teal-3 text-n-teal-11"
      >
        <span class="i-lucide-store size-5" />
      </span>
      <div class="grid flex-1 min-w-0 gap-0.5">
        <h3
          class="flex items-center gap-1 m-0 text-base font-medium text-n-slate-12"
        >
          {{ $t('SMART_FEATURES.STORE_CONNECT.TITLE') }}
          <HelpTip :text="$t('SMART_FEATURES.STORE_CONNECT.HELP')" />
        </h3>
        <p class="m-0 text-sm text-n-slate-11">
          {{ $t('SMART_FEATURES.STORE_CONNECT.TEXT') }}
        </p>
      </div>
    </div>

    <div class="flex gap-2">
      <button
        v-for="platform in ['shopify', 'woocommerce']"
        :key="platform"
        type="button"
        class="px-4 py-2 text-sm font-medium border rounded-full"
        :class="
          store.platform === platform
            ? 'border-n-teal-8 bg-n-teal-3 text-n-teal-11'
            : 'border-n-weak text-n-slate-11'
        "
        @click="setPlatform(platform)"
      >
        {{ $t(`SMART_FEATURES.STORE_CONNECT.${platform.toUpperCase()}`) }}
      </button>
    </div>

    <label class="grid gap-1 text-sm text-n-slate-12">
      {{
        $t(
          isWoo
            ? 'SMART_FEATURES.STORE_CONNECT.URL_WOO'
            : 'SMART_FEATURES.STORE_CONNECT.URL_SHOPIFY'
        )
      }}
      <input
        v-model="url"
        type="text"
        class="!m-0"
        :placeholder="isWoo ? 'mystore.com' : 'mystore.myshopify.com'"
      />
    </label>

    <div class="grid gap-3 p-4 rounded-xl bg-n-alpha-1">
      <p
        class="flex items-center gap-1 m-0 text-sm font-medium text-n-slate-12"
      >
        {{ $t('SMART_FEATURES.STORE_CONNECT.KEY_TITLE') }}
        <HelpTip
          :text="
            $t(
              isWoo
                ? 'SMART_FEATURES.STORE_CONNECT.KEY_HELP_WOO'
                : 'SMART_FEATURES.STORE_CONNECT.KEY_HELP_SHOPIFY'
            )
          "
        />
      </p>
      <p v-if="store.key_saved" class="m-0 text-sm text-n-teal-11">
        {{ $t('SMART_FEATURES.STORE_CONNECT.KEY_SAVED') }}
        <button
          type="button"
          class="ml-2 underline text-n-slate-11"
          @click="removeKey"
        >
          {{ $t('SMART_FEATURES.STORE_CONNECT.REMOVE_KEY') }}
        </button>
      </p>
      <div class="grid gap-3 sm:grid-cols-2">
        <input
          v-model="token"
          type="password"
          autocomplete="off"
          class="!m-0"
          :placeholder="
            $t(
              isWoo
                ? 'SMART_FEATURES.STORE_CONNECT.WOO_KEY'
                : 'SMART_FEATURES.STORE_CONNECT.SHOPIFY_TOKEN'
            )
          "
        />
        <input
          v-if="isWoo"
          v-model="secret"
          type="password"
          autocomplete="off"
          class="!m-0"
          :placeholder="$t('SMART_FEATURES.STORE_CONNECT.WOO_SECRET')"
        />
      </div>
    </div>

    <div class="flex flex-wrap items-center gap-2">
      <NextButton
        solid
        blue
        sm
        :is-loading="isSaving"
        :label="$t('SMART_FEATURES.STORE_CONNECT.SAVE')"
        @click="saveStore"
      />
      <NextButton
        faded
        slate
        sm
        icon="i-lucide-download"
        :is-loading="isImporting"
        :disabled="!store.url"
        :label="$t('SMART_FEATURES.STORE_CONNECT.IMPORT')"
        @click="importProducts"
      />
      <span v-if="importedText" class="text-xs text-n-slate-11">
        {{ importedText }}
      </span>
    </div>
  </section>
</template>
