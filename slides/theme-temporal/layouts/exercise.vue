<!--
  Exercise timer layout: "MM:SS" countdown chip with play/pause and restart buttons.
  `title` is reserved by Slidev for doc metadata, so we use `heading`.
  Example:
    ---
    layout: exercise
    minutes: 15
    heading: Exercise 1
    ---

  Buttons (when `minutes` is set):
    - Play / Pause   -> single morphing button. Starts the countdown
                        from idle, resumes from paused, or resets and
                        starts from expired.
    - Restart        -> resets to full duration and starts running.

  State persists across slide navigation via localStorage, keyed by
  (heading, minutes), so the timer keeps counting wall-clock time
  even when the slide is unmounted, and stays in sync between
  presenter view and audience view.
-->
<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue'

const props = defineProps({
  minutes: { type: [Number, String], default: '' },
  heading: { type: String, default: '' },
})

const totalSec = computed(() => {
  const n = Number(props.minutes)
  return Number.isFinite(n) && n > 0 ? Math.floor(n * 60) : 0
})

const storageKey = computed(
  () => `nexus-workshop:timer:${props.heading || 'untitled'}:${props.minutes || 0}`,
)

type Persisted =
  | { kind: 'idle' }
  | { kind: 'running'; endsAt: number }
  | { kind: 'paused'; remainingMs: number }
  | { kind: 'expired' }

function load(): Persisted {
  try {
    const raw = window.localStorage.getItem(storageKey.value)
    if (!raw) return { kind: 'idle' }
    return JSON.parse(raw) as Persisted
  } catch {
    return { kind: 'idle' }
  }
}

function save(state: Persisted) {
  try {
    window.localStorage.setItem(storageKey.value, JSON.stringify(state))
  } catch {
    // ignore write failures (private mode, quota, etc.)
  }
}

const persisted = ref<Persisted>({ kind: 'idle' })
const tickNow = ref(Date.now())
let intervalId: number | undefined
let storageListener: ((e: StorageEvent) => void) | undefined

function syncFromStorage() {
  persisted.value = load()
}

onMounted(() => {
  syncFromStorage()
  intervalId = window.setInterval(() => {
    tickNow.value = Date.now()
    if (persisted.value.kind === 'running' && persisted.value.endsAt <= tickNow.value) {
      persisted.value = { kind: 'expired' }
      save(persisted.value)
    }
  }, 500) as unknown as number

  storageListener = (e: StorageEvent) => {
    if (e.key === storageKey.value) syncFromStorage()
  }
  window.addEventListener('storage', storageListener)
})

onUnmounted(() => {
  if (intervalId !== undefined) {
    clearInterval(intervalId)
    intervalId = undefined
  }
  if (storageListener) {
    window.removeEventListener('storage', storageListener)
    storageListener = undefined
  }
})

const isRunning = computed(() => persisted.value.kind === 'running')

const remainingSec = computed(() => {
  const state = persisted.value
  switch (state.kind) {
    case 'idle': return totalSec.value
    case 'running': return Math.max(0, Math.ceil((state.endsAt - tickNow.value) / 1000))
    case 'paused': return Math.max(0, Math.ceil(state.remainingMs / 1000))
    case 'expired': return 0
  }
})

const display = computed(() => {
  const s = remainingSec.value
  const m = Math.floor(s / 60)
  const r = s % 60
  return `${m}:${r.toString().padStart(2, '0')}`
})

const visualState = computed(() => {
  if (persisted.value.kind === 'expired' || remainingSec.value === 0) return 'expired'
  if (remainingSec.value <= 30) return 'warning'
  if (persisted.value.kind === 'running') return 'running'
  if (persisted.value.kind === 'paused') return 'paused'
  return 'idle'
})

function startFromFull() {
  if (totalSec.value <= 0) return
  persisted.value = { kind: 'running', endsAt: Date.now() + totalSec.value * 1000 }
  save(persisted.value)
}

function resumeFromPause() {
  if (persisted.value.kind !== 'paused') return
  const remainingMs = persisted.value.remainingMs
  if (remainingMs <= 0) { startFromFull(); return }
  persisted.value = { kind: 'running', endsAt: Date.now() + remainingMs }
  save(persisted.value)
}

function pauseTimer() {
  if (persisted.value.kind !== 'running') return
  const remainingMs = Math.max(0, persisted.value.endsAt - Date.now())
  persisted.value = { kind: 'paused', remainingMs }
  save(persisted.value)
}

function onPlayPause() {
  if (totalSec.value <= 0) return
  switch (persisted.value.kind) {
    case 'running': pauseTimer(); break
    case 'paused':  resumeFromPause(); break
    case 'idle':    startFromFull(); break
    case 'expired': startFromFull(); break
  }
}

function onRestart() {
  if (totalSec.value <= 0) return
  startFromFull()
}
</script>

<template>
  <div class="slidev-layout exercise bg-glow">
    <div class="exercise-inner">
      <div class="timer" :class="`timer--${visualState}`">
        <span class="time">{{ totalSec ? display : minutes }}</span>
        <span class="unit" v-if="!totalSec">min</span>

        <div v-if="totalSec" class="timer-controls" role="group" aria-label="Timer controls">
          <button
            type="button"
            class="timer-btn"
            :aria-label="isRunning ? 'Pause timer' : 'Start timer'"
            :title="isRunning ? 'Pause' : 'Start'"
            @click="onPlayPause"
          >
            <svg v-if="!isRunning" viewBox="0 0 16 16" class="icon" aria-hidden="true">
              <path d="M4 3 L13 8 L4 13 Z" fill="currentColor" />
            </svg>
            <svg v-else viewBox="0 0 16 16" class="icon" aria-hidden="true">
              <rect x="4" y="3" width="3" height="10" fill="currentColor" />
              <rect x="9" y="3" width="3" height="10" fill="currentColor" />
            </svg>
          </button>

          <button
            type="button"
            class="timer-btn"
            aria-label="Restart timer"
            title="Restart"
            @click="onRestart"
          >
            <svg viewBox="0 0 24 24" class="icon" aria-hidden="true"
                 fill="none" stroke="currentColor"
                 stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M3 12 a9 9 0 1 0 3-6.7" />
              <path d="M3 4 v5 h5" />
            </svg>
          </button>
        </div>
      </div>

      <h1 v-if="heading" class="exercise-title">{{ heading }}</h1>
      <div class="exercise-body">
        <slot />
      </div>
    </div>
  </div>
</template>

<style scoped>
.exercise {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 3rem;
  position: relative;
}
.exercise-inner {
  position: relative;
  text-align: center;
  max-width: 60ch;
}
.exercise-body {
  text-align: left;
  margin-top: 1.4rem;
}

.timer {
  display: inline-flex;
  align-items: center;
  gap: 0.7rem;
  color: var(--temporal-green);
  font-weight: 300;
  padding: 0.4rem 0.8rem 0.4rem 1.1rem;
  border: 1px solid rgba(89, 253, 160, 0.35);
  border-radius: 999px;
  margin-bottom: 1.6rem;
  background: transparent;
  transition: border-color 160ms ease, box-shadow 160ms ease, background 160ms ease;
}

.timer--running {
  border-color: rgba(89, 253, 160, 0.95);
  box-shadow: 0 0 0 1px rgba(89, 253, 160, 0.35) inset, 0 0 18px rgba(89, 253, 160, 0.20);
}
.timer--paused {
  border-color: rgba(255, 209, 102, 0.85);
}
.timer--paused .time { color: rgba(255, 209, 102, 1); }
.timer--warning {
  border-color: rgba(255, 107, 107, 0.95);
  animation: pulse-red 1s ease-in-out infinite;
}
.timer--warning .time { color: rgba(255, 107, 107, 1); }
.timer--expired {
  border-color: rgba(255, 70, 70, 1);
  background: rgba(255, 70, 70, 0.10);
  animation: shake 0.45s ease-in-out infinite;
}
.timer--expired .time { color: rgba(255, 110, 110, 1); }

.time {
  font-size: 1.6rem;
  font-weight: 200;
  color: #ffffff;
  font-variant-numeric: tabular-nums;
  letter-spacing: 0.02em;
  line-height: 1;
}
.unit {
  font-size: 0.9rem;
  color: var(--temporal-text);
  text-transform: uppercase;
  letter-spacing: 0.1em;
}

.timer-controls {
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
  padding-left: 0.5rem;
  border-left: 1px solid rgba(255, 255, 255, 0.12);
}

.timer-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 1.9rem;
  height: 1.9rem;
  padding: 0;
  border: none;
  border-radius: 999px;
  background: transparent;
  color: var(--temporal-green);
  cursor: pointer;
  transition: background 140ms ease, color 140ms ease, transform 120ms ease;
  font-family: inherit;
  line-height: 0;
}
.timer-btn:hover {
  background: rgba(89, 253, 160, 0.14);
}
.timer-btn:active {
  transform: scale(0.92);
}
.timer-btn:focus-visible {
  outline: 2px solid var(--temporal-green);
  outline-offset: 2px;
}
.timer--paused .timer-btn { color: rgba(255, 209, 102, 1); }
.timer--paused .timer-btn:hover { background: rgba(255, 209, 102, 0.14); }
.timer--warning .timer-btn,
.timer--expired .timer-btn { color: rgba(255, 130, 130, 1); }
.timer--warning .timer-btn:hover,
.timer--expired .timer-btn:hover { background: rgba(255, 107, 107, 0.16); }

.icon {
  width: 1rem;
  height: 1rem;
  display: block;
}

.exercise-title {
  font-size: 2.8rem;
  font-weight: 200;
  letter-spacing: -0.02em;
  color: #ffffff;
  margin: 0 0 1rem;
  line-height: 1.05;
}
.exercise-body :deep(p) {
  color: var(--temporal-text);
  font-size: 1.05rem;
  line-height: 1.55;
  margin: 0.4rem 0;
}
.exercise-body :deep(strong) {
  color: #ffffff;
}

@keyframes pulse-red {
  0%, 100% { box-shadow: 0 0 0 1px rgba(255, 107, 107, 0.35) inset, 0 0 0 rgba(255, 107, 107, 0); }
  50%      { box-shadow: 0 0 0 1px rgba(255, 107, 107, 0.65) inset, 0 0 18px rgba(255, 107, 107, 0.35); }
}
@keyframes shake {
  0%, 100% { transform: translateX(0); }
  25%      { transform: translateX(-2px); }
  75%      { transform: translateX(2px); }
}
</style>
