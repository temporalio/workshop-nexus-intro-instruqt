<!--
  Workshop table of contents. Rendered once before each section divider
  with `current` set to the id of the section we're about to enter.
  Active row is highlighted in mint; the rest read as muted Inter Light.
-->
<script setup lang="ts">
defineProps<{ current?: string }>()

const sections = [
  { id: 'ch1',      label: 'Why Nexus' },
  { id: 'ch2',      label: 'The Service Contract' },
  { id: 'ch3',      label: 'Sync Handlers and the Endpoint' },
  { id: 'ch4',      label: 'Calling Nexus from a Workflow' },
  { id: 'ch5',      label: 'Async Operations' },
  { id: 'ch6',      label: 'Updates Through Nexus' },
  { id: 'ch7',      label: 'Cancellation, Errors, Circuit Breaker' },
  { id: 'polyglot', label: 'Polyglot Connector' },
  { id: 'wrap',     label: 'Wrap-Up' },
]
</script>

<template>
  <ol class="workshop-toc">
    <li
      v-for="(section, index) in sections"
      :key="section.id"
      :class="{ active: current === section.id }"
    >
      <span class="number">{{ String(index + 1).padStart(2, '0') }}</span>
      <span class="label">{{ section.label }}</span>
    </li>
  </ol>
</template>

<style scoped>
.workshop-toc {
  list-style: none;
  padding: 0;
  margin: 0;
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
}
.workshop-toc li {
  display: flex;
  align-items: baseline;
  gap: 1.25rem;
  padding: 0.05rem 0;
  color: var(--temporal-text-muted);
  font-weight: 300;
  font-size: 1.25rem;
  transition: color 150ms ease;
}
.workshop-toc li .number {
  font-variant-numeric: tabular-nums;
  font-size: 0.95rem;
  letter-spacing: 0.1em;
  color: var(--temporal-text-muted);
  opacity: 0.65;
}
.workshop-toc li.active {
  color: #ffffff;
}
.workshop-toc li.active .number {
  color: var(--temporal-green);
  opacity: 1;
}
.workshop-toc li.active .label {
  font-weight: 400;
}
</style>
