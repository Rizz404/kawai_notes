# GitHub Actions — Automated Release Pipeline

Dokumen ini menjelaskan cara kerja workflow release otomatis dan langkah-langkah untuk menggunakannya.

## Gambaran Umum

Workflow `.github/workflows/release.yml` otomatis melakukan:

1. Build universal APK + 4 ABI-split APKs
2. Rename APK dengan format `kawai-notes-{version}-{abi}.apk`
3. Generate changelog dari conventional commits
4. Buat GitHub Release dengan semua APK sebagai assets

---

## Setup Awal (Satu Kali)

### 1. Tambahkan Secrets di GitHub

Buka: **GitHub repo → Settings → Secrets and variables → Actions → New repository secret**

| Secret Name | Value | Keterangan |
|---|---|---|
| `SUPABASE_URL` | `https://kcwluolgiqgvcltkjdyo.supabase.co` | Diambil dari file `.env` lokal |
| `SUPABASE_ANON_KEY` | `eyJhbGci...` | Diambil dari file `.env` lokal |

> `GITHUB_TOKEN` sudah tersedia otomatis — tidak perlu dibuat manual.

### 2. Pastikan Workflow Tersedia di Repo

File `.github/workflows/release.yml` harus sudah di-push ke branch `main`. Workflow baru aktif setelah file ini ada di remote.

---

## Cara Membuat Release

### Opsi A — Push Tag (Direkomendasikan)

Alur standar untuk setiap versi baru:

```powershell
# 1. Bump versi di pubspec.yaml
# Ubah: version: 1.0.0+1 → version: 1.1.0+2
# (format: <versionName>+<versionCode>)

# 2. Commit perubahan versi
git add pubspec.yaml
git commit -m "chore: bump version to 1.1.0"

# 3. Buat annotated tag
git tag -a v1.1.0 -m "Release v1.1.0"

# 4. Push commit + tag ke GitHub
git push origin main
git push origin v1.1.0
```

Setelah `git push origin v1.1.0`, GitHub Actions otomatis terpicu.

### Opsi B — Manual via GitHub UI (workflow_dispatch)

Gunakan ini untuk re-run release yang gagal, atau jika tag sudah ada tapi release belum terbentuk.

1. Buka **GitHub repo → Actions → Release**
2. Klik **Run workflow**
3. Isi:
   - **Version tag**: `v1.1.0` (harus sesuai tag yang sudah ada)
   - **Mark as pre-release**: centang jika ini versi beta/RC
4. Klik **Run workflow**

---

## Alur Kerja Workflow

```
Trigger (push tag / manual)
        │
        ▼
   Job: build
   ├── Resolve version dari tag atau input
   ├── Setup Java 17 + Flutter 3.38.8
   ├── Inject .env dari GitHub Secrets
   ├── flutter pub get
   ├── Build universal APK
   ├── Build ABI-split APKs (arm64, armv7, x86_64)
   ├── Rename ke kawai-notes-{VERSION}-{abi}.apk
   └── Upload artifact (disimpan 7 hari)
        │
        ▼
   Job: release (butuh build selesai)
   ├── Download artifact APKs
   ├── Generate changelog dari git log conventional commits
   │   ├── feat:     → ✨ Features
   │   ├── fix:      → 🐛 Bug Fixes
   │   ├── perf:     → ⚡ Performance
   │   └── refactor: → ♻️ Refactoring
   └── gh release create dengan semua 4 APK + release notes
```

**Estimasi durasi:** 12–18 menit (pub cache hangat: ~10 menit).

---

## Format APK yang Dihasilkan

| File | Ukuran | Untuk |
|------|--------|-------|
| `kawai-notes-{v}-universal.apk` | ~80 MB | Semua device, cocok untuk share langsung |
| `kawai-notes-{v}-arm64-v8a.apk` | ~30 MB | HP Android modern (2017+) |
| `kawai-notes-{v}-armeabi-v7a.apk` | ~28 MB | HP Android lama |
| `kawai-notes-{v}-x86_64.apk` | ~30 MB | Emulator / device x86 |

---

## Memahami Alur Commit → Release

Kamu tidak perlu langsung buat tag setiap commit. Alur normalnya:

```
commit feat: tambah fitur A  ──┐
commit fix: perbaiki bug B     │  semua ini sudah di main
commit feat: tambah fitur C    │  (git push origin main biasa)
commit fix: crash di screen D ─┘
                                │
         git tag -a v1.1.0      │ ← penanda: "sampai sini = versi 1.1.0"
         git push origin v1.1.0 │ ← ini yang trigger workflow
                                ▼
     Changelog release v1.1.0 otomatis berisi
     semua commit di atas (sejak v1.0.0)
```

**Jadi:** push ke `main` itu bebas kapan saja. Tag baru dibuat hanya saat kamu siap rilis — workflow lalu menarik semua commit antara tag lama dan tag baru sebagai changelog.

---

## Format Version di pubspec.yaml

```yaml
version: 1.2.3+4
#        ^ ^ ^ ^
#        │ │ │ └── versionCode: integer, naik setiap build (dipakai Android)
#        │ │ └──── patch
#        │ └────── minor
#        └──────── major
```

Workflow mengambil `versionCode` langsung dari `pubspec.yaml` — tidak pakai `GITHUB_RUN_NUMBER`.

### Kapan Naik Apa?

| Tipe | Kapan | Contoh |
|------|-------|--------|
| **patch** | Bug fix, typo, crash fix — tidak ada fitur baru | `1.0.0` → `1.0.1` |
| **minor** | Fitur baru yang tidak merusak fitur lama | `1.0.1` → `1.1.0` |
| **major** | Perubahan besar / breaking (misal: auth ulang, format data berubah) | `1.1.0` → `2.0.0` |

### Contoh Lengkap

**Skenario patch** — ada 2 bug fix setelah v1.0.0:

```yaml
# pubspec.yaml
version: 1.0.1+2   # patch naik 0→1, versionCode naik 1→2
```

```powershell
git add pubspec.yaml
git commit -m "chore: bump version to 1.0.1"
git tag -a v1.0.1 -m "Release v1.0.1"
git push origin main
git push origin v1.0.1
```

Changelog otomatis: hanya commit antara `v1.0.0` dan `v1.0.1`.

---

**Skenario minor** — sprint baru dengan beberapa fitur:

```yaml
# pubspec.yaml
version: 1.1.0+3   # minor naik 0→1, patch reset ke 0, versionCode naik 2→3
```

```powershell
git add pubspec.yaml
git commit -m "chore: bump version to 1.1.0"
git tag -a v1.1.0 -m "Release v1.1.0"
git push origin main
git push origin v1.1.0
```

---

**Skenario major** — redesign / perubahan besar:

```yaml
# pubspec.yaml
version: 2.0.0+4   # major naik 1→2, minor+patch reset ke 0, versionCode naik 3→4
```

```powershell
git add pubspec.yaml
git commit -m "chore: bump version to 2.0.0"
git tag -a v2.0.0 -m "Release v2.0.0"
git push origin main
git push origin v2.0.0
```

> **Aturan versionCode:** selalu naik +1 dari sebelumnya, tidak pernah turun atau reset. Android menolak install APK dengan versionCode lebih rendah dari yang sudah terpasang.

---

## Troubleshooting

### Build gagal: `.env` tidak ditemukan

**Penyebab:** Secrets `SUPABASE_URL` atau `SUPABASE_ANON_KEY` belum diset di GitHub.

**Solusi:** Ikuti langkah Setup Awal di atas.

### Release gagal: tag tidak ditemukan

**Penyebab:** Workflow dipicu via `workflow_dispatch` dengan versi yang tag-nya belum ada di GitHub.

**Solusi:** Push tag dari lokal dulu (`git push origin v1.x.x`), baru jalankan manual trigger.

### Workflow tidak terpicu setelah push tag

**Penyebab:** File `release.yml` belum ada di remote saat tag di-push, atau tag di-push sebelum workflow file.

**Solusi:** Pastikan commit yang berisi `release.yml` sudah ada di `main` sebelum push tag. Gunakan workflow_dispatch untuk re-trigger.

### Flutter version tidak ditemukan di CI

**Penyebab:** `subosito/flutter-action` tidak mengenali versi yang di-pin.

**Solusi:** Update `FLUTTER_VERSION` di `release.yml` ke versi stable terbaru yang tersedia, atau hapus `flutter-version` agar selalu pakai latest stable.

### Re-run release untuk tag yang sama

Workflow menggunakan `--clobber` — release lama untuk tag yang sama akan ditimpa otomatis. Aman untuk di-re-run.

---

## Mengganti Flutter Version

Jika perlu upgrade Flutter di CI, ubah baris ini di `release.yml`:

```yaml
env:
  FLUTTER_VERSION: '3.38.8'  # ← ganti ke versi baru
```

Selalu test secara lokal dengan versi yang sama sebelum ganti di CI.
