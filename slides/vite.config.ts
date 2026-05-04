import { defineConfig } from 'vite'

// Slidev auto-loads this. The base path is overridden by an env var so
// local `pnpm dev` stays rooted at `/` while the VPS systemd unit sets
// SLIDEV_BASE=/slides/ to match the Caddy reverse-proxy prefix.
export default defineConfig({
  base: process.env.SLIDEV_BASE || '/',
})
