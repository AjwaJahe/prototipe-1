# Audit AI Guru — 10 Oktober 2026

## Perubahan yang diterapkan

### 1. `TeacherAI_New.gd`
- `_try_open_door_in_path()` tidak lagi membuka pintu hanya berdasarkan jarak dan arah.
- Sistem sekarang melakukan raycast ke arah gerak dan hanya membuka pintu jika collider yang benar-benar terkena merupakan bagian dari node pintu yang tertutup.
- Ditambahkan helper `_is_node_within_door()` untuk mengenali collider di bawah `DoorPivot` maupun struktur pintu lain.
- `_move_intro_departure_toward()` tidak lagi memakai fallback bergerak lurus ke koordinat tujuan saat NavigationAgent belum menyediakan titik rute. Guru berhenti sementara dan menunggu rute, daripada mencoba menembus penghalang.

### 2. `PintuKelas.gd`
- Ketika guru membuka pintu geser, arah geser dipilih menjauhi sisi tempat guru berdiri.
- Sebelumnya arah geser tetap dapat memindahkan daun pintu tepat ke arah guru, sehingga status pintu sudah terbuka tetapi collider masih menghalangi guru.

### 3. `map58/Map58.tscn`
- Sumber geometri navmesh diubah ke `geometry_parsed_geometry_type = 1` (static colliders).
- `cell_size = 0.2`, `cell_height = 0.1`, `agent_radius = 0.6`, `agent_height = 2.0`, dan `agent_max_climb = 0.4`.
- Tujuannya supaya bake menggunakan collision fisik untuk menentukan area yang bisa dilalui, bukan menganggap permukaan render furnitur sebagai permukaan navigasi.

### 4. `map58/Map58_NavigationBaker.gd`
- Navigation map disamakan pada `cell_size` dan `cell_height` dengan NavigationMesh.
- Root collision map `Map58Collision` dimasukkan sebagai sumber geometri navmesh.
- Saat bake, 29 root sumber geometri yang ditandai sementara dipindahkan ke bawah NavigationRegion agar parser dapat mengumpulkan sumber dari hierarchy region. Setelah pemanggilan bake, node dikembalikan ke parent dan urutan sibling asalnya. Ini menjaga NodePath gameplay seperti `Furniture/PintuKelas_...` tetap valid.
- Proses bake sekarang memakai collision shapes, sehingga peringatan pembacaan mesh dari GPU tidak muncul pada pengujian terakhir.

## Pengujian yang dijalankan

1. Memuat `main.tscn` melalui Godot 4.7.2 headless dengan skrip audit runtime.
2. Navmesh berhasil dibake dengan **2.409 poligon** pada pengujian rute terakhir; 29 root sumber geometri diproses.
3. Uji rute dari koridor dekat `WayPoint_04` ke `WayPoint_02`: guru melewati dua pintu kelas yang benar-benar menghalangi jalur, kedua pintu terbuka, lalu guru kembali bergerak dan mencapai area tujuan dalam 15 detik simulasi. Timer macet tetap 0 pada sampel setelah pintu dilewati.
4. Uji rute lurus koridor dari `(20, -36.1)` ke `WayPoint_04`: selama segmen koridor, guru bergerak konsisten dan tidak membuka pintu kelas yang berada di samping jalur. Setelah tiba di area waypoint dan AI memilih tujuan berikutnya, pintu baru dibuka ketika raycast benar-benar mengenai collider pintu yang menghalangi rute.
5. Pengujian terakhir selesai dengan kode keluar Godot **0**. Tidak ditemukan `SCRIPT ERROR` atau `Parse Error` pada log audit.

## Peringatan yang masih terlihat

- `FirstPersonLocalHeadCulling.gd` masih mengeluarkan warning bahwa node `PlayerVisual` tidak ditemukan. Itu berasal dari script lain dan belum diubah dalam audit AI guru ini.
- Uji headless membuktikan rute dan interaksi pintu pada skenario terpilih; ini belum menggantikan pengujian manual penuh untuk semua mode AI, cutscene, dan seluruh kelas di game.

## Backup

Sebelum perubahan audit dibuat salinan:
- `TeacherAI_New.gd.audit_20261010_2203.bak`
- `map58/Map58_NavigationBaker.gd.audit_20261010_2203.bak`
- `map58/Map58.tscn.audit_20261010_2203.bak`

Backup pintu dari perbaikan sebelumnya juga masih ada: `PintuKelas.gd.before_door_nav_fix_20261010.bak`.
