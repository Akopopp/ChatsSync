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
const agentsList = useMapGetter('agents/getAgents');
const teamsList = useMapGetter('teams/getTeams');
const typingGetter = useMapGetter('conversationTypingStatus/getUserList');

const typingNames = computed(() => {
  try {
    const u = typingGetter.value?.(currentChat.value?.id) || [];
    return u.map(x => x.name).filter(Boolean);
  } catch (e) {
    return [];
  }
});

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
  (labelsList.value || []).forEach(l => {
    base.push({ k: `lb-${l.title}`, n: l.title, lb: true, color: l.color });
  });
  return base;
});

const PILL_LIMIT = 5;
const visiblePills = computed(() =>
  showAllPills.value ? pills.value : pills.value.slice(0, PILL_LIMIT)
);
const hiddenPillCount = computed(() =>
  Math.max(0, pills.value.length - PILL_LIMIT)
);

const rows = computed(() => {
  let L = [...(allChats.value || [])];
  if (props.inboxId) {
    const iid = Number(props.inboxId);
    const only = L.filter(c => c.inbox_id === iid);
    if (only.length) L = only;
  }
  if (fStatus.value === 'snoozed')
    L = L.filter(c => c.status === 'snoozed' || !!c.snoozed_until);
  else if (fStatus.value !== 'all')
    L = L.filter(c => c.status === fStatus.value);
  if (fAssignee.value === 'me')
    L = L.filter(c => c.meta?.assignee?.id === currentUser.value?.id);
  else if (fAssignee.value === 'none') L = L.filter(c => !c.meta?.assignee);
  if (fPriority.value !== 'all')
    L = L.filter(c => (c.priority || 'none') === fPriority.value);
  if (fUnreplied.value) {
    L = L.filter(c => {
      const m = lastOf(c);
      return m && m.message_type === 0 && c.status !== 'resolved';
    });
  }
  if (fHasAttach.value) {
    L = L.filter(c =>
      (c.messages || []).some(m => (m.attachments || []).length > 0)
    );
  }

  const f = filt.value;
  if (f === 'unread') L = L.filter(c => (c.unread_count || 0) > 0);
  else if (f === 'mine')
    L = L.filter(c => c.meta?.assignee?.id === currentUser.value?.id);
  else if (f === 'unassigned') L = L.filter(c => !c.meta?.assignee);
  else if (f.startsWith('lb-')) {
    const t = f.slice(3);
    L = L.filter(c => (c.labels || []).includes(t));
  } else if (f.startsWith('in-')) {
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
  L = L.filter(c => (showArchived.value ? isArchived(c) : !isArchived(c)));

  const k = sortBy.value;
  const val = c => {
    if (k === 'created_at_desc' || k === 'created_at_asc') return c.created_at || 0;
    if (k === 'priority_desc') {
      const P = { urgent: 4, high: 3, medium: 2, low: 1 };
      return P[c.priority] || 0;
    }
    if (k === 'waiting_since_desc') return -(c.waiting_since || c.timestamp || 0);
    return c.timestamp || 0;
  };
  const asc = k === 'created_at_asc';

  return L.slice().sort((a, b) => {
    const p = (isPinned(b) ? 1 : 0) - (isPinned(a) ? 1 : 0);
    if (p) return p;
    return asc ? val(a) - val(b) : val(b) - val(a);
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

const lastOf = c =>
  c?.messages?.length ? c.messages[c.messages.length - 1] : null;

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
  let lastAgent = null;
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
    const first = key !== prevSender;
    // naam sirf outgoing par, aur sirf jab agent badle — 1-on-1 chat
    // mein har bubble par apna naam WhatsApp nahi dikhata
    const showName =
      first &&
      m.message_type === 1 &&
      !!m.sender?.name &&
      m.sender.id !== lastAgent;
    if (m.message_type === 1 && m.sender?.id) lastAgent = m.sender.id;
    out.push({ kind: 'msg', id: m.id, m, first, showName });
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
const lightbox = ref(null);
const fwdQ = ref('');
const newLabel = ref('');
const showAllPills = ref(false);
const hmenu = ref(false);
const hsub = ref('');
const hmFlip = ref(false);

/* submenu ki side: daayen jagah na ho to baaen kholo */
const fitHm = el => {
  if (!el) return;
  nextTick(() => {
    const r = el.getBoundingClientRect();
    hmFlip.value = r.right + 200 > window.innerWidth;
  });
};
const selectMode = ref(false);
const picked = ref([]);

const SORTS = [
  { k: 'last_activity_at_desc', n: 'Latest' },
  { k: 'created_at_desc', n: 'Newest first' },
  { k: 'created_at_asc', n: 'Oldest first' },
  { k: 'priority_desc', n: 'Priority' },
  { k: 'waiting_since_desc', n: 'Longest waiting' },
];
const sortBy = ref('last_activity_at_desc');

/* filter panel */
const showFilter = ref(false);
const fStatus = ref('all');
const fAssignee = ref('all');
const fPriority = ref('all');
const fUnreplied = ref(false);
const fHasAttach = ref(false);

const activeFilterCount = computed(() => {
  let n = 0;
  if (fStatus.value !== 'all') n += 1;
  if (fAssignee.value !== 'all') n += 1;
  if (fPriority.value !== 'all') n += 1;
  if (fUnreplied.value) n += 1;
  if (fHasAttach.value) n += 1;
  return n;
});

const clearFilters = () => {
  fStatus.value = 'all';
  fAssignee.value = 'all';
  fPriority.value = 'all';
  fUnreplied.value = false;
  fHasAttach.value = false;
};

const togglePick = id => {
  const i = picked.value.indexOf(id);
  if (i >= 0) picked.value.splice(i, 1);
  else picked.value.push(id);
};

const bulk = name => {
  const ids = [...picked.value];
  if (!ids.length) return;
  ids.forEach(id => {
    const c = (allChats.value || []).find(x => x.id === id);
    if (!c) return;
    if (name === 'read') store.dispatch('markMessagesRead', { id });
    else if (name === 'resolved')
      store.dispatch('toggleStatus', { conversationId: id, status: 'resolved' });
    else if (name === 'archive') setAttr(c, { cs_archived: true });
    else if (name === 'delete') store.dispatch('deleteConversation', id);
  });
  picked.value = [];
  selectMode.value = false;
};

const markAllRead = () => {
  (rows.value || []).forEach(c => {
    if ((c.unread_count || 0) > 0)
      store.dispatch('markMessagesRead', { id: c.id })?.catch?.(() => {});
  });
  hmenu.value = false;
};

const applySort = k => {
  sortBy.value = k;
  hmenu.value = false;
  hsub.value = '';
  store.dispatch('setChatSortFilter', k);
};

const goSettings = () => {
  hmenu.value = false;
  router.push({ name: 'general_settings_index', params: { accountId: accountId.value } });
};

const doLogout = () => {
  hmenu.value = false;
  store.dispatch('logout')?.catch?.(() => {
    window.location.href = '/app/login';
  });
};
const labelsList = useMapGetter('labels/getLabels');

const REACTS = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

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

/* asli tick: Chatwoot/WhatsApp ka status field
   sent -> ek tick | delivered -> do grey | read -> do neele
   failed -> laal (!) */
const tickOf = m => {
  if (!m || m.message_type !== 1) return null;
  const st = m.status || 'sent';
  if (st === 'failed') return { i: 'i-lucide-circle-alert', c: 'err' };
  if (st === 'read') return { i: 'i-lucide-check-check', c: 'blue' };
  if (st === 'delivered') return { i: 'i-lucide-check-check', c: '' };
  if (st === 'progress' || st === 'pending')
    return { i: 'i-lucide-clock-3', c: '' };
  return { i: 'i-lucide-check', c: '' };
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
  /* WhatsApp voice note ke liye OGG/Opus lazmi hai. Browser support
     kare to wahi, warna mp3 (jo file ki tarah jayega). */
  const canOgg =
    typeof MediaRecorder !== 'undefined' &&
    MediaRecorder.isTypeSupported?.('audio/ogg;codecs=opus');
  return canOgg ? 'audio/ogg' : 'audio/mp3';
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
    /* WhatsApp voice note (PTT) tabhi banta hai jab file OGG/Opus ho
       aur Chatwoot ko isVoiceMessage flag mile. Warna woh usay
       aam audio file ki tarah bhejta hai. */
    const f = file.file;
    try {
      f.isVoiceMessage = true;
    } catch (e) {
      /* ignore */
    }
    pushMessage({
      conversationId: currentChat.value.id,
      message: '',
      private: false,
      files: [f],
      isVoiceMessage: true,
      ccEmails: '',
      bccEmails: '',
      toEmails: '',
      contentAttributes: { is_recorded_audio: true },
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
  hmenu.value = false;
  hsub.value = '';
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

/* Chatwoot ki custom_attributes API — server par save hota hai,
   isliye PC aur mobile dono par ek jaisa. localStorage sirf
   fallback hai agar API fail ho jaye. */
const setAttr = (c, patch) => {
  const merged = { ...(c.custom_attributes || {}), ...patch };
  // turant UI update
  if (c.custom_attributes) Object.assign(c.custom_attributes, patch);
  else c.custom_attributes = { ...patch };

  const r = store.dispatch('updateCustomAttributes', {
    conversationId: c.id,
    customAttributes: merged,
  });
  if (r && r.catch) {
    r.catch(() => {
      // API na chale to kam az kam is device par yaad rahe
      if (patch.cs_pinned !== undefined) {
        pinned.value = { ...pinned.value, [c.id]: patch.cs_pinned };
        saveLS('pin', pinned.value);
      }
      if (patch.cs_archived !== undefined) {
        archived.value = { ...archived.value, [c.id]: patch.cs_archived };
        saveLS('arch', archived.value);
      }
    });
  }
  return r;
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
    setAttr(c, { cs_pinned: !isPinned(c) });
  } else if (name === 'archive') {
    const next = !isArchived(c);
    setAttr(c, { cs_archived: next });
    // WhatsApp jaisa: archive karte hi mute ho jaye
    if (next && !isMuted(c)) {
      d('muteConversation', c.id);
      muted.value = { ...muted.value, [c.id]: true };
      saveLS('mute', muted.value);
    } else if (!next && isMuted(c)) {
      d('unmuteConversation', c.id);
      muted.value = { ...muted.value, [c.id]: false };
      saveLS('mute', muted.value);
    }
  } else if (name === 'copy') {
    copyText(
      `${window.location.origin}/app/accounts/${accountId.value}/conversations/${c.id}`
    );
  } else if (name === 'block') {
    d('contacts/update', {
      id: c.meta?.sender?.id,
      blocked: !c.meta?.sender?.blocked,
    });
  } else if (name === 'label') {
    const cur = c.labels || [];
    const next = cur.includes(arg) ? cur.filter(x => x !== arg) : [...cur, arg];
    d('setLabels', { conversationId: c.id, labels: next });
  } else if (name === 'newlabel') {
    const t = (newLabel.value || '').trim().replace(/\s+/g, '-').toLowerCase();
    if (!t) return;
    newLabel.value = '';
    store
      .dispatch('labels/create', { title: t, color: '#00A884' })
      ?.catch?.(() => {});
    d('setLabels', { conversationId: c.id, labels: [...(c.labels || []), t] });
  } else if (name === 'agent') d('assignAgent', { conversationId: c.id, agentId: arg?.id })
  else if (name === 'team') d('assignTeam', { conversationId: c.id, teamId: arg?.id });
  else if (name === 'delete') d('deleteConversation', c.id);
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
const msgAct = (name, arg) => {
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
  } else if (name === 'react') {
    pushMessage({
      conversationId: currentChat.value.id,
      message: arg,
      private: false,
      files: [],
      ccEmails: '',
      bccEmails: '',
      toEmails: '',
      contentAttributes: { in_reply_to: m.id },
    }).then(scrollDown);
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

/* server ka field pehle, warna local — jab backend chale to
   sab agents ko nazar aayega */
const isPinned = c =>
  !!(
    c?.custom_attributes?.cs_pinned ||
    c?.additional_attributes?.pinned_at ||
    pinned.value[c?.id]
  );
const isArchived = c =>
  !!(
    c?.custom_attributes?.cs_archived ||
    c?.additional_attributes?.archived_at ||
    archived.value[c?.id]
  );
const isMuted = c =>
  !!(c?.muted || c?.custom_attributes?.cs_archived || muted.value[c?.id]);

/* reply ka quote dhoondo */
const quotedOf = m => {
  const rid = m?.content_attributes?.in_reply_to;
  if (!rid) return null;
  return messages.value.find(x => x.id === rid) || null;
};

/* reactions agar data mein hon */
const reactionsOf = m => {
  const r = m?.content_attributes?.reactions;
  if (!r) return [];
  if (Array.isArray(r)) return r;
  return Object.entries(r).map(([e, n]) => ({ emoji: e, count: n }));
};

const fwdRows = computed(() => {
  const q2 = fwdQ.value.trim().toLowerCase();
  const L = allChats.value || [];
  if (!q2) return L;
  return L.filter(c =>
    `${c.meta?.sender?.name || ''} ${phoneOf(c)}`.toLowerCase().includes(q2)
  );
});

const archivedCount = computed(
  () => (allChats.value || []).filter(isArchived).length
);

/* ---------------- lifecycle ---------------- */
onMounted(() => {
  store.dispatch('inboxes/get');
  store.dispatch('teams/get');
  store.dispatch('labels/get');
  store.dispatch('agents/get');
  store.dispatch('setActiveInbox', props.inboxId || null);
  store.dispatch('updateChatListFilters', {
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
      <div v-if="selectMode" class="cs-ph cs-phsel">
        <span
          class="cs-ic i-lucide-x"
          @click="
            selectMode = false;
            picked = [];
          "
        />
        <h1 class="cs-selh">{{ picked.length }} selected</h1>
        <button
          class="cs-sb"
          :disabled="!picked.length"
          @click="bulk('read')"
        >
          <span class="i-lucide-mail-open" />
          <span>Read</span>
        </button>
        <button
          class="cs-sb"
          :disabled="!picked.length"
          @click="bulk('resolved')"
        >
          <span class="i-lucide-check" />
          <span>Resolve</span>
        </button>
        <button
          class="cs-sb"
          :disabled="!picked.length"
          @click="bulk('archive')"
        >
          <span class="i-lucide-archive" />
          <span>Archive</span>
        </button>
        <button
          class="cs-sb dgr"
          :disabled="!picked.length"
          @click="bulk('delete')"
        >
          <span class="i-lucide-trash-2" />
          <span>Delete</span>
        </button>
      </div>

      <div v-else class="cs-ph">
        <h1>Chats</h1>
        <span class="cs-ic i-lucide-more-vertical" @click.stop="hmenu = !hmenu" />
        <div
          v-if="hmenu"
          :ref="fitHm"
          class="cs-hm"
          :class="{ flipL: hmFlip }"
          @click.stop
        >
          <div
            class="cs-mi"
            @click="
              selectMode = true;
              hmenu = false;
            "
          >
            <span class="i-lucide-check-square" /><span>Select chats</span>
          </div>
          <div class="cs-mi" @click="markAllRead">
            <span class="i-lucide-mail-open" /><span>Mark all as read</span>
          </div>
          <hr />
          <div
            class="cs-mi cs-has-sub"
            @click.stop="hsub = hsub === 'sort' ? '' : 'sort'"
          >
            <span class="i-lucide-arrow-up-down" /><span>Sort by</span>
            <span class="cs-arw i-lucide-chevron-right" />
            <div v-if="hsub === 'sort'" class="cs-sub" @click.stop>
              <div
                v-for="o in SORTS"
                :key="o.k"
                class="cs-mi"
                @click.stop="applySort(o.k)"
              >
                <span>{{ o.n }}</span>
                <span v-if="sortBy === o.k" class="cs-arw i-lucide-check" />
              </div>
            </div>
          </div>
          <div
            class="cs-mi"
            @click="
              showFilter = true;
              hmenu = false;
            "
          >
            <span class="i-lucide-list-filter" /><span>Filter conversations</span>
            <span v-if="activeFilterCount" class="cs-fcn">
              {{ activeFilterCount }}
            </span>
          </div>
          <hr />
          <div class="cs-mi" @click="goSettings">
            <span class="i-lucide-settings" /><span>Settings</span>
          </div>
          <div class="cs-mi" @click="doLogout">
            <span class="i-lucide-log-out" /><span>Log out</span>
          </div>
        </div>
      </div>


      <div class="cs-psr" :class="{ act: q }">
        <span class="i-lucide-search" />
        <input v-model="q" placeholder="Search chats, contacts or messages" />
        <span v-if="q" class="cs-clr i-lucide-x" @click="q = ''" />
      </div>

      <div class="cs-pills">
        <div
          v-for="p in visiblePills"
          :key="p.k"
          class="cs-pl"
          :class="{ on: filt === p.k, lb: p.lb }"
          @click="filt = p.k"
        >
          <span
            v-if="p.lb"
            class="cs-pld"
            :style="{ background: p.color || 'var(--g)' }"
          />
          <span>{{ p.n }}</span>
          <span v-if="p.c" class="cs-plc">{{ p.c }}</span>
        </div>
        <div
          v-if="hiddenPillCount && !showAllPills"
          class="cs-pl cs-plmore"
          @click="showAllPills = true"
        >
          <span class="i-lucide-chevron-down" />
          <span>{{ hiddenPillCount }}</span>
        </div>
        <div
          v-if="showAllPills && hiddenPillCount"
          class="cs-pl cs-plmore"
          @click="showAllPills = false"
        >
          <span class="i-lucide-chevron-up" />
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
          @click="selectMode ? togglePick(c.id) : openChat(c)"
          @contextmenu="openMenu($event, c)"
        >
          <span
            v-if="selectMode"
            class="cs-ck"
            :class="
              picked.includes(c.id)
                ? 'i-lucide-check-circle-2 on'
                : 'i-lucide-circle'
            "
          />
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
            <div v-if="(c.labels || []).length" class="cs-lbs">
              <span v-for="l in c.labels" :key="l" class="cs-lb">{{ l }}</span>
            </div>

            <div class="cs-r2">
              <span
                v-if="lastOf(c) && tickOf(lastOf(c))"
                class="cs-tick"
                :class="[tickOf(lastOf(c)).i, tickOf(lastOf(c)).c]"
              />
              <span
                v-else-if="chipFor(c.inbox_id)"
                class="cs-chip"
                :class="'cs-chip--' + chipFor(c.inbox_id).c"
              >
                {{ chipFor(c.inbox_id).t }}
              </span>
              <span class="cs-m">{{ previewOf(c) }}</span>
              <span v-if="isMuted(c)" class="cs-mk i-lucide-bell-off" />
              <span v-if="isPinned(c)" class="cs-mk i-lucide-pin" />
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
          <div v-if="typingNames.length" class="cs-ts cs-typ">
            {{ typingNames.join(', ') }} typing…
          </div>
          <div v-else class="cs-ts">
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
              <div v-if="b.showName" class="cs-snd">
                {{ b.m.sender?.name || 'You' }}
              </div>

              <div v-if="quotedOf(b.m)" class="cs-q">
                <div class="cs-qbar" />
                <div class="cs-qb">
                  <div class="cs-qn">
                    {{
                      quotedOf(b.m).message_type === 1
                        ? quotedOf(b.m).sender?.name || 'You'
                        : contact.name || 'Customer'
                    }}
                  </div>
                  <div class="cs-qt">
                    {{ plain(quotedOf(b.m).content || '') || 'Attachment' }}
                  </div>
                </div>
              </div>

              <template v-if="b.m.attachments && b.m.attachments.length">
                <template v-for="a in b.m.attachments" :key="a.id">
                  <img
                    v-if="aType(a) === 'image' && aUrl(a)"
                    :src="aUrl(a)"
                    class="cs-img"
                    @click.stop="lightbox = aUrl(a)"
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

              <div v-if="reactionsOf(b.m).length" class="cs-rx">
                <span v-for="(r, i) in reactionsOf(b.m)" :key="i" class="cs-rxi">
                  {{ r.emoji || r }}
                  <b v-if="r.count > 1">{{ r.count }}</b>
                </span>
              </div>

              <div class="cs-mt">
                <span>{{ clock(b.m.created_at) }}</span>
                <span
                  v-if="tickOf(b.m)"
                  class="cs-tick"
                  :class="[tickOf(b.m).i, tickOf(b.m).c]"
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

    <!-- ============ FILTERS ============ -->
    <div v-if="showFilter" class="cs-fw" @click.self="showFilter = false">
      <div class="cs-fwb cs-flt">
        <div class="cs-fwh">
          <span class="cs-ic i-lucide-x" @click="showFilter = false" />
          <span>Filter conversations</span>
        </div>
        <div class="cs-fltb">
          <div class="cs-fg">
            <div class="cs-fgl">Status</div>
            <div class="cs-fgo">
              <span
                v-for="o in ['all', 'open', 'pending', 'resolved', 'snoozed']"
                :key="o"
                class="cs-pl"
                :class="{ on: fStatus === o }"
                @click="fStatus = o"
              >
                {{ o }}
              </span>
            </div>
          </div>
          <div class="cs-fg">
            <div class="cs-fgl">Assigned</div>
            <div class="cs-fgo">
              <span
                v-for="o in [
                  { k: 'all', n: 'Anyone' },
                  { k: 'me', n: 'Me' },
                  { k: 'none', n: 'Unassigned' },
                ]"
                :key="o.k"
                class="cs-pl"
                :class="{ on: fAssignee === o.k }"
                @click="fAssignee = o.k"
              >
                {{ o.n }}
              </span>
            </div>
          </div>
          <div class="cs-fg">
            <div class="cs-fgl">Priority</div>
            <div class="cs-fgo">
              <span
                v-for="o in ['all', 'urgent', 'high', 'medium', 'low', 'none']"
                :key="o"
                class="cs-pl"
                :class="{ on: fPriority === o }"
                @click="fPriority = o"
              >
                {{ o }}
              </span>
            </div>
          </div>
          <div class="cs-fg">
            <div class="cs-fgl">Quick</div>
            <div class="cs-fgo">
              <span
                class="cs-pl"
                :class="{ on: fUnreplied }"
                @click="fUnreplied = !fUnreplied"
              >
                Needs reply
              </span>
              <span
                class="cs-pl"
                :class="{ on: fHasAttach }"
                @click="fHasAttach = !fHasAttach"
              >
                Has attachment
              </span>
            </div>
          </div>
        </div>
        <div class="cs-fwf">
          <span class="cs-fwc">{{ rows.length }} chats match</span>
          <button class="cs-fwbtn ghost" @click="clearFilters">Clear</button>
          <button class="cs-fwbtn" @click="showFilter = false">Done</button>
        </div>
      </div>
    </div>

    <!-- ============ IMAGE LIGHTBOX ============ -->
    <div v-if="lightbox" class="cs-lb" @click="lightbox = null">
      <span class="cs-lbx i-lucide-x" />
      <img :src="lightbox" @click.stop />
      <a class="cs-lbd" :href="lightbox" target="_blank" @click.stop>
        <span class="i-lucide-download" />
      </a>
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
        <div class="cs-search cs-fwsr">
          <span class="cs-search__ic i-lucide-search" />
          <input v-model="fwdQ" placeholder="Search name or number" />
          <span v-if="fwdQ" class="cs-search__x i-lucide-x" @click="fwdQ = ''" />
        </div>
        <div class="cs-fwl">
          <div
            v-for="c in fwdRows"
            :key="c.id"
            class="cs-fwr"
            :class="{ on: fwdPick.includes(c.id) }"
            @click="toggleFwd(c.id)"
          >
            <div class="cs-fwav" :style="{ background: colorFor(c.id) }">
              {{ initials(c.meta?.sender?.name) }}
            </div>
            <div class="cs-fwnb">
              <span class="cs-fwn">{{ c.meta?.sender?.name || 'Unknown' }}</span>
              <span v-if="phoneOf(c)" class="cs-fwph">{{ phoneOf(c) }}</span>
            </div>
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
            <span :class="isMuted(currentChat) ? 'i-lucide-bell' : 'i-lucide-bell-off'" />
            <span>{{ isMuted(currentChat) ? 'Unmute' : 'Mute' }}</span>
          </div>
          <div class="cs-pfab" @click="act2('pin')">
            <span class="i-lucide-pin" />
            <span>{{ isPinned(currentChat) ? 'Unpin' : 'Pin' }}</span>
          </div>
          <div class="cs-pfab" @click="act2('archive')">
            <span class="i-lucide-archive" />
            <span>{{ isArchived(currentChat) ? 'Unarchive' : 'Archive' }}</span>
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
      <div class="cs-rxrow">
        <span
          v-for="e in REACTS"
          :key="e"
          class="cs-rxb"
          @click="msgAct('react', e)"
        >
          {{ e }}
        </span>
      </div>
      <hr />
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
        <span>{{ isPinned(menu.chat) ? 'Unpin chat' : 'Pin chat' }}</span>
      </div>
      <div class="cs-mi" @click="act('mute')">
        <span class="i-lucide-bell-off" />
        <span>
          {{ isMuted(menu.chat) ? 'Unmute notifications' : 'Mute notifications' }}
        </span>
      </div>
      <div class="cs-mi" @click="act('archive')">
        <span class="i-lucide-archive" />
        <span>
          {{ isArchived(menu.chat) ? 'Unarchive chat' : 'Archive chat' }}
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
      <div
        class="cs-mi cs-has-sub"
        @click.stop="sub = sub === 'lb' ? '' : 'lb'"
      >
        <span class="i-lucide-tag" /><span>Assign label</span>
        <span class="cs-arw i-lucide-chevron-right" />
        <div v-if="sub === 'lb'" class="cs-sub cs-sub--tall" @click.stop>
          <div class="cs-lbnew">
            <input
              v-model="newLabel"
              placeholder="New label..."
              @keydown.enter.stop="act('newlabel')"
              @click.stop
            />
            <span class="i-lucide-plus" @click.stop="act('newlabel')" />
          </div>
          <div
            v-for="l in labelsList"
            :key="l.id"
            class="cs-mi"
            @click.stop="act('label', l.title)"
          >
            <span class="cs-pld" :style="{ background: l.color }" />
            <span>{{ l.title }}</span>
            <span
              v-if="(menu.chat?.labels || []).includes(l.title)"
              class="cs-arw i-lucide-check"
            />
          </div>
          <div v-if="!labelsList.length" class="cs-mi">
            <span>Koi label nahi — upar likh kar banao</span>
          </div>
        </div>
      </div>
      <div
        class="cs-mi cs-has-sub"
        @click.stop="sub = sub === 'ag' ? '' : 'ag'"
      >
        <span class="i-lucide-user-plus" /><span>Assign agent</span>
        <span class="cs-arw i-lucide-chevron-right" />
        <div v-if="sub === 'ag'" class="cs-sub cs-sub--tall">
          <div class="cs-mi" @click.stop="act('agent', { id: null })">
            <span>Unassign</span>
          </div>
          <div
            v-for="a in agentsList"
            :key="a.id"
            class="cs-mi"
            @click.stop="act('agent', a)"
          >
            <span>{{ a.name }}</span>
          </div>
        </div>
      </div>
      <div
        class="cs-mi cs-has-sub"
        @click.stop="sub = sub === 'tm' ? '' : 'tm'"
      >
        <span class="i-lucide-users" /><span>Assign team</span>
        <span class="cs-arw i-lucide-chevron-right" />
        <div v-if="sub === 'tm'" class="cs-sub cs-sub--tall">
          <div
            v-for="t in teamsList"
            :key="t.id"
            class="cs-mi"
            @click.stop="act('team', t)"
          >
            <span>{{ t.name }}</span>
          </div>
          <div v-if="!teamsList.length" class="cs-mi"><span>No teams</span></div>
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
  --inp: #2a3942;
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
  --fld: #eaeef0;
  --tx: #111b21;
  --tx2: #54656f;
  --tx3: #667781;
  --ln: #d9dfe2;
  --ln2: #e9edef;
  --hov: #f0f2f5;
  --sel: #dee7e4;
  --g: #008069;
  --g-tint: #d6f0e6;
  --b: #027eb5;
  --menu: #ffffff;
  --menu-hov: #eef3f1;
  --sent: #d9fdd3;
  --recv: #ffffff;
  --note: #fff6d6;
  --note-b: #e6d79a;
  --chat: #e3ded7;
  --badge: #25d366;
  --badge-tx: #053e20;
  --inp: #ffffff;
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
  left: calc(100% + 4px);
  top: -7px;
  background: var(--menu);
  border-radius: 8px;
  box-shadow: 0 6px 26px rgba(0, 0, 0, 0.5);
  padding: 7px 0;
  min-width: 186px;
  max-width: 260px;
  z-index: 10000;
  white-space: nowrap;
}
.cs-sub .cs-mi {
  white-space: nowrap;
  padding: 9px 16px !important;
  gap: 10px !important;
}
.cs-hm .cs-sub {
  left: calc(100% + 4px);
  right: auto;
}
.cs-hm.flipL .cs-sub {
  left: auto;
  right: calc(100% + 4px);
}
.cs-app.lite .cs-sub {
  border: 1px solid var(--ln);
  box-shadow: 0 6px 26px rgba(11, 20, 26, 0.18);
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
  width: 20px;
  height: 20px;
  padding: 7px;
  box-sizing: content-box;
  border-radius: 50%;
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
  padding: 6px 9px 7px 10px;
  border-radius: 7.5px;
  box-shadow: var(--sh);
  min-width: 110px;
  cursor: default;
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
  padding-right: 52px;
  letter-spacing: 0.002em;
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
/* target ka exact tareeqa: waqt text ki aakhri line par float
   karta hai, neeche nayi line nahi banata */
.cs-mt {
  font-size: 11px;
  color: var(--tx3);
  float: right;
  margin: -14px -3px -2px 0;
  display: flex;
  align-items: center;
  gap: 3px;
  line-height: 1;
  white-space: nowrap;
}
.cs-msg {
  width: fit-content;
  max-width: 65%;
}
.cs-msg.out.f1::before,
.cs-msg.in.f1::before {
  z-index: 1;
}
/* attachment bubbles: text nahi hota, isliye waqt absolute */
.cs-msg:has(.cs-aud) .cs-mt,
.cs-msg:has(.cs-img) .cs-mt,
.cs-msg:has(.cs-file) .cs-mt {
  float: none;
  position: absolute;
  right: 10px;
  bottom: 6px;
  margin: 0;
}
.cs-msg.in { margin-right: auto; }
.cs-msg.out { margin-left: auto; }
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
  padding: 3px;
  min-width: 0;
}
.cs-msg:has(.cs-img) .cs-mt {
  position: absolute;
  right: 10px;
  bottom: 8px;
  margin: 0;
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
  width: 100%;
  min-width: 0;
  max-width: 100%;
  display: block;
  margin: 2px 0 0;
}
/* :has() ke bagair bhi chale — bubble khud chaudai le */
.cs-msg:has(.cs-aud) {
  width: min(330px, 100%);
}
.cs-msg:has(.cs-aud) .cs-bub {
  padding: 8px 10px 7px;
  min-width: 0;
  width: 100%;
}
.cs-aud :deep(.cs-voice) {
  width: 100% !important;
  min-width: 0 !important;
  max-width: 100% !important;
}
.cs-aud :deep(.cs-voice__wave) {
  flex: 1 1 0 !important;
  min-width: 0 !important;
  overflow: hidden !important;
}
.cs-aud :deep(.cs-voice__row) {
  gap: 10px;
}
.cs-msg .cs-aud :deep(.cs-voice__play),
.cs-aud :deep(button.cs-voice__play) {
  width: 38px !important;
  height: 38px !important;
  min-width: 38px !important;
  flex: 0 0 38px !important;
  opacity: 1 !important;
  border-radius: 50% !important;
  background: rgba(255, 255, 255, 0.12) !important;
  display: grid !important;
  place-items: center !important;
}
.cs-msg .cs-aud :deep(.cs-voice__play *),
.cs-aud :deep(.cs-voice__play svg),
.cs-aud :deep(.cs-voice__play .size-5) {
  width: 24px !important;
  height: 24px !important;
  min-width: 24px !important;
  font-size: 24px !important;
}
.cs-app.lite .cs-aud :deep(.cs-voice__play) {
  background: rgba(0, 0, 0, 0.07) !important;
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
  padding-left: 48px !important;
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
  background: var(--inp);
  border-radius: 24px;
  display: flex !important;
  flex-direction: row !important;
  flex-wrap: nowrap !important;
  align-items: center;
  gap: 12px;
  padding: 11px 17px;
  min-height: 48px;
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
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 20px;
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
.cs-fwh .cs-ic,
.cs-pfh .cs-ic {
  width: 19px;
  height: 19px;
  padding: 7px;
  box-sizing: content-box;
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

/* quoted reply bubble ke andar */
.cs-q {
  display: flex;
  gap: 8px;
  background: rgba(0, 0, 0, 0.22);
  border-radius: 5px;
  padding: 5px 8px;
  margin-bottom: 4px;
  max-height: 58px;
  overflow: hidden;
}
.cs-app.lite .cs-q {
  background: rgba(0, 0, 0, 0.06);
}
.cs-qbar {
  width: 4px;
  border-radius: 3px;
  background: var(--g);
  flex-shrink: 0;
}
.cs-qb {
  min-width: 0;
}
.cs-qn {
  font-size: 12.5px;
  font-weight: 600;
  color: var(--g);
}
.cs-qt {
  font-size: 12.5px;
  color: var(--tx3);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* reactions */
.cs-rx {
  display: flex;
  gap: 3px;
  margin: 3px 0 -2px;
}
.cs-rxi {
  background: var(--head);
  border-radius: 11px;
  padding: 2px 7px;
  font-size: 12.5px;
  display: flex;
  align-items: center;
  gap: 3px;
  box-shadow: var(--sh);
}
.cs-rxi b {
  font-size: 11px;
  color: var(--tx3);
  font-weight: 500;
}

/* labels chip */
.cs-lbs {
  display: flex;
  gap: 4px;
  margin: 0 0 3px;
  overflow: hidden;
}
.cs-lb {
  font-size: 10.5px;
  background: var(--g-tint);
  color: var(--g);
  padding: 1px 7px;
  border-radius: 9px;
  white-space: nowrap;
  flex-shrink: 0;
}

/* typing */
.cs-typ {
  color: var(--g) !important;
  font-style: italic;
}

/* lightbox */
.cs-lb {
  position: fixed;
  inset: 0;
  z-index: 10001;
  background: rgba(0, 0, 0, 0.92);
  display: grid;
  place-items: center;
  cursor: zoom-out;
}
.cs-lb img {
  max-width: 92vw;
  max-height: 88vh;
  object-fit: contain;
  border-radius: 4px;
}
.cs-lbx,
.cs-lbd {
  position: absolute;
  top: 18px;
  width: 26px;
  height: 26px;
  color: #e9edef;
  cursor: pointer;
}
.cs-lbx {
  left: 20px;
}
.cs-lbd {
  right: 20px;
}

/* forward: search + number */
.cs-fwsr {
  margin: 0 14px 8px !important;
}
.cs-fwnb {
  flex: 1;
  min-width: 0;
}
.cs-fwph {
  display: block;
  font-size: 12px;
  color: var(--tx3);
  font-variant-numeric: tabular-nums;
}
.cs-sub--tall {
  max-height: 300px;
  overflow-y: auto;
}

/* pills: label dot + more arrow */
.cs-pld {
  width: 8px;
  height: 8px;
  border-radius: 2px;
  flex-shrink: 0;
}
.cs-plmore {
  padding: 5px 10px !important;
  gap: 4px;
}
.cs-plmore span:first-child {
  width: 15px;
  height: 15px;
}

/* reactions row menu mein */
.cs-rxrow {
  display: flex;
  gap: 2px;
  padding: 6px 10px 8px;
  justify-content: space-between;
}
.cs-rxb {
  font-size: 21px;
  cursor: pointer;
  width: 32px;
  height: 32px;
  display: grid;
  place-items: center;
  border-radius: 50%;
  transition: transform 0.1s, background 0.1s;
}
.cs-rxb:hover {
  background: var(--menu-hov);
  transform: scale(1.18);
}

/* naya label banao */
.cs-lbnew {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 14px;
  border-bottom: 1px solid var(--ln2);
}
.cs-lbnew input {
  flex: 1;
  min-width: 0;
  background: var(--inp);
  border: none;
  outline: none;
  color: var(--tx);
  font-size: 13px;
  font-family: inherit;
  padding: 6px 10px;
  border-radius: 6px;
}
.cs-lbnew span {
  width: 18px;
  height: 18px;
  color: var(--g);
  cursor: pointer;
  flex-shrink: 0;
}

/* header 3-dot menu */
.cs-ph {
  position: relative;
}
.cs-hm {
  position: absolute;
  top: 54px;
  right: 18px;
  z-index: 60;
  background: var(--menu);
  border-radius: 8px;
  box-shadow: 0 4px 22px rgba(0, 0, 0, 0.32);
  padding: 7px 0;
  min-width: 226px;
}
.cs-app.lite .cs-hm,
.cs-app.lite .cs-cmenu {
  box-shadow: 0 4px 22px rgba(11, 20, 26, 0.16);
  border: 1px solid var(--ln);
}

/* select mode */
.cs-phsel {
  gap: 4px;
}
.cs-selh {
  font-size: 16px !important;
  font-weight: 500 !important;
  letter-spacing: 0 !important;
}
.cs-phsel {
  gap: 6px;
  padding: 13px 14px 10px;
}
.cs-sb {
  display: flex;
  align-items: center;
  gap: 6px;
  height: 30px;
  padding: 0 11px;
  border-radius: 15px;
  border: 0;
  background: var(--fld);
  color: var(--tx2);
  font-size: 12.5px;
  font-family: inherit;
  cursor: pointer;
  white-space: nowrap;
  transition: background 0.12s, color 0.12s;
}
.cs-sb span:first-child {
  width: 15px;
  height: 15px;
  flex-shrink: 0;
}
.cs-sb:hover:not(:disabled) {
  background: var(--sel);
  color: var(--tx);
}
.cs-sb.dgr {
  color: var(--red);
}
.cs-sb:disabled {
  opacity: 0.35;
  cursor: default;
}
.cs-phsel .cs-ic {
  width: 17px;
  height: 17px;
  padding: 8px;
  box-sizing: content-box;
}
.cs-phsel::after {
  display: none;
}
.cs-ic.off {
  opacity: 0.32;
  pointer-events: none;
}
.cs-ic.dgr {
  color: var(--red);
}
.cs-ck {
  width: 22px;
  height: 22px;
  color: var(--tx3);
  flex-shrink: 0;
}
.cs-ck.on {
  color: var(--g);
}

/* light mode: bubbles aur panel ko kinara do */
.cs-app.lite .cs-bub {
  box-shadow: 0 1px 0.5px rgba(11, 20, 26, 0.13);
}
.cs-app.lite .cs-day,
.cs-app.lite .cs-sysm {
  background: #ffffff;
  color: #54656f;
  box-shadow: 0 1px 0.5px rgba(11, 20, 26, 0.13);
}
.cs-app.lite .cs-panel {
  border-right: 1px solid var(--ln);
}
.cs-app.lite .cs-th {
  border-bottom: 1px solid var(--ln);
}
.cs-app.lite .cs-comp {
  border-top: 1px solid var(--ln);
}
.cs-app.lite .cs-cbar {
  box-shadow: 0 1px 2px rgba(11, 20, 26, 0.08);
}
.cs-app.lite .cs-un {
  color: #ffffff;
}
.cs-app.lite .cs-rxi,
.cs-app.lite .cs-q {
  background: #f0f2f5;
}

/* tick: asli status */
.cs-tick {
  color: var(--tx3);
  width: 15px;
  height: 15px;
  flex-shrink: 0;
}
.cs-tick.blue {
  color: var(--b);
}
.cs-tick.err {
  color: var(--red);
}
.cs-mt .cs-tick {
  width: 14px;
  height: 14px;
}

/* filter panel */
.cs-flt {
  width: 440px;
}
.cs-fltb {
  flex: 1;
  overflow-y: auto;
  padding: 6px 18px 14px;
}
.cs-fg {
  padding: 12px 0;
  border-bottom: 1px solid var(--ln2);
}
.cs-fg:last-child {
  border-bottom: none;
}
.cs-fgl {
  font-size: 12.5px;
  color: var(--g);
  margin-bottom: 9px;
  font-weight: 500;
}
.cs-fgo {
  display: flex;
  flex-wrap: wrap;
  gap: 7px;
}
.cs-fgo .cs-pl {
  text-transform: capitalize;
  user-select: none;
}
.cs-fgo .cs-pl.on::before {
  content: '✓';
  font-size: 11px;
  margin-right: 2px;
}
.cs-fcn {
  margin-left: auto;
  background: var(--g);
  color: #fff;
  font-size: 11px;
  min-width: 18px;
  height: 18px;
  border-radius: 9px;
  display: grid;
  place-items: center;
  padding: 0 5px;
}
.cs-fwbtn.ghost {
  background: transparent;
  color: var(--tx2);
  border: 1px solid var(--ln);
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
  .cs-msg:has(.cs-aud) {
    width: min(330px, 84%);
  }
  .cs-lb img {
    max-width: 98vw;
  }
  .cs-fwb {
    max-height: 88vh;
  }
  .cs-cbar {
    padding: 9px 13px;
  }
  .cs-comp {
    padding: 7px 8px calc(env(safe-area-inset-bottom, 0px) + 14px);
  }
  .cs-cbar {
    border-radius: 24px;
    min-height: 46px;
    gap: 12px;
    padding: 10px 15px;
  }
  .cs-msg {
    max-width: 84%;
  }
  .cs-snd2,
  .cs-ci {
    width: 22px;
    height: 22px;
    min-width: 22px;
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
