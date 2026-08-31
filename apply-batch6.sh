#!/bin/bash
# ============================================================
#  ChatsSync — Batch 6 : search bar, bada title, avatars hatao
#      cd /root/staging-build && git pull && bash apply-batch6.sh
# ============================================================
set -e
REPO="/root/staging-build"
COMPOSE="/data/coolify/applications/vdcb3i4jbkc4jsw204xguhk5"
[ -f "$REPO/docker/Dockerfile" ] || { echo "ERROR: repo $REPO mein nahi mila"; exit 1; }
cd "$REPO"
echo ""
echo "=== 1/3  Files likh raha hun ==="
mkdir -p "$(dirname app/javascript/dashboard/components/ChatListHeader.vue)"
cat > app/javascript/dashboard/components/ChatListHeader.vue << 'CS_EOF_3c7b9'
<script setup>
import { ref } from 'vue';
import { useRouter } from 'vue-router';
import { computed } from 'vue';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { formatNumber } from '@chatwoot/utils';
import wootConstants from 'dashboard/constants/globals';

import ConversationBasicFilter from './widgets/conversation/ConversationBasicFilter.vue';
import SwitchLayout from 'dashboard/routes/dashboard/conversation/search/SwitchLayout.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  pageTitle: { type: String, required: true },
  hasAppliedFilters: { type: Boolean, required: true },
  hasActiveFolders: { type: Boolean, required: true },
  activeStatus: { type: String, required: true },
  isOnExpandedLayout: { type: Boolean, required: true },
  conversationStats: { type: Object, required: true },
  isListLoading: { type: Boolean, required: true },
});

const emit = defineEmits([
  'addFolders',
  'deleteFolders',
  'resetFilters',
  'basicFilterChange',
  'filtersModal',
]);

const { uiSettings, updateUISettings } = useUISettings();

const onBasicFilterChange = (value, type) => {
  emit('basicFilterChange', value, type);
};

const hasAppliedFiltersOrActiveFolders = computed(() => {
  return props.hasAppliedFilters || props.hasActiveFolders;
});

const allCount = computed(() => props.conversationStats?.allCount || 0);
const formattedAllCount = computed(() => formatNumber(allCount.value));

const toggleConversationLayout = () => {
  const { LAYOUT_TYPES } = wootConstants;
  const {
    conversation_display_type: conversationDisplayType = LAYOUT_TYPES.CONDENSED,
  } = uiSettings.value;
  const newViewType =
    conversationDisplayType === LAYOUT_TYPES.CONDENSED
      ? LAYOUT_TYPES.EXPANDED
      : LAYOUT_TYPES.CONDENSED;
  updateUISettings({
    conversation_display_type: newViewType,
    previously_used_conversation_display_type: newViewType,
  });
};

// ---- WhatsApp-style search ----
const searchQuery = ref('');
const searchRouter = useRouter();
const goToSearch = () => {
  const q = searchQuery.value.trim();
  if (!q) return;
  searchRouter.push({ name: 'search', query: { q } });
};
</script>

<template>
  <div>
  <div
    class="flex items-center justify-between gap-2 px-4 h-[3.5rem]"
    :class="{
      'border-b border-n-strong': hasAppliedFiltersOrActiveFolders,
    }"
  >
    <div class="flex items-center justify-center min-w-0">
      <h1
        class="text-xl font-semibold truncate text-n-slate-12 tracking-tight"
        :title="pageTitle"
      >
        {{ pageTitle }}
      </h1>
      <span
        v-if="
          allCount > 0 && hasAppliedFiltersOrActiveFolders && !isListLoading
        "
        class="px-2 py-1 my-0.5 mx-1 rounded-md capitalize bg-n-slate-3 text-xxs text-n-slate-12 shrink-0"
        :title="allCount"
      >
        {{ formattedAllCount }}
      </span>
      <span
        v-if="!hasAppliedFiltersOrActiveFolders"
        class="px-2 py-1 my-0.5 mx-1 rounded-md capitalize bg-n-slate-3 text-xxs text-n-slate-12 shrink-0"
      >
        {{ $t(`CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.${activeStatus}.TEXT`) }}
      </span>
    </div>
    <div class="flex items-center gap-1">
      <template v-if="hasAppliedFilters && !hasActiveFolders">
        <div class="relative">
          <NextButton
            v-tooltip.top-end="$t('FILTER.CUSTOM_VIEWS.ADD.SAVE_BUTTON')"
            icon="i-lucide-save"
            slate
            xs
            faded
            @click="emit('addFolders')"
          />
          <div
            id="saveFilterTeleportTarget"
            class="absolute z-50 mt-2"
            :class="{ 'ltr:right-0 rtl:left-0': isOnExpandedLayout }"
          />
        </div>
        <NextButton
          v-tooltip.top-end="$t('FILTER.CLEAR_BUTTON_LABEL')"
          icon="i-lucide-circle-x"
          ruby
          faded
          xs
          @click="emit('resetFilters')"
        />
      </template>
      <template v-if="hasActiveFolders">
        <div class="relative">
          <NextButton
            id="toggleConversationFilterButton"
            v-tooltip.top-end="$t('FILTER.CUSTOM_VIEWS.EDIT.EDIT_BUTTON')"
            icon="i-lucide-pen-line"
            slate
            xs
            faded
            @click="emit('filtersModal')"
          />
          <div
            id="conversationFilterTeleportTarget"
            class="absolute z-50 mt-2"
            :class="{ 'ltr:right-0 rtl:left-0': isOnExpandedLayout }"
          />
        </div>
        <NextButton
          id="toggleConversationFilterButton"
          v-tooltip.top-end="$t('FILTER.CUSTOM_VIEWS.DELETE.DELETE_BUTTON')"
          icon="i-lucide-trash-2"
          ruby
          xs
          faded
          @click="emit('deleteFolders')"
        />
      </template>
      <div v-else class="relative">
        <NextButton
          id="toggleConversationFilterButton"
          v-tooltip.right="$t('FILTER.TOOLTIP_LABEL')"
          icon="i-lucide-list-filter"
          slate
          xs
          faded
          @click="emit('filtersModal')"
        />
        <div
          id="conversationFilterTeleportTarget"
          class="absolute z-50 mt-2"
          :class="{ 'ltr:right-0 rtl:left-0': isOnExpandedLayout }"
        />
      </div>
      <ConversationBasicFilter
        v-if="!hasAppliedFiltersOrActiveFolders"
        :is-on-expanded-layout="isOnExpandedLayout"
        @change-filter="onBasicFilterChange"
      />
      <SwitchLayout
        :is-on-expanded-layout="isOnExpandedLayout"
        @toggle="toggleConversationLayout"
      />
    </div>
  </div>
  <!-- WhatsApp-style search -->
  <div class="px-3 pb-2">
    <div
      class="flex items-center gap-3 px-3.5 h-9 rounded-full bg-n-alpha-2 text-n-slate-11 cursor-text focus-within:bg-n-alpha-1 transition-colors"
    >
      <span class="i-lucide-search size-4 flex-shrink-0" />
      <input
        v-model="searchQuery"
        type="text"
        class="flex-1 min-w-0 bg-transparent border-0 outline-none text-sm text-n-slate-12 placeholder:text-n-slate-10 p-0 m-0 h-full"
        placeholder="Search chats, contacts or messages"
        @keyup.enter="goToSearch"
      >
      <span
        v-if="searchQuery"
        class="i-lucide-x size-4 flex-shrink-0 cursor-pointer hover:text-n-slate-12"
        @click="searchQuery = ''"
      />
    </div>
  </div>
  </div>

</template>
CS_EOF_3c7b9
echo "  ok  app/javascript/dashboard/components/ChatListHeader.vue"

mkdir -p "$(dirname app/javascript/dashboard/components-next/message/Message.vue)"
cat > app/javascript/dashboard/components-next/message/Message.vue << 'CS_EOF_3c7b9'
<script setup>
import { onMounted, computed, ref, toRefs } from 'vue';
import { useTimeoutFn } from '@vueuse/core';
import { provideMessageContext } from './provider.js';
import { useTrack } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import { emitter } from 'shared/helpers/mitt';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { LocalStorage } from 'shared/helpers/localStorage';
import { ACCOUNT_EVENTS } from 'dashboard/helper/AnalyticsHelper/events';
import { LOCAL_STORAGE_KEYS } from 'dashboard/constants/localStorage';
import { getInboxIconByType } from 'dashboard/helper/inbox';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import {
  MESSAGE_TYPES,
  ATTACHMENT_TYPES,
  MESSAGE_VARIANTS,
  SENDER_TYPES,
  ORIENTATION,
  MESSAGE_STATUS,
  CONTENT_TYPES,
} from './constants';

import Avatar from 'next/avatar/Avatar.vue';

import TextBubble from './bubbles/Text/Index.vue';
import ActivityBubble from './bubbles/Activity.vue';
import ImageBubble from './bubbles/Image.vue';
import FileBubble from './bubbles/File.vue';
import AudioBubble from './bubbles/Audio.vue';
import VideoBubble from './bubbles/Video.vue';
import EmbedBubble from './bubbles/Embed.vue';
import FallbackBubble from './bubbles/Fallback.vue';
import InstagramStoryBubble from './bubbles/InstagramStory.vue';
import EmailBubble from './bubbles/Email/Index.vue';
import UnsupportedBubble from './bubbles/Unsupported.vue';
import ContactBubble from './bubbles/Contact.vue';
import DyteBubble from './bubbles/Dyte.vue';
import LocationBubble from './bubbles/Location.vue';
import CSATBubble from './bubbles/CSAT.vue';
import FormBubble from './bubbles/Form.vue';
import VoiceCallBubble from './bubbles/VoiceCall.vue';

import MessageError from './MessageError.vue';
import ContextMenu from 'dashboard/modules/conversations/components/MessageContextMenu.vue';
import { useBranding } from 'shared/composables/useBranding';

/**
 * @typedef {Object} Attachment
 * @property {number} id - Unique identifier for the attachment
 * @property {number} messageId - ID of the associated message
 * @property {'image'|'audio'|'video'|'file'|'location'|'fallback'|'share'|'story_mention'|'contact'|'ig_reel'} fileType - Type of the attachment (file or image)
 * @property {number} accountId - ID of the associated account
 * @property {string|null} extension - File extension
 * @property {string} dataUrl - URL to access the full attachment data
 * @property {string} thumbUrl - URL to access the thumbnail version
 * @property {number} fileSize - Size of the file in bytes
 * @property {number|null} width - Width of the image if applicable
 * @property {number|null} height - Height of the image if applicable
 */

/**
 * @typedef {Object} Sender
 * @property {Object} additional_attributes - Additional attributes of the sender
 * @property {Object} custom_attributes - Custom attributes of the sender
 * @property {string} email - Email of the sender
 * @property {number} id - ID of the sender
 * @property {string|null} identifier - Identifier of the sender
 * @property {string} name - Name of the sender
 * @property {string|null} phone_number - Phone number of the sender
 * @property {string} thumbnail - Thumbnail URL of the sender
 * @property {string} type - Type of sender
 */

/**
 * @typedef {Object} ContentAttributes
 * @property {string} externalError - an error message to be shown if the message failed to send
 */

/**
 * @typedef {Object} Props
 * @property {('sent'|'delivered'|'read'|'failed'|'progress')} status - The delivery status of the message
 * @property {ContentAttributes} [contentAttributes={}] - Additional attributes of the message content
 * @property {Attachment[]} [attachments=[]] - The attachments associated with the message
 * @property {Sender|null} [sender=null] - The sender information
 * @property {boolean} [private=false] - Whether the message is private
 * @property {number|null} [senderId=null] - The ID of the sender
 * @property {number} createdAt - Timestamp when the message was created
 * @property {number} currentUserId - The ID of the current user
 * @property {number} id - The unique identifier for the message
 * @property {number} messageType - The type of message (must be one of MESSAGE_TYPES)
 * @property {string|null} [error=null] - Error message if the message failed to send
 * @property {string|null} [senderType=null] - The type of the sender
 * @property {string} content - The message content
 * @property {boolean} [groupWithNext=false] - Whether the message should be grouped with the next message
 * @property {Object|null} [inReplyTo=null] - The message to which this message is a reply
 * @property {boolean} [isEmailInbox=false] - Whether the message is from an email inbox
 * @property {number} conversationId - The ID of the conversation to which the message belongs
 * @property {number} inboxId - The ID of the inbox to which the message belongs
 */

// eslint-disable-next-line vue/define-macros-order
const props = defineProps({
  id: { type: Number, required: true },
  messageType: {
    type: Number,
    required: true,
    validator: value => Object.values(MESSAGE_TYPES).includes(value),
  },
  status: {
    type: String,
    required: true,
    validator: value => Object.values(MESSAGE_STATUS).includes(value),
  },
  attachments: { type: Array, default: () => [] },
  call: { type: Object, default: null }, // eslint-disable-line vue/no-unused-properties
  content: { type: String, default: null },
  contentAttributes: { type: Object, default: () => ({}) },
  contentType: {
    type: String,
    default: 'text',
    validator: value => Object.values(CONTENT_TYPES).includes(value),
  },
  conversationId: { type: Number, required: true },
  createdAt: { type: Number, required: true }, // eslint-disable-line vue/no-unused-properties
  currentUserId: { type: Number, required: true }, // eslint-disable-line vue/no-unused-properties
  groupWithNext: { type: Boolean, default: false },
  inboxId: { type: Number, default: null }, // eslint-disable-line vue/no-unused-properties
  inboxSupportsReplyTo: { type: Object, default: () => ({}) },
  inReplyTo: { type: Object, default: null }, // eslint-disable-line vue/no-unused-properties
  isEmailInbox: { type: Boolean, default: false },
  private: { type: Boolean, default: false },
  additionalAttributes: { type: Object, default: () => ({}) }, // eslint-disable-line vue/no-unused-properties
  sender: { type: Object, default: null },
  senderId: { type: Number, default: null },
  senderType: { type: String, default: null },
  sourceId: { type: String, default: '' }, // eslint-disable-line vue/no-unused-properties
});

const emit = defineEmits(['retry']);

const contextMenuPosition = ref({});
const showBackgroundHighlight = ref(false);
const showContextMenu = ref(false);
const { t } = useI18n();
const route = useRoute();
const inboxGetter = useMapGetter('inboxes/getInbox');
const inbox = computed(() => inboxGetter.value(props.inboxId) || {});
const { replaceInstallationName } = useBranding();

/**
 * Computes the message variant based on props
 * @type {import('vue').ComputedRef<'user'|'agent'|'activity'|'private'|'bot'|'template'>}
 */
const variant = computed(() => {
  if (props.private) return MESSAGE_VARIANTS.PRIVATE;

  if (props.isEmailInbox) {
    const emailInboxTypes = [MESSAGE_TYPES.INCOMING, MESSAGE_TYPES.OUTGOING];
    if (emailInboxTypes.includes(props.messageType)) {
      return MESSAGE_VARIANTS.EMAIL;
    }
  }

  if (props.contentType === CONTENT_TYPES.INCOMING_EMAIL) {
    return MESSAGE_VARIANTS.EMAIL;
  }

  if (props.status === MESSAGE_STATUS.FAILED) return MESSAGE_VARIANTS.ERROR;
  if (props.contentAttributes?.isUnsupported)
    return MESSAGE_VARIANTS.UNSUPPORTED;

  if (props.contentAttributes?.externalEcho) {
    return MESSAGE_VARIANTS.AGENT;
  }

  const isBot =
    props.sender?.type === SENDER_TYPES.AGENT_BOT ||
    props.senderType === SENDER_TYPES.AGENT_BOT ||
    (!props.sender && !props.additionalAttributes?.senderName);
  if (isBot && props.messageType === MESSAGE_TYPES.OUTGOING) {
    return MESSAGE_VARIANTS.BOT;
  }

  const variants = {
    [MESSAGE_TYPES.INCOMING]: MESSAGE_VARIANTS.USER,
    [MESSAGE_TYPES.ACTIVITY]: MESSAGE_VARIANTS.ACTIVITY,
    [MESSAGE_TYPES.OUTGOING]: MESSAGE_VARIANTS.AGENT,
    [MESSAGE_TYPES.TEMPLATE]: MESSAGE_VARIANTS.TEMPLATE,
  };

  return variants[props.messageType] || MESSAGE_VARIANTS.USER;
});

const isBotOrAgentMessage = computed(() => {
  if (props.messageType === MESSAGE_TYPES.ACTIVITY) {
    return false;
  }
  // if an outgoing message is still processing, then it's definitely a
  // message sent by the current user
  if (
    props.status === MESSAGE_STATUS.PROGRESS &&
    props.messageType === MESSAGE_TYPES.OUTGOING
  ) {
    return true;
  }
  const senderId = props.senderId ?? props.sender?.id;
  const senderType = props.sender?.type ?? props.senderType;

  if (!senderType || !senderId) {
    return true;
  }

  if (
    [SENDER_TYPES.AGENT_BOT, SENDER_TYPES.CAPTAIN_ASSISTANT].includes(
      senderType
    )
  ) {
    return true;
  }

  return senderType.toLowerCase() === SENDER_TYPES.USER.toLowerCase();
});

/**
 * Computes the message orientation based on sender type and message type
 * @returns {import('vue').ComputedRef<'left'|'right'|'center'>} The computed orientation
 */
const orientation = computed(() => {
  if (isBotOrAgentMessage.value) {
    return ORIENTATION.RIGHT;
  }

  if (props.messageType === MESSAGE_TYPES.ACTIVITY) return ORIENTATION.CENTER;

  return ORIENTATION.LEFT;
});

const flexOrientationClass = computed(() => {
  const map = {
    [ORIENTATION.LEFT]: 'justify-start',
    [ORIENTATION.RIGHT]: 'justify-end',
    [ORIENTATION.CENTER]: 'justify-center',
  };

  return map[orientation.value];
});

const gridClass = computed(() => {
  const map = {
    [ORIENTATION.LEFT]: 'grid grid-cols-1fr',
    [ORIENTATION.RIGHT]: 'grid grid-cols-[1fr_24px]',
  };

  return map[orientation.value];
});

const gridTemplate = computed(() => {
  const map = {
    [ORIENTATION.LEFT]: `
      "bubble"
      "meta"
    `,
    [ORIENTATION.RIGHT]: `
      "bubble avatar"
      "meta spacer"
    `,
  };

  return map[orientation.value];
});

const shouldGroupWithNext = computed(() => {
  if (props.status === MESSAGE_STATUS.FAILED) return false;

  return props.groupWithNext;
});

const shouldShowAvatar = computed(() => {
  // WhatsApp mein bubble ke saath avatar nahi hota — dono taraf band
  return false;
});

const componentToRender = computed(() => {
  if (props.isEmailInbox && !props.private) {
    const emailInboxTypes = [MESSAGE_TYPES.INCOMING, MESSAGE_TYPES.OUTGOING];
    if (emailInboxTypes.includes(props.messageType)) return EmailBubble;
  }

  if (props.contentType === CONTENT_TYPES.INPUT_CSAT) {
    return CSATBubble;
  }

  if (
    [CONTENT_TYPES.INPUT_SELECT, CONTENT_TYPES.FORM].includes(props.contentType)
  ) {
    return FormBubble;
  }

  if (props.contentType === CONTENT_TYPES.VOICE_CALL) {
    return VoiceCallBubble;
  }

  if (props.contentType === CONTENT_TYPES.INCOMING_EMAIL) {
    return EmailBubble;
  }

  if (props.contentAttributes?.isUnsupported) {
    return UnsupportedBubble;
  }

  if (props.contentAttributes.type === 'dyte') {
    return DyteBubble;
  }

  const instagramSharedTypes = [
    ATTACHMENT_TYPES.STORY_MENTION,
    ATTACHMENT_TYPES.IG_STORY,
    ATTACHMENT_TYPES.IG_STORY_REPLY,
    ATTACHMENT_TYPES.IG_POST,
  ];
  if (instagramSharedTypes.includes(props.contentAttributes.imageType)) {
    return InstagramStoryBubble;
  }

  if (Array.isArray(props.attachments) && props.attachments.length === 1) {
    const fileType = props.attachments[0].fileType;

    if (fileType === ATTACHMENT_TYPES.FALLBACK) return FallbackBubble;

    if (!props.content) {
      if (fileType === ATTACHMENT_TYPES.IMAGE) return ImageBubble;
      if (fileType === ATTACHMENT_TYPES.FILE) return FileBubble;
      if (fileType === ATTACHMENT_TYPES.AUDIO) return AudioBubble;
      if (fileType === ATTACHMENT_TYPES.VIDEO) return VideoBubble;
      if (fileType === ATTACHMENT_TYPES.IG_REEL) return VideoBubble;
      if (fileType === ATTACHMENT_TYPES.EMBED) return EmbedBubble;
      if (fileType === ATTACHMENT_TYPES.LOCATION) return LocationBubble;
    }
    // Attachment content is the name of the contact
    if (fileType === ATTACHMENT_TYPES.CONTACT) return ContactBubble;
  }

  return TextBubble;
});

const shouldShowContextMenu = computed(() => {
  return !props.contentAttributes?.isUnsupported;
});

const isBubble = computed(() => {
  return props.messageType !== MESSAGE_TYPES.ACTIVITY;
});

const isMessageDeleted = computed(() => {
  return props.contentAttributes?.deleted;
});

const payloadForContextMenu = computed(() => {
  return {
    id: props.id,
    content_attributes: props.contentAttributes,
    content: props.content,
    conversation_id: props.conversationId,
  };
});

const contextMenuEnabledOptions = computed(() => {
  const hasText = !!props.content;
  const hasAttachments = !!(props.attachments && props.attachments.length > 0);

  const isOutgoing = props.messageType === MESSAGE_TYPES.OUTGOING;
  const isFailedOrProcessing =
    props.status === MESSAGE_STATUS.FAILED ||
    props.status === MESSAGE_STATUS.PROGRESS;

  return {
    copy: hasText,
    delete:
      (hasText || hasAttachments) &&
      !isFailedOrProcessing &&
      !isMessageDeleted.value,
    cannedResponse: isOutgoing && hasText && !isMessageDeleted.value,
    copyLink: !isFailedOrProcessing,
    translate: !isFailedOrProcessing && !isMessageDeleted.value && hasText,
    replyTo:
      !props.private &&
      props.inboxSupportsReplyTo.outgoing &&
      !isFailedOrProcessing,
  };
});

const shouldRenderMessage = computed(() => {
  const hasAttachments = !!(props.attachments && props.attachments.length > 0);
  const isEmailContentType = props.contentType === CONTENT_TYPES.INCOMING_EMAIL;
  const isUnsupported = props.contentAttributes?.isUnsupported;
  const isAnIntegrationMessage =
    props.contentType === CONTENT_TYPES.INTEGRATIONS;
  const isFailedMessage = props.status === MESSAGE_STATUS.FAILED;
  const hasExternalError = !!props.contentAttributes?.externalError;

  return (
    hasAttachments ||
    props.content ||
    isEmailContentType ||
    isUnsupported ||
    isAnIntegrationMessage ||
    isFailedMessage ||
    hasExternalError
  );
});

function openContextMenu(e) {
  const shouldSkipContextMenu =
    e.target?.classList.contains('skip-context-menu') ||
    ['a', 'img'].includes(e.target?.tagName.toLowerCase());
  if (shouldSkipContextMenu || getSelection().toString()) {
    return;
  }

  e.preventDefault();
  if (e.type === 'contextmenu') {
    useTrack(ACCOUNT_EVENTS.OPEN_MESSAGE_CONTEXT_MENU);
  }
  contextMenuPosition.value = {
    x: e.pageX || e.clientX,
    y: e.pageY || e.clientY,
  };
  showContextMenu.value = true;
}

function closeContextMenu() {
  showContextMenu.value = false;
  contextMenuPosition.value = { x: null, y: null };
}

function handleReplyTo() {
  const replyStorageKey = LOCAL_STORAGE_KEYS.MESSAGE_REPLY_TO;
  const { conversationId, id: replyTo } = props;

  LocalStorage.updateJsonStore(replyStorageKey, conversationId, replyTo);
  emitter.emit(BUS_EVENTS.TOGGLE_REPLY_TO_MESSAGE, props);
}

const avatarInfo = computed(() => {
  if (props.contentAttributes?.externalEcho) {
    const { name, avatar_url, channel_type, medium } = inbox.value;
    const iconName = avatar_url
      ? null
      : getInboxIconByType(channel_type, medium);
    return {
      name: iconName ? '' : name || t('CONVERSATION.NATIVE_APP'),
      src: avatar_url || '',
      iconName,
    };
  }

  // If no sender, check for Slack (or other integration) sender info
  if (!props.sender) {
    const { senderName, senderAvatarUrl } = props.additionalAttributes || {};
    if (senderName) {
      return { name: senderName, src: senderAvatarUrl ?? '' };
    }
    return { name: t('CONVERSATION.BOT'), src: '' };
  }

  const { sender } = props;
  const { name, type, avatarUrl, thumbnail } = sender || {};

  // If sender type is agent bot, use avatarUrl
  if ([SENDER_TYPES.AGENT_BOT, SENDER_TYPES.CAPTAIN_ASSISTANT].includes(type)) {
    return {
      name: name ?? '',
      src: avatarUrl ?? '',
    };
  }

  // For all other senders, use thumbnail
  return {
    name: name ?? '',
    src: thumbnail ?? '',
  };
});

const avatarTooltip = computed(() => {
  if (props.contentAttributes?.externalEcho) {
    return replaceInstallationName(t('CONVERSATION.NATIVE_APP_ADVISORY'));
  }
  if (avatarInfo.value.name === '') return '';
  return `${t('CONVERSATION.SENT_BY')} ${avatarInfo.value.name}`;
});

const setupHighlightTimer = () => {
  if (Number(route.query.messageId) !== Number(props.id)) {
    return;
  }

  showBackgroundHighlight.value = true;
  const HIGHLIGHT_TIMER = 1000;
  useTimeoutFn(() => {
    showBackgroundHighlight.value = false;
  }, HIGHLIGHT_TIMER);
};

onMounted(setupHighlightTimer);

provideMessageContext({
  ...toRefs(props),
  isPrivate: computed(() => props.private),
  variant,
  orientation,
  isBotOrAgentMessage,
  shouldGroupWithNext,
});
</script>

<!-- eslint-disable-next-line vue/no-root-v-if -->
<template>
  <div
    v-if="shouldRenderMessage"
    :id="`message${props.id}`"
    class="flex w-full mb-2 message-bubble-container"
    :data-message-id="props.id"
    :class="[
      flexOrientationClass,
      {
        'group-with-next': shouldGroupWithNext,
        'bg-n-alpha-1': showBackgroundHighlight,
      },
    ]"
  >
    <div v-if="variant === MESSAGE_VARIANTS.ACTIVITY">
      <ActivityBubble :content="content" />
    </div>
    <div
      v-else
      :class="[
        gridClass,
        {
          'gap-y-2': contentAttributes.externalError,
          'w-full': variant === MESSAGE_VARIANTS.EMAIL,
        },
      ]"
      class="gap-x-2"
      :style="{
        gridTemplateAreas: gridTemplate,
      }"
    >
      <div
        v-if="!shouldGroupWithNext && shouldShowAvatar"
        v-tooltip.left-end="avatarTooltip"
        class="[grid-area:avatar] flex items-end"
      >
        <Avatar v-bind="avatarInfo" :size="24" />
      </div>
      <div
        class="[grid-area:bubble] flex min-w-0"
        :class="{
          'ltr:ml-8 rtl:mr-8 justify-end': orientation === ORIENTATION.RIGHT,
          'ltr:mr-8 rtl:ml-8': orientation === ORIENTATION.LEFT,
        }"
        @contextmenu="openContextMenu($event)"
      >
        <Component :is="componentToRender" />
      </div>
      <MessageError
        v-if="contentAttributes.externalError"
        class="[grid-area:meta]"
        :class="flexOrientationClass"
        :error="contentAttributes.externalError"
        @retry="emit('retry')"
      />
    </div>
    <div v-if="shouldShowContextMenu" class="context-menu-wrap">
      <ContextMenu
        v-if="isBubble"
        :context-menu-position="contextMenuPosition"
        :is-open="showContextMenu"
        :enabled-options="contextMenuEnabledOptions"
        :message="payloadForContextMenu"
        hide-button
        @open="openContextMenu"
        @close="closeContextMenu"
        @reply-to="handleReplyTo"
      />
    </div>
  </div>
</template>

<style lang="scss">
/* ---- WhatsApp bubble tail ----
   Group ka pehla bubble sharp kona + nok leta hai.
   Baad wale bubbles poore gol, bina nok ke.                */
.left-bubble,
.right-bubble {
  position: relative;
}

.left-bubble::before,
.right-bubble::before {
  content: '';
  position: absolute;
  top: 0;
  width: 0;
  height: 0;
  border-top-width: 10px;
  border-top-style: solid;
  border-top-color: transparent;
}

.left-bubble::before {
  left: -9px;
  border-left: 9px solid transparent;
}

.right-bubble::before {
  right: -9px;
  border-right: 9px solid transparent;
}

/* nok ka rang bubble ke rang se milta hai */
.left-bubble.bg-n-solid-received::before {
  border-top-color: rgb(var(--solid-received));
}
.right-bubble.bg-n-solid-sent::before {
  border-top-color: rgb(var(--solid-sent));
}
.right-bubble.bg-n-solid-amber::before {
  border-top-color: rgb(var(--solid-amber));
}

/* group ke baad wale bubbles: poore gol, nok nahi */
.group-with-next + .message-bubble-container {
  .left-bubble,
  .right-bubble {
    @apply rounded-lg;
  }

  .left-bubble::before,
  .right-bubble::before {
    display: none;
  }
}
</style>
CS_EOF_3c7b9
echo "  ok  app/javascript/dashboard/components-next/message/Message.vue"


echo ""
echo "=== 2/3  Build ==="
docker build -f docker/Dockerfile -t chatssync-staging:latest .
echo ""
echo "=== 3/3  Restart ==="
cd "$COMPOSE"
docker compose up -d
echo ""
echo "============================================"
echo "  HO GAYA — Ctrl+Shift+R dabana"
echo "============================================"
