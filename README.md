# Golf Slove

Aplikasi iOS untuk golfer: membaca kemiringan green, menghitung skor dan handicap, serta tips & trik golf.

Versi ini (0.1) berisi **prototipe baca green**. Tab Skor dan Tips masih placeholder.

## Cara kerja baca green

1. **Pindai**: arahkan iPhone ke green dan berjalan pelan di antara bola dan lubang. Sensor LiDAR (iPhone Pro) atau kamera mengumpulkan titik permukaan, lalu aplikasi menghitung kemiringan per kotak 20 × 20 cm.
2. Green diberi warna: hijau < 1%, kuning 1–2%, oranye 2–3%, merah > 3%. Panah putih menunjuk ke arah turun, yaitu ke mana bola akan berbelok.
3. **Bola** lalu **Lubang**: ketuk layar di posisi bola dan lubang.
4. Aplikasi menyimulasikan putt dan menampilkan titik bidik (tiang merah), lintasan bola (garis kuning), dan saran seperti "Bidik 25 cm ke kanan lubang".
5. Atur **Stimp** sesuai kecepatan green (umumnya 8–11) agar perhitungan lebih tepat.

> Catatan: menurut Rules of Golf (Aturan 4.3), alat pengukur kemiringan tidak boleh dipakai saat kompetisi resmi. Gunakan untuk latihan dan ronde santai.

## Menjalankan di iPhone Anda

Yang diperlukan:
- Mac dengan **macOS 14.5 atau lebih baru**
- **Xcode 16 atau lebih baru** (gratis di Mac App Store). Proyek ini tidak bisa dibuka dengan Xcode 15 atau lebih lama.
- iPhone dengan iOS 17 atau lebih baru, dan kabel USB / USB-C
- Apple ID biasa (gratis). Akun Apple Developer berbayar belum diperlukan untuk uji coba.

### Langkah 1: Pasang dan siapkan Xcode

1. Buka **App Store** di Mac, cari **Xcode**, lalu klik **Get / Install**. Ukurannya besar (±10 GB), jadi butuh waktu.
2. Buka Xcode untuk pertama kali. Jika muncul jendela **"Select the platforms you want to develop for"**, centang **iOS** lalu klik **Download & Install**. Tunggu sampai selesai.
   - Jika jendela itu tidak muncul: menu **Xcode → Settings… → Components** (atau **Platforms**), lalu unduh **iOS**.
3. Cek versinya di menu **Xcode → About Xcode**. Harus 16.0 atau lebih tinggi.

### Langkah 2: Unduh kode aplikasi

Cara paling mudah tanpa Terminal:
1. Buka https://github.com/dasmighty/golf-slove-app di browser (pastikan sudah login GitHub).
2. Klik tombol hijau **Code → Download ZIP**.
3. Buka folder **Downloads**, klik dua kali file ZIP-nya. Akan muncul folder **golf-slove-app-main**. Pindahkan folder itu ke tempat yang mudah, misalnya **Documents**.

(Atau lewat Terminal: `git clone https://github.com/dasmighty/golf-slove-app.git`)

### Langkah 3: Buka proyek

1. Buka folder **golf-slove-app-main**.
2. Klik dua kali **GolfSlove.xcodeproj** (ikon biru). Xcode akan terbuka.
3. Jika Xcode bertanya **"Trust and Open"**, pilih itu.

### Langkah 4: Masukkan Apple ID untuk tanda tangan aplikasi

1. Menu **Xcode → Settings… → Accounts**, klik **+** di kiri bawah, pilih **Apple ID**, lalu login.
2. Tutup jendela Settings. Di panel kiri Xcode, klik baris paling atas yang bertuliskan **GolfSlove** (ikon biru).
3. Di bagian tengah, di bawah **TARGETS** pilih **GolfSlove**, lalu buka tab **Signing & Capabilities**.
4. Pastikan **Automatically manage signing** tercentang, lalu di **Team** pilih **nama Anda (Personal Team)**.
5. Jika muncul error merah soal **Bundle Identifier**, ganti `com.dasmighty.golfslove` menjadi yang unik, misalnya `com.dhany.golfslove2026`.

### Langkah 5: Sambungkan iPhone

1. Colokkan iPhone ke Mac dengan kabel. Buka kunci iPhone, lalu ketuk **Trust / Percayai** dan masukkan kode iPhone.
2. Di bagian atas tengah Xcode ada pilihan perangkat (misalnya "iPhone 16 Pro"). Klik, lalu pilih **iPhone Anda** di bagian **iOS Device**. Jangan pilih Simulator, karena AR tidak bisa berjalan di Simulator.
3. Aktifkan **Developer Mode** di iPhone: **Settings → Privacy & Security → Developer Mode** (paling bawah) → nyalakan → **Restart**. Setelah restart, ketuk **Turn On**.
   - Menu Developer Mode baru muncul setelah iPhone pernah disambungkan ke Xcode. Jika belum terlihat, cabut lalu colok lagi kabelnya dan tunggu sebentar.

### Langkah 6: Jalankan

1. Klik tombol **▶︎** (Run) di kiri atas Xcode, atau tekan **⌘R**.
2. Saat pertama kali, iPhone mungkin menolak membuka aplikasi ("Untrusted Developer"). Buka **Settings → General → VPN & Device Management**, ketuk Apple ID Anda, lalu **Trust**. Kemudian tekan ▶︎ lagi di Xcode.
3. Izinkan akses kamera saat diminta.

Dengan Apple ID gratis, aplikasi perlu dipasang ulang dari Xcode setiap 7 hari.

### Jika ada masalah

| Pesan / gejala | Solusi |
| --- | --- |
| "The project … cannot be opened" atau "future Xcode project file format" | Xcode terlalu lama. Perbarui ke Xcode 16 atau lebih baru. |
| "iOS 17.x is not installed" / "Platform not installed" | Xcode → Settings → Components → unduh iOS. |
| "Signing for GolfSlove requires a development team" | Ulangi Langkah 4: pilih Team (Personal Team). |
| "Failed to register bundle identifier" | Ganti Bundle Identifier menjadi nama unik (Langkah 4 nomor 5). |
| iPhone tidak muncul di daftar perangkat | Buka kunci iPhone, ketuk Trust, coba kabel/port lain, atau buka menu Window → Devices and Simulators. |
| "Developer Mode disabled" | Langkah 5 nomor 3. |
| Error merah saat build (Build Failed) | Klik ikon segitiga merah di panel kiri, lalu kirim screenshot pesan errornya. |

## Struktur kode

| File | Isi |
| --- | --- |
| `GolfSlove/Green/HeightField.swift` | Grid ketinggian dan perhitungan kemiringan (tanpa ketergantungan ARKit) |
| `GolfSlove/Green/PuttSimulator.swift` | Simulasi bola menggelinding dan pencarian titik bidik |
| `GolfSlove/Green/GreenReaderModel.swift` | Sesi ARKit, pengambilan titik LiDAR/kamera, ketukan |
| `GolfSlove/Green/GreenOverlay.swift` | Gambar AR: peta warna, panah, bola, lubang, lintasan |
| `GolfSlove/Green/GreenReaderView.swift` | Layar SwiftUI baca green |

## Rencana

1. ✅ Prototipe baca green (versi ini)
2. Kartu skor 18 hole dan handicap sederhana
3. Tips & trik dan perapian tampilan
4. Rilis gratis di App Store
