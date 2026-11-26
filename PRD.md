# Product Requirements Document (PRD): Football Tournament Simulator

## 1. Ringkasan Proyek
* **Nama Aplikasi:** Football Tournament Simulator
* **Platform Target:** Mobile (Android / iOS) & Web Preview menggunakan **Flutter (Dart)**
* **Arsitektur Penyimpanan:** Offline-First (Local Database menggunakan `Hive` atau `SQLite` + fitur *Export/Import* file `.json` untuk cadangan data)
* **Konsep Utama:** Simulator ekosistem sepak bola multi-musim yang mencakup **8 Liga Lokal (Liga A–H)**, **8 Piala Domestik (Cup Liga A–H)**, dan **5 Turnamen Kontinental** dengan sistem promosi/kualifikasi antar-musim, dinamika *Overall Rating* (OVR), serta simulasi pertandingan berbasis probabilitas matematis.

---

## 2. Task Flow & Alur Navigasi Utama

```text
[Buka Aplikasi]
       │
       ├──(Belum Ada Data / Musim Baru)──► [Setup 8 Liga Lokal (Liga A-H)]
       │                                           │
       │                        (Input List 20 Tim/Liga + OVR + Logo Opsional / Paste Teks)
       │                                           │
       │                                           ▼
       └──(Data Tersedia) ───────────────► [Main Navigation (Bottom Bar)]
                                                   │
         ┌─────────────────────┬───────────────────┼───────────────────┬─────────────────────┐
         ▼                     ▼                   ▼                   ▼                     ▼
  [Tab: Turnamen]       [Tab: Fixture]      [Tab: Daftar Tim]   [Tab: History]      [Tab: Pengaturan]
         │                     │                   │                   │                     │
  (Pilih Liga/Cup/      (Simulate 1 Match   (Cari & Pilih       (Arsip Juara,       (Export/Import
   Kontinental)          atau 1 Pekan)       Salah Satu Tim)     Rekor Gol, dll)     Save Data JSON)
         │                     │                   │
         ▼                     ▼                   ▼
 [Info Turnamen]       [Detail Match &     [Info Detail Tim]
  - Klasemen / Bagan    Hasil Simulasi]     - OVR & Grafik Tren
  - Statistik Tim                           - Peringkat Aktif
  - Hasil Drawing                           - Kabinet Trofi
  - Log Berita/Event                        - Histori Musim Lalu
```

---

## 3. Spesifikasi Ekosistem Turnamen (14 Turnamen per Musim)

### 3.1. Liga Lokal (`Liga A` sampai `Liga H`)
* **Jumlah Liga:** 8 liga lokal aktif sejak Musim 1.
* **Peserta:** Wajib **20 tim** per liga (total **160 tim** di seluruh ekosistem).
* **Format Kompetisi:** Liga *Double Round-Robin* (setiap tim saling bertemu kandang & tandang = **38 pertandingan** per tim, 38 pekan).
* **Sistem Poin:** Menang = **3 poin**, Seri = **1 poin**, Kalah = **0 poin**.
* **Aturan Tie-Breaker Klasemen (Berurutan):**
  1. Selisih Gol ($GD = GF - GA$)
  2. Jumlah Gol Dicetak ($GF$)
  3. Poin *Head-to-Head* antar tim yang seri
  4. Selisih Gol *Head-to-Head*
  5. Gol Tandang *Head-to-Head*
  6. Perbandingan OVR / Undian acak jika masih identik

### 3.2. Cup League (`Cup Liga A` sampai `Cup Liga H`)
* **Jumlah Turnamen:** 8 piala terpisah (1 piala untuk masing-masing Liga A–H).
* **Peserta (16 Tim per Liga):**
  * **Musim 1:** Diambil otomatis dari **16 tim dengan OVR tertinggi** di masing-masing liga lokal.
  * **Musim 2+:** Diambil dari **peringkat 1–16** klasemen akhir masing-masing liga lokal di musim sebelumnya.
* **Format Kompetisi:** Sistem gugur (*Knockout*) **1 leg** di tempat netral (tanpa bonus *home advantage*), mulai dari **16 Besar $\rightarrow$ Perempat Final $\rightarrow$ Semifinal $\rightarrow$ Final**.
* **Aturan Seri:** Jika skor imbang di waktu normal, langsung dilanjutkan ke **Adu Penalti**.

### 3.3. Turnamen Kontinental (Aktif Mulai Musim 2)
Pada **Musim 1**, menu turnamen kontinental berstatus *"Belum Bergulir — Menunggu Hasil Klasemen Akhir Musim 1"*. Mulai **Musim 2**, slot diisi berdasarkan peringkat akhir Liga A–H:

| Nama Turnamen | Kualifikasi Liga A–H | Total Tim | Format Fase Awal | Format Fase Gugur (*Knockout*) |
| :--- | :--- | :---: | :--- | :--- |
| **Champions League** | Peringkat **1 – 4** | **32 Tim** | **League Phase (Format UCL Modern):** 1 klasemen besar. Dibagi ke Pot 1–4 sesuai peringkat liga (Rank 1 = Pot 1, dst). Tiap tim main **8 laga** (lawan 2 tim dari tiap pot: 1 kandang, 1 tandang). Rank 1–8 lolos ke 16 Besar; Rank 9–24 adu *Play-off* 2 leg; Rank 25–32 gugur. | 2 Leg (kandang-tandang, tanpa aturan gol tandang, seri $\rightarrow$ Penalti). **Final 1 Leg** di tempat netral. |
| **Winner League** | Peringkat **5 – 8** | **32 Tim** | **League Phase:** Identik dengan Champions League (Pot 1 = Rank 5, Pot 2 = Rank 6, Pot 3 = Rank 7, Pot 4 = Rank 8). | Identik dengan Champions League. |
| **Federation League** | Peringkat **9 – 12** | **32 Tim** | **League Phase:** Identik dengan Champions League (Pot 1 = Rank 9, Pot 2 = Rank 10, Pot 3 = Rank 11, Pot 4 = Rank 12). | Identik dengan Champions League. |
| **Mid Range League** | Peringkat **13 – 17** | **40 Tim** | **Fase Grup (Format UCL Lama):** Dibagi menjadi **8 Grup (Grup A–H)** berisi **5 tim** per grup (*Single Round-Robin*, 4 laga per tim). **Rank 1 & 2** grup lolos ke 16 Besar Mid Range; **Rank 3 grup turun/pindah ke 16 Besar Challenger League**; Rank 4 & 5 gugur. | 2 Leg (tanpa gol tandang, seri $\rightarrow$ Penalti). **Final 1 Leg** di tempat netral. |
| **Challenger League** | Peringkat **18 – 20** | **24 Tim** | **Fase Grup:** Dibagi menjadi **8 Grup (Grup A–H)** berisi **3 tim** per grup (*Double Round-Robin*, 4 laga per tim). Hanya **Juara Grup (8 tim)** yang lolos ke 16 Besar, bergabung dengan **8 tim peringkat 3 grup Mid Range League**. Rank 2 & 3 gugur. | 2 Leg (tanpa gol tandang, seri $\rightarrow$ Penalti). **Final 1 Leg** di tempat netral. |

---

## 4. Manajemen Tim & Dinamika OVR

### 4.1. Input List Tim (Setup Liga)
* **Atribut Tim:**
  * `name` (String, **Wajib**)
  * `ovr` (Integer `1–100`, **Wajib**)
  * `logoPath` (String/File gambar lokal, **Opsional** — jika kosong otomatis memakai avatar perisai inisial klub dengan warna acak)
* **Kemudahan Input List:**
  * Di halaman setup tiap liga (Liga A–H), langsung tersedia **20 baris input berurutan** (*Nama Tim* + *Input Angka OVR* + *Tombol Pilih Logo*) lengkap dengan penghitung `0/20 Tim Terisi`.
  * Tersedia tombol **"Paste List Teks"** agar pemain bisa menempel daftar 20 tim sekaligus dari catatan dengan format:
    ```text
    Nama Tim A, 85
    Nama Tim B, 82
    ```

### 4.2. Perubahan OVR: Transfer Window & Cedera
Setiap perubahan OVR wajib dibatasi dalam rentang minimum **1** dan maksimum **100** (`ovr.clamp(1, 100)`), serta dicatat dalam **Log Berita (*Event Feed*)**.

1. **Transfer Window (2x per Musim: Setelah Week 19 Liga Lokal & Akhir Musim):**
   Setiap tim diundi perubahan OVR-nya berdasarkan tabel bobot probabilitas berikut:
   * **Sangat Sering (Total 70%):** `-3`, `-2`, `-1`, `+1`, `+2`, `+3` (masing-masing peluang $\approx 11{,}67\%$)
   * **Cukup Jarang (Total 20%):** `-4`, `0`, `+4` (masing-masing peluang $\approx 6{,}67\%$)
   * **Jarang (Total 8%):** `-5`, `+5` (masing-masing peluang $4\%$)
   * **Sangat Jarang / *Golden Era* (Total 2%):** `+6`, `+7`, `+8`, `+9`, `+10` (masing-masing peluang $0{,}4\%$)
2. **Simulasi Cedera Pemain (Random Tengah Musim):**
   * Di setiap pergantian pekan pertandingan, tiap tim memiliki peluang kecil (**$1{,}5\%$**) mengalami badai cedera yang menurunkan OVR sebesar **`-1` (60%)**, **`-2` (30%)**, atau **`-3` (10%)**.

---

## 5. Match Engine & Rumus Matematis

### 5.1. Parameter Dasar & Home Advantage
* **Bonus Kandang (*Home Advantage*):** Jika pertandingan berlangsung kandang-tandang (bukan tempat netral), tim tuan rumah mendapat tambahan **`+2 OVR`** sebelum perhitungan.
* **Selisih Kekuatan ($\Delta$):**
  $$\Delta = (\text{OVR}_{\text{home}} + \text{HomeBonus}) - \text{OVR}_{\text{away}}$$

### 5.2. Model Davidson (Indikator Peluang Menang / Seri / Kalah)
Digunakan untuk menghitung persentase peluang hasil pertandingan yang ditampilkan pada kartu *preview* pertandingan dan analitik pra-laga:
$$R = 10^{\frac{\Delta}{S}}, \quad \text{dengan konstanta } S = 15 \text{ dan } \nu = 0{,}8$$

* **Peluang Tuan Rumah Menang:** $P(H) = \frac{R}{R + 1 + \nu\sqrt{R}}$
* **Peluang Seri:** $P(D) = \frac{\nu\sqrt{R}}{R + 1 + \nu\sqrt{R}}$
* **Peluang Tim Tamu Menang:** $P(A) = \frac{1}{R + 1 + \nu\sqrt{R}}$

### 5.3. Distribusi Poisson (Simulasi Skor Akhir & Gol)
Untuk menghasilkan skor gol realistis ($k_{\text{home}}$ vs $k_{\text{away}}$) saat tombol **Simulate** ditekan:

1. **Menentukan Rata-Rata Gol ($\lambda$ / Expected Goals):**
   * **Musim 1 (Belum ada histori gol):**
     $$\lambda_{\text{home}} = \max\left(0{,}25,\; 1{,}35 + (\Delta \times 0{,}05)\right)$$
     $$\lambda_{\text{away}} = \max\left(0{,}25,\; 1{,}35 - (\Delta \times 0{,}05)\right)$$
   * **Musim 2+ (Hybrid 70% OVR + 30% Histori Gol Musim Sebelumnya):**
     $$\lambda_{\text{final}} = (0{,}7 \times \lambda_{\text{OVR}}) + \left(0{,}3 \times \frac{\text{AvgGF}_{\text{tim}} + \text{AvgGA}_{\text{lawan}}}{2}\right)$$
2. **Momen Tak Terduga (*Chaotic / Pesta Gol $>5$ Gol*):**
   * Setiap pertandingan memiliki peluang **$2{,}5\%$** memicu *Chaotic Event* (misal kartu merah dini atau performa eksplosif). Saat aktif, salah satu tim (diacak) mendapat lonjakan $\lambda$ sebesar **`+2.5` hingga `+3.5` gol**, sehingga memungkinkan terciptanya skor besar seperti `6-0`, `5-3`, atau kejutan besar (*upset*).
3. **Pembangkitan Jumlah Gol ($k$) via Kumulatif Poisson:**
   $$P(k) = \frac{\lambda^k \cdot e^{-\lambda}}{k!}, \quad \text{untuk } k = 0, 1, 2, \dots, 10$$
   Bangkitkan bilangan acak (*random float*) $u \in [0, 1]$ untuk masing-masing tim dan cocokkan dengan rentang probabilitas kumulatifnya untuk memperoleh skor akhir.
4. **Adu Penalti (Khusus Fase Gugur yang Seri):**
   Jika agregat imbang pada fase gugur, sistem menjalankan simulasi 5 penendang (+ *sudden death* jika masih seri) dengan peluang masuk $75\% + (\Delta \times 0{,}3\%)$ dan menyimpan skor penalti pada objek pertandingan.

---

## 6. Sistem Penjadwalan Terpadu & Mekanisme Simulasi

* **Kalender Terpadu (*Unified Gameweek*):** Seluruh jadwal dari 14 turnamen disusun otomatis sejak awal musim ke dalam **Pekan 1 sampai Pekan 48**:
  * **Slot Akhir Pekan:** 38 Pekan Liga Lokal (A–H).
  * **Slot Tengah Pekan:** 4 Babak Cup League + 8 Matchday League Phase + Play-off & Fase Knockout Kontinental.
* **Kontrol Simulasi di Menu Fixture:**
  * **Simulate Satuan:** Tombol `Simulate` di tiap kartu pertandingan untuk menjalankan laga satu per satu.
  * **Simulate Pekan Ini (*Simulate Week*):** Tombol aksi cepat untuk mensimulasikan seluruh pertandingan yang tersisa pada pekan aktif sekaligus.
* **Transisi Antar-Musim (*End Season*):** Setelah seluruh laga Pekan 48 (termasuk semua Final) selesai, muncul tombol **"Tutup Musim & Lanjut ke Musim Berikutnya"** yang otomatis mengarsipkan rekor ke *History*, menjalankan *Transfer Window* akhir musim, mengundi grup/pot turnamen kontinental baru, dan mereset klasemen.

---

## 7. Spesifikasi Halaman UI/UX

1. **Halaman Setup Awal (Onboarding Liga A–H):** Tab A–H untuk input 20 tim per liga dalam bentuk daftar berurutan + tombol *Paste List Teks*, dilengkapi validasi tombol *"Mulai Musim 1"* (aktif hanya jika $8 \times 20 = 160$ tim sudah lengkap).
2. **Halaman Turnamen:** Menampilkan daftar 14 turnamen yang dikelompokkan dalam 3 kategori (*Liga Lokal*, *Cup Domestik*, *Turnamen Kontinental*).
3. **Halaman Info Turnamen:**
   * *Tab Klasemen / Bagan:* Tabel klasemen lengkap (MP, W, D, L, GF, GA, GD, PTS) dengan indikator warna zona kualifikasi kontinental, atau tampilan *Bracket* untuk fase gugur.
   * *Tab Jadwal & Hasil:* Riwayat pertandingan yang sudah dimainkan dan jadwal mendatang di turnamen tersebut.
   * *Tab Statistik & Drawing:* Daftar tim peserta, pembagian Pot/Grup, serta tim tersubur & pertahanan terbaik.
4. **Halaman Daftar Tim & Info Detail Tim:**
   * Pencarian & filter tim berdasarkan liga.
   * Saat tim diklik, tampilkan: Logo, Nama, OVR saat ini + indikator perubahan (`+3` hijau / `-2` merah), peringkat aktif di Liga Lokal & Kontinental, **Kabinet Trofi** (jumlah gelar tiap ajang), grafik/daftar peringkat musim-musim sebelumnya, dan rata-rata gol cetak/kebobolan.
5. **Halaman Fixture:** Menampilkan seluruh jadwal dari awal sampai akhir musim secara terpadu dengan badge nama turnamen di tiap kartu laga, dilengkapi filter **Pekan (Week 1–48)**, filter **Turnamen**, dan tombol **Simulate**.
6. **Halaman History (Arsip Sejarah):** Menyimpan rekam jejak tiap musim (`Season 1`, `Season 2`, dst.) yang berisi:
   * Daftar Juara & *Runner-up* seluruh 14 turnamen.
   * Penghargaan Statistik Musim: **Tim Tersubur** (gol terbanyak), **Pertahanan Terbaik** (kebobolan paling sedikit), dan **Skor Terbesar / Kejutan Terbesar** musim tersebut.
   * Papan Peringkat Koleksi Trofi Sepanjang Masa (*All-Time Hall of Fame*).

---

## 8. Struktur Data (Dart Models) & Arsitektur Folder

### 8.1. Struktur Folder Proyek (`lib/`)
```text
lib/
├── main.dart
├── models/
│   ├── team.dart
│   ├── tournament.dart
│   ├── match_game.dart
│   ├── standing_row.dart
│   ├── season_archive.dart
│   └── news_event.dart
├── engine/
│   ├── match_simulator.dart      # Rumus Davidson, Poisson, Chaotic Event & Penalti
│   ├── fixture_generator.dart    # Generator jadwal Round-Robin, Pot UCL, Grup & Bracket
│   └── ovr_manager.dart          # Logika Transfer Window & Random Injury
├── services/
│   └── storage_service.dart      # Penyimpanan lokal (Hive/SQLite) & Export/Import JSON
├── providers/
│   └── game_state_provider.dart  # State management seluruh ekosistem turnamen
└── ui/
    ├── screens/                  # Halaman utama (Setup, Turnamen, Fixture, Tim, History)
    └── widgets/                  # Komponen reusable (MatchCard, StandingsTable, TeamBadge)
```

### 8.2. Skema Model Utama
* **`Team`:** `id`, `name`, `leagueId`, `ovr`, `lastOvrChange`, `logoPath`, `trophies` (Map), `seasonHistory` (List riwayat peringkat & rata-rata gol per musim).
* **`Tournament`:** `id`, `name`, `type` (`localLeague`, `domesticCup`, `continentalLeague`, `continentalGroup`), `seasonNumber`, `teamIds`, `potsOrGroups`, `isActive`.
* **`MatchGame`:** `id`, `tournamentId`, `seasonNumber`, `gameweek` (`1–48`), `stageName` (misal `"Week 12"`, `"League Phase MD 3"`, `"Final"`), `leg` (`1` atau `2`), `isNeutralVenue`, `homeTeamId`, `awayTeamId`, `homeScore`, `awayScore`, `homePenaltyScore`, `awayPenaltyScore`, `isFinished`, `isChaoticMatch`.
* **`SeasonArchive`:** `seasonNumber`, `championsMap` (Juara & Runner-up tiap turnamen), `topScoringTeam`, `bestDefenseTeam`, `biggestScoreMatch`, `newsEvents`.