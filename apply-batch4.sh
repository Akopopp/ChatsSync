#!/bin/bash
# ============================================================
#  ChatsSync — Batch 4 : chat list, composer height, bubble tail
#      cd /root/staging-build && git pull && bash apply-batch4.sh
# ============================================================
set -e
REPO="/root/staging-build"
COMPOSE="/data/coolify/applications/vdcb3i4jbkc4jsw204xguhk5"
[ -f "$REPO/docker/Dockerfile" ] || { echo "ERROR: repo $REPO mein nahi mila"; exit 1; }
cd "$REPO"
echo ""
echo "=== 1/3  Files likh raha hun ==="
mkdir -p "$(dirname app/javascript/dashboard/components/widgets/conversation/ConversationCard.vue)"
cat > app/javascript/dashboard/components/widgets/conversation/ConversationCard.vue << 'CS_EOF_1a6f8'
<script setup>
import { computed, ref, watch } from 'vue';
import { getLastMessage } from 'dashboard/helper/conversationHelper';
import Avatar from 'next/avatar/Avatar.vue';
import MessagePreview from './MessagePreview.vue';
import InboxName from '../InboxName.vue';
import TimeAgo from 'dashboard/components/ui/TimeAgo.vue';
import CardLabels from './conversationCardComponents/CardLabels.vue';
import CardPriorityIcon from 'dashboard/components-next/Conversation/ConversationCard/CardPriorityIcon.vue';
import UnreadBadge from 'dashboard/components-next/Conversation/ConversationCard/UnreadBadge.vue';
import SLACardLabel from './components/SLACardLabel.vue';
import VoiceCallStatus from './VoiceCallStatus.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';

const props = defineProps({
  chat: { type: Object, required: true },
  currentContact: { type: Object, required: true },
  assignee: { type: Object, default: () => ({}) },
  inbox: { type: Object, default: () => ({}) },
  selected: { type: Boolean, default: false },
  isActiveChat: { type: Boolean, default: false },
  showAssignee: { type: Boolean, default: false },
  showInboxName: { type: Boolean, default: false },
  hideThumbnail: { type: Boolean, default: false },
  compact: { type: Boolean, default: false },
});

const emit = defineEmits([
  'click',
  'contextmenu',
  'selectConversation',
  'deSelectConversation',
]);

const hovered = ref(false);

const unreadCount = computed(() => props.chat.unread_count);
const hasUnread = computed(() => unreadCount.value > 0);
const lastMessageInChat = computed(() => getLastMessage(props.chat));

const voiceCallData = computed(() => {
  const last = lastMessageInChat.value;
  if (last?.content_type !== 'voice_call' || !last.call) {
    return { status: null, direction: null };
  }
  return {
    status: last.call.status,
    direction: last.call.direction === 'outgoing' ? 'outbound' : 'inbound',
  };
});

const showMetaSection = computed(() => {
  return (
    props.showInboxName ||
    (props.showAssignee && props.assignee.name) ||
    props.chat.priority
  );
});

const hasSlaPolicyId = computed(() => props.chat?.sla_policy_id);

const showLabelsSection = computed(() => {
  return props.chat.labels?.length > 0 || hasSlaPolicyId.value;
});

const messagePreviewClass = computed(() => {
  return [
    hasUnread.value ? 'font-medium text-n-slate-12' : 'text-n-slate-11',
    !props.compact && hasUnread.value ? 'ltr:pr-4 rtl:pl-4' : '',
    props.compact && hasUnread.value ? 'ltr:pr-6 rtl:pl-6' : '',
  ];
});

const onThumbnailHover = () => {
  hovered.value = !props.hideThumbnail;
};

const onThumbnailLeave = () => {
  hovered.value = false;
};

const onSelectConversation = checked => {
  if (checked) {
    emit('selectConversation', props.chat.id, props.inbox.id);
  } else {
    emit('deSelectConversation', props.chat.id, props.inbox.id);
  }
};

const selectedModel = computed({
  get: () => props.selected,
  set: value => onSelectConversation(value),
});

watch(
  () => props.chat.id,
  () => {
    hovered.value = false;
  }
);
</script>

<template>
  <div
    class="relative flex items-start flex-grow-0 flex-shrink-0 w-auto max-w-full py-0 cursor-pointer conversation border-b border-n-slate-3 hover:border-n-surface-1 hover:bg-n-alpha-1 dark:hover:bg-n-alpha-3 group hover:z-[1] before:content-[none] before:absolute before:-top-px before:inset-x-0 before:h-px before:bg-n-surface-1 before:pointer-events-none hover:before:content-['']"
    :class="{
      'active animate-card-select bg-n-background !border-n-surface-1':
        isActiveChat,
      'selected bg-n-slate-2 !border-n-surface-1': selected,
      'px-0': compact,
      'px-4': !compact,
    }"
    @click="$emit('click', $event)"
    @contextmenu="$emit('contextmenu', $event)"
  >
    <div
      class="relative"
      @mouseenter="onThumbnailHover"
      @mouseleave="onThumbnailLeave"
    >
      <Avatar
        v-if="!hideThumbnail"
        :name="currentContact.name"
        :src="currentContact.thumbnail"
        :size="48"
        :status="currentContact.availability_status"
        :class="!showInboxName ? 'mt-3' : 'mt-6'"
        hide-offline-status
      >
        <template #overlay="{ size }">
          <label
            v-if="hovered || selected"
            class="flex items-center justify-center rounded-full cursor-pointer absolute inset-0 z-10 backdrop-blur-[2px]"
            :style="{ width: `${size}px`, height: `${size}px` }"
            @click.stop
          >
            <Checkbox v-model="selectedModel" />
          </label>
        </template>
      </Avatar>
    </div>
    <div class="px-0 py-2.5 flex-1 min-w-0 border-line">
      <div
        v-if="showMetaSection"
        class="flex items-center min-w-0 gap-1"
        :class="{
          'ltr:ml-2 rtl:mr-2': !compact,
          'mx-2': compact,
        }"
      >
        <InboxName v-if="showInboxName" :inbox="inbox" class="flex-1 min-w-0" />
        <div
          class="flex items-baseline gap-2 flex-shrink-0"
          :class="{
            'flex-1 justify-between': !showInboxName,
          }"
        >
          <span
            v-if="showAssignee && assignee.name"
            class="text-n-slate-11 text-xs font-medium leading-3 py-0.5 px-0 inline-flex items-center truncate"
          >
            <fluent-icon icon="person" size="12" class="text-n-slate-11" />
            {{ assignee.name }}
          </span>
          <CardPriorityIcon
            :priority="chat.priority"
            class="flex-shrink-0 !size-3.5"
          />
        </div>
      </div>
      <h4
        class="conversation--user text-base my-0 mx-3 capitalize pt-0.5 text-ellipsis overflow-hidden whitespace-nowrap flex-1 min-w-0 ltr:pr-16 rtl:pl-16 text-n-slate-12"
        :class="hasUnread ? 'font-medium' : 'font-normal'"
      >
        {{ currentContact.name }}
      </h4>
      <VoiceCallStatus
        v-if="voiceCallData.status"
        key="voice-status-row"
        :status="voiceCallData.status"
        :direction="voiceCallData.direction"
        :message-preview-class="messagePreviewClass"
      />
      <MessagePreview
        v-else-if="lastMessageInChat"
        key="message-preview"
        :message="lastMessageInChat"
        class="my-0 mx-2 leading-6 h-6 flex-1 min-w-0 text-sm"
        :class="messagePreviewClass"
      />
      <p
        v-else
        key="no-messages"
        class="text-n-slate-11 text-sm my-0 mx-2 leading-6 h-6 flex-1 min-w-0 overflow-hidden text-ellipsis whitespace-nowrap"
        :class="messagePreviewClass"
      >
        <fluent-icon
          size="16"
          class="-mt-0.5 align-middle inline-block text-n-slate-10"
          icon="info"
        />
        <span class="mx-0.5">
          {{ $t(`CHAT_LIST.NO_MESSAGES`) }}
        </span>
      </p>
      <div
        class="absolute flex flex-col ltr:right-3 rtl:left-3"
        :class="showMetaSection ? 'top-8' : 'top-4'"
      >
        <span class="ml-auto font-normal leading-4 text-xxs">
          <TimeAgo
            :last-activity-timestamp="chat.timestamp"
            :created-at-timestamp="chat.created_at"
            :conversation-id="chat.id"
          />
        </span>
        <UnreadBadge
          v-if="hasUnread"
          :count="unreadCount"
          class="ltr:ml-auto rtl:mr-auto mt-1"
        />
      </div>
      <CardLabels
        v-if="showLabelsSection"
        :conversation-labels="chat.labels"
        class="mt-0.5 mx-2 mb-0"
      >
        <template v-if="hasSlaPolicyId" #before>
          <SLACardLabel :chat="chat" class="ltr:mr-1 rtl:ml-1" />
        </template>
      </CardLabels>
    </div>
  </div>
</template>
CS_EOF_1a6f8
echo "  ok  app/javascript/dashboard/components/widgets/conversation/ConversationCard.vue"

mkdir -p "$(dirname app/javascript/dashboard/components-next/message/Message.vue)"
cat > app/javascript/dashboard/components-next/message/Message.vue << 'CS_EOF_1a6f8'
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
  if (props.messageType === MESSAGE_TYPES.ACTIVITY) return false;
  if (orientation.value === ORIENTATION.LEFT) return false;

  return true;
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
CS_EOF_1a6f8
echo "  ok  app/javascript/dashboard/components-next/message/Message.vue"

mkdir -p "$(dirname app/javascript/dashboard/components/widgets/WootWriter/Editor.vue)"
cat > app/javascript/dashboard/components/widgets/WootWriter/Editor.vue << 'CS_EOF_1a6f8'
<script setup>
// TODO This is a huge component, we should split this up into separate composables
// like `useSignature`, `useImageHandling`, `useFileUpload`, `useSpecialContent``
import {
  ref,
  unref,
  computed,
  watch,
  onMounted,
  useTemplateRef,
  nextTick,
} from 'vue';

import CannedResponse from '../conversation/CannedResponse.vue';
import KeyboardEmojiSelector from './keyboardEmojiSelector.vue';
import TagAgents from '../conversation/TagAgents.vue';
import VariableList from '../conversation/VariableList.vue';
import TagTools from '../conversation/TagTools.vue';
import CopilotMenuBar from './CopilotMenuBar.vue';

import { useEmitter } from 'dashboard/composables/emitter';
import { useI18n } from 'vue-i18n';
import { useCaptain } from 'dashboard/composables/useCaptain';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';
import { useTrack } from 'dashboard/composables';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useAlert } from 'dashboard/composables';
import { vOnClickOutside } from '@vueuse/components';

import { BUS_EVENTS } from 'shared/constants/busEvents';
import {
  CONVERSATION_EVENTS,
  CAPTAIN_EVENTS,
} from 'dashboard/helper/AnalyticsHelper/events';

import {
  messageSchema,
  buildMessageSchema,
  buildEditor,
  EditorView,
  MessageMarkdownTransformer,
  MessageMarkdownSerializer,
  EditorState,
  Selection,
  imageResizeView,
} from '@chatwoot/prosemirror-schema';
import {
  suggestionsPlugin,
  triggerCharacters,
} from '@chatwoot/prosemirror-schema/src/mentions/plugin';

import {
  appendSignature,
  collapseSelection,
  findNodeToInsertImage,
  getContentNode,
  insertAtCursor,
  removeSignature as removeSignatureHelper,
  scrollCursorIntoView,
  getFormattingForEditor,
  getSelectionCoords,
  calculateMenuPosition,
  getEffectiveChannelType,
  stripUnsupportedFormatting,
} from 'dashboard/helper/editorHelper';
import {
  hasPressedEnterAndNotCmdOrShift,
  hasPressedCommandAndEnter,
  isEscape,
} from 'shared/helpers/KeyboardHelpers';
import { createTypingIndicator } from '@chatwoot/utils';
import { checkFileSizeLimit } from 'shared/helpers/FileHelper';
import { uploadFile } from 'dashboard/helper/uploadHelper';
import { INBOX_TYPES } from 'dashboard/helper/inbox';

const props = defineProps({
  modelValue: { type: String, default: '' },
  editorId: { type: String, default: '' },
  placeholder: { type: String, default: '' },
  disabled: { type: Boolean, default: false },
  isPrivate: { type: Boolean, default: false },
  enableSuggestions: { type: Boolean, default: true },
  overrideLineBreaks: { type: Boolean, default: false },
  updateSelectionWith: { type: String, default: '' },
  enableVariables: { type: Boolean, default: false },
  enableCannedResponses: { type: Boolean, default: true },
  enableCaptainTools: { type: Boolean, default: false },
  variables: { type: Object, default: () => ({}) },
  signature: { type: String, default: '' },
  // allowSignature is a kill switch, ensuring no signature methods
  // are triggered except when this flag is true
  allowSignature: { type: Boolean, default: false },
  channelType: { type: String, default: '' },
  conversationId: { type: Number, default: null },
  medium: { type: String, default: '' },
  focusOnMount: { type: Boolean, default: true },
});

const emit = defineEmits([
  'typingOn',
  'typingOff',
  'toggleUserMention',
  'toggleCannedMenu',
  'toggleVariablesMenu',
  'toggleToolsMenu',
  'clearSelection',
  'blur',
  'focus',
  'input',
  'update:modelValue',
  'executeCopilotAction',
]);

const { t } = useI18n();
const { captainTasksEnabled } = useCaptain();

const TYPING_INDICATOR_IDLE_TIME = 4000;
const MAXIMUM_FILE_UPLOAD_SIZE = 4; // in MB
const DEFAULT_FORMATTING = 'Context::Default';
const PRIVATE_NOTE_FORMATTING = 'Context::PrivateNote';
const MESSAGE_SIGNATURE_FORMATTING = 'Context::MessageSignature';
const INLINE_IMAGE_PASTE_TYPES = [
  'image/png',
  'image/jpeg',
  'image/jpg',
  'image/gif',
  'image/webp',
];

const effectiveChannelType = computed(() =>
  getEffectiveChannelType(props.channelType, props.medium)
);

const editorSchema = computed(() => {
  if (!props.channelType) return messageSchema;

  const formatType = props.isPrivate
    ? PRIVATE_NOTE_FORMATTING
    : effectiveChannelType.value;
  const formatting = getFormattingForEditor(
    formatType,
    captainTasksEnabled.value
  );
  return buildMessageSchema(formatting.marks, formatting.nodes);
});

const editorMenuOptions = computed(() => {
  const formatType = props.isPrivate
    ? PRIVATE_NOTE_FORMATTING
    : effectiveChannelType.value || DEFAULT_FORMATTING;
  const formatting = getFormattingForEditor(
    formatType,
    captainTasksEnabled.value
  );

  return formatting.menu;
});

const createState = (content, placeholder, plugins = [], methods = {}) => {
  const schema = editorSchema.value;
  // Strip unsupported formatting before parsing to prevent "Token type not supported" errors
  const sanitizedContent = stripUnsupportedFormatting(content, schema);
  return EditorState.create({
    doc: new MessageMarkdownTransformer(schema).parse(sanitizedContent),
    plugins: buildEditor({
      schema,
      placeholder,
      methods,
      plugins,
      enabledMenuOptions: editorMenuOptions.value,
    }),
  });
};

const { isEditorHotKeyEnabled, fetchSignatureFlagFromUISettings } =
  useUISettings();

const typingIndicator = createTypingIndicator(
  () => emit('typingOn'),
  () => emit('typingOff'),
  TYPING_INDICATOR_IDLE_TIME
);

// we don't need them to be reactive
// It cases weird issues where the objects are proxied
// and then the editor doesn't work as expected
// We have to wrap them in closures or use toRaw to get the actual values
let editorView = null;
let state = null;

const showUserMentions = ref(false);
const showCannedMenu = ref(false);
const showVariables = ref(false);
const showEmojiMenu = ref(false);
const showToolsMenu = ref(false);
const mentionSearchKey = ref('');
const toolSearchKey = ref('');
const cannedSearchTerm = ref('');
const variableSearchTerm = ref('');
const emojiSearchTerm = ref('');
const range = ref(null);
const isTextSelected = ref(false); // Tracks text selection and prevents unnecessary re-renders on mouse selection
const showSelectionMenu = ref(false);

// element ref
const editorRoot = useTemplateRef('editorRoot');
const imageUpload = useTemplateRef('imageUpload');
const editor = useTemplateRef('editor');

const isEditorMenuPopover = computed(
  () =>
    editorRoot.value?.classList.contains('popover-prosemirror-menu') ?? false
);

const handleCopilotAction = actionKey => {
  if (actionKey === 'improve_selection' && editorView?.state) {
    const { from, to } = editorView.state.selection;
    const selectedText = editorView.state.doc.textBetween(from, to).trim();

    if (from !== to && selectedText) {
      emit('executeCopilotAction', 'improve', selectedText);
    }
  } else {
    emit('executeCopilotAction', actionKey, props.modelValue);
  }

  showSelectionMenu.value = false;
};

const contentFromEditor = () => {
  return MessageMarkdownSerializer.serialize(editorView.state.doc);
};

const shouldShowVariables = computed(() => {
  return props.enableVariables && showVariables.value && !props.isPrivate;
});

const shouldShowCannedResponses = computed(() => {
  return (
    props.enableCannedResponses && showCannedMenu.value && !props.isPrivate
  );
});

function createSuggestionPlugin({
  trigger,
  minChars = 0,
  showMenu,
  searchTerm,
  isAllowed = () => true,
}) {
  return suggestionsPlugin({
    matcher: triggerCharacters(trigger, minChars),
    suggestionClass: '',
    onEnter: args => {
      if (!isAllowed()) return false;
      showMenu.value = true;
      range.value = args.range;
      editorView = args.view;
      if (searchTerm) searchTerm.value = args.text || '';
      return false;
    },
    onChange: args => {
      editorView = args.view;
      range.value = args.range;
      if (searchTerm) searchTerm.value = args.text;
      return false;
    },
    onExit: () => {
      if (searchTerm) searchTerm.value = '';
      showMenu.value = false;
      return false;
    },
    onKeyDown: ({ event }) => {
      return event.keyCode === 13 && showMenu.value;
    },
  });
}

const plugins = computed(() => {
  if (!props.enableSuggestions) {
    return [];
  }

  return [
    createSuggestionPlugin({
      trigger: '@',
      showMenu: showToolsMenu,
      searchTerm: toolSearchKey,
      isAllowed: () => props.enableCaptainTools,
    }),
    createSuggestionPlugin({
      trigger: '@',
      showMenu: showUserMentions,
      searchTerm: mentionSearchKey,
      isAllowed: () => props.isPrivate || !props.enableCaptainTools,
    }),
    createSuggestionPlugin({
      trigger: '/',
      showMenu: showCannedMenu,
      searchTerm: cannedSearchTerm,
      isAllowed: () => !props.isPrivate,
    }),
    createSuggestionPlugin({
      trigger: '{{',
      showMenu: showVariables,
      searchTerm: variableSearchTerm,
      isAllowed: () => !props.isPrivate,
    }),
    createSuggestionPlugin({
      trigger: ':',
      minChars: 2,
      showMenu: showEmojiMenu,
      searchTerm: emojiSearchTerm,
    }),
  ];
});

const sendWithSignature = computed(() => {
  // this is considered the source of truth, we watch this property
  // on change, we toggle the signature in the editor
  if (
    props.allowSignature &&
    !props.isPrivate &&
    props.channelType &&
    !props.disabled
  ) {
    return fetchSignatureFlagFromUISettings(props.channelType);
  }

  return false;
});

watch(showUserMentions, updatedValue => {
  emit('toggleUserMention', props.isPrivate && updatedValue);
});
watch(showCannedMenu, updatedValue => {
  emit('toggleCannedMenu', !props.isPrivate && updatedValue);
});
watch(showVariables, updatedValue => {
  emit('toggleVariablesMenu', !props.isPrivate && updatedValue);
});
watch(showToolsMenu, updatedValue => {
  emit('toggleToolsMenu', props.enableCaptainTools && updatedValue);
});

function focusEditorInputField(pos = 'end') {
  const { tr } = editorView.state;

  const selection =
    pos === 'end' ? Selection.atEnd(tr.doc) : Selection.atStart(tr.doc);

  editorView.dispatch(tr.setSelection(selection));
  editorView.focus();
}

function isBodyEmpty(content) {
  // if content is undefined, we assume that the body is empty
  if (!content) return true;

  // Only strip the signature when it's actually being auto-appended for this
  // draft. Otherwise an agent whose typed text happens to match their saved
  // signature would be mistakenly treated as empty.
  const bodyWithoutSignature =
    sendWithSignature.value && props.signature
      ? removeSignatureHelper(
          content,
          props.signature,
          effectiveChannelType.value
        )
      : content;

  // trimming should remove all the whitespaces, so we can check the length
  return bodyWithoutSignature.trim().length === 0;
}

function handleEmptyBodyWithSignature() {
  const { schema, tr, doc } = state;

  const isEmptyParagraph = node =>
    node && node.type === schema.nodes.paragraph && node.content.size === 0;

  // Check if empty paragraph already exists to prevent duplicates when toggling signatures
  if (isEmptyParagraph(doc.firstChild)) {
    focusEditorInputField('start');
    return;
  }

  // create a paragraph node and
  // start a transaction to append it at the end
  const paragraph = schema.nodes.paragraph.create();
  const paragraphTransaction = tr.insert(0, paragraph);
  editorView.dispatch(paragraphTransaction);

  // Set the focus at the start of the input field
  focusEditorInputField('start');
}

function focusEditor(content) {
  if (props.disabled) return;

  const unrefContent = unref(content);
  if (isBodyEmpty(unrefContent) && sendWithSignature.value) {
    // reload state can be called when switching between conversations, or when drafts is loaded
    // these drafts can also have a signature, so we need to check if the body is empty
    // and handle things accordingly
    handleEmptyBodyWithSignature();
  } else if (props.focusOnMount) {
    // this is in the else block, handleEmptyBodyWithSignature also has a call to the focus method
    // the position is set to start, because the signature is added at the end of the body
    focusEditorInputField('end');
  }
}

function openFileBrowser() {
  imageUpload.value.click();
}

function handleCopilotClick() {
  const isOpening = !showSelectionMenu.value;
  if (isOpening) {
    useTrack(CAPTAIN_EVENTS.EDITOR_AI_MENU_OPENED, {
      conversationId: props.conversationId,
      entryPoint: 'inline',
    });
  }
  showSelectionMenu.value = isOpening;
}

function handleClickOutside(event) {
  // Check if the clicked element or its parents have the ignored class
  if (event.target.closest('.ProseMirror-copilot')) return;
  showSelectionMenu.value = false;
}

function reloadState(content = props.modelValue) {
  const unrefContent = unref(content);
  state = createState(
    unrefContent,
    props.placeholder,
    plugins.value,
    { onImageUpload: openFileBrowser, onCopilotClick: handleCopilotClick },
    editorMenuOptions.value
  );

  editorView.updateState(state);
  focusEditor(unrefContent);
}

function addSignature() {
  if (props.disabled) return;
  let content = props.modelValue;
  // see if the content is empty, if it is before appending the signature
  // we need to add a paragraph node and move the cursor at the start of the editor
  const contentWasEmpty = isBodyEmpty(content);
  content = appendSignature(
    content,
    props.signature,
    effectiveChannelType.value
  );
  // need to reload first, ensuring that the editorView is updated
  reloadState(content);

  if (contentWasEmpty) {
    handleEmptyBodyWithSignature();
  }
}

function removeSignature() {
  if (props.disabled) return;
  if (!props.signature) return;
  let content = props.modelValue;
  content = removeSignatureHelper(
    content,
    props.signature,
    effectiveChannelType.value
  );
  // reload the state, ensuring that the editorView is updated
  reloadState(content);
}

function setMenubarPosition({ selection } = {}) {
  const wrapper = editorRoot.value;
  if (!selection || !wrapper) return;
  if (!isEditorMenuPopover.value) return;

  const rect = wrapper.getBoundingClientRect();
  const isRtl = getComputedStyle(wrapper).direction === 'rtl';

  // Calculate coords and final position
  const coords = getSelectionCoords(editorView, selection, rect);
  const { left, top, width } = calculateMenuPosition(coords, rect, isRtl);

  wrapper.style.setProperty('--selection-left', `${left}px`);
  wrapper.style.setProperty(
    '--selection-right',
    `${rect.width - left - width}px`
  );
  wrapper.style.setProperty('--selection-top', `${top}px`);
}

function checkSelection(editorState) {
  showSelectionMenu.value = false;
  const { selection } = editorState;
  // Skip NodeSelection (from Esc -> selectParentNode); only text ranges count.
  const hasSelection = !selection.empty && !selection.node;
  if (hasSelection === isTextSelected.value) return;

  isTextSelected.value = hasSelection;
  const wrapper = editorRoot.value;
  if (!wrapper) return;

  wrapper.classList.toggle('has-selection', hasSelection);
  if (hasSelection) setMenubarPosition(editorState);
}

function emitOnChange() {
  emit('input', contentFromEditor());
  emit('update:modelValue', contentFromEditor());
}

function toggleSignatureInEditor(signatureEnabled) {
  // The toggleSignatureInEditor gets the new value from the
  // watcher, this means that if the value is true, the signature
  // is supposed to be added, else we remove it.
  if (signatureEnabled) {
    addSignature();
  } else {
    removeSignature();
  }
  // reloadState replaces editor state directly and bypasses dispatchTransaction,
  // so v-model never hears about the signature change — sync it back explicitly.
  emitOnChange();
}

function isEnterToSendEnabled() {
  return isEditorHotKeyEnabled('enter');
}

function isCmdPlusEnterToSendEnabled() {
  return isEditorHotKeyEnabled('cmd_enter');
}

function onImageInsertInEditor(fileUrl) {
  const { tr } = editorView.state;

  const insertData = findNodeToInsertImage(editorView.state, fileUrl);

  if (insertData) {
    editorView.dispatch(
      tr.insert(insertData.pos, insertData.node).scrollIntoView()
    );
    focusEditorInputField();
  }
}

async function uploadImageToStorage(file) {
  try {
    const { fileUrl } = await uploadFile(file);
    if (fileUrl) {
      onImageInsertInEditor(fileUrl);
    }
    useAlert(
      props.channelType === MESSAGE_SIGNATURE_FORMATTING
        ? t(
            'PROFILE_SETTINGS.FORM.MESSAGE_SIGNATURE_SECTION.IMAGE_UPLOAD_SUCCESS'
          )
        : t('CONVERSATION.REPLYBOX.IMAGE_UPLOAD_SUCCESS')
    );
  } catch (error) {
    useAlert(
      t('PROFILE_SETTINGS.FORM.MESSAGE_SIGNATURE_SECTION.IMAGE_UPLOAD_ERROR')
    );
  }
}

function uploadImageIfWithinSizeLimit(file) {
  if (!file) return;
  if (checkFileSizeLimit(file, MAXIMUM_FILE_UPLOAD_SIZE)) {
    uploadImageToStorage(file);
  } else {
    useAlert(
      t(
        'PROFILE_SETTINGS.FORM.MESSAGE_SIGNATURE_SECTION.IMAGE_UPLOAD_SIZE_ERROR',
        {
          size: MAXIMUM_FILE_UPLOAD_SIZE,
        }
      )
    );
  }
}

function onFileChange() {
  const input = imageUpload.value;
  uploadImageIfWithinSizeLimit(input.files[0]);
  input.value = '';
}

const allowsInlineImagePaste = computed(
  () =>
    !props.isPrivate &&
    (props.channelType === INBOX_TYPES.EMAIL ||
      props.channelType === INBOX_TYPES.WEB)
);

// Shift+Cmd/Ctrl+V on email/website: upload a clipboard image inline. This
// gesture's native paste event carries no image, so clipboard.read() is the
// only way to get the bytes. No preventDefault: text still pastes natively.
async function pasteInlineImageFromClipboard() {
  if (!editorView?.hasFocus()) return;
  if (!allowsInlineImagePaste.value || !navigator.clipboard?.read) return;
  try {
    const items = await navigator.clipboard.read();
    const imageItem = items.find(item =>
      item.types.some(type => INLINE_IMAGE_PASTE_TYPES.includes(type))
    );
    if (!imageItem) return;
    const imageType = imageItem.types.find(type =>
      INLINE_IMAGE_PASTE_TYPES.includes(type)
    );
    const blob = await imageItem.getType(imageType);
    uploadImageIfWithinSizeLimit(
      new File([blob], 'pasted-image', { type: imageType })
    );
  } catch (error) {
    // clipboard-read denied/unfocused (NotAllowedError): image can't be read.
    // Text paste is unaffected — ProseMirror handles it from the native event.
  }
}

useKeyboardEvents({
  'Alt+KeyP': {
    action: focusEditorInputField,
    allowOnFocusedInput: false,
  },
  'Alt+KeyL': {
    action: focusEditorInputField,
    allowOnFocusedInput: false,
  },
  '$mod+Shift+KeyV': {
    action: pasteInlineImageFromClipboard,
    allowOnFocusedInput: true,
  },
});

function handleLineBreakWhenEnterToSendEnabled(event) {
  if (
    hasPressedEnterAndNotCmdOrShift(event) &&
    isEnterToSendEnabled() &&
    !props.overrideLineBreaks
  ) {
    event.preventDefault();
  }
}

async function insertNodeIntoEditor(node, from = 0, to = 0) {
  state = insertAtCursor(editorView, node, from, to);
  emitOnChange();
  await nextTick();
  scrollCursorIntoView(editorView);
}

function insertContentIntoEditor(content, defaultFrom = 0) {
  const from = defaultFrom || editorView.state.selection.from || 0;
  // Use the editor's current schema to ensure compatibility with buildMessageSchema
  const currentSchema = editorView.state.schema;
  // Strip unsupported formatting before parsing to ensure content can be inserted
  // into channels that don't support certain markdown features (e.g., API channels)
  const sanitizedContent = stripUnsupportedFormatting(content, currentSchema);
  let node = new MessageMarkdownTransformer(currentSchema).parse(
    sanitizedContent
  );

  insertNodeIntoEditor(node, from, undefined);
}

/**
 * Inserts special content (mention, canned response, variable, emoji) into the editor.
 * @param {string} type - The type of special content to insert. Possible values: 'mention', 'canned_response', 'variable', 'emoji'.
 * @param {Object|string} content - The content to insert, depending on the type.
 */
function insertSpecialContent(type, content) {
  if (!editorView) {
    return;
  }

  let { node, from, to } = getContentNode(
    editorView,
    type,
    content,
    range.value,
    props.variables
  );

  if (!node) return;

  insertNodeIntoEditor(node, from, to);

  const event_map = {
    mention: CONVERSATION_EVENTS.USED_MENTIONS,
    cannedResponse: CONVERSATION_EVENTS.INSERTED_A_CANNED_RESPONSE,
    variable: CONVERSATION_EVENTS.INSERTED_A_VARIABLE,
    emoji: CONVERSATION_EVENTS.INSERTED_AN_EMOJI,
    tool: CONVERSATION_EVENTS.INSERTED_A_TOOL,
  };

  useTrack(event_map[type]);
}

function handleLineBreakWhenCmdAndEnterToSendEnabled(event) {
  if (
    hasPressedCommandAndEnter(event) &&
    isCmdPlusEnterToSendEnabled() &&
    !props.overrideLineBreaks
  ) {
    event.preventDefault();
  }
}

function onKeydown(event) {
  if (isEscape(event)) {
    collapseSelection(editorView);
    return true;
  }
  if (isEnterToSendEnabled()) {
    handleLineBreakWhenEnterToSendEnabled(event);
  }
  if (isCmdPlusEnterToSendEnabled()) {
    handleLineBreakWhenCmdAndEnterToSendEnabled(event);
  }
  return false;
}

function createEditorView() {
  editorView = new EditorView(editor.value, {
    state: state,
    editable: () => !props.disabled,
    nodeViews: {
      image: imageResizeView,
    },
    dispatchTransaction: tx => {
      state = state.apply(tx);
      editorView.updateState(state);
      if (tx.docChanged) {
        emitOnChange();
      }
      checkSelection(state);
    },
    handleDOMEvents: {
      keyup: () => {
        if (!props.disabled) {
          typingIndicator.start();
        }
      },
      keydown: (view, event) => !props.disabled && onKeydown(event),
      focus: () => !props.disabled && emit('focus'),
      blur: () => {
        if (props.disabled) return;
        typingIndicator.stop();
        // PM keeps its selection on blur — clear the menu flags manually.
        isTextSelected.value = false;
        editorRoot.value?.classList.remove('has-selection');
        emit('blur');
      },
      paste: (view, event) => {
        if (props.disabled) return;
        const { files } = event.clipboardData;
        if (!files.length) return;
        event.preventDefault();
        // Paste text content alongside files (e.g., spreadsheet data from Numbers app)
        // Numbers app includes invalid 0-byte attachments with text, so we paste the text here
        // while ReplyBox filters and handles valid file attachments
        const text = event.clipboardData.getData('text/plain');
        if (text) {
          view.dispatch(view.state.tr.insertText(text));
          emitOnChange();
        }
      },
    },
  });
}

watch(
  computed(() => props.modelValue),
  (newVal = '') => {
    if (newVal !== contentFromEditor()) {
      reloadState(newVal);
    }
  }
);

watch(
  computed(() => props.editorId),
  () => {
    showCannedMenu.value = false;
    showEmojiMenu.value = false;
    showVariables.value = false;
    cannedSearchTerm.value = '';
    reloadState(props.modelValue);
  }
);

watch(
  computed(() => props.isPrivate),
  () => {
    reloadState(props.modelValue);
  }
);

watch(
  computed(() => props.disabled),
  () => editorView?.setProps({})
);

watch(
  computed(() => props.updateSelectionWith),
  (newValue, oldValue) => {
    if (!editorView) return;

    if (newValue !== oldValue) {
      if (props.updateSelectionWith !== '') {
        const node = editorView.state.schema.text(props.updateSelectionWith);

        const tr = editorView.state.tr.replaceSelectionWith(node);
        editorView.focus();
        state = editorView.state.apply(tr);
        editorView.updateState(state);
        emitOnChange();
        emit('clearSelection');
      }
    }
  }
);

watch(sendWithSignature, newValue => {
  // see if the allowSignature flag is true
  if (props.allowSignature && !props.disabled) {
    toggleSignatureInEditor(newValue);
  }
});

onMounted(() => {
  // [VITE] state assignment was done in created before
  state = createState(
    props.modelValue,
    props.placeholder,
    plugins.value,
    { onImageUpload: openFileBrowser, onCopilotClick: handleCopilotClick },
    editorMenuOptions.value
  );

  createEditorView();
  editorView.updateState(state);
  if (props.focusOnMount) {
    focusEditorInputField();
  }
});

defineExpose({ focusEditorInputField });

// BUS Event to insert text or markdown into the editor at the
// current cursor position.
// Components using this
// 1. SearchPopover.vue
useEmitter(BUS_EVENTS.INSERT_INTO_RICH_EDITOR, insertContentIntoEditor);
</script>

<template>
  <div
    ref="editorRoot"
    class="relative w-full"
    :class="{
      'opacity-50 cursor-not-allowed pointer-events-none': disabled,
    }"
  >
    <TagAgents
      v-if="showUserMentions && isPrivate"
      :search-key="mentionSearchKey"
      @select-agent="content => insertSpecialContent('mention', content)"
    />
    <CannedResponse
      v-if="shouldShowCannedResponses"
      :search-key="cannedSearchTerm"
      @replace="content => insertSpecialContent('cannedResponse', content)"
    />
    <VariableList
      v-if="shouldShowVariables"
      :search-key="variableSearchTerm"
      @select-variable="content => insertSpecialContent('variable', content)"
    />
    <KeyboardEmojiSelector
      v-if="showEmojiMenu"
      :search-key="emojiSearchTerm"
      @select-emoji="emoji => insertSpecialContent('emoji', emoji)"
    />
    <TagTools
      v-if="showToolsMenu"
      :search-key="toolSearchKey"
      @select-tool="content => insertSpecialContent('tool', content)"
    />
    <CopilotMenuBar
      v-if="showSelectionMenu"
      v-on-click-outside="handleClickOutside"
      :has-selection="isTextSelected"
      :is-editor-menu-popover="isEditorMenuPopover"
      :has-content="!isBodyEmpty(modelValue)"
      :conversation-id="conversationId"
      :show-selection-menu="showSelectionMenu"
      :show-general-menu="false"
      class="copilot-editor-menu"
      @execute-copilot-action="handleCopilotAction"
    />
    <input
      ref="imageUpload"
      type="file"
      accept="image/png, image/jpeg, image/jpg, image/gif, image/webp"
      hidden
      @change="onFileChange"
    />
    <div ref="editor" />
    <slot name="footer" />
  </div>
</template>

<style lang="scss">
@import '@chatwoot/prosemirror-schema/src/styles/base.scss';

.ProseMirror-menubar-wrapper {
  @apply flex flex-col gap-3;

  .ProseMirror-menubar {
    min-height: 1.25rem !important;
    @apply items-center gap-4 flex pb-0 bg-transparent text-n-slate-11 relative ltr:-left-[3px] rtl:-right-[3px];

    .ProseMirror-menu-active {
      @apply bg-n-slate-5 dark:bg-n-solid-3 !important;
    }

    .ProseMirror-menuitem {
      @apply mr-0 size-4 flex items-center justify-center;

      .ProseMirror-icon {
        @apply size-4 flex items-center justify-center flex-shrink-0;

        svg {
          @apply size-full;
        }
      }

      .ProseMirror-copilot svg {
        @apply fill-n-violet-9 text-n-violet-9 stroke-none;
      }
    }
  }

  .ProseMirror-menubar:not(:has(*)) {
    max-height: none !important;
    min-height: 0 !important;
    padding: 0 !important;
    display: none !important;
  }

  > .ProseMirror {
    @apply p-0 break-words text-n-slate-12;

    h1,
    h2,
    h3,
    h4,
    h5,
    h6,
    p {
      @apply text-n-slate-12;
    }

    blockquote {
      @apply border-n-slate-7;

      p {
        @apply text-n-slate-11;
      }
    }
  }
}

.ProseMirror-woot-style {
  @apply overflow-auto;
}

.ProseMirror-woot-style:not(
    :where(.resizable-editor-wrapper .ProseMirror-woot-style)
  ) {
  /* WhatsApp composer: ek line se shuru, likhne par barhta hai */
  @apply min-h-[1.5rem] max-h-[7.5rem];
}

// Resizable editor wrapper styles
.resizable-editor-wrapper {
  .ProseMirror-woot-style {
    min-height: clamp(
      var(--editor-min-allowed, var(--editor-min-height, 1.5rem)),
      var(--editor-height, var(--editor-min-height, 1.5rem)),
      var(--editor-max-allowed, var(--editor-max-height, 7.5rem))
    );
    max-height: clamp(
      var(--editor-min-allowed, var(--editor-min-height, 1.5rem)),
      var(--editor-height, var(--editor-min-height, 1.5rem)),
      var(--editor-max-allowed, var(--editor-max-height, 7.5rem))
    );
    transition:
      min-height var(--editor-height-transition, 180ms ease),
      max-height var(--editor-height-transition, 180ms ease);
  }
}

.ProseMirror-prompt-backdrop::backdrop {
  @apply bg-n-alpha-black1 backdrop-blur-[4px];
}

.ProseMirror-prompt {
  @apply bg-n-alpha-3 border border-n-strong p-6 shadow-xl rounded-xl w-96 !important;

  h5 {
    @apply text-n-slate-12 mb-3;
  }

  .ProseMirror-prompt-buttons {
    button {
      @apply h-8 px-3;

      &[type='submit'] {
        @apply bg-n-brand text-white hover:bg-n-brand/90;
      }

      &[type='button'] {
        @apply bg-n-slate-9/10 text-n-slate-12 hover:bg-n-slate-9/20;
      }
    }
  }
}

.is-private {
  .prosemirror-mention-node {
    @apply font-medium bg-n-amber-2/80 dark:bg-n-amber-2/80 text-n-slate-12 py-0 px-1;
  }

  .ProseMirror-menubar-wrapper {
    > .ProseMirror {
      @apply text-n-slate-12;

      p {
        @apply text-n-slate-12;
      }
    }
  }
}

.prosemirror-tools-node {
  @apply font-medium text-n-slate-12 py-0;
}

.editor-wrap {
  @apply mb-4;
}

.message-editor {
  @apply rounded-lg outline outline-1 outline-n-weak hover:outline-n-slate-6 dark:hover:outline-n-slate-6 bg-n-alpha-black2 py-0 px-1 mb-0;
}

.editor_warning {
  @apply outline outline-1 outline-n-ruby-8 dark:outline-n-ruby-8 hover:outline-n-ruby-9 dark:hover:outline-n-ruby-9;
}

.editor-warning__message {
  @apply text-n-ruby-9 dark:text-n-ruby-9 font-normal text-sm pt-1 pb-0 px-0;
}

// Default copilot menu position (non-popover editors like components-next/Editor)
// When popover-prosemirror-menu is NOT on the wrapper, anchor below the menubar
:not(.popover-prosemirror-menu) > .copilot-editor-menu {
  top: 1.5rem !important;

  [dir='rtl'] & {
    left: auto !important;
    right: 0 !important;
  }
}

// Float editor menu
.popover-prosemirror-menu {
  position: relative;

  .ProseMirror p:last-child {
    margin-bottom: 10px !important;
  }

  .ProseMirror-menubar {
    display: none; // Hide by default
  }

  &.has-selection {
    // Hide menu completely when it has no items
    .ProseMirror-menubar:not(:has(*)) {
      display: none !important;
    }

    .ProseMirror-menubar {
      @apply rounded-lg !px-3 !py-1.5 z-50 bg-n-background items-center gap-4 ml-0 mb-0 shadow-md outline outline-1 outline-n-weak;
      display: flex;
      width: fit-content !important;
      position: absolute !important;

      // Default/LTR: position from left
      top: var(--selection-top);
      left: var(--selection-left);

      // RTL: position from right instead
      [dir='rtl'] & {
        left: auto;
        right: var(--selection-right);
      }

      .ProseMirror-menuitem {
        @apply mr-0 size-4 flex items-center;

        .ProseMirror-icon {
          @apply p-0.5 flex-shrink-0;
        }

        .ProseMirror-copilot svg {
          @apply fill-n-violet-9 text-n-violet-9 stroke-none;
        }
      }

      .ProseMirror-menu-active {
        @apply bg-n-slate-3;
      }
    }
  }
}
</style>
CS_EOF_1a6f8
echo "  ok  app/javascript/dashboard/components/widgets/WootWriter/Editor.vue"

mkdir -p "$(dirname app/javascript/dashboard/components/widgets/WootWriter/ReplyTopPanel.vue)"
cat > app/javascript/dashboard/components/widgets/WootWriter/ReplyTopPanel.vue << 'CS_EOF_1a6f8'
<script>
import { ref } from 'vue';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';
import { useCaptain } from 'dashboard/composables/useCaptain';
import { useTrack } from 'dashboard/composables';
import { vOnClickOutside } from '@vueuse/components';
import { REPLY_EDITOR_MODES, CHAR_LENGTH_WARNING } from './constants';
import { CAPTAIN_EVENTS } from 'dashboard/helper/AnalyticsHelper/events';
import NextButton from 'dashboard/components-next/button/Button.vue';
import EditorModeToggle from './EditorModeToggle.vue';
import CopilotMenuBar from './CopilotMenuBar.vue';

export default {
  name: 'ReplyTopPanel',
  components: {
    NextButton,
    EditorModeToggle,
    CopilotMenuBar,
  },
  directives: {
    OnClickOutside: vOnClickOutside,
  },
  props: {
    mode: {
      type: String,
      default: REPLY_EDITOR_MODES.REPLY,
    },
    isReplyRestricted: {
      type: Boolean,
      default: false,
    },
    disabled: {
      type: Boolean,
      default: false,
    },
    isEditorDisabled: {
      type: Boolean,
      default: false,
    },
    conversationId: {
      type: Number,
      default: null,
    },
    isMessageLengthReachingThreshold: {
      type: Boolean,
      default: () => false,
    },
    charactersRemaining: {
      type: Number,
      default: () => 0,
    },
    editorContent: {
      type: String,
      default: undefined,
    },
    hasContent: {
      type: Boolean,
      default: false,
    },
  },
  emits: ['setReplyMode', 'toggleEditorSize', 'executeCopilotAction'],
  setup(props, { emit }) {
    const setReplyMode = mode => {
      emit('setReplyMode', mode);
    };
    const handleReplyClick = () => {
      if (props.isReplyRestricted) return;
      setReplyMode(REPLY_EDITOR_MODES.REPLY);
    };
    const handleNoteClick = () => {
      setReplyMode(REPLY_EDITOR_MODES.NOTE);
    };
    const handleModeToggle = () => {
      const newMode =
        props.mode === REPLY_EDITOR_MODES.REPLY
          ? REPLY_EDITOR_MODES.NOTE
          : REPLY_EDITOR_MODES.REPLY;
      setReplyMode(newMode);
    };

    const { captainTasksEnabled } = useCaptain();
    const showCopilotMenu = ref(false);
    const copilotToggleRef = ref(null);

    const handleCopilotAction = (actionKey, data) => {
      emit('executeCopilotAction', actionKey, data || props.editorContent);
      showCopilotMenu.value = false;
    };

    const toggleCopilotMenu = () => {
      const isOpening = !showCopilotMenu.value;
      if (isOpening) {
        useTrack(CAPTAIN_EVENTS.EDITOR_AI_MENU_OPENED, {
          conversationId: props.conversationId,
          entryPoint: 'top_panel',
        });
      }
      showCopilotMenu.value = isOpening;
    };

    const handleClickOutside = () => {
      showCopilotMenu.value = false;
    };

    const keyboardEvents = {
      'Alt+KeyP': {
        action: () => handleNoteClick(),
        allowOnFocusedInput: false,
      },
      'Alt+KeyL': {
        action: () => handleReplyClick(),
        allowOnFocusedInput: false,
      },
    };
    useKeyboardEvents(keyboardEvents);

    return {
      handleModeToggle,
      handleReplyClick,
      handleNoteClick,
      REPLY_EDITOR_MODES,
      captainTasksEnabled,
      handleCopilotAction,
      showCopilotMenu,
      copilotToggleRef,
      toggleCopilotMenu,
      handleClickOutside,
    };
  },
  computed: {
    replyButtonClass() {
      return {
        'is-active': this.mode === REPLY_EDITOR_MODES.REPLY,
      };
    },
    noteButtonClass() {
      return {
        'is-active': this.mode === REPLY_EDITOR_MODES.NOTE,
      };
    },
    charLengthClass() {
      return this.charactersRemaining < 0 ? 'text-n-ruby-9' : 'text-n-slate-11';
    },
    characterLengthWarning() {
      return this.charactersRemaining < 0
        ? `${-this.charactersRemaining} ${CHAR_LENGTH_WARNING.NEGATIVE}`
        : `${this.charactersRemaining} ${CHAR_LENGTH_WARNING.UNDER_50}`;
    },
  },
};
</script>

<template>
  <div
    class="flex justify-between gap-2 h-9 items-center ltr:pl-3 ltr:pr-2 rtl:pr-3 rtl:pl-2"
  >
    <EditorModeToggle
      :mode="mode"
      :disabled="disabled"
      :is-reply-restricted="isReplyRestricted"
      @toggle-mode="handleModeToggle"
    />
    <div class="flex items-center mx-4 my-0">
      <div v-if="isMessageLengthReachingThreshold" class="text-xs">
        <span :class="charLengthClass">
          {{ characterLengthWarning }}
        </span>
      </div>
    </div>
    <div v-if="captainTasksEnabled" class="flex items-center gap-2">
      <div class="relative">
        <NextButton
          ref="copilotToggleRef"
          ghost
          :disabled="disabled || isEditorDisabled"
          :class="{
            'text-n-violet-9 hover:enabled:!bg-n-violet-3': !showCopilotMenu,
            'text-n-violet-9 bg-n-violet-3': showCopilotMenu,
          }"
          sm
          icon="i-ph-sparkle-fill"
          @click="toggleCopilotMenu"
        />
        <CopilotMenuBar
          v-if="showCopilotMenu"
          v-on-click-outside="[
            handleClickOutside,
            { ignore: [copilotToggleRef] },
          ]"
          :has-selection="false"
          :has-content="hasContent"
          :conversation-id="conversationId"
          class="ltr:right-0 rtl:left-0 bottom-full mb-2"
          @execute-copilot-action="handleCopilotAction"
        />
      </div>
      <NextButton
        ghost
        class="text-n-slate-11"
        sm
        icon="i-lucide-maximize-2"
        @click="$emit('toggleEditorSize')"
      />
    </div>
  </div>
</template>
CS_EOF_1a6f8
echo "  ok  app/javascript/dashboard/components/widgets/WootWriter/ReplyTopPanel.vue"


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
