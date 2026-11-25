// Daftar app yang dijalankan PM2. Tambah satu baris site('<nama>') per site baru.
const SITES = '/data/data/com.termux/files/home/sites'

// Binary Bun (glibc) dijalankan lewat grun; .env di folder site dibaca otomatis oleh binary.
const site = (name) => ({
  name,
  cwd: `${SITES}/${name}`,
  script: '/data/data/com.termux/files/usr/bin/grun',
  args: './app',
  interpreter: 'none',
  exp_backoff_restart_delay: 1000,
})

module.exports = {
  apps: [
    // site('blog'),
  ],
}
