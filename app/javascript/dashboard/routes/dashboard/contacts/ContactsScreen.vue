<script setup>
/* =====================================================================
   ContactsScreen.vue  —  ChatsSync ka apna Contacts tab
   chatssync-v16.html ka markup, Chatwoot ka data.
   Chatwoot ke ContactsTable / ContactInfoPanel yahan use NAHI hote.

   Data seedha REST API se aata hai (store ke action ke naam har
   version mein badalte hain). Har call authHeaders() se jaati hai —
   wahi tareeqa jo ChatsScreen ke labels mein chala.
   ===================================================================== */
import { ref, computed, watch, onMounted, onBeforeUnmount, nextTick } from 'vue';
import { useStore } from 'vuex';
import { useRouter } from 'vue-router';
import { useMapGetter } from 'dashboard/composables/store.js';

const store = useStore();
const router = useRouter();

const accountId = useMapGetter('getCurrentAccountId');
const currentUser = useMapGetter('getCurrentUser');
const labelsList = useMapGetter('labels/getLabels');
const inboxesList = useMapGetter('inboxes/getInboxes');

/* ---------------- safe dispatch ---------------- */
const warned = {};
const has = name => !!(store._actions && store._actions[name]);
const safeD = (name, payload) => {
  if (!has(name)) {
    if (!warned[name]) {
      warned[name] = 1;
      console.warn('[ChatsSync] action not found:', name);
    }
    return Promise.resolve(null);
  }
  try {
    const r = store.dispatch(name, payload);
    return r && typeof r.then === 'function' ? r : Promise.resolve(r);
  } catch (e) {
    console.warn('[ChatsSync] dispatch failed:', name, e);
    return Promise.reject(e);
  }
};

/* ---------------- API ---------------- */
const authHeaders = () => {
  const h = { 'Content-Type': 'application/json' };
  try {
    const raw = (document.cookie.match(
      /(?:^|;\s*)cw_d_session_info=([^;]+)/
    ) || [])[1];
    if (raw) {
      let txt = decodeURIComponent(raw);
      if (txt.charAt(0) === 'j' && txt.charAt(1) === ':') txt = txt.slice(2);
      const sess = JSON.parse(txt);
      if (sess['access-token']) {
        h['access-token'] = sess['access-token'];
        h['token-type'] = sess['token-type'] || 'Bearer';
        h.client = sess.client;
        h.expiry = sess.expiry;
        h.uid = sess.uid;
        h.api_access_token = sess['access-token'];
      }
    }
  } catch (e) {
    /* ignore */
  }
  const tok = currentUser.value?.access_token;
  if (tok) h.api_access_token = tok;
  return h;
};

const api = (path, opts = {}) =>
  fetch(`/api/v1/accounts/${accountId.value}${path}`, {
    credentials: 'same-origin',
    headers: authHeaders(),
    ...opts,
  }).then(r => {
    if (!r.ok) throw new Error(`${opts.method || 'GET'} ${path} → ${r.status}`);
    return r.status === 204 ? null : r.json();
  });

/* ---------------- state ---------------- */
const contacts = ref([]);
const loading = ref(true);
const loadingMore = ref(false);
const page = ref(1);
const noMore = ref(false);

const q = ref('');
const filt = ref('all');
const selected = ref(null);
const convs = ref([]);
const convsLoading = ref(false);

const isMobile = ref(window.innerWidth <= 768);
const isLight = ref(false);
const showAllPills = ref(false);

/* date-added filter */
const dFrom = ref(null);
const dTo = ref(null);
const dLabel = ref('any time');

/* menus */
const hmenu = ref(false);
const hsub = ref('');
const cmenu = ref(false);
const csub = ref('');
const lblMenu = ref(false);

/* ---------------- helpers ---------------- */
const initials = name =>
  (name || '?')
    .trim()
    .split(/\s+/)
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

const MONTHS = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const ymd = d =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(
    d.getDate()
  ).padStart(2, '0')}`;
const daysAgo = n => {
  const d = new Date();
  d.setDate(d.getDate() - n);
  return d;
};
const fmtYmd = str => {
  if (!str) return '';
  const p = String(str).split('-');
  return `${+p[2]} ${MONTHS[+p[1] - 1]} ${p[0]}`;
};
const fmtStamp = ts => {
  if (!ts) return '';
  const d = new Date(Number(ts) * 1000);
  if (Number.isNaN(d.getTime())) return '';
  return `${d.getDate()} ${MONTHS[d.getMonth()]} ${d.getFullYear()}`;
};
const seenOf = c => {
  const ts = c?.last_activity_at;
  if (!ts) return 'Never';
  const d = new Date(Number(ts) * 1000);
  const now = new Date();
  const mins = Math.floor((now - d) / 60000);
  if (mins < 1) return 'Just now';
  if (mins < 60) return `${mins} min ago`;
  if (d.toDateString() === now.toDateString())
    return d.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' });
  const y = new Date(now);
  y.setDate(y.getDate() - 1);
  if (d.toDateString() === y.toDateString()) return 'Yesterday';
  const days = Math.floor((now - d) / 86400000);
  if (days < 7) return d.toLocaleDateString(undefined, { weekday: 'long' });
  return fmtStamp(ts);
};
const createdYmd = c => {
  const ts = c?.created_at;
  if (!ts) return '';
  return ymd(new Date(Number(ts) * 1000));
};

const attrs = c => c?.additional_attributes || {};
const phoneOf = c => c?.phone_number || '';
const emailOf = c => c?.email || '';
const cityOf = c => attrs(c).city || '';
const countryOf = c => attrs(c).country || '';
const companyOf = c => attrs(c).company_name || '';
const bioOf = c => attrs(c).description || '';

/* channel_type se kism nikalo — inbox ka naam kuch bhi ho,
   rang channel ka hi rahega (WhatsApp hara, Facebook neela, ...) */
const chKind = t => {
  const s0 = String(t || '');
  if (/Whatsapp/i.test(s0)) return 'wa';
  if (/FacebookPage/i.test(s0)) return 'fb';
  if (/Instagram/i.test(s0)) return 'ig';
  if (/Sms|Twilio/i.test(s0)) return 'sms';
  if (/Telegram/i.test(s0)) return 'tg';
  if (/Email/i.test(s0)) return 'em';
  if (/WebWidget/i.test(s0)) return 'web';
  if (/Api/i.test(s0)) return 'api';
  return 'other';
};
const CH_COLOR = {
  wa: '#25D366',
  fb: '#0866FF',
  ig: '#E1306C',
  sms: '#7C4DFF',
  tg: '#26A5E4',
  em: '#F59E0B',
  web: '#0EA5E9',
  api: '#94A3B8',
  other: '#8696A0',
};
const CH_NAME = {
  wa: 'WhatsApp',
  fb: 'Facebook',
  ig: 'Instagram',
  sms: 'SMS',
  tg: 'Telegram',
  em: 'Email',
  web: 'Website',
  api: 'API',
  other: 'Channel',
};
const CH_TAG = {
  wa: 'WA', fb: 'FB', ig: 'IG', sms: 'SMS',
  tg: 'TG', em: 'MAIL', web: 'WEB', api: 'API', other: '',
};

const inboxesOf = c =>
  (c?.contact_inboxes || []).map(x => x.inbox).filter(Boolean);
const inboxIdsOf = c => inboxesOf(c).map(ib => ib.id).filter(Boolean);
const chOf = c => {
  const ib = inboxesOf(c)[0];
  return ib ? chKind(ib.channel_type) : '';
};
const chChip = c => {
  const k = chOf(c);
  if (!k || !CH_TAG[k]) return null;
  return { k, t: CH_TAG[k], color: CH_COLOR[k] };
};
const inboxOf = c => inboxesOf(c)[0]?.name || '';
const isActive = c => (c?.availability_status || '') === 'online';
const labelsOf = c => (Array.isArray(c?.labels) ? c.labels : []);
const subOf = c => phoneOf(c) || emailOf(c) || cityOf(c) || companyOf(c) || '—';

/* ---------------- toast + confirm ---------------- */
const toasts = ref([]);
let toastId = 0;
const toast = (text, kind = 'ok') => {
  const id = ++toastId;
  toasts.value.push({ id, text, kind });
  setTimeout(() => {
    toasts.value = toasts.value.filter(t => t.id !== id);
  }, 3200);
};

const ask = ref(null);
const confirmBox = (title, body, okText, onOk, danger = true) => {
  ask.value = {
    title,
    body,
    okText: okText || 'Confirm',
    danger,
    ok: () => {
      ask.value = null;
      onOk?.();
    },
    cancel: () => {
      ask.value = null;
    },
  };
};

/* ---------------- load ---------------- */
const mergeContacts = (list, reset) => {
  const incoming = (list || []).filter(c => c && c.id);
  if (reset) {
    contacts.value = incoming;
    return;
  }
  const seen = new Set(contacts.value.map(c => c.id));
  contacts.value = [...contacts.value, ...incoming.filter(c => !seen.has(c.id))];
};

const fetchPage = (p, reset = false) => {
  const term = q.value.trim();
  const path = term
    ? `/contacts/search?q=${encodeURIComponent(term)}&page=${p}&sort=name`
    : `/contacts?page=${p}&sort=name`;
  return api(path)
    .then(res => {
      const list = res?.payload || [];
      mergeContacts(list, reset);
      if (!list.length) noMore.value = true;
      else page.value = p;
      return list;
    })
    .catch(err => {
      console.warn('[ChatsSync] contacts load failed', err);
      if (reset) contacts.value = [];
      noMore.value = true;
      toast('Could not load contacts', 'err');
      return [];
    });
};

const reload = () => {
  loading.value = true;
  noMore.value = false;
  page.value = 1;
  fetchPage(1, true).finally(() => {
    loading.value = false;
  });
};

const onListScroll = e => {
  const el = e.target;
  if (
    el.scrollHeight - el.scrollTop - el.clientHeight < 260 &&
    !loadingMore.value &&
    !loading.value &&
    !noMore.value
  ) {
    loadingMore.value = true;
    fetchPage(page.value + 1).finally(() => {
      loadingMore.value = false;
    });
  }
};

/* search — server par bhi, 350ms rukh kar */
let qTimer = null;
watch(q, () => {
  clearTimeout(qTimer);
  qTimer = setTimeout(reload, 350);
});

/* ---------------- filter + group ---------------- */
const rows = computed(() => {
  const k = q.value.trim().toLowerCase();
  let L = [...contacts.value];

  if (k) {
    L = L.filter(c =>
      `${c.name || ''} ${phoneOf(c)} ${emailOf(c)} ${cityOf(c)} ${companyOf(c)}`
        .toLowerCase()
        .includes(k)
    );
  }
  const f = filt.value;
  if (f === 'active') L = L.filter(isActive);
  else if (f.startsWith('in-')) {
    const id = Number(f.slice(3));
    L = L.filter(c => inboxIdsOf(c).includes(id));
  } else if (f.startsWith('lb-')) {
    const t = f.slice(3);
    L = L.filter(c => labelsOf(c).includes(t));
  }
  if (dFrom.value) L = L.filter(c => createdYmd(c) >= dFrom.value);
  if (dTo.value) L = L.filter(c => createdYmd(c) <= dTo.value);

  return L.sort((a, b) =>
    String(a.name || '').localeCompare(String(b.name || ''))
  );
});

/* A-Z index — har harf ka apna sar */
const grouped = computed(() => {
  const out = [];
  let letter = null;
  rows.value.forEach(c => {
    const L0 = (String(c.name || '#').trim()[0] || '#').toUpperCase();
    if (L0 !== letter) {
      letter = L0;
      out.push({ kind: 'idx', id: `i${L0}-${c.id}`, letter: L0 });
    }
    out.push({ kind: 'row', id: c.id, c });
  });
  return out;
});

/* Pills: All / Active + HAR ASAL INBOX (jo account mein juRa hai)
   + har label. Inbox ka apna naam, rang uske channel ka. */
const pills = computed(() => {
  const base = [
    { k: 'all', n: 'All' },
    { k: 'active', n: 'Active' },
  ];
  (inboxesList.value || []).forEach(ib => {
    base.push({
      k: `in-${ib.id}`,
      n: ib.name,
      dot: CH_COLOR[chKind(ib.channel_type)],
    });
  });
  (labelsList.value || []).forEach(l => {
    base.push({ k: `lb-${l.title}`, n: l.title, dot: l.color || '#00A884' });
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

const activeFilters = computed(() => {
  let n = 0;
  if (filt.value !== 'all') n += 1;
  if (dFrom.value || dTo.value) n += 1;
  return n;
});

/* ---------------- calendar ---------------- */
const showCal = ref(false);
const calMonth = ref(new Date());
const calFrom = ref(null);
const calTo = ref(null);
const pickStage = ref(0);
const QUICK = [
  { n: 'Any time', d: null },
  { n: 'Today', d: 0 },
  { n: 'Last 7 days', d: 7 },
  { n: 'Last 30 days', d: 30 },
  { n: 'Last 3 months', d: 90 },
  { n: 'Custom', d: -1 },
];
const quickPick = ref('Any time');

const calDays = computed(() => {
  const m = calMonth.value;
  const first = new Date(m.getFullYear(), m.getMonth(), 1);
  const start = new Date(first);
  start.setDate(1 - first.getDay());
  const out = [];
  for (let i = 0; i < 42; i += 1) {
    const d = new Date(start);
    d.setDate(start.getDate() + i);
    out.push({
      key: ymd(d),
      day: d.getDate(),
      mut: d.getMonth() !== m.getMonth(),
    });
  }
  return out;
});
const calTitle = computed(
  () => `${MONTHS[calMonth.value.getMonth()]} ${calMonth.value.getFullYear()}`
);
const calMove = n => {
  const d = new Date(calMonth.value);
  d.setMonth(d.getMonth() + n);
  calMonth.value = d;
};
const dayCls = key => ({
  sel: key === calFrom.value || key === calTo.value,
  rng:
    calFrom.value &&
    calTo.value &&
    key > calFrom.value &&
    key < calTo.value,
});
const pickDay = key => {
  if (pickStage.value === 0 || (calFrom.value && calTo.value)) {
    calFrom.value = key;
    calTo.value = null;
    pickStage.value = 1;
    quickPick.value = 'Custom';
  } else if (key < calFrom.value) {
    calTo.value = calFrom.value;
    calFrom.value = key;
    pickStage.value = 0;
  } else {
    calTo.value = key;
    pickStage.value = 0;
  }
};
const pickQuick = qk => {
  quickPick.value = qk.n;
  if (qk.d === null) {
    calFrom.value = null;
    calTo.value = null;
  } else if (qk.d === -1) {
    pickStage.value = 0;
  } else if (qk.d === 0) {
    calFrom.value = ymd(new Date());
    calTo.value = ymd(new Date());
  } else {
    calFrom.value = ymd(daysAgo(qk.d));
    calTo.value = ymd(new Date());
  }
};
const calApply = () => {
  dFrom.value = calFrom.value;
  dTo.value = calTo.value;
  if (!calFrom.value && !calTo.value) dLabel.value = 'any time';
  else if (calFrom.value && calTo.value && calFrom.value === calTo.value)
    dLabel.value = fmtYmd(calFrom.value);
  else if (calFrom.value && calTo.value)
    dLabel.value = `${fmtYmd(calFrom.value)} – ${fmtYmd(calTo.value)}`;
  else dLabel.value = `after ${fmtYmd(calFrom.value)}`;
  showCal.value = false;
};
const calClear = () => {
  calFrom.value = null;
  calTo.value = null;
  pickStage.value = 0;
  quickPick.value = 'Any time';
  dFrom.value = null;
  dTo.value = null;
  dLabel.value = 'any time';
};
const openCal = () => {
  closeAll();
  calFrom.value = dFrom.value;
  calTo.value = dTo.value;
  showCal.value = true;
};

/* ---------------- select + detail ---------------- */
const openContact = c => {
  selected.value = c;
  convs.value = [];
  cmenu.value = false;
  csub.value = '';
  if (!c?.id) return;
  convsLoading.value = true;
  api(`/contacts/${c.id}/conversations`)
    .then(res => {
      convs.value = res?.payload || [];
    })
    .catch(() => {
      convs.value = [];
    })
    .finally(() => {
      convsLoading.value = false;
    });
  // taaza data (labels, attributes) le lo
  api(`/contacts/${c.id}`)
    .then(res => {
      const full = res?.payload;
      if (full && selected.value?.id === full.id) {
        selected.value = { ...c, ...full };
        const i = contacts.value.findIndex(x => x.id === full.id);
        if (i >= 0) contacts.value[i] = { ...contacts.value[i], ...full };
      }
    })
    .catch(() => {});
};

const backToList = () => {
  selected.value = null;
};

const openConversation = cv => {
  if (!cv?.id) return;
  router.push({
    name: 'inbox_conversation',
    params: { accountId: accountId.value, conversation_id: cv.id },
  });
};

const msgContact = c => {
  if (convs.value.length) {
    openConversation(convs.value[0]);
    return;
  }
  api(`/contacts/${c.id}/conversations`)
    .then(res => {
      const list = res?.payload || [];
      if (list.length) openConversation(list[0]);
      else toast('No conversation yet with this contact');
    })
    .catch(() => toast('Could not open conversation', 'err'));
};

/* ---------------- labels ---------------- */
const lp = ref({ open: false, sel: [], q: '' });
const newLabel = ref('');

const lpOpen = () => {
  closeAll();
  lp.value = { open: true, sel: [...labelsOf(selected.value)], q: '' };
};
const lpHits = computed(() => {
  const k = lp.value.q.trim().toLowerCase();
  const L = labelsList.value || [];
  return k ? L.filter(l => (l.title || '').toLowerCase().includes(k)) : L;
});

const applyContactLabels = (c, list) => {
  if (!c?.id) return Promise.reject(new Error('no contact'));
  const next = [...new Set((list || []).filter(Boolean))];
  const prev = labelsOf(c);
  const put = obj => {
    if (!obj) return;
    obj.labels = next;
  };
  put(selected.value?.id === c.id ? selected.value : null);
  const i = contacts.value.findIndex(x => x.id === c.id);
  if (i >= 0) contacts.value[i] = { ...contacts.value[i], labels: next };

  return api(`/contacts/${c.id}/labels`, {
    method: 'POST',
    body: JSON.stringify({ labels: next }),
  }).catch(err => {
    put(selected.value?.id === c.id ? selected.value : null);
    if (i >= 0) contacts.value[i] = { ...contacts.value[i], labels: prev };
    if (selected.value?.id === c.id) selected.value.labels = prev;
    throw err;
  });
};

const lpToggle = t => {
  const sel = [...lp.value.sel];
  const i = sel.indexOf(t);
  if (i >= 0) sel.splice(i, 1);
  else sel.push(t);
  lp.value.sel = sel;
  applyContactLabels(selected.value, sel)
    .then(() => toast(i >= 0 ? `"${t}" removed` : `"${t}" added`))
    .catch(() => {
      lp.value.sel = [...labelsOf(selected.value)];
      toast('Could not update labels', 'err');
    });
};

const lpNew = () => {
  const t = (newLabel.value || lp.value.q || '')
    .trim()
    .replace(/\s+/g, '-')
    .toLowerCase();
  if (!t) return;
  newLabel.value = '';
  lp.value.q = '';
  const after = () => {
    safeD('labels/get');
    if (!lp.value.sel.includes(t)) lpToggle(t);
  };
  const exists = (labelsList.value || []).some(l => l.title === t);
  if (exists) after();
  else
    safeD('labels/create', { title: t, color: '#00A884' })
      .then(after)
      .catch(after);
};

const dropLabel = t => {
  const next = labelsOf(selected.value).filter(x => x !== t);
  applyContactLabels(selected.value, next)
    .then(() => toast(`Label "${t}" removed`))
    .catch(() => toast('Could not remove label', 'err'));
};

/* ---------------- create / edit ---------------- */
const edit = ref(null);
const saving = ref(false);

const openEdit = c => {
  closeAll();
  edit.value = {
    id: c?.id || null,
    name: c?.name || '',
    phone_number: phoneOf(c),
    email: emailOf(c),
    company_name: companyOf(c),
    city: cityOf(c),
    country: countryOf(c),
    description: bioOf(c),
  };
};

const saveContact = () => {
  const e = edit.value;
  if (!e) return;
  if (!e.name.trim()) {
    toast('Name is required', 'err');
    return;
  }
  const body = {
    name: e.name.trim(),
    email: e.email.trim() || null,
    // phone_number jaan-boojh kar nahi bheja — woh WhatsApp identity hai,
    // badalne se conversation ka rishta toot jaata hai
    additional_attributes: {
      company_name: e.company_name.trim(),
      city: e.city.trim(),
      country: e.country.trim(),
      description: e.description.trim(),
    },
  };
  saving.value = true;
  const req = e.id
    ? api(`/contacts/${e.id}`, { method: 'PATCH', body: JSON.stringify(body) })
    : api('/contacts', { method: 'POST', body: JSON.stringify(body) });

  req
    .then(res => {
      const saved = res?.payload?.contact || res?.payload || null;
      toast(e.id ? 'Contact updated' : 'Contact created');
      edit.value = null;
      if (saved && saved.id) {
        const i = contacts.value.findIndex(x => x.id === saved.id);
        if (i >= 0) contacts.value[i] = { ...contacts.value[i], ...saved };
        else contacts.value = [saved, ...contacts.value];
        if (!e.id || selected.value?.id === saved.id) openContact(saved);
      } else {
        reload();
      }
    })
    .catch(err => {
      console.warn('[ChatsSync] save contact failed', err);
      toast('Could not save contact', 'err');
    })
    .finally(() => {
      saving.value = false;
    });
};

const deleteContact = c => {
  if (!c?.id) return;
  confirmBox(
    'Delete contact',
    `Delete ${c.name || 'this contact'}? Their conversations stay, but the contact record is removed. This cannot be undone.`,
    'Delete',
    () => {
      api(`/contacts/${c.id}`, { method: 'DELETE' })
        .then(() => {
          contacts.value = contacts.value.filter(x => x.id !== c.id);
          if (selected.value?.id === c.id) selected.value = null;
          toast('Contact deleted');
        })
        .catch(() => toast('Could not delete contact', 'err'));
    }
  );
};

/* ---------------- import ---------------- */
const importInput = ref(null);
const importing = ref(false);

const pickImport = () => {
  hmenu.value = false;
  importInput.value?.click();
};

const onImportFile = e => {
  const file = e.target.files?.[0];
  e.target.value = '';
  if (!file) return;
  const fd = new FormData();
  fd.append('import_file', file);
  // FormData ke saath Content-Type khud browser set karta hai
  // (boundary ke saath) — apna bhejenge to server parse nahi kar payega
  const h = authHeaders();
  delete h['Content-Type'];
  importing.value = true;
  toast('Uploading — import background mein chalta hai');
  fetch(`/api/v1/accounts/${accountId.value}/contacts/import`, {
    method: 'POST',
    credentials: 'same-origin',
    headers: h,
    body: fd,
  })
    .then(r => {
      if (!r.ok) throw new Error('import ' + r.status);
      toast('Import started — contacts thoRi der mein aa jayenge');
      setTimeout(reload, 5000);
    })
    .catch(err => {
      console.warn('[ChatsSync] import failed', err);
      toast('Import failed — CSV ke columns check karo', 'err');
    })
    .finally(() => {
      importing.value = false;
    });
};

const sampleCsv = () => {
  hmenu.value = false;
  const head = 'name,email,phone_number,company_name,city,country,identifier';
  const row = 'Ali Khan,ali@example.com,+923001234567,Al-Noor Clinic,Faisalabad,Pakistan,';
  const blob = new Blob(['\ufeff' + head + '\n' + row], {
    type: 'text/csv;charset=utf-8',
  });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = 'contacts-sample.csv';
  a.style.display = 'none';
  document.body.appendChild(a);
  a.click();
  setTimeout(() => {
    try {
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
    } catch (err) {
      /* ignore */
    }
  }, 1500);
};

/* ---------------- export ---------------- */
const exportCsv = () => {
  hmenu.value = false;
  const list = rows.value;
  if (!list.length) {
    toast('Nothing to export', 'err');
    return;
  }
  const esc = v => `"${String(v == null ? '' : v).replace(/"/g, '""')}"`;
  const head = [
    'Name', 'Phone', 'Email', 'Company', 'City', 'Country',
    'Channel', 'Inbox', 'Labels', 'Added on', 'Last seen',
  ];
  const lines = [head.map(esc).join(',')];
  list.forEach(c => {
    lines.push(
      [
        c.name, phoneOf(c), emailOf(c), companyOf(c), cityOf(c), countryOf(c),
        CH_NAME[chOf(c)] || '', inboxOf(c), labelsOf(c).join(' '),
        fmtStamp(c.created_at), seenOf(c),
      ]
        .map(esc)
        .join(',')
    );
  });
  const blob = new Blob(['\ufeff' + lines.join('\n')], {
    type: 'text/csv;charset=utf-8',
  });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `contacts-${ymd(new Date())}.csv`;
  a.style.display = 'none';
  document.body.appendChild(a);
  a.click();
  setTimeout(() => {
    try {
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
    } catch (err) {
      /* ignore */
    }
  }, 1500);
  toast(`${list.length} contact(s) exported`);
};

/* ---------------- menus ---------------- */
const closeAll = () => {
  hmenu.value = false;
  hsub.value = '';
  cmenu.value = false;
  csub.value = '';
  lblMenu.value = false;
  showCal.value = false;
};
const toggleHm = () => {
  const w = hmenu.value;
  closeAll();
  hmenu.value = !w;
};
const toggleCm = () => {
  const w = cmenu.value;
  closeAll();
  cmenu.value = !w;
};
const toggleLblMenu = () => {
  const w = lblMenu.value;
  closeAll();
  lblMenu.value = !w;
};
const pickPillLabel = title => {
  filt.value = `lb-${title}`;
  lblMenu.value = false;
};

const clearAll = () => {
  filt.value = 'all';
  q.value = '';
  calClear();
  toast('Filters cleared');
};

/* ---------------- rail (mobile drawer) ---------------- */
const railOpen = ref(false);
/* Rail ab Sidebar.vue khud sambhalta hai.
   PEHLE closeRail() har document click par aside par Tailwind ki class
   'ltr:-translate-x-full' laga deta tha (= translateX(-100%)), isliye
   sidebar khul kar agle click par hi gaayab ho jaati thi. */
const openRail = () => {
  window.dispatchEvent(new CustomEvent('chatssync:toggle-rail'));
};
const closeRail = () => {
  railOpen.value = false;
};

const closeEverything = () => {
  closeAll();
  closeRail();
};

/* ---------------- lifecycle ---------------- */
let themeObs = null;
const onResize = () => {
  isMobile.value = window.innerWidth <= 768;
};
const readTheme = () => {
  isLight.value = !(
    document.documentElement.classList.contains('dark') ||
    document.body.classList.contains('dark')
  );
};
const onHotkey = e => {
  if (e.key === 'Escape') {
    closeAll();
    if (lp.value.open) lp.value.open = false;
    else if (edit.value) edit.value = null;
    else if (ask.value) ask.value.cancel();
    else if (selected.value && isMobile.value) selected.value = null;
  }
  if ((e.ctrlKey || e.metaKey) && (e.key === 'k' || e.key === 'K')) {
    e.preventDefault();
    document.querySelector('.cs-psr input')?.focus();
  }
};

onMounted(() => {
  document.body.classList.add('cs-own-header');
  closeRail();
  safeD('labels/get');
  safeD('inboxes/get');
  reload();
  document.addEventListener('click', closeEverything);
  document.addEventListener('keydown', onHotkey);
  window.addEventListener('resize', onResize);
  readTheme();
  themeObs = new MutationObserver(readTheme);
  themeObs.observe(document.documentElement, {
    attributes: true,
    attributeFilter: ['class'],
    subtree: true,
  });
});

onBeforeUnmount(() => {
  document.body.classList.remove('cs-own-header');
  document.removeEventListener('click', closeEverything);
  document.removeEventListener('keydown', onHotkey);
  window.removeEventListener('resize', onResize);
  if (themeObs) {
    themeObs.disconnect();
    themeObs = null;
  }
  clearTimeout(qTimer);
  toasts.value = [];
  closeRail();
});

/* mobile par detail khulte hi list chhup jaati hai */
const detailOpen = computed(() => !!selected.value);
watch(detailOpen, v => {
  if (v) nextTick(() => window.scrollTo(0, 0));
});
</script>

<template>
  <section
    class="cs-app cs-cts"
    :class="{ mob: isMobile, lite: isLight, det: detailOpen }"
  >
    <!-- ============ LEFT: CONTACTS PANEL ============ -->
    <div class="cs-panel">
      <div class="cs-ph">
        <span
          v-if="isMobile"
          class="cs-ic cs-ham"
          title="Menu"
          @click.stop="openRail"
        >
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M4 6h16M4 12h16M4 18h16" stroke-linecap="round" />
          </svg>
        </span>
        <h1>Contacts</h1>
        <span class="cs-ic" title="New contact" @click.stop="openEdit(null)">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M12 5v14M5 12h14" stroke-linecap="round" />
          </svg>
        </span>
        <span class="cs-ic" title="More" @click.stop="toggleHm">
          <svg viewBox="0 0 24 24" fill="currentColor">
            <circle cx="12" cy="5" r="1.6" />
            <circle cx="12" cy="12" r="1.6" />
            <circle cx="12" cy="19" r="1.6" />
          </svg>
        </span>
        <input
          ref="importInput"
          type="file"
          accept=".csv,text/csv"
          hidden
          @change="onImportFile"
        />

        <div v-if="hmenu" class="cs-hm" @click.stop>
          <div class="cs-mi" @click="pickImport">
            <span class="i-lucide-upload" />
            <span>{{ importing ? 'Importing…' : 'Import contacts (CSV)' }}</span>
          </div>
          <div class="cs-mi" @click="exportCsv">
            <span class="i-lucide-download" /><span>Export contacts (CSV)</span>
          </div>
          <div class="cs-mi" @click="sampleCsv">
            <span class="i-lucide-file-text" /><span>Download sample CSV</span>
          </div>
          <div
            class="cs-mi"
            @click="
              hmenu = false;
              openEdit(null);
            "
          >
            <span class="i-lucide-user-plus" /><span>New contact</span>
          </div>
          <div class="cs-sep" />
          <div
            class="cs-mi cs-has-sub"
            @click.stop="hsub = hsub === 'sort' ? '' : 'sort'"
          >
            <span class="i-lucide-arrow-down-up" /><span>Sorted by</span>
            <span class="cs-arw i-lucide-chevron-right" />
            <div v-if="hsub === 'sort'" class="cs-sub" @click.stop>
              <div class="cs-mi on"><span>Name (A–Z)</span></div>
            </div>
          </div>
          <div
            class="cs-mi"
            @click="
              hmenu = false;
              reload();
            "
          >
            <span class="i-lucide-rotate-cw" /><span>Refresh list</span>
          </div>
          <div v-if="activeFilters" class="cs-sep" />
          <div
            v-if="activeFilters"
            class="cs-mi"
            @click="
              hmenu = false;
              clearAll();
            "
          >
            <span class="i-lucide-filter-x" /><span>Clear filters</span>
          </div>
        </div>
      </div>

      <div class="cs-search cs-psr" :class="{ act: q }">
        <span class="cs-search__ic i-lucide-search" />
        <input v-model="q" placeholder="Search name, phone, email or city" />
        <span v-if="q" class="cs-search__x i-lucide-x" @click="q = ''" />
      </div>

      <div class="cs-pillwrap">
      <div class="cs-pills">
        <div
          v-for="p in visiblePills"
          :key="p.k"
          class="cs-pl"
          :class="{ on: filt === p.k }"
          @click="filt = p.k"
        >
          <span v-if="p.dot" class="cs-pld" :style="{ background: p.dot }" />
          <span>{{ p.n }}</span>
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
        <div class="cs-pl cs-pltag" title="Filter by label" @click.stop="toggleLblMenu">
          <span class="i-lucide-tag" />
        </div>
      </div>
      <div v-if="lblMenu" class="cs-cmenu cs-lblmenu" @click.stop>
        <div class="cs-mt2">Filter by label</div>
        <div
          v-for="l in labelsList || []"
          :key="l.id || l.title"
          class="cs-mi"
          @click="pickPillLabel(l.title)"
        >
          <span class="cs-pld" :style="{ background: l.color || '#00A884' }" />
          <span>{{ l.title }}</span>
        </div>
        <div v-if="!(labelsList || []).length" class="cs-agempty">
          No labels yet
        </div>
      </div>
      </div>

      <div class="cs-dchip" :class="{ act: dFrom || dTo }" @click.stop="openCal">
        <span class="i-lucide-calendar" />
        <span class="cs-dv">Added: {{ dLabel }}</span>
        <span class="i-lucide-chevron-down" />
      </div>

      <div class="cs-list" @scroll.passive="onListScroll">
        <div v-if="loading" class="cs-sk">
          <div v-for="i in 8" :key="i" class="cs-skr">
            <div class="cs-ska" />
            <div class="cs-skb">
              <div class="cs-skl" />
              <div class="cs-skl short" />
            </div>
          </div>
        </div>

        <div v-else-if="!rows.length" class="cs-nempty">
          <span class="i-lucide-contact" />
          <div class="cs-net">No contacts found</div>
          <div class="cs-nes">
            Try a different search or clear the date filter.
          </div>
          <button v-if="activeFilters || q" class="cs-btn ghost" @click="clearAll">
            Clear filters
          </button>
        </div>

        <template v-else>
          <template v-for="g in grouped" :key="g.id">
            <div v-if="g.kind === 'idx'" class="cs-aidx">{{ g.letter }}</div>
            <div
              v-else
              class="cs-crow"
              :class="{ on: selected && selected.id === g.c.id }"
              @click="openContact(g.c)"
            >
              <div
                class="cs-cav"
                :style="{ background: colorFor(g.c.id) }"
              >
                <img v-if="g.c.thumbnail" :src="g.c.thumbnail" alt="" />
                <template v-else>{{ initials(g.c.name) }}</template>
              </div>
              <div class="cs-cb">
                <div class="cs-cn">
                  <span class="cs-cnt">{{ g.c.name || 'Unknown' }}</span>
                  <span v-if="isActive(g.c)" class="cs-online" title="Active" />
                </div>
                <div class="cs-cs">
                  <span
                    v-if="chChip(g.c)"
                    class="cs-chip"
                    :style="{
                      color: chChip(g.c).color,
                      background: chChip(g.c).color + '26',
                    }"
                  >
                    {{ chChip(g.c).t }}
                  </span>
                  <span class="cs-csv">{{ subOf(g.c) }}</span>
                </div>
                <div v-if="labelsOf(g.c).length" class="cs-clbs">
                  <span v-for="l in labelsOf(g.c)" :key="l" class="cs-clb">
                    {{ l }}
                  </span>
                </div>
              </div>
            </div>
          </template>
          <div v-if="loadingMore" class="cs-more">Loading more…</div>
        </template>
      </div>
    </div>

    <!-- ============ RIGHT: CONTACT DETAIL ============ -->
    <div class="cs-cdet">
      <div v-if="!selected" class="cs-blank">
        <span class="i-lucide-contact" />
        <div class="cs-bt">Select a contact</div>
        <div class="cs-bs">
          Pick someone on the left to see their details, labels and every
          conversation they have had with you.
        </div>
      </div>

      <template v-else>
        <div class="cs-cdh">
          <span v-if="isMobile" class="cs-ic" @click="backToList">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M15 18l-6-6 6-6" stroke-linecap="round" stroke-linejoin="round" />
            </svg>
          </span>
          <h3>Contact info</h3>
          <span class="cs-ic" title="Edit" @click.stop="openEdit(selected)">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M12 20h9" stroke-linecap="round" />
              <path
                d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4z"
                stroke-linecap="round"
                stroke-linejoin="round"
              />
            </svg>
          </span>
          <span class="cs-ic" title="More" @click.stop="toggleCm">
            <svg viewBox="0 0 24 24" fill="currentColor">
              <circle cx="12" cy="5" r="1.6" />
              <circle cx="12" cy="12" r="1.6" />
              <circle cx="12" cy="19" r="1.6" />
            </svg>
          </span>

          <div v-if="cmenu" class="cs-tm" @click.stop>
            <div
              class="cs-mi"
              @click="
                cmenu = false;
                openEdit(selected);
              "
            >
              <span class="i-lucide-pencil" /><span>Edit contact</span>
            </div>
            <div
              class="cs-mi"
              @click="
                cmenu = false;
                lpOpen();
              "
            >
              <span class="i-lucide-tag" /><span>Labels</span>
            </div>
            <div class="cs-sep" />
            <div
              class="cs-mi dgr"
              @click="
                cmenu = false;
                deleteContact(selected);
              "
            >
              <span class="i-lucide-trash-2" /><span>Delete contact</span>
            </div>
          </div>
        </div>

        <div class="cs-cscroll">
          <div class="cs-ctop">
            <div class="cs-iav" :style="{ background: colorFor(selected.id) }">
              <img v-if="selected.thumbnail" :src="selected.thumbnail" alt="" />
              <template v-else>{{ initials(selected.name) }}</template>
            </div>
            <div class="cs-inm">{{ selected.name || 'Unknown' }}</div>
            <div class="cs-iph">
              {{ phoneOf(selected) || CH_NAME[chOf(selected)] || 'Contact' }}
            </div>
            <div v-if="bioOf(selected)" class="cs-ibio">
              {{ bioOf(selected) }}
            </div>
          </div>

          <div class="cs-csec">
            <div class="cs-sl">Details</div>
            <div v-if="phoneOf(selected)" class="cs-irow">
              <span class="cs-k">Phone</span>
              <span class="cs-v">{{ phoneOf(selected) }}</span>
            </div>
            <div v-if="emailOf(selected)" class="cs-irow">
              <span class="cs-k">Email</span>
              <span class="cs-v">{{ emailOf(selected) }}</span>
            </div>
            <div v-if="companyOf(selected)" class="cs-irow">
              <span class="cs-k">Company</span>
              <span class="cs-v">{{ companyOf(selected) }}</span>
            </div>
            <div v-if="cityOf(selected)" class="cs-irow">
              <span class="cs-k">City</span>
              <span class="cs-v">{{ cityOf(selected) }}</span>
            </div>
            <div v-if="countryOf(selected)" class="cs-irow">
              <span class="cs-k">Country</span>
              <span class="cs-v">{{ countryOf(selected) }}</span>
            </div>
            <div v-if="chOf(selected)" class="cs-irow">
              <span class="cs-k">Channel</span>
              <span class="cs-v">{{ CH_NAME[chOf(selected)] }}</span>
            </div>
            <div v-if="inboxOf(selected)" class="cs-irow">
              <span class="cs-k">Inbox</span>
              <span class="cs-v">{{ inboxOf(selected) }}</span>
            </div>
            <div v-if="selected.created_at" class="cs-irow">
              <span class="cs-k">Added on</span>
              <span class="cs-v">{{ fmtStamp(selected.created_at) }}</span>
            </div>
            <div class="cs-irow">
              <span class="cs-k">Last seen</span>
              <span class="cs-v">{{ seenOf(selected) }}</span>
            </div>
            <div class="cs-irow">
              <span class="cs-k">Status</span>
              <span class="cs-v cap">
                {{ isActive(selected) ? 'Active' : 'Offline' }}
              </span>
            </div>
          </div>

          <div class="cs-csec">
            <div class="cs-sl">Labels</div>
            <div class="cs-lbls">
              <span v-for="l in labelsOf(selected)" :key="l" class="cs-lb">
                {{ l }}
                <span
                  class="cs-lbx i-lucide-x"
                  title="Remove label"
                  @click.stop="dropLabel(l)"
                />
              </span>
              <span class="cs-lb add" @click.stop="lpOpen">+ Add label</span>
            </div>
          </div>

          <div
            v-if="Object.keys(selected.custom_attributes || {}).length"
            class="cs-csec"
          >
            <div class="cs-sl">Custom attributes</div>
            <div
              v-for="(v, k) in selected.custom_attributes"
              :key="k"
              class="cs-irow"
            >
              <span class="cs-k">{{ k }}</span>
              <span class="cs-v">{{ v }}</span>
            </div>
          </div>

          <div class="cs-csec">
            <div class="cs-sl">
              Conversations<template v-if="convs.length">
                · {{ convs.length }}</template
              >
            </div>
            <div v-if="convsLoading" class="cs-agempty">Loading…</div>
            <div v-else-if="!convs.length" class="cs-agempty">
              No conversations yet
            </div>
            <div
              v-for="cv in convs"
              :key="cv.id"
              class="cs-convrow"
              @click="openConversation(cv)"
            >
              <div
                class="cs-cvi"
                :class="cv.status === 'resolved' ? 'done' : 'open'"
              >
                <span
                  :class="
                    cv.status === 'resolved'
                      ? 'i-lucide-check'
                      : 'i-lucide-message-circle'
                  "
                />
              </div>
              <div class="cs-cvb">
                <div class="cs-cvt">
                  {{ cv.meta?.sender?.name || selected.name || 'Conversation' }}
                  <span class="cs-cvid">#{{ cv.id }}</span>
                </div>
                <div class="cs-cvs">
                  {{ fmtStamp(cv.created_at) }} ·
                  <span class="cap">{{ cv.status || 'open' }}</span>
                </div>
              </div>
              <span class="i-lucide-chevron-right cs-cvr" />
            </div>
          </div>

          <div class="cs-cactions">
            <div class="cs-iitem dgr" @click="deleteContact(selected)">
              <span class="i-lucide-trash-2" />
              <span>Delete contact</span>
            </div>
          </div>
        </div>
      </template>
    </div>

    <!-- ============ CALENDAR ============ -->
    <div v-if="showCal" class="cs-fw" @click.self="showCal = false">
      <div class="cs-cal" @click.stop>
        <div class="cs-calq">
          <div
            v-for="qk in QUICK"
            :key="qk.n"
            :class="{ on: quickPick === qk.n }"
            @click="pickQuick(qk)"
          >
            {{ qk.n }}
          </div>
        </div>
        <div class="cs-calh">
          <span class="cs-cnav i-lucide-chevron-left" @click="calMove(-1)" />
          <span class="cs-cm">{{ calTitle }}</span>
          <span class="cs-cnav i-lucide-chevron-right" @click="calMove(1)" />
        </div>
        <div class="cs-calg">
          <div v-for="d in ['S', 'M', 'T', 'W', 'T', 'F', 'S']" :key="d" class="cs-dh">
            {{ d }}
          </div>
          <div
            v-for="d in calDays"
            :key="d.key"
            class="cs-dd"
            :class="[{ mut: d.mut }, dayCls(d.key)]"
            @click="pickDay(d.key)"
          >
            {{ d.day }}
          </div>
        </div>
        <div class="cs-calf">
          <button @click="calClear">Clear</button>
          <button class="p" @click="calApply">Apply</button>
        </div>
      </div>
    </div>

    <!-- ============ LABEL PICKER ============ -->
    <div v-if="lp.open" class="cs-fw" @click.self="lp.open = false">
      <div class="cs-lpb" @click.stop>
        <div class="cs-fwh">
          <span>Labels</span>
          <span class="cs-ic" @click="lp.open = false">
            <span class="i-lucide-x" />
          </span>
        </div>
        <div class="cs-search cs-lpsr">
          <span class="cs-search__ic i-lucide-search" />
          <input v-model="lp.q" placeholder="Search or create label" />
        </div>
        <div class="cs-lpl">
          <div
            v-for="l in lpHits"
            :key="l.id || l.title"
            class="cs-lpr"
            :class="{ on: lp.sel.includes(l.title) }"
            @click="lpToggle(l.title)"
          >
            <span class="cs-pld" :style="{ background: l.color || '#00A884' }" />
            <span class="cs-lpn">{{ l.title }}</span>
            <span v-if="lp.sel.includes(l.title)" class="cs-lpck i-lucide-check" />
          </div>
          <div
            v-if="
              lp.q.trim() &&
              !lpHits.some(
                l => l.title === lp.q.trim().replace(/\s+/g, '-').toLowerCase()
              )
            "
            class="cs-lpr new"
            @click="lpNew"
          >
            <span class="i-lucide-plus" />
            <span class="cs-lpn">
              Create "{{ lp.q.trim().replace(/\s+/g, '-').toLowerCase() }}"
            </span>
          </div>
          <div v-if="!lpHits.length && !lp.q" class="cs-agempty">
            No labels yet — type above to create one
          </div>
        </div>
        <div class="cs-lpf">
          <span class="cs-lpc">{{ lp.sel.length }} selected</span>
          <button class="cs-btn" @click="lp.open = false">Done</button>
        </div>
      </div>
    </div>

    <!-- ============ EDIT / NEW CONTACT ============ -->
    <div v-if="edit" class="cs-fw" @click.self="edit = null">
      <div class="cs-form" @click.stop>
        <div class="cs-fwh">
          <span>{{ edit.id ? 'Edit contact' : 'New contact' }}</span>
          <span class="cs-ic" @click="edit = null">
            <span class="i-lucide-x" />
          </span>
        </div>
        <div class="cs-fb">
          <label class="cs-fl">
            <span>Name</span>
            <input v-model="edit.name" placeholder="Full name" />
          </label>
          <label class="cs-fl">
            <span>Phone <em>· cannot be changed</em></span>
            <input
              :value="edit.phone_number || '—'"
              readonly
              disabled
              class="ro"
            />
          </label>
          <label class="cs-fl">
            <span>Email</span>
            <input v-model="edit.email" placeholder="name@example.com" />
          </label>
          <label class="cs-fl">
            <span>Company</span>
            <input v-model="edit.company_name" placeholder="Company name" />
          </label>
          <div class="cs-frow">
            <label class="cs-fl">
              <span>City</span>
              <input v-model="edit.city" placeholder="City" />
            </label>
            <label class="cs-fl">
              <span>Country</span>
              <input v-model="edit.country" placeholder="Country" />
            </label>
          </div>
          <label class="cs-fl">
            <span>Notes</span>
            <textarea
              v-model="edit.description"
              rows="3"
              placeholder="Anything worth remembering about this contact"
            />
          </label>
        </div>
        <div class="cs-ff">
          <button class="cs-btn ghost" @click="edit = null">Cancel</button>
          <button class="cs-btn" :disabled="saving" @click="saveContact">
            {{ saving ? 'Saving…' : edit.id ? 'Save changes' : 'Create contact' }}
          </button>
        </div>
      </div>
    </div>

    <!-- ============ CONFIRM ============ -->
    <div v-if="ask" class="cs-fw" @click.self="ask.cancel()">
      <div class="cs-ask" @click.stop>
        <div class="cs-askt">{{ ask.title }}</div>
        <div class="cs-askb">{{ ask.body }}</div>
        <div class="cs-askf">
          <button class="cs-btn ghost" @click="ask.cancel()">Cancel</button>
          <button
            class="cs-btn"
            :class="{ dgr: ask.danger }"
            @click="ask.ok()"
          >
            {{ ask.okText }}
          </button>
        </div>
      </div>
    </div>

    <div v-if="isMobile && (hmenu || cmenu || lblMenu)" class="cs-sheetbg" />

    <!-- ============ TOASTS ============ -->
    <div class="cs-toasts">
      <div
        v-for="t in toasts"
        :key="t.id"
        class="cs-toast"
        :class="{ err: t.kind === 'err' }"
      >
        {{ t.text }}
      </div>
    </div>
  </section>
</template>

<style scoped>
/* ===== tokens — ChatsScreen.vue se bilkul same ===== */
.cs-app {
  position: relative;
  max-width: 100%;
  overflow: hidden;

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
  --content: #0b141a;
  --inp: #2a3942;
  --red: #f15c6d;
  --red-tint: #3a1d22;

  display: flex;
  width: 100%;
  height: 100%;
  min-width: 0;
  font-size: 14px;
  color: var(--tx);
  background: var(--content);
}
.cs-app.lite {
  --panel: #ffffff;
  --head: #eff3f4;
  --fld: #e3e9eb;
  --tx: #0a1519;
  --tx2: #3d4f57;
  --tx3: #55666e;
  --ln: #c7d1d6;
  --ln2: #dce3e6;
  --hov: #eceff1;
  --sel: #cfe6dd;
  --g: #00755f;
  --g-tint: #c8e8db;
  --b: #026a99;
  --menu: #ffffff;
  --menu-hov: #eceff1;
  --content: #e3e8ea;
  --inp: #ffffff;
  --red: #c22b3b;
  --red-tint: #f9dde1;
}
/* light mode mein safed-par-safed gum ho jaata tha — border chahiye */
.cs-app.lite .cs-hm,
.cs-app.lite .cs-tm,
.cs-app.lite .cs-cmenu,
.cs-app.lite .cs-sub,
.cs-app.lite .cs-cal,
.cs-app.lite .cs-lpb,
.cs-app.lite .cs-form,
.cs-app.lite .cs-ask {
  border: 1px solid var(--ln);
  box-shadow: 0 8px 28px rgba(11, 20, 26, 0.16);
}
.cs-app.lite .cs-search,
.cs-app.lite .cs-dchip {
  border: 1px solid var(--ln);
}
.cs-app.lite .cs-search.act,
.cs-app.lite .cs-dchip.act {
  border-color: var(--g);
}
.cs-app.lite .cs-pl {
  border: 1px solid var(--ln);
}
.cs-app.lite .cs-pl.on {
  border-color: var(--g);
}
.cs-app.lite .cs-toast {
  background: #10202a;
  color: #fff;
}
.cs-app.lite .cs-toast.err {
  background: var(--red);
  color: #fff;
}
.cs-app.lite .cs-fw {
  background: rgba(11, 20, 26, 0.4);
}
.cs-app.lite .cs-cvi.done {
  background: var(--fld);
  color: var(--tx2);
}
.cs-app * {
  box-sizing: border-box;
}

/* ===== PANEL ===== */
.cs-panel {
  flex: 0 0 auto;
  width: 32%;
  min-width: 300px;
  max-width: 420px;
  display: flex;
  flex-direction: column;
  background: var(--panel);
  border-right: 1px solid var(--ln);
  min-height: 0;
  /* is ke bagair search/pills panel ki chauRai se bahar nikal jaate the */
  overflow: hidden;
}
.cs-ph {
  height: 60px;
  flex-shrink: 0;
  /* pehle var(--head) tha jo rail ke rang jaisa hi hai — dono mil kar
     ek dikhte the. Ab panel ka rang + neeche saaf lakeer. */
  background: var(--panel);
  border-bottom: 1px solid var(--ln);
  display: flex;
  align-items: center;
  gap: 4px;
  padding: 0 8px 0 18px;
  position: relative;
}
.cs-ph h1 {
  flex: 1;
  min-width: 0;
  font-size: 19px;
  font-weight: 600;
  margin: 0;
  letter-spacing: 0.01em;
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
}
.cs-ic svg {
  width: 20px;
  height: 20px;
}
.cs-ham {
  margin-left: -8px;
}

/* search */
.cs-search {
  display: flex;
  align-items: center;
  gap: 10px;
  margin: 8px 12px;
  padding: 0 12px;
  height: 38px;
  background: var(--fld);
  border-radius: 8px;
  flex-shrink: 0;
  min-width: 0;
  max-width: calc(100% - 24px);
}
.cs-search__ic {
  width: 17px;
  height: 17px;
  color: var(--tx3);
  flex-shrink: 0;
}
.cs-search.act .cs-search__ic {
  color: var(--g);
}
.cs-search input {
  flex: 1;
  min-width: 0;
  background: none;
  border: 0;
  outline: none;
  color: var(--tx);
  font-size: 14px;
  font-family: inherit;
}
.cs-search input::placeholder {
  color: var(--tx3);
}
.cs-search__x {
  width: 16px;
  height: 16px;
  color: var(--tx3);
  cursor: pointer;
  flex-shrink: 0;
}

/* pills */
.cs-pillwrap {
  position: relative;
  flex-shrink: 0;
  max-width: 100%;
}
.cs-pills {
  display: flex;
  gap: 7px;
  padding: 2px 12px 10px;
  overflow-x: auto;
  flex-shrink: 0;
  scrollbar-width: none;
}
.cs-pills::-webkit-scrollbar {
  display: none;
}
.cs-pl {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 6px 13px;
  border-radius: 15px;
  background: var(--fld);
  color: var(--tx2);
  font-size: 13.5px;
  cursor: pointer;
  white-space: nowrap;
  flex-shrink: 0;
  position: relative;
}
.cs-pl:hover {
  filter: brightness(1.12);
}
.cs-pl.on {
  background: var(--g-tint);
  color: var(--g);
}
.cs-pld {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  flex-shrink: 0;
}
.cs-plmore span[class*='i-'],
.cs-pltag span[class*='i-'] {
  width: 15px;
  height: 15px;
}

/* date chip */
.cs-dchip {
  display: flex;
  align-items: center;
  gap: 8px;
  margin: 0 12px 10px;
  background: var(--fld);
  border-radius: 9px;
  padding: 9px 13px;
  cursor: pointer;
  font-size: 13.5px;
  color: var(--tx2);
  flex-shrink: 0;
}
.cs-dchip:hover {
  filter: brightness(1.12);
}
.cs-dchip span[class*='i-'] {
  width: 17px;
  height: 17px;
  color: var(--tx3);
  flex-shrink: 0;
}
.cs-dv {
  flex: 1;
  color: var(--tx);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.cs-dchip.act {
  background: var(--g-tint);
  color: var(--g);
}
.cs-dchip.act span[class*='i-'],
.cs-dchip.act .cs-dv {
  color: var(--g);
}

/* ===== LIST ===== */
.cs-list {
  flex: 1;
  min-height: 0;
  overflow-y: auto;
  overscroll-behavior: contain;
}
.cs-aidx {
  font-size: 12.5px;
  font-weight: 600;
  color: var(--g);
  padding: 14px 20px 7px;
  background: var(--panel);
  position: sticky;
  top: 0;
  z-index: 2;
  letter-spacing: 0.03em;
}
.cs-crow {
  display: flex;
  gap: 14px;
  padding: 11px 20px 11px 16px;
  cursor: pointer;
  align-items: center;
}
.cs-crow:hover {
  background: var(--hov);
}
.cs-crow.on {
  background: var(--sel);
}
.cs-cav {
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
}
.cs-cav img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.cs-cb {
  flex: 1;
  min-width: 0;
  border-bottom: 1px solid var(--ln2);
  padding-bottom: 11px;
  margin-bottom: -11px;
}
.cs-cn {
  display: flex;
  align-items: center;
  gap: 7px;
  margin-bottom: 3px;
}
.cs-cnt {
  font-size: 15.5px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.cs-online {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: var(--g);
  flex-shrink: 0;
}
.cs-cs {
  font-size: 13.5px;
  color: var(--tx3);
  display: flex;
  align-items: center;
  gap: 7px;
  min-width: 0;
}
.cs-csv {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.cs-chip {
  font-size: 9.5px;
  font-weight: 700;
  padding: 1px 5px;
  border-radius: 4px;
  letter-spacing: 0.04em;
  flex-shrink: 0;
  background: var(--fld);
  color: var(--tx2);
}
.cs-chip--wa {
  background: rgba(37, 211, 102, 0.16);
  color: #25d366;
}
.cs-chip--fb {
  background: rgba(8, 102, 255, 0.16);
  color: #4d8dff;
}
.cs-chip--ig {
  background: rgba(225, 48, 108, 0.16);
  color: #e1306c;
}
.cs-clbs {
  display: flex;
  flex-wrap: wrap;
  gap: 5px;
  margin-top: 5px;
}
.cs-clb {
  font-size: 10.5px;
  background: var(--g-tint);
  color: var(--g);
  padding: 1px 7px;
  border-radius: 9px;
  white-space: nowrap;
}
.cs-more {
  text-align: center;
  font-size: 12.5px;
  color: var(--tx3);
  padding: 14px 0 20px;
}

/* skeleton */
.cs-sk {
  padding: 6px 0;
}
.cs-skr {
  display: flex;
  gap: 14px;
  padding: 11px 20px 11px 16px;
  align-items: center;
}
.cs-ska {
  width: 49px;
  height: 49px;
  border-radius: 50%;
  background: var(--fld);
  flex-shrink: 0;
}
.cs-skb {
  flex: 1;
  min-width: 0;
}
.cs-skl {
  height: 11px;
  border-radius: 6px;
  background: var(--fld);
  margin-bottom: 8px;
}
.cs-skl.short {
  width: 45%;
  margin-bottom: 0;
}
.cs-sk .cs-skr {
  animation: csPulse 1.3s ease-in-out infinite;
}
@keyframes csPulse {
  0%,
  100% {
    opacity: 1;
  }
  50% {
    opacity: 0.5;
  }
}

/* empty */
.cs-nempty {
  padding: 56px 26px;
  text-align: center;
  color: var(--tx3);
}
.cs-nempty > span[class*='i-'] {
  width: 44px;
  height: 44px;
  color: var(--tx3);
  opacity: 0.5;
  margin: 0 auto 14px;
  display: block;
}
.cs-net {
  font-size: 15.5px;
  color: var(--tx2);
  margin-bottom: 6px;
}
.cs-nes {
  font-size: 13px;
  line-height: 1.5;
  margin-bottom: 16px;
}

/* ===== DETAIL ===== */
.cs-cdet {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  background: var(--content);
}
.cs-blank {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  text-align: center;
  padding: 40px;
  color: var(--tx3);
}
.cs-blank > span[class*='i-'] {
  width: 58px;
  height: 58px;
  opacity: 0.4;
  margin-bottom: 18px;
}
.cs-bt {
  font-size: 22px;
  color: var(--tx2);
  font-weight: 300;
  margin-bottom: 10px;
}
.cs-bs {
  font-size: 13.5px;
  max-width: 420px;
  line-height: 1.6;
}
.cs-cdh {
  background: var(--panel);
  border-bottom: 1px solid var(--ln);
  padding: 12px 14px 12px 18px;
  display: flex;
  align-items: center;
  gap: 6px;
  flex-shrink: 0;
  position: relative;
  height: 60px;
}
.cs-cdh h3 {
  font-size: 16px;
  font-weight: 500;
  flex: 1;
  margin: 0;
}
.cs-cscroll {
  flex: 1;
  min-height: 0;
  overflow-y: auto;
}
.cs-ctop {
  background: var(--panel);
  padding: 28px 20px 22px;
  text-align: center;
  border-bottom: 9px solid var(--content);
}
.cs-iav {
  width: 108px;
  height: 108px;
  border-radius: 50%;
  display: grid;
  place-items: center;
  color: #fff;
  font-size: 36px;
  font-weight: 600;
  margin: 0 auto 14px;
  overflow: hidden;
}
.cs-iav img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.cs-inm {
  font-size: 21px;
  margin-bottom: 4px;
}
.cs-iph {
  font-size: 14px;
  color: var(--tx3);
}
.cs-ibio {
  font-size: 13.5px;
  color: var(--tx2);
  margin-top: 10px;
  line-height: 1.5;
}
.cs-iacts {
  display: flex;
  justify-content: center;
  gap: 34px;
  margin-top: 20px;
}
.cs-iact {
  font-size: 12.5px;
  color: var(--g);
  cursor: pointer;
  text-decoration: none;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 7px;
}
.cs-cir {
  width: 42px;
  height: 42px;
  border-radius: 50%;
  background: var(--g-tint);
  color: var(--g);
  display: grid;
  place-items: center;
}
.cs-csec {
  background: var(--panel);
  padding: 16px 20px;
  border-bottom: 9px solid var(--content);
}
.cs-sl {
  font-size: 12.5px;
  color: var(--tx3);
  margin-bottom: 12px;
}
.cs-irow {
  display: flex;
  gap: 14px;
  padding: 7px 0;
  font-size: 14px;
  align-items: flex-start;
}
.cs-k {
  color: var(--tx3);
  width: 108px;
  flex-shrink: 0;
  font-size: 13px;
}
.cs-v {
  flex: 1;
  min-width: 0;
  word-break: break-word;
}
.cs-v.cap,
.cap {
  text-transform: capitalize;
}
.cs-lbls {
  display: flex;
  flex-wrap: wrap;
  gap: 7px;
}
.cs-lb {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  font-size: 12px;
  background: var(--g-tint);
  color: var(--g);
  padding: 4px 10px;
  border-radius: 12px;
}
.cs-lb.add {
  background: var(--fld);
  color: var(--tx2);
  cursor: pointer;
}
.cs-lb.add:hover {
  background: var(--sel);
  color: var(--tx);
}
.cs-lbx {
  width: 12px;
  height: 12px;
  opacity: 0.6;
  cursor: pointer;
}
.cs-lbx:hover {
  opacity: 1;
}
.cs-convrow {
  display: flex;
  gap: 13px;
  padding: 12px 0;
  border-bottom: 1px solid var(--ln2);
  cursor: pointer;
  align-items: center;
}
.cs-convrow:last-child {
  border-bottom: none;
}
.cs-convrow:hover {
  opacity: 0.75;
}
.cs-cvi {
  width: 36px;
  height: 36px;
  border-radius: 9px;
  display: grid;
  place-items: center;
  flex-shrink: 0;
}
.cs-cvi span {
  width: 17px;
  height: 17px;
}
.cs-cvi.open {
  background: var(--g-tint);
  color: var(--g);
}
.cs-cvi.done {
  background: var(--fld);
  color: var(--tx3);
}
.cs-cvb {
  flex: 1;
  min-width: 0;
}
.cs-cvt {
  font-size: 14px;
  margin-bottom: 2px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.cs-cvid {
  color: var(--tx3);
  font-size: 12px;
  margin-left: 5px;
}
.cs-cvs {
  font-size: 12.5px;
  color: var(--tx3);
}
.cs-cvr {
  width: 16px;
  height: 16px;
  color: var(--tx3);
  flex-shrink: 0;
}
.cs-cactions {
  background: var(--panel);
}
.cs-iitem {
  display: flex;
  align-items: center;
  gap: 18px;
  padding: 15px 20px;
  cursor: pointer;
  font-size: 14.5px;
  color: var(--tx);
}
.cs-iitem:hover {
  background: var(--hov);
}
.cs-iitem span[class*='i-'] {
  width: 19px;
  height: 19px;
  color: var(--tx3);
  flex-shrink: 0;
}
.cs-iitem.dgr,
.cs-iitem.dgr span[class*='i-'] {
  color: var(--red);
}

/* ===== MENUS ===== */
.cs-hm,
.cs-tm,
.cs-cmenu {
  position: absolute;
  top: 52px;
  right: 8px;
  min-width: 224px;
  background: var(--menu);
  border-radius: 10px;
  box-shadow: 0 6px 26px rgba(0, 0, 0, 0.45);
  padding: 7px 0;
  z-index: 700;
  overflow-y: auto;
  max-height: 76vh;
}
.cs-lblmenu {
  top: 100%;
  right: 12px;
  left: auto;
  min-width: 200px;
  max-height: 320px;
}
.cs-mt2 {
  font-size: 11.5px;
  color: var(--tx3);
  padding: 5px 16px 8px;
}
.cs-mi {
  display: flex;
  align-items: center;
  gap: 13px;
  padding: 10px 16px;
  cursor: pointer;
  font-size: 14px;
  color: var(--tx);
  white-space: nowrap;
  position: relative;
}
.cs-mi:hover {
  background: var(--menu-hov);
}
.cs-mi span[class*='i-'] {
  width: 17px;
  height: 17px;
  color: var(--tx3);
  flex-shrink: 0;
}
.cs-mi.on {
  color: var(--g);
}
.cs-mi.dgr,
.cs-mi.dgr span[class*='i-'] {
  color: var(--red);
}
.cs-sep {
  height: 1px;
  background: var(--ln);
  margin: 6px 0;
}
.cs-arw {
  margin-left: auto;
}
.cs-has-sub {
  position: relative;
}
.cs-sub {
  position: absolute;
  top: 0;
  right: 100%;
  min-width: 190px;
  background: var(--menu);
  border-radius: 10px;
  box-shadow: 0 6px 26px rgba(0, 0, 0, 0.45);
  padding: 7px 0;
  z-index: 720;
}
.cs-agempty {
  padding: 14px 16px;
  font-size: 13px;
  color: var(--tx3);
  text-align: center;
}

/* ===== OVERLAYS ===== */
.cs-fw {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.55);
  z-index: 9000;
  display: grid;
  place-items: center;
  padding: 20px;
}
.cs-fwh {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 13px 12px 13px 18px;
  background: var(--head);
  font-size: 16px;
  font-weight: 500;
  flex-shrink: 0;
  border-bottom: 1px solid var(--ln);
}
.cs-fwh > span:first-child {
  flex: 1;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.cs-fwh .cs-ic {
  width: 34px;
  height: 34px;
  flex-shrink: 0;
}
.cs-fwh .cs-ic span {
  width: 18px;
  height: 18px;
}

/* calendar */
.cs-cal {
  background: var(--menu);
  border-radius: 12px;
  padding: 14px;
  width: 320px;
  max-width: 100%;
  box-shadow: 0 8px 30px rgba(0, 0, 0, 0.5);
}
.cs-calq {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin-bottom: 12px;
  padding-bottom: 12px;
  border-bottom: 1px solid var(--ln);
}
.cs-calq div {
  font-size: 12.5px;
  padding: 5px 11px;
  border-radius: 14px;
  background: var(--fld);
  cursor: pointer;
  color: var(--tx2);
}
.cs-calq div:hover {
  filter: brightness(1.15);
}
.cs-calq div.on {
  background: var(--g-tint);
  color: var(--g);
}
.cs-calh {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 10px;
}
.cs-cm {
  flex: 1;
  font-size: 14.5px;
  font-weight: 600;
  text-align: center;
}
.cs-cnav {
  width: 30px;
  height: 30px;
  border-radius: 50%;
  display: grid;
  place-items: center;
  cursor: pointer;
  color: var(--tx2);
}
.cs-cnav:hover {
  background: var(--hov);
}
.cs-calg {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  gap: 2px;
}
.cs-dh {
  font-size: 11px;
  color: var(--tx3);
  text-align: center;
  padding: 5px 0;
  font-weight: 600;
}
.cs-dd {
  aspect-ratio: 1;
  display: grid;
  place-items: center;
  font-size: 13px;
  border-radius: 8px;
  cursor: pointer;
  color: var(--tx);
}
.cs-dd:hover {
  background: var(--hov);
}
.cs-dd.mut {
  color: var(--tx3);
  opacity: 0.4;
}
.cs-dd.rng {
  background: var(--g-tint);
  color: var(--g);
  border-radius: 0;
}
.cs-dd.sel {
  background: var(--g);
  color: #fff;
  font-weight: 600;
}
.cs-calf {
  display: flex;
  gap: 8px;
  margin-top: 13px;
  padding-top: 12px;
  border-top: 1px solid var(--ln);
}
.cs-calf button {
  flex: 1;
  padding: 9px;
  border-radius: 8px;
  border: 1px solid var(--ln);
  background: transparent;
  color: var(--tx);
  font-family: inherit;
  font-size: 13.5px;
  cursor: pointer;
  font-weight: 500;
}
.cs-calf button:hover {
  background: var(--hov);
}
.cs-calf button.p {
  background: var(--g);
  color: #fff;
  border-color: var(--g);
}

/* label picker */
.cs-lpb {
  background: var(--panel);
  border-radius: 12px;
  width: 400px;
  max-width: 100%;
  max-height: 78vh;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}
.cs-lpsr {
  margin: 10px 14px;
}
.cs-lpl {
  flex: 1;
  min-height: 0;
  overflow-y: auto;
  padding: 2px 8px 8px;
}
.cs-lpr {
  display: flex;
  align-items: center;
  gap: 11px;
  padding: 11px 14px;
  border-radius: 8px;
  cursor: pointer;
  font-size: 14px;
  min-height: 44px;
}
.cs-lpr:hover {
  background: var(--hov);
}
.cs-lpr.on {
  background: var(--g-tint);
}
.cs-lpr.new > span:first-child {
  width: 16px;
  height: 16px;
  color: var(--g);
}
.cs-lpn {
  flex: 1;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.cs-lpck {
  width: 16px;
  height: 16px;
  color: var(--g);
  flex-shrink: 0;
}
.cs-lpf {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 12px 16px;
  border-top: 1px solid var(--ln);
  flex-shrink: 0;
}
.cs-lpc {
  flex: 1;
  font-size: 13px;
  color: var(--tx3);
}

/* form */
.cs-form {
  background: var(--panel);
  border-radius: 12px;
  width: 460px;
  max-width: 100%;
  max-height: 86vh;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}
.cs-fb {
  flex: 1;
  min-height: 0;
  overflow-y: auto;
  padding: 16px 18px;
}
.cs-fl {
  display: block;
  margin-bottom: 14px;
}
.cs-fl > span {
  display: block;
  font-size: 12.5px;
  color: var(--tx3);
  margin-bottom: 6px;
}
.cs-fl input,
.cs-fl textarea {
  width: 100%;
  background: var(--inp);
  border: 1px solid var(--ln);
  border-radius: 8px;
  padding: 10px 12px;
  color: var(--tx);
  font-size: 14px;
  font-family: inherit;
  outline: none;
  resize: vertical;
}
.cs-fl input:focus,
.cs-fl textarea:focus {
  border-color: var(--g);
}
.cs-fl > span em {
  font-style: normal;
  color: var(--tx3);
  opacity: 0.85;
}
.cs-fl input.ro {
  background: var(--fld);
  color: var(--tx3);
  cursor: not-allowed;
}
.cs-frow {
  display: flex;
  gap: 12px;
}
.cs-frow .cs-fl {
  flex: 1;
  min-width: 0;
}
.cs-ff {
  display: flex;
  justify-content: flex-end;
  gap: 10px;
  padding: 12px 18px;
  border-top: 1px solid var(--ln);
  flex-shrink: 0;
}

/* confirm */
.cs-ask {
  background: var(--panel);
  border-radius: 12px;
  padding: 22px;
  width: 400px;
  max-width: 100%;
}
.cs-askt {
  font-size: 17px;
  margin-bottom: 10px;
}
.cs-askb {
  font-size: 13.8px;
  color: var(--tx2);
  line-height: 1.55;
  margin-bottom: 20px;
}
.cs-askf {
  display: flex;
  justify-content: flex-end;
  gap: 10px;
}

/* buttons */
.cs-btn {
  background: var(--g);
  color: #fff;
  border: 0;
  border-radius: 20px;
  padding: 9px 22px;
  font-size: 14px;
  font-family: inherit;
  cursor: pointer;
}
.cs-btn:hover {
  filter: brightness(1.08);
}
.cs-btn:disabled {
  opacity: 0.5;
  cursor: default;
}
.cs-btn.ghost {
  background: transparent;
  color: var(--tx2);
  border: 1px solid var(--ln);
}
.cs-btn.ghost:hover {
  background: var(--hov);
}
.cs-btn.dgr {
  background: var(--red);
}

/* mobile sheet ka parda */
.cs-sheetbg {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.45);
  z-index: 9390;
}

/* toasts */
.cs-toasts {
  position: fixed;
  bottom: 26px;
  left: 50%;
  transform: translateX(-50%);
  display: flex;
  flex-direction: column;
  gap: 8px;
  z-index: 9500;
  pointer-events: none;
}
.cs-toast {
  background: var(--menu);
  color: var(--tx);
  padding: 11px 20px;
  border-radius: 22px;
  font-size: 13.5px;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.4);
  white-space: nowrap;
}
.cs-toast.err {
  background: var(--red-tint);
  color: var(--red);
}

/* ===== MOBILE ===== */
@media (max-width: 768px) {
  .cs-app {
    overflow: hidden;
    max-width: 100vw;
  }
  .cs-panel {
    width: 100%;
    max-width: 100vw;
    min-width: 0;
    border-right: none;
  }
  .cs-cdet {
    display: none;
  }
  .cs-app.det .cs-panel {
    display: none;
  }
  .cs-app.det .cs-cdet {
    display: flex;
  }
  .cs-aidx {
    padding: 13px 14px 6px;
  }
  .cs-crow {
    padding: 11px 14px;
  }
  .cs-ph {
    padding: 0 6px 0 12px;
  }
  .cs-ctop {
    padding: 26px 18px 20px;
  }
  .cs-csec {
    padding: 16px 18px;
  }
  .cs-cdh {
    padding: 12px 10px 12px 12px;
  }
  .cs-hm,
  .cs-tm,
  .cs-cmenu {
    position: fixed;
    left: 0;
    right: 0;
    top: auto;
    bottom: 0;
    min-width: 0;
    max-width: none;
    max-height: 76vh;
    border-radius: 14px 14px 0 0;
    /* pehle 700 tha — contact detail ke andar wala menu dab jaata tha */
    z-index: 9400;
    box-shadow: 0 -8px 40px rgba(0, 0, 0, 0.5);
    padding-bottom: calc(10px + env(safe-area-inset-bottom));
  }
  .cs-mi {
    padding: 13px 20px;
    font-size: 15px;
  }
  .cs-sub {
    position: static;
    box-shadow: none;
    background: var(--menu-hov);
    border-radius: 0;
    margin-top: 4px;
  }
  .cs-fw {
    padding: 12px;
  }
  .cs-cal,
  .cs-form,
  .cs-lpb,
  .cs-ask {
    width: 100%;
    max-width: 100%;
  }
  .cs-form {
    max-height: 90vh;
  }
  /* City + Country ek hi row mein tang parte the */
  .cs-frow {
    flex-direction: column;
    gap: 0;
  }
  .cs-ff .cs-btn {
    flex: 1;
  }
  .cs-iacts {
    gap: 26px;
  }
  .cs-k {
    width: 92px;
  }
  .cs-toasts {
    bottom: 80px;
  }
}
</style>
