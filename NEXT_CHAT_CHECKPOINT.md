# NEXT CHAT CHECKPOINT — Map58 / Godot

Tanggal checkpoint: 2026-10-04

## IDENTITAS PROJECT
- Engine: Godot 4.7.2
- Project path: C:\Users\LENOVO\Documents\prototipe-1
- Device: DESKTOP-QRVA3D9
- Project utama: Map58 / game horror school multiplayer
- File aturan utama: PROJECT_RULES.md
- File checkpoint ini: NEXT_CHAT_CHECKPOINT.md

## ATURAN WAJIB
Baca PROJECT_RULES.md terlebih dahulu sebelum mengedit apa pun.

MAP58:
- Geometry/floorplan JANGAN UBAH.
- Posisi Map58 JANGAN UBAH.
- Collision Map58 JANGAN UBAH.

SCENE ANAK:
- Root harus lokal.
- Tidak boleh membawa/instance Map58.
- Layout internal memakai koordinat lokal.
- Posisi dunia ditentukan oleh parent/instance.
- Jangan memindahkan root child scene untuk menyesuaikan posisi dunia kecuali user memerintahkannya.

PERUBAHAN:
- Jangan mengubah apa pun di luar permintaan user.
- Jangan reset ke versi lama tanpa perintah.
- Kondisi yang user ubah manual adalah baseline baru.
- Sebelum edit: baca file aktual.
- Setelah edit: validasi file/scene tree/parser.
- Jangan mengklaim selesai sebelum diverifikasi.
- Gunakan nama file yang sudah ada; jangan membuat V2/FIXED tanpa alasan yang diminta.
- Saat menambahkan sesuatu, jelaskan scene/node, parent, posisi lokal, posisi world bila relevan, dan rotasi bila relevan.

## CARA KERJA ASISTEN
- Bertindak sebagai developer/project maintainer.
- Gunakan Remote Desktop Commander untuk bekerja langsung pada PC bila tersedia.
- Jangan menebak kondisi file berdasarkan percakapan lama.
- Utamakan satu perubahan yang fokus pada satu permintaan.
- Untuk ukuran model, bedakan scale seragam dengan duplikasi mesh/model.
- Jika user meminta "kalikan 2" dan maksudnya memperbanyak keseluruhan bentuk, jangan memakai non-uniform scale satu sumbu yang menyebabkan model gepeng.
- Jangan menyentuh Map58 untuk menyelesaikan masalah child scene.

## STATUS TERKINI — BASKETBALL BLEACHERS
File:
- res://BasketballBleachers.tscn
- instance di res://main.tscn

User sudah mengubah sendiri posisi dan bentuk BasketballBleachers. Kondisi manual terbaru HARUS dianggap baseline dan dipertahankan.

Struktur penting yang terverifikasi:
- root: BasketballBleachers (Node3D), local origin
- child: Model (Node3D)
- child: Model_02 (Node3D)
- Model berisi Platforms, Seats, dan railing meshes
- Model_02 juga berisi Platforms, Seats, dan railing meshes
- total layout sekarang lebih besar/berlapis karena ada Model dan Model_02; jangan menghapus, merapikan, atau menggabungkan keduanya tanpa perintah user.

Transform aktual terverifikasi:
- BasketballBleachers/Model:
  scale = (1.15, 1.15, 1.15)
  local position = (11.303591, 0, 10.599238)
- BasketballBleachers/Model_02:
  scale = (1.15, 1.15, 1.15)
  local position = (11.303591, 0, 21.656162)
- main.tscn instance BasketballBleachers:
  position = (42.0, -0.18, -3.49)
- main.tscn instance BasketballCourt:
  position = (42.4047, -0.18, 8.0614)

## TERAKHIR YANG TERJADI
1. User sebelumnya meminta bleachers dibesarkan ~15%.
2. Model awalnya diubah ke scale seragam 1.15.
3. User lalu meminta "kalikan 2 ke sumbu z", maksudnya bukan membuat objek gepeng, tetapi memperbanyak keseluruhan bagian/material mesh.
4. Percobaan scale Z=2.30 membuat bentuk gepeng; perubahan itu langsung dikembalikan ke scale seragam 1.15.
5. File aktual sekarang memiliki Model dan Model_02. Jangan menganggap struktur ini salah; user sudah mengubah bentuk/posisinya dan itulah baseline.
6. Sebelumnya user juga bertanya tentang railing yang terpisah dari Model. Kondisi aktual menunjukkan railing meshes berada sebagai child langsung di bawah Model dan Model_02 (bukan di dalam node Railings terpisah). Jangan memindahkannya lagi kecuali user meminta.
7. User meminta checkpoint karena chat mencapai batas maksimum.

## MAP58 / MAIN
main.tscn masih memiliki:
- Map58 instance res://map58/Map58.tscn
- Furniture
- BasketballCourt
- BasketballBleachers
- SpawnManager
- Teacher
Jangan ubah Map58/floorplan/collision.

## PREFERENSI USER
- Indonesian, gaya santai dan langsung.
- Sangat tidak suka perubahan yang menghapus hasil manual atau menambah error.
- Tidak ingin bolak-balik mengganti file secara manual jika perubahan bisa dilakukan langsung pada PC.
- Saat mengganti script/file, gunakan nama file yang sama.
- Jangan kirim preview gambar jika tidak diminta.
- Bila tidak aman/tidak bisa dilakukan tanpa merusak aturan, katakan sebelum mengedit.
- Saat menambahkan objek, jelaskan tepat di mana objek ditaruh.

## LANGKAH PERTAMA CHAT BARU
1. Baca NEXT_CHAT_CHECKPOINT.md.
2. Baca PROJECT_RULES.md.
3. Baca file aktual yang berkaitan dengan permintaan baru.
4. Jangan reset BasketballBleachers atau Map58.
5. Tanyakan/interpretasikan permintaan baru berdasarkan kondisi aktual, bukan kondisi lama.
