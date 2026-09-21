<script setup>
import {
  computed,
  onMounted,
  useTemplateRef,
  ref,
  getCurrentInstance,
} from 'vue';
import Icon from 'next/icon/Icon.vue';
import { timeStampAppendedURL } from 'dashboard/helper/URLHelper';
import { downloadFile } from '@chatwoot/utils';
import { useEmitter } from 'dashboard/composables/emitter';
import { emitter } from 'shared/helpers/mitt';

const { attachment } = defineProps({
  attachment: {
    type: Object,
    required: true,
  },
  showTranscribedText: {
    type: Boolean,
    default: true,
  },
});

defineOptions({
  inheritAttrs: false,
});

const timeStampURL = computed(() => {
  return timeStampAppendedURL(attachment.dataUrl);
});

const TRANSCRIPT_PREVIEW_LENGTH = 200;
const isTranscriptExpanded = ref(false);
const isTranscriptLong = computed(
  () => (attachment.transcribedText?.length || 0) > TRANSCRIPT_PREVIEW_LENGTH
);
const displayedTranscript = computed(() => {
  const text = attachment.transcribedText || '';
  if (!isTranscriptLong.value || isTranscriptExpanded.value) return text;
  return `${text.slice(0, TRANSCRIPT_PREVIEW_LENGTH).trimEnd()}…`;
});

const audioPlayer = useTemplateRef('audioPlayer');

const isPlaying = ref(false);
const isMuted = ref(false);
const currentTime = ref(0);
const duration = ref(0);
const playbackSpeed = ref(1);

const { uid } = getCurrentInstance();

// MediaRecorder-produced WebM/Opus blobs lack a Duration header → <audio>.duration
// resolves to Infinity until we seek past the end, which forces the engine to
// scan the file and compute the real length. Safe no-op for files with a real
// duration already (mp3/m4a/etc).
const resolveStreamingDuration = () => {
  const el = audioPlayer.value;
  if (!el) return;
  const onTimeUpdate = () => {
    el.removeEventListener('timeupdate', onTimeUpdate);
    el.currentTime = 0;
    duration.value = el.duration;
  };
  el.addEventListener('timeupdate', onTimeUpdate);
  try {
    el.currentTime = Number.MAX_SAFE_INTEGER;
  } catch {
    el.removeEventListener('timeupdate', onTimeUpdate);
  }
};

const onLoadedMetadata = () => {
  const d = audioPlayer.value?.duration;
  if (!Number.isFinite(d)) {
    resolveStreamingDuration();
    return;
  }
  duration.value = d;
};

const playbackSpeedLabel = computed(() => {
  return `${playbackSpeed.value}x`;
});

// There maybe a chance that the audioPlayer ref is not available
// When the onLoadMetadata is called, so we need to set the duration
// value when the component is mounted
onMounted(() => {
  const d = audioPlayer.value?.duration;
  if (Number.isFinite(d)) duration.value = d;
  audioPlayer.value.playbackRate = playbackSpeed.value;
});

// Listen for global audio play events and pause if it's not this audio
useEmitter('pause_playing_audio', currentPlayingId => {
  if (currentPlayingId !== uid && isPlaying.value) {
    try {
      audioPlayer.value.pause();
    } catch {
      /* ignore pause errors */
    }
    isPlaying.value = false;
  }
});

const formatTime = time => {
  if (!time || Number.isNaN(time)) return '0:00';
  const minutes = Math.floor(time / 60);
  const seconds = Math.floor(time % 60);
  return `${minutes}:${seconds.toString().padStart(2, '0')}`;
};

const toggleMute = () => {
  audioPlayer.value.muted = !audioPlayer.value.muted;
  isMuted.value = audioPlayer.value.muted;
};

const onTimeUpdate = () => {
  currentTime.value = audioPlayer.value?.currentTime;
};

const seek = event => {
  const time = Number(event.target.value);
  audioPlayer.value.currentTime = time;
  currentTime.value = time;
};

const playOrPause = () => {
  if (isPlaying.value) {
    audioPlayer.value.pause();
    isPlaying.value = false;
  } else {
    // Emit event to pause all other audio
    emitter.emit('pause_playing_audio', uid);
    audioPlayer.value.play();
    isPlaying.value = true;
  }
};

const onEnd = () => {
  isPlaying.value = false;
  currentTime.value = 0;
  playbackSpeed.value = 1;
  audioPlayer.value.playbackRate = 1;
};

const changePlaybackSpeed = () => {
  const speeds = [1, 1.5, 2];
  const currentIndex = speeds.indexOf(playbackSpeed.value);
  const nextIndex = (currentIndex + 1) % speeds.length;
  playbackSpeed.value = speeds[nextIndex];
  audioPlayer.value.playbackRate = playbackSpeed.value;
};

// WhatsApp jaisi waveform: file ke naam se seed, taake har baar wahi shakl bane
const waveBars = computed(() => {
  const seedStr = String(attachment.dataUrl || attachment.id || 'a');
  let seed = 0;
  for (let i = 0; i < seedStr.length; i += 1) {
    seed = (seed * 31 + seedStr.charCodeAt(i)) % 100000;
  }
  const bars = [];
  for (let i = 0; i < 34; i += 1) {
    seed = (seed * 1103515245 + 12345) % 2147483648;
    bars.push(18 + ((seed >> 8) % 82));
  }
  return bars;
});

const progressPct = computed(() => {
  if (!duration.value) return 0;
  return Math.min(100, (currentTime.value / duration.value) * 100);
});

const remainingLabel = computed(() =>
  formatTime(currentTime.value > 0 ? currentTime.value : duration.value)
);

const seekToBar = index => {
  if (!duration.value) return;
  const t = (index / 34) * duration.value;
  audioPlayer.value.currentTime = t;
  currentTime.value = t;
};

const downloadAudio = async () => {
  const { fileType, dataUrl, extension } = attachment;
  downloadFile({ url: dataUrl, type: fileType, extension });
};
</script>

<template>
  <audio
    ref="audioPlayer"
    controls
    class="hidden"
    playsinline
    @loadedmetadata="onLoadedMetadata"
    @timeupdate="onTimeUpdate"
    @ended="onEnd"
  >
    <source :src="timeStampURL" />
  </audio>
  <div v-bind="$attrs" class="cs-voice">
    <div class="cs-voice__row">
      <button class="cs-voice__play" @click="playOrPause">
        <Icon
          v-if="isPlaying"
          class="size-5"
          icon="i-teenyicons-pause-small-solid"
        />
        <Icon v-else class="size-5" icon="i-teenyicons-play-small-solid" />
      </button>

      <div class="cs-voice__wave" @click.stop>
        <span
          v-for="(h, i) in waveBars"
          :key="i"
          class="cs-voice__bar"
          :class="{ 'cs-voice__bar--on': (i / 34) * 100 <= progressPct }"
          :style="{ height: h + '%' }"
          @click="seekToBar(i)"
        />
      </div>

      <span class="cs-voice__time">{{ remainingLabel }}</span>

      <button
        class="cs-voice__speed"
        :class="{ 'cs-voice__speed--on': playbackSpeed !== 1 }"
        @click="changePlaybackSpeed"
      >
        {{ playbackSpeedLabel }}
      </button>
    </div>

    <div
      v-if="attachment.transcribedText && showTranscribedText"
      class="text-n-slate-12 p-3 text-sm bg-n-alpha-1 rounded-lg w-full break-words"
    >
      {{ displayedTranscript }}
      <button
        v-if="isTranscriptLong"
        class="block mt-1 p-0 border-0 bg-transparent text-n-slate-11 hover:text-n-slate-12 font-medium"
        @click="isTranscriptExpanded = !isTranscriptExpanded"
      >
        {{
          isTranscriptExpanded
            ? $t('CONVERSATION.VOICE_CALL.TRANSCRIPT_SHOW_LESS')
            : $t('CONVERSATION.VOICE_CALL.TRANSCRIPT_SHOW_MORE')
        }}
      </button>
    </div>
  </div>
</template>

<style scoped>
/* WhatsApp jaisa voice player — bubble ke andar */
.cs-voice {
  width: 100%;
  max-width: 100%;
  min-width: 0;
}

.cs-voice__row {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.cs-voice__play {
  border: 0;
  padding: 0;
  width: 2rem;
  height: 2rem;
  flex-shrink: 0;
  display: grid;
  place-items: center;
  background: transparent;
  cursor: pointer;
  opacity: 0.85;
}

.cs-voice__play:hover {
  opacity: 1;
}

.cs-voice__wave {
  flex: 1 1 0;
  /* min-width: 0 zaroori hai warna bars bubble se bahar bah jaati hain */
  min-width: 0;
  height: 1.75rem;
  display: flex;
  align-items: center;
  gap: 1px;
  cursor: pointer;
  overflow: hidden;
}

.cs-voice__bar {
  flex: 1 1 0;
  min-width: 1px;
  border-radius: 999px;
  background: currentColor;
  opacity: 0.32;
  transition: opacity 0.12s ease;
}

.cs-voice__bar--on {
  opacity: 0.85;
}

.cs-voice__speed {
  border: 0;
  background: transparent;
  font-size: 0.6875rem;
  font-weight: 600;
  opacity: 0.5;
  cursor: pointer;
  padding: 0 0.15rem;
  flex-shrink: 0;
}

.cs-voice__speed--on {
  opacity: 0.9;
}

.cs-voice__time {
  flex-shrink: 0;
  font-size: 0.6875rem;
  opacity: 0.6;
  font-variant-numeric: tabular-nums;
}

.cs-voice__dl {
  border: 0;
  background: transparent;
  cursor: pointer;
  opacity: 0.45;
  padding: 0;
  display: grid;
  place-items: center;
}

.cs-voice__dl:hover {
  opacity: 0.85;
}
</style>
