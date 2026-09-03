<script>
import { mapGetters } from 'vuex';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useAccount } from 'dashboard/composables/useAccount';
import ChatsScreen from './ChatsScreen.vue';
import CmdBarConversationSnooze from 'dashboard/routes/dashboard/commands/CmdBarConversationSnooze.vue';

export default {
  components: {
    ChatsScreen,
    CmdBarConversationSnooze,
  },
  beforeRouteLeave(to, from, next) {
    if (this.conversationId) {
      this.$store.dispatch('clearSelectedState');
    }
    next();
  },
  props: {
    inboxId: {
      type: [String, Number],
      default: 0,
    },
    conversationId: {
      type: [String, Number],
      default: 0,
    },
    label: {
      type: String,
      default: '',
    },
    teamId: {
      type: String,
      default: '',
    },
    conversationType: {
      type: String,
      default: '',
    },
    foldersId: {
      type: [String, Number],
      default: 0,
    },
  },
  setup() {
    const { uiSettings, updateUISettings } = useUISettings();
    const { accountId } = useAccount();

    return {
      uiSettings,
      updateUISettings,
      accountId,
    };
  },
  computed: {
    ...mapGetters({
      chatList: 'getAllConversations',
      currentChat: 'getSelectedChat',
    }),
  },
  created() {
    if (!this.conversationId) {
      this.$store.dispatch('clearSelectedState');
    }
  },
  mounted() {
    this.$store.dispatch('agents/get');
  },
};
</script>

<template>
  <section class="flex w-full h-full min-w-0">
    <ChatsScreen :conversation-id="conversationId" :inbox-id="inboxId" />
    <CmdBarConversationSnooze />
  </section>
</template>
