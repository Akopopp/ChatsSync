<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';

const { t } = useI18n();
const token = window.location.pathname.split('/').filter(Boolean).pop();

const isLoading = ref(true);
const notAvailable = ref(false);
const menu = ref(null);
const category = ref('');

const categories = computed(() => [
  ...new Set(
    (menu.value?.products || []).map(product => product.category || '')
  ),
]);

const shown = computed(() =>
  (menu.value?.products || []).filter(
    product => !category.value || (product.category || '') === category.value
  )
);

const whatsappLink = text =>
  `https://wa.me/${menu.value.whatsapp}?text=${encodeURIComponent(text)}`;

const load = async () => {
  try {
    const response = await fetch(`/public/api/v1/menus/${token}`);
    if (response.ok) {
      menu.value = await response.json();
    } else {
      notAvailable.value = true;
    }
  } finally {
    isLoading.value = false;
  }
};

onMounted(load);
</script>

<template>
  <div class="min-h-screen bg-n-slate-2 text-n-slate-12 pb-24">
    <header class="bg-n-solid-1 shadow-sm">
      <div class="max-w-2xl mx-auto px-4 py-5 flex items-center gap-3">
        <div
          class="size-12 rounded-full bg-n-brand text-white grid place-items-center text-xl font-semibold"
        >
          {{ (menu?.business_name || '?').charAt(0).toUpperCase() }}
        </div>
        <div class="grid">
          <h1 class="text-lg font-semibold">{{ menu?.business_name }}</h1>
          <span class="text-sm text-n-slate-11">{{ t('MENU.TITLE') }}</span>
        </div>
      </div>
      <nav
        v-if="categories.length > 1"
        class="max-w-2xl mx-auto px-4 pb-3 flex gap-2 overflow-x-auto"
      >
        <button
          class="shrink-0 px-3 py-1.5 rounded-full text-sm border transition-colors"
          :class="
            !category
              ? 'bg-n-brand border-n-brand text-white'
              : 'border-n-weak hover:bg-n-alpha-1'
          "
          @click="category = ''"
        >
          {{ t('MENU.ALL') }}
        </button>
        <button
          v-for="name in categories"
          :key="name"
          class="shrink-0 px-3 py-1.5 rounded-full text-sm border transition-colors"
          :class="
            category === name
              ? 'bg-n-brand border-n-brand text-white'
              : 'border-n-weak hover:bg-n-alpha-1'
          "
          @click="category = name"
        >
          {{ name || t('MENU.OTHER') }}
        </button>
      </nav>
    </header>

    <main class="max-w-2xl mx-auto px-4 py-5 grid gap-3">
      <p v-if="isLoading" class="text-sm text-n-slate-11">
        {{ t('LOADING') }}
      </p>
      <p
        v-else-if="notAvailable"
        class="p-5 rounded-2xl bg-n-solid-1 text-sm text-n-slate-11"
      >
        {{ t('MENU.NOT_AVAILABLE') }}
      </p>
      <template v-else>
        <p v-if="!shown.length" class="text-sm text-n-slate-11">
          {{ t('MENU.EMPTY') }}
        </p>
        <article
          v-for="product in shown"
          :key="product.id"
          class="flex gap-4 p-3 rounded-2xl bg-n-solid-1 shadow-sm"
        >
          <img
            v-if="product.image_url"
            :src="product.image_url"
            :alt="product.name"
            loading="lazy"
            class="size-24 shrink-0 rounded-xl object-cover bg-n-alpha-1"
          />
          <div class="grid gap-1 flex-1 min-w-0 content-start">
            <h2 class="font-semibold">{{ product.name }}</h2>
            <p
              v-if="product.description"
              class="text-sm text-n-slate-11 line-clamp-3"
            >
              {{ product.description }}
            </p>
            <div class="flex items-center justify-between gap-2 mt-1">
              <span class="font-semibold text-n-blue-11">
                {{ product.price }}
              </span>
              <a
                v-if="menu.whatsapp"
                :href="
                  whatsappLink(
                    t('MENU.ORDER_ITEM_TEXT', {
                      name: product.name,
                      price: product.price,
                    })
                  )
                "
                target="_blank"
                rel="noopener noreferrer"
                class="px-3 py-1.5 rounded-full bg-n-teal-9 text-white text-xs font-medium"
              >
                {{ t('MENU.ORDER') }}
              </a>
            </div>
          </div>
        </article>
        <p
          v-if="menu.notes"
          class="text-sm text-n-slate-11 whitespace-pre-line px-1"
        >
          {{ menu.notes }}
        </p>
      </template>
    </main>

    <a
      v-if="menu?.whatsapp"
      :href="whatsappLink(t('MENU.ORDER_TEXT'))"
      target="_blank"
      rel="noopener noreferrer"
      class="fixed bottom-5 inset-x-4 max-w-md mx-auto py-3.5 rounded-full bg-n-teal-9 text-white text-center font-medium shadow-lg"
    >
      {{ t('MENU.ORDER_ALL') }}
    </a>
  </div>
</template>
