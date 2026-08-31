#!/bin/bash
# ============================================================
#  ChatsSync — Batch 1 : WhatsApp-style Chats section
#  Chalane ka tareeqa:
#      cd /root/staging-build && git pull && bash apply-batch1.sh
# ============================================================
set -e

REPO="/root/staging-build"
COMPOSE="/data/coolify/applications/vdcb3i4jbkc4jsw204xguhk5"

if [ ! -f "$REPO/docker/Dockerfile" ]; then
  echo "ERROR: $REPO mein repo nahi mila."
  exit 1
fi
cd "$REPO"

echo ""
echo "=== 1/3  Files likh raha hun ==="
mkdir -p "$(dirname app/javascript/dashboard/components-next/message/bubbles/Base.vue)"
cat > app/javascript/dashboard/components-next/message/bubbles/Base.vue << 'CS_EOF_9f3a1'
<script setup>
import { computed } from 'vue';

import MessageMeta from '../MessageMeta.vue';

import { emitter } from 'shared/helpers/mitt';
import { useMessageContext } from '../provider.js';
import { useI18n } from 'vue-i18n';

import MessageFormatter from 'shared/helpers/MessageFormatter.js';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { MESSAGE_VARIANTS, ORIENTATION } from '../constants';

const props = defineProps({
  hideMeta: { type: Boolean, default: false },
});

const { variant, orientation, inReplyTo, shouldGroupWithNext } =
  useMessageContext();
const { t } = useI18n();

const varaintBaseMap = {
  [MESSAGE_VARIANTS.AGENT]: 'bg-n-solid-sent text-n-slate-12',
  [MESSAGE_VARIANTS.PRIVATE]:
    'bg-n-solid-amber text-n-amber-12 [&_.prosemirror-mention-node]:font-semibold',
  [MESSAGE_VARIANTS.USER]: 'bg-n-solid-received text-n-slate-12',
  [MESSAGE_VARIANTS.ACTIVITY]: 'bg-n-alpha-1 text-n-slate-11 text-sm',
  [MESSAGE_VARIANTS.BOT]: 'bg-n-solid-sent text-n-slate-12',
  [MESSAGE_VARIANTS.TEMPLATE]: 'bg-n-solid-sent text-n-slate-12',
  [MESSAGE_VARIANTS.ERROR]: 'bg-n-ruby-4 text-n-ruby-12',
  [MESSAGE_VARIANTS.EMAIL]: 'w-full',
  [MESSAGE_VARIANTS.UNSUPPORTED]:
    'bg-n-solid-amber/70 border border-dashed border-n-amber-12 text-n-amber-12',
};

const orientationMap = {
  [ORIENTATION.LEFT]:
    'left-bubble rounded-lg ltr:rounded-tl-none rtl:rounded-tr-none',
  [ORIENTATION.RIGHT]:
    'right-bubble rounded-lg ltr:rounded-tr-none rtl:rounded-tl-none',
  [ORIENTATION.CENTER]: 'rounded-md',
};

const flexOrientationClass = computed(() => {
  const map = {
    [ORIENTATION.LEFT]: 'justify-start',
    [ORIENTATION.RIGHT]: 'justify-end',
    [ORIENTATION.CENTER]: 'justify-center',
  };

  return map[orientation.value];
});

const messageClass = computed(() => {
  const classToApply = [varaintBaseMap[variant.value]];

  if (variant.value !== MESSAGE_VARIANTS.ACTIVITY) {
    classToApply.push(orientationMap[orientation.value]);
  } else {
    classToApply.push('rounded-lg');
  }

  return classToApply;
});

const scrollToMessage = () => {
  emitter.emit(BUS_EVENTS.SCROLL_TO_MESSAGE, {
    messageId: inReplyTo.value.id,
  });
};

const shouldShowMeta = computed(
  () =>
    !props.hideMeta &&
    !shouldGroupWithNext.value &&
    variant.value !== MESSAGE_VARIANTS.ACTIVITY
);

const replyToPreview = computed(() => {
  if (!inReplyTo) return '';

  const { content, attachments } = inReplyTo.value;

  if (content) return new MessageFormatter(content).formattedMessage;
  if (attachments?.length) {
    const firstAttachment = attachments[0];
    const fileType = firstAttachment.fileType ?? firstAttachment.file_type;

    return t(`CHAT_LIST.ATTACHMENTS.${fileType}.CONTENT`);
  }

  return t('CONVERSATION.REPLY_MESSAGE_NOT_FOUND');
});
</script>

<template>
  <div
    class="text-sm min-w-0"
    :class="[
      messageClass,
      {
        'max-w-lg': variant !== MESSAGE_VARIANTS.EMAIL,
      },
    ]"
  >
    <div
      v-if="inReplyTo"
      class="p-2 -mx-1 mb-2 rounded-lg cursor-pointer bg-n-alpha-black1"
      @click="scrollToMessage"
    >
      <div
        v-dompurify-html="replyToPreview"
        class="prose prose-bubble line-clamp-2"
      />
    </div>
    <slot />
    <MessageMeta
      v-if="shouldShowMeta"
      :class="[
        flexOrientationClass,
        variant === MESSAGE_VARIANTS.EMAIL ? 'px-3 pb-3' : '',
        variant === MESSAGE_VARIANTS.PRIVATE
          ? 'text-n-amber-12/50'
          : 'text-n-slate-11',
      ]"
      class="mt-2"
    />
  </div>
</template>
CS_EOF_9f3a1
echo "  ok  app/javascript/dashboard/components-next/message/bubbles/Base.vue"

mkdir -p "$(dirname app/javascript/dashboard/assets/scss/_next-colors.scss)"
cat > app/javascript/dashboard/assets/scss/_next-colors.scss << 'CS_EOF_9f3a1'
// scss-lint:disable PropertySortOrder
@layer base {
  // NEXT COLORS START
  :root {
    // slate
    --slate-1: 252 252 253;
    --slate-2: 249 249 251;
    --slate-3: 240 240 243;
    --slate-4: 232 232 236;
    --slate-5: 224 225 230;
    --slate-6: 217 217 224;
    --slate-7: 205 206 214;
    --slate-8: 185 187 198;
    --slate-9: 139 141 152;
    --slate-10: 128 131 141;
    --slate-11: 96 100 108;
    --slate-12: 28 32 36;

    --iris-1: 253 253 255;
    --iris-2: 248 248 255;
    --iris-3: 240 241 254;
    --iris-4: 230 231 255;
    --iris-5: 218 220 255;
    --iris-6: 203 205 255;
    --iris-7: 184 186 248;
    --iris-8: 155 158 240;
    --iris-9: 91 91 214;
    --iris-10: 81 81 205;
    --iris-11: 87 83 198;
    --iris-12: 39 41 98;

    --blue-1: 251 253 255;
    --blue-2: 245 249 255;
    --blue-3: 233 243 255;
    --blue-4: 218 236 255;
    --blue-5: 201 226 255;
    --blue-6: 181 213 255;
    --blue-7: 155 195 252;
    --blue-8: 117 171 247;
    --blue-9: 39 129 246;
    --blue-10: 16 115 233;
    --blue-11: 8 109 224;
    --blue-12: 11 50 101;

    --ruby-1: 255 252 253;
    --ruby-2: 255 247 248;
    --ruby-3: 254 234 237;
    --ruby-4: 255 220 225;
    --ruby-5: 255 206 214;
    --ruby-6: 248 191 200;
    --ruby-7: 239 172 184;
    --ruby-8: 229 146 163;
    --ruby-9: 229 70 102;
    --ruby-10: 220 59 93;
    --ruby-11: 202 36 77;
    --ruby-12: 100 23 43;

    --amber-1: 254 253 251;
    --amber-2: 254 251 233;
    --amber-3: 255 247 194;
    --amber-4: 255 238 156;
    --amber-5: 251 229 119;
    --amber-6: 243 214 115;
    --amber-7: 233 193 98;
    --amber-8: 226 163 54;
    --amber-9: 255 197 61;
    --amber-10: 255 186 24;
    --amber-11: 171 100 0;
    --amber-12: 79 52 34;

    --teal-1: 250 254 253;
    --teal-2: 243 251 249;
    --teal-3: 224 248 243;
    --teal-4: 204 243 234;
    --teal-5: 184 234 224;
    --teal-6: 161 222 210;
    --teal-7: 131 205 193;
    --teal-8: 83 185 171;
    --teal-9: 18 165 148;
    --teal-10: 13 155 138;
    --teal-11: 0 133 115;
    --teal-12: 13 61 56;

    --gray-1: 252 252 252;
    --gray-2: 249 249 249;
    --gray-3: 240 240 240;
    --gray-4: 232 232 232;
    --gray-5: 224 224 224;
    --gray-6: 217 217 217;
    --gray-7: 206 206 206;
    --gray-8: 187 187 187;
    --gray-9: 141 141 141;
    --gray-10: 131 131 131;
    --gray-11: 100 100 100;
    --gray-12: 32 32 32;

    --violet-1: 253 252 254;
    --violet-2: 250 248 255;
    --violet-3: 244 240 254;
    --violet-4: 235 228 255;
    --violet-5: 225 217 255;
    --violet-6: 212 202 254;
    --violet-7: 194 178 248;
    --violet-8: 169 153 236;
    --violet-9: 110 86 207;
    --violet-10: 100 84 196;
    --violet-11: 101 85 183;
    --violet-12: 47 38 95;

    --background-color: 247 247 247;
    --surface-1: 254 254 254;
    --surface-2: 255 255 255;
    --surface-active: 255 255 255;
    --background-input-box: 0, 0, 0, 0.03;
    --text-blue: 1 22 44;
    --text-purple: 2 4 49;
    --text-amber: 37 24 1;
    --border-container: 236 236 236;
    --border-strong: 226 227 231;
    --border-weak: 234 234 234;
    --border-blue-strong: 18 61 117;
    --solid-1: 255 255 255;
    --solid-2: 255 255 255;
    --solid-3: 255 255 255;
    --solid-active: 255 255 255;
    --solid-amber: 255 228 181;
    --solid-blue: 218 236 255;
    --solid-blue-2: 251 253 255;
    --solid-iris: 230 231 255;
    --solid-sent: 217 253 211;
    --solid-received: 255 255 255;
    --solid-purple: 230 231 255;
    --solid-red: 254 200 201;
    --solid-amber-button: 255 221 141;
    --card-color: 255 255 255;
    --overlay: 0, 0, 0, 0.12;
    --overlay-avatar: 255, 255, 255, 0.67;
    --button-color: 255 255 255;
    --button-hover-color: 255, 255, 255, 0.2;
    --label-background: 247 247 247;
    --label-border: 0, 0, 0, 0.04;

    --alpha-1: 215, 215, 215, 0.22;
    --alpha-2: 196, 197, 198, 0.22;
    --alpha-3: 255, 255, 255, 0.96;
    --black-alpha-1: 0, 0, 0, 0.12;
    --black-alpha-2: 0, 0, 0, 0.04;
    --border-blue: 39, 129, 246, 0.5;
    --white-alpha: 255, 255, 255, 0.8;
  }

  .dark {
    // slate
    --slate-1: 17 17 19;
    --slate-2: 24 25 27;
    --slate-3: 33 34 37;
    --slate-4: 39 42 45;
    --slate-5: 46 49 53;
    --slate-6: 54 58 63;
    --slate-7: 67 72 78;
    --slate-8: 90 97 105;
    --slate-9: 105 110 119;
    --slate-10: 119 123 132;
    --slate-11: 176 180 186;
    --slate-12: 237 238 240;

    --iris-1: 19 19 30;
    --iris-2: 23 22 37;
    --iris-3: 32 34 72;
    --iris-4: 38 42 101;
    --iris-5: 48 51 116;
    --iris-6: 61 62 130;
    --iris-7: 74 74 149;
    --iris-8: 89 88 177;
    --iris-9: 91 91 214;
    --iris-10: 84 114 228;
    --iris-11: 158 177 255;
    --iris-12: 224 223 254;

    --blue-1: 10 17 28;
    --blue-2: 15 24 38;
    --blue-3: 15 39 72;
    --blue-4: 10 49 99;
    --blue-5: 18 61 117;
    --blue-6: 29 84 134;
    --blue-7: 40 89 156;
    --blue-8: 48 106 186;
    --blue-9: 39 129 246;
    --blue-10: 21 116 231;
    --blue-11: 126 182 255;
    --blue-12: 205 227 255;

    --ruby-1: 25 17 19;
    --ruby-2: 30 21 23;
    --ruby-3: 58 20 30;
    --ruby-4: 78 19 37;
    --ruby-5: 94 26 46;
    --ruby-6: 111 37 57;
    --ruby-7: 136 52 71;
    --ruby-8: 179 68 90;
    --ruby-9: 229 70 102;
    --ruby-10: 236 90 114;
    --ruby-11: 255 148 157;
    --ruby-12: 254 210 225;

    --amber-1: 22 18 12;
    --amber-2: 29 24 15;
    --amber-3: 48 32 8;
    --amber-4: 63 39 0;
    --amber-5: 77 48 0;
    --amber-6: 92 61 5;
    --amber-7: 113 79 25;
    --amber-8: 143 100 36;
    --amber-9: 255 197 61;
    --amber-10: 255 214 10;
    --amber-11: 255 202 22;
    --amber-12: 255 231 179;

    --teal-1: 13 21 20;
    --teal-2: 17 28 27;
    --teal-3: 13 45 42;
    --teal-4: 2 59 55;
    --teal-5: 8 72 67;
    --teal-6: 20 87 80;
    --teal-7: 28 105 97;
    --teal-8: 32 126 115;
    --teal-9: 18 165 148;
    --teal-10: 14 179 158;
    --teal-11: 11 216 182;
    --teal-12: 173 240 221;

    --gray-1: 17 17 17;
    --gray-2: 25 25 25;
    --gray-3: 34 34 34;
    --gray-4: 42 42 42;
    --gray-5: 49 49 49;
    --gray-6: 58 58 58;
    --gray-7: 72 72 72;
    --gray-8: 96 96 96;
    --gray-9: 110 110 110;
    --gray-10: 123 123 123;
    --gray-11: 180 180 180;
    --gray-12: 238 238 238;

    --violet-1: 20 17 31;
    --violet-2: 27 21 37;
    --violet-3: 41 31 67;
    --violet-4: 50 37 85;
    --violet-5: 60 46 105;
    --violet-6: 71 56 135;
    --violet-7: 86 70 151;
    --violet-8: 110 86 171;
    --violet-9: 110 86 207;
    --violet-10: 125 109 217;
    --violet-11: 169 153 236;
    --violet-12: 226 221 254;

    --background-color: 28 29 32;
    --surface-1: 20 21 23;
    --surface-2: 22 23 26;
    --surface-active: 53 57 66;
    --background-input-box: 255, 255, 255, 0.02;
    --text-blue: 213 234 255;
    --text-purple: 232 233 254;
    --text-amber: 255 247 234;
    --border-strong: 46 45 50;
    --border-weak: 31 31 37;
    --border-blue-strong: 201 226 255;
    --solid-1: 23 23 26;
    --solid-2: 29 30 36;
    --solid-3: 44 45 54;
    --solid-active: 53 57 66;
    --solid-amber: 56 50 41;
    --solid-blue: 15 57 102;
    --solid-blue-2: 26 29 35;
    --solid-iris: 38 42 101;
    --solid-sent: 0 92 75;
    --solid-received: 32 44 51;
    --solid-purple: 51 51 107;
    --solid-red: 90 33 34;
    --solid-amber-button: 255 221 141;
    --card-color: 28 30 34;
    --overlay: 0, 0, 0, 0.4;
    --overlay-avatar: 0, 0, 0, 0.05;
    --button-color: 42 43 51;
    --button-hover-color: 0, 0, 0, 0.15;
    --label-background: 36 38 45;
    --label-border: 255, 255, 255, 0.03;

    --alpha-1: 35, 36, 42, 0.8;
    --alpha-2: 147, 153, 176, 0.12;
    --alpha-3: 33, 34, 38, 0.95;
    --black-alpha-1: 0, 0, 0, 0.3;
    --black-alpha-2: 0, 0, 0, 0.2;
    --border-blue: 39, 129, 246, 0.5;
    --border-container: 255, 255, 255, 0;
    --white-alpha: 255, 255, 255, 0.1;
  }
}
// NEXT COLORS END
CS_EOF_9f3a1
echo "  ok  app/javascript/dashboard/assets/scss/_next-colors.scss"

mkdir -p "$(dirname theme/colors.js)"
cat > theme/colors.js << 'CS_EOF_9f3a1'
const {
  blue,
  blueDark,
  green,
  greenDark,
  yellow,
  yellowDark,
  slate,
  slateDark,
  red,
  redDark,
  violet,
  violetDark,
} = require('@radix-ui/colors');

export const colors = {
  woot: {
    25: blue.blue2,
    50: blue.blue3,
    75: blue.blue4,
    100: blue.blue5,
    200: blue.blue7,
    300: blue.blue8,
    400: blueDark.blue11,
    500: blueDark.blue10,
    600: blueDark.blue9,
    700: blueDark.blue8,
    800: blueDark.blue6,
    900: blueDark.blue2,
  },
  green: {
    50: greenDark.green12,
    100: green.green6,
    200: green.green7,
    300: green.green8,
    400: greenDark.green10,
    500: greenDark.green9,
    600: green.green10,
    700: green.green11,
    800: greenDark.green7,
    900: greenDark.green6,
  },
  yellow: {
    50: yellow.yellow2,
    100: yellow.yellow3,
    200: yellow.yellow5,
    300: yellowDark.yellow10,
    400: yellowDark.yellow9,
    500: yellowDark.yellow11,
    600: yellow.yellow8,
    700: yellowDark.yellow7,
    800: yellowDark.yellow2,
    900: yellowDark.yellow1,
  },
  slate: {
    25: slate.slate2,
    50: slate.slate3,
    75: slate.slate4,
    100: slate.slate5,
    200: slate.slate7,
    300: slate.slate8,
    400: slateDark.slate11,
    500: slateDark.slate10,
    600: slate.slate11,
    700: slateDark.slate8,
    800: slateDark.slate4,
    900: slateDark.slate1,
  },
  black: {
    50: slate.slate2,
    100: slateDark.slate12,
    200: slate.slate7,
    300: slate.slate8,
    400: slateDark.slate11,
    500: slate.slate9,
    600: slateDark.slate9,
    700: slateDark.slate8,
    800: slateDark.slate7,
    900: slateDark.slate2,
  },
  red: {
    50: redDark.red12,
    100: red.red6,
    200: red.red8,
    300: redDark.red11,
    400: redDark.red10,
    500: red.red9,
    600: red.red10,
    700: red.red11,
    800: redDark.red8,
    900: red.red12,
  },
  violet: {
    50: violet.violet1,
    100: violetDark.violet12,
    200: violet.violet6,
    300: violet.violet8,
    400: violet.violet11,
    500: violet.violet9,
    600: violetDark.violet8,
    700: violetDark.violet7,
    800: violetDark.violet6,
    900: violet.violet12,
  },

  // next design system color
  n: {
    slate: {
      1: 'rgb(var(--slate-1) / <alpha-value>)',
      2: 'rgb(var(--slate-2) / <alpha-value>)',
      3: 'rgb(var(--slate-3) / <alpha-value>)',
      4: 'rgb(var(--slate-4) / <alpha-value>)',
      5: 'rgb(var(--slate-5) / <alpha-value>)',
      6: 'rgb(var(--slate-6) / <alpha-value>)',
      7: 'rgb(var(--slate-7) / <alpha-value>)',
      8: 'rgb(var(--slate-8) / <alpha-value>)',
      9: 'rgb(var(--slate-9) / <alpha-value>)',
      10: 'rgb(var(--slate-10) / <alpha-value>)',
      11: 'rgb(var(--slate-11) / <alpha-value>)',
      12: 'rgb(var(--slate-12) / <alpha-value>)',
    },

    iris: {
      1: 'rgb(var(--iris-1) / <alpha-value>)',
      2: 'rgb(var(--iris-2) / <alpha-value>)',
      3: 'rgb(var(--iris-3) / <alpha-value>)',
      4: 'rgb(var(--iris-4) / <alpha-value>)',
      5: 'rgb(var(--iris-5) / <alpha-value>)',
      6: 'rgb(var(--iris-6) / <alpha-value>)',
      7: 'rgb(var(--iris-7) / <alpha-value>)',
      8: 'rgb(var(--iris-8) / <alpha-value>)',
      9: 'rgb(var(--iris-9) / <alpha-value>)',
      10: 'rgb(var(--iris-10) / <alpha-value>)',
      11: 'rgb(var(--iris-11) / <alpha-value>)',
      12: 'rgb(var(--iris-12) / <alpha-value>)',
    },

    blue: {
      1: 'rgb(var(--blue-1) / <alpha-value>)',
      2: 'rgb(var(--blue-2) / <alpha-value>)',
      3: 'rgb(var(--blue-3) / <alpha-value>)',
      4: 'rgb(var(--blue-4) / <alpha-value>)',
      5: 'rgb(var(--blue-5) / <alpha-value>)',
      6: 'rgb(var(--blue-6) / <alpha-value>)',
      7: 'rgb(var(--blue-7) / <alpha-value>)',
      8: 'rgb(var(--blue-8) / <alpha-value>)',
      9: 'rgb(var(--blue-9) / <alpha-value>)',
      10: 'rgb(var(--blue-10) / <alpha-value>)',
      11: 'rgb(var(--blue-11) / <alpha-value>)',
      12: 'rgb(var(--blue-12) / <alpha-value>)',
    },

    ruby: {
      1: 'rgb(var(--ruby-1) / <alpha-value>)',
      2: 'rgb(var(--ruby-2) / <alpha-value>)',
      3: 'rgb(var(--ruby-3) / <alpha-value>)',
      4: 'rgb(var(--ruby-4) / <alpha-value>)',
      5: 'rgb(var(--ruby-5) / <alpha-value>)',
      6: 'rgb(var(--ruby-6) / <alpha-value>)',
      7: 'rgb(var(--ruby-7) / <alpha-value>)',
      8: 'rgb(var(--ruby-8) / <alpha-value>)',
      9: 'rgb(var(--ruby-9) / <alpha-value>)',
      10: 'rgb(var(--ruby-10) / <alpha-value>)',
      11: 'rgb(var(--ruby-11) / <alpha-value>)',
      12: 'rgb(var(--ruby-12) / <alpha-value>)',
    },

    amber: {
      1: 'rgb(var(--amber-1) / <alpha-value>)',
      2: 'rgb(var(--amber-2) / <alpha-value>)',
      3: 'rgb(var(--amber-3) / <alpha-value>)',
      4: 'rgb(var(--amber-4) / <alpha-value>)',
      5: 'rgb(var(--amber-5) / <alpha-value>)',
      6: 'rgb(var(--amber-6) / <alpha-value>)',
      7: 'rgb(var(--amber-7) / <alpha-value>)',
      8: 'rgb(var(--amber-8) / <alpha-value>)',
      9: 'rgb(var(--amber-9) / <alpha-value>)',
      10: 'rgb(var(--amber-10) / <alpha-value>)',
      11: 'rgb(var(--amber-11) / <alpha-value>)',
      12: 'rgb(var(--amber-12) / <alpha-value>)',
    },

    teal: {
      1: 'rgb(var(--teal-1) / <alpha-value>)',
      2: 'rgb(var(--teal-2) / <alpha-value>)',
      3: 'rgb(var(--teal-3) / <alpha-value>)',
      4: 'rgb(var(--teal-4) / <alpha-value>)',
      5: 'rgb(var(--teal-5) / <alpha-value>)',
      6: 'rgb(var(--teal-6) / <alpha-value>)',
      7: 'rgb(var(--teal-7) / <alpha-value>)',
      8: 'rgb(var(--teal-8) / <alpha-value>)',
      9: 'rgb(var(--teal-9) / <alpha-value>)',
      10: 'rgb(var(--teal-10) / <alpha-value>)',
      11: 'rgb(var(--teal-11) / <alpha-value>)',
      12: 'rgb(var(--teal-12) / <alpha-value>)',
    },

    gray: {
      1: 'rgb(var(--gray-1) / <alpha-value>)',
      2: 'rgb(var(--gray-2) / <alpha-value>)',
      3: 'rgb(var(--gray-3) / <alpha-value>)',
      4: 'rgb(var(--gray-4) / <alpha-value>)',
      5: 'rgb(var(--gray-5) / <alpha-value>)',
      6: 'rgb(var(--gray-6) / <alpha-value>)',
      7: 'rgb(var(--gray-7) / <alpha-value>)',
      8: 'rgb(var(--gray-8) / <alpha-value>)',
      9: 'rgb(var(--gray-9) / <alpha-value>)',
      10: 'rgb(var(--gray-10) / <alpha-value>)',
      11: 'rgb(var(--gray-11) / <alpha-value>)',
      12: 'rgb(var(--gray-12) / <alpha-value>)',
    },

    violet: {
      1: 'rgb(var(--violet-1) / <alpha-value>)',
      2: 'rgb(var(--violet-2) / <alpha-value>)',
      3: 'rgb(var(--violet-3) / <alpha-value>)',
      4: 'rgb(var(--violet-4) / <alpha-value>)',
      5: 'rgb(var(--violet-5) / <alpha-value>)',
      6: 'rgb(var(--violet-6) / <alpha-value>)',
      7: 'rgb(var(--violet-7) / <alpha-value>)',
      8: 'rgb(var(--violet-8) / <alpha-value>)',
      9: 'rgb(var(--violet-9) / <alpha-value>)',
      10: 'rgb(var(--violet-10) / <alpha-value>)',
      11: 'rgb(var(--violet-11) / <alpha-value>)',
      12: 'rgb(var(--violet-12) / <alpha-value>)',
    },

    black: '#000000',
    brand: '#2781F6',
    portal: 'var(--dynamic-portal-color)',
    'portal-soft': 'var(--dynamic-portal-color-soft)',
    'portal-faint': 'var(--dynamic-portal-color-faint)',
    background: 'rgb(var(--background-color) / <alpha-value>)',
    'input-background': 'rgba(var(--background-input-box))',
    surface: {
      1: 'rgb(var(--surface-1) / <alpha-value>)',
      2: 'rgb(var(--surface-2) / <alpha-value>)',
      active: 'rgb(var(--surface-active) / <alpha-value>)',
    },
    solid: {
      1: 'rgb(var(--solid-1) / <alpha-value>)',
      2: 'rgb(var(--solid-2) / <alpha-value>)',
      3: 'rgb(var(--solid-3) / <alpha-value>)',
      active: 'rgb(var(--solid-active) / <alpha-value>)',
      amber: 'rgb(var(--solid-amber) / <alpha-value>)',
      'amber-button': 'rgb(var(--solid-amber-button) / <alpha-value>)',
      blue: 'rgb(var(--solid-blue) / <alpha-value>)',
      'blue-2': 'rgb(var(--solid-blue-2) / <alpha-value>)',
      red: 'rgb(var(--solid-red) / <alpha-value>)',
      iris: 'rgb(var(--solid-iris) / <alpha-value>)',
      sent: 'rgb(var(--solid-sent) / <alpha-value>)',
      received: 'rgb(var(--solid-received) / <alpha-value>)',
      purple: 'rgb(var(--solid-purple) / <alpha-value>)',
    },
    alpha: {
      1: 'rgba(var(--alpha-1))',
      2: 'rgba(var(--alpha-2))',
      3: 'rgba(var(--alpha-3))',
      black1: 'rgba(var(--black-alpha-1))',
      black2: 'rgba(var(--black-alpha-2))',
      white: 'rgba(var(--white-alpha))',
    },
    // Border colors
    weak: 'rgb(var(--border-weak) / <alpha-value>)',
    container: 'rgba(var(--border-container))',
    strong: 'rgb(var(--border-strong) / <alpha-value>)',
    'blue-strong': 'rgb(var(--border-blue-strong) / <alpha-value>)',
    'blue-border': 'rgba(var(--border-blue))',
    // Text colors
    'blue-text': 'rgb(var(--text-blue) / <alpha-value>)',
    'purple-text': 'rgb(var(--text-purple) / <alpha-value>)',
    'amber-text': 'rgb(var(--text-amber) / <alpha-value>)',
    card: 'rgb(var(--card-color) / <alpha-value>)',
    overlay: {
      default: 'rgba(var(--overlay))',
      avatar: 'rgba(var(--overlay-avatar))',
    },
    button: {
      color: 'rgb(var(--button-color) / <alpha-value>)',
      hover: 'rgb(var(--button-hover-color) / <alpha-value>)',
    },
    label: {
      color: 'rgb(var(--label-background) / <alpha-value>)',
      border: 'rgba(var(--label-border))',
    },
  },
};
CS_EOF_9f3a1
echo "  ok  theme/colors.js"

mkdir -p "$(dirname app/javascript/dashboard/components-next/Conversation/ConversationCard/ConversationCard.vue)"
cat > app/javascript/dashboard/components-next/Conversation/ConversationCard/ConversationCard.vue << 'CS_EOF_9f3a1'
<script setup>
import { computed, ref } from 'vue';
import { getInboxIconByType } from 'dashboard/helper/inbox';
import { useRouter, useRoute } from 'vue-router';
import { frontendURL, conversationUrl } from 'dashboard/helper/URLHelper.js';
import { dynamicTime, shortTimestamp } from 'shared/helpers/timeHelper';

import Icon from 'dashboard/components-next/icon/Icon.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import CardMessagePreview from './CardMessagePreview.vue';
import CardMessagePreviewWithMeta from './CardMessagePreviewWithMeta.vue';
import CardPriorityIcon from './CardPriorityIcon.vue';

const props = defineProps({
  conversation: {
    type: Object,
    required: true,
  },
  contact: {
    type: Object,
    required: true,
  },
  stateInbox: {
    type: Object,
    required: true,
  },
  accountLabels: {
    type: Array,
    required: true,
  },
});

const router = useRouter();
const route = useRoute();

const cardMessagePreviewWithMetaRef = ref(null);

const currentContact = computed(() => props.contact);

const currentContactName = computed(() => currentContact.value?.name);
const currentContactThumbnail = computed(() => currentContact.value?.thumbnail);
const currentContactStatus = computed(
  () => currentContact.value?.availabilityStatus
);

const inbox = computed(() => props.stateInbox);

const inboxName = computed(() => inbox.value?.name);

const inboxIcon = computed(() => {
  const { channelType, medium } = inbox.value;
  return getInboxIconByType(channelType, medium);
});

const lastActivityAt = computed(() => {
  const timestamp = props.conversation?.timestamp;
  return timestamp ? shortTimestamp(dynamicTime(timestamp)) : '';
});

const showMessagePreviewWithoutMeta = computed(() => {
  const { labels = [] } = props.conversation;
  return (
    !cardMessagePreviewWithMetaRef.value?.hasSlaThreshold && labels.length === 0
  );
});

const onCardClick = e => {
  const path = frontendURL(
    conversationUrl({
      accountId: route.params.accountId,
      id: props.conversation.id,
    })
  );

  if (e.metaKey || e.ctrlKey) {
    window.open(
      window.chatwootConfig.hostURL + path,
      '_blank',
      'noopener noreferrer nofollow'
    );
    return;
  }
  router.push({ path });
};
</script>

<template>
  <div
    role="button"
    class="flex w-full gap-3 px-4 py-2.5 transition-colors duration-150 cursor-pointer"
    @click="onCardClick"
  >
    <Avatar
      :name="currentContactName"
      :src="currentContactThumbnail"
      :size="48"
      :status="currentContactStatus"
      rounded-full
    />
    <div class="flex flex-col w-full gap-0.5 min-w-0 border-b border-n-weak pb-2.5 -mb-2.5">
      <div class="flex items-center justify-between h-6 gap-2">
        <h4 class="text-base font-normal truncate text-n-slate-12">
          {{ currentContactName }}
        </h4>
        <div class="flex items-center gap-2">
          <CardPriorityIcon :priority="conversation.priority || null" />
          <div
            v-tooltip.left="inboxName"
            class="flex items-center justify-center flex-shrink-0 rounded-full bg-n-alpha-2 size-5"
          >
            <Icon
              :icon="inboxIcon"
              class="flex-shrink-0 text-n-slate-11 size-3"
            />
          </div>
          <span class="text-sm text-n-slate-10">
            {{ lastActivityAt }}
          </span>
        </div>
      </div>
      <CardMessagePreview
        v-show="showMessagePreviewWithoutMeta"
        :conversation="conversation"
      />
      <CardMessagePreviewWithMeta
        v-show="!showMessagePreviewWithoutMeta"
        ref="cardMessagePreviewWithMetaRef"
        :conversation="conversation"
        :account-labels="accountLabels"
      />
    </div>
  </div>
</template>
CS_EOF_9f3a1
echo "  ok  app/javascript/dashboard/components-next/Conversation/ConversationCard/ConversationCard.vue"

mkdir -p "$(dirname app/javascript/dashboard/components/widgets/conversation/ConversationHeader.vue)"
cat > app/javascript/dashboard/components/widgets/conversation/ConversationHeader.vue << 'CS_EOF_9f3a1'
<script setup>
import { computed, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useStore } from 'vuex';
import { useElementSize } from '@vueuse/core';
import BackButton from '../BackButton.vue';
import InboxName from '../InboxName.vue';
import MoreActions from './MoreActions.vue';
import Avatar from 'next/avatar/Avatar.vue';
import SLACardLabel from './components/SLACardLabel.vue';
import ConversationCallButton from './ConversationCallButton.vue';
import wootConstants from 'dashboard/constants/globals';
import { conversationListPageURL } from 'dashboard/helper/URLHelper';
import { snoozedReopenTime } from 'dashboard/helper/snoozeHelpers';
import { useInbox } from 'dashboard/composables/useInbox';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { copyTextToClipboard } from 'shared/helpers/clipboard';

const props = defineProps({
  chat: {
    type: Object,
    default: () => ({}),
  },
  showBackButton: {
    type: Boolean,
    default: false,
  },
});

const { t } = useI18n();
const store = useStore();
const route = useRoute();
const conversationHeader = ref(null);
const { width } = useElementSize(conversationHeader);
const { isAWebWidgetInbox } = useInbox();

const currentChat = computed(() => store.getters.getSelectedChat);
const accountId = computed(() => store.getters.getCurrentAccountId);

const chatMetadata = computed(() => props.chat.meta);

const backButtonUrl = computed(() => {
  const {
    params: { inbox_id: inboxId, label, teamId, id: customViewId },
    name,
  } = route;

  const conversationTypeMap = {
    conversation_through_mentions: 'mention',
    conversation_through_participating: 'participating',
    conversation_through_unattended: 'unattended',
  };
  return conversationListPageURL({
    accountId: accountId.value,
    inboxId,
    label,
    teamId,
    conversationType: conversationTypeMap[name],
    customViewId,
  });
});

const isHMACVerified = computed(() => {
  if (!isAWebWidgetInbox.value) {
    return true;
  }
  return chatMetadata.value.hmac_verified;
});

const currentContact = computed(() =>
  store.getters['contacts/getContact'](props.chat.meta.sender.id)
);

const isSnoozed = computed(
  () => currentChat.value.status === wootConstants.STATUS_TYPE.SNOOZED
);

const snoozedDisplayText = computed(() => {
  const { snoozed_until: snoozedUntil } = currentChat.value;
  if (snoozedUntil) {
    return `${t('CONVERSATION.HEADER.SNOOZED_UNTIL')} ${snoozedReopenTime(snoozedUntil)}`;
  }
  return t('CONVERSATION.HEADER.SNOOZED_UNTIL_NEXT_REPLY');
});

const inbox = computed(() => {
  const { inbox_id: inboxId } = props.chat;
  return store.getters['inboxes/getInbox'](inboxId);
});

const hasMultipleInboxes = computed(
  () => store.getters['inboxes/getInboxes'].length > 1
);

const hasSlaPolicyId = computed(() => props.chat?.sla_policy_id);

const copyConversationId = async () => {
  try {
    await copyTextToClipboard(String(props.chat.id));
    useAlert(t('CONVERSATION.HEADER.COPY_ID_SUCCESS'));
  } catch (error) {
    // error
  }
};
</script>

<template>
  <div
    ref="conversationHeader"
    class="flex flex-col gap-3 items-center justify-between flex-1 w-full min-w-0 xl:flex-row px-4 pt-3 pb-2 h-24 xl:h-14"
  >
    <div
      class="flex items-center justify-start w-full xl:w-auto max-w-full min-w-0 xl:flex-1"
    >
      <BackButton
        v-if="showBackButton"
        :back-url="backButtonUrl"
        class="ltr:mr-2 rtl:ml-2"
      />
      <Avatar
        :name="currentContact.name"
        :src="currentContact.thumbnail"
        :size="40"
        :status="currentContact.availability_status"
        hide-offline-status
      />
      <div
        class="flex flex-col items-start min-w-0 ml-3 overflow-hidden rtl:ml-0 rtl:mr-3"
      >
        <div class="flex flex-row items-center max-w-full gap-1 p-0 m-0">
          <span
            class="text-base font-medium truncate leading-tight text-n-slate-12"
          >
            {{ currentContact.name }}
          </span>
          <fluent-icon
            v-if="!isHMACVerified"
            v-tooltip="$t('CONVERSATION.UNVERIFIED_SESSION')"
            size="14"
            class="text-n-amber-10 my-0 mx-0 min-w-[14px] flex-shrink-0"
            icon="warning"
          />
        </div>

        <div
          class="flex items-center gap-1 overflow-hidden text-xs conversation--header--actions text-n-slate-11 text-ellipsis whitespace-nowrap"
        >
          <button
            type="button"
            class="truncate text-label-small text-n-slate-11 hover:text-n-slate-12 !p-0 cucursor-pointer"
            @click="copyConversationId"
          >
            {{ `#${chat.id}` }}
          </button>
          <span v-if="hasMultipleInboxes">•</span>
          <InboxName v-if="hasMultipleInboxes" :inbox="inbox" class="!mx-0" />
          <span v-if="isSnoozed">•</span>
          <span v-if="isSnoozed" class="font-medium text-n-amber-10">
            {{ snoozedDisplayText }}
          </span>
        </div>
      </div>
    </div>
    <div
      class="flex flex-row items-center justify-start xl:justify-end flex-shrink-0 gap-2 w-full xl:w-auto header-actions-wrap"
    >
      <SLACardLabel
        v-if="hasSlaPolicyId"
        :chat="chat"
        show-extended-info
        :parent-width="width"
        class="hidden md:flex"
      />
      <ConversationCallButton :inbox="inbox" :chat="currentChat" />
      <MoreActions :conversation-id="currentChat.id" />
    </div>
  </div>
</template>
CS_EOF_9f3a1
echo "  ok  app/javascript/dashboard/components/widgets/conversation/ConversationHeader.vue"

mkdir -p "$(dirname app/javascript/dashboard/components/widgets/conversation/MessagesView.vue)"
cat > app/javascript/dashboard/components/widgets/conversation/MessagesView.vue << 'CS_EOF_9f3a1'
<script>
import { ref, provide, useTemplateRef } from 'vue';
import { useElementSize } from '@vueuse/core';
// composable
import { useLabelSuggestions } from 'dashboard/composables/useLabelSuggestions';
import { useSnakeCase } from 'dashboard/composables/useTransformKeys';

// components
import ReplyBox from './ReplyBox.vue';
import MessageList from 'next/message/MessageList.vue';
import ConversationLabelSuggestion from './conversation/LabelSuggestion.vue';
import Banner from 'dashboard/components/ui/Banner.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ResizableEditorWrapper from './ResizableEditorWrapper.vue';

// stores and apis
import { mapGetters } from 'vuex';

// mixins
import inboxMixin, { INBOX_FEATURES } from 'shared/mixins/inboxMixin';

// utils
import { emitter } from 'shared/helpers/mitt';
import { getTypingUsersText } from '../../../helper/commons';
import { calculateScrollTop } from './helpers/scrollTopCalculationHelper';
import { LocalStorage } from 'shared/helpers/localStorage';
import {
  filterDuplicateSourceMessages,
  getReadMessages,
  getUnreadMessages,
} from 'dashboard/helper/conversationHelper';

// constants
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { REPLY_POLICY } from 'shared/constants/links';
import wootConstants from 'dashboard/constants/globals';
import { LOCAL_STORAGE_KEYS } from 'dashboard/constants/localStorage';
import { INBOX_TYPES } from 'dashboard/helper/inbox';

export default {
  components: {
    MessageList,
    ReplyBox,
    Banner,
    ConversationLabelSuggestion,
    Spinner,
    ResizableEditorWrapper,
  },
  mixins: [inboxMixin],
  setup() {
    const conversationPanelRef = ref(null);
    const resizableEditorWrapperRef = ref(null);
    const messagesViewRef = useTemplateRef('messagesViewRef');
    const topBannerRef = useTemplateRef('topBannerRef');
    const { height: containerHeight } = useElementSize(messagesViewRef);
    const { height: topBannerHeight } = useElementSize(topBannerRef);

    const {
      captainTasksEnabled,
      isLabelSuggestionFeatureEnabled,
      getLabelSuggestions,
    } = useLabelSuggestions();

    provide('contextMenuElementTarget', conversationPanelRef);

    return {
      captainTasksEnabled,
      getLabelSuggestions,
      isLabelSuggestionFeatureEnabled,
      conversationPanelRef,
      resizableEditorWrapperRef,
      messagesViewRef,
      topBannerRef,
      containerHeight,
      topBannerHeight,
    };
  },
  data() {
    return {
      isLoadingPrevious: true,
      heightBeforeLoad: null,
      conversationPanel: null,
      hasUserScrolled: false,
      isProgrammaticScroll: false,
      messageSentSinceOpened: false,
      labelSuggestions: [],
    };
  },

  computed: {
    ...mapGetters({
      currentChat: 'getSelectedChat',
      currentUserId: 'getCurrentUserID',
      listLoadingStatus: 'getAllMessagesLoaded',
      currentAccountId: 'getCurrentAccountId',
    }),
    isOpen() {
      return this.currentChat?.status === wootConstants.STATUS_TYPE.OPEN;
    },
    shouldShowLabelSuggestions() {
      return (
        this.isOpen &&
        this.captainTasksEnabled &&
        this.isLabelSuggestionFeatureEnabled &&
        !this.messageSentSinceOpened
      );
    },
    inboxId() {
      return this.currentChat.inbox_id;
    },
    inbox() {
      return this.$store.getters['inboxes/getInbox'](this.inboxId);
    },
    typingUsersList() {
      const userList = this.$store.getters[
        'conversationTypingStatus/getUserList'
      ](this.currentChat.id);
      return userList;
    },
    isAnyoneTyping() {
      const userList = this.typingUsersList;
      return userList.length !== 0;
    },
    typingUserNames() {
      const userList = this.typingUsersList;
      if (this.isAnyoneTyping) {
        const [i18nKey, params] = getTypingUsersText(userList);
        return this.$t(i18nKey, params);
      }

      return '';
    },
    getMessages() {
      const messages = this.currentChat.messages || [];
      if (this.isAWhatsAppChannel) {
        return filterDuplicateSourceMessages(messages);
      }
      return messages;
    },
    readMessages() {
      return getReadMessages(
        this.getMessages,
        this.currentChat.agent_last_seen_at
      );
    },
    unReadMessages() {
      return getUnreadMessages(
        this.getMessages,
        this.currentChat.agent_last_seen_at
      );
    },
    shouldShowSpinner() {
      return (
        (this.currentChat && this.currentChat.dataFetched === undefined) ||
        (!this.listLoadingStatus && this.isLoadingPrevious)
      );
    },
    // Check there is a instagram inbox exists with the same instagram_id
    hasDuplicateInstagramInbox() {
      const instagramId = this.inbox.instagram_id;
      const { additional_attributes: additionalAttributes = {} } = this.inbox;
      const instagramInbox =
        this.$store.getters['inboxes/getInstagramInboxByInstagramId'](
          instagramId
        );

      return (
        this.inbox.channel_type === INBOX_TYPES.FB &&
        additionalAttributes.type === 'instagram_direct_message' &&
        instagramInbox
      );
    },

    replyWindowBannerMessage() {
      if (this.isAWhatsAppChannel) {
        return this.$t('CONVERSATION.TWILIO_WHATSAPP_CAN_REPLY');
      }
      if (this.isAPIInbox) {
        const { additional_attributes: additionalAttributes = {} } = this.inbox;
        if (additionalAttributes) {
          const {
            agent_reply_time_window_message: agentReplyTimeWindowMessage,
            agent_reply_time_window: agentReplyTimeWindow,
          } = additionalAttributes;
          return (
            agentReplyTimeWindowMessage ||
            this.$t('CONVERSATION.API_HOURS_WINDOW', {
              hours: agentReplyTimeWindow,
            })
          );
        }
        return '';
      }
      return this.$t('CONVERSATION.CANNOT_REPLY');
    },
    replyWindowLink() {
      if (this.isAFacebookInbox || this.isAnInstagramChannel) {
        return REPLY_POLICY.FACEBOOK;
      }
      if (this.isAWhatsAppCloudChannel) {
        return REPLY_POLICY.WHATSAPP_CLOUD;
      }
      if (this.isATiktokChannel) {
        return REPLY_POLICY.TIKTOK;
      }
      if (!this.isAPIInbox) {
        return REPLY_POLICY.TWILIO_WHATSAPP;
      }
      return '';
    },
    replyWindowLinkText() {
      if (
        this.isAWhatsAppChannel ||
        this.isAFacebookInbox ||
        this.isAnInstagramChannel
      ) {
        return this.$t('CONVERSATION.24_HOURS_WINDOW');
      }
      if (this.isATiktokChannel) {
        return this.$t('CONVERSATION.48_HOURS_WINDOW');
      }
      if (!this.isAPIInbox) {
        return this.$t('CONVERSATION.TWILIO_WHATSAPP_24_HOURS_WINDOW');
      }
      return '';
    },
    unreadMessageCount() {
      return this.currentChat.unread_count || 0;
    },
    unreadMessageLabel() {
      const count =
        this.unreadMessageCount > 9 ? '9+' : this.unreadMessageCount;
      const label =
        this.unreadMessageCount > 1
          ? 'CONVERSATION.UNREAD_MESSAGES'
          : 'CONVERSATION.UNREAD_MESSAGE';
      return `${count} ${this.$t(label)}`;
    },
    inboxSupportsReplyTo() {
      const incoming = this.inboxHasFeature(INBOX_FEATURES.REPLY_TO);
      const outgoing =
        this.inboxHasFeature(INBOX_FEATURES.REPLY_TO_OUTGOING) &&
        !this.is360DialogWhatsAppChannel;

      return { incoming, outgoing };
    },
  },

  watch: {
    currentChat(newChat, oldChat) {
      if (newChat.id === oldChat.id) {
        return;
      }
      this.fetchAllAttachmentsFromCurrentChat();
      this.fetchSuggestions();
      this.messageSentSinceOpened = false;
      this.resetReplyEditorHeight();
    },
  },

  created() {
    emitter.on(BUS_EVENTS.SCROLL_TO_MESSAGE, this.onScrollToMessage);
    // when a message is sent we set the flag to true this hides the label suggestions,
    // until the chat is changed and the flag is reset in the watch for currentChat
    emitter.on(BUS_EVENTS.MESSAGE_SENT, () => {
      this.messageSentSinceOpened = true;
    });
  },

  mounted() {
    this.addScrollListener();
    this.fetchAllAttachmentsFromCurrentChat();
    this.fetchSuggestions();
  },

  unmounted() {
    this.removeBusListeners();
    this.removeScrollListener();
  },

  methods: {
    async fetchSuggestions() {
      // start empty, this ensures that the label suggestions are not shown
      this.labelSuggestions = [];

      if (this.isLabelSuggestionDismissed()) {
        return;
      }

      // Early exit if conversation already has labels - no need to suggest more
      const existingLabels = this.currentChat?.labels || [];
      if (existingLabels.length > 0) return;

      if (!this.captainTasksEnabled || !this.isLabelSuggestionFeatureEnabled) {
        return;
      }

      this.labelSuggestions = await this.getLabelSuggestions();

      // once the labels are fetched, we need to scroll to bottom
      // but we need to wait for the DOM to be updated
      // so we use the nextTick method
      this.$nextTick(() => {
        // this param is added to route, telling the UI to navigate to the message
        // it is triggered by the SCROLL_TO_MESSAGE method
        // see setActiveChat on ConversationView.vue for more info
        const { messageId } = this.$route.query;

        // only trigger the scroll to bottom if the user has not scrolled
        // and there's no active messageId that is selected in view
        if (!messageId && !this.hasUserScrolled) {
          this.scrollToBottom();
        }
      });
    },
    isLabelSuggestionDismissed() {
      return LocalStorage.getFlag(
        LOCAL_STORAGE_KEYS.DISMISSED_LABEL_SUGGESTIONS,
        this.currentAccountId,
        this.currentChat.id
      );
    },
    fetchAllAttachmentsFromCurrentChat() {
      this.$store.dispatch('fetchAllAttachments', this.currentChat.id);
    },
    removeBusListeners() {
      emitter.off(BUS_EVENTS.SCROLL_TO_MESSAGE, this.onScrollToMessage);
    },
    onScrollToMessage({ messageId = '' } = {}) {
      this.$nextTick(() => {
        const messageElement = document.getElementById('message' + messageId);
        if (messageElement) {
          this.isProgrammaticScroll = true;
          messageElement.scrollIntoView({ behavior: 'smooth' });
          this.fetchPreviousMessages();
        } else {
          this.scrollToBottom();
        }
      });
      this.makeMessagesRead();
    },
    addScrollListener() {
      this.conversationPanel = this.$el.querySelector('.conversation-panel');
      this.setScrollParams();
      this.conversationPanel.addEventListener('scroll', this.handleScroll);
      this.$nextTick(() => this.scrollToBottom());
      this.isLoadingPrevious = false;
    },
    removeScrollListener() {
      this.conversationPanel.removeEventListener('scroll', this.handleScroll);
    },
    scrollToBottom() {
      this.isProgrammaticScroll = true;
      let relevantMessages = [];

      // label suggestions are not part of the messages list
      // so we need to handle them separately
      let labelSuggestions =
        this.conversationPanel.querySelector('.label-suggestion');

      // if there are unread messages, scroll to the first unread message
      if (this.unreadMessageCount > 0) {
        // capturing only the unread messages
        relevantMessages =
          this.conversationPanel.querySelectorAll('.message--unread');
      } else if (labelSuggestions) {
        // when scrolling to the bottom, the label suggestions is below the last message
        // so we scroll there if there are no unread messages
        // Unread messages always take the highest priority
        relevantMessages = [labelSuggestions];
      } else {
        // if there are no unread messages or label suggestion, scroll to the last message
        // capturing last message from the messages list
        relevantMessages = Array.from(
          this.conversationPanel.querySelectorAll('.message--read')
        ).slice(-1);
      }

      this.conversationPanel.scrollTop = calculateScrollTop(
        this.conversationPanel.scrollHeight,
        this.$el.scrollHeight,
        relevantMessages
      );
    },
    setScrollParams() {
      this.heightBeforeLoad = this.conversationPanel.scrollHeight;
      this.scrollTopBeforeLoad = this.conversationPanel.scrollTop;
    },

    async fetchPreviousMessages(scrollTop = 0) {
      this.setScrollParams();
      const shouldLoadMoreMessages =
        this.currentChat.dataFetched === true &&
        !this.listLoadingStatus &&
        !this.isLoadingPrevious;

      if (
        scrollTop < 100 &&
        !this.isLoadingPrevious &&
        shouldLoadMoreMessages
      ) {
        this.isLoadingPrevious = true;
        try {
          await this.$store.dispatch('fetchPreviousMessages', {
            conversationId: this.currentChat.id,
            before: this.currentChat.messages[0].id,
          });
          const heightDifference =
            this.conversationPanel.scrollHeight - this.heightBeforeLoad;
          this.conversationPanel.scrollTop =
            this.scrollTopBeforeLoad + heightDifference;
          this.setScrollParams();
        } catch (error) {
          // Ignore Error
        } finally {
          this.isLoadingPrevious = false;
        }
      }
    },

    handleScroll(e) {
      if (this.isProgrammaticScroll) {
        // Reset the flag
        this.isProgrammaticScroll = false;
        this.hasUserScrolled = false;
      } else {
        this.hasUserScrolled = true;
      }
      emitter.emit(BUS_EVENTS.ON_MESSAGE_LIST_SCROLL);
      this.fetchPreviousMessages(e.target.scrollTop);
    },

    makeMessagesRead() {
      this.$store.dispatch('markMessagesRead', { id: this.currentChat.id });
    },
    async handleMessageRetry(message) {
      if (!message) return;
      const payload = useSnakeCase(message);
      await this.$store.dispatch('sendMessageWithData', payload);
    },
    toggleReplyEditorSize() {
      this.resizableEditorWrapperRef?.toggleEditorExpand?.();
    },
    resetReplyEditorHeight() {
      this.resizableEditorWrapperRef?.resetEditorHeight?.();
    },
  },
};
</script>

<template>
  <div
    ref="messagesViewRef"
    class="flex flex-col justify-between flex-grow h-full min-w-0 m-0"
  >
    <div ref="topBannerRef">
      <Banner
        v-if="!currentChat.can_reply"
        color-scheme="alert"
        class="mx-2 mt-2 overflow-hidden rounded-lg"
        :banner-message="replyWindowBannerMessage"
        :href-link="replyWindowLink"
        :href-link-text="replyWindowLinkText"
      />
      <Banner
        v-else-if="hasDuplicateInstagramInbox"
        color-scheme="alert"
        class="mx-2 mt-2 overflow-hidden rounded-lg"
        :banner-message="$t('CONVERSATION.OLD_INSTAGRAM_INBOX_REPLY_BANNER')"
      />
    </div>
    <MessageList
      ref="conversationPanelRef"
      class="conversation-panel cs-chat-bg flex-shrink flex-grow basis-px flex flex-col overflow-y-auto relative h-full m-0 pb-4"
      :current-user-id="currentUserId"
      :first-unread-id="unReadMessages[0]?.id"
      :is-an-email-channel="isAnEmailChannel"
      :inbox-supports-reply-to="inboxSupportsReplyTo"
      :messages="getMessages"
      @retry="handleMessageRetry"
    >
      <template #beforeAll>
        <transition name="slide-up">
          <!-- eslint-disable-next-line vue/require-toggle-inside-transition -->
          <li
            class="min-h-[4rem] flex flex-shrink-0 flex-grow-0 items-center flex-auto justify-center max-w-full mt-0 mr-0 mb-1 ml-0 relative first:mt-auto last:mb-0"
          >
            <Spinner v-if="shouldShowSpinner" class="text-n-brand" />
          </li>
        </transition>
      </template>
      <template #unreadBadge>
        <li
          v-show="unreadMessageCount != 0"
          class="list-none flex justify-center items-center"
        >
          <span
            class="shadow-lg rounded-full bg-n-brand text-white text-xs font-medium my-2.5 mx-auto px-2.5 py-1.5"
          >
            {{ unreadMessageLabel }}
          </span>
        </li>
      </template>
      <template #after>
        <ConversationLabelSuggestion
          v-if="shouldShowLabelSuggestions"
          :suggested-labels="labelSuggestions"
          :chat-labels="currentChat.labels"
          :conversation-id="currentChat.id"
        />
      </template>
    </MessageList>
    <div class="flex relative flex-col bg-n-surface-1">
      <div
        v-if="isAnyoneTyping"
        class="absolute flex items-center w-full h-0 -top-7"
      >
        <div
          class="flex py-2 pr-4 pl-5 shadow-md rounded-full bg-white dark:bg-n-solid-3 text-n-slate-11 text-xs font-semibold my-2.5 mx-auto"
        >
          {{ typingUserNames }}
          <img
            class="w-6 ltr:ml-2 rtl:mr-2"
            src="assets/images/typing.gif"
            alt="Someone is typing"
          />
        </div>
      </div>
      <ResizableEditorWrapper
        ref="resizableEditorWrapperRef"
        :container-height="Math.max(0, containerHeight - topBannerHeight)"
      >
        <ReplyBox @toggle-editor-size="toggleReplyEditorSize" />
      </ResizableEditorWrapper>
    </div>
  </div>
</template>

<style scoped lang="scss">
/* WhatsApp-style chat background: flat colour + faint doodle pattern.
   Light and dark both handled; pattern is drawn on a ::before layer so it
   never sits on top of the messages. */
.cs-chat-bg {
  background-color: #efe7de;

  &::before {
    content: '';
    position: absolute;
    inset: 0;
    pointer-events: none;
    opacity: 0.06;
    background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='352' height='232' viewBox='0 0 352 232'%3E%3Cg fill='none' stroke='%23fff' stroke-width='1.25' stroke-linecap='round' stroke-linejoin='round'%3E%3Cg transform='translate(18,20)'%3E%3Cpath d='M0 6a6 6 0 0 1 12 0 6 6 0 0 1-6 6H2l2-3a6 6 0 0 1-4-3z'/%3E%3C/g%3E%3Cg transform='translate(62,14)'%3E%3Cpath d='M0 0h14v10H4L0 13z'/%3E%3C/g%3E%3Cg transform='translate(108,22)'%3E%3Cpath d='M6 0l1.8 3.7 4 .6-2.9 2.8.7 4L6 9.2 2.4 11l.7-4L.2 4.3l4-.6z'/%3E%3C/g%3E%3Cg transform='translate(150,16)'%3E%3Cpath d='M2 2h12v12H2z M2 6h12'/%3E%3C/g%3E%3Cg transform='translate(192,20)'%3E%3Cpath d='M7 0C3 0 0 3 0 6.5 0 11 7 16 7 16s7-5 7-9.5C14 3 11 0 7 0z M7 4a2.5 2.5 0 1 1 0 5 2.5 2.5 0 0 1 0-5z'/%3E%3C/g%3E%3Cg transform='translate(234,14)'%3E%3Cpath d='M0 8c0-4 3-7 7-7s7 3 7 7-3 7-7 7-7-3-7-7z M4 8h6 M7 5v6'/%3E%3C/g%3E%3Cg transform='translate(276,20)'%3E%3Cpath d='M0 3h16v10H0z M0 3l8 6 8-6'/%3E%3C/g%3E%3Cg transform='translate(318,16)'%3E%3Cpath d='M3 0h10v4H3z M1 4h14v11H1z M6 8h4'/%3E%3C/g%3E%3Cg transform='translate(14,64)'%3E%3Cpath d='M0 10c3-5 9-5 12 0 M6 4a2.5 2.5 0 1 1 0 .01'/%3E%3C/g%3E%3Cg transform='translate(56,58)'%3E%3Cpath d='M0 0h13M0 5h9M0 10h11'/%3E%3C/g%3E%3Cg transform='translate(98,62)'%3E%3Cpath d='M8 0a8 8 0 1 1 0 16A8 8 0 0 1 8 0z M8 4v4.5l3 2'/%3E%3C/g%3E%3Cg transform='translate(140,60)'%3E%3Cpath d='M0 0l11 6-11 6z'/%3E%3C/g%3E%3Cg transform='translate(182,58)'%3E%3Cpath d='M2 0h11l3 4v11H2z M13 0v4h3'/%3E%3C/g%3E%3Cg transform='translate(224,62)'%3E%3Cpath d='M0 6h4l4-5v14l-4-5H0z M11 4a4 4 0 0 1 0 8'/%3E%3C/g%3E%3Cg transform='translate(266,58)'%3E%3Cpath d='M1 1h14v10H1z M1 11l5-4 3 2 3-3 3 3'/%3E%3C/g%3E%3Cg transform='translate(308,64)'%3E%3Cpath d='M6 0a6 6 0 0 1 6 6c0 4-6 10-6 10S0 10 0 6a6 6 0 0 1 6-6z'/%3E%3C/g%3E%3Cg transform='translate(20,106)'%3E%3Cpath d='M0 4h5l3-4h4l3 4h1v10H0z M8 6a3 3 0 1 1 0 6 3 3 0 0 1 0-6z'/%3E%3C/g%3E%3Cg transform='translate(62,110)'%3E%3Cpath d='M6 0l6 12H0z'/%3E%3C/g%3E%3Cg transform='translate(104,104)'%3E%3Cpath d='M0 0h12v12H0z M3 3h6v6H3z'/%3E%3C/g%3E%3Cg transform='translate(146,108)'%3E%3Cpath d='M0 6a6 6 0 1 0 12 0 6 6 0 0 0-12 0z M3 6l2 2 4-4'/%3E%3C/g%3E%3Cg transform='translate(188,104)'%3E%3Cpath d='M1 3h14v9H1z M4 3V1h8v2 M4 12v2h8v-2'/%3E%3C/g%3E%3Cg transform='translate(230,110)'%3E%3Cpath d='M0 12L6 0l6 12z M4 12v3h4v-3'/%3E%3C/g%3E%3Cg transform='translate(272,106)'%3E%3Cpath d='M2 2l10 10M12 2L2 12'/%3E%3C/g%3E%3Cg transform='translate(314,110)'%3E%3Cpath d='M0 8h16 M4 4l-4 4 4 4 M12 4l4 4-4 4'/%3E%3C/g%3E%3Cg transform='translate(16,150)'%3E%3Cpath d='M0 2h14v12H0z M3 0v4M11 0v4M0 6h14'/%3E%3C/g%3E%3Cg transform='translate(58,154)'%3E%3Cpath d='M7 0a7 7 0 1 1 0 14A7 7 0 0 1 7 0z M4 7h6'/%3E%3C/g%3E%3Cg transform='translate(100,148)'%3E%3Cpath d='M0 10c0-6 5-10 8-10s8 4 8 10'/%3E%3C/g%3E%3Cg transform='translate(142,152)'%3E%3Cpath d='M2 0h10v14l-5-4-5 4z'/%3E%3C/g%3E%3Cg transform='translate(184,150)'%3E%3Cpath d='M0 0h14v3H0z M2 3v10h10V3 M6 6v4M8 6v4'/%3E%3C/g%3E%3Cg transform='translate(226,154)'%3E%3Cpath d='M8 0l2 5 5 .5-4 3.5 1 5-4-2.6L4 14l1-5L1 5.5 6 5z'/%3E%3C/g%3E%3Cg transform='translate(268,148)'%3E%3Cpath d='M1 1h13v13H1z M4 7h7M7 4v7'/%3E%3C/g%3E%3Cg transform='translate(310,152)'%3E%3Cpath d='M0 5a5 5 0 0 1 10 0v6H0z M3 11v3h4v-3'/%3E%3C/g%3E%3Cg transform='translate(22,196)'%3E%3Cpath d='M0 3h16v9H0z M5 12v2h6v-2 M2 16h12'/%3E%3C/g%3E%3Cg transform='translate(64,198)'%3E%3Cpath d='M6 0a6 6 0 1 1 0 12A6 6 0 0 1 6 0z M6 3v3l2 2'/%3E%3C/g%3E%3Cg transform='translate(106,194)'%3E%3Cpath d='M0 6h12 M8 2l4 4-4 4'/%3E%3C/g%3E%3Cg transform='translate(148,198)'%3E%3Cpath d='M2 0h8a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H2a2 2 0 0 1-2-2V2a2 2 0 0 1 2-2z M4 3h4M4 6h4M4 9h2'/%3E%3C/g%3E%3Cg transform='translate(190,194)'%3E%3Cpath d='M0 0h14M0 5h14M0 10h8'/%3E%3C/g%3E%3Cg transform='translate(232,198)'%3E%3Cpath d='M7 0l7 7-7 7-7-7z'/%3E%3C/g%3E%3Cg transform='translate(274,194)'%3E%3Cpath d='M1 4h12v9H1z M4 4V2a3 3 0 0 1 6 0v2'/%3E%3C/g%3E%3Cg transform='translate(316,198)'%3E%3Cpath d='M0 0l14 7-14 7 3-7z'/%3E%3C/g%3E%3C/g%3E%3C/svg%3E");
    background-size: 352px 232px;
  }

  > * {
    position: relative;
    z-index: 1;
  }
}

.dark .cs-chat-bg {
  background-color: #0b141a;

  &::before {
    opacity: 0.045;
  }
}
</style>
CS_EOF_9f3a1
echo "  ok  app/javascript/dashboard/components/widgets/conversation/MessagesView.vue"

mkdir -p "$(dirname app/javascript/dashboard/components/widgets/conversation/ReplyBox.vue)"
cat > app/javascript/dashboard/components/widgets/conversation/ReplyBox.vue << 'CS_EOF_9f3a1'
<script>
import { defineAsyncComponent, useTemplateRef } from 'vue';
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useTrack } from 'dashboard/composables';
import keyboardEventListenerMixins from 'shared/mixins/keyboardEventListenerMixins';

import ReplyToMessage from './ReplyToMessage.vue';
import AttachmentPreview from 'dashboard/components/widgets/AttachmentsPreview.vue';
import ReplyTopPanel from 'dashboard/components/widgets/WootWriter/ReplyTopPanel.vue';
import ReplyEmailHead from './ReplyEmailHead.vue';
import ReplyBottomPanel from 'dashboard/components/widgets/WootWriter/ReplyBottomPanel.vue';
import CopilotReplyBottomPanel from 'dashboard/components/widgets/WootWriter/CopilotReplyBottomPanel.vue';
import ArticleSearchPopover from 'dashboard/routes/dashboard/helpcenter/components/ArticleSearch/SearchPopover.vue';
import CopilotEditorSection from './CopilotEditorSection.vue';
import MessageSignatureMissingAlert from './MessageSignatureMissingAlert.vue';
import ReplyBoxBanner from './ReplyBoxBanner.vue';
import QuotedEmailPreview from './QuotedEmailPreview.vue';
import { REPLY_EDITOR_MODES } from 'dashboard/components/widgets/WootWriter/constants';
import WootMessageEditor from 'dashboard/components/widgets/WootWriter/Editor.vue';
import AudioRecorder from 'dashboard/components/widgets/WootWriter/AudioRecorder.vue';
import { AUDIO_FORMATS } from 'shared/constants/messages';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { CMD_AI_ASSIST } from 'dashboard/helper/commandbar/events';
import {
  getMessageVariables,
  getUndefinedVariablesInMessage,
} from '@chatwoot/utils';
import WhatsappTemplates from './WhatsappTemplates/Modal.vue';
import ContentTemplates from './ContentTemplates/ContentTemplatesModal.vue';
import { MESSAGE_MAX_LENGTH } from 'shared/helpers/MessageTypeHelper';
import inboxMixin, { INBOX_FEATURES } from 'shared/mixins/inboxMixin';
import { trimContent, debounce, getRecipients } from '@chatwoot/utils';
import wootConstants from 'dashboard/constants/globals';
import {
  extractQuotedEmailText,
  buildQuotedEmailHeader,
  truncatePreviewText,
  appendQuotedTextToMessage,
} from 'dashboard/helper/quotedEmailHelper';
import {
  CONVERSATION_EVENTS,
  CAPTAIN_EVENTS,
} from '../../../helper/AnalyticsHelper/events';
import fileUploadMixin from 'dashboard/mixins/fileUploadMixin';
import {
  appendSignature,
  removeSignature,
  getEffectiveChannelType,
} from 'dashboard/helper/editorHelper';
import { useCopilotReply } from 'dashboard/composables/useCopilotReply';
import { useKbd } from 'dashboard/composables/utils/useKbd';
import { isFileTypeAllowedForChannel } from 'shared/helpers/FileHelper';

import { LOCAL_STORAGE_KEYS } from 'dashboard/constants/localStorage';
import { LocalStorage } from 'shared/helpers/localStorage';
import { emitter } from 'shared/helpers/mitt';
const EmojiInput = defineAsyncComponent(
  () => import('shared/components/emoji/EmojiInput.vue')
);

export default {
  components: {
    ArticleSearchPopover,
    AttachmentPreview,
    AudioRecorder,
    ReplyBoxBanner,
    EmojiInput,
    MessageSignatureMissingAlert,
    ReplyBottomPanel,
    ReplyEmailHead,
    ReplyToMessage,
    ReplyTopPanel,
    ContentTemplates,
    WhatsappTemplates,
    WootMessageEditor,
    QuotedEmailPreview,
    CopilotEditorSection,
    CopilotReplyBottomPanel,
  },
  mixins: [inboxMixin, fileUploadMixin, keyboardEventListenerMixins],
  emits: ['toggleEditorSize'],
  setup() {
    const {
      uiSettings,
      isEditorHotKeyEnabled,
      fetchSignatureFlagFromUISettings,
      setQuotedReplyFlagForInbox,
      fetchQuotedReplyFlagFromUISettings,
    } = useUISettings();

    const replyEditor = useTemplateRef('replyEditor');
    const messageEditor = useTemplateRef('messageEditor');
    const copilot = useCopilotReply();
    const shortcutKey = useKbd(['$mod', '+', 'enter']);

    return {
      uiSettings,
      isEditorHotKeyEnabled,
      fetchSignatureFlagFromUISettings,
      setQuotedReplyFlagForInbox,
      fetchQuotedReplyFlagFromUISettings,
      replyEditor,
      messageEditor,
      copilot,
      shortcutKey,
    };
  },
  data() {
    return {
      message: '',
      inReplyTo: {},
      isFocused: false,
      showEmojiPicker: false,
      attachedFiles: [],
      isRecordingAudio: false,
      recordingAudioState: '',
      recordingAudioDurationText: '',
      replyType: REPLY_EDITOR_MODES.REPLY,
      bccEmails: '',
      ccEmails: '',
      toEmails: '',
      doAutoSaveDraft: () => {},
      showWhatsAppTemplatesModal: false,
      showContentTemplatesModal: false,
      updateEditorSelectionWith: '',
      undefinedVariableMessage: '',
      showMentions: false,
      showUserMentions: false,
      showCannedMenu: false,
      showVariablesMenu: false,
      newConversationModalActive: false,
      showArticleSearchPopover: false,
      hasRecordedAudio: false,
      copilotAcceptedMessages: {},
    };
  },
  computed: {
    ...mapGetters({
      currentChat: 'getSelectedChat',
      messageSignature: 'getMessageSignature',
      currentUser: 'getCurrentUser',
      lastEmail: 'getLastEmailInSelectedChat',
      globalConfig: 'globalConfig/get',
    }),
    currentContact() {
      const senderId = this.currentChat?.meta?.sender?.id;
      if (!senderId) return {};
      return this.$store.getters['contacts/getContact'](senderId);
    },
    shouldShowReplyToMessage() {
      return (
        this.inReplyTo?.id &&
        !this.isPrivate &&
        this.inboxHasFeature(INBOX_FEATURES.REPLY_TO) &&
        !this.is360DialogWhatsAppChannel &&
        !this.copilot.isActive.value
      );
    },
    showWhatsappTemplates() {
      // We support templates for API channels if someone updates templates manually via API
      // That's why we don't explicitly check for channel type here
      const templates = this.$store.getters['inboxes/getWhatsAppTemplates'](
        this.inboxId
      );
      return !!(templates && templates.length) && !this.isPrivate;
    },
    showContentTemplates() {
      return this.isATwilioWhatsAppChannel && !this.isPrivate;
    },
    isPrivate() {
      if (
        this.currentChat.can_reply ||
        this.isAWhatsAppChannel ||
        this.isAPIInbox
      ) {
        return this.isOnPrivateNote;
      }
      return true;
    },
    hasMeaningfulEditorContent() {
      const body = this.message || '';
      // Only strip the signature when it's actually being auto-appended.
      // If the toggle is off, the agent's text might happen to match their
      // saved signature and we'd incorrectly treat it as empty.
      const shouldStripSignature =
        !this.isPrivate && this.sendWithSignature && !!this.messageSignature;
      if (!shouldStripSignature) return !!body.trim();
      const stripped = removeSignature(
        body,
        this.messageSignature,
        getEffectiveChannelType(this.channelType, this.inbox?.medium || '')
      );
      return !!stripped.trim();
    },
    isReplyRestricted() {
      return (
        !this.currentChat?.can_reply &&
        !(this.isAWhatsAppChannel || this.isAPIInbox)
      );
    },
    inboxId() {
      return this.currentChat.inbox_id;
    },
    inbox() {
      return this.$store.getters['inboxes/getInbox'](this.inboxId);
    },
    messagePlaceHolder() {
      if (this.isEditorDisabled) {
        if (this.isAWhatsAppChannel) {
          return this.$t('CONVERSATION.FOOTER.MESSAGING_RESTRICTED_WHATSAPP');
        }
        if (this.isAPIInbox) {
          return this.$t('CONVERSATION.FOOTER.MESSAGING_RESTRICTED_API');
        }
        return this.$t('CONVERSATION.FOOTER.MESSAGING_RESTRICTED');
      }
      return this.isPrivate
        ? this.$t('CONVERSATION.FOOTER.PRIVATE_MSG_INPUT')
        : this.$t('CONVERSATION.FOOTER.MSG_INPUT');
    },
    isMessageLengthReachingThreshold() {
      return this.message.length > this.maxLength - 50;
    },
    charactersRemaining() {
      return this.maxLength - this.message.length;
    },
    isReplyButtonDisabled() {
      if (this.isEditorDisabled) return true;
      if (this.isATwitterInbox) return true;
      if (this.hasAttachments || this.hasRecordedAudio) return false;

      return (
        this.isMessageEmpty ||
        this.message.length === 0 ||
        this.message.length > this.maxLength
      );
    },
    sender() {
      return {
        name: this.currentUser.name,
        thumbnail: this.currentUser.avatar_url,
      };
    },
    conversationType() {
      const { additional_attributes: additionalAttributes } = this.currentChat;
      const type = additionalAttributes ? additionalAttributes.type : '';
      return type || '';
    },
    maxLength() {
      if (this.isPrivate) {
        return MESSAGE_MAX_LENGTH.GENERAL;
      }
      if (this.isAFacebookInbox) {
        return MESSAGE_MAX_LENGTH.FACEBOOK;
      }
      if (this.isAnInstagramChannel) {
        return MESSAGE_MAX_LENGTH.INSTAGRAM;
      }
      if (this.isATelegramChannel) {
        return MESSAGE_MAX_LENGTH.TELEGRAM;
      }
      if (this.isATiktokChannel) {
        return MESSAGE_MAX_LENGTH.TIKTOK;
      }
      if (this.isATwilioWhatsAppChannel) {
        return MESSAGE_MAX_LENGTH.TWILIO_WHATSAPP;
      }
      if (this.isAWhatsAppCloudChannel) {
        return MESSAGE_MAX_LENGTH.WHATSAPP_CLOUD;
      }
      if (this.isASmsInbox) {
        return MESSAGE_MAX_LENGTH.TWILIO_SMS;
      }
      if (this.isAnEmailChannel) {
        return MESSAGE_MAX_LENGTH.EMAIL;
      }
      if (this.isATwilioSMSChannel) {
        return MESSAGE_MAX_LENGTH.TWILIO_SMS;
      }
      if (this.isAWhatsAppChannel) {
        return MESSAGE_MAX_LENGTH.WHATSAPP_CLOUD;
      }
      return MESSAGE_MAX_LENGTH.GENERAL;
    },
    showFileUpload() {
      const { image_send: imageSend } =
        this.currentChat?.additional_attributes?.tiktok_capabilities ?? {};
      const tiktokAttachmentSupported = imageSend ?? true;

      return (
        this.isAWebWidgetInbox ||
        this.isAFacebookInbox ||
        this.isAWhatsAppChannel ||
        this.isAPIInbox ||
        this.isAnEmailChannel ||
        this.isASmsInbox ||
        this.isATelegramChannel ||
        this.isALineChannel ||
        this.isAnInstagramChannel ||
        (this.isATiktokChannel && tiktokAttachmentSupported)
      );
    },
    replyButtonLabel() {
      let sendMessageText = this.$t('CONVERSATION.REPLYBOX.SEND');
      if (this.isPrivate) {
        sendMessageText = this.$t('CONVERSATION.REPLYBOX.CREATE');
      }
      const keyLabel = this.isEditorHotKeyEnabled('cmd_enter')
        ? `(${this.shortcutKey})`
        : '(↵)';
      return `${sendMessageText} ${keyLabel}`;
    },
    replyBoxClass() {
      return {
        'is-private': this.isPrivate,
        'is-focused': this.isFocused || this.hasAttachments,
      };
    },
    hasAttachments() {
      return this.attachedFiles.length;
    },
    showAudioRecorder() {
      return !this.isOnPrivateNote && this.showFileUpload;
    },
    showAudioRecorderEditor() {
      return this.showAudioRecorder && this.isRecordingAudio;
    },
    isOnPrivateNote() {
      return this.replyType === REPLY_EDITOR_MODES.NOTE;
    },
    isOnExpandedLayout() {
      const {
        LAYOUT_TYPES: { CONDENSED },
      } = wootConstants;
      const { conversation_display_type: conversationDisplayType = CONDENSED } =
        this.uiSettings;
      return conversationDisplayType !== CONDENSED;
    },
    isMessageEmpty() {
      if (!this.message) {
        return true;
      }
      return !this.message.trim().replace(/\n/g, '').length;
    },
    showReplyHead() {
      return !this.isOnPrivateNote && this.isAnEmailChannel;
    },
    enableMultipleFileUpload() {
      return (
        this.isAnEmailChannel ||
        this.isAWebWidgetInbox ||
        this.isAPIInbox ||
        this.isAWhatsAppChannel ||
        this.isATelegramChannel
      );
    },
    isSignatureEnabledForInbox() {
      return !this.isPrivate && this.sendWithSignature;
    },
    isSignatureAvailable() {
      return !!this.messageSignature;
    },
    sendWithSignature() {
      return this.fetchSignatureFlagFromUISettings(this.channelType);
    },
    conversationId() {
      return this.currentChat.id;
    },
    conversationIdByRoute() {
      return this.conversationId;
    },
    editorStateId() {
      return `draft-${this.conversationIdByRoute}-${this.replyType}`;
    },
    audioRecordFormat() {
      if (this.isAWhatsAppChannel) {
        return AUDIO_FORMATS.OGG;
      }
      if (this.isATelegramChannel) {
        return AUDIO_FORMATS.MP3;
      }
      if (this.isAPIInbox) {
        return AUDIO_FORMATS.MP3;
      }
      return AUDIO_FORMATS.WAV;
    },
    messageVariables() {
      const variables = getMessageVariables({
        conversation: this.currentChat,
        contact: this.currentContact,
        inbox: this.inbox,
      });
      return variables;
    },
    connectedPortalSlug() {
      const { help_center: portal = {} } = this.inbox;
      const { slug = '' } = portal;
      return slug;
    },
    quotedReplyPreference() {
      if (!this.isAnEmailChannel) {
        return false;
      }

      return !!this.fetchQuotedReplyFlagFromUISettings(this.channelType);
    },
    lastEmailWithQuotedContent() {
      if (!this.isAnEmailChannel) {
        return null;
      }

      const lastEmail = this.lastEmail;
      if (!lastEmail || lastEmail.private) {
        return null;
      }

      return lastEmail;
    },
    quotedEmailText() {
      return extractQuotedEmailText(this.lastEmailWithQuotedContent);
    },
    quotedEmailPreviewText() {
      return truncatePreviewText(this.quotedEmailText, 80);
    },
    shouldShowQuotedReplyToggle() {
      return this.isAnEmailChannel && !this.isOnPrivateNote;
    },
    shouldShowQuotedPreview() {
      return (
        this.shouldShowQuotedReplyToggle &&
        this.quotedReplyPreference &&
        !!this.quotedEmailText
      );
    },
    isDefaultEditorMode() {
      return !this.showAudioRecorderEditor && !this.copilot.isActive.value;
    },
    isEditorDisabled() {
      return (
        (this.isAWhatsAppChannel || this.isAPIInbox) &&
        !this.isOnPrivateNote &&
        !this.currentChat.can_reply
      );
    },
  },
  watch: {
    currentChat(conversation, oldConversation) {
      const { can_reply: canReply } = conversation;
      if (oldConversation && oldConversation.id !== conversation.id) {
        // Only update email fields when switching to a completely different conversation (by ID)
        // This prevents overwriting user input (e.g., CC/BCC fields) when performing actions
        // like self-assign or other updates that do not actually change the conversation context
        this.setCCAndToEmailsFromLastChat();
        // Reset Copilot editor state (includes cancelling ongoing generation)
        this.copilot.reset();
      }

      if (this.isOnPrivateNote) {
        return;
      }

      if (canReply || this.isAWhatsAppChannel || this.isAPIInbox) {
        this.replyType = REPLY_EDITOR_MODES.REPLY;
      } else {
        this.replyType = REPLY_EDITOR_MODES.NOTE;
      }

      this.fetchAndSetReplyTo();
    },
    // When moving from one conversation to another, the store may not have the
    // list of all the messages. A fetch is subsequently made to get the messages.
    // This watcher handles two main cases:
    // 1. When switching conversations and messages are fetched/updated, ensures CC/BCC fields are set from the latest OUTGOING/INCOMING email (not activity/private messages).
    // 2. Fixes and issue where CC/BCC fields could be reset/lost after assignment/activity actions or message mutations that did not represent a true email context change.
    lastEmail: {
      handler(lastEmail) {
        if (!lastEmail) return;
        this.setCCAndToEmailsFromLastChat();
      },
      deep: true,
    },
    conversationIdByRoute(conversationId, oldConversationId) {
      if (conversationId !== oldConversationId) {
        this.setToDraft(oldConversationId, this.replyType);
        this.getFromDraft();
        this.resetRecorderAndClearAttachments();
      }
    },
    message() {
      // Autosave the current message draft.
      this.doAutoSaveDraft();
    },
    replyType(updatedReplyType, oldReplyType) {
      this.setToDraft(this.conversationIdByRoute, oldReplyType);
      this.getFromDraft();
    },
  },

  mounted() {
    this.getFromDraft();
    // Don't use the keyboard listener mixin here as the events here are supposed to be
    // working even if the editor is focussed.
    document.addEventListener('paste', this.onPaste);
    document.addEventListener('keydown', this.handleKeyEvents);
    this.setCCAndToEmailsFromLastChat();
    this.doAutoSaveDraft = debounce(
      () => {
        this.saveDraft(this.conversationIdByRoute, this.replyType);
      },
      500,
      true
    );

    this.fetchAndSetReplyTo();
    emitter.on(BUS_EVENTS.TOGGLE_REPLY_TO_MESSAGE, this.onReplyToMessage);

    // A hacky fix to solve the drag and drop
    // Is showing on top of new conversation modal drag and drop
    // TODO need to find a better solution
    emitter.on(
      BUS_EVENTS.NEW_CONVERSATION_MODAL,
      this.onNewConversationModalActive
    );
    emitter.on(BUS_EVENTS.INSERT_INTO_NORMAL_EDITOR, this.addIntoEditor);
    emitter.on(CMD_AI_ASSIST, this.executeCopilotAction);
  },
  unmounted() {
    document.removeEventListener('paste', this.onPaste);
    document.removeEventListener('keydown', this.handleKeyEvents);
    emitter.off(BUS_EVENTS.TOGGLE_REPLY_TO_MESSAGE, this.onReplyToMessage);
    emitter.off(BUS_EVENTS.INSERT_INTO_NORMAL_EDITOR, this.addIntoEditor);
    emitter.off(
      BUS_EVENTS.NEW_CONVERSATION_MODAL,
      this.onNewConversationModalActive
    );
    emitter.off(CMD_AI_ASSIST, this.executeCopilotAction);
  },
  methods: {
    getDraftKey(
      conversationId = this.conversationIdByRoute,
      replyType = this.replyType
    ) {
      return `draft-${conversationId}-${replyType}`;
    },
    getCopilotAcceptedMessage(replyType = this.replyType) {
      const key = this.getDraftKey(this.conversationIdByRoute, replyType);
      return this.copilotAcceptedMessages[key] || '';
    },
    setCopilotAcceptedMessage(message, replyType = this.replyType) {
      const key = this.getDraftKey(this.conversationIdByRoute, replyType);
      this.copilotAcceptedMessages[key] = trimContent(
        message || '',
        this.maxLength
      );
    },
    clearCopilotAcceptedMessage(replyType = this.replyType) {
      const key = this.getDraftKey(this.conversationIdByRoute, replyType);
      delete this.copilotAcceptedMessages[key];
    },
    handleInsert(article) {
      const { url, title } = article;
      // Removing empty lines from the title
      const lines = title.split('\n');
      const nonEmptyLines = lines.filter(line => line.trim() !== '');
      const filteredMarkdown = nonEmptyLines.join(' ');
      emitter.emit(
        BUS_EVENTS.INSERT_INTO_RICH_EDITOR,
        `[${filteredMarkdown}](${url})`
      );

      useTrack(CONVERSATION_EVENTS.INSERT_ARTICLE_LINK);
    },
    toggleQuotedReply() {
      if (!this.isAnEmailChannel) {
        return;
      }

      const nextValue = !this.quotedReplyPreference;
      this.setQuotedReplyFlagForInbox(this.channelType, nextValue);
    },
    shouldIncludeQuotedEmail() {
      return (
        this.quotedReplyPreference &&
        this.shouldShowQuotedReplyToggle &&
        !!this.quotedEmailText
      );
    },
    getMessageWithQuotedEmailText(message) {
      if (!this.shouldIncludeQuotedEmail()) {
        return message;
      }

      const quotedText = this.quotedEmailText || '';
      const header = buildQuotedEmailHeader(
        this.lastEmailWithQuotedContent,
        this.currentContact,
        this.inbox
      );

      return appendQuotedTextToMessage(message, quotedText, header);
    },
    resetRecorderAndClearAttachments() {
      // Reset audio recorder UI state
      this.resetAudioRecorderInput();
      // Reset attached files
      this.attachedFiles = [];
    },
    saveDraft(conversationId, replyType) {
      if (this.message || this.message === '') {
        const key = this.getDraftKey(conversationId, replyType);
        const draftToSave = trimContent(this.message || '', this.maxLength);

        this.$store.dispatch('draftMessages/set', {
          key,
          message: draftToSave,
        });
      }
    },
    setToDraft(conversationId, replyType) {
      this.saveDraft(conversationId, replyType);
      this.message = '';
    },
    getFromDraft() {
      if (this.conversationIdByRoute) {
        const key = this.getDraftKey();
        const messageFromStore =
          this.$store.getters['draftMessages/get'](key) || '';

        // ensure that the message has signature set based on the ui setting
        this.message = this.toggleSignatureForDraft(messageFromStore);
      }
    },
    toggleSignatureForDraft(message) {
      if (this.isPrivate) {
        return message;
      }

      // Even when editor is disabled (e.g. WhatsApp/API can't reply), we must
      // still normalize stale signatures out of drafts when signature is off.
      if (this.isEditorDisabled && this.sendWithSignature) {
        return message;
      }

      const effectiveChannelType = getEffectiveChannelType(
        this.channelType,
        this.inbox?.medium || ''
      );

      return this.sendWithSignature
        ? appendSignature(message, this.messageSignature, effectiveChannelType)
        : removeSignature(message, this.messageSignature, effectiveChannelType);
    },
    removeFromDraft() {
      if (this.conversationIdByRoute) {
        const key = this.getDraftKey();
        this.$store.dispatch('draftMessages/delete', { key });
      }
    },
    getElementToBind() {
      return this.replyEditor;
    },
    getKeyboardEvents() {
      return {
        Escape: {
          action: () => {
            this.hideEmojiPicker();
          },
          allowOnFocusedInput: true,
        },
        '$mod+KeyK': {
          action: e => {
            e.preventDefault();
            const ninja = document.querySelector('ninja-keys');
            ninja.open();
          },
          allowOnFocusedInput: true,
        },
        Enter: {
          action: e => {
            if (this.isAValidEvent('enter')) {
              this.onSendReply();
              e.preventDefault();
            }
          },
          allowOnFocusedInput: true,
        },
        '$mod+Enter': {
          action: () => {
            if (this.copilot.isActive.value && this.isFocused) {
              this.onSubmitCopilotReply();
            } else if (this.isAValidEvent('cmd_enter')) {
              this.onSendReply();
            }
          },
          allowOnFocusedInput: true,
        },
      };
    },
    isAValidEvent(selectedKey) {
      return (
        !this.showUserMentions &&
        !this.showMentions &&
        !this.showCannedMenu &&
        !this.showVariablesMenu &&
        this.isFocused &&
        this.isEditorHotKeyEnabled(selectedKey)
      );
    },
    onPaste(e) {
      // Don't handle paste if compose new conversation modal is open
      if (this.newConversationModalActive) return;

      // Don't handle paste if editor is disabled
      if (this.isEditorDisabled) return;
      if (!this.showFileUpload && !this.isOnPrivateNote) return;

      // Filter valid files (non-zero size)
      Array.from(e.clipboardData.files)
        .filter(file => file.size > 0)
        .filter(file => {
          const isAllowed = isFileTypeAllowedForChannel(file, {
            channelType: this.channelType || this.inbox?.channel_type,
            medium: this.inbox?.medium,
            conversationType: this.conversationType,
            isInstagramChannel: this.isAnInstagramChannel,
            isOnPrivateNote: this.isOnPrivateNote,
          });

          if (!isAllowed) {
            useAlert(
              this.$t('CONVERSATION.FILE_TYPE_NOT_SUPPORTED', {
                fileName: file.name,
              })
            );
          }

          return isAllowed;
        })
        .forEach(file => {
          const { name, type, size } = file;
          this.onFileUpload({ name, type, size, file });
        });
    },
    toggleUserMention(currentMentionState) {
      this.showUserMentions = currentMentionState;
    },
    toggleCannedMenu(value) {
      this.showCannedMenu = value;
    },
    toggleVariablesMenu(value) {
      this.showVariablesMenu = value;
    },
    openWhatsappTemplateModal() {
      this.showWhatsAppTemplatesModal = true;
    },
    hideWhatsappTemplatesModal() {
      this.showWhatsAppTemplatesModal = false;
    },
    openContentTemplateModal() {
      this.showContentTemplatesModal = true;
    },
    hideContentTemplatesModal() {
      this.showContentTemplatesModal = false;
    },
    confirmOnSendReply() {
      if (this.isReplyButtonDisabled) {
        return;
      }
      if (!this.showMentions) {
        const copilotAcceptedMessage = this.getCopilotAcceptedMessage();
        const isOnWhatsApp =
          this.isATwilioWhatsAppChannel ||
          this.isAWhatsAppCloudChannel ||
          this.is360DialogWhatsAppChannel;
        // Instagram and TikTok do not support sending text and attachments in the same message.
        // For Instagram, combining them causes duplicate messages due to separate echo events per component.
        // For TikTok, the API rejects messages that mix text and media.
        // To handle both cases, text and attachments are always sent as separate messages.
        const isOnInstagram = this.isAnInstagramChannel;
        const isOnTiktok = this.isATiktokChannel;
        if ((isOnWhatsApp || isOnInstagram || isOnTiktok) && !this.isPrivate) {
          this.sendMessageAsMultipleMessages(
            this.message,
            copilotAcceptedMessage
          );
        } else {
          const messagePayload = this.getMessagePayload(this.message);
          this.sendMessage(
            messagePayload,
            this.message,
            copilotAcceptedMessage
          );
        }

        if (!this.isPrivate) {
          this.clearEmailField();
        }

        this.clearMessage();
        this.hideEmojiPicker();
      }
    },
    sendMessageAsMultipleMessages(message, copilotAcceptedMessage = '') {
      const messages = this.getMultipleMessagesPayload(message);
      messages.forEach(messagePayload => {
        this.sendMessage(
          messagePayload,
          messagePayload.message || '',
          copilotAcceptedMessage
        );
      });
    },
    sendMessageAnalyticsData(
      isPrivate,
      { editorMessage = '', copilotAcceptedMessage = '' } = {}
    ) {
      const normalizeForComparison = message => {
        let normalizedMessage = message || '';

        if (this.sendWithSignature && this.messageSignature && !isPrivate) {
          const effectiveChannelType = getEffectiveChannelType(
            this.channelType,
            this.inbox?.medium || ''
          );
          normalizedMessage = removeSignature(
            normalizedMessage,
            this.messageSignature,
            effectiveChannelType
          );
        }

        return trimContent(normalizedMessage);
      };

      const normalizedAcceptedMessage = normalizeForComparison(
        copilotAcceptedMessage
      );
      const normalizedEditorMessage = normalizeForComparison(editorMessage);

      if (normalizedAcceptedMessage && normalizedEditorMessage) {
        useTrack(CAPTAIN_EVENTS.AI_ASSISTED_MESSAGE_SENT, {
          conversationId: this.conversationIdByRoute,
          channelType: this.channelType,
          editedBeforeSend:
            normalizedAcceptedMessage !== normalizedEditorMessage,
          isPrivate,
        });
      }

      // Analytics data for message signature is enabled or not in channels
      return isPrivate
        ? useTrack(CONVERSATION_EVENTS.SENT_PRIVATE_NOTE)
        : useTrack(CONVERSATION_EVENTS.SENT_MESSAGE, {
            channelType: this.channelType,
            signatureEnabled: this.sendWithSignature,
            hasReplyTo: !!this.inReplyTo?.id,
          });
    },
    async onSendReply() {
      const undefinedVariables = getUndefinedVariablesInMessage({
        message: this.message,
        variables: this.messageVariables,
      });
      if (undefinedVariables.length > 0) {
        const undefinedVariablesCount =
          undefinedVariables.length > 1 ? undefinedVariables.length : 1;
        this.undefinedVariableMessage = this.$t(
          'CONVERSATION.REPLYBOX.UNDEFINED_VARIABLES.MESSAGE',
          {
            undefinedVariablesCount,
            undefinedVariables: undefinedVariables.join(', '),
          }
        );

        const ok = await this.$refs.confirmDialog.showConfirmation();
        if (ok) {
          this.confirmOnSendReply();
        }
      } else {
        this.confirmOnSendReply();
      }
    },
    async sendMessage(
      messagePayload,
      editorMessage = '',
      copilotAcceptedMessage = ''
    ) {
      try {
        await this.$store.dispatch(
          'createPendingMessageAndSend',
          messagePayload
        );
        emitter.emit(BUS_EVENTS.SCROLL_TO_MESSAGE);
        emitter.emit(BUS_EVENTS.MESSAGE_SENT);
        this.removeFromDraft();
        this.sendMessageAnalyticsData(messagePayload.private, {
          editorMessage,
          copilotAcceptedMessage,
        });
      } catch (error) {
        const errorMessage =
          error?.response?.data?.error || this.$t('CONVERSATION.MESSAGE_ERROR');
        useAlert(errorMessage);
      }
    },
    async onSendWhatsAppReply(messagePayload) {
      this.sendMessage({
        conversationId: this.currentChat.id,
        ...messagePayload,
      });
      this.hideWhatsappTemplatesModal();
    },
    async onSendContentTemplateReply(messagePayload) {
      this.sendMessage({
        conversationId: this.currentChat.id,
        ...messagePayload,
      });
      this.hideContentTemplatesModal();
    },
    setReplyMode(mode = REPLY_EDITOR_MODES.REPLY) {
      // Clear attachments when switching between private note and reply modes
      // This is to prevent from breaking the upload rules
      if (this.attachedFiles.length > 0) this.attachedFiles = [];

      const { can_reply: canReply } = this.currentChat;
      this.$store.dispatch('draftMessages/setReplyEditorMode', {
        mode,
      });
      if (canReply || this.isAWhatsAppChannel || this.isAPIInbox)
        this.replyType = mode;
      if (this.isRecordingAudio) {
        this.toggleAudioRecorder();
      }
    },
    clearEditorSelection() {
      this.updateEditorSelectionWith = '';
    },
    addIntoEditor(content) {
      this.updateEditorSelectionWith = content;
      this.onFocus();
    },
    executeCopilotAction(action, data) {
      this.copilot.execute(action, data);
    },
    clearMessage() {
      this.message = '';
      this.clearCopilotAcceptedMessage();
      if (this.sendWithSignature && !this.isPrivate) {
        // if signature is enabled, append it to the message
        const effectiveChannelType = getEffectiveChannelType(
          this.channelType,
          this.inbox?.medium || ''
        );
        this.message = appendSignature(
          this.message,
          this.messageSignature,
          effectiveChannelType
        );
      }
      this.attachedFiles = [];
      this.isRecordingAudio = false;
      this.resetReplyToMessage();
      this.resetAudioRecorderInput();
    },
    clearEmailField() {
      this.ccEmails = '';
      this.bccEmails = '';
      this.toEmails = '';
    },

    toggleEmojiPicker() {
      this.showEmojiPicker = !this.showEmojiPicker;
    },
    toggleAudioRecorder() {
      this.isRecordingAudio = !this.isRecordingAudio;
      if (!this.isRecordingAudio) {
        this.resetAudioRecorderInput();
      }
    },
    toggleAudioRecorderPlayPause() {
      if (!this.$refs.audioRecorderInput) return;
      if (!this.recordingAudioState) {
        this.$refs.audioRecorderInput.stopRecording();
      } else {
        this.$refs.audioRecorderInput.playPause();
      }
    },
    hideEmojiPicker() {
      if (this.showEmojiPicker) {
        this.toggleEmojiPicker();
      }
    },
    onTypingOn() {
      this.toggleTyping('on');
    },
    onTypingOff() {
      this.toggleTyping('off');
    },
    onBlur() {
      this.isFocused = false;
      this.saveDraft(this.conversationIdByRoute, this.replyType);
    },
    onFocus() {
      this.isFocused = true;
    },
    onRecordProgressChanged(duration) {
      this.recordingAudioDurationText = duration;
    },
    onFinishRecorder(file) {
      this.recordingAudioState = 'stopped';
      this.hasRecordedAudio = true;
      // Added a new key isVoiceMessage to the file to identify recorded audio
      // Because to filter and show only non recorded audio and other attachments
      const autoRecordedFile = {
        ...file,
        isVoiceMessage: true,
      };
      return file && this.onFileUpload(autoRecordedFile);
    },
    onRecordError() {
      this.toggleAudioRecorder();
      useAlert(this.$t('CONVERSATION.REPLYBOX.AUDIO_CONVERSION_FAILED'));
    },
    toggleTyping(status) {
      const conversationId = this.currentChat.id;
      const isPrivate = this.isPrivate;

      if (!conversationId) {
        return;
      }

      this.$store.dispatch('conversationTypingStatus/toggleTyping', {
        status,
        conversationId,
        isPrivate,
      });
    },
    attachFile({ blob, file }) {
      if (!this.showFileUpload && !this.isOnPrivateNote) return;

      const reader = new FileReader();
      reader.readAsDataURL(file.file);
      reader.onloadend = () => {
        this.attachedFiles.push({
          currentChatId: this.currentChat.id,
          resource: blob || file,
          isPrivate: this.isPrivate,
          thumb: reader.result,
          blobSignedId: blob ? blob.signed_id : undefined,
          isVoiceMessage: file?.isVoiceMessage || false,
        });
      };
    },
    removeAttachment(attachments) {
      this.attachedFiles = attachments;
    },
    setReplyToInPayload(payload) {
      if (this.inReplyTo?.id) {
        return {
          ...payload,
          contentAttributes: {
            ...payload.contentAttributes,
            in_reply_to: this.inReplyTo.id,
          },
        };
      }

      return payload;
    },
    getMultipleMessagesPayload(message) {
      const multipleMessagePayload = [];

      if (this.attachedFiles && this.attachedFiles.length) {
        let caption =
          this.isAnInstagramChannel || this.isATiktokChannel ? '' : message;
        this.attachedFiles.forEach(attachment => {
          const attachedFile = this.globalConfig.directUploadsEnabled
            ? attachment.blobSignedId
            : attachment.resource.file;
          let attachmentPayload = {
            conversationId: this.currentChat.id,
            files: [attachedFile],
            private: false,
            message: caption,
            sender: this.sender,
            isVoiceMessage: attachment.isVoiceMessage || false,
          };

          attachmentPayload = this.setReplyToInPayload(attachmentPayload);
          multipleMessagePayload.push(attachmentPayload);
          // For WhatsApp, only the first attachment gets a caption
          if (!this.isAnInstagramChannel) caption = '';
        });
      }

      const hasNoAttachments =
        !this.attachedFiles || !this.attachedFiles.length;
      // For Instagram and TikTok, text must always be sent as a separate message (no captions on attachments).
      // For WhatsApp, we only need a text message if there are no attachments.
      if (
        ((this.isAnInstagramChannel || this.isATiktokChannel) &&
          this.message) ||
        (!(this.isAnInstagramChannel || this.isATiktokChannel) &&
          hasNoAttachments)
      ) {
        let messagePayload = {
          conversationId: this.currentChat.id,
          message,
          private: false,
          sender: this.sender,
        };

        messagePayload = this.setReplyToInPayload(messagePayload);

        multipleMessagePayload.push(messagePayload);
      }

      return multipleMessagePayload;
    },
    getMessagePayload(message) {
      const messageWithQuote = this.getMessageWithQuotedEmailText(message);

      let messagePayload = {
        conversationId: this.currentChat.id,
        message: messageWithQuote,
        private: this.isPrivate,
        sender: this.sender,
      };
      messagePayload = this.setReplyToInPayload(messagePayload);

      if (this.attachedFiles && this.attachedFiles.length) {
        messagePayload.files = [];
        this.attachedFiles.forEach(attachment => {
          if (this.globalConfig.directUploadsEnabled) {
            messagePayload.files.push(attachment.blobSignedId);
            if (attachment.isVoiceMessage) {
              messagePayload.isVoiceMessage = true;
            }
          } else {
            messagePayload.files.push(attachment.resource.file);
          }
        });
      }

      if (this.ccEmails && !this.isOnPrivateNote) {
        messagePayload.ccEmails = this.ccEmails;
      }

      if (this.bccEmails && !this.isOnPrivateNote) {
        messagePayload.bccEmails = this.bccEmails;
      }

      if (this.toEmails && !this.isOnPrivateNote) {
        messagePayload.toEmails = this.toEmails;
      }
      return messagePayload;
    },
    setCcEmails(value) {
      this.bccEmails = value.bccEmails;
      this.ccEmails = value.ccEmails;
    },
    setCCAndToEmailsFromLastChat() {
      const conversationContact = this.currentChat?.meta?.sender?.email || '';
      const { email: inboxEmail, forward_to_email: forwardToEmail } =
        this.inbox;

      const { cc, bcc, to } = getRecipients(
        this.lastEmail,
        conversationContact,
        inboxEmail,
        forwardToEmail
      );

      this.toEmails = to.join(', ');
      this.ccEmails = cc.join(', ');
      this.bccEmails = bcc.join(', ');
    },
    fetchAndSetReplyTo() {
      const replyStorageKey = LOCAL_STORAGE_KEYS.MESSAGE_REPLY_TO;
      const replyToMessageId = LocalStorage.getFromJsonStore(
        replyStorageKey,
        this.conversationId
      );

      this.inReplyTo = this.currentChat?.messages?.find(message => {
        if (message.id === replyToMessageId) {
          return true;
        }
        return false;
      });
    },
    onReplyToMessage() {
      this.fetchAndSetReplyTo();
      if (this.inReplyTo) {
        this.$nextTick(() => {
          const pos = this.isSignatureEnabledForInbox ? 'start' : 'end';
          this.messageEditor?.focusEditorInputField(pos);
        });
      }
    },
    resetReplyToMessage() {
      const replyStorageKey = LOCAL_STORAGE_KEYS.MESSAGE_REPLY_TO;
      LocalStorage.deleteFromJsonStore(replyStorageKey, this.conversationId);
      emitter.emit(BUS_EVENTS.TOGGLE_REPLY_TO_MESSAGE);
    },
    onNewConversationModalActive(isActive) {
      // Issue is if the new conversation modal is open and we drag and drop the file
      // then the file is not getting attached to the new conversation modal
      // and it is getting attached to the current conversation reply box
      // so to fix this we are removing the drag and drop event listener from the current conversation reply box
      // When new conversation modal is open
      this.newConversationModalActive = isActive;
    },
    onSearchPopoverClose() {
      this.showArticleSearchPopover = false;
    },
    toggleInsertArticle() {
      this.showArticleSearchPopover = !this.showArticleSearchPopover;
    },
    resetAudioRecorderInput() {
      this.recordingAudioDurationText = '00:00';
      this.isRecordingAudio = false;
      this.recordingAudioState = '';
      this.hasRecordedAudio = false;
      // Only clear the recorded audio when we click toggle button.
      this.attachedFiles = this.attachedFiles.filter(
        file => !file?.isVoiceMessage
      );
    },
    toggleEditorSize() {
      this.$emit('toggleEditorSize');
      this.$nextTick(() => this.messageEditor?.focusEditorInputField());
    },
    onSubmitCopilotReply() {
      const acceptedMessage = this.copilot.accept();
      this.message = acceptedMessage;
      this.setCopilotAcceptedMessage(acceptedMessage);
    },
  },
};
</script>

<template>
  <ReplyBoxBanner :message="message" :is-on-private-note="isOnPrivateNote" />
  <div ref="replyEditor" class="reply-box" :class="replyBoxClass">
    <ReplyTopPanel
      :mode="replyType"
      :conversation-id="conversationId"
      :is-reply-restricted="isReplyRestricted"
      :disabled="
        (copilot.isActive.value && copilot.isButtonDisabled.value) ||
        showAudioRecorderEditor
      "
      :is-editor-disabled="isEditorDisabled"
      :is-message-length-reaching-threshold="isMessageLengthReachingThreshold"
      :characters-remaining="charactersRemaining"
      :editor-content="message"
      :has-content="hasMeaningfulEditorContent"
      @set-reply-mode="setReplyMode"
      @toggle-editor-size="toggleEditorSize"
      @toggle-copilot="copilot.toggleEditor"
      @execute-copilot-action="executeCopilotAction"
    />
    <ArticleSearchPopover
      v-if="showArticleSearchPopover && connectedPortalSlug"
      :selected-portal-slug="connectedPortalSlug"
      @insert="handleInsert"
      @close="onSearchPopoverClose"
    />
    <Transition
      mode="out-in"
      enter-active-class="transition-all duration-300 ease-out"
      enter-from-class="opacity-0 translate-y-2 scale-[0.98]"
      enter-to-class="opacity-100 translate-y-0 scale-100"
      leave-active-class="transition-all duration-200 ease-in"
      leave-from-class="opacity-100 translate-y-0 scale-100"
      leave-to-class="opacity-0 translate-y-2 scale-[0.98]"
    >
      <div :key="copilot.editorTransitionKey.value" class="reply-box__top">
        <ReplyToMessage
          v-if="shouldShowReplyToMessage"
          :message="inReplyTo"
          @dismiss="resetReplyToMessage"
        />
        <EmojiInput
          v-if="showEmojiPicker"
          v-on-clickaway="hideEmojiPicker"
          :class="{
            'emoji-dialog--expanded': isOnExpandedLayout,
          }"
          :on-click="addIntoEditor"
        />
        <ReplyEmailHead
          v-if="showReplyHead && isDefaultEditorMode"
          v-model:cc-emails="ccEmails"
          v-model:bcc-emails="bccEmails"
          v-model:to-emails="toEmails"
        />
        <AudioRecorder
          v-if="showAudioRecorderEditor"
          ref="audioRecorderInput"
          :audio-record-format="audioRecordFormat"
          @recorder-progress-changed="onRecordProgressChanged"
          @finish-record="onFinishRecorder"
          @record-error="onRecordError"
          @play="recordingAudioState = 'playing'"
          @pause="recordingAudioState = 'paused'"
        />
        <CopilotEditorSection
          v-if="copilot.isActive.value && !showAudioRecorderEditor"
          :show-copilot-editor="copilot.showEditor.value"
          :is-generating-content="copilot.isGenerating.value"
          :generated-content="copilot.generatedContent.value"
          :placeholder="$t('CONVERSATION.FOOTER.COPILOT_MSG_INPUT')"
          @focus="onFocus"
          @blur="onBlur"
          @clear-selection="clearEditorSelection"
          @close="copilot.showEditor.value = false"
          @content-ready="copilot.setContentReady"
          @send="copilot.sendFollowUp"
        />
        <WootMessageEditor
          v-else-if="!showAudioRecorderEditor"
          ref="messageEditor"
          v-model="message"
          :conversation-id="conversationId"
          :editor-id="editorStateId"
          class="input popover-prosemirror-menu"
          :is-private="isOnPrivateNote"
          :placeholder="messagePlaceHolder"
          :update-selection-with="updateEditorSelectionWith"
          :min-height="4"
          :disabled="isEditorDisabled"
          enable-variables
          :variables="messageVariables"
          :signature="messageSignature"
          allow-signature
          :channel-type="channelType"
          :medium="inbox.medium"
          @typing-off="onTypingOff"
          @typing-on="onTypingOn"
          @focus="onFocus"
          @blur="onBlur"
          @toggle-user-mention="toggleUserMention"
          @toggle-canned-menu="toggleCannedMenu"
          @toggle-variables-menu="toggleVariablesMenu"
          @clear-selection="clearEditorSelection"
          @execute-copilot-action="executeCopilotAction"
        />

        <QuotedEmailPreview
          v-if="shouldShowQuotedPreview && isDefaultEditorMode"
          :quoted-email-text="quotedEmailText"
          :preview-text="quotedEmailPreviewText"
          class="mb-2"
          @toggle="toggleQuotedReply"
        />

        <div
          v-if="hasAttachments && isDefaultEditorMode"
          class="bg-transparent py-0 mb-2"
          @paste="onPaste"
        >
          <AttachmentPreview
            class="mt-2"
            :attachments="attachedFiles"
            @remove-attachment="removeAttachment"
          />
        </div>
        <MessageSignatureMissingAlert
          v-if="
            isSignatureEnabledForInbox &&
            !isSignatureAvailable &&
            isDefaultEditorMode
          "
          class="mb-2"
        />
      </div>
    </Transition>

    <Transition
      mode="out-in"
      enter-active-class="transition-all duration-300 ease-out"
      enter-from-class="opacity-0 translate-y-2 scale-[0.98]"
      enter-to-class="opacity-100 translate-y-0 scale-100"
      leave-active-class="transition-all duration-200 ease-in"
      leave-from-class="opacity-100 translate-y-0 scale-100"
      leave-to-class="opacity-0 translate-y-2 scale-[0.98]"
    >
      <CopilotReplyBottomPanel
        v-if="copilot.isActive.value"
        key="copilot-bottom-panel"
        :is-generating-content="copilot.isButtonDisabled.value"
        @submit="onSubmitCopilotReply"
        @cancel="copilot.reset"
      />
      <ReplyBottomPanel
        v-else
        key="reply-bottom-panel"
        :conversation-id="conversationId"
        :enable-multiple-file-upload="enableMultipleFileUpload"
        :enable-whats-app-templates="showWhatsappTemplates"
        :enable-content-templates="showContentTemplates"
        :inbox="inbox"
        :is-on-private-note="isOnPrivateNote"
        :is-recording-audio="isRecordingAudio"
        :is-send-disabled="isReplyButtonDisabled"
        :is-note="isPrivate"
        :is-editor-disabled="isEditorDisabled"
        :on-file-upload="onFileUpload"
        :on-send="onSendReply"
        :conversation-type="conversationType"
        :recording-audio-duration-text="recordingAudioDurationText"
        :recording-audio-state="recordingAudioState"
        :send-button-text="replyButtonLabel"
        :show-audio-recorder="showAudioRecorder"
        :show-emoji-picker="showEmojiPicker"
        :show-file-upload="showFileUpload"
        :show-quoted-reply-toggle="shouldShowQuotedReplyToggle"
        :quoted-reply-enabled="quotedReplyPreference"
        :toggle-audio-recorder-play-pause="toggleAudioRecorderPlayPause"
        :toggle-audio-recorder="toggleAudioRecorder"
        :toggle-emoji-picker="toggleEmojiPicker"
        :message="message"
        :portal-slug="connectedPortalSlug"
        :new-conversation-modal-active="newConversationModalActive"
        @select-whatsapp-template="openWhatsappTemplateModal"
        @select-content-template="openContentTemplateModal"
        @toggle-insert-article="toggleInsertArticle"
        @toggle-quoted-reply="toggleQuotedReply"
      />
    </Transition>

    <WhatsappTemplates
      :inbox-id="inbox.id"
      :show="showWhatsAppTemplatesModal"
      @close="hideWhatsappTemplatesModal"
      @on-send="onSendWhatsAppReply"
      @cancel="hideWhatsappTemplatesModal"
    />

    <ContentTemplates
      :inbox-id="inbox.id"
      :show="showContentTemplatesModal"
      @close="hideContentTemplatesModal"
      @on-send="onSendContentTemplateReply"
      @cancel="hideContentTemplatesModal"
    />

    <woot-confirm-modal
      ref="confirmDialog"
      :title="$t('CONVERSATION.REPLYBOX.UNDEFINED_VARIABLES.TITLE')"
      :description="undefinedVariableMessage"
    />
  </div>
</template>

<style lang="scss" scoped>
.send-button {
  @apply mb-0;
}

.reply-box {
  /* WhatsApp composer: pill shape, sits flush at the bottom of the thread */
  @apply relative mb-3 mx-3 border border-n-weak rounded-3xl bg-n-solid-1;

  &.is-private {
    @apply bg-n-solid-amber dark:border-n-amber-3/10 border-n-amber-12/5;
  }
}

.send-button {
  @apply mb-0;
}

.reply-box__top {
  @apply relative py-0 px-4 -mt-px;
}

.emoji-dialog {
  @apply top-[unset] -bottom-10 ltr:-left-80 ltr:right-[unset] rtl:left-[unset] rtl:-right-80;

  &::before {
    filter: drop-shadow(0px 4px 4px rgba(0, 0, 0, 0.08));
    @apply ltr:-right-4 bottom-2 rtl:-left-4 ltr:rotate-[270deg] rtl:rotate-[90deg];
  }
}

.emoji-dialog--expanded {
  @apply left-[unset] bottom-0 absolute z-[100];

  &::before {
    transform: rotate(0deg);
    @apply ltr:left-1 rtl:right-1 -bottom-2;
  }
}
</style>
CS_EOF_9f3a1
echo "  ok  app/javascript/dashboard/components/widgets/conversation/ReplyBox.vue"


echo ""
echo "=== 2/3  Build (5-8 min, pehli baar zyada) ==="
docker build -f docker/Dockerfile -t chatssync-staging:latest .

echo ""
echo "=== 3/3  Staging restart ==="
cd "$COMPOSE"
grep -q "chatssync-staging:latest" docker-compose.yaml || {
  echo "  compose ko image par point kar raha hun"
  sed -i "s|image: 'vdcb3i4jbkc4jsw204xguhk5_chatwoot:.*'|image: 'chatssync-staging:latest'|" docker-compose.yaml
  sed -i "s|image: 'vdcb3i4jbkc4jsw204xguhk5_sidekiq:.*'|image: 'chatssync-staging:latest'|" docker-compose.yaml
}
docker compose up -d

echo ""
echo "============================================"
echo "  HO GAYA"
echo "  https://staging.chatssync.online"
echo "  Browser mein Ctrl+Shift+R dabana"
echo "============================================"
