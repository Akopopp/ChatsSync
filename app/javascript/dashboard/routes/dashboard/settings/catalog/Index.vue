<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import { frontendURL, conversationUrl } from 'dashboard/helper/URLHelper';
import { downloadCsvFile } from 'dashboard/helper/downloadHelper';
import CatalogAPI from 'dashboard/api/catalog';
import ExportsAPI from 'dashboard/api/exports';

import BillingCard from '../billing/components/BillingCard.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import ButtonV4 from 'next/button/Button.vue';

const { t } = useI18n();
const accountId = useMapGetter('getCurrentAccountId');

const ORDER_STATUSES = [
  'new',
  'confirmed',
  'shipped',
  'delivered',
  'cancelled',
];
const emptyProduct = () => ({
  id: null,
  name: '',
  price: '',
  category: '',
  description: '',
  image: null,
});

const isLoading = ref(true);
const isSaving = ref(false);
const isDownloading = ref(false);
const isSavingProduct = ref(false);
const setting = ref(null);
const products = ref([]);
const orders = ref([]);
const form = ref(emptyProduct());
const imageInput = ref(null);

const errorMessage = error =>
  error?.response?.data?.message ||
  error?.response?.data?.error ||
  t('CATALOG.ERROR');

const money = amount => {
  const value = Number(amount);
  const text = Number.isInteger(value)
    ? value.toLocaleString('en-US')
    : value.toLocaleString('en-US', { minimumFractionDigits: 2 });
  return `${setting.value?.currency || ''} ${text}`;
};

const groupedProducts = computed(() =>
  products.value.reduce((groups, product) => {
    const name = product.category || t('CATALOG.PRODUCTS.NO_CATEGORY');
    (groups[name] ||= []).push(product);
    return groups;
  }, {})
);

const fetchProducts = async () => {
  const response = await CatalogAPI.get();
  products.value = response.data;
};

const downloadOrders = async () => {
  isDownloading.value = true;
  try {
    const { data } = await ExportsAPI.csv('orders');
    downloadCsvFile(
      `orders-${new Date().toISOString().slice(0, 10)}.csv`,
      data
    );
  } catch (error) {
    useAlert(errorMessage(error));
  } finally {
    isDownloading.value = false;
  }
};

const fetchOrders = async () => {
  const response = await CatalogAPI.getOrders();
  orders.value = response.data.payload;
};

const fetchAll = async () => {
  try {
    const response = await CatalogAPI.getSetting();
    setting.value = response.data;
    await Promise.all([fetchProducts(), fetchOrders()]);
  } finally {
    isLoading.value = false;
  }
};

const save = async () => {
  isSaving.value = true;
  try {
    const { enabled, take_orders, currency } = setting.value;
    const { delivery_fee, min_order, order_notes } = setting.value;
    const response = await CatalogAPI.updateSetting({
      enabled,
      take_orders,
      currency,
      delivery_fee,
      min_order,
      order_notes,
    });
    setting.value = response.data;
    useAlert(t('CATALOG.SAVED'));
  } catch (error) {
    useAlert(errorMessage(error));
  } finally {
    isSaving.value = false;
  }
};

const resetForm = () => {
  form.value = emptyProduct();
  if (imageInput.value) imageInput.value.value = '';
};

const saveProduct = async () => {
  if (!form.value.name || form.value.price === '') return;
  isSavingProduct.value = true;
  try {
    const { id, name, price, category, description, image } = form.value;
    const product = { name, price, category, description, image };
    if (id) {
      await CatalogAPI.updateProduct(id, product);
    } else {
      await CatalogAPI.createProduct(product);
    }
    resetForm();
    await fetchProducts();
  } catch (error) {
    useAlert(errorMessage(error));
  } finally {
    isSavingProduct.value = false;
  }
};

const editProduct = product => {
  form.value = { ...emptyProduct(), ...product, image: null };
};

const onImageSelected = event => {
  [form.value.image] = event.target.files;
};

const toggleAvailable = async product => {
  await CatalogAPI.updateProduct(product.id, {
    available: !product.available,
  });
  await fetchProducts();
};

const removeProduct = async product => {
  await CatalogAPI.delete(product.id);
  await fetchProducts();
};

const setOrderStatus = async (order, status) => {
  try {
    await CatalogAPI.setOrderStatus(order.id, status);
    await fetchOrders();
  } catch (error) {
    useAlert(errorMessage(error));
  }
};

const copyLink = async () => {
  await navigator.clipboard.writeText(setting.value.menu_page_url);
  useAlert(t('CATALOG.STATUS.COPIED'));
};

const formatDate = value =>
  new Intl.DateTimeFormat(undefined, {
    day: 'numeric',
    month: 'short',
    hour: 'numeric',
    minute: '2-digit',
  }).format(new Date(value));

const chatLink = order =>
  frontendURL(
    conversationUrl({ accountId: accountId.value, id: order.conversation_id })
  );

onMounted(fetchAll);
</script>

<template>
  <SettingsLayout
    :is-loading="isLoading"
    :loading-message="$t('CATALOG.LOADING')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('CATALOG.TITLE')"
        :description="$t('CATALOG.DESCRIPTION')"
      />
    </template>
    <template #body>
      <section v-if="setting" class="grid gap-4">
        <div
          v-if="!setting.feature_available"
          class="px-4 py-3 rounded-lg bg-n-amber-3 text-n-amber-11 text-sm"
        >
          {{ $t('CATALOG.NOT_IN_PLAN') }}
        </div>

        <BillingCard
          :title="$t('CATALOG.STATUS.TITLE')"
          :description="$t('CATALOG.STATUS.DESCRIPTION')"
        >
          <template #action>
            <ButtonV4 sm solid blue :is-loading="isSaving" @click="save">
              {{ $t('CATALOG.SAVE') }}
            </ButtonV4>
          </template>
          <div class="px-5 grid gap-3 text-sm text-n-slate-12">
            <label class="flex items-center gap-2">
              <input v-model="setting.enabled" type="checkbox" />
              {{ $t('CATALOG.STATUS.ENABLED') }}
            </label>
            <label class="flex items-center gap-2">
              <input v-model="setting.take_orders" type="checkbox" />
              {{ $t('CATALOG.STATUS.TAKE_ORDERS') }}
            </label>
            <div class="grid sm:grid-cols-3 gap-3">
              <label class="grid gap-1">
                {{ $t('CATALOG.STATUS.CURRENCY') }}
                <input
                  v-model="setting.currency"
                  type="text"
                  maxlength="10"
                  class="w-full"
                />
              </label>
              <label class="grid gap-1">
                {{ $t('CATALOG.STATUS.DELIVERY_FEE') }}
                <input
                  v-model="setting.delivery_fee"
                  type="number"
                  min="0"
                  class="w-full"
                />
              </label>
              <label class="grid gap-1">
                {{ $t('CATALOG.STATUS.MIN_ORDER') }}
                <input
                  v-model="setting.min_order"
                  type="number"
                  min="0"
                  class="w-full"
                />
              </label>
            </div>
            <label class="grid gap-1">
              {{ $t('CATALOG.STATUS.NOTES') }}
              <textarea
                v-model="setting.order_notes"
                rows="2"
                maxlength="1000"
                class="w-full"
                :placeholder="$t('CATALOG.STATUS.NOTES_PLACEHOLDER')"
              />
            </label>
            <div class="grid gap-1">
              <span class="font-medium">{{ $t('CATALOG.STATUS.PAGE') }}</span>
              <span class="text-xs text-n-slate-11">
                {{ $t('CATALOG.STATUS.PAGE_NOTE') }}
              </span>
              <div class="flex items-center gap-2">
                <a
                  :href="setting.menu_page_url"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="text-n-blue-11 break-all"
                >
                  {{ setting.menu_page_url }}
                </a>
                <ButtonV4 xs faded slate @click="copyLink">
                  {{ $t('CATALOG.STATUS.COPY') }}
                </ButtonV4>
              </div>
            </div>
          </div>
        </BillingCard>

        <BillingCard
          :title="$t('CATALOG.PRODUCTS.TITLE')"
          :description="$t('CATALOG.PRODUCTS.DESCRIPTION')"
        >
          <div class="px-5 grid gap-4 text-sm">
            <div class="grid gap-2 p-3 rounded-lg bg-n-alpha-1">
              <div class="grid sm:grid-cols-3 gap-2">
                <input
                  v-model="form.name"
                  type="text"
                  maxlength="120"
                  class="!mb-0"
                  :placeholder="$t('CATALOG.PRODUCTS.NAME')"
                />
                <input
                  v-model="form.price"
                  type="number"
                  min="0"
                  class="!mb-0"
                  :placeholder="$t('CATALOG.PRODUCTS.PRICE')"
                />
                <input
                  v-model="form.category"
                  type="text"
                  maxlength="60"
                  class="!mb-0"
                  :placeholder="$t('CATALOG.PRODUCTS.CATEGORY')"
                />
              </div>
              <textarea
                v-model="form.description"
                rows="2"
                maxlength="1000"
                class="!mb-0"
                :placeholder="$t('CATALOG.PRODUCTS.PRODUCT_DESCRIPTION')"
              />
              <input
                ref="imageInput"
                type="file"
                accept="image/*"
                class="!mb-0"
                @change="onImageSelected"
              />
              <div class="flex gap-2">
                <ButtonV4
                  sm
                  solid
                  blue
                  :is-loading="isSavingProduct"
                  @click="saveProduct"
                >
                  {{
                    form.id
                      ? $t('CATALOG.PRODUCTS.UPDATE')
                      : $t('CATALOG.PRODUCTS.ADD')
                  }}
                </ButtonV4>
                <ButtonV4 v-if="form.id" sm faded slate @click="resetForm">
                  {{ $t('CATALOG.PRODUCTS.CANCEL_EDIT') }}
                </ButtonV4>
              </div>
            </div>

            <p v-if="!products.length" class="text-n-slate-11">
              {{ $t('CATALOG.PRODUCTS.EMPTY') }}
            </p>
            <div
              v-for="(items, category) in groupedProducts"
              :key="category"
              class="grid gap-2"
            >
              <span class="font-medium text-n-slate-12">{{ category }}</span>
              <div
                v-for="product in items"
                :key="product.id"
                class="flex items-center gap-3 p-2 rounded-lg border border-n-weak"
                :class="{ 'opacity-50': !product.available }"
              >
                <img
                  v-if="product.image_url"
                  :src="product.image_url"
                  :alt="product.name"
                  class="size-12 rounded-md object-cover shrink-0"
                />
                <div
                  v-else
                  class="size-12 rounded-md bg-n-alpha-2 grid place-items-center shrink-0 text-n-slate-10"
                >
                  <span class="i-lucide-image size-5" />
                </div>
                <div class="grid flex-1 min-w-0">
                  <span class="font-medium text-n-slate-12 truncate">
                    {{ product.name }}
                  </span>
                  <span class="text-xs text-n-slate-11">
                    {{ money(product.price) }}
                  </span>
                </div>
                <div class="flex gap-3 text-xs shrink-0">
                  <button class="text-n-blue-11" @click="editProduct(product)">
                    {{ $t('CATALOG.PRODUCTS.EDIT') }}
                  </button>
                  <button
                    class="text-n-amber-11"
                    @click="toggleAvailable(product)"
                  >
                    {{
                      product.available
                        ? $t('CATALOG.PRODUCTS.SOLD_OUT')
                        : $t('CATALOG.PRODUCTS.AVAILABLE')
                    }}
                  </button>
                  <button
                    class="text-n-ruby-11"
                    @click="removeProduct(product)"
                  >
                    {{ $t('CATALOG.DELETE') }}
                  </button>
                </div>
              </div>
            </div>
          </div>
        </BillingCard>

        <BillingCard
          :title="$t('CATALOG.ORDERS.TITLE')"
          :description="$t('CATALOG.ORDERS.DESCRIPTION')"
        >
          <template #action>
            <ButtonV4
              sm
              faded
              slate
              icon="i-lucide-download"
              :is-loading="isDownloading"
              :disabled="!orders.length"
              @click="downloadOrders"
            >
              {{ $t('CATALOG.ORDERS.DOWNLOAD') }}
            </ButtonV4>
          </template>
          <div class="px-5 grid gap-2 text-sm">
            <p v-if="!orders.length" class="text-n-slate-11">
              {{ $t('CATALOG.ORDERS.EMPTY') }}
            </p>
            <div
              v-for="order in orders"
              :key="order.id"
              class="grid gap-2 p-3 rounded-lg border border-n-weak"
            >
              <div class="flex flex-wrap items-center gap-3">
                <span class="font-semibold text-n-slate-12">
                  {{ $t('CATALOG.ORDERS.NUMBER', { number: order.number }) }}
                </span>
                <span class="text-xs text-n-slate-11">
                  {{ formatDate(order.created_at) }}
                </span>
                <span
                  v-if="order.external_ref"
                  class="px-2 py-0.5 rounded-full bg-n-alpha-2 text-xs text-n-slate-11"
                >
                  {{
                    $t('CATALOG.ORDERS.FROM_STORE', { ref: order.external_ref })
                  }}
                </span>
                <span class="flex-1" />
                <span class="font-semibold text-n-slate-12">
                  {{ money(order.total) }}
                </span>
                <select
                  :value="order.status"
                  class="!w-36 !mb-0 !py-1 text-xs"
                  @change="setOrderStatus(order, $event.target.value)"
                >
                  <option
                    v-for="status in ORDER_STATUSES"
                    :key="status"
                    :value="status"
                  >
                    {{ $t(`CATALOG.ORDERS.STATUSES.${status.toUpperCase()}`) }}
                  </option>
                </select>
              </div>
              <div class="text-n-slate-11">
                <div
                  v-for="(item, index) in order.items"
                  :key="`${order.id}-${index}`"
                >
                  {{
                    $t('CATALOG.ORDERS.ITEM', {
                      name: item.name,
                      quantity: item.quantity,
                    })
                  }}
                </div>
              </div>
              <div class="flex flex-wrap items-center gap-3 text-xs">
                <span class="text-n-slate-12">
                  {{ order.customer_name }}
                  <span class="text-n-slate-11">
                    {{ order.customer_phone }}
                  </span>
                </span>
                <span v-if="order.address" class="text-n-slate-11">
                  {{ order.address }}
                </span>
                <router-link
                  v-if="order.conversation_id"
                  :to="chatLink(order)"
                  class="text-n-blue-11"
                >
                  {{ $t('CATALOG.ORDERS.OPEN_CHAT') }}
                </router-link>
              </div>
            </div>
          </div>
        </BillingCard>
      </section>
    </template>
  </SettingsLayout>
</template>
