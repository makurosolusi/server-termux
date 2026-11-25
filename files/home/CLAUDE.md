# HP ini = server produksi

HP ini (`@NAME@`, Android, Termux) adalah **server produksi** untuk web app milik user, bukan HP biasa. Perubahan yang salah bisa langsung mematikan situs, jadi bekerjalah hati-hati dan tanya user sebelum melakukan aksi destruktif.

Panduan operasional (daftar site, deploy, tambah site/subdomain, backup, troubleshooting) ada di **`~/sites/README.md`**. Baca dulu sebelum mengubah apa pun di `~/sites`.

Setup HP ini dibuat oleh repo `server-termux` (`sh ~/server-termux/install.sh @NAME@`). Menjalankannya ulang aman dan bisa dipakai untuk memperbaiki service.

## Arsitektur singkat

```
Internet → Cloudflare → cloudflared (tunnel "@NAME@") → http://localhost:<PORT> → app
runit (Termux:Boot + job 15 menit) ─┬─ sshd, postgres, cloudflared
                                    └─ pm2 (pm2-runtime ~/sites/ecosystem.config.js) ── app di ~/sites/*
```

| Komponen | Lokasi |
|---|---|
| Service runit | `$PREFIX/var/service/<nama>/run`, log di `$PREFIX/var/log/sv/<nama>/current` |
| Daftar app PM2 (sumber kebenaran, tanpa `pm2 save`) | `~/sites/ecosystem.config.js` |
| Satu site | `~/sites/<nama>/` berisi `app` (binary Bun, dijalankan via `grun`), `.env`, `data/` |
| Routing domain | `~/.cloudflared/config.yml` |
| Postgres (localhost saja) | data di `$PREFIX/var/lib/postgresql`, superuser `postgres` lewat socket lokal |
| Boot/watchdog | `~/bin/ensure-services` ← `~/.termux/boot/start-services` + termux-job-scheduler job 1, log di `~/.termux/ensure.log` |

## Aturan wajib

- **Rahasia:** jangan `cat` atau print `.env`, `~/.cloudflared/*.json`, `~/.cloudflared/cert.pem`, maupun `~/.ssh/*`. Cukup cek keberadaannya atau nama key-nya (`cut -d= -f1 .env`).
- **Jangan pakai `pkill -f` / `pgrep -f`.** Pola itu ikut cocok dengan shell ssh sendiri sehingga sesi ikut terputus. Pakai `sv`, `pm2`, `pgrep -x`, atau pid dari file.
- **SSH hanya lewat key** (login password dimatikan). Jangan ubah sshd, `~/.ssh/authorized_keys`, atau `$PREFIX/etc/ssh/` tanpa izin user. Sedikit salah saja, akses jarak jauh hilang.
- Dari shell non-login (perintah lewat ssh), jalankan dulu `export SVDIR=$PREFIX/var/service LOGDIR=$PREFIX/var/log` sebelum `sv`.
- Untuk menyalakan runit, pakai `ensure-services manual`, jangan `service-daemon start` langsung (tanpa `LOGDIR`, log service gagal).
- Menghapus file `down` pada service yang runsv-nya sudah berjalan **tidak** menyalakan service itu. Jalankan juga `sv up <nama>`.
- `pgrep -x runsvdir` bisa tidak menemukan apa-apa. Cek lewat `$PREFIX/var/run/service-daemon.pid`.
- Setelah `pkg upgrade` yang ikut mengubah `openssh`, jalankan `sv restart sshd`. Setelah Node di-upgrade, jalankan `npm i -g pm2 && sv restart pm2`.
- `pm2 -v` dan perintah pm2 lain yang dijalankan saat pm2-runtime mati bisa memunculkan daemon liar. Jalankan `pm2 kill` sebelum `sv up pm2`.
- Docker/Podman tidak bisa dipakai (tidak ada user namespace, cgroup, dan KVM). Semua app adalah binary native yang dijalankan PM2.
- Binary Bun glibc dijalankan lewat `grun`. File `.env` di cwd dibaca otomatis.

## Cek cepat kesehatan

```sh
export SVDIR=$PREFIX/var/service
sv status sshd postgres cloudflared pm2
pm2 ls
```

## Catatan

- Setiap kali menambah site atau mengubah alur, perbarui `~/sites/README.md` (dan file ini bila menyangkut aturan).
