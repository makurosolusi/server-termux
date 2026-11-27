[English](README.md) | Bahasa Indonesia

# Sites di HP ini

HP Android (Termux) ini, `@NAME@` (`ssh @NAME@`, tunnel Cloudflare `@NAME@`), dipakai sebagai server. Setiap website adalah **satu folder** di `~/sites/` dan **satu baris** di `~/sites/ecosystem.config.js`, dan dijalankan oleh **PM2**.

```
Internet → Cloudflare → cloudflared (di HP) → http://localhost:<PORT> → app
runit (Termux:Boot) ─┬─ sshd, postgres, cloudflared
                     └─ pm2 ── semua app di ~/sites
```

- **PM2** menjalankan app, menyalakan ulang app yang crash, dan menyediakan `pm2 ls` / `pm2 logs` / `pm2 restart`.
- **runit** menjaga PM2 sendiri, sshd, postgres, dan cloudflared, lalu menyalakan semuanya lagi setelah reboot (lewat Termux:Boot). `pm2 startup` **tidak dipakai** karena Termux tidak punya systemd.
- **cloudflared** membuka domain publik tanpa perlu IP publik.
- **postgres** satu instance, hanya bisa diakses dari HP sendiri (localhost).

## Daftar site

| Site | Domain | Port | Database |
|---|---|---|---|
| *(belum ada)* | | | |

> Tambah baris di tabel ini setiap kali menambah site.

## Situs buatan panel

Selain baris `site('<nama>')` yang kamu tulis sendiri, `ecosystem.config.js` juga memuat:

- **`pm2-guard`**: app penjaga (`sleep infinity`, ±1 MB). pm2-runtime keluar bila tidak ada satu pun app saat
  menyala, juga dengan `--no-auto-exit`, jadi penjaga ini menahannya hidup di HP yang belum punya situs.
  **Jangan dihapus** dari `ecosystem.config.js` dan jangan `pm2 delete pm2-guard`.
- **`apps.json`** (`~/sites/apps.json`): daftar situs buatan Panel Termux, dimuat otomatis oleh blok `panelApps`
  di `ecosystem.config.js`. File ini **dikelola panel, jangan diedit tangan**. Bila hilang, kosong, atau rusak,
  ecosystem tetap jalan tanpa situs panel; entri yang binary-nya belum ada dilewati.
- Jangan hapus `app` situs panel lewat ssh tanpa menghapus situsnya di panel. Hapus situsnya dari panel.

## Isi folder sebuah site

```
~/sites/<site>/
├── app     binary aplikasi (Bun single binary, dijalankan lewat grun)
├── .env    konfigurasi + rahasia (chmod 600, JANGAN di-cat/di-share)
└── data/   data milik app
```

| Apa | Lokasi |
|---|---|
| Daftar app PM2 | `~/sites/ecosystem.config.js` (+ situs panel di `~/sites/apps.json`) |
| Log app | `~/.pm2/logs/<site>-out.log` dan `-error.log` (dirotasi `pm2-logrotate`: 10M, simpan 7) |
| Service runit PM2 | `$PREFIX/var/service/pm2/run`, log di `$PREFIX/var/log/sv/pm2/current` |
| Routing domain | `~/.cloudflared/config.yml` |
| Data postgres | `$PREFIX/var/lib/postgresql` |

## Perintah sehari-hari

```sh
pm2 ls                 # status semua app
pm2 logs <site>        # log live (Ctrl+C untuk keluar)
pm2 restart <site>     # restart (misalnya setelah mengubah .env)
pm2 monit              # dashboard CPU/RAM
```

Untuk mematikan app secara **permanen** (juga setelah reboot): hapus barisnya di `ecosystem.config.js`, lalu jalankan `pm2 delete <site>`.

Service di luar PM2 (kalau lewat `ssh @NAME@ '…'`, tambahkan `export SVDIR=$PREFIX/var/service;` di depan):

```sh
sv status pm2 postgres cloudflared sshd
sv restart pm2         # restart PM2 beserta semua app
```

## Menambah site baru

Contoh: nama site `blog`, port `3006`, domain `blog.example.com`.

1. **Folder dan binary.** Build di komputer dengan `bun build --compile --target=bun-linux-arm64`, lalu:
   ```sh
   mkdir -p ~/sites/blog
   rsync --partial -t <binary> @NAME@:sites/blog/app      # dari komputer; ulangi bila koneksi putus
   chmod +x ~/sites/blog/app
   ```
2. **`.env`** dengan **port unik** (cek tabel di atas):
   ```sh
   cd ~/sites/blog && umask 077 && nano .env   # minimal PORT=3006, ditambah env yang dibutuhkan app
   ```
3. **Database** (jika perlu):
   ```sh
   psql -U postgres -c "CREATE ROLE blog LOGIN;" -c "CREATE DATABASE blog OWNER blog;"
   psql -U postgres -c "\password blog"   # ketik password-nya, jangan ditulis di command
   # DATABASE_URL=postgres://blog:<password>@127.0.0.1:5432/blog  → masukkan ke .env
   ```
   Untuk menjalankan migrasi dari komputer, buka tunnel dulu: `ssh -N -L 15432:127.0.0.1:5432 @NAME@`.
4. **Daftarkan ke PM2.** Di `~/sites/ecosystem.config.js`, tambahkan `site('blog'),` ke `apps`, lalu:
   ```sh
   pm2 start ~/sites/ecosystem.config.js --only blog
   ```
   Tidak perlu `pm2 save`, karena PM2 membaca file ini setiap kali menyala.
5. **Domain.** Tambahkan di `~/.cloudflared/config.yml`, **di atas** baris `- service: http_status:404`:
   ```yaml
     - hostname: blog.example.com
       service: http://localhost:3006
   ```
   Lalu jalankan:
   ```sh
   cloudflared tunnel route dns @NAME@ blog.example.com
   sv restart cloudflared
   ```
6. Tambahkan baris di **Daftar site** di atas.

## Update versi app

```sh
rsync --partial -t <binary-baru> @NAME@:sites/<site>/app.new    # dari komputer
cd ~/sites/<site> && mv app app.prev && mv app.new app && chmod +x app && pm2 restart <site>
# rollback: mv app.prev app && pm2 restart <site>
```

## Backup database

```sh
mkdir -p ~/backups
pg_dump -U postgres -Fc <db> > ~/backups/<db>-$(date +%F).dump
# restore: pg_restore -U postgres -d <db> --clean ~/backups/<file>.dump
```

> Backup yang hanya tersimpan di HP ikut hilang kalau HP rusak. Salin ke komputer atau cloud secara berkala.

## Hal yang perlu diingat

- **Jangan `cat .env`** atau menampilkannya di layar/chat.
- **Jangan `pkill -f <nama>` / `pgrep -f` lewat ssh**, karena bisa ikut membunuh shell ssh-nya sendiri.
- **Node** berasal dari paket `nodejs-lts` (bukan nvm). Setelah Node di-upgrade, jalankan `npm i -g pm2 && sv restart pm2`.
- Setelah `pkg upgrade` yang ikut meng-upgrade `openssh`, jalankan `sv restart sshd`.
- Kalau PM2 mati keras, app-nya bisa tertinggal memegang port. Script `run` pm2 otomatis membunuh app yatim di `~/sites/*` sebelum PM2 menyala lagi.

## Kalau ada masalah

| Gejala | Cek |
|---|---|
| Domain error 502/1033 | `pm2 ls` dan `sv status cloudflared`, lalu lihat log keduanya |
| App terus restart | `pm2 logs <site> --lines 50` (`EADDRINUSE` = port bentrok) |
| `pm2 ls` kosong / error | `sv status pm2`, `tail -50 $PREFIX/var/log/sv/pm2/current` |
| Setelah reboot tidak hidup | Pastikan layar sudah di-unlock sekali, cek ada baris `by=boot` di `~/.termux/ensure.log`, lalu periksa pengaturan HP di `~/README.md` |
| ssh tidak bisa | Kalau timeout: cek Tailscale di HP dan komputer. Kalau refused: di Termux HP jalankan `sv up $PREFIX/var/service/sshd` (atau `sshd`) |
| Ada yang lain rusak | `sh ~/server-termux/install.sh @NAME@` (aman dijalankan ulang) |
