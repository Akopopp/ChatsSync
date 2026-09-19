<script>
import { mapGetters } from 'vuex';
import { useAccount } from 'dashboard/composables/useAccount';

export default {
  name: 'PlanExpiryBanner',
  setup() {
    const { accountId } = useAccount();
    return { currentAccountId: accountId };
  },
  data() {
    return { inChat: false };
  },
  computed: {
    ...mapGetters({ getAccount: 'accounts/getAccount' }),
    daysLeft() {
      const account = this.getAccount(this.currentAccountId);
      const ends = account && account.plan_ends_at;
      if (!ends) return null;
      const end = new Date(ends).getTime();
      if (Number.isNaN(end)) return null;
      return Math.ceil((end - Date.now()) / (1000 * 60 * 60 * 24));
    },
    showBanner() {
      if (this.inChat) return false;
      return this.daysLeft !== null && this.daysLeft > 0 && this.daysLeft <= 3;
    },
  },
  mounted() {
    /* Mobile par jab koi chat KHULI ho, ye patti upar se jagah kha
       jaati thi aur chatbox ka layout bigar jaata tha — message likhna
       mushkil ho jaata tha.
       Ab chat ke andar ye nahi aati. Chats list par aur baqi tabs par
       pehle ki tarah aati rehti hai. PC par bhi koi farq nahi.

       ChatsScreen mobile par thread khulte hi apni root section par
       "thr" class laga deta hai — usi se pata chal jaata hai. */
    this.watchChat();
    this.chatObserver = new MutationObserver(() => this.watchChat());
    this.chatObserver.observe(document.body, {
      subtree: true,
      childList: true,
      attributes: true,
      attributeFilter: ['class'],
    });
  },
  beforeUnmount() {
    if (this.chatObserver) {
      this.chatObserver.disconnect();
      this.chatObserver = null;
    }
  },
  methods: {
    watchChat() {
      const mobile = window.innerWidth <= 768;
      const open = !!document.querySelector('.cs-app.mob.thr');
      const next = mobile && open;
      if (next !== this.inChat) this.inChat = next;
    },
  },
};
</script>

<template>
  <div
    v-if="showBanner"
    style="background-color:#FEF3C7;color:#92400E;padding:8px 16px;text-align:center;font-size:13px;font-weight:600;border-bottom:1px solid #FCD34D;"
  >
    ⚠️ Your plan expires in {{ daysLeft }} day{{ daysLeft === 1 ? '' : 's' }}. Please renew to avoid interruption.
  </div>
</template>
