<script>
import { ref } from 'vue';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';
import FileUpload from 'vue-upload-component';
import * as ActiveStorage from 'activestorage';
import inboxMixin from 'shared/mixins/inboxMixin';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { getAllowedFileTypesByChannel } from '@chatwoot/utils';
import VideoCallButton from '../VideoCallButton.vue';
import { INBOX_TYPES } from 'dashboard/helper/inbox';
import { mapGetters } from 'vuex';
import NextButton from 'dashboard/components-next/button/Button.vue';

export default {
  name: 'ReplyBottomPanel',
  components: { NextButton, FileUpload, VideoCallButton },
  mixins: [inboxMixin],
  props: {
    isNote: {
      type: Boolean,
      default: false,
    },
    onSend: {
      type: Function,
      default: () => {},
    },
    sendButtonText: {
      type: String,
      default: '',
    },
    recordingAudioDurationText: {
      type: String,
      default: '00:00',
    },
    // inbox prop is used in /mixins/inboxMixin,
    // remove this props when refactoring to composable if not needed
    // eslint-disable-next-line vue/no-unused-properties
    inbox: {
      type: Object,
      default: () => ({}),
    },
    showFileUpload: {
      type: Boolean,
      default: false,
    },
    showAudioRecorder: {
      type: Boolean,
      default: false,
    },
    onFileUpload: {
      type: Function,
      default: () => {},
    },
    toggleEmojiPicker: {
      type: Function,
      default: () => {},
    },
    toggleAudioRecorder: {
      type: Function,
      default: () => {},
    },
    toggleAudioRecorderPlayPause: {
      type: Function,
      default: () => {},
    },
    isRecordingAudio: {
      type: Boolean,
      default: false,
    },
    recordingAudioState: {
      type: String,
      default: '',
    },
    isSendDisabled: {
      type: Boolean,
      default: false,
    },
    isOnPrivateNote: {
      type: Boolean,
      default: false,
    },
    enableMultipleFileUpload: {
      type: Boolean,
      default: true,
    },
    enableWhatsAppTemplates: {
      type: Boolean,
      default: false,
    },
    enableContentTemplates: {
      type: Boolean,
      default: false,
    },
    conversationId: {
      type: Number,
      required: true,
    },
    // eslint-disable-next-line vue/no-unused-properties
    message: {
      type: String,
      default: '',
    },
    newConversationModalActive: {
      type: Boolean,
      default: false,
    },
    portalSlug: {
      type: String,
      required: true,
    },
    conversationType: {
      type: String,
      default: '',
    },
    showQuotedReplyToggle: {
      type: Boolean,
      default: false,
    },
    quotedReplyEnabled: {
      type: Boolean,
      default: false,
    },
    isEditorDisabled: {
      type: Boolean,
      default: false,
    },
  },
  emits: [
    'toggleInsertArticle',
    'selectWhatsappTemplate',
    'selectContentTemplate',
    'toggleQuotedReply',
    'cancelAudio',
    'finishAudio',
  ],
  setup(props) {
    const { setSignatureFlagForInbox, fetchSignatureFlagFromUISettings } =
      useUISettings();

    const uploadRef = ref(false);

    const keyboardEvents = {
      '$mod+Alt+KeyA': {
        action: () => {
          // Skip if editor is disabled (e.g., WhatsApp 24-hour window expired)
          if (props.isEditorDisabled) return;

          // TODO: This is really hacky, we need to replace the file picker component with
          // a custom one, where the logic and the component markup is isolated.
          // Once we have the custom component, we can remove the hacky logic below.

          const uploadTriggerButton = document.querySelector(
            '#conversationAttachment'
          );
          if (uploadTriggerButton) uploadTriggerButton.click();
        },
        allowOnFocusedInput: true,
      },
    };

    useKeyboardEvents(keyboardEvents);

    return {
      setSignatureFlagForInbox,
      fetchSignatureFlagFromUISettings,
      uploadRef,
    };
  },
  computed: {
    ...mapGetters({
      accountId: 'getCurrentAccountId',
      isFeatureEnabledonAccount: 'accounts/isFeatureEnabledonAccount',
      uiFlags: 'integrations/getUIFlags',
    }),
    wrapClass() {
      return {
        'is-note-mode': this.isNote,
      };
    },
    showAttachButton() {
      if (this.isEditorDisabled) return false;
      return this.showFileUpload || this.isNote;
    },
    showAudioRecorderButton() {
      if (this.isEditorDisabled) return false;
      if (this.isALineChannel || this.isATiktokChannel) {
        return false;
      }
      // Disable audio recorder for safari browser as recording is not supported
      // const isSafari = /^((?!chrome|android|crios|fxios).)*safari/i.test(
      //   navigator.userAgent
      // );

      return (
        this.isFeatureEnabledonAccount(
          this.accountId,
          FEATURE_FLAGS.VOICE_RECORDER
        ) && this.showAudioRecorder
        // !isSafari
      );
    },
    showAudioPlayStopButton() {
      if (this.isEditorDisabled) return false;
      return this.showAudioRecorder && this.isRecordingAudio;
    },
    isInstagramDM() {
      return this.conversationType === 'instagram_direct_message';
    },
    allowedFileTypes() {
      if (this.isOnPrivateNote) {
        return getAllowedFileTypesByChannel();
      }

      let channelType = this.channelType || this.inbox?.channel_type;
      if (this.isAnInstagramChannel || this.isInstagramDM) {
        channelType = INBOX_TYPES.INSTAGRAM;
      }

      return getAllowedFileTypesByChannel({
        channelType,
        medium: this.inbox?.medium,
      });
    },
    enableDragAndDrop() {
      return !this.newConversationModalActive;
    },
    audioRecorderPlayStopIcon() {
      switch (this.recordingAudioState) {
        // playing paused recording stopped inactive destroyed
        case 'playing':
          return 'i-ph-pause';
        case 'paused':
          return 'i-ph-play';
        case 'stopped':
          return 'i-ph-play';
        default:
          return 'i-ph-stop';
      }
    },
    showMessageSignatureButton() {
      if (this.isEditorDisabled) return false;
      return !this.isOnPrivateNote;
    },
    sendWithSignature() {
      // channelType is sourced from inboxMixin
      return this.fetchSignatureFlagFromUISettings(this.channelType);
    },
    signatureToggleTooltip() {
      return this.sendWithSignature
        ? this.$t('CONVERSATION.FOOTER.DISABLE_SIGN_TOOLTIP')
        : this.$t('CONVERSATION.FOOTER.ENABLE_SIGN_TOOLTIP');
    },
    enableInsertArticleInReply() {
      return this.portalSlug;
    },
    isFetchingAppIntegrations() {
      return this.uiFlags.isFetching;
    },
    quotedReplyToggleTooltip() {
      return this.quotedReplyEnabled
        ? this.$t('CONVERSATION.REPLYBOX.QUOTED_REPLY.DISABLE_TOOLTIP')
        : this.$t('CONVERSATION.REPLYBOX.QUOTED_REPLY.ENABLE_TOOLTIP');
    },
  },
  mounted() {
    ActiveStorage.start();
  },
  methods: {
    toggleMessageSignature() {
      this.setSignatureFlagForInbox(this.channelType, !this.sendWithSignature);
    },
    toggleInsertArticle() {
      this.$emit('toggleInsertArticle');
    },
  },
};
</script>

<template>
  <!-- WhatsApp composer:  📎 😊 [extra]  |  input  |  🎤 / ➤ -->
  <div class="cs-composer" :class="wrapClass">
    <!-- LEFT: attach, emoji, aur zaroori extras -->
    <div v-if="!isRecordingAudio" class="cs-left">
      <FileUpload
        v-if="showAttachButton"
        ref="uploadRef"
        v-tooltip.top-end="$t('CONVERSATION.REPLYBOX.TIP_ATTACH_ICON')"
        input-id="conversationAttachment"
        :size="4096 * 4096"
        :accept="allowedFileTypes"
        :multiple="enableMultipleFileUpload"
        :drop="enableDragAndDrop"
        :drop-directory="false"
        :data="{
          direct_upload_url: '/rails/active_storage/direct_uploads',
          direct_upload: true,
        }"
        @input-file="onFileUpload"
      >
        <NextButton
          v-tooltip.top-end="$t('CONVERSATION.REPLYBOX.TIP_ATTACH_ICON')"
          icon="i-ph-paperclip"
          slate
          ghost
          sm
        />
      </FileUpload>

      <NextButton
        v-if="!isEditorDisabled"
        v-tooltip.top-end="$t('CONVERSATION.REPLYBOX.TIP_EMOJI_ICON')"
        icon="i-ph-smiley"
        slate
        ghost
        sm
        @click="toggleEmojiPicker"
      />

      <NextButton
        v-if="enableWhatsAppTemplates"
        v-tooltip.top-end="$t('CONVERSATION.FOOTER.WHATSAPP_TEMPLATES')"
        icon="i-ph-list-dashes"
        slate
        ghost
        sm
        @click="$emit('selectWhatsappTemplate')"
      />

      <NextButton
        v-if="enableContentTemplates"
        v-tooltip.top-end="'Content Templates'"
        icon="i-ph-list-dashes"
        slate
        ghost
        sm
        @click="$emit('selectContentTemplate')"
      />

      <NextButton
        v-if="showQuotedReplyToggle"
        v-tooltip.top-end="quotedReplyToggleTooltip"
        icon="i-ph-quotes"
        :variant="quotedReplyEnabled ? 'solid' : 'ghost'"
        color="slate"
        sm
        :aria-pressed="quotedReplyEnabled"
        @click="$emit('toggleQuotedReply')"
      />

      <NextButton
        v-if="enableInsertArticleInReply"
        v-tooltip.top-end="$t('HELP_CENTER.ARTICLE_SEARCH.OPEN_ARTICLE_SEARCH')"
        icon="i-ph-article-ny-times"
        slate
        ghost
        sm
        @click="toggleInsertArticle"
      />

      <VideoCallButton
        v-if="
          (isAWebWidgetInbox || isAPIInbox) &&
          !isOnPrivateNote &&
          !isEditorDisabled
        "
        :conversation-id="conversationId"
      />
    </div>

    <!-- RECORDING: WhatsApp patti — delete, red dot, waqt, pause, send -->
    <div v-if="isRecordingAudio" class="cs-rec">
      <NextButton
        v-tooltip.top-end="'Delete recording'"
        icon="i-ph-trash"
        ruby
        ghost
        sm
        @click="$emit('cancelAudio')"
      />
      <span
        class="cs-rec__dot"
        :class="{ 'cs-rec__dot--paused': recordingAudioState === 'recording-paused' }"
      />
      <span class="cs-rec__time">{{ recordingAudioDurationText || '0:00' }}</span>
      <span class="cs-rec__spacer" />
      <NextButton
        v-tooltip.top-end="
          recordingAudioState === 'recording-paused' ? 'Resume' : 'Pause'
        "
        :icon="
          recordingAudioState === 'recording-paused'
            ? 'i-ph-microphone'
            : 'i-ph-pause'
        "
        slate
        ghost
        sm
        @click="toggleAudioRecorderPlayPause"
      />
      <NextButton
        v-tooltip.top-end="'Send voice message'"
        icon="i-ph-paper-plane-right-fill"
        teal
        sm
        class="cs-send"
        @click="$emit('finishAudio')"
      />
    </div>

    <!-- RIGHT: mic YA send -->
    <div v-else class="cs-right">

      <!-- kuch likha nahi hai -> mic (WhatsApp) -->
      <NextButton
        v-if="showAudioRecorderButton && isSendDisabled"
        v-tooltip.top-end="$t('CONVERSATION.REPLYBOX.TIP_AUDIORECORDER_ICON')"
        :icon="!isRecordingAudio ? 'i-ph-microphone' : 'i-ph-microphone-slash'"
        :color="isRecordingAudio ? 'ruby' : 'slate'"
        ghost
        sm
        @click="toggleAudioRecorder"
      />

      <!-- kuch likha hai -> gol hara send -->
      <NextButton
        v-if="!isSendDisabled"
        v-tooltip.top-end="sendButtonText"
        icon="i-ph-paper-plane-right-fill"
        type="submit"
        sm
        :color="isNote ? 'amber' : 'teal'"
        class="cs-send"
        @click="onSend"
      />
    </div>

    <transition name="modal-fade">
      <div
        v-show="uploadRef && uploadRef.dropActive"
        class="flex fixed top-0 right-0 bottom-0 left-0 z-20 flex-col gap-2 justify-center items-center w-full h-full text-n-slate-12 bg-modal-backdrop-light dark:bg-modal-backdrop-dark"
      >
        <fluent-icon icon="cloud-backup" size="40" />
        <h4 class="text-2xl break-words text-n-slate-12">
          {{ $t('CONVERSATION.REPLYBOX.DRAG_DROP') }}
        </h4>
      </div>
    </transition>
  </div>
</template>

<style lang="scss" scoped>
.cs-composer {
  @apply flex items-center justify-between gap-1 px-2 py-1;
}

.cs-left {
  @apply flex items-center gap-0.5;
}

.cs-right {
  @apply flex items-center gap-1;
}

.cs-rec {
  @apply flex items-center gap-2 w-full px-1;
}

.cs-rec__dot {
  @apply rounded-full flex-shrink-0;
  width: 9px;
  height: 9px;
  background: #f15c6d;
  animation: cs-blink 1.4s ease-in-out infinite;
}

.cs-rec__dot--paused {
  animation: none;
  opacity: 0.45;
}

@keyframes cs-blink {
  0%,
  100% {
    opacity: 1;
  }
  50% {
    opacity: 0.3;
  }
}

.cs-rec__time {
  @apply text-sm tabular-nums flex-shrink-0;
  min-width: 2.6rem;
}

.cs-rec__spacer {
  @apply flex-1;
}

.cs-send {
  @apply rounded-full;
  width: 2.25rem;
  height: 2.25rem;
  padding: 0;
  transition: transform 0.14s cubic-bezier(0.34, 1.56, 0.64, 1);

  &:active {
    transform: scale(0.92);
  }
}

:deep(.file-uploads) {
  label {
    @apply cursor-pointer;
  }

  &:hover button {
    @apply enabled:bg-n-slate-9/20;
  }
}
</style>
