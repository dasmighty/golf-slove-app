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

Yang diperlukan: Mac dengan **Xcode 16 atau lebih baru** (gratis di App Store), iPhone dengan iOS 17+, dan kabel USB. Untuk uji coba cukup Apple ID biasa, belum perlu akun Apple Developer berbayar.

1. Unduh kode: di halaman GitHub repo ini klik **Code → Open with GitHub Desktop**, atau di Terminal:
   ```
   git clone https://github.com/dasmighty/golf-slove-app.git
   ```
2. Buka file `GolfSlove.xcodeproj` dengan Xcode.
3. Di Xcode: klik proyek **GolfSlove** di panel kiri → tab **Signing & Capabilities** → di **Team** pilih **Add an Account...** dan masuk dengan Apple ID Anda, lalu pilih tim "(Personal Team)".
   - Jika muncul error bundle identifier, ubah `com.dasmighty.golfslove` menjadi sesuatu yang unik, misalnya `com.namaanda.golfslove`.
4. Sambungkan iPhone ke Mac. Di iPhone, aktifkan **Settings → Privacy & Security → Developer Mode**, lalu restart jika diminta.
5. Di bagian atas Xcode pilih iPhone Anda sebagai tujuan, lalu tekan tombol ▶︎ (Run).
6. Saat pertama kali, di iPhone buka **Settings → General → VPN & Device Management**, pilih Apple ID Anda, lalu ketuk **Trust**.

Dengan Apple ID gratis, aplikasi perlu dipasang ulang dari Xcode setiap 7 hari.

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
