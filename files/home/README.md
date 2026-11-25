# @NAME@: HP Android yang jadi server

HP ini (Android, Termux) bekerja sebagai **server** 24 jam. Website di dalamnya bisa diakses dari internet lewat Cloudflare Tunnel, jadi HP tidak perlu IP publik.

## Peta dokumentasi

| File | Untuk siapa | Isi |
|---|---|---|
| `~/README.md` (file ini) | Manusia | Gambaran umum, perawatan HP, akses |
| `~/sites/README.md` | Manusia | Daftar website, deploy/update, tambah site, database, backup, troubleshooting |
| `~/CLAUDE.md` (= `~/AGENTS.md`) | AI agent | Aturan wajib dan jebakan teknis saat bekerja di HP ini |

## Cara kerjanya

```
Internet → Cloudflare → cloudflared (di HP) → app di ~/sites/*
```

Saat HP menyala, **Termux:Boot** menjalankan semua service secara otomatis: ssh, database postgres, cloudflared, dan PM2 (pengelola app). Service yang mati akan dinyalakan lagi otomatis. Sebagai cadangan, ada pengecekan berkala setiap 15 menit.

Kalau ada yang rusak, jalankan ulang installer. Ini aman dilakukan, data dan konfigurasi yang sudah ada tidak ditimpa:

```sh
sh ~/server-termux/install.sh @NAME@
```

## Menjaga HP tetap hidup sebagai server

- Sambungkan HP ke **charger** dan **WiFi** yang stabil.
- **Jangan uninstall atau force-stop** Termux, Termux:Boot, Termux:API, maupun Tailscale.

Pengaturan berikut wajib dipasang. Periksa lagi setelah update sistem atau reset HP:

1. Settings → About phone → ketuk **OS version** (atau Build number) 7× untuk membuka Developer options.
2. Developer options → **"Disable child process restrictions"** = ON. Tanpa ini, Android membunuh proses server.
3. Untuk Termux, Termux:Boot, Termux:API, dan Tailscale: **Autostart** ON dan **Battery: No restrictions**.
4. Tailscale → **Always-on VPN** ON, supaya ssh tetap bisa setelah reboot.
5. Aplikasi **Termux:Boot** harus pernah dibuka minimal sekali.

**Setelah HP restart:** cukup **buka kunci layar sekali**, karena script boot baru berjalan setelah unlock pertama. Dalam ±1 menit, semua service dan situs hidup sendiri.

## Akses dari komputer

```sh
ssh @NAME@        # alias di ~/.ssh/config: HostName <IP Tailscale>, Port 8022; hanya SSH key
```

## Cek cepat: semua sehat?

```sh
export SVDIR=$PREFIX/var/service
sv status sshd postgres cloudflared pm2   # semuanya harus "run"
pm2 ls                                    # semua app "online"
```

## Penting

- **Data hanya ada di HP ini.** Kalau HP rusak, datanya ikut hilang. Salin backup database ke komputer atau cloud secara berkala. Caranya ada di `~/sites/README.md`.
- File `.env` dan isi `~/.cloudflared/` berisi rahasia. Jangan ditampilkan atau dibagikan.
- Update paket dengan `pkg upgrade`, lalu ikuti catatan di bagian "Hal yang perlu diingat" pada `~/sites/README.md`.
