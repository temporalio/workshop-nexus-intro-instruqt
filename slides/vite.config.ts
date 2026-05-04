import { defineConfig } from 'vite'

// Slidev auto-loads this. The base path is set via Slidev's `--base`
// CLI flag in deploy/slidev.service, not here; Slidev does not merge
// the `base` option from vite.config.ts.
//
// `server.allowedHosts: true` disables Vite's host-header check (added
// in Vite 5 to mitigate DNS rebinding). The dev server only binds to
// localhost; the only path in is via Caddy on the same VPS, so accepting
// any forwarded Host header is safe and means we don't have to thread the
// public domain through systemd env on every deploy.
export default defineConfig({
  server: {
    allowedHosts: true,
  },
})
