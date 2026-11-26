// Daftar app yang dijalankan PM2 di HP ini. Tambah site('<nama>') untuk situs yang kamu tulis sendiri.
// Situs buatan Panel Termux ada di apps.json dan dimuat otomatis oleh blok panelApps di bawah.
// Sumber: PLAN/03 §7.2, sama dengan files/sites/ecosystem.config.js di repo server-termux.
const SITES = "/data/data/com.termux/files/home/sites";
const PREFIX = "/data/data/com.termux/files/usr";

// Binary Bun glibc dijalankan lewat grun; .env di folder situs dibaca binary saat start.
// biome-ignore lint/correctness/noUnusedVariables: dipakai saat pemilik membuka komentar site('<nama>') di bawah.
const site = (name) => ({
  name,
  cwd: `${SITES}/${name}`,
  script: `${PREFIX}/bin/grun`,
  args: "./app",
  interpreter: "none",
  exp_backoff_restart_delay: 1000,
});

// Panel Termux: situs buatan panel tercatat di apps.json (dikelola panel, jangan diedit tangan).
// Aman bila apps.json belum ada, kosong, atau rusak; entri yang binary-nya belum ada dilewati,
// karena satu script yang hilang membuat pm2-runtime menghentikan semua aplikasi.
const panelApps = (() => {
  try {
    const fs = require("fs");
    const path = require("path");
    const list = require("./apps.json");
    return Array.isArray(list)
      ? list.filter(
          (a) => a && typeof a.name === "string" && fs.existsSync(path.resolve(a.cwd || __dirname, a.script || "")),
        )
      : [];
  } catch (e) {
    console.error(`[ecosystem] apps.json dilewati: ${e.message}`);
    return [];
  }
})();

// pm2-runtime keluar bila ecosystem tidak punya aplikasi saat start, juga dengan --no-auto-exit.
// Penjaga ini (sleep, ±1 MB) menahannya hidup di HP yang belum punya situs. Jangan dihapus.
const guard = {
  name: "pm2-guard",
  script: `${PREFIX}/bin/sleep`,
  args: "infinity",
  interpreter: "none",
  autorestart: true,
};

module.exports = {
  apps: [
    guard,
    // site('blog'),
    ...panelApps,
  ],
};
