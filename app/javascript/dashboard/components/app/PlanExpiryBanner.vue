<script>
import { mapGetters } from 'vuex';
import { useAccount } from 'dashboard/composables/useAccount';

export default {
  name: 'PlanExpiryBanner',
  setup() {
    const { accountId } = useAccount();
    return { currentAccountId: accountId };
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
      return this.daysLeft !== null && this.daysLeft > 0 && this.daysLeft <= 3;
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
