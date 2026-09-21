<script setup>
import getUuid from 'widget/helpers/uuid';
import { ref, onMounted, onUnmounted } from 'vue';
import WaveSurfer from 'wavesurfer.js';
import RecordPlugin from 'wavesurfer.js/dist/plugins/record.js';
import { format, intervalToDuration } from 'date-fns';
import { convertAudio } from './utils/audioConversionUtils';

const props = defineProps({
  audioRecordFormat: {
    type: String,
    required: true,
  },
});

const emit = defineEmits([
  'recorderProgressChanged',
  'finishRecord',
  'pause',
  'play',
  'recordError',
  'recordPause',
  'recordResume',
  'recordCancel',
]);

const waveformContainer = ref(null);
const wavesurfer = ref(null);
const record = ref(null);
const isRecording = ref(false);
const isPlaying = ref(false);
const hasRecording = ref(false);
const cancelled = ref(false);
const recordedAudioUrl = ref(null);
const destroyed = ref(false);

const formatTimeProgress = time => {
  const duration = intervalToDuration({ start: 0, end: time });
  return format(
    new Date(0, 0, 0, 0, duration.minutes, duration.seconds),
    'mm:ss'
  );
};

const AUDIO_EXTENSION_MAP = {
  'audio/ogg': 'ogg',
  'audio/mp3': 'mp3',
  'audio/mpeg': 'mp3',
  'audio/wav': 'wav',
  'audio/webm': 'webm',
};

const getRecordPluginOptions = audioFormat => {
  const options = {
    scrollingWaveform: true,
    renderRecordedAudio: false,
  };
  if (
    audioFormat === 'audio/ogg' &&
    MediaRecorder.isTypeSupported('audio/ogg;codecs=opus')
  ) {
    options.mimeType = 'audio/ogg;codecs=opus';
  }
  return options;
};

const initWaveSurfer = () => {
  wavesurfer.value = WaveSurfer.create({
    container: waveformContainer.value,
    // WhatsApp jaisi waveform: patli, chhoti, grey
    waveColor: 'rgba(134, 150, 160, 0.85)',
    progressColor: 'rgba(0, 168, 132, 0.9)',
    cursorWidth: 0,
    height: 34,
    barWidth: 2,
    barGap: 2,
    barRadius: 3,
    plugins: [
      RecordPlugin.create(getRecordPluginOptions(props.audioRecordFormat)),
    ],
  });

  wavesurfer.value.on('pause', () => emit('pause'));
  wavesurfer.value.on('play', () => emit('play'));

  record.value = wavesurfer.value.plugins[0];

  wavesurfer.value.on('finish', () => {
    isPlaying.value = false;
  });

  record.value.on('record-end', async blob => {
    if (cancelled.value) {
      cancelled.value = false;
      return;
    }
    try {
      const audioBlob = await convertAudio(blob, props.audioRecordFormat);
      // Use the converted blob's actual type, which may differ from the
      // requested format when the browser can't produce it (e.g. Safari falls
      // back to MP3 instead of OGG). This keeps the filename, content type, and
      // voice-note flag consistent with the real bytes.
      const audioType = audioBlob.type || props.audioRecordFormat;
      const ext = AUDIO_EXTENSION_MAP[audioType] || 'mp3';
      const fileName = `${getUuid()}.${ext}`;
      const file = new File([audioBlob], fileName, {
        type: audioType,
      });
      if (recordedAudioUrl.value) URL.revokeObjectURL(recordedAudioUrl.value);
      recordedAudioUrl.value = URL.createObjectURL(audioBlob);
      emit('finishRecord', {
        name: file.name,
        type: file.type,
        size: file.size,
        file,
      });
      hasRecording.value = true;
      if (!destroyed.value && wavesurfer.value) {
        const ld = wavesurfer.value.load(recordedAudioUrl.value);
        if (ld && typeof ld.catch === 'function') ld.catch(() => {});
      }
      isRecording.value = false;
    } catch (error) {
      isRecording.value = false;
      hasRecording.value = false;
      emit('recordError', { error });
    }
  });

  record.value.on('record-progress', time => {
    emit('recorderProgressChanged', formatTimeProgress(time));
  });
};

const isPaused = ref(false);

const stopRecording = () => {
  if (isRecording.value) {
    record.value.stopRecording();
    isRecording.value = false;
    isPaused.value = false;
  }
};

// WhatsApp jaisa: pause matlab recording ruk jaye — apni awaz na sunayi de
const pauseResumeRecording = () => {
  if (!isRecording.value) return;
  if (isPaused.value) {
    record.value.resumeRecording();
    isPaused.value = false;
    emit('recordResume');
  } else {
    record.value.pauseRecording();
    isPaused.value = true;
    emit('recordPause');
  }
};

// delete — recording band karo aur file bhejo hi mat
const cancelRecording = () => {
  cancelled.value = true;
  if (isRecording.value) {
    record.value.stopRecording();
    isRecording.value = false;
  }
  isPaused.value = false;
  if (recordedAudioUrl.value) {
    URL.revokeObjectURL(recordedAudioUrl.value);
    recordedAudioUrl.value = null;
  }
  hasRecording.value = false;
  emit('recordCancel');
};

const startRecording = () => {
  try {
    const started = record.value.startRecording();
    isRecording.value = true;
    // startRecording() promise deta hai. Mic block ho to yahi
    // reject hota hai — pehle koi ise pakadta nahi tha, isliye
    // chup-chaap fail ho jaata tha.
    if (started && typeof started.catch === 'function') {
      started.catch(error => {
        isRecording.value = false;
        emit('recordError', { error });
      });
    }
  } catch (error) {
    isRecording.value = false;
    emit('recordError', { error });
  }
};

const playPause = () => {
  if (hasRecording.value) {
    wavesurfer.value.playPause();
    isPlaying.value = !isPlaying.value;
  }
};

onMounted(() => {
  initWaveSurfer();
  startRecording();
});

onUnmounted(() => {
  destroyed.value = true;
  if (recordedAudioUrl.value) {
    URL.revokeObjectURL(recordedAudioUrl.value);
    recordedAudioUrl.value = null;
  }
  if (wavesurfer.value) {
    try {
      wavesurfer.value.destroy();
    } catch (e) {}
    wavesurfer.value = null;
  }
});

defineExpose({
  playPause,
  stopRecording,
  pauseResumeRecording,
  cancelRecording,
  isPaused,
  record,
});
</script>

<template>
  <div ref="waveformContainer" class="cs-wave w-full" />
</template>

<style scoped>
/* WhatsApp jaisi patli waveform */
.cs-wave {
  padding: 0.25rem 0;
  min-height: 34px;
}
</style>
