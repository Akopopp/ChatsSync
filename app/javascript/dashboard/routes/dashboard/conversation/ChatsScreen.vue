<script setup>
/* =====================================================================
   ChatsScreen.vue  —  ChatsSync ka apna Chats tab
   index.html (chatssync-v16) ka markup, Chatwoot ka data.
   Chatwoot ke ChatList / ConversationBox / MessagesView / ReplyBox
   ismein use NAHI hote — poora markup apna hai.
   ===================================================================== */
import { ref, computed, watch, onMounted, nextTick } from 'vue';
import { useStore } from 'vuex';
import { useRoute, useRouter } from 'vue-router';
import { useMapGetter } from 'dashboard/composables/store.js';
import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import MessageFormatter from 'shared/helpers/MessageFormatter.js';
import AudioChip from 'next/message/chips/Audio.vue';
import AudioRecorder from 'dashboard/components/widgets/WootWriter/AudioRecorder.vue';

const props = defineProps({
  conversationId: { type: [String, Number], default: 0 },
  inboxId: { type: [String, Number], default: 0 },
});

const store = useStore();
const route = useRoute();
const router = useRouter();

/* ---------------- store ---------------- */
const allChats = useMapGetter('getAllConversations');
const currentChat = useMapGetter('getSelectedChat');
const currentUser = useMapGetter('getCurrentUser');
const inboxesList = useMapGetter('inboxes/getInboxes');
const accountId = useMapGetter('getCurrentAccountId');
const listLoading = useMapGetter('getChatListLoadingStatus');

/* ---------------- local state ---------------- */
const q = ref('');
const filt = ref('all');
const draft = ref('');
const isRecording = ref(false);
const recState = ref('');
const recTime = ref('0:00');
const sendAfterRec = ref(false);
const pendingFiles = ref([]);
const threadRef = ref(null);
const recorderRef = ref(null);
const fileInput = ref(null);
const menu = ref({ open: false, x: 0, y: 0, chat: null, up: false });
const isMobile = ref(window.innerWidth <= 768);
const isLight = ref(false);
const showArchived = ref(false);
const LS = k => {
  try {
    return JSON.parse(localStorage.getItem('cs_' + k) || '{}');
  } catch (e) {
    return {};
  }
};
const saveLS = (k, v) => {
  try {
    localStorage.setItem('cs_' + k, JSON.stringify(v));
  } catch (e) {
    /* ignore */
  }
};
const pinned = ref(LS('pin'));
const muted = ref(LS('mute'));
const archived = ref(LS('arch'));

/* ---------------- helpers ---------------- */
const initials = name =>
  (name || '?')
    .split(' ')
    .filter(Boolean)
    .slice(0, 2)
    .map(w => w[0])
    .join('')
    .toUpperCase();

const COLORS = [
  '#7F77DD', '#E5793A', '#12A150', '#D9455F',
  '#2F7FD1', '#C247A8', '#4A9E8F', '#B5852B',
];
const colorFor = id => COLORS[Math.abs(Number(id) || 0) % COLORS.length];

const clock = ts => {
  if (!ts) return '';
  const d = new Date(ts * 1000);
  let h = d.getHours();
  const m = String(d.getMinutes()).padStart(2, '0');
  const ap = h >= 12 ? 'PM' : 'AM';
  h = h % 12 || 12;
  return `${h}:${m} ${ap}`;
};

const dayLabel = ts => {
  const d = new Date(ts * 1000);
  const t = new Date();
  const same = (a, b) => a.toDateString() === b.toDateString();
  if (same(d, t)) return 'Today';
  const y = new Date(t);
  y.setDate(y.getDate() - 1);
  if (same(d, y)) return 'Yesterday';
  return d.toLocaleDateString(undefined, {
    day: 'numeric',
    month: 'short',
    year: d.getFullYear() === t.getFullYear() ? undefined : 'numeric',
  });
};

const listTime = ts => {
  if (!ts) return '';
  const d = new Date(ts * 1000);
  const t = new Date();
  if (d.toDateString() === t.toDateString()) return clock(ts).replace(/ [AP]M$/, '');
  const y = new Date(t);
  y.setDate(y.getDate() - 1);
  if (d.toDateString() === y.toDateString()) return 'Yesterday';
  const diff = (t - d) / 86400000;
  if (diff < 7) return d.toLocaleDateString(undefined, { weekday: 'long' });
  return d.toLocaleDateString(undefined, { day: '2-digit', month: '2-digit', year: '2-digit' });
};

const chipFor = inboxId => {
  const ib = (inboxesList.value || []).find(i => i.id === inboxId);
  const ct = ib?.channel_type || '';
  if (/Whatsapp/.test(ct)) return { t: 'WA', c: 'wa' };
  if (/FacebookPage/.test(ct)) return { t: 'FB', c: 'fb' };
  if (/Instagram/.test(ct)) return { t: 'IG', c: 'ig' };
  return null;
};

/* ---------------- list ---------------- */
const stats = useMapGetter('conversationStats/getStats');

const pills = computed(() => {
  const base = [
    { k: 'all', n: 'All' },
    { k: 'unread', n: 'Unread' },
    { k: 'mine', n: 'Mine', c: stats.value?.mineCount },
    { k: 'unassigned', n: 'Unassigned', c: stats.value?.unAssignedCount },
  ];
  (inboxesList.value || []).forEach(ib => {
    base.push({ k: `in-${ib.id}`, n: ib.name });
  });
  return base;
});

const rows = computed(() => {
  let L = [...(allChats.value || [])];
  const f = filt.value;
  if (f === 'unread') L = L.filter(c => (c.unread_count || 0) > 0);
  else if (f === 'mine')
    L = L.filter(c => c.meta?.assignee?.id === currentUser.value?.id);
  else if (f === 'unassigned') L = L.filter(c => !c.meta?.assignee);
  else if (f.startsWith('in-')) {
    const id = Number(f.slice(3));
    L = L.filter(c => c.inbox_id === id);
  }
  const s = q.value.trim().toLowerCase();
  if (s) {
    L = L.filter(c => {
      const n = c.meta?.sender?.name || '';
      const p = c.meta?.sender?.phone_number || '';
      const m = c.messages?.length
        ? c.messages[c.messages.length - 1]?.content || ''
        : '';
      return `${n} ${p} ${m}`.toLowerCase().includes(s);
    });
  }
  L = L.filter(c =>
    showArchived.value ? archived.value[c.id] : !archived.value[c.id]
  );
  return L.sort((a, b) => {
    const p = (pinned.value[b.id] ? 1 : 0) - (pinned.value[a.id] ? 1 : 0);
    if (p) return p;
    return (b.timestamp || 0) - (a.timestamp || 0);
  });
});

/* API snake_case deti hai, AudioChip camelCase maangta hai */
const attach = a => ({
  ...a,
  id: a.id,
  dataUrl: a.data_url || a.dataUrl,
  fileType: a.file_type || a.fileType,
  fileName: a.file_name || a.fileName,
  extension: a.extension,
  transcribedText: a.transcribed_text || a.transcribedText,
});
const aUrl = a => a.data_url || a.dataUrl || '';
const aType = a => a.file_type || a.fileType || 'file';

const plain = html => {
  if (!html) return '';
  try {
    const f = new MessageFormatter(html);
    if (f.plainText) return f.plainText;
  } catch (e) {
    /* niche fallback */
  }
  return String(html)
    .replace(/<[^>]*>/g, '')
    .trim();
};

const previewOf = c => {
  const m = c.messages?.length ? c.messages[c.messages.length - 1] : null;
  if (!m) return 'No messages yet';
  if (m.content) return plain(m.content);
  const a = m.attachments?.[0];
  if (a) {
    const map = {
      image: 'Photo',
      audio: 'Voice message',
      video: 'Video',
      file: 'Document',
    };
    return map[a.file_type] || 'Attachment';
  }
  return '';
};

const isOut = c => {
  const m = c.messages?.length ? c.messages[c.messages.length - 1] : null;
  return m?.message_type === 1;
};

/* ---------------- thread ---------------- */
const messages = computed(() => currentChat.value?.messages || []);

const blocks = computed(() => {
  const out = [];
  let lastDay = null;
  let prevSender = null;
  messages.value.forEach(m => {
    const d = dayLabel(m.created_at);
    if (d !== lastDay) {
      out.push({ kind: 'day', id: `d${m.id}`, text: d });
      lastDay = d;
      prevSender = null;
    }
    if (m.message_type === 2) {
      out.push({ kind: 'sys', id: m.id, text: m.content });
      prevSender = null;
      return;
    }
    const key = `${m.message_type}-${m.private ? 'p' : ''}-${m.sender?.id || ''}`;
    out.push({ kind: 'msg', id: m.id, m, first: key !== prevSender });
    prevSender = key;
  });
  return out;
});

const bodyHtml = m => new MessageFormatter(m.content || '').formattedMessage;

const contact = computed(() => currentChat.value?.meta?.sender || {});
const contactStatus = computed(() => {
  const c = contact.value;
  return (
    c.phone_number ||
    c.email ||
    c.identifier ||
    (inboxesList.value || []).find(i => i.id === currentChat.value?.inbox_id)
      ?.name ||
    ''
  );
});

/* contact profile drawer */
const showProfile = ref(false);
const isNote = ref(false);
const showEmoji = ref(false);
const showTpl = ref(false);
const replyTo = ref(null);
const fwdMsg = ref(null);
const fwdPick = ref([]);
const infoMsg = ref(null);

const EMOJIS = (
  '😀 😃 😄 😁 😆 😅 😂 🙂 🙃 😉 😊 😇 🥰 😍 😘 😗 😋 😜 🤪 🤗 ' +
  '🤔 🤐 😐 😑 😶 😏 😒 🙄 😬 😔 😪 😴 😷 🤒 🤕 🥳 😎 🤓 🧐 😕 ' +
  '😟 🙁 😮 😯 😲 😳 🥺 😦 😧 😨 😰 😥 😢 😭 😱 😖 😣 😞 😓 😩 ' +
  '👍 👎 👌 ✌️ 🤞 🤝 🙏 💪 👏 🙌 👋 ✋ 🤚 ☝️ 👆 👇 👉 👈 ✍️ 💅 ' +
  '❤️ 🧡 💛 💚 💙 💜 🖤 🤍 💔 💯 🔥 ⭐ ✨ 🎉 🎊 🎁 🏆 ✅ ❌ ⚠️'
).split(' ');

const addEmoji = e => {
  draft.value += e;
};

const templates = computed(() => {
  const ib = (inboxesList.value || []).find(
    i => i.id === currentChat.value?.inbox_id
  );
  return ib?.message_templates || [];
});

const useTemplate = t => {
  const body = (t.components || []).find(c => c.type === 'BODY');
  draft.value = body?.text || t.name || '';
  showTpl.value = false;
};

const phoneOf = c => {
  const sn = c?.meta?.sender || c || {};
  return sn.phone_number || sn.identifier || '';
};

const inboxName = id =>
  (inboxesList.value || []).find(i => i.id === id)?.name || '';

/* ---------------- actions ---------------- */
const openChat = c => {
  router.push({
    name: 'inbox_conversation',
    params: { accountId: accountId.value, conversation_id: c.id },
  });
};

const goBack = () => {
  router.push({
    name: 'home',
    params: { accountId: accountId.value },
  });
};

const onRecError = () => {
  isRecording.value = false;
  recState.value = '';
  sendAfterRec.value = false;
};

const scrollDown = () => {
  nextTick(() => {
    if (threadRef.value) threadRef.value.scrollTop = threadRef.value.scrollHeight;
  });
};

/* Chatwoot ke version ke hisaab se action ka naam alag hota hai.
   Jo mojood ho wahi use karo — andaza mat lagao. */
const sendAction = () => {
  const names = Object.keys(store._actions || {});
  return (
    ['createPendingMessageAndSend', 'sendMessage', 'sendMessageWithData'].find(
      n => names.includes(n)
    ) || 'sendMessage'
  );
};

const pushMessage = payload => {
  const r = store.dispatch(sendAction(), payload);
  return r && typeof r.then === 'function' ? r : Promise.resolve(r);
};

const doSend = () => {
  const text = draft.value.trim();
  if (!text && !pendingFiles.value.length) return;
  if (!currentChat.value?.id) return;
  const payload = {
    conversationId: currentChat.value.id,
    message: text,
    private: isNote.value,
    files: pendingFiles.value.map(f => f.file),
    ccEmails: '',
    bccEmails: '',
    toEmails: '',
  };
  if (replyTo.value?.id) {
    payload.contentAttributes = { in_reply_to: replyTo.value.id };
  }
  pushMessage(payload)
    .then(() => {
      draft.value = '';
      pendingFiles.value = [];
      replyTo.value = null;
      scrollDown();
    })
    .catch(e => console.error('[ChatsSync] send fail', e));
};

const onKey = e => {
  if (e.key === 'Enter' && !e.shiftKey) {
    e.preventDefault();
    doSend();
  }
};

const pickFile = () => fileInput.value?.click();
const onFiles = e => {
  [...e.target.files].forEach(f => pendingFiles.value.push({ file: f, name: f.name }));
  e.target.value = '';
};

/* audio — Chatwoot ka apna recorder use kar rahe hain */
const audioFormat = computed(() => {
  const ib = (inboxesList.value || []).find(
    i => i.id === currentChat.value?.inbox_id
  );
  return /Whatsapp/.test(ib?.channel_type || '') ? 'audio/ogg' : 'audio/mp3';
});

const startRec = () => {
  isRecording.value = true;
  recState.value = '';
  recTime.value = '0:00';
};
const cancelRec = () => {
  sendAfterRec.value = false;
  try {
    recorderRef.value?.cancelRecording();
  } catch (e) {
    /* ignore */
  }
  // foran unmount karne se mic ka stream band nahi hota
  setTimeout(() => {
    isRecording.value = false;
    recState.value = '';
  }, 180);
};
const pauseRec = () => recorderRef.value?.pauseResumeRecording();
const finishRec = () => {
  sendAfterRec.value = true;
  recorderRef.value?.stopRecording();
};
const onRecProgress = t => {
  recTime.value = String(t).replace(/^0(\d:)/, '$1');
};
const onRecDone = file => {
  if (!file) return;
  if (sendAfterRec.value) {
    sendAfterRec.value = false;
    isRecording.value = false;
    recState.value = '';
    pushMessage({
      conversationId: currentChat.value.id,
      message: '',
      private: false,
      files: [file.file],
      ccEmails: '',
      bccEmails: '',
      toEmails: '',
    })
      .then(scrollDown)
      .catch(e => console.error('[ChatsSync] voice fail', e));
  }
};

/* right-click */
const sub = ref('');
const openMenu = (e, c) => {
  e.preventDefault();
  sub.value = '';
  const H = 470; // menu ki taqreeban unchai
  const y = Math.max(8, Math.min(e.clientY, window.innerHeight - H - 8));
  menu.value = {
    open: true,
    x: Math.max(8, Math.min(e.clientX, window.innerWidth - 244)),
    y,
    chat: c,
    up: false,
  };
};
const closeMenu = () => {
  menu.value.open = false;
  mmenu.value.open = false;
  sub.value = '';
};

/* menu render hone ke baad asli naap le kar screen ke andar khinch lo */
const menuRef = ref(null);
const fitMenu = el => {
  if (!el) return;
  nextTick(() => {
    const r = el.getBoundingClientRect();
    const pad = 8;
    let t = r.top;
    let l = r.left;
    if (r.bottom > window.innerHeight - pad)
      t = Math.max(pad, window.innerHeight - r.height - pad);
    if (r.right > window.innerWidth - pad)
      l = Math.max(pad, window.innerWidth - r.width - pad);
    el.style.top = t + 'px';
    el.style.left = l + 'px';
  });
};

const convApi = (cid, path) => {
  const base = `/api/v1/accounts/${accountId.value}/conversations/${cid}`;
  return fetch(`${base}/${path}`, {
    method: 'POST',
    credentials: 'same-origin',
    headers: {
      'Content-Type': 'application/json',
      api_access_token: currentUser.value?.access_token || '',
    },
  });
};

const act = (name, arg) => {
  const c = menu.value.chat;
  if (!c) return;
  closeMenu();
  const d = (a, p) => store.dispatch(a, p)?.catch?.(() => {});

  if (name === 'unread') d('markMessagesUnread', { id: c.id });
  else if (name === 'resolved')
    d('toggleStatus', { conversationId: c.id, status: 'resolved' });
  else if (name === 'pending')
    d('toggleStatus', { conversationId: c.id, status: 'pending' });
  else if (name === 'open')
    d('toggleStatus', { conversationId: c.id, status: 'open' });
  else if (name === 'priority')
    d('assignPriority', { conversationId: c.id, priority: arg });
  else if (name === 'mute') {
    muted.value = { ...muted.value, [c.id]: !muted.value[c.id] };
    saveLS('mute', muted.value);
    d(muted.value[c.id] ? 'muteConversation' : 'unmuteConversation', c.id);
  } else if (name === 'pin') {
    pinned.value = { ...pinned.value, [c.id]: !pinned.value[c.id] };
    saveLS('pin', pinned.value);
    convApi(c.id, pinned.value[c.id] ? 'pin' : 'unpin').catch(() => {});
  } else if (name === 'archive') {
    archived.value = { ...archived.value, [c.id]: !archived.value[c.id] };
    saveLS('arch', archived.value);
    convApi(c.id, archived.value[c.id] ? 'archive' : 'unarchive').catch(
      () => {}
    );
  } else if (name === 'copy') {
    copyText(
      `${window.location.origin}/app/accounts/${accountId.value}/conversations/${c.id}`
    );
  } else if (name === 'block') {
    d('contacts/update', {
      id: c.meta?.sender?.id,
      blocked: !c.meta?.sender?.blocked,
    });
  } else if (name === 'delete') d('deleteConversation', c.id);
};

const copyText = t => {
  if (!t) return;
  if (navigator.clipboard?.writeText) {
    navigator.clipboard.writeText(t).catch(() => fallbackCopy(t));
  } else {
    fallbackCopy(t);
  }
};
const fallbackCopy = t => {
  const ta = document.createElement('textarea');
  ta.value = t;
  ta.style.position = 'fixed';
  ta.style.opacity = '0';
  document.body.appendChild(ta);
  ta.select();
  try {
    document.execCommand('copy');
  } catch (e) {
    /* ignore */
  }
  document.body.removeChild(ta);
};

const mmenu = ref({ open: false, x: 0, y: 0, msg: null });
const openMsgMenu = (e, m) => {
  e.preventDefault();
  e.stopPropagation();
  mmenu.value = {
    open: true,
    x: Math.max(8, Math.min(e.clientX, window.innerWidth - 224)),
    y: Math.max(8, Math.min(e.clientY, window.innerHeight - 300)),
    msg: m,
  };
};
const msgAct = name => {
  const m = mmenu.value.msg;
  mmenu.value.open = false;
  if (!m) return;
  if (name === 'copy') copyText(plain(m.content || ''));
  else if (name === 'forward') {
    fwdMsg.value = m;
    fwdPick.value = [];
  }
  else if (name === 'reply') {
    replyTo.value = m;
  } else if (name === 'info') {
    infoMsg.value = m;
  } else if (name === 'note') {
    isNote.value = true;
    draft.value = plain(m.content || '');
  } else if (name === 'delete') {
    store
      .dispatch('deleteMessage', {
        conversationId: currentChat.value.id,
        messageId: m.id,
      })
      ?.catch?.(() => {});
  }
};

const act2 = name => {
  menu.value.chat = currentChat.value;
  menu.value.open = true;
  act(name);
};

const doForward = () => {
  const m = fwdMsg.value;
  if (!m || !fwdPick.value.length) return;
  const body = plain(m.content || '');
  fwdPick.value.forEach(cid => {
    pushMessage({
      conversationId: cid,
      message: body,
      private: false,
      files: [],
      ccEmails: '',
      bccEmails: '',
      toEmails: '',
    });
  });
  fwdMsg.value = null;
  fwdPick.value = [];
};

const toggleFwd = id => {
  const i = fwdPick.value.indexOf(id);
  if (i >= 0) fwdPick.value.splice(i, 1);
  else fwdPick.value.push(id);
};

const archivedCount = computed(
  () => Object.values(archived.value).filter(Boolean).length
);

/* ---------------- lifecycle ---------------- */
onMounted(() => {
  store.dispatch('inboxes/get');
  store.dispatch('setActiveInbox', props.inboxId || null);
  store.dispatch('updateChatListFilters', {
    inboxId: props.inboxId || undefined,
    assigneeType: 'all',
    status: 'all',
    page: 1,
  });
  store.dispatch('setChatStatusFilter', 'all');
  store.dispatch('fetchAllConversations');
  document.addEventListener('click', closeMenu);

  const onResize = () => {
    isMobile.value = window.innerWidth <= 768;
  };
  window.addEventListener('resize', onResize);

  /* Chatwoot ka dark class kahin bhi ho sakta hai — DOM se poochho */
  const readTheme = () => {
    isLight.value = !(
      document.documentElement.classList.contains('dark') ||
      document.body.classList.contains('dark') ||
      !!document.querySelector('.dark')
    );
  };
  readTheme();
  const mo = new MutationObserver(readTheme);
  mo.observe(document.documentElement, {
    attributes: true,
    attributeFilter: ['class'],
    subtree: true,
  });
});

watch(
  () => props.conversationId,
  id => {
    if (!id) {
      store.dispatch('clearSelectedState');
      return;
    }
    const c = (allChats.value || []).find(x => x.id === Number(id));
    if (c && c.id !== currentChat.value?.id) {
      store.dispatch('setActiveChat', { data: c }).then(() => {
        emitter.emit(BUS_EVENTS.SCROLL_TO_MESSAGE, {});
        scrollDown();
      });
    } else if (!c) {
      store.dispatch('getConversation', id);
    }
  },
  { immediate: true }
);

watch(
  () => allChats.value?.length,
  () => {
    const id = Number(props.conversationId);
    if (!id) return;
    const c = (allChats.value || []).find(x => x.id === id);
    if (c && c.id !== currentChat.value?.id) {
      store.dispatch('setActiveChat', { data: c }).then(scrollDown);
    }
  }
);

watch(() => messages.value.length, scrollDown);
</script>

<template>
  <section class="cs-app" :class="{ mob: isMobile, lite: isLight, thr: !!conversationId }">
    <!-- ============ LEFT: CHATS PANEL ============ -->
    <div class="cs-panel">
      <div class="cs-ph">
        <h1>Chats</h1>
      </div>

      <div class="cs-psr" :class="{ act: q }">
        <span class="i-lucide-search" />
        <input v-model="q" placeholder="Search chats, contacts or messages" />
        <span v-if="q" class="cs-clr i-lucide-x" @click="q = ''" />
      </div>

      <div class="cs-pills">
        <div
          v-for="p in pills"
          :key="p.k"
          class="cs-pl"
          :class="{ on: filt === p.k }"
          @click="filt = p.k"
        >
          <span>{{ p.n }}</span>
          <span v-if="p.c" class="cs-plc">{{ p.c }}</span>
        </div>
      </div>

      <div class="cs-list">
        <div
          v-if="!q"
          class="cs-arch"
          :class="{ on: showArchived }"
          @click="showArchived = !showArchived"
        >
          <span :class="showArchived ? 'i-lucide-arrow-left' : 'i-lucide-archive'" />
          <span class="cs-arch-t">{{ showArchived ? 'Back to chats' : 'Archived' }}</span>
          <span class="cs-arch-c">{{ archivedCount }}</span>
        </div>

        <div
          v-for="c in rows"
          :key="c.id"
          class="cs-row"
          :class="{
            on: Number(conversationId) === c.id,
            unrd: (c.unread_count || 0) > 0,
          }"
          @click="openChat(c)"
          @contextmenu="openMenu($event, c)"
        >
          <div class="cs-av" :style="{ background: colorFor(c.id) }">
            <img v-if="c.meta?.sender?.thumbnail" :src="c.meta.sender.thumbnail" />
            <template v-else>{{ initials(c.meta?.sender?.name) }}</template>
          </div>
          <div class="cs-rb">
            <div class="cs-r1">
              <span class="cs-n">{{ c.meta?.sender?.name || 'Unknown' }}</span>
              <span v-if="inboxName(c.inbox_id)" class="cs-ib">
                {{ inboxName(c.inbox_id) }}
              </span>
              <span class="cs-t">{{ listTime(c.timestamp) }}</span>
            </div>
            <div v-if="phoneOf(c)" class="cs-rph">{{ phoneOf(c) }}</div>

            <div class="cs-r2">
              <span v-if="isOut(c)" class="cs-tick i-lucide-check-check" />
              <span
                v-else-if="chipFor(c.inbox_id)"
                class="cs-chip"
                :class="'cs-chip--' + chipFor(c.inbox_id).c"
              >
                {{ chipFor(c.inbox_id).t }}
              </span>
              <span class="cs-m">{{ previewOf(c) }}</span>
              <span v-if="muted[c.id]" class="cs-mk i-lucide-bell-off" />
              <span v-if="pinned[c.id]" class="cs-mk i-lucide-pin" />
              <span v-if="(c.unread_count || 0) > 0" class="cs-un">
                {{ c.unread_count }}
              </span>
            </div>
          </div>
        </div>

        <div v-if="!rows.length && !listLoading" class="cs-empty-list">
          No chats, contacts or messages found
        </div>
      </div>
    </div>

    <!-- ============ RIGHT: THREAD ============ -->
    <div v-if="currentChat && currentChat.id" class="cs-main">
      <div class="cs-th">
        <span v-if="isMobile" class="cs-ic i-lucide-arrow-left" @click="goBack" />
        <div
          class="cs-tav"
          :style="{ background: colorFor(currentChat.id) }"
          @click="showProfile = true"
        >
          <img v-if="contact.thumbnail" :src="contact.thumbnail" />
          <template v-else>{{ initials(contact.name) }}</template>
        </div>
        <div class="cs-tnm" @click="showProfile = true">
          <div class="cs-tn">{{ contact.name || 'Unknown' }}</div>
          <div class="cs-ts">
            <span v-if="phoneOf(contact)" class="cs-tph">
              {{ phoneOf(contact) }}
            </span>
            <span v-if="phoneOf(contact) && inboxName(currentChat.inbox_id)">
              ·
            </span>
            <span>{{ inboxName(currentChat.inbox_id) }}</span>
          </div>
        </div>
      </div>

      <div ref="threadRef" class="cs-thread">
        <template v-for="b in blocks" :key="b.id">
          <div v-if="b.kind === 'day'" class="cs-day">{{ b.text }}</div>
          <div v-else-if="b.kind === 'sys'" class="cs-sysm">{{ b.text }}</div>
          <div
            v-else
            class="cs-msg"
            :class="[
              b.m.message_type === 1 ? 'out' : 'in',
              { pv: b.m.private, f1: b.first, grp: !b.first },
            ]"
          >
            <div class="cs-bub" @contextmenu="openMsgMenu($event, b.m)">
              <div v-if="b.first && b.m.message_type === 1" class="cs-snd">
                {{ b.m.sender?.name || 'You' }}
              </div>

              <template v-if="b.m.attachments && b.m.attachments.length">
                <template v-for="a in b.m.attachments" :key="a.id">
                  <img
                    v-if="aType(a) === 'image' && aUrl(a)"
                    :src="aUrl(a)"
                    class="cs-img"
                  />
                  <AudioChip
                    v-else-if="aType(a) === 'audio' && aUrl(a)"
                    :attachment="attach(a)"
                    :show-transcribed-text="false"
                    class="cs-aud"
                  />
                  <video
                    v-else-if="aType(a) === 'video' && aUrl(a)"
                    :src="aUrl(a)"
                    controls
                    class="cs-img"
                  />
                  <a
                    v-else-if="aUrl(a)"
                    :href="aUrl(a)"
                    target="_blank"
                    class="cs-file"
                  >
                    <span class="i-lucide-file" />
                    {{ a.file_name || a.fileName || 'Document' }}
                  </a>
                </template>
              </template>

              <div v-if="b.m.content" class="cs-tx" v-html="bodyHtml(b.m)" />

              <div class="cs-mt">
                <span>{{ clock(b.m.created_at) }}</span>
                <span
                  v-if="b.m.message_type === 1"
                  class="cs-tick i-lucide-check-check"
                />
              </div>
            </div>
          </div>
        </template>
      </div>

      <div class="cs-comp">
        <template v-if="isRecording">
          <!-- waveform poori chaudai ki apni patti mein — yahi shakl
               pehle chal rahi thi. Bar ke andar dalne se WaveSurfer
               ko container ki chaudai/height nahi milti thi. -->
          <div class="cs-recstrip">
            <AudioRecorder
              ref="recorderRef"
              :audio-record-format="audioFormat"
              @recorder-progress-changed="onRecProgress"
              @finish-record="onRecDone"
              @record-pause="recState = 'recording-paused'"
              @record-resume="recState = ''"
              @record-cancel="onRecError"
              @record-error="onRecError"
            />
          </div>
          <div class="cs-cbar">
            <span class="cs-ci i-lucide-trash-2" @click="cancelRec" />
            <span
              class="cs-dot"
              :class="{ pz: recState === 'recording-paused' }"
            />
            <span class="cs-rt">{{ recTime }}</span>
            <span class="cs-sp" />
            <span
              class="cs-ci"
              :class="
                recState === 'recording-paused'
                  ? 'i-lucide-mic'
                  : 'i-lucide-pause'
              "
              @click="pauseRec"
            />
            <span class="cs-snd2 i-lucide-send" @click="finishRec" />
          </div>
        </template>

        <div v-if="!isRecording" class="cs-tabs">
          <button
            class="cs-tab"
            :class="{ on: !isNote }"
            @click="isNote = false"
          >
            Reply
          </button>
          <button class="cs-tab" :class="{ on: isNote }" @click="isNote = true">
            Private note
          </button>
        </div>

        <div v-if="showEmoji && !isRecording" class="cs-emoji">
          <span
            v-for="(e, i) in EMOJIS"
            :key="i"
            class="cs-em"
            @click="addEmoji(e)"
          >
            {{ e }}
          </span>
        </div>

        <div v-if="showTpl && !isRecording" class="cs-tplbox">
          <div v-if="!templates.length" class="cs-tplempty">
            Is inbox mein koi template nahi
          </div>
          <div
            v-for="t in templates"
            :key="t.id || t.name"
            class="cs-tpl"
            @click="useTemplate(t)"
          >
            <div class="cs-tpln">{{ t.name }}</div>
            <div class="cs-tplt">
              {{
                (t.components || []).find(c => c.type === 'BODY')?.text || ''
              }}
            </div>
          </div>
        </div>

        <div v-if="replyTo && !isRecording" class="cs-rp">
          <div class="cs-rpbar" />
          <div class="cs-rpb">
            <div class="cs-rpn">
              {{
                replyTo.message_type === 1
                  ? replyTo.sender?.name || 'You'
                  : contact.name || 'Customer'
              }}
            </div>
            <div class="cs-rpt">
              {{ plain(replyTo.content || '') || 'Attachment' }}
            </div>
          </div>
          <span class="cs-ci i-lucide-x" @click="replyTo = null" />
        </div>

        <div
          v-if="!isRecording"
          class="cs-cbar"
          :class="{ note: isNote }"
        >
          <span class="cs-ci i-lucide-paperclip" @click="pickFile" />
          <span
            class="cs-ci i-lucide-smile"
            :class="{ act: showEmoji }"
            @click="
              showEmoji = !showEmoji;
              showTpl = false;
            "
          />
          <span
            class="cs-ci i-lucide-layout-template"
            :class="{ act: showTpl }"
            @click="
              showTpl = !showTpl;
              showEmoji = false;
            "
          />
          <input
            ref="fileInput"
            type="file"
            multiple
            hidden
            @change="onFiles"
          />
          <textarea
            v-model="draft"
            class="cs-cin"
            rows="1"
            :placeholder="isNote ? 'Private note...' : 'Type a message'"
            @keydown="onKey"
          />
          <span
            v-if="!draft.trim() && !pendingFiles.length"
            class="cs-ci i-lucide-mic"
            @click="startRec"
          />
          <span v-else class="cs-snd2 i-lucide-send" @click="doSend" />
        </div>

        <div v-if="pendingFiles.length" class="cs-files">
          <span v-for="(f, i) in pendingFiles" :key="i" class="cs-fchip">
            {{ f.name }}
            <span class="i-lucide-x" @click="pendingFiles.splice(i, 1)" />
          </span>
        </div>
      </div>
    </div>

    <div v-else class="cs-none">
      <div>
        <div class="cs-none-t">ChatsSync</div>
        <div class="cs-none-s">Select a chat to start messaging</div>
      </div>
    </div>

    <!-- ============ MESSAGE INFO ============ -->
    <div v-if="infoMsg" class="cs-fw" @click.self="infoMsg = null">
      <div class="cs-fwb cs-inf">
        <div class="cs-fwh">
          <span class="cs-ic i-lucide-x" @click="infoMsg = null" />
          <span>Message info</span>
        </div>
        <div class="cs-infp">
          {{ plain(infoMsg.content || '') || 'Attachment' }}
        </div>
        <div class="cs-infl">
          <div class="cs-pfr">
            <span class="cs-pfk">Sent</span>
            <span class="cs-pfv">
              {{ dayLabel(infoMsg.created_at) }} · {{ clock(infoMsg.created_at) }}
            </span>
          </div>
          <div class="cs-pfr">
            <span class="cs-pfk">Status</span>
            <span class="cs-pfv cap">{{ infoMsg.status || 'sent' }}</span>
          </div>
          <div class="cs-pfr">
            <span class="cs-pfk">Direction</span>
            <span class="cs-pfv">
              {{ infoMsg.message_type === 1 ? 'Outgoing' : 'Incoming' }}
            </span>
          </div>
          <div class="cs-pfr" v-if="infoMsg.sender?.name">
            <span class="cs-pfk">Sent by</span>
            <span class="cs-pfv">{{ infoMsg.sender.name }}</span>
          </div>
          <div class="cs-pfr">
            <span class="cs-pfk">Channel</span>
            <span class="cs-pfv">
              {{ inboxName(currentChat.inbox_id) || '—' }}
            </span>
          </div>
          <div class="cs-pfr" v-if="infoMsg.private">
            <span class="cs-pfk">Type</span>
            <span class="cs-pfv">Private note</span>
          </div>
          <div class="cs-pfr" v-if="(infoMsg.attachments || []).length">
            <span class="cs-pfk">Attachment</span>
            <span class="cs-pfv cap">
              {{ aType(infoMsg.attachments[0]) }}
            </span>
          </div>
          <div class="cs-pfr">
            <span class="cs-pfk">Message ID</span>
            <span class="cs-pfv">{{ infoMsg.id }}</span>
          </div>
          <div class="cs-pfr" v-if="infoMsg.source_id">
            <span class="cs-pfk">WhatsApp ID</span>
            <span class="cs-pfv">{{ infoMsg.source_id }}</span>
          </div>
          <div
            class="cs-pfr"
            v-if="infoMsg.content_attributes?.external_error"
          >
            <span class="cs-pfk err">Error</span>
            <span class="cs-pfv err">
              {{ infoMsg.content_attributes.external_error }}
            </span>
          </div>
        </div>
        <div class="cs-fwf">
          <span class="cs-fwc">Delete sirf tumhare dashboard se hataata hai</span>
          <button class="cs-fwbtn" @click="copyText(plain(infoMsg.content || ''))">
            Copy
          </button>
        </div>
      </div>
    </div>

    <!-- ============ FORWARD ============ -->
    <div v-if="fwdMsg" class="cs-fw" @click.self="fwdMsg = null">
      <div class="cs-fwb">
        <div class="cs-fwh">
          <span class="cs-ic i-lucide-x" @click="fwdMsg = null" />
          <span>Forward message to</span>
        </div>
        <div class="cs-fwp">{{ plain(fwdMsg.content || '') || 'Attachment' }}</div>
        <div class="cs-fwl">
          <div
            v-for="c in rows"
            :key="c.id"
            class="cs-fwr"
            :class="{ on: fwdPick.includes(c.id) }"
            @click="toggleFwd(c.id)"
          >
            <div class="cs-fwav" :style="{ background: colorFor(c.id) }">
              {{ initials(c.meta?.sender?.name) }}
            </div>
            <span class="cs-fwn">{{ c.meta?.sender?.name || 'Unknown' }}</span>
            <span
              class="cs-fwck"
              :class="
                fwdPick.includes(c.id) ? 'i-lucide-check-circle-2' : 'i-lucide-circle'
              "
            />
          </div>
        </div>
        <div class="cs-fwf">
          <span class="cs-fwc">{{ fwdPick.length }} selected</span>
          <button class="cs-fwbtn" :disabled="!fwdPick.length" @click="doForward">
            Send
          </button>
        </div>
      </div>
    </div>

    <!-- ============ CONTACT PROFILE ============ -->
    <div v-if="showProfile" class="cs-pf" @click.self="showProfile = false">
      <div class="cs-pfp">
        <div class="cs-pfh">
          <span class="cs-ic i-lucide-x" @click="showProfile = false" />
          <span>Contact info</span>
        </div>
        <div class="cs-pfb">
          <div
            class="cs-pfav"
            :style="{ background: colorFor(currentChat.id) }"
          >
            <img v-if="contact.thumbnail" :src="contact.thumbnail" />
            <template v-else>{{ initials(contact.name) }}</template>
          </div>
          <div class="cs-pfn">{{ contact.name || 'Unknown' }}</div>
          <div class="cs-pfs">{{ contact.phone_number || '' }}</div>
        </div>
        <div class="cs-pfr" v-if="contact.email">
          <span class="cs-pfk">Email</span>
          <span class="cs-pfv">{{ contact.email }}</span>
        </div>
        <div class="cs-pfr" v-if="contact.identifier">
          <span class="cs-pfk">Identifier</span>
          <span class="cs-pfv">{{ contact.identifier }}</span>
        </div>
        <div class="cs-pfr">
          <span class="cs-pfk">Channel</span>
          <span class="cs-pfv">
            {{
              (inboxesList || []).find(i => i.id === currentChat.inbox_id)
                ?.name || '—'
            }}
          </span>
        </div>
        <div class="cs-pfr" v-if="contact.company_name">
          <span class="cs-pfk">Company</span>
          <span class="cs-pfv">{{ contact.company_name }}</span>
        </div>
        <div class="cs-pfr" v-if="contact.location">
          <span class="cs-pfk">Location</span>
          <span class="cs-pfv">{{ contact.location }}</span>
        </div>
        <div class="cs-pfr">
          <span class="cs-pfk">Conversation</span>
          <span class="cs-pfv">#{{ currentChat.id }}</span>
        </div>
        <div class="cs-pfr">
          <span class="cs-pfk">Status</span>
          <span class="cs-pfv cap">{{ currentChat.status || '—' }}</span>
        </div>
        <div class="cs-pfr" v-if="currentChat.priority">
          <span class="cs-pfk">Priority</span>
          <span class="cs-pfv cap">{{ currentChat.priority }}</span>
        </div>
        <div class="cs-pfr">
          <span class="cs-pfk">Assigned to</span>
          <span class="cs-pfv">
            {{ currentChat.meta?.assignee?.name || 'Unassigned' }}
          </span>
        </div>
        <div class="cs-pfr" v-if="currentChat.meta?.team?.name">
          <span class="cs-pfk">Team</span>
          <span class="cs-pfv">{{ currentChat.meta.team.name }}</span>
        </div>
        <div class="cs-pfr" v-if="(currentChat.labels || []).length">
          <span class="cs-pfk">Labels</span>
          <span class="cs-pfv">{{ (currentChat.labels || []).join(', ') }}</span>
        </div>
        <div class="cs-pfr">
          <span class="cs-pfk">Messages</span>
          <span class="cs-pfv">{{ messages.length }}</span>
        </div>
        <div class="cs-pfr" v-if="currentChat.created_at">
          <span class="cs-pfk">First contact</span>
          <span class="cs-pfv">
            {{ dayLabel(currentChat.created_at) }} · {{ clock(currentChat.created_at) }}
          </span>
        </div>
        <div class="cs-pfr" v-if="contact.created_at">
          <span class="cs-pfk">Contact since</span>
          <span class="cs-pfv">{{ dayLabel(contact.created_at) }}</span>
        </div>
        <div
          class="cs-pfr"
          v-for="(v, k) in contact.custom_attributes || {}"
          :key="k"
        >
          <span class="cs-pfk">{{ k }}</span>
          <span class="cs-pfv">{{ v }}</span>
        </div>
        <div class="cs-pfacts">
          <div class="cs-pfab" @click="act2('mute')">
            <span :class="muted[currentChat.id] ? 'i-lucide-bell' : 'i-lucide-bell-off'" />
            <span>{{ muted[currentChat.id] ? 'Unmute' : 'Mute' }}</span>
          </div>
          <div class="cs-pfab" @click="act2('pin')">
            <span class="i-lucide-pin" />
            <span>{{ pinned[currentChat.id] ? 'Unpin' : 'Pin' }}</span>
          </div>
          <div class="cs-pfab" @click="act2('archive')">
            <span class="i-lucide-archive" />
            <span>{{ archived[currentChat.id] ? 'Unarchive' : 'Archive' }}</span>
          </div>
        </div>
      </div>
    </div>

    <!-- ============ MESSAGE MENU ============ -->
    <div
      v-if="mmenu.open"
      class="cs-cmenu"
      :style="{ left: mmenu.x + 'px', top: mmenu.y + 'px' }"
      @click.stop
    >
      <div class="cs-mi" @click="msgAct('reply')">
        <span class="i-lucide-reply" /><span>Reply</span>
      </div>
      <div class="cs-mi" @click="msgAct('copy')">
        <span class="i-lucide-copy" /><span>Copy</span>
      </div>
      <div class="cs-mi" @click="msgAct('forward')">
        <span class="i-lucide-forward" /><span>Forward</span>
      </div>
      <div class="cs-mi" @click="msgAct('note')">
        <span class="i-lucide-sticky-note" /><span>Add to private note</span>
      </div>
      <div class="cs-mi" @click="msgAct('info')">
        <span class="i-lucide-info" /><span>Message info</span>
      </div>
      <hr />
      <div class="cs-mi danger" @click="msgAct('delete')">
        <span class="i-lucide-trash-2" /><span>Delete for me</span>
      </div>
    </div>

    <!-- ============ RIGHT-CLICK MENU ============ -->
    <div
      v-if="menu.open"
      :ref="fitMenu"
      class="cs-cmenu"
      :style="{ left: menu.x + 'px', top: menu.y + 'px' }"
      @click.stop
    >
      <div class="cs-mi" @click="act('pin')">
        <span class="i-lucide-pin" />
        <span>{{ pinned[menu.chat?.id] ? 'Unpin chat' : 'Pin chat' }}</span>
      </div>
      <div class="cs-mi" @click="act('mute')">
        <span class="i-lucide-bell-off" />
        <span>
          {{ muted[menu.chat?.id] ? 'Unmute notifications' : 'Mute notifications' }}
        </span>
      </div>
      <div class="cs-mi" @click="act('archive')">
        <span class="i-lucide-archive" />
        <span>
          {{ archived[menu.chat?.id] ? 'Unarchive chat' : 'Archive chat' }}
        </span>
      </div>
      <div class="cs-mi" @click="act('unread')">
        <span class="i-lucide-mail" /><span>Mark as unread</span>
      </div>
      <hr />
      <div class="cs-mi" @click="act('resolved')">
        <span class="i-lucide-check" /><span>Mark as resolved</span>
      </div>
      <div class="cs-mi" @click="act('pending')">
        <span class="i-lucide-clock" /><span>Mark as pending</span>
      </div>
      <div class="cs-mi" @click="act('open')">
        <span class="i-lucide-rotate-ccw" /><span>Reopen</span>
      </div>
      <hr />
      <div
        class="cs-mi cs-has-sub"
        @click.stop="sub = sub === 'pri' ? '' : 'pri'"
      >
        <span class="i-lucide-flag" /><span>Priority</span>
        <span class="cs-arw i-lucide-chevron-right" />
        <div v-if="sub === 'pri'" class="cs-sub">
          <div
            v-for="p in ['urgent', 'high', 'medium', 'low', 'none']"
            :key="p"
            class="cs-mi"
            @click.stop="act('priority', p === 'none' ? null : p)"
          >
            <span>{{ p }}</span>
          </div>
        </div>
      </div>
      <hr />
      <div class="cs-mi" @click="act('copy')">
        <span class="i-lucide-link" /><span>Copy conversation link</span>
      </div>
      <div class="cs-mi danger" @click="act('block')">
        <span class="i-lucide-ban" /><span>Block contact</span>
      </div>
      <div class="cs-mi danger" @click="act('delete')">
        <span class="i-lucide-trash-2" /><span>Delete conversation</span>
      </div>
    </div>
  </section>
</template>

<style scoped>
/* ===== tokens (index.html se) ===== */
.cs-app {
  --rail: #202c33;
  --panel: #111b21;
  --head: #202c33;
  --fld: #202c33;
  --tx: #e9edef;
  --tx2: #aebac1;
  --tx3: #8696a0;
  --ln: #222e35;
  --ln2: #1d282f;
  --hov: #202c33;
  --sel: #2a3942;
  --g: #00a884;
  --g-tint: #103529;
  --b: #53bdeb;
  --menu: #233138;
  --menu-hov: #182229;
  --sent: #005c4b;
  --recv: #202c33;
  --note: #3b3117;
  --note-b: #5a4a20;
  --chat: #0b141a;
  --badge: #00a884;
  --badge-tx: #0b141a;
  --sh: 0 1px 0.5px rgba(0, 0, 0, 0.35);
  --red: #f15c6d;

  display: flex;
  width: 100%;
  height: 100%;
  min-width: 0;
  font-size: 14px;
  color: var(--tx);
}

/* ===== LIGHT THEME ===== */
.cs-app.lite {
  --panel: #ffffff;
  --head: #f0f2f5;
  --fld: #f0f2f5;
  --tx: #111b21;
  --tx2: #54656f;
  --tx3: #667781;
  --ln: #e4e7e9;
  --ln2: #eef1f2;
  --hov: #f5f6f6;
  --sel: #f0f2f5;
  --g: #008069;
  --g-tint: #dcefe9;
  --b: #2f7fd1;
  --menu: #ffffff;
  --menu-hov: #f0f2f5;
  --sent: #d9fdd3;
  --recv: #ffffff;
  --note: #fff6d6;
  --note-b: #e6d79a;
  --chat: #e3ded7;
  --badge: #25d366;
  --badge-tx: #053e20;
  --sh: 0 1px 0.5px rgba(11, 20, 26, 0.13);
  --red: #d63c4b;
}
.cs-app.lite .cs-thread {
  background-image: url('data:image/svg+xml,%3Csvg%20xmlns%3D%27http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%27%20width%3D%27352%27%20height%3D%27232%27%20viewBox%3D%270%200%20352%20232%27%3E%3Cg%20fill%3D%27none%27%20stroke%3D%27%230b141a%27%20stroke-opacity%3D%27.07%27%20stroke-width%3D%271.25%27%20stroke-linecap%3D%27round%27%20stroke-linejoin%3D%27round%27%3E%3Cg%20transform%3D%27translate%2818%2C20%29%27%3E%3Cpath%20d%3D%27M0%206a6%206%200%200%201%2012%200%206%206%200%200%201-6%206H2l2-3a6%206%200%200%201-4-3z%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%2862%2C14%29%27%3E%3Cpath%20d%3D%27M0%200h14v10H4L0%2013z%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28108%2C22%29%27%3E%3Cpath%20d%3D%27M6%200l1.8%203.7%204%20.6-2.9%202.8.7%204L6%209.2%202.4%2011l.7-4L.2%204.3l4-.6z%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28150%2C16%29%27%3E%3Cpath%20d%3D%27M2%202h12v12H2z%20M2%206h12%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28192%2C20%29%27%3E%3Cpath%20d%3D%27M7%200C3%200%200%203%200%206.5%200%2011%207%2016%207%2016s7-5%207-9.5C14%203%2011%200%207%200z%20M7%204a2.5%202.5%200%201%201%200%205%202.5%202.5%200%200%201%200-5z%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28234%2C14%29%27%3E%3Cpath%20d%3D%27M0%208c0-4%203-7%207-7s7%203%207%207-3%207-7%207-7-3-7-7z%20M4%208h6%20M7%205v6%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28276%2C20%29%27%3E%3Cpath%20d%3D%27M0%203h16v10H0z%20M0%203l8%206%208-6%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28318%2C16%29%27%3E%3Cpath%20d%3D%27M3%200h10v4H3z%20M1%204h14v11H1z%20M6%208h4%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%2814%2C64%29%27%3E%3Cpath%20d%3D%27M0%2010c3-5%209-5%2012%200%20M6%204a2.5%202.5%200%201%201%200%20.01%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%2856%2C58%29%27%3E%3Cpath%20d%3D%27M0%200h13M0%205h9M0%2010h11%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%2898%2C62%29%27%3E%3Cpath%20d%3D%27M8%200a8%208%200%201%201%200%2016A8%208%200%200%201%208%200z%20M8%204v4.5l3%202%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28140%2C60%29%27%3E%3Cpath%20d%3D%27M0%200l11%206-11%206z%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28182%2C58%29%27%3E%3Cpath%20d%3D%27M2%200h11l3%204v11H2z%20M13%200v4h3%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28224%2C62%29%27%3E%3Cpath%20d%3D%27M0%206h4l4-5v14l-4-5H0z%20M11%204a4%204%200%200%201%200%208%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28266%2C58%29%27%3E%3Cpath%20d%3D%27M1%201h14v10H1z%20M1%2011l5-4%203%202%203-3%203%203%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28308%2C64%29%27%3E%3Cpath%20d%3D%27M6%200a6%206%200%200%201%206%206c0%204-6%2010-6%2010S0%2010%200%206a6%206%200%200%201%206-6z%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%2820%2C106%29%27%3E%3Cpath%20d%3D%27M0%204h5l3-4h4l3%204h1v10H0z%20M8%206a3%203%200%201%201%200%206%203%203%200%200%201%200-6z%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%2862%2C110%29%27%3E%3Cpath%20d%3D%27M6%200l6%2012H0z%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28104%2C104%29%27%3E%3Cpath%20d%3D%27M0%200h12v12H0z%20M3%203h6v6H3z%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28146%2C108%29%27%3E%3Cpath%20d%3D%27M0%206a6%206%200%201%200%2012%200%206%206%200%200%200-12%200z%20M3%206l2%202%204-4%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28188%2C104%29%27%3E%3Cpath%20d%3D%27M1%203h14v9H1z%20M4%203V1h8v2%20M4%2012v2h8v-2%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28230%2C110%29%27%3E%3Cpath%20d%3D%27M0%2012L6%200l6%2012z%20M4%2012v3h4v-3%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28272%2C106%29%27%3E%3Cpath%20d%3D%27M2%202l10%2010M12%202L2%2012%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28314%2C110%29%27%3E%3Cpath%20d%3D%27M0%208h16%20M4%204l-4%204%204%204%20M12%204l4%204-4%204%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%2816%2C150%29%27%3E%3Cpath%20d%3D%27M0%202h14v12H0z%20M3%200v4M11%200v4M0%206h14%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%2858%2C154%29%27%3E%3Cpath%20d%3D%27M7%200a7%207%200%201%201%200%2014A7%207%200%200%201%207%200z%20M4%207h6%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28100%2C148%29%27%3E%3Cpath%20d%3D%27M0%2010c0-6%205-10%208-10s8%204%208%2010%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28142%2C152%29%27%3E%3Cpath%20d%3D%27M2%200h10v14l-5-4-5%204z%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28184%2C150%29%27%3E%3Cpath%20d%3D%27M0%200h14v3H0z%20M2%203v10h10V3%20M6%206v4M8%206v4%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28226%2C154%29%27%3E%3Cpath%20d%3D%27M8%200l2%205%205%20.5-4%203.5%201%205-4-2.6L4%2014l1-5L1%205.5%206%205z%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28268%2C148%29%27%3E%3Cpath%20d%3D%27M1%201h13v13H1z%20M4%207h7M7%204v7%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28310%2C152%29%27%3E%3Cpath%20d%3D%27M0%205a5%205%200%200%201%2010%200v6H0z%20M3%2011v3h4v-3%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%2822%2C196%29%27%3E%3Cpath%20d%3D%27M0%203h16v9H0z%20M5%2012v2h6v-2%20M2%2016h12%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%2864%2C198%29%27%3E%3Cpath%20d%3D%27M6%200a6%206%200%201%201%200%2012A6%206%200%200%201%206%200z%20M6%203v3l2%202%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28106%2C194%29%27%3E%3Cpath%20d%3D%27M0%206h12%20M8%202l4%204-4%204%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28148%2C198%29%27%3E%3Cpath%20d%3D%27M2%200h8a2%202%200%200%201%202%202v10a2%202%200%200%201-2%202H2a2%202%200%200%201-2-2V2a2%202%200%200%201%202-2z%20M4%203h4M4%206h4M4%209h2%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28190%2C194%29%27%3E%3Cpath%20d%3D%27M0%200h14M0%205h14M0%2010h8%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28232%2C198%29%27%3E%3Cpath%20d%3D%27M7%200l7%207-7%207-7-7z%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28274%2C194%29%27%3E%3Cpath%20d%3D%27M1%204h12v9H1z%20M4%204V2a3%203%200%200%201%206%200v2%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28316%2C198%29%27%3E%3Cpath%20d%3D%27M0%200l14%207-14%207%203-7z%27%2F%3E%3C%2Fg%3E%3C%2Fg%3E%3C%2Fsvg%3E');
}

/* ===== PANEL ===== */
.cs-panel {
  width: 400px;
  background: var(--panel);
  display: flex;
  flex-direction: column;
  flex-shrink: 0;
  border-right: 1px solid var(--ln);
}
.cs-ph {
  padding: 17px 20px 12px;
  display: flex;
  align-items: center;
  gap: 8px;
  flex-shrink: 0;
}
.cs-ph h1 {
  font-size: 22px;
  font-weight: 600;
  flex: 1;
  letter-spacing: -0.02em;
  margin: 0;
  color: var(--tx);
}
.cs-psr {
  margin: 0 12px 11px;
  background: var(--fld);
  border-radius: 9px;
  padding: 0 14px;
  display: flex;
  align-items: center;
  gap: 12px;
  flex-shrink: 0;
  transition: background 0.14s;
}
.cs-psr > span {
  width: 19px;
  height: 19px;
  color: var(--tx3);
  flex-shrink: 0;
}
.cs-psr .cs-clr {
  cursor: pointer;
}
.cs-psr input {
  flex: 1;
  min-width: 0;
  background: none;
  border: none;
  outline: none;
  color: var(--tx);
  font-size: 14px;
  font-family: inherit;
  padding: 10px 0;
}
.cs-psr input::placeholder {
  color: var(--tx3);
}
.cs-pills {
  display: flex;
  gap: 8px;
  padding: 0 12px 12px;
  align-items: center;
  overflow-x: auto;
  flex-shrink: 0;
  scrollbar-width: none;
}
.cs-pills::-webkit-scrollbar {
  display: none;
}
.cs-pl {
  font-size: 13.5px;
  padding: 5px 14px;
  border-radius: 16px;
  background: var(--fld);
  color: var(--tx2);
  cursor: pointer;
  white-space: nowrap;
  user-select: none;
  display: flex;
  align-items: center;
  gap: 6px;
  flex-shrink: 0;
  transition: background 0.12s, color 0.12s;
}
.cs-pl.on {
  background: var(--g-tint);
  color: var(--g);
}
.cs-plc {
  font-weight: 600;
}

.cs-list {
  flex: 1;
  min-height: 0;
  overflow-y: auto;
  overscroll-behavior: contain;
}
.cs-row {
  display: flex;
  gap: 14px;
  padding: 11px 20px 11px 16px;
  cursor: pointer;
  align-items: center;
  position: relative;
  transition: background 0.09s ease;
}
.cs-row:hover {
  background: var(--hov);
}
.cs-row.on {
  background: var(--sel);
}
.cs-av {
  width: 49px;
  height: 49px;
  border-radius: 50%;
  display: grid;
  place-items: center;
  color: #fff;
  font-size: 15px;
  font-weight: 600;
  flex-shrink: 0;
  overflow: hidden;
  letter-spacing: -0.01em;
  box-shadow: inset 0 0 0 1px rgba(0, 0, 0, 0.05);
}
.cs-av img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.cs-rb {
  flex: 1;
  min-width: 0;
  border-bottom: 1px solid var(--ln2);
  padding-bottom: 11px;
  margin-bottom: -11px;
}
.cs-row:last-child .cs-rb {
  border-bottom: none;
}
.cs-r1 {
  display: flex;
  align-items: baseline;
  gap: 9px;
  margin-bottom: 3px;
}
.cs-n {
  font-size: 15.5px;
  flex: 1;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  letter-spacing: -0.005em;
}
.cs-row.unrd .cs-n {
  font-weight: 500;
}
.cs-t {
  font-size: 11.5px;
  color: var(--tx3);
  flex-shrink: 0;
  font-variant-numeric: tabular-nums;
}
.cs-row.unrd .cs-t {
  color: var(--g);
}
.cs-r2 {
  display: flex;
  align-items: center;
  gap: 7px;
  min-width: 0;
}
.cs-m {
  font-size: 13.5px;
  color: var(--tx3);
  flex: 1;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.cs-tick {
  color: var(--b);
  width: 15px;
  height: 15px;
  flex-shrink: 0;
}
.cs-chip {
  font-size: 9.5px;
  font-weight: 700;
  padding: 1px 5px;
  border-radius: 3px;
  flex-shrink: 0;
  line-height: 1.6;
}
.cs-chip--wa {
  background: #123a22;
  color: #7dd99b;
}
.cs-chip--fb {
  background: #12283f;
  color: #8cbef2;
}
.cs-chip--ig {
  background: #3a1526;
  color: #f09bc0;
}
.cs-un {
  background: var(--badge);
  color: var(--badge-tx);
  font-size: 11px;
  font-weight: 600;
  min-width: 20px;
  height: 20px;
  padding: 0 5px;
  border-radius: 10px;
  display: grid;
  place-items: center;
  flex-shrink: 0;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.16);
}
.cs-arch {
  display: flex;
  align-items: center;
  gap: 22px;
  padding: 13px 20px;
  cursor: pointer;
  color: var(--tx2);
}
.cs-arch:hover {
  background: var(--hov);
}
.cs-arch > span:first-child {
  width: 20px;
  height: 20px;
  flex-shrink: 0;
}
.cs-arch-t {
  flex: 1;
  font-size: 15px;
  color: var(--tx);
}
.cs-arch-c {
  font-size: 12.5px;
  color: var(--g);
  font-weight: 500;
}
.cs-has-sub {
  position: relative;
}
.cs-arw {
  width: 16px;
  height: 16px;
  margin-left: auto;
  color: var(--tx3);
}
.cs-sub {
  position: absolute;
  left: 100%;
  top: -7px;
  background: var(--menu);
  border-radius: 8px;
  box-shadow: 0 4px 22px rgba(0, 0, 0, 0.45);
  padding: 7px 0;
  min-width: 150px;
  z-index: 1;
}
.cs-sub .cs-mi {
  text-transform: capitalize;
}
.cs-empty-list {
  padding: 40px 20px;
  text-align: center;
  color: var(--tx3);
  font-size: 14px;
}

/* ===== MAIN ===== */
.cs-main {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  background: var(--chat);
}
.cs-th {
  height: 60px;
  background: var(--head);
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 0 18px;
  flex-shrink: 0;
  border-left: 1px solid var(--ln);
}
.cs-tav {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  display: grid;
  place-items: center;
  color: #fff;
  font-size: 13px;
  font-weight: 600;
  flex-shrink: 0;
  overflow: hidden;
}
.cs-tav img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.cs-tnm {
  flex: 1;
  min-width: 0;
}
.cs-tn {
  font-size: 16px;
  font-weight: 500;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.cs-ts {
  font-size: 12.5px;
  color: var(--tx3);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.cs-ic {
  width: 38px;
  height: 38px;
  border-radius: 50%;
  display: grid;
  place-items: center;
  cursor: pointer;
  color: var(--tx2);
  flex-shrink: 0;
}
.cs-ic:hover {
  background: var(--hov);
  color: var(--tx);
}

.cs-thread {
  flex: 1;
  overflow-y: auto;
  padding: 18px 6.5%;
  display: flex;
  flex-direction: column;
  gap: 3px;
  background-color: var(--chat);
  background-image: url('data:image/svg+xml,%3Csvg%20xmlns%3D%27http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%27%20width%3D%27352%27%20height%3D%27232%27%20viewBox%3D%270%200%20352%20232%27%3E%3Cg%20fill%3D%27none%27%20stroke%3D%27%23fff%27%20stroke-opacity%3D%27.05%27%20stroke-width%3D%271.25%27%20stroke-linecap%3D%27round%27%20stroke-linejoin%3D%27round%27%3E%3Cg%20transform%3D%27translate%2818%2C20%29%27%3E%3Cpath%20d%3D%27M0%206a6%206%200%200%201%2012%200%206%206%200%200%201-6%206H2l2-3a6%206%200%200%201-4-3z%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%2862%2C14%29%27%3E%3Cpath%20d%3D%27M0%200h14v10H4L0%2013z%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28108%2C22%29%27%3E%3Cpath%20d%3D%27M6%200l1.8%203.7%204%20.6-2.9%202.8.7%204L6%209.2%202.4%2011l.7-4L.2%204.3l4-.6z%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28150%2C16%29%27%3E%3Cpath%20d%3D%27M2%202h12v12H2z%20M2%206h12%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28192%2C20%29%27%3E%3Cpath%20d%3D%27M7%200C3%200%200%203%200%206.5%200%2011%207%2016%207%2016s7-5%207-9.5C14%203%2011%200%207%200z%20M7%204a2.5%202.5%200%201%201%200%205%202.5%202.5%200%200%201%200-5z%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28234%2C14%29%27%3E%3Cpath%20d%3D%27M0%208c0-4%203-7%207-7s7%203%207%207-3%207-7%207-7-3-7-7z%20M4%208h6%20M7%205v6%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28276%2C20%29%27%3E%3Cpath%20d%3D%27M0%203h16v10H0z%20M0%203l8%206%208-6%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28318%2C16%29%27%3E%3Cpath%20d%3D%27M3%200h10v4H3z%20M1%204h14v11H1z%20M6%208h4%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%2814%2C64%29%27%3E%3Cpath%20d%3D%27M0%2010c3-5%209-5%2012%200%20M6%204a2.5%202.5%200%201%201%200%20.01%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%2856%2C58%29%27%3E%3Cpath%20d%3D%27M0%200h13M0%205h9M0%2010h11%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%2898%2C62%29%27%3E%3Cpath%20d%3D%27M8%200a8%208%200%201%201%200%2016A8%208%200%200%201%208%200z%20M8%204v4.5l3%202%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28140%2C60%29%27%3E%3Cpath%20d%3D%27M0%200l11%206-11%206z%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28182%2C58%29%27%3E%3Cpath%20d%3D%27M2%200h11l3%204v11H2z%20M13%200v4h3%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28224%2C62%29%27%3E%3Cpath%20d%3D%27M0%206h4l4-5v14l-4-5H0z%20M11%204a4%204%200%200%201%200%208%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28266%2C58%29%27%3E%3Cpath%20d%3D%27M1%201h14v10H1z%20M1%2011l5-4%203%202%203-3%203%203%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28308%2C64%29%27%3E%3Cpath%20d%3D%27M6%200a6%206%200%200%201%206%206c0%204-6%2010-6%2010S0%2010%200%206a6%206%200%200%201%206-6z%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%2820%2C106%29%27%3E%3Cpath%20d%3D%27M0%204h5l3-4h4l3%204h1v10H0z%20M8%206a3%203%200%201%201%200%206%203%203%200%200%201%200-6z%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%2862%2C110%29%27%3E%3Cpath%20d%3D%27M6%200l6%2012H0z%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28104%2C104%29%27%3E%3Cpath%20d%3D%27M0%200h12v12H0z%20M3%203h6v6H3z%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28146%2C108%29%27%3E%3Cpath%20d%3D%27M0%206a6%206%200%201%200%2012%200%206%206%200%200%200-12%200z%20M3%206l2%202%204-4%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28188%2C104%29%27%3E%3Cpath%20d%3D%27M1%203h14v9H1z%20M4%203V1h8v2%20M4%2012v2h8v-2%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28230%2C110%29%27%3E%3Cpath%20d%3D%27M0%2012L6%200l6%2012z%20M4%2012v3h4v-3%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28272%2C106%29%27%3E%3Cpath%20d%3D%27M2%202l10%2010M12%202L2%2012%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28314%2C110%29%27%3E%3Cpath%20d%3D%27M0%208h16%20M4%204l-4%204%204%204%20M12%204l4%204-4%204%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%2816%2C150%29%27%3E%3Cpath%20d%3D%27M0%202h14v12H0z%20M3%200v4M11%200v4M0%206h14%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%2858%2C154%29%27%3E%3Cpath%20d%3D%27M7%200a7%207%200%201%201%200%2014A7%207%200%200%201%207%200z%20M4%207h6%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28100%2C148%29%27%3E%3Cpath%20d%3D%27M0%2010c0-6%205-10%208-10s8%204%208%2010%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28142%2C152%29%27%3E%3Cpath%20d%3D%27M2%200h10v14l-5-4-5%204z%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28184%2C150%29%27%3E%3Cpath%20d%3D%27M0%200h14v3H0z%20M2%203v10h10V3%20M6%206v4M8%206v4%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28226%2C154%29%27%3E%3Cpath%20d%3D%27M8%200l2%205%205%20.5-4%203.5%201%205-4-2.6L4%2014l1-5L1%205.5%206%205z%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28268%2C148%29%27%3E%3Cpath%20d%3D%27M1%201h13v13H1z%20M4%207h7M7%204v7%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28310%2C152%29%27%3E%3Cpath%20d%3D%27M0%205a5%205%200%200%201%2010%200v6H0z%20M3%2011v3h4v-3%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%2822%2C196%29%27%3E%3Cpath%20d%3D%27M0%203h16v9H0z%20M5%2012v2h6v-2%20M2%2016h12%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%2864%2C198%29%27%3E%3Cpath%20d%3D%27M6%200a6%206%200%201%201%200%2012A6%206%200%200%201%206%200z%20M6%203v3l2%202%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28106%2C194%29%27%3E%3Cpath%20d%3D%27M0%206h12%20M8%202l4%204-4%204%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28148%2C198%29%27%3E%3Cpath%20d%3D%27M2%200h8a2%202%200%200%201%202%202v10a2%202%200%200%201-2%202H2a2%202%200%200%201-2-2V2a2%202%200%200%201%202-2z%20M4%203h4M4%206h4M4%209h2%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28190%2C194%29%27%3E%3Cpath%20d%3D%27M0%200h14M0%205h14M0%2010h8%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28232%2C198%29%27%3E%3Cpath%20d%3D%27M7%200l7%207-7%207-7-7z%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28274%2C194%29%27%3E%3Cpath%20d%3D%27M1%204h12v9H1z%20M4%204V2a3%203%200%200%201%206%200v2%27%2F%3E%3C%2Fg%3E%3Cg%20transform%3D%27translate%28316%2C198%29%27%3E%3Cpath%20d%3D%27M0%200l14%207-14%207%203-7z%27%2F%3E%3C%2Fg%3E%3C%2Fg%3E%3C%2Fsvg%3E');
  background-repeat: repeat;
  background-size: 352px 232px;
  position: relative;
  overscroll-behavior: contain;
  scroll-behavior: smooth;
}
.cs-day,
.cs-sysm {
  align-self: center;
  background: var(--head);
  color: var(--tx2);
  font-size: 12.5px;
  font-weight: 500;
  padding: 5px 13px;
  border-radius: 8px;
  margin: 10px 0;
  box-shadow: var(--sh);
}
.cs-sysm {
  padding: 6px 14px;
  max-width: 70%;
  text-align: center;
  margin: 8px 0;
  font-weight: 400;
}

.cs-msg {
  max-width: 65%;
  position: relative;
  margin-top: 4px;
}
.cs-msg.grp {
  margin-top: 1px;
}
.cs-bub {
  position: relative;
  padding: 6px 9px 19px 10px;
  border-radius: 7.5px;
  box-shadow: var(--sh);
  min-width: 110px;
}
.cs-msg.in {
  align-self: flex-start;
}
.cs-msg.in .cs-bub {
  background: var(--recv);
}
.cs-msg.in.f1 .cs-bub {
  border-radius: 0 7.5px 7.5px 7.5px;
}
.cs-msg.in.f1::before {
  content: '';
  position: absolute;
  top: 0;
  left: -8px;
  border-top: 9px solid var(--recv);
  border-left: 9px solid transparent;
}
.cs-msg.out {
  align-self: flex-end;
}
.cs-msg.out .cs-bub {
  background: var(--sent);
}
.cs-msg.out.f1 .cs-bub {
  border-radius: 7.5px 0 7.5px 7.5px;
}
.cs-msg.out.f1::before {
  content: '';
  position: absolute;
  top: 0;
  right: -8px;
  border-top: 9px solid var(--sent);
  border-right: 9px solid transparent;
}
.cs-msg.pv .cs-bub {
  background: var(--note);
  border: 1px solid var(--note-b);
}
.cs-msg.pv.f1::before {
  border-top-color: var(--note);
}
.cs-snd {
  font-size: 12.5px;
  font-weight: 600;
  color: var(--g);
  margin-bottom: 2px;
}
.cs-tx {
  font-size: 14.4px;
  line-height: 1.42;
  word-wrap: break-word;
  white-space: pre-wrap;
}
.cs-tx :deep(a) {
  color: var(--b);
  text-decoration: underline;
}
.cs-tx :deep(p) {
  margin: 0;
}
.cs-tx :deep(p + p) {
  margin-top: 6px;
}
.cs-mt {
  position: absolute;
  right: 9px;
  bottom: 4px;
  font-size: 11px;
  color: var(--tx3);
  display: flex;
  align-items: center;
  gap: 3px;
  line-height: 1;
  pointer-events: none;
}
.cs-mt .cs-tick {
  width: 14px;
  height: 14px;
}
.cs-img {
  max-width: 330px;
  max-height: 340px;
  width: auto;
  height: auto;
  object-fit: cover;
  border-radius: 6px;
  display: block;
  margin-bottom: 4px;
  cursor: pointer;
  background: rgba(0, 0, 0, 0.12);
}
.cs-msg:has(.cs-img) .cs-bub {
  padding: 3px 3px 19px;
  min-width: 0;
}
.cs-msg:has(.cs-img) .cs-mt {
  right: 10px;
  bottom: 7px;
  background: rgba(11, 20, 26, 0.45);
  color: #e9edef;
  padding: 2px 6px;
  border-radius: 8px;
  backdrop-filter: blur(2px);
}
.cs-err {
  background: #4a1d24;
  color: #ffb4bd;
  font-size: 12.5px;
  padding: 8px 12px;
  border-radius: 8px;
  margin-bottom: 6px;
}
.cs-aud {
  min-width: 210px;
  display: block;
  margin-bottom: 2px;
}
/* ===== VOICE bubble — WhatsApp jaisa ===== */
.cs-aud {
  width: 300px;
  max-width: 100%;
  display: block;
  margin: 2px 0 0;
}
.cs-msg:has(.cs-aud) .cs-bub {
  padding: 8px 10px 19px;
  min-width: 300px;
}
.cs-aud :deep(.cs-voice__row) {
  gap: 10px;
}
.cs-aud :deep(.cs-voice__play) {
  width: 26px;
  height: 26px;
  opacity: 1;
}
.cs-aud :deep(.cs-voice__wave) {
  height: 26px;
  gap: 2px;
}
.cs-aud :deep(.cs-voice__bar) {
  min-width: 2px;
  opacity: 0.42;
}
.cs-aud :deep(.cs-voice__bar--on) {
  opacity: 1;
  background: #53bdeb;
}
.cs-aud :deep(.cs-voice__meta) {
  padding-left: 36px !important;
  margin-top: 2px !important;
}
.cs-aud :deep(.cs-voice__time) {
  font-size: 11.5px;
  opacity: 0.75;
}
.cs-aud :deep(.cs-voice__speed) {
  opacity: 0.6;
}

/* ===== CONTACT PROFILE ===== */
.cs-pf {
  position: fixed;
  inset: 0;
  z-index: 9998;
  background: rgba(0, 0, 0, 0.4);
  display: flex;
  justify-content: flex-end;
}
.cs-pfp {
  width: 380px;
  max-width: 90vw;
  background: var(--panel);
  height: 100%;
  overflow-y: auto;
}
.cs-pfh {
  height: 60px;
  background: var(--head);
  display: flex;
  align-items: center;
  gap: 18px;
  padding: 0 18px;
  font-size: 16px;
  font-weight: 500;
}
.cs-pfb {
  padding: 26px 20px 22px;
  text-align: center;
  border-bottom: 8px solid var(--chat);
}
.cs-pfav {
  width: 168px;
  height: 168px;
  border-radius: 50%;
  margin: 0 auto 14px;
  display: grid;
  place-items: center;
  color: #fff;
  font-size: 52px;
  font-weight: 600;
  overflow: hidden;
}
.cs-pfav img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.cs-pfn {
  font-size: 21px;
  color: var(--tx);
}
.cs-pfs {
  font-size: 15px;
  color: var(--tx3);
  margin-top: 4px;
}
.cs-pfr {
  padding: 13px 20px;
  border-bottom: 1px solid var(--ln2);
  display: flex;
  flex-direction: column;
  gap: 3px;
}
.cs-pfk {
  font-size: 12.5px;
  color: var(--g);
}
.cs-pfv {
  font-size: 14.5px;
  color: var(--tx);
  word-break: break-all;
}
.cs-tnm {
  cursor: pointer;
}
.cs-tav {
  cursor: pointer;
}

.cs-file {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 10px;
  background: rgba(0, 0, 0, 0.18);
  border-radius: 6px;
  color: var(--tx);
  text-decoration: none;
  margin-bottom: 4px;
  font-size: 13.5px;
}

/* ===== COMPOSER ===== */
.cs-comp {
  padding: 8px 18px 12px;
  background: var(--head);
  flex-shrink: 0;
  position: relative;
}
.cs-cbar {
  background: var(--fld);
  border-radius: 24px;
  display: flex !important;
  flex-direction: row !important;
  flex-wrap: nowrap !important;
  align-items: center;
  gap: 11px;
  padding: 10px 16px;
  min-height: 46px;
  width: 100%;
}
.cs-ci {
  width: 23px;
  height: 23px;
  min-width: 23px;
  color: var(--tx2);
  cursor: pointer;
  flex-shrink: 0;
  margin: 0;
  align-self: center;
}
.cs-ci:hover {
  color: var(--tx);
}
.cs-cin {
  flex: 1 1 0 !important;
  width: auto !important;
  min-width: 0;
  background: none !important;
  border: none !important;
  outline: none !important;
  box-shadow: none !important;
  resize: none;
  color: var(--tx);
  font-size: 15px;
  font-family: inherit;
  line-height: 21px;
  padding: 0 !important;
  margin: 0 !important;
  height: 21px;
  min-height: 21px;
  max-height: 105px;
  display: block;
  overflow-y: auto;
  align-self: center;
}
.cs-cin::placeholder {
  color: var(--tx3);
}
.cs-send {
  width: 34px;
  height: 34px;
  border-radius: 50%;
  background: var(--g);
  color: #fff;
  display: grid;
  place-items: center;
  cursor: pointer;
  flex-shrink: 0;
  margin: 6px 0;
  padding: 8px;
}
.cs-dot {
  width: 9px;
  height: 9px;
  border-radius: 50%;
  background: var(--red);
  flex-shrink: 0;
  animation: csblink 1.4s ease-in-out infinite;
}
.cs-dot.pz {
  animation: none;
  opacity: 0.45;
}
@keyframes csblink {
  0%,
  100% {
    opacity: 1;
  }
  50% {
    opacity: 0.25;
  }
}
.cs-rt {
  font-size: 13px;
  color: var(--tx2);
  font-variant-numeric: tabular-nums;
}
.cs-sp {
  flex: 1;
}
.cs-recstrip {
  width: 100%;
  min-height: 42px;
  padding: 4px 16px 6px;
  margin-bottom: 6px;
  background: var(--fld);
  border-radius: 10px;
  overflow: hidden;
}
.cs-recstrip :deep(.cs-wave),
.cs-recstrip :deep(> div) {
  width: 100% !important;
  min-height: 34px;
}
.cs-files {
  display: flex;
  gap: 6px;
  flex-wrap: wrap;
  margin-top: 6px;
}
.cs-fchip {
  background: var(--fld);
  border-radius: 6px;
  padding: 4px 9px;
  font-size: 12.5px;
  color: var(--tx2);
  display: flex;
  align-items: center;
  gap: 6px;
}
.cs-fchip span {
  cursor: pointer;
  width: 14px;
  height: 14px;
}

/* ===== COMPOSER extras ===== */
.cs-tabs {
  display: flex;
  gap: 6px;
  margin-bottom: 7px;
}
.cs-tab {
  font-size: 13px;
  padding: 5px 13px;
  border-radius: 7px;
  border: 0;
  background: transparent;
  color: var(--tx3);
  cursor: pointer;
}
.cs-tab.on {
  background: var(--fld);
  color: var(--tx);
  font-weight: 500;
}
.cs-cbar.note {
  background: var(--note);
  border: 1px solid var(--note-b);
}
.cs-ci.act {
  color: var(--g);
}
.cs-emoji {
  background: var(--fld);
  border-radius: 10px;
  padding: 10px;
  margin-bottom: 7px;
  max-height: 190px;
  overflow-y: auto;
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(34px, 1fr));
  gap: 2px;
}
.cs-em {
  font-size: 21px;
  cursor: pointer;
  display: grid;
  place-items: center;
  height: 34px;
  border-radius: 6px;
}
.cs-em:hover {
  background: var(--hov);
}
.cs-tplbox {
  background: var(--fld);
  border-radius: 10px;
  margin-bottom: 7px;
  max-height: 210px;
  overflow-y: auto;
}
.cs-tpl {
  padding: 10px 14px;
  cursor: pointer;
  border-bottom: 1px solid var(--ln2);
}
.cs-tpl:hover {
  background: var(--hov);
}
.cs-tpln {
  font-size: 13.5px;
  color: var(--g);
  font-weight: 500;
}
.cs-tplt {
  font-size: 13px;
  color: var(--tx3);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  margin-top: 2px;
}
.cs-tplempty {
  padding: 16px;
  text-align: center;
  color: var(--tx3);
  font-size: 13px;
}

/* row ke chhote nishan */
.cs-mk {
  width: 14px;
  height: 14px;
  color: var(--tx3);
  flex-shrink: 0;
}
.cs-ib {
  font-size: 10.5px;
  color: var(--tx3);
  background: var(--fld);
  padding: 1px 6px;
  border-radius: 4px;
  flex-shrink: 0;
  max-width: 92px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* submenu ab menu ke upar — chhupta nahi tha */
.cs-cmenu {
  overflow: visible !important;
}
.cs-cmenu {
  z-index: 9999;
}
.cs-sub {
  z-index: 10000 !important;
  box-shadow: 0 6px 26px rgba(0, 0, 0, 0.55) !important;
}
.cs-has-sub:hover {
  background: var(--menu-hov);
}

/* profile: aur tafseel */
.cs-pfacts {
  display: flex;
  gap: 8px;
  justify-content: center;
  padding: 16px 0 24px;
}
.cs-pfv.cap {
  text-transform: capitalize;
}
.cs-pfa {
  display: flex;
  gap: 10px;
  justify-content: center;
  padding: 14px 0 4px;
}
.cs-pfab {
  display: grid;
  place-items: center;
  gap: 4px;
  color: var(--g);
  font-size: 12px;
  cursor: pointer;
  padding: 8px 14px;
  border-radius: 8px;
}
.cs-pfab:hover {
  background: var(--hov);
}
.cs-pfab span:first-child {
  width: 20px;
  height: 20px;
}

/* ===== EMPTY ===== */
.cs-none {
  flex: 1;
  display: grid;
  place-items: center;
  background: var(--chat);
  text-align: center;
}
.cs-none-t {
  font-size: 26px;
  font-weight: 300;
  color: var(--tx2);
}
.cs-none-s {
  font-size: 14px;
  color: var(--tx3);
  margin-top: 8px;
}

/* send: WhatsApp jaisa plain, gol background nahi */
.cs-snd2 {
  width: 24px;
  height: 24px;
  min-width: 24px;
  color: var(--g);
  cursor: pointer;
  flex-shrink: 0;
  align-self: center;
}

/* ===== REPLY PREVIEW ===== */
.cs-rp {
  display: flex;
  align-items: center;
  gap: 10px;
  background: var(--fld);
  border-radius: 8px;
  padding: 8px 12px;
  margin-bottom: 7px;
}
.cs-rpbar {
  width: 4px;
  align-self: stretch;
  border-radius: 3px;
  background: var(--g);
  flex-shrink: 0;
}
.cs-rpb {
  flex: 1;
  min-width: 0;
}
.cs-rpn {
  font-size: 12.5px;
  font-weight: 600;
  color: var(--g);
}
.cs-rpt {
  font-size: 13px;
  color: var(--tx3);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  margin-top: 2px;
}

/* number: naam ke neeche */
.cs-rph {
  font-size: 12px;
  color: var(--tx3);
  margin: -1px 0 3px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-variant-numeric: tabular-nums;
}
.cs-tph {
  font-variant-numeric: tabular-nums;
}

/* ===== MESSAGE INFO ===== */
.cs-inf {
  width: 400px;
}
.cs-infp {
  padding: 12px 16px;
  font-size: 14px;
  color: var(--tx);
  background: var(--sent);
  margin: 12px 16px;
  border-radius: 7.5px;
  max-height: 110px;
  overflow-y: auto;
}
.cs-infl {
  flex: 1;
  overflow-y: auto;
}
.cs-pfk.err,
.cs-pfv.err {
  color: var(--red);
}

/* ===== FORWARD ===== */
.cs-fw {
  position: fixed;
  inset: 0;
  z-index: 9998;
  background: rgba(0, 0, 0, 0.55);
  display: grid;
  place-items: center;
}
.cs-fwb {
  width: 420px;
  max-width: 92vw;
  max-height: 78vh;
  background: var(--panel);
  border-radius: 10px;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}
.cs-fwh {
  height: 58px;
  background: var(--head);
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 0 16px;
  font-size: 16px;
  font-weight: 500;
  flex-shrink: 0;
}
.cs-fwp {
  padding: 10px 16px;
  font-size: 13px;
  color: var(--tx3);
  border-bottom: 1px solid var(--ln2);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.cs-fwl {
  flex: 1;
  overflow-y: auto;
}
.cs-fwr {
  display: flex;
  align-items: center;
  gap: 13px;
  padding: 10px 16px;
  cursor: pointer;
}
.cs-fwr:hover {
  background: var(--hov);
}
.cs-fwr.on {
  background: var(--g-tint);
}
.cs-fwav {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  display: grid;
  place-items: center;
  color: #fff;
  font-size: 13px;
  font-weight: 600;
  flex-shrink: 0;
}
.cs-fwn {
  flex: 1;
  min-width: 0;
  font-size: 15px;
  color: var(--tx);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.cs-fwck {
  width: 20px;
  height: 20px;
  color: var(--g);
  flex-shrink: 0;
}
.cs-fwf {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 16px;
  border-top: 1px solid var(--ln2);
  flex-shrink: 0;
}
.cs-fwc {
  flex: 1;
  font-size: 13px;
  color: var(--tx3);
}
.cs-fwbtn {
  background: var(--g);
  color: #fff;
  border: 0;
  border-radius: 20px;
  padding: 8px 22px;
  font-size: 14px;
  cursor: pointer;
}
.cs-fwbtn:disabled {
  opacity: 0.4;
  cursor: default;
}

/* ===== CONTEXT MENU ===== */
.cs-cmenu {
  position: fixed;
  z-index: 9999;
  background: var(--menu);
  border-radius: 8px;
  box-shadow: 0 4px 22px rgba(0, 0, 0, 0.45);
  padding: 7px 0;
  min-width: 224px;
  max-height: calc(100vh - 24px);
  overflow-y: auto;
  overscroll-behavior: contain;
}
.cs-cmenu::-webkit-scrollbar {
  width: 5px;
}
.cs-cmenu::-webkit-scrollbar-thumb {
  background: var(--ln);
  border-radius: 3px;
}
.cs-arch.on {
  background: var(--g-tint);
}
.cs-arch.on .cs-arch-t {
  color: var(--g);
}

/* ===== MOBILE ===== */
@media (max-width: 768px) {
  .cs-app {
    overflow: hidden;
  }
  .cs-panel {
    width: 100%;
    flex: 1 1 100%;
    min-width: 0;
    border-right: none;
  }
  .cs-img {
    max-width: 78vw;
    max-height: 60vh;
  }
  .cs-main {
    display: none;
  }
  .cs-none {
    display: none;
  }
  .cs-app.thr .cs-panel {
    display: none;
  }
  .cs-app.thr .cs-main {
    display: flex;
    width: 100%;
  }
  .cs-thread {
    padding: 14px 10px;
  }
  .cs-msg {
    max-width: 82%;
  }
  .cs-comp {
    padding: 7px 8px 9px;
  }
  .cs-ph {
    padding: 14px 14px 10px;
  }
  .cs-row {
    padding: 11px 14px;
  }
  .cs-cmenu {
    min-width: 200px;
    max-width: 84vw;
  }
  .cs-th {
    height: 56px;
    padding: 0 10px;
    gap: 10px;
  }
  .cs-tav {
    width: 36px;
    height: 36px;
  }
  .cs-tn {
    font-size: 15.5px;
  }
  .cs-av {
    width: 46px;
    height: 46px;
    min-width: 46px;
  }
  .cs-psr {
    margin: 0 10px 10px;
  }
  .cs-pills {
    padding: 0 10px 10px;
  }
  .cs-pfp {
    width: 100%;
    max-width: 100%;
  }
  .cs-cbar {
    border-radius: 22px;
    min-height: 44px;
    gap: 9px;
    padding: 0 12px;
  }
  .cs-emoji {
    max-height: 150px;
  }
  .cs-msg:has(.cs-aud) .cs-bub {
    min-width: 0;
  }
  .cs-aud {
    width: 100%;
    min-width: 0;
  }
  .cs-msg:has(.cs-aud) {
    max-width: 88%;
  }
  .cs-fwb {
    max-height: 88vh;
  }
  .cs-cbar {
    padding: 9px 13px;
  }
  .cs-comp {
    padding-bottom: env(safe-area-inset-bottom, 9px);
  }
}
.cs-mi {
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 10px 17px;
  font-size: 14.5px;
  color: var(--tx);
  cursor: pointer;
}
.cs-mi:hover {
  background: var(--menu-hov);
}
.cs-mi span:first-child {
  width: 19px;
  height: 19px;
  color: var(--tx2);
  flex-shrink: 0;
}
.cs-mi.danger,
.cs-mi.danger span:first-child {
  color: var(--red);
}
.cs-cmenu hr {
  margin: 6px 0;
  border: none;
  border-top: 1px solid var(--ln);
}
</style>
