import { defineConfig } from 'vite'

// Slidev auto-loads this. The base path is overridden by an env var so
// local `pnpm dev` stays rooted at `/` while the VPS systemd unit sets
// SLIDEV_BASE=/slides/ to match the Caddy reverse-proxy prefix.
//
// `server.allowedHosts: true` disables Vite's host-header check (added
// in Vite 5 to mitigate DNS rebinding). The dev server only binds to
// localhost; the only path in is via Caddy on the same VPS, so accepting
// any forwarded Host header is safe and means we don't have to thread the
// public domain through systemd env on every deploy.
export default defineConfig({
  base: process.env.SLIDEV_BASE || '/',
  server: {
    allowedHosts: true,
  },
})
