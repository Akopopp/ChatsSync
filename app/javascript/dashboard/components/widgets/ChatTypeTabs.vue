<script setup>
import { computed } from 'vue';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';
import wootConstants from 'dashboard/constants/globals';

const props = defineProps({
  items: {
    type: Array,
    default: () => [],
  },
  activeTab: {
    type: String,
    default: wootConstants.ASSIGNEE_TYPE.ME,
  },
});

const emit = defineEmits(['chatTabChange']);

const activeTabIndex = computed(() => {
  return props.items.findIndex(item => item.key === props.activeTab);
});

const onTabChange = selectedTabIndex => {
  if (selectedTabIndex >= 0 && selectedTabIndex < props.items.length) {
    const selectedItem = props.items[selectedTabIndex];
    if (selectedItem.key !== props.activeTab) {
      emit('chatTabChange', selectedItem.key);
    }
  }
};

const keyboardEvents = {
  'Alt+KeyN': {
    action: () => {
      if (props.activeTab === wootConstants.ASSIGNEE_TYPE.ALL) {
        onTabChange(0);
      } else {
        const nextIndex = (activeTabIndex.value + 1) % props.items.length;
        onTabChange(nextIndex);
      }
    },
  },
};

useKeyboardEvents(keyboardEvents);
</script>

<template>
  <!-- WhatsApp filter pills -->
  <div class="cs-pills">
    <button
      v-for="(item, index) in items"
      :key="item.key"
      type="button"
      class="cs-pill"
      :class="{ 'cs-pill--on': item.key === activeTab }"
      @click="onTabChange(index)"
    >
      <span>{{ item.name }}</span>
      <span v-if="item.count" class="cs-pill__count">{{ item.count }}</span>
    </button>
  </div>
</template>

<style scoped lang="scss">
.cs-pills {
  @apply flex items-center gap-2 px-3 pb-2 pt-0.5 overflow-x-auto;
  scrollbar-width: none;

  &::-webkit-scrollbar {
    display: none;
  }
}

.cs-pill {
  @apply flex-shrink-0 flex items-center gap-1.5 rounded-full text-sm;
  padding: 0.3rem 0.9rem;
  background: rgb(var(--wa-hover, 245 246 246));
  color: rgb(var(--wa-text2, 84 101 111));
  transition: background-color 0.14s ease, color 0.14s ease, transform 0.12s ease;

  &:active {
    transform: scale(0.96);
  }

  &--on {
    background: rgb(var(--wa-green, 0 128 105) / 0.16);
    color: rgb(var(--wa-green, 0 128 105));
    font-weight: 500;
  }
}

.cs-pill__count {
  @apply text-xs font-semibold;
  opacity: 0.85;
}
</style>
