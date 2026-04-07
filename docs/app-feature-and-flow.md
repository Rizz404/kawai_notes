# Arsitektur & Tech Stack
Proyek ini menggunakan arsitektur *Feature-First* yang ketat dengan pemisahan direktori `core`, `di`, `feature`, dan `shared`.
- **State Management**: `flutter_riverpod` (tanpa `riverpod_annotation`).
- **Routing**: *Custom Router Delegate* di `lib/core/router/`.
- **Local Database**: `objectbox` untuk *indexing* metadata, tag, dan link.
- **File System**: `path_provider` untuk menyimpan file `.md` mentah.
- **Markdown**: `flutter_markdown` atau `markdown_widget`.
- **UI & Widget**: Akan menggunakan widget kustom di `lib/shared/widgets/` seperti `app_text_field.dart`, `app_checkbox.dart`, dll.

---

# Alur Pengembangan (Phases)

## Phase 1: Fondasi Markdown dan Skema Database
**Direktori: `core/services` & `feature/notes/models`**

- Buat entitas/model database yang merepresentasikan sebuah catatan, dengan field: `id`, `title`, path ke file mentah, daftar tags, relasi ke catatan lain (untuk *bidirectional linking*), `createdAt`, dan `updatedAt`.
- Buat sebuah *service* yang bertanggung jawab membaca dan menulis file Markdown mentah ke penyimpanan lokal perangkat.
- Buat sebuah *helper* berbasis *regular expression* di `lib/core/extensions/` yang mampu mengekstrak otomatis `#tag` dan `[[Bidirectional Link]]` dari string teks Markdown setiap kali catatan disimpan.
- Buat sebuah *repository* menggunakan Riverpod di `lib/feature/notes/repositories/` yang menjadi jembatan sinkronisasi antara file mentah di penyimpanan lokal dan metadata di database.

---

## Phase 2: Antarmuka UI Dasar dan Rendering Markdown
**Direktori: `feature/notes/screens` & `shared/widgets`**

- Buat `NoteEditorScreen` yang memiliki dua mode: mode *editor* teks biasa untuk menulis Markdown, dan mode *preview* yang me-render Markdown tersebut menjadi tampilan yang terbaca.
- Implementasikan *Bidirectional Navigation*: Ketika pengguna mengetuk sebuah tautan `[[Judul Catatan]]` pada mode *preview*, gunakan sistem router di `lib/core/router/` untuk menavigasi ke catatan yang dituju.
- Buat `HomeScreen` yang menampilkan daftar catatan dengan kemampuan beralih tampilan antara mode *list* dan mode *grid*.
- Implementasikan fitur *Full-AppText Search* lokal di beranda dengan memanfaatkan kemampuan *query* dari database.

---

## Phase 3: Manajemen Tugas dan Folder
**Direktori: `feature/tasks` & `feature/folders`**

- Buat tab khusus `TasksScreen` yang terpisah dari catatan reguler untuk manajemen tugas.
- Implementasikan komponen *checkbox* pada daftar tugas yang memicu animasi visual saat dicentang dan secara otomatis memindahkan tugas tersebut ke daftar "Selesai".
- Buat sistem "Folder Klasik" (termasuk folder default "Uncategorized"). Folder berfungsi sebagai pengelompokan hierarki (*parent-child*), sementara *tags* berfungsi sebagai kategori silang yang fleksibel.
- Integrasikan layanan notifikasi lokal di `core/services/` untuk mendukung fitur pengingat tenggat waktu (*deadline reminder*) pada tugas.

---

## Phase 4: Multimedia dan Fitur Keamanan
**Direktori: `core/services` & `feature/notes`**

- Tambahkan kemampuan menyisipkan gambar: pengguna dapat memilih gambar dari galeri perangkat, gambar tersebut otomatis disalin ke direktori lokal aplikasi, dan *syntax* gambar Markdown yang sesuai disisipkan ke dalam teks editor.
- Tambahkan fitur *Hidden Notes* berbasis autentikasi biometrik atau PIN. Sebuah catatan yang ditandai sebagai privat harus diverifikasi identitasnya terlebih dahulu sebelum kontennya ditampilkan. Implementasikan ini sebagai sebuah *service* di `core/services/`.
- *(Opsional/Tahap Akhir)* Buat *Graph View*: Visualisasikan relasi antar catatan dari data di database ke dalam tampilan *node graph* menggunakan *CustomPainter*, meniru konsep *Knowledge Graph* dari Obsidian.
