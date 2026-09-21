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
    class="cs-row"
    :class="{
      'cs-row--on': isActiveChat,
      'cs-row--sel': selected,
      'cs-row--unread': hasUnread,
    }"
    @click="$emit('click', $event)"
    @contextmenu="$emit('contextmenu', $event)"
  >
    <div
      class="cs-row__av"
      @mouseenter="onThumbnailHover"
      @mouseleave="onThumbnailLeave"
    >
      <Avatar
        v-if="!hideThumbnail"
        :name="currentContact.name"
        :src="currentContact.thumbnail"
        :size="49"
        :status="currentContact.availability_status"
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

    <div class="cs-row__body">
      <div class="cs-row__l1">
        <span class="cs-row__name">{{ currentContact.name }}</span>
        <span class="cs-row__time">
          <TimeAgo
            :last-activity-timestamp="chat.timestamp"
            :created-at-timestamp="chat.created_at"
            :conversation-id="chat.id"
          />
        </span>
      </div>

      <div class="cs-row__l2">
        <span
          v-if="inbox && inbox.channel_type && /Whatsapp|FacebookPage|Instagram/.test(inbox.channel_type)"
          class="cs-chip"
          :class="{
            'cs-chip--fb': inbox.channel_type.includes('FacebookPage'),
            'cs-chip--ig': inbox.channel_type.includes('Instagram'),
          }"
        >
          {{
            inbox.channel_type.includes('Whatsapp')
              ? 'WA'
              : inbox.channel_type.includes('FacebookPage')
                ? 'FB'
                : inbox.channel_type.includes('Instagram')
                  ? 'IG'
                  : ''
          }}
        </span>
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
          class="cs-row__prev"
          :class="messagePreviewClass"
        />
        <span v-else key="no-messages" class="cs-row__prev">
          {{ $t(`CHAT_LIST.NO_MESSAGES`) }}
        </span>

        <CardPriorityIcon
          :priority="chat.priority"
          class="flex-shrink-0 !size-3.5"
        />
        <UnreadBadge
          v-if="hasUnread"
          :count="unreadCount"
          class="cs-row__badge"
        />
      </div>

      <InboxName
        v-if="showInboxName"
        :inbox="inbox"
        class="mt-1 min-w-0 opacity-70"
      />

      <CardLabels
        v-if="showLabelsSection"
        :conversation-labels="chat.labels"
        class="mt-1"
      >
        <template v-if="hasSlaPolicyId" #before>
          <SLACardLabel :chat="chat" class="ltr:mr-1 rtl:ml-1" />
        </template>
      </CardLabels>
    </div>
  </div>
</template>
