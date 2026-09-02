#!/usr/bin/env bash
# =====================================================================
#  apply-wa-all.sh   —   SAB KUCH EK FILE MEIN
#   1. Sidebar.vue   rail target ki tarteeb; All Conversations/Mentions/
#                    Participating/Unattended KHATAM; Companies khatam;
#                    new-conversation button khatam
#   2. ChatList.vue  search bar (chalti hui), pills WhatsApp tarteeb,
#                    channel pills (WhatsApp/FB/IG), title "Chats"
#   3. app.scss      doodle halka, canary off, composer chhota,
#                    right-click menu, row, search, pills
# =====================================================================
set -euo pipefail
cd /root/staging-build
SB=app/javascript/dashboard/components-next/sidebar/Sidebar.vue
CL=app/javascript/dashboard/components/ChatList.vue
SCSS=app/javascript/dashboard/assets/scss/app.scss
BK=/root/backups; S=$(date +%F-%H%M%S)
say(){ printf '\n\033[1;36m>> %s\033[0m\n' "$*"; }
die(){ printf '\n\033[1;31m!! %s\033[0m\n' "$*"; exit 1; }
for f in "$SB" "$CL" "$SCSS"; do [ -f "$f" ] || die "nahi mili: $f"; done
mkdir -p "$BK"
cp "$SB" "$BK/Sidebar.$S.bak"; cp "$CL" "$BK/ChatList.$S.bak"; cp "$SCSS" "$BK/app.scss.$S.bak"
echo ">> backup: $BK/*.$S.bak"

cat > /tmp/cs_menu.js <<'MENUEOF'
const menuItems = computed(() => {
  return [
    {
      name: 'Conversation',
      label: t('SIDEBAR.CONVERSATIONS'),
      icon: 'i-lucide-message-circle',
      activeOn: ['inbox_conversation', 'home'],
      to: accountScopedRoute('home'),
    },
    {
      name: 'Inbox',
      label: t('SIDEBAR.INBOX'),
      icon: 'i-lucide-inbox',
      to: accountScopedRoute('inbox_view'),
      activeOn: ['inbox_view', 'inbox_view_conversation'],
      getterKeys: {
        count: 'notifications/getUnreadCount',
      },
    },
    {
      name: 'Contacts',
      label: t('SIDEBAR.CONTACTS'),
      icon: 'i-lucide-contact',
      activeOn: ['contacts_dashboard_index', 'contacts_edit'],
      to: accountScopedRoute(
        'contacts_dashboard_index',
        {},
        { page: 1, search: undefined }
      ),
    },
    {
      name: 'Campaigns',
      label: t('SIDEBAR.CAMPAIGNS'),
      icon: 'i-lucide-megaphone',
      children: [
        {
          name: 'WhatsApp',
          label: t('SIDEBAR.WHATSAPP'),
          to: accountScopedRoute('campaigns_whatsapp_index'),
        },
        {
          name: 'Live chat',
          label: t('SIDEBAR.LIVE_CHAT'),
          to: accountScopedRoute('campaigns_livechat_index'),
        },
        {
          name: 'SMS',
          label: t('SIDEBAR.SMS'),
          to: accountScopedRoute('campaigns_sms_index'),
        },
      ],
    },
    ...(isAdmin.value
      ? [
          {
            name: 'Chatbot',
            label: 'Chatbot Builder',
            icon: 'i-lucide-bot',
            to: accountScopedRoute('chatbot_builder'),
          },
          {
            name: 'Templates',
            label: 'Templates',
            icon: 'i-lucide-layout-template',
            to: accountScopedRoute('templates_index'),
          },
          {
            name: 'Gallery',
            label: 'Gallery',
            icon: 'i-lucide-image',
            to: accountScopedRoute('gallery_index'),
          },
        ]
      : []),
    {
      name: 'Reports',
      label: t('SIDEBAR.REPORTS'),
      icon: 'i-lucide-chart-spline',
      children: [
        {
          name: 'Report Overview',
          label: t('SIDEBAR.REPORTS_OVERVIEW'),
          to: accountScopedRoute('account_overview_reports'),
        },
        {
          name: 'Report Conversation',
          label: t('SIDEBAR.REPORTS_CONVERSATION'),
          to: accountScopedRoute('conversation_reports'),
        },
        ...reportRoutes.value,
        {
          name: 'Reports CSAT',
          label: t('SIDEBAR.CSAT'),
          to: accountScopedRoute('csat_reports'),
        },
        {
          name: 'Reports Bot',
          label: t('SIDEBAR.REPORTS_BOT'),
          to: accountScopedRoute('bot_reports'),
        },
      ],
    },
    {
      name: 'Settings',
      label: t('SIDEBAR.SETTINGS'),
      icon: 'i-lucide-bolt',
      children: [
        {
          name: 'Settings Account Settings',
          label: t('SIDEBAR.ACCOUNT_SETTINGS'),
          icon: 'i-lucide-briefcase',
          to: accountScopedRoute('general_settings_index'),
        },
        {
          name: 'Settings Agents',
          label: t('SIDEBAR.AGENTS'),
          icon: 'i-lucide-square-user',
          to: accountScopedRoute('agent_list'),
        },
        {
          name: 'Settings Teams',
          label: t('SIDEBAR.TEAMS'),
          icon: 'i-lucide-users',
          activeOn: [
            'settings_teams_list',
            'settings_teams_new',
            'settings_teams_finish',
            'settings_teams_add_agents',
            'settings_teams_show',
            'settings_teams_edit',
            'settings_teams_edit_members',
            'settings_teams_edit_finish',
          ],
          to: accountScopedRoute('settings_teams_list'),
        },
        {
          name: 'Settings Inboxes',
          label: t('SIDEBAR.INBOXES'),
          icon: 'i-lucide-inbox',
          activeOn: [
            'settings_inbox_list',
            'settings_inbox_show',
            'settings_inbox_new',
            'settings_inbox_finish',
            'settings_inboxes_page_channel',
            'settings_inboxes_add_agents',
          ],
          to: accountScopedRoute('settings_inbox_list'),
        },
        {
          name: 'Settings Labels',
          label: t('SIDEBAR.LABELS'),
          icon: 'i-lucide-tags',
          to: accountScopedRoute('labels_list'),
        },
        {
          name: 'Settings Custom Attributes',
          label: t('SIDEBAR.CUSTOM_ATTRIBUTES'),
          icon: 'i-lucide-code',
          to: accountScopedRoute('attributes_list'),
        },
        {
          name: 'Settings Automation',
          label: t('SIDEBAR.AUTOMATION'),
          icon: 'i-lucide-repeat',
          to: accountScopedRoute('automation_list'),
        },
        {
          name: 'Settings Agent Bots',
          label: t('SIDEBAR.AGENT_BOTS'),
          icon: 'i-lucide-bot',
          to: accountScopedRoute('agent_bots'),
        },
        {
          name: 'Settings Macros',
          label: t('SIDEBAR.MACROS'),
          icon: 'i-lucide-toy-brick',
          to: accountScopedRoute('macros_wrapper'),
        },
        {
          name: 'Settings Canned Responses',
          label: t('SIDEBAR.CANNED_RESPONSES'),
          icon: 'i-lucide-message-square-quote',
          to: accountScopedRoute('canned_list'),
        },
        {
          name: 'Settings Integrations',
          label: t('SIDEBAR.INTEGRATIONS'),
          icon: 'i-lucide-blocks',
          to: accountScopedRoute('settings_applications'),
        },
        {
          name: 'Settings Security',
          label: t('SIDEBAR.SECURITY'),
          icon: 'i-lucide-shield',
          to: accountScopedRoute('security_settings_index'),
        },
        {
          name: 'Settings Billing',
          label: t('SIDEBAR.BILLING'),
          icon: 'i-lucide-credit-card',
          to: accountScopedRoute('billing_settings_index'),
        },
      ],
    },
  ];
});
MENUEOF

cat > /tmp/cs_wa.css <<'CSSEOF'
/* CS-WA3-START */

.conversations-list-wrap::before, .conversations-list::before { content: none !important; }

/* ---- doodle halka ---- */
.conversation-panel {
  background-color: var(--cs-chat, #0B141A) !important;
  background-image: none !important;
  position: relative;
}
.conversation-panel::before {
  content: '' !important;
  position: absolute; inset: 0;
  pointer-events: none; z-index: 0;
  opacity: .05;
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='352' height='232' viewBox='0 0 352 232'%3E%3Cg fill='none' stroke='%23fff' stroke-width='1.25' stroke-linecap='round' stroke-linejoin='round'%3E%3Cg transform='translate(18,20)'%3E%3Cpath d='M0 6a6 6 0 0 1 12 0 6 6 0 0 1-6 6H2l2-3a6 6 0 0 1-4-3z'/%3E%3C/g%3E%3Cg transform='translate(62,14)'%3E%3Cpath d='M0 0h14v10H4L0 13z'/%3E%3C/g%3E%3Cg transform='translate(108,22)'%3E%3Cpath d='M6 0l1.8 3.7 4 .6-2.9 2.8.7 4L6 9.2 2.4 11l.7-4L.2 4.3l4-.6z'/%3E%3C/g%3E%3Cg transform='translate(150,16)'%3E%3Cpath d='M2 2h12v12H2z M2 6h12'/%3E%3C/g%3E%3Cg transform='translate(192,20)'%3E%3Cpath d='M7 0C3 0 0 3 0 6.5 0 11 7 16 7 16s7-5 7-9.5C14 3 11 0 7 0z M7 4a2.5 2.5 0 1 1 0 5 2.5 2.5 0 0 1 0-5z'/%3E%3C/g%3E%3Cg transform='translate(234,14)'%3E%3Cpath d='M0 8c0-4 3-7 7-7s7 3 7 7-3 7-7 7-7-3-7-7z M4 8h6 M7 5v6'/%3E%3C/g%3E%3Cg transform='translate(276,20)'%3E%3Cpath d='M0 3h16v10H0z M0 3l8 6 8-6'/%3E%3C/g%3E%3Cg transform='translate(318,16)'%3E%3Cpath d='M3 0h10v4H3z M1 4h14v11H1z M6 8h4'/%3E%3C/g%3E%3Cg transform='translate(14,64)'%3E%3Cpath d='M0 10c3-5 9-5 12 0 M6 4a2.5 2.5 0 1 1 0 .01'/%3E%3C/g%3E%3Cg transform='translate(56,58)'%3E%3Cpath d='M0 0h13M0 5h9M0 10h11'/%3E%3C/g%3E%3Cg transform='translate(98,62)'%3E%3Cpath d='M8 0a8 8 0 1 1 0 16A8 8 0 0 1 8 0z M8 4v4.5l3 2'/%3E%3C/g%3E%3Cg transform='translate(140,60)'%3E%3Cpath d='M0 0l11 6-11 6z'/%3E%3C/g%3E%3Cg transform='translate(182,58)'%3E%3Cpath d='M2 0h11l3 4v11H2z M13 0v4h3'/%3E%3C/g%3E%3Cg transform='translate(224,62)'%3E%3Cpath d='M0 6h4l4-5v14l-4-5H0z M11 4a4 4 0 0 1 0 8'/%3E%3C/g%3E%3Cg transform='translate(266,58)'%3E%3Cpath d='M1 1h14v10H1z M1 11l5-4 3 2 3-3 3 3'/%3E%3C/g%3E%3Cg transform='translate(308,64)'%3E%3Cpath d='M6 0a6 6 0 0 1 6 6c0 4-6 10-6 10S0 10 0 6a6 6 0 0 1 6-6z'/%3E%3C/g%3E%3Cg transform='translate(20,106)'%3E%3Cpath d='M0 4h5l3-4h4l3 4h1v10H0z M8 6a3 3 0 1 1 0 6 3 3 0 0 1 0-6z'/%3E%3C/g%3E%3Cg transform='translate(62,110)'%3E%3Cpath d='M6 0l6 12H0z'/%3E%3C/g%3E%3Cg transform='translate(104,104)'%3E%3Cpath d='M0 0h12v12H0z M3 3h6v6H3z'/%3E%3C/g%3E%3Cg transform='translate(146,108)'%3E%3Cpath d='M0 6a6 6 0 1 0 12 0 6 6 0 0 0-12 0z M3 6l2 2 4-4'/%3E%3C/g%3E%3Cg transform='translate(188,104)'%3E%3Cpath d='M1 3h14v9H1z M4 3V1h8v2 M4 12v2h8v-2'/%3E%3C/g%3E%3Cg transform='translate(230,110)'%3E%3Cpath d='M0 12L6 0l6 12z M4 12v3h4v-3'/%3E%3C/g%3E%3Cg transform='translate(272,106)'%3E%3Cpath d='M2 2l10 10M12 2L2 12'/%3E%3C/g%3E%3Cg transform='translate(314,110)'%3E%3Cpath d='M0 8h16 M4 4l-4 4 4 4 M12 4l4 4-4 4'/%3E%3C/g%3E%3Cg transform='translate(16,150)'%3E%3Cpath d='M0 2h14v12H0z M3 0v4M11 0v4M0 6h14'/%3E%3C/g%3E%3Cg transform='translate(58,154)'%3E%3Cpath d='M7 0a7 7 0 1 1 0 14A7 7 0 0 1 7 0z M4 7h6'/%3E%3C/g%3E%3Cg transform='translate(100,148)'%3E%3Cpath d='M0 10c0-6 5-10 8-10s8 4 8 10'/%3E%3C/g%3E%3Cg transform='translate(142,152)'%3E%3Cpath d='M2 0h10v14l-5-4-5 4z'/%3E%3C/g%3E%3Cg transform='translate(184,150)'%3E%3Cpath d='M0 0h14v3H0z M2 3v10h10V3 M6 6v4M8 6v4'/%3E%3C/g%3E%3Cg transform='translate(226,154)'%3E%3Cpath d='M8 0l2 5 5 .5-4 3.5 1 5-4-2.6L4 14l1-5L1 5.5 6 5z'/%3E%3C/g%3E%3Cg transform='translate(268,148)'%3E%3Cpath d='M1 1h13v13H1z M4 7h7M7 4v7'/%3E%3C/g%3E%3Cg transform='translate(310,152)'%3E%3Cpath d='M0 5a5 5 0 0 1 10 0v6H0z M3 11v3h4v-3'/%3E%3C/g%3E%3Cg transform='translate(22,196)'%3E%3Cpath d='M0 3h16v9H0z M5 12v2h6v-2 M2 16h12'/%3E%3C/g%3E%3Cg transform='translate(64,198)'%3E%3Cpath d='M6 0a6 6 0 1 1 0 12A6 6 0 0 1 6 0z M6 3v3l2 2'/%3E%3C/g%3E%3Cg transform='translate(106,194)'%3E%3Cpath d='M0 6h12 M8 2l4 4-4 4'/%3E%3C/g%3E%3Cg transform='translate(148,198)'%3E%3Cpath d='M2 0h8a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H2a2 2 0 0 1-2-2V2a2 2 0 0 1 2-2z M4 3h4M4 6h4M4 9h2'/%3E%3C/g%3E%3Cg transform='translate(190,194)'%3E%3Cpath d='M0 0h14M0 5h14M0 10h8'/%3E%3C/g%3E%3Cg transform='translate(232,198)'%3E%3Cpath d='M7 0l7 7-7 7-7-7z'/%3E%3C/g%3E%3Cg transform='translate(274,194)'%3E%3Cpath d='M1 4h12v9H1z M4 4V2a3 3 0 0 1 6 0v2'/%3E%3C/g%3E%3Cg transform='translate(316,198)'%3E%3Cpath d='M0 0l14 7-14 7 3-7z'/%3E%3C/g%3E%3C/g%3E%3C/svg%3E");
  background-repeat: repeat;
  background-size: 352px 232px;
}
.conversation-panel > * { position: relative; z-index: 1; }

/* ---- composer chhota ---- */
.resizable-editor-wrapper {
  --editor-height: 54px !important;
  --editor-min-allowed: 44px !important;
  min-height: 0 !important;
}
.resizable-editor-wrapper .ProseMirror {
  min-height: 1.4rem !important;
  max-height: 7rem !important;
}
.reply-box { border: none !important; background: transparent !important; padding: 4px 10px 8px !important; }

/* ---- SEARCH BAR ---- */
.cs-search {
  margin: 0 12px 11px;
  background: var(--cs-fld, #202C33);
  border-radius: 9px;
  padding: 0 14px;
  display: flex;
  align-items: center;
  gap: 12px;
  flex-shrink: 0;
}
.cs-search__ic { width: 19px; height: 19px; color: var(--cs-tx3, #8696A0); flex-shrink: 0; }
.cs-search input {
  flex: 1; min-width: 0;
  background: none; border: none; outline: none;
  color: var(--cs-tx, #E9EDEF);
  font-size: 14px; font-family: inherit;
  padding: 10px 0;
}
.cs-search input::placeholder { color: var(--cs-tx3, #8696A0); }
.cs-search__x { width: 17px; height: 17px; color: var(--cs-tx3); cursor: pointer; flex-shrink: 0; }

/* ---- PILLS ---- */
.cs-pills { display: flex; gap: 8px; padding: 0 12px 10px; overflow-x: auto; flex-shrink: 0; }
.cs-pills::-webkit-scrollbar { display: none; }
.cs-pill {
  font-size: 13.5px; padding: 5px 14px; border-radius: 16px;
  background: var(--cs-fld, #202C33); color: var(--cs-tx2, #AEBAC1);
  border: 0; cursor: pointer; white-space: nowrap;
  display: flex; align-items: center; gap: 6px; flex-shrink: 0;
}
.cs-pill:hover { filter: brightness(1.15); }
.cs-pill--on { background: var(--cs-g-tint, #103529); color: var(--cs-g, #00A884); }
.cs-pill__count { font-weight: 600; }

/* ---- list row ---- */
.cs-row { padding: 10px 16px !important; }
.cs-row__av > *, .cs-row__av img {
  width: 49px !important; height: 49px !important; min-width: 49px !important;
  border-radius: 50% !important; font-size: 15px !important;
}
.cs-row__body { border-bottom: 1px solid var(--cs-ln2, #1D282F) !important; }

/* ---- right-click menu ---- */
.z-\[9999\] > div {
  background: var(--cs-menu, #233138) !important;
  backdrop-filter: none !important;
  border-radius: 8px !important;
  outline: none !important;
  box-shadow: 0 4px 22px rgba(0,0,0,.45) !important;
  padding: 7px 0 !important;
  min-width: 232px !important;
}
.z-\[9999\] [role='button'], .z-\[9999\] > div > div {
  height: auto !important; padding: 9px 16px !important;
  border-radius: 0 !important; gap: 14px !important;
}
.z-\[9999\] [role='button']:hover { background: var(--cs-menu-hov, #182229) !important; }
.z-\[9999\] span { font-size: 14.5px !important; }
.z-\[9999\] hr { margin: 6px 0 !important; border-color: var(--cs-ln, #222E35) !important; }

/* ---- list header ---- */
.conversations-list-wrap h1 { font-size: 21px !important; font-weight: 600 !important; }
aside nav ul { gap: 4px !important; }

/* CS-WA3-END */
CSSEOF

say "1/4  Sidebar.vue  (rail)"
python3 - "$SB" /tmp/cs_menu.js <<'PYEOF'
import io, sys
p, mf = sys.argv[1], sys.argv[2]
s = io.open(p, encoding='utf-8').read()
menu = io.open(mf, encoding='utf-8').read().rstrip()
i = s.index('const menuItems = computed(() => {')
j = s.index('</script>', i)
s = s[:i] + menu + "\n" + s[j:]
print("   menuItems OK")
blk = """        <ComposeConversation align="start">
          <template #trigger="{ isOpen }">
            <Button
              icon="i-lucide-pen-line"
              color="slate"
              size="sm"
              class="dark:hover:!bg-n-slate-9/30"
              :class="[
                isEffectivelyCollapsed
                  ? '!size-8 !outline-n-weak !text-n-slate-11'
                  : '!h-7 !outline-n-weak !text-n-slate-11',
                { '!bg-n-alpha-2 dark:!bg-n-slate-9/30': isOpen },
              ]"
            />
          </template>
        </ComposeConversation>
"""
print("   compose button " + ("hataya" if blk in s else "match nahi hua"))
s = s.replace(blk, "")
io.open(p,'w',encoding='utf-8').write(s)
PYEOF

say "2/4  ChatList.vue  (search + pills + title)"
python3 - "$CL" <<'PYEOF'
import io, sys
p = sys.argv[1]
s = io.open(p, encoding='utf-8').read()
E = []

# -- a) search + channel filter ke refs --
E.append((
"const showAdvancedFilters = ref(false);",
"""const showAdvancedFilters = ref(false);
// WhatsApp jaisi search + channel filter
const searchQuery = ref('');
const activeChannel = ref(null);"""))

# -- b) pills: All pehle (WhatsApp tarteeb) --
E.append((
"""    count: conversationStats.value[countKey] || 0,
  }));
});""",
"""    count: conversationStats.value[countKey] || 0,
  }));
  const order = { all: 0, me: 1, unassigned: 2 };
  return items
    .slice()
    .sort((a, b) => (order[a.key] ?? 9) - (order[b.key] ?? 9));
});"""))
E.append((
"""  return filterItemsByPermission(
    ASSIGNEE_TYPE_TAB_PERMISSIONS,
    userPermissions.value,
    item => item.permissions
  ).map(({ key, count: countKey }) => ({""",
"""  const items = filterItemsByPermission(
    ASSIGNEE_TYPE_TAB_PERMISSIONS,
    userPermissions.value,
    item => item.permissions
  ).map(({ key, count: countKey }) => ({"""))

# -- c) search + channel se list filter --
E.append((
"""  return localConversationList;
});""",
"""  if (activeChannel.value) {
    localConversationList = localConversationList.filter(
      c => c.inbox_id === activeChannel.value
    );
  }

  const q = searchQuery.value.trim().toLowerCase();
  if (q) {
    localConversationList = localConversationList.filter(c => {
      const name = c.meta?.sender?.name || '';
      const msgs = c.messages || [];
      const last = msgs.length ? msgs[msgs.length - 1]?.content || '' : '';
      return `${name} ${last}`.toLowerCase().includes(q);
    });
  }

  return localConversationList;
});"""))

# -- d) title "Chats" --
E.append((
"""  return t('CHAT_LIST.TAB_HEADING');
});

function filterByAssigneeTab""",
"""  return 'Chats';
});

function filterByAssigneeTab"""))

# -- e) template: search bar + channel pills --
E.append((
"""    <ChatTypeTabs
      v-if="!hasAppliedFiltersOrActiveFolders"
      :items="assigneeTabItems"
      :active-tab="activeAssigneeTab"
      is-compact
      @chat-tab-change="updateAssigneeTab"
    />""",
"""    <div class="cs-search">
      <span class="cs-search__ic i-lucide-search" />
      <input
        v-model="searchQuery"
        type="text"
        placeholder="Search chats, contacts or messages"
      />
      <span
        v-if="searchQuery"
        class="cs-search__x i-lucide-x"
        @click="searchQuery = ''"
      />
    </div>

    <ChatTypeTabs
      v-if="!hasAppliedFiltersOrActiveFolders"
      :items="assigneeTabItems"
      :active-tab="activeAssigneeTab"
      is-compact
      @chat-tab-change="updateAssigneeTab"
    />

    <div v-if="inboxesList.length > 1" class="cs-pills">
      <button
        type="button"
        class="cs-pill"
        :class="{ 'cs-pill--on': !activeChannel }"
        @click="activeChannel = null"
      >
        All channels
      </button>
      <button
        v-for="ib in inboxesList"
        :key="ib.id"
        type="button"
        class="cs-pill"
        :class="{ 'cs-pill--on': activeChannel === ib.id }"
        @click="activeChannel = ib.id"
      >
        {{ ib.name }}
      </button>
    </div>"""))

for i,(o,n) in enumerate(E):
    c = s.count(o)
    assert c == 1, "block %d: match %d (chahiye 1)" % (i+1, c)
    s = s.replace(o, n)
io.open(p,'w',encoding='utf-8').write(s)
print("   %d/%d blocks OK" % (len(E), len(E)))
PYEOF

say "3/4  app.scss"
python3 - "$SCSS" /tmp/cs_wa.css <<'PYEOF'
import io, re, sys
p, c = sys.argv[1], sys.argv[2]
s = io.open(p, encoding='utf-8').read()
b = io.open(c, encoding='utf-8').read().strip()
s2 = re.sub(r"/\* CS-WA3-START \*/.*?/\* CS-WA3-END \*/\n?", "", s, flags=re.S)
if s2 != s: print("   purana block hataya")
io.open(p,'w',encoding='utf-8').write(s2.rstrip() + "\n\n" + b + "\n")
print("   append OK")
PYEOF

say "4/4  CHECK"
for F in "$SB" "$CL"; do
docker exec -u root chatssync-dev node -e "
const fs=require('fs');
const c=require('/src/node_modules/@vue/compiler-sfc');
const src=fs.readFileSync('/src/$F','utf8');
const {descriptor,errors}=c.parse(src,{filename:'x.vue'});
if(errors.length){console.error('PARSE FAIL $F');errors.forEach(e=>console.error(e.message));process.exit(1);}
try{ c.compileScript(descriptor,{id:'x'}); }catch(e){ console.error('SCRIPT FAIL $F: '+e.message); process.exit(1); }
console.log('   OK  $F');
" || die "FAIL — wapas: cp $BK/*.$S.bak (backup se restore karo)"
done

git diff --stat "$SB" "$CL" "$SCSS"
echo
echo ">> tail -3 /tmp/vite.log   ('built in' ka intezaar)"
echo ">> bash push.sh"
echo ">> Ctrl-Shift-R"
