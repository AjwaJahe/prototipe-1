# Integrasi NodeTunnel — Demo Multiplayer (2026-10-12)

## Lingkup

Perubahan diterapkan pada proyek utama:
`C:\Users\LENOVO\Documents\prototipe-1`

Proyek pengujian terpisah `ujicoba-multi` tidak diubah.

## Perubahan

- Menyalin addon NodeTunnel ke `addons/nodetunnel`, termasuk library Windows dan Android ARM64.
- Mengaktifkan plugin NodeTunnel di `project.godot`.
- Menetapkan kompresi tekstur ETC2/ASTC untuk target Android.
- Mengubah `RoomFlow.gd`:
  - App ID NodeTunnel disimpan di konfigurasi script; pemain tidak perlu mengisinya.
  - Host meminta NodeTunnel membuat room sungguhan dan menampilkan Room ID yang dikembalikan relay.
  - Pemain yang bergabung hanya perlu memasukkan Room ID.
  - Peer dipasang ke MultiplayerAPI sejak proses koneksi dimulai agar dapat dipoll dan memicu sinyal autentikasi.
  - Menambahkan timeout koneksi, penanganan error/forced disconnect, dan pembersihan peer saat batal atau keluar.
  - Tombol salin Room ID menggunakan clipboard.
  - Tombol mulai sekarang hanya tersedia bagi host dan transisi scene dikirim secara reliable ke seluruh room, termasuk pengaturan mode/durasi.
- Menambahkan `MultiplayerGame.gd` ke `main.tscn` untuk mengirim posisi/arah badan tiap pemain dan membuat avatar visual remote di perangkat lain.
- Batas jumlah pemain dan status siap masih belum ditegakkan/disinkronkan. Sistem gameplay lain (AI guru, item, soal, objektif, dan hasil permainan) juga belum menjadi state multiplayer otoritatif.
- Menambahkan preset ekspor Android ARM64 bernama `Kelas Malam Android Demo`.

## Validasi yang dilakukan

- Godot 4.7.2 headless memuat scene menu dan mengenali kelas `NodeTunnelPeer`.
- Tes host nyata melalui relay berhasil: Room ID diterima dan lobi menampilkan status tersambung.
- APK berhasil dibuat di `build/kelas-malam-demo.apk` (42.946.611 byte).
- APK memiliki tanda tangan v2 dan v3 yang valid.
- APK menyertakan `lib/arm64-v8a/libnodetunnel.android.arm64.so` dan izin `android.permission.INTERNET`.

## Catatan dan batasan

- Koneksi room online aktif, tetapi gameplay belum disinkronkan antarpemain.
- Pilihan jumlah pemain saat ini hanya informasi UI; relay tidak membatasi kapasitas berdasarkan pilihan itu.
- Log ekspor juga mencatat referensi resource lama yang hilang/tidak valid: `Furniture_Administrasi.glb`, `school_map_master_floor_editable.glb`, `SchoolMap_FloorColorController.gd`, serta UID tidak valid di `WhiteboardTest.tscn`. Ekspor tetap menghasilkan APK, tetapi resource terkait perlu diaudit terpisah sebelum rilis.

## Backup sebelum perubahan

- `RoomFlow.gd.before_nodetunnel_20261012_095253.bak`
- `MainMenu.gd.before_nodetunnel_20261012_095253.bak`
- `project.godot.before_nodetunnel_20261012_095253.bak`
