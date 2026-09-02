#!/usr/bin/env bash
# =====================================================================
#  apply-wa-layout.sh   —   ChatsSync: poori WhatsApp layout, ek patch
#
#   1. ConversationCard.vue  ->  WhatsApp row (49px circle, preview,
#                                waqt, unread badge)
#   2. app.scss              ->  doodle, bubble tail, day chips,
#                                header, composer, right-click menus,
#                                rail, scrollbars — light + dark
#
#  Sab kuch marker ke andar hai:  /* CS-WA-START */ ... /* CS-WA-END */
#  Dobara chalao to purana block khud hat jaata hai (idempotent).
#
#  Chalane ka tareeqa:
#      cd /root/staging-build
#      curl -sO https://raw.githubusercontent.com/Akopopp/ChatsSync/new-ui/apply-wa-layout.sh
#      bash apply-wa-layout.sh
#
#  Poora wapas lena ho to:
#      git checkout -- app/javascript/dashboard/components/widgets/conversation/ConversationCard.vue
#      git checkout -- app/javascript/dashboard/assets/scss/app.scss
# =====================================================================
set -euo pipefail
cd /root/staging-build

CARD=app/javascript/dashboard/components/widgets/conversation/ConversationCard.vue
SCSS=app/javascript/dashboard/assets/scss/app.scss
BK=/root/backups
S=$(date +%F-%H%M%S)

say(){ printf '\n\033[1;36m>> %s\033[0m\n' "$*"; }
ok(){  printf '   \033[1;32mOK\033[0m  %s\n' "$*"; }
die(){ printf '\n\033[1;31m!! %s\033[0m\n' "$*"; exit 1; }

[ -f "$CARD" ] || die "nahi mili: $CARD"
[ -f "$SCSS" ] || die "nahi mili: $SCSS"
mkdir -p "$BK"
cp "$CARD" "$BK/ConversationCard.$S.bak"
cp "$SCSS" "$BK/app.scss.$S.bak"
ok "backup: $BK/*.$S.bak"

say "1/4  ConversationCard.vue  ->  WhatsApp row"
cat > /tmp/cs_newtpl.txt <<'CSTPLEOF'
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
CSTPLEOF

python3 - "$CARD" /tmp/cs_newtpl.txt <<'CSPYEOF'
import io, re, sys
card, tplf = sys.argv[1], sys.argv[2]
s = io.open(card, encoding='utf-8').read()
new = io.open(tplf, encoding='utf-8').read().rstrip() + "\n"

m = re.search(r"^<template>\n.*?^</template>\n", s, re.S | re.M)
assert m, "template block nahi mila"
s = s[:m.start()] + new + s[m.end():]
io.open(card, 'w', encoding='utf-8').write(s)
print("   template replace OK")
CSPYEOF

say "2/4  app.scss  ->  WhatsApp layout block"
cat > /tmp/cs_wa.css <<'CSCSSEOF'
/* CS-WA-START  — ChatsSync WhatsApp layout. Is marker ke andar sab kuch
   apply-wa-layout.sh ka likha hua hai. Haath se edit karo to theek hai,
   magar script dobara chalane par ye block replace ho jayega. */

:root {
  --cs-rail:#F0F2F5; --cs-rail-hov:#E3E6EA; --cs-rail-on:#DCEFE9;
  --cs-rail-ic:#54656F; --cs-rail-ic-on:#008069;
  --cs-panel:#FFFFFF; --cs-head:#F0F2F5; --cs-card:#FFFFFF;
  --cs-fld:#F0F2F5; --cs-fld-b:#E4E7E9;
  --cs-tx:#111B21; --cs-tx2:#54656F; --cs-tx3:#8696A0;
  --cs-ln:#E4E7E9; --cs-ln2:#F0F2F4; --cs-hov:#F5F6F8; --cs-sel:#E9EDEF;
  --cs-g:#008069; --cs-g-tint:#DCEFE9; --cs-b:#2F7FD1;
  --cs-menu:#FFFFFF; --cs-menu-hov:#F0F2F5;
  --cs-sent:#D9FDD3; --cs-recv:#FFFFFF;
  --cs-chat:#EFE7DE; --cs-doodle:.06;
  --cs-badge:#25D366; --cs-badge-tx:#053E20;
  --cs-red:#D63C4B;
  --cs-sh:0 1px .5px rgba(11,20,26,.13);
  --cs-menu-sh:0 4px 22px rgba(11,20,26,.18);
}

html.dark, body.dark, .dark, [data-theme='dark'] {
  --cs-rail:#202C33; --cs-rail-hov:#2A3942; --cs-rail-on:#103529;
  --cs-rail-ic:#AEBAC1; --cs-rail-ic-on:#00A884;
  --cs-panel:#111B21; --cs-head:#202C33; --cs-card:#182229;
  --cs-fld:#202C33; --cs-fld-b:#2A3942;
  --cs-tx:#E9EDEF; --cs-tx2:#AEBAC1; --cs-tx3:#8696A0;
  --cs-ln:#222E35; --cs-ln2:#1D282F; --cs-hov:#202C33; --cs-sel:#2A3942;
  --cs-g:#00A884; --cs-g-tint:#103529; --cs-b:#53BDEB;
  --cs-menu:#233138; --cs-menu-hov:#182229;
  --cs-sent:#005C4B; --cs-recv:#202C33;
  --cs-chat:#0B141A; --cs-doodle:.045;
  --cs-badge:#00A884; --cs-badge-tx:#0B141A;
  --cs-red:#F15C6D;
  --cs-sh:0 1px .5px rgba(0,0,0,.35);
  --cs-menu-sh:0 4px 22px rgba(0,0,0,.45);
}

/* ---------- 1. CHAT LIST ROW ---------- */
.cs-row {
  display: flex;
  gap: 14px;
  align-items: center;
  padding: 11px 20px 11px 16px;
  cursor: pointer;
  position: relative;
}
.cs-row:hover   { background: var(--cs-hov); }
.cs-row--on     { background: var(--cs-sel) !important; }
.cs-row--sel    { background: var(--cs-g-tint) !important; }

.cs-row__av { flex-shrink: 0; position: relative; }
.cs-row__av > * { border-radius: 50% !important; }

.cs-row__body {
  flex: 1;
  min-width: 0;
  border-bottom: 1px solid var(--cs-ln2);
  padding-bottom: 11px;
  margin-bottom: -11px;
}
.cs-row:last-child .cs-row__body { border-bottom: none; }

.cs-row__l1 {
  display: flex;
  align-items: baseline;
  gap: 9px;
  margin-bottom: 3px;
}
.cs-row__name {
  font-size: 15.5px;
  flex: 1;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  color: var(--cs-tx);
}
.cs-row--unread .cs-row__name { font-weight: 600; }
.cs-row__time {
  font-size: 11.5px;
  color: var(--cs-tx3);
  flex-shrink: 0;
  white-space: nowrap;
}
.cs-row--unread .cs-row__time { color: var(--cs-g); }

.cs-row__l2 {
  display: flex;
  align-items: center;
  gap: 7px;
  min-width: 0;
}
.cs-row__prev {
  font-size: 13.5px;
  color: var(--cs-tx3);
  flex: 1;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  line-height: 1.45;
  margin: 0;
}
.cs-row__prev * { color: inherit !important; font-size: inherit !important; }
.cs-row__badge { flex-shrink: 0; }
.cs-row__badge > * {
  background: var(--cs-badge) !important;
  color: var(--cs-badge-tx) !important;
  font-size: 11px !important;
  font-weight: 600 !important;
  min-width: 20px;
  height: 20px;
  border-radius: 10px !important;
}

/* ---------- 2. LIST HEADER (bara title) ---------- */
.conversations-list-wrap h1,
.chat-list__top h1 {
  font-size: 21px !important;
  font-weight: 600 !important;
}

/* ---------- 3. THREAD: doodle + day chips ---------- */
.conversation-panel,
.cs-chat-bg {
  background-color: var(--cs-chat) !important;
  position: relative;
}
.conversation-panel::before,
.cs-chat-bg::before {
  content: '';
  position: absolute;
  inset: 0;
  pointer-events: none;
  z-index: 0;
  opacity: var(--cs-doodle);
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='352' height='232' viewBox='0 0 352 232'%3E%3Cg fill='none' stroke='%23fff' stroke-width='1.25' stroke-linecap='round' stroke-linejoin='round'%3E%3Cg transform='translate(18,20)'%3E%3Cpath d='M0 6a6 6 0 0 1 12 0 6 6 0 0 1-6 6H2l2-3a6 6 0 0 1-4-3z'/%3E%3C/g%3E%3Cg transform='translate(62,14)'%3E%3Cpath d='M0 0h14v10H4L0 13z'/%3E%3C/g%3E%3Cg transform='translate(108,22)'%3E%3Cpath d='M6 0l1.8 3.7 4 .6-2.9 2.8.7 4L6 9.2 2.4 11l.7-4L.2 4.3l4-.6z'/%3E%3C/g%3E%3Cg transform='translate(150,16)'%3E%3Cpath d='M2 2h12v12H2z M2 6h12'/%3E%3C/g%3E%3Cg transform='translate(192,20)'%3E%3Cpath d='M7 0C3 0 0 3 0 6.5 0 11 7 16 7 16s7-5 7-9.5C14 3 11 0 7 0z M7 4a2.5 2.5 0 1 1 0 5 2.5 2.5 0 0 1 0-5z'/%3E%3C/g%3E%3Cg transform='translate(234,14)'%3E%3Cpath d='M0 8c0-4 3-7 7-7s7 3 7 7-3 7-7 7-7-3-7-7z M4 8h6 M7 5v6'/%3E%3C/g%3E%3Cg transform='translate(276,20)'%3E%3Cpath d='M0 3h16v10H0z M0 3l8 6 8-6'/%3E%3C/g%3E%3Cg transform='translate(318,16)'%3E%3Cpath d='M3 0h10v4H3z M1 4h14v11H1z M6 8h4'/%3E%3C/g%3E%3Cg transform='translate(14,64)'%3E%3Cpath d='M0 10c3-5 9-5 12 0 M6 4a2.5 2.5 0 1 1 0 .01'/%3E%3C/g%3E%3Cg transform='translate(56,58)'%3E%3Cpath d='M0 0h13M0 5h9M0 10h11'/%3E%3C/g%3E%3Cg transform='translate(98,62)'%3E%3Cpath d='M8 0a8 8 0 1 1 0 16A8 8 0 0 1 8 0z M8 4v4.5l3 2'/%3E%3C/g%3E%3Cg transform='translate(140,60)'%3E%3Cpath d='M0 0l11 6-11 6z'/%3E%3C/g%3E%3Cg transform='translate(182,58)'%3E%3Cpath d='M2 0h11l3 4v11H2z M13 0v4h3'/%3E%3C/g%3E%3Cg transform='translate(224,62)'%3E%3Cpath d='M0 6h4l4-5v14l-4-5H0z M11 4a4 4 0 0 1 0 8'/%3E%3C/g%3E%3Cg transform='translate(266,58)'%3E%3Cpath d='M1 1h14v10H1z M1 11l5-4 3 2 3-3 3 3'/%3E%3C/g%3E%3Cg transform='translate(308,64)'%3E%3Cpath d='M6 0a6 6 0 0 1 6 6c0 4-6 10-6 10S0 10 0 6a6 6 0 0 1 6-6z'/%3E%3C/g%3E%3Cg transform='translate(20,106)'%3E%3Cpath d='M0 4h5l3-4h4l3 4h1v10H0z M8 6a3 3 0 1 1 0 6 3 3 0 0 1 0-6z'/%3E%3C/g%3E%3Cg transform='translate(62,110)'%3E%3Cpath d='M6 0l6 12H0z'/%3E%3C/g%3E%3Cg transform='translate(104,104)'%3E%3Cpath d='M0 0h12v12H0z M3 3h6v6H3z'/%3E%3C/g%3E%3Cg transform='translate(146,108)'%3E%3Cpath d='M0 6a6 6 0 1 0 12 0 6 6 0 0 0-12 0z M3 6l2 2 4-4'/%3E%3C/g%3E%3Cg transform='translate(188,104)'%3E%3Cpath d='M1 3h14v9H1z M4 3V1h8v2 M4 12v2h8v-2'/%3E%3C/g%3E%3Cg transform='translate(230,110)'%3E%3Cpath d='M0 12L6 0l6 12z M4 12v3h4v-3'/%3E%3C/g%3E%3Cg transform='translate(272,106)'%3E%3Cpath d='M2 2l10 10M12 2L2 12'/%3E%3C/g%3E%3Cg transform='translate(314,110)'%3E%3Cpath d='M0 8h16 M4 4l-4 4 4 4 M12 4l4 4-4 4'/%3E%3C/g%3E%3Cg transform='translate(16,150)'%3E%3Cpath d='M0 2h14v12H0z M3 0v4M11 0v4M0 6h14'/%3E%3C/g%3E%3Cg transform='translate(58,154)'%3E%3Cpath d='M7 0a7 7 0 1 1 0 14A7 7 0 0 1 7 0z M4 7h6'/%3E%3C/g%3E%3Cg transform='translate(100,148)'%3E%3Cpath d='M0 10c0-6 5-10 8-10s8 4 8 10'/%3E%3C/g%3E%3Cg transform='translate(142,152)'%3E%3Cpath d='M2 0h10v14l-5-4-5 4z'/%3E%3C/g%3E%3Cg transform='translate(184,150)'%3E%3Cpath d='M0 0h14v3H0z M2 3v10h10V3 M6 6v4M8 6v4'/%3E%3C/g%3E%3Cg transform='translate(226,154)'%3E%3Cpath d='M8 0l2 5 5 .5-4 3.5 1 5-4-2.6L4 14l1-5L1 5.5 6 5z'/%3E%3C/g%3E%3Cg transform='translate(268,148)'%3E%3Cpath d='M1 1h13v13H1z M4 7h7M7 4v7'/%3E%3C/g%3E%3Cg transform='translate(310,152)'%3E%3Cpath d='M0 5a5 5 0 0 1 10 0v6H0z M3 11v3h4v-3'/%3E%3C/g%3E%3Cg transform='translate(22,196)'%3E%3Cpath d='M0 3h16v9H0z M5 12v2h6v-2 M2 16h12'/%3E%3C/g%3E%3Cg transform='translate(64,198)'%3E%3Cpath d='M6 0a6 6 0 1 1 0 12A6 6 0 0 1 6 0z M6 3v3l2 2'/%3E%3C/g%3E%3Cg transform='translate(106,194)'%3E%3Cpath d='M0 6h12 M8 2l4 4-4 4'/%3E%3C/g%3E%3Cg transform='translate(148,198)'%3E%3Cpath d='M2 0h8a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H2a2 2 0 0 1-2-2V2a2 2 0 0 1 2-2z M4 3h4M4 6h4M4 9h2'/%3E%3C/g%3E%3Cg transform='translate(190,194)'%3E%3Cpath d='M0 0h14M0 5h14M0 10h8'/%3E%3C/g%3E%3Cg transform='translate(232,198)'%3E%3Cpath d='M7 0l7 7-7 7-7-7z'/%3E%3C/g%3E%3Cg transform='translate(274,194)'%3E%3Cpath d='M1 4h12v9H1z M4 4V2a3 3 0 0 1 6 0v2'/%3E%3C/g%3E%3Cg transform='translate(316,198)'%3E%3Cpath d='M0 0l14 7-14 7 3-7z'/%3E%3C/g%3E%3C/g%3E%3C/svg%3E");
}
.conversation-panel > *,
.cs-chat-bg > * { position: relative; z-index: 1; }

/* din ka chip — Chatwoot ka date separator */
.conversation-panel .date--separator,
.conversation-panel [class*='date-separator'] {
  display: flex !important;
  justify-content: center !important;
  margin: 10px 0 !important;
  background: none !important;
}
.conversation-panel .date--separator::before,
.conversation-panel .date--separator::after { display: none !important; }
.conversation-panel .date--separator > span,
.conversation-panel .date--separator > div {
  background: var(--cs-head) !important;
  color: var(--cs-tx2) !important;
  font-size: 12px !important;
  font-weight: 500 !important;
  padding: 5px 13px !important;
  border-radius: 8px !important;
  box-shadow: var(--cs-sh);
  border: none !important;
}

/* ---------- 4. BUBBLE + NOK (tail) ---------- */
.left-bubble, .right-bubble {
  position: relative;
  box-shadow: var(--cs-sh);
}
.left-bubble::before {
  content: '';
  position: absolute;
  top: 0;
  left: -8px;
  border-top: 9px solid var(--cs-recv);
  border-left: 9px solid transparent;
}
.right-bubble::before {
  content: '';
  position: absolute;
  top: 0;
  right: -8px;
  border-top: 9px solid var(--cs-sent);
  border-right: 9px solid transparent;
}
/* grouped message par nok nahi */
.left-bubble.rounded-tl-none::before,
.right-bubble.rounded-tr-none::before { content: ''; }
.bg-n-solid-sent     { background: var(--cs-sent) !important; }
.bg-n-solid-received { background: var(--cs-recv) !important; }

/* ---------- 5. COMPOSER: patli pill ---------- */
.cs-composer {
  display: flex;
  align-items: flex-end;
  gap: 8px;
  background: var(--cs-fld);
  border-radius: 10px;
  padding: 4px 10px;
  min-height: 46px;
}
.cs-left, .cs-right, .cs-rec {
  display: flex;
  align-items: center;
  gap: 2px;
  flex-shrink: 0;
}
.cs-rec { flex: 1; gap: 8px; }
.cs-rec__spacer { flex: 1; }
.cs-rec__dot {
  width: 9px; height: 9px; border-radius: 50%;
  background: var(--cs-red);
  animation: cs-blink 1.4s ease-in-out infinite;
}
.cs-rec__dot--paused { animation: none; opacity: .45; }
@keyframes cs-blink { 0%,100%{opacity:1} 50%{opacity:.25} }
.cs-rec__time {
  font-size: 13px;
  color: var(--cs-tx2);
  font-variant-numeric: tabular-nums;
}
.cs-send > * {
  border-radius: 50% !important;
  background: var(--cs-g) !important;
  color: #fff !important;
}

/* ---------- 6. PILLS ---------- */
.cs-pills {
  display: flex;
  gap: 8px;
  padding: 0 12px 12px;
  align-items: center;
  overflow-x: auto;
}
.cs-pills::-webkit-scrollbar { display: none; }
.cs-pill {
  font-size: 13.5px;
  padding: 5px 14px;
  border-radius: 16px;
  background: var(--cs-fld);
  color: var(--cs-tx2);
  cursor: pointer;
  white-space: nowrap;
  border: 0;
  display: flex;
  align-items: center;
  gap: 6px;
  flex-shrink: 0;
}
.cs-pill:hover  { filter: brightness(1.12); }
.cs-pill--on    { background: var(--cs-g-tint); color: var(--cs-g); }
.cs-pill__count { font-weight: 600; }

/* ---------- 7. RIGHT-CLICK MENU ---------- */
.z-\[9999\] > div,
.z-\[9999\] > ul,
.z-\[9999\] > nav {
  background: var(--cs-menu) !important;
  border-radius: 8px !important;
  box-shadow: var(--cs-menu-sh) !important;
  padding: 7px 0 !important;
  min-width: 212px;
  border: none !important;
  font-size: 14.5px;
}
.z-\[9999\] li,
.z-\[9999\] [role='button'],
.z-\[9999\] button {
  display: flex !important;
  align-items: center !important;
  gap: 14px !important;
  padding: 10px 17px !important;
  border-radius: 0 !important;
  height: auto !important;
  color: var(--cs-tx) !important;
  font-size: 14.5px !important;
  font-weight: 400 !important;
  width: 100%;
}
.z-\[9999\] li:hover,
.z-\[9999\] [role='button']:hover,
.z-\[9999\] button:hover {
  background: var(--cs-menu-hov) !important;
}
.z-\[9999\] span { font-size: 14.5px !important; }
.z-\[9999\] svg,
.z-\[9999\] i { width: 19px; height: 19px; color: var(--cs-tx2); }
.z-\[9999\] hr { border-color: var(--cs-ln) !important; margin: 6px 0 !important; }
.z-\[9999\] .text-n-ruby-11,
.z-\[9999\] [class*='ruby'] { color: var(--cs-red) !important; }

/* ---------- 8. SCROLLBAR ---------- */
.conversation-panel::-webkit-scrollbar,
.conversations-list::-webkit-scrollbar { width: 6px; }
.conversation-panel::-webkit-scrollbar-thumb,
.conversations-list::-webkit-scrollbar-thumb {
  background: var(--cs-fld-b);
  border-radius: 3px;
}
.conversation-panel::-webkit-scrollbar-track,
.conversations-list::-webkit-scrollbar-track { background: transparent; }

/* CS-WA-END */
CSCSSEOF

python3 - "$SCSS" /tmp/cs_wa.css <<'CSPYEOF'
import io, re, sys
scss, cssf = sys.argv[1], sys.argv[2]
s = io.open(scss, encoding='utf-8').read()
block = io.open(cssf, encoding='utf-8').read().strip()

# purana block hatao (idempotent)
s2 = re.sub(r"/\* CS-WA-START.*?/\* CS-WA-END \*/\n?", "", s, flags=re.S)
if s2 != s:
    print("   purana block hataya")
s = s2.rstrip() + "\n\n" + block + "\n"
io.open(scss, 'w', encoding='utf-8').write(s)
print("   append OK")
CSPYEOF

say "3/4  CHECK"
docker exec -u root chatssync-dev node -e "
const fs=require('fs');
const c=require('/src/node_modules/@vue/compiler-sfc');
const src=fs.readFileSync('/src/$CARD','utf8');
const {descriptor,errors}=c.parse(src,{filename:'ConversationCard.vue'});
if(errors.length){console.error('PARSE FAIL');errors.forEach(e=>console.error(e.message));process.exit(1);}
try{ c.compileScript(descriptor,{id:'x'}); }catch(e){ console.error('SCRIPT FAIL: '+e.message); process.exit(1); }
if(!/cs-row__name/.test(src)){console.error('template nahi laga');process.exit(1);}
console.log('   vue parse + compileScript OK');
" || die "vue FAIL — wapas: cp $BK/ConversationCard.$S.bak $CARD"

docker exec -u root chatssync-dev node -e "
const sass=require('/src/node_modules/sass');
try{ sass.compile('/src/$SCSS',{loadPaths:['/src/app/javascript','/src/node_modules']}); }
catch(e){ console.error('SCSS FAIL: '+e.message); process.exit(1); }
console.log('   scss compile OK');
" || echo "   (sass module nahi mila ya fail — vite build khud pakad legi)"

say "4/4  HO GAYA"
git diff --stat "$CARD" "$SCSS"
cat <<'ENDMSG'

   Ab:
     tail -3 /tmp/vite.log      # 'built in' aane tak RUKO
                                # ('build started...' dikhe to abhi nahi)
     bash push.sh
     browser: Ctrl-Shift-R

   Poora wapas lena ho to:
     git checkout -- app/javascript/dashboard/components/widgets/conversation/ConversationCard.vue
     git checkout -- app/javascript/dashboard/assets/scss/app.scss
ENDMSG
