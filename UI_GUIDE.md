# UI/UX Design Guide: Football Tournament Simulator

## 1. Filosofi Desain & Identitas Visual
* **Gaya Visual:** *Clean Sports Data UI* (terinspirasi dari **FotMob Light Mode**).
* **Prinsip Utama:**
  * **High Readability:** Latar belakang abu-abu sangat terang (`#F4F5F7`) dengan kartu informasi berwarna putih bersih (`#FFFFFF`) dan garis tepi halus (*hairline border*) agar ratusan data tim, klasemen, dan jadwal mudah dipindai mata.
  * **Tabular Numbers:** Semua angka (skor, OVR, poin klasemen, selisih gol) wajib menggunakan `fontFeatures: [FontFeature.tabularFigures()]` agar kolom angka sejajar lurus dari atas ke bawah.
  * **Zero Clutter:** Informasi sekunder (seperti persentase peluang menang/seri/kalah) disembunyikan secara rapi atau ditampilkan sebagai bar tipis agar kartu pertandingan tetap ringkas.

---

## 2. Sistem Warna (*Color Palette*)

### 2.1. Warna Dasar & Permukaan (*Surface*)
| Token Warna | Kode Hex | Penggunaan |
| :--- | :--- | :--- |
| `backgroundCanvas` | `#F4F5F7` | Latar belakang utama halaman (`Scaffold.backgroundColor`) |
| `surfaceCard` | `#FFFFFF` | Latar belakang kartu pertandingan, tabel klasemen, dan form |
| `surfaceSubtle` | `#EEF0F4` | Latar belakang chip filter tidak aktif, header tabel, dan badge netral |
| `borderHairline` | `#E5E7EB` | Garis pemisah antar-baris tabel dan border tipis kartu (`1px`) |

### 2.2. Warna Aksi & Teks
| Token Warna | Kode Hex | Penggunaan |
| :--- | :--- | :--- |
| `primaryBrand` | `#00A859` | Warna utama (FotMob Green): tombol *Simulate*, tab aktif, dan aksi utama |
| `secondaryAccent` | `#1D4ED8` | Warna aksen sekunder untuk tautan, badge turnamen, dan indikator netral |
| `textPrimary` | `#111827` | Judul halaman, nama tim, dan angka skor utama |
| `textSecondary` | `#6B7280` | Nama kompetisi, nomor pekan, statistik pendukung, dan label form |
| `textMuted` | `#9CA3AF` | Placeholder input dan keterangan pertandingan belum dimulai |

### 2.3. Warna Zona Kualifikasi Klasemen (Indikator Garis Kiri 4px)
Pada tabel klasemen Liga Lokal (`Liga A–H`), sisi paling kiri baris peringkat diberi garis indikator vertikal selebar `4px`:
* **Peringkat 1–4 (Champions League):** `#2563EB` (Biru)
* **Peringkat 5–8 (Winner League):** `#EA580C` (Oranye)
* **Peringkat 9–12 (Federation League):** `#7C3AED` (Ungu)
* **Peringkat 13–17 (Mid Range League):** `#0D9488` (Teal)
* **Peringkat 18–20 (Challenger League):** `#D97706` (Amber)

### 2.4. Warna Indikator OVR & Event Khusus
* **OVR Elite (85–100):** Latar `#ECFDF5`, Teks `#059669` (Hijau Emerald)
* **OVR Menengah (75–84):** Latar `#EFF6FF`, Teks `#2563EB` (Biru)
* **OVR Bawah (1–74):** Latar `#F1F5F9`, Teks `#475569` (Slate)
* **Perubahan OVR Naik (`+`):** `#16A34A` (Hijau, ikon `▲`)
* **Perubahan OVR Turun (`-`):** `#DC2626` (Merah, ikon `▼`)
* **Chaotic Match Badge (`>5 Gol` / *Upset*):** Latar `#FEF3C7`, Teks `#B45309` (Emas/Amber)

---

## 3. Tipografi & Skala Ukuran
Menggunakan font bawaan modern (`Roboto` / `Inter` / `Plus Jakarta Sans`) dengan aturan ukuran:
* **AppBar Title:** `18sp`, `FontWeight.w700`, `textPrimary`
* **Section Header:** `15sp`, `FontWeight.w700`, `textPrimary`
* **Card Title / Nama Tim:** `14sp`, `FontWeight.w600`, `textPrimary`
* **Skor Pertandingan:** `16sp`, `FontWeight.w800`, `textPrimary` (dengan *tabular figures*)
* **Body / Subtitle:** `13sp`, `FontWeight.w400`, `textSecondary`
* **Badge / Table Header / Caption:** `11sp`–`12sp`, `FontWeight.w600`

---

## 4. Struktur Navigasi Utama

### 4.1. Bottom Navigation Bar (4 Tab Utama)
Menggunakan `NavigationBar` / `BottomNavigationBar` berlatar `#FFFFFF` dengan garis batas atas `#E5E7EB`, ikon hijau `#00A859` saat aktif, dan abu-abu `#6B7280` saat tidak aktif:
1. **Turnamen** (`Icons.emoji_events_outlined` / `Icons.emoji_events`)
2. **Fixture** (`Icons.calendar_today_outlined` / `Icons.calendar_today`)
3. **Tim** (`Icons.shield_outlined` / `Icons.shield`)
4. **History** (`Icons.history_edu_outlined` / `Icons.history_edu`)

### 4.2. Global AppBar
* Berlatar `#FFFFFF` dengan teks gelap `#111827` (khas FotMob Light Mode) dan garis bawah tipis `#E5E7EB`.
* Di sisi kanan terdapat badge indikator musim aktif (misal pill kecil `Musim 1`) serta ikon **Pengaturan / Backup (`Icons.settings_outlined`)** untuk mengakses *Export/Import JSON* dan *Reset Aplikasi*.

---

## 5. Spesifikasi Desain Tiap Layar (*Screen Blueprints*)

### 5.1. Halaman Setup Awal 8 Liga (`SetupLeaguesScreen`)
Muncul saat aplikasi pertama kali dibuka sebelum Musim 1 dimulai:
* **Header:** Judul *"Setup Peserta Liga"* + indikator total keseluruhan (`0 / 160 Tim Siap`).
* **Tab Liga (`Liga A` – `Liga H`):** `TabBar` horizontal yang menampilkan nama liga serta ikon centang hijau kecil jika liga tersebut sudah terisi penuh `20/20` tim.
* **Toolbar Input Cepat:** Baris aksi di atas daftar berisi penghitung liga aktif (`15/20 Tim`) dan tombol `OutlinedButton` **"Paste List Teks"** (membuka *Bottom Sheet* untuk menempel daftar 20 baris `Nama Tim, OVR`).
* **Daftar Input 20 Baris (`ListView`):**
  * Setiap baris berbentuk kartu ringkas putih berisi: Nomor urut (`1`–`20`), Avatar Logo bulat `36x36` (ketuk untuk unggah gambar atau otomatis menampilkan inisial 3 huruf), `TextField` Nama Tim (`Expanded`), dan `TextField` angka OVR (`width: 64`, validasi `1–100`).
* **Sticky Bottom Bar:** Tombol penuh berwarna hijau `#00A859` bertuliskan **"Mulai Musim 1"** (nonaktif/abu-abu hingga seluruh `160` tim valid).

### 5.2. Tab 1: Halaman Turnamen (`TournamentsScreen`)
Menampilkan 14 turnamen yang dikelompokkan rapi dalam `SingleChildScrollView`:
* **Section 1 — Turnamen Kontinental:** Daftar 5 kartu horizontal/vertikal (*Champions League*, *Winner League*, *Federation League*, *Mid Range League*, *Challenger League*). Pada Musim 1, kartu menampilkan badge status `"Mulai Musim 2"`.
* **Section 2 — Liga Lokal (Liga A–H):** Grid 2 kolom (`GridView` dengan `childAspectRatio: 2.4`) menampilkan ikon perisai liga, nama liga, dan pekan berjalan.
* **Section 3 — Cup Domestik (Cup Liga A–H):** Grid 2 kolom menampilkan 8 piala domestik beserta babak aktifnya (misal `"16 Besar"` atau `"Final"`).

### 5.3. Halaman Info Turnamen (`TournamentDetailScreen`)
Dibuka saat salah satu turnamen diklik. Menggunakan `DefaultTabController` dengan 3 tab:
1. **Tab Klasemen / Bagan:**
   * *Untuk Fase Liga/Grup:* Tabel klasemen dengan kolom `#` (bergaris warna zona di sisi kiri), `Tim` (Logo `20x20` + Nama), `Main`, `M`, `S`, `K`, `SG`, dan `Poin` (ditebalkan). Dilengkapi legenda warna zona di bagian bawah tabel.
   * *Untuk Fase Knockout:* Tampilan bagan (*Bracket Tree*) yang dapat digeser horizontal (`16 Besar` $\rightarrow$ `Perempat Final` $\rightarrow$ `Semifinal` $\rightarrow$ `Final`), menampilkan skor Leg 1, Leg 2, Agregat, serta skor penalti jika ada.
2. **Tab Jadwal & Hasil:** Daftar pertandingan khusus turnamen tersebut yang dikelompokkan per *Matchday* / Babak.
3. **Tab Statistik & Pot/Grup:**
   * Pembagian Pot 1–4 atau Grup A–H hasil *drawing*.
   * Kartu mini **Tim Tersubur** (gol terbanyak) dan **Pertahanan Terbaik** (kebobolan paling sedikit) di turnamen tersebut.
   * **Log Berita Turnamen** (riwayat perubahan OVR akibat *Transfer Window* atau cedera).

### 5.4. Tab 2: Halaman Fixture & Simulasi (`FixtureScreen`)
Pusat interaksi utama pemain untuk menjalankan musim:
* **Sticky Top Control Panel:**
  * **Navigasi Pekan:** Tombol panah kiri/kanan (`<`) dan (`>`) mengapit teks **"Pekan 12 / 48"** (dapat diketuk untuk melompat ke pekan tertentu).
  * **Filter Chip Horizontal:** `Semua`, `Liga Lokal`, `Cup Domestik`, `Kontinental`.
  * **Tombol Aksi Utama:** Tombol penuh berwarna `#00A859` bertuliskan **"Simulate Pekan Ini"** (dengan ikon petir/play) untuk mensimulasikan semua laga yang belum selesai di pekan aktif.
* **Kartu Pertandingan (`MatchCard` ala FotMob):**
  * Bagian atas kartu: Nama turnamen & tahapannya (misal `Champions League • League Phase MD 3`) + badge `CHAOTIC` jika terjadi pesta gol (`>5 gol`).
  * Bagian tengah (3 kolom sejajar):
    * **Kiri (`Expanded`):** Nama Tim Home (rata kanan) + Logo `24x24`.
    * **Tengah (`width: 84`):** Jika belum main tampilkan badge waktu/status `VS`; jika sudah main tampilkan skor tebal **`2 - 1`** (dan teks kecil `Pen 4-3` di bawahnya jika adu penalti).
    * **Kanan (`Expanded`):** Logo `24x24` + Nama Tim Away (rata kiri).
  * Bagian bawah/aksi kartu:
    * Jika belum main: Tombol kapsul kecil **`Simulate`** di sisi kanan dan bar visual tipis perbandingan peluang Davidson (`Home % | Seri % | Away %`).
* **Banner Event & Akhir Musim:**
  * Setelah Pekan 19 selesai: Kartu notifikasi biru muda menginformasikan *"Transfer Window Tengah Musim Telah Selesai — Cek Perubahan OVR Tim!"*.
  * Setelah seluruh laga Pekan 48 selesai: Muncul kartu besar di atas daftar dengan tombol **"Tutup Musim & Lanjut ke Musim Berikutnya"**.

### 5.5. Tab 3: Daftar Tim & Info Detail Tim (`TeamsScreen` & `TeamDetailScreen`)
* **Halaman Daftar Tim:**
  * Kolom pencarian (*Search Bar*) di atas + filter dropdown berdasarkan Liga (`Semua Liga`, `Liga A`–`H`) dan urutan (`OVR Tertinggi`, `Nama A–Z`).
  * Daftar kartu tim menampilkan: Logo `36x36`, Nama Tim, Subjudul Liga Asal, dan Badge Pill OVR di ujung kanan beserta indikator perubahan terakhir (misal `86` `▲+3`).
* **Halaman Info Detail Tim:**
  * **Kartu Header Profil:** Logo besar `64x64`, Nama Tim, asal liga, dan Pill OVR besar beserta riwayat perubahan OVR musim ini.
  * **Kartu Kabinet Trofi:** Deretan ikon piala (Liga Lokal, Cup Lokal, Champions, Winner, Federation, Mid Range, Challenger) lengkap dengan angka jumlah gelar yang diraih.
  * **Kartu Status Musim Aktif:** Posisi peringkat saat ini di Liga Lokal dan Turnamen Kontinental.
  * **Kartu Histori Per Musim:** Tabel riwayat musim (`Musim 1`, `Musim 2`, dst.) berisi peringkat akhir liga, pencapaian kontinental, dan rata-rata gol cetak/kebobolan per laga.

### 5.6. Tab 4: Halaman History (`HistoryScreen`)
* **Selector Atas:** Segmented button untuk memilih **"Arsip Per Musim"** (`Season 1`, `Season 2`, dst.) atau **"Hall of Fame (Sepanjang Masa)"**.
* **Konten Arsip Per Musim:**
  * **Kartu Rekor Musim (Grid 3 Kartu Mini):** *Tim Tersubur*, *Pertahanan Terbaik*, dan *Skor Terbesar / Kejutan Terbesar*.
  * **Daftar Juara 14 Turnamen:** Kartu daftar menampilkan nama turnamen, ikon piala, Tim Juara (tebal + logo), dan Tim *Runner-up*.
* **Konten Hall of Fame:** Peringkat klub dengan koleksi trofi terbanyak sepanjang sejarah simulasi.

---

## 6. Standar Komponen & Aturan Layouting Flutter
* **Border Radius Standar:** `12.0` untuk kartu utama (`Card` / `Container`), `8.0` untuk tombol dan kolom input (`TextField`), dan `20.0` (pill) untuk badge OVR maupun filter chip.
* **Padding & Spacing:** Padding luar layar `16.0`, jarak antar-kartu `10.0`, padding dalam kartu `12.0`–`16.0`.
* **Aturan Anti-Overflow:**
  * Setiap nama tim di dalam `Row` wajib dibungkus `Expanded` dengan `maxLines: 1` dan `overflow: TextOverflow.ellipsis`.
  * Setiap tabel lebar atau bagan fase gugur wajib dibungkus `SingleChildScrollView(scrollDirection: Axis.horizontal)`.