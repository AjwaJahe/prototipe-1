# Catatan Audit & Perbaikan — 11 Oktober 2026

## Ruang lingkup
Audit awal difokuskan pada penempatan item dan integrasinya dengan collision scene, karena sistem spawn menghitung titik dari AABB mesh dan sebelumnya tidak memverifikasi bahwa titik tersebut benar-benar ditopang collision fisik. File aktif yang dipakai main.tscn adalah `Map58ItemSpawnerV2.gd`; `Map58ItemSpawner.gd` bukan script spawner yang aktif pada scene utama.

## Perubahan
### `Map58ItemSpawnerV2.gd`
1. Menunggu dua physics frame setelah satu process frame sebelum mengumpulkan dan memvalidasi titik spawn. Tujuannya memberi waktu agar collision map dan furnitur tersedia di physics space.
2. Menambahkan `_validate_spawn_points()`.
   - Raycast vertikal di setiap kandidat permukaan.
   - Mengecualikan RID item agar item yang sudah ada tidak dianggap sebagai permukaan penopang.
   - Menolak titik tanpa collision pendukung, titik yang mengenai sisi vertikal, serta titik yang terlalu jauh dari permukaan collision yang ditemukan.
   - Menyelaraskan ketinggian titik ke collision aktual ditambah `initial_surface_offset`.
   - Menyusun ulang indeks titik per ruang agar pembatasan ruang yang sudah ada tetap konsisten.
3. Menambahkan log jumlah titik tervalidasi untuk memudahkan diagnosis di run berikutnya.

### Backup
Salinan sebelum perubahan: `Map58ItemSpawnerV2.gd.before_surface_validation_20261011.bak`.

## Hasil pengujian
- Godot 4.7.2 headless memuat `main.tscn`, memulai spawner, dan menyelesaikan bake navmesh dengan exit code 0.
- Titik kandidat awal: 1.293.
- Titik yang lolos validasi pada pengujian runtime: 344 (run lain menghasilkan 346 karena konfigurasi runtime/seed).
- Item aktif: 15/15; jumlah yang dilaporkan: 5 paper, 3 chalk, 3 medkit, sisanya key.
- Audit raycast setelah perubahan: 15 item diperiksa, 0 item tanpa permukaan penopang yang terdeteksi, 0 pasangan item dengan jarak kurang dari 0,75 unit pada run tersebut.
- Warning yang tetap muncul saat boot normal: `FirstPersonLocalHeadCulling.gd` tidak menemukan node `PlayerVisual`. Warning ini tidak berasal dari perubahan spawner dan belum diperbaiki.
- Validator proyek `tools/validate_project.gd` gagal pada skrip validator itu sendiri (error saat menyelesaikan eksekusi), sehingga hasil validasi penuh seluruh file belum dapat diklaim berhasil. Pemeriksaan boot scene utama tetap berhasil.

## Hasil yang diharapkan
- Item tidak lagi dipasang pada kandidat permukaan yang tidak memiliki dukungan collision yang sesuai.
- Titik item mengikuti tinggi permukaan fisik yang ditemukan, bukan hanya tinggi perkiraan dari AABB mesh.
- Titik yang tidak dapat divalidasi tidak dipakai untuk spawn.
- Jumlah titik valid akan berkurang dibanding 1.293 kandidat mentah; ini disengaja untuk mengutamakan lokasi yang dapat dipertanggungjawabkan secara fisik.

## Batasan yang belum diselesaikan
- Sistem masih menemukan kandidat berdasarkan nama mesh seperti `table`, `desk`, `shelf`, dan `cabinet`. Validasi collision mengurangi risiko item melayang, tetapi belum menggantikan marker spawn eksplisit untuk setiap item.
- Aturan ruangan per jenis item belum diubah; hal itu perlu dicocokkan dengan proposal/gameplay yang benar sebelum mengubah distribusi item.
- AI guru, penangkapan, pintu, dan semua kelas belum menjalani pengujian manual penuh. Perbaikan ini tidak menyatakan masalah AI telah selesai.

## Referensi teknis (10)
1. Godot 4.x — NavigationAgent3D: https://docs.godotengine.org/en/4.x/classes/class_navigationagent3d.html
2. Godot 4.x — NavigationMesh: https://docs.godotengine.org/en/4.x/classes/class_navigationmesh.html
3. Godot 4.7 — Supporting different navigation actor sizes: https://docs.godotengine.org/en/4.7/tutorials/navigation/navigation_different_actor_types.html
4. Godot 4.7 — Using 3D transforms: https://docs.godotengine.org/en/4.7/tutorials/3d/using_transforms.html
5. Godot stable — Physics introduction, collision shapes and masks: https://docs.godotengine.org/en/stable/tutorials/physics/physics_introduction.html
6. Godot 4.0 — PhysicsRayQueryParameters3D: https://docs.godotengine.org/en/4.0/classes/class_physicsrayqueryparameters3d.html
7. Godot latest — NavigationRegion3D and bake completion: https://docs.godotengine.org/en/latest/classes/class_navigationregion3d.html
8. Godot latest — Mesh AABB is in local space: https://docs.godotengine.org/en/latest/classes/class_mesh.html
9. Godot 4.7 — Physics overview and ray-casting index: https://docs.godotengine.org/en/4.7/tutorials/physics/index.html
10. Godot 4.7 — Transform3D: https://docs.godotengine.org/en/4.7/classes/class_transform3d.html

## Metode
Referensi dipakai untuk memeriksa asumsi koordinat lokal/global, peran collision, raycast, dan ukuran agen navigasi. Tidak ada klaim bahwa perilaku game komersial disalin dari kode internalnya.


---

## Perbaikan AI Guru — patroli, pemulihan macet, dan pintu (11 Oktober 2026)

### File aktif yang diubah
1. **`TeacherAI_New.gd`**
   - Watchdog macet tidak lagi membandingkan perpindahan hanya antar-frame. Getaran collision kecil dapat terlihat seperti kemajuan walaupun guru tetap tertahan. Sekarang progres dinilai dalam jendela waktu `stuck_sample_interval = 0.5` detik, dengan ambang `stuck_min_progress = 0.2` unit serta perubahan jarak ke tujuan.
   - Setelah watchdog mendeteksi tidak ada kemajuan selama sekitar 1 detik, guru mencoba arah yang aman di sekitar penghalang melalui sensor raycast. Navigasi normal tetap memakai `NavigationAgent3D`.
   - Lompatan tetap menjadi pemulihan terakhir setelah `stuck_jump_delay` (default 5 detik).
   - Jika satu lompatan gagal menyelesaikan tujuan, patroli memilih waypoint lain; investigasi melewati titik ruangan yang tidak terjangkau; pendekatan pintu, keluar ruangan, atau pencarian yang gagal kembali ke patroli. Pengejaran tidak membuang target hanya karena satu upaya pemulihan gagal.
   - Timer dan sampel watchdog direset saat state/waypoint berubah, agar kegagalan dari tujuan sebelumnya tidak mencemari tujuan baru.
   - Pintu yang dibuka hanya untuk melintas tidak lagi dimasukkan ke mekanisme auto-close berbasis jarak. Uji menunjukkan auto-close dapat menutup pintu ketika guru masih di ambang dan memicu pembukaan berulang. Pintu transit dibiarkan terbuka; pintu ruangan yang benar-benar diinvestigasi tetap ditutup oleh alur `_on_exit_room()`.
   - Kecepatan pemulihan mengikuti kecepatan mode `teacher`, `ghost`, `berserk`, dan `responding` secara konsisten.

2. **`Map58Game.gd`**
   - `debug_start_in_ghost_mode` dikembalikan ke `false`. Pengujian mode hantu langsung saat startup tidak lagi menggantikan alur normal permainan secara default.

### Backup sebelum perubahan
- `TeacherAI_New.gd.before_patrol_recovery_repair_20261011.bak`
- `Map58Game.gd.before_restore_normal_start_20261011.bak`

### Hasil yang diharapkan
- Gerakan kecil akibat collision tidak lagi mereset watchdog setiap frame.
- Guru mencoba menghindari penghalang sebelum melompat, lalu tidak terjebak selamanya pada satu waypoint.
- Kegagalan mencapai satu titik tidak menghentikan siklus patroli; titik tersebut dapat dicoba kembali pada siklus berikutnya.
- Pintu yang dipakai untuk transit tidak berulang kali dibuka-tutup oleh auto-close; pintu ruangan yang diperiksa tetap ditutup setelah guru keluar.
- Game kembali menggunakan alur startup normal secara default.

### Pengujian setelah perubahan
- Godot 4.7.2 headless memuat `main.tscn`, membangun navmesh **2.408 poligon**, dan keluar dengan kode **0** pada boot normal.
- Audit patroli 60 detik pada salah satu run mencapai `WayPoint_05` dan `WayPoint_02`, kemudian masuk ke state `CHOOSE_ROOM`, `MOVE_TO_DOOR`, `OPEN_DOOR`, `INVESTIGATE`, dan `EXIT_ROOM`. Satu waypoint yang terhambat dilewati setelah pemulihan gagal; AI tetap melanjutkan tujuan berikutnya.
- Audit patroli berikutnya selama 30 detik juga berakhir dengan kode **0**. Waypoint awal yang terhambat dilewati setelah lompatan pemulihan; durasi run tersebut terlalu singkat untuk mengonfirmasi waypoint berikutnya tercapai.
- Pemeriksaan `git diff --check` lulus. Pemindaian log boot tidak menemukan `SCRIPT ERROR`, `Parse Error`, atau `Failed to load script`.
- Peringatan pemulihan waypoint yang terhalang adalah log diagnostik yang disengaja, bukan parse error.

### Batasan yang masih perlu diuji
- Pengujian di atas adalah simulasi headless, bukan pengujian manual lengkap di editor/game. Jalur menuju waypoint tertentu masih dapat gagal karena konfigurasi navmesh, pintu, atau collision pada rute tersebut; perilaku aman saat ini adalah melanjutkan ke tujuan berikutnya, bukan diam selamanya.
- Pintu transit sengaja dibiarkan terbuka untuk menghindari siklus auto-close di ambang. Jika desain akhir mengharuskan semua pintu transit menutup, mekanisme itu perlu menggunakan deteksi lintasan melewati bidang pintu yang sesuai dengan orientasi tiap pintu, bukan jarak saja.
- Belum diklaim bahwa semua mode AI, seluruh ruangan, dan penangkapan pemain sudah lulus pengujian manual.


### Pemeriksaan tambahan setelah audit patroli
- `_audit_teacher_navpaths.gd` mengonfirmasi semua 5 waypoint memiliki path dari spawn pada navmesh; jarak endpoint navmesh ke marker sekitar **0,3 unit**. Panjang path yang dihitung berkisar **14,7–82,7 unit**. Jadi, bukti saat ini tidak menunjukkan marker waypoint berada jauh di luar navmesh.
- Pada pemeriksaan patroli terakhir 30 detik, guru mencoba mencapai waypoint pertama, watchdog melakukan satu lompatan, lalu berpindah ke waypoint berikutnya; proses berakhir dengan kode **0**. Run ini belum cukup lama untuk memastikan waypoint pengganti tercapai.
- Boot normal dan pemeriksaan whitespace lulus. Perubahan pada file aktif dibandingkan dengan backup sebelum perbaikan terbatas pada perbaikan AI yang tercatat di atas dan pengembalian flag debug startup ke nilai normal.


## Audit ulang AI Guru — pengujian patroli bersih (11 Oktober 2026)

### Temuan awal audit ulang
- Sebagian log patroli terdahulu menunjukkan guru kembali ke area spawn di tengah simulasi. Pemeriksaan menemukan bahwa harness audit lama baru mengubah `GameManager.phase` menjadi `HUNT` setelah 240 physics frame. Ini membuat fase startup dapat ikut berjalan sebelum simulasi AI dimulai, sehingga hasil tersebut tidak layak dipakai sendirian untuk menyimpulkan bahwa waypoint/patroli produksi rusak.
- Audit bersih menetapkan fase `HUNT` sebelum scene dimasukkan ke SceneTree. Dengan demikian, timer/cutscene fase intro tidak bercampur dengan pengujian patroli.

### Perubahan yang dibuat pada alat uji
1. **`_audit_teacher_patrol_long.gd`** — fase `HUNT` diatur sebelum `root.add_child(scene)`; komentar menjelaskan alasannya.
2. Backup alat uji sebelum edit: **`_audit_teacher_patrol_long.gd.before_phase_fix_20261011.bak`**.
3. **`_audit_teacher_patrol_60s_clean.gd`** dibuat sebagai audit 60 detik untuk mengukur pergantian dan pencapaian waypoint dalam satu run.
4. Log hasil disimpan di **`_teacher_patrol_final_clean_20261011.log`**, **`_teacher_patrol_60s_clean_baseline.log`**, dan **`_teacher_full_boot_check_20261011.log`**.

### Hasil audit bersih
- Godot 4.7.2 memuat scene dan membangun navmesh sebanyak **2.408 poligon**.
- Pada simulasi patroli bersih 60 detik, guru mencapai **4 waypoint berbeda** (`WayPoint_03`, `WayPoint_05`, `WayPoint_01`, `WayPoint_04`) dan kemudian memilih waypoint berikutnya. Exit code **0**.
- Pada run audit bersih 30 detik dengan seed/urutan acak lain, guru mencapai `WayPoint_04`, memilih `WayPoint_02`, dan masih bergerak menuju waypoint tersebut ketika simulasi selesai. Exit code **0**.
- Log memperlihatkan pintu yang menghalangi rute dibuka saat dibutuhkan, misalnya `PintuRuangGuru_East` dan pintu kelas pada rute. Tidak ada `SCRIPT ERROR`, `Parse Error`, atau `Failed to load script` pada run patroli ini.
- Hasil tersebut menunjukkan bahwa antrean waypoint acak saat ini dapat mengarahkan guru ke beberapa titik; satu run 30 detik tidak cukup untuk menilai seluruh siklus karena beberapa waypoint berjarak puluhan unit dari spawn.

### Keputusan perubahan kode gameplay
- **Tidak ada perubahan pada `TeacherAI_New.gd`, scene gameplay, atau logika mode dalam audit ini.** Setelah memperbaiki harness, belum ada bukti baru yang cukup untuk membenarkan perubahan perilaku AI lebih lanjut. Mengubah algoritma berdasarkan log yang terkontaminasi fase startup berisiko memperkenalkan regresi.
- Watchdog tetap menjadi fallback untuk rute yang macet; log lama menunjukkan waypoint yang gagal dapat dilewati setelah pemulihan. Pengujian bersih berikutnya perlu mencakup rute yang sengaja dihalangi furnitur serta semua mode (teacher/ghost/berserk/responding), bukan hanya patroli koridor.

### Hasil yang diharapkan saat game dijalankan normal
- Guru memulai alur permainan normal, lalu melakukan patroli menggunakan urutan waypoint yang diacak.
- Guru berusaha mencapai satu waypoint sebelum memilih titik berikutnya; dalam kondisi rute bersih, guru dapat mengunjungi beberapa lokasi berbeda dalam satu siklus.
- Jika sebuah rute terhalang, watchdog dapat mencoba pemulihan dan melanjutkan ke tujuan lain, sehingga AI tidak harus diam selamanya pada satu titik.
- Pintu yang memotong rute dibuka oleh AI; audit ini tidak membuktikan semua kombinasi pintu/furnitur atau semua mode telah lulus uji manual.

### Batasan
Audit ini dijalankan secara headless, bukan pengujian manual penuh dari sudut pandang pemain. Hasil positif tidak boleh ditafsirkan sebagai bukti bahwa semua interaksi AI dan cutscene telah sempurna. Pemeriksaan boot normal terpisah dilakukan pada `_teacher_full_boot_check_20261011.log`.


### Pemeriksaan tambahan fase HUNT
- Harness **`_audit_teacher_mode_short.gd`** juga diperbaiki agar menetapkan `phase=HUNT` sebelum scene masuk ke SceneTree; backup: **`_audit_teacher_mode_short.gd.before_phase_fix_20261011.bak`**.
- Run 12 detik pada mode `teacher` berakhir dengan exit code **0**. Guru bergerak terus menuju `WayPoint_04`, membuka `PintuRuangGuru_East` saat pintu berada pada rutenya, dan tidak mengalami reset posisi di tengah simulasi.
- Run ini hanya memvalidasi mode patroli dasar. Ghost, berserk, responding, penangkapan pemain, dan perpindahan ke ruang investigasi tetap memerlukan skenario uji terpisah.


## Iterasi audit lanjutan — diagnosis perpindahan posisi dan transisi state (11 Oktober 2026)

### Pemeriksaan koneksi dan kondisi kerja
- Desktop Commander perangkat `DESKTOP-QRVA3D9` merespons ping.
- Proyek aktif: `C:\Users\LENOVO\Documents\prototipe-1`.
- Branch: `integration/github-plus-local-20261009`.
- Working tree memiliki banyak perubahan staged/unstaged dan file untracked. Tidak ada reset, checkout destruktif, atau perubahan gameplay tambahan pada iterasi ini.

### Audit log lama
- Log `_teacher_patrol_long_verified_20261011.log`, `_teacher_patrol_cached_path_final_20261011.log`, dan `_teacher_patrol_reaudit_20261011.log` memuat perpindahan posisi yang besar antara sampel 5 detik. Posisi pada beberapa sampel kembali mendekati area spawn guru.
- Log tersebut belum mencatat semua perubahan posisi per-frame, sehingga penyebab perpindahan itu belum dapat dipastikan.
- Harness lama menjalankan fase HUNT, tetapi AI tetap dapat berganti dari PATROL ke MOVE_TO_DOOR/INVESTIGATE. Karena itu, label "patroli" pada pengujian tidak berarti AI selalu berada di state PATROL.

### Pengujian diagnostik baru
- Dibuat alat uji diagnostik tambahan: `_audit_teacher_teleport_diag_20261011.gd`.
- Log hasil: `_teacher_teleport_diag_20261011.log`.
- Perintah: Godot 4.7.2 console, `--headless --path <project> --script res://_audit_teacher_teleport_diag_20261011.gd`.
- Hasil aktual: exit code 0; scene utama dan navmesh 2.408 poligon berhasil dimuat/dibangun.
- Run terbaru mencatat state PATROL, MOVE_TO_DOOR, INVESTIGATE, lalu kembali ke PATROL. Ini membuktikan bahwa audit harus merekam state dan waypoint, bukan hanya posisi.
- Guru sempat tidak bergerak di sekitar `(-8.45, -0.00, -37.83)`, watchdog mencapai sekitar 5 detik dan memicu lompatan pemulihan. Pada akhir run guru kembali bergerak.
- Run baru tidak mereproduksi perpindahan posisi mendadak lebih dari 3 unit dalam satu physics frame. Dengan demikian, anomali pada log lama belum terjelaskan, bukan terbukti sebagai teleportasi gameplay.

### Keputusan iterasi awal
- Pada iterasi diagnosis awal belum ada perubahan gameplay; kemudian audit state machine menemukan bahwa timeout global dapat memutus state INVESTIGATE sebelum seluruh titik ruangan selesai dikunjungi. Perbaikan minimal untuk temuan itu dicatat pada bagian patch berikut.

### Status dan risiko
- Koneksi dan boot/headless diagnostic: lulus pada run ini.
- Konsistensi pencapaian semua waypoint: belum terverifikasi.
- Pemulihan dari furnitur/penghalang: terbukti terpicu, tetapi belum terbukti selalu menyelesaikan rute.
- Penyebab perpindahan posisi besar pada log lama: belum terverifikasi.
- Pengujian manual dalam game dan seluruh mode AI: belum selesai.


### Revalidasi boot normal setelah audit diagnostik
- Perintah: Godot 4.7.2 console `--headless --path C:\Users\LENOVO\Documents\prototipe-1 --quit-after 300`.
- Exit code aktual: **0**.
- Scene utama memuat collision map, spawner memvalidasi 346 titik dari 1.293 kandidat dan mengaktifkan 15 item, lalu NavigationBaker menyelesaikan navmesh 2.408 poligon.
- Pemindaian log boot ini tidak menemukan `SCRIPT ERROR`, `Parse Error`, `Failed to load script`, atau `ERROR:`.
- `git diff --check` juga exit code **0**. Peringatan normalisasi CRLF yang ditampilkan Git bukan error sintaks.


### Patch timeout investigasi — 2026-10-11
- File gameplay: `TeacherAI_New.gd`.
- Perubahan tepat: kondisi timeout umum di `_physics_process()` kini mengecualikan `State.INVESTIGATE` bersama `PATROL` dan `SEARCH`.
- Alasan: sebelumnya `_state_timer > state_timeout` memaksa state investigasi kembali ke PATROL setelah 25 detik, tanpa menunggu `_current_waypoint_index` selesai. Ini dapat menjelaskan guru membuka pintu, masuk sebentar, lalu pergi sebelum menyusuri semua titik ruangan.
- State investigasi sekarang selesai melalui alur normal `_on_investigate()` setelah waypoint habis. Timeout umum untuk state lain tidak diubah.
- Backup sebelum patch: `TeacherAI_New.gd.pre_investigation_timeout_patch_20261011.bak`.
- Validasi boot setelah patch: Godot headless exit code 0; belum ada error parse/script pada hasil yang diperiksa. `git diff --check` lulus.
- Validasi perilaku sesudah patch masih berjalan/harus diperiksa dari log `_teacher_patrol_postpatch_20261011.log`; belum mengklaim semua waypoint ruangan berhasil dicapai sampai hasil tersebut diverifikasi.

## 2026-10-11 — Fix penyeretan, animasi locomotion, dan pembukaan pintu

### Perubahan
- `PlayerAnimation.gd`: menambahkan pose `capture_dragging` dengan badan condong, tangan terangkat, dan gerakan kaki. Prioritasnya di atas pose tangkapan statis agar pemain tidak meluncur kaku saat dipindahkan.
- `TeacherAnimation.gd`: pose `capture_pose` tidak lagi menahan guru dalam pose statis ketika metadata `capture_dragging` aktif.
- `Map58Game.gd`: mengaktifkan/menonaktifkan metadata penyeretan pada pemain dan guru. Saat guru mengikuti pemain dengan `move_and_collide`, `velocity` sekarang diisi eksplisit karena `move_and_collide` tidak mengisinya; arah hadap guru juga mengikuti arah gerak.
- `Map58Game.gd`: jika penyeretan bertabrakan dengan collider milik pintu, guru memanggil `interact`, menunggu tween pintu selesai, lalu mencoba waypoint yang sama lagi. Collision fisika tetap aktif.
- `TeacherAI_New.gd`: deteksi pintu di rute tidak lagi bergantung hanya pada raycast yang mengenai daun pintu. Jika raycast meleset, sistem memeriksa pintu dalam koridor di depan berdasarkan jarak proyeksi dan offset lateral; jika raycast benar-benar mengenai collider pintu, orientasi basis model tidak lagi menolak deteksi itu.

### Backup
- `PlayerAnimation.gd.pre_drag_fix_20261011.bak`
- `TeacherAnimation.gd.pre_drag_fix_20261011.bak`
- `Map58Game.gd.pre_drag_fix_20261011.bak`
- `TeacherAI_New.gd.pre_path_door_fix_20261011.bak`

### Validasi
- Godot 4.7.2 headless boot test: exit code 0.
- Tidak ditemukan `SCRIPT ERROR`, `Parse Error`, `Parser Error`, atau `ERROR:` pada log boot terakhir.
- `git diff --check`: exit code 0.
- Belum diklaim sebagai validasi gameplay penuh; animasi dan interaksi pintu tetap perlu diuji langsung di scene berjalan.

### Follow-up verification
- Headless route diagnostic completed with exit code 0 in about 39 seconds.
- Teacher moved across multiple corridor waypoints during the 30-second sample.
- Door-opening log confirmed `PintuRuangGuru_East`, `PintuKelas_11_C_South`, and `PintuKelas_11_C_North` were opened while following the patrol route.
- This confirms patrol route movement and door detection in the diagnostic scene; it does not yet confirm the full player-capture/drag sequence in a live interactive session.
- Diagnostic output: `_teacher_ai_route_postfix_20261011.log`; boot/parse output: `_drag_path_door_validation_20261011.log`.

## 2026-10-11 � Langsung mulai mode hantu untuk pengujian
- `Map58Game.gd`: default `debug_start_in_ghost_mode` diubah dari `false` menjadi `true`, sehingga saat run `_ready()` memilih `_start_debug_ghost_test()` dan melewati ujian pembuka/cutscene.
- Mode awal: `PHASE_HUNT`, `teacher_mode=ghost`, guru ditempatkan pada `SpawnManager/TeacherSpawn` (Ruang Guru), intro dikunci dibuka dan kertas intro disembunyikan.
- Backup sebelum perubahan: `Map58Game.gd.pre_direct_ghost_start_20261011.bak`.
- Validasi: Godot 4.7.2 headless boot exit code 0; log mengonfirmasi `DEBUG AI: mulai di ruang guru | phase=HUNT | teacher_mode=ghost`; tidak ditemukan parse/script error pada log.
- Catatan: ini sengaja menjadi default pengujian sementara. Kembalikan `debug_start_in_ghost_mode` ke `false` untuk alur pembuka normal.

## 2026-10-11 — Perbaikan collision/path saat guru menyeret player
- Penyebab yang ditemukan: selama capture, player bergerak lewat waypoint secara independen, sementara guru hanya memakai langkah langsung ke posisi player dan hasil `move_and_collide()` diabaikan. Akibatnya guru bisa tertahan di tembok/furnitur sementara player tetap terseret.
- `Map58Game.gd`: guru sekarang bergerak menggunakan `NavigationAgent3D` menuju titik trailing di belakang player; hasil collision guru diperiksa; pintu yang terdeteksi diminta terbuka; player ditahan sementara jika guru terhalang dan jarak horizontal mereka sudah melewati ambang aman.
- Backup sebelum perubahan: `Map58Game.gd.pre_capture_collision_nav_fix_20261011.bak`.
- Validasi: Godot 4.7.2 headless boot exit code 0; log `_capture_collision_nav_test_20261011.log`; tidak ditemukan parse/script error.
- Batas validasi: boot/parse telah lolos, tetapi capture langsung di gameplay masih harus diuji untuk memastikan rute di sudut furnitur dan pintu benar-benar mulus.

## 2026-10-11 — Perbaikan penyeretan ke sofa, ujian hukuman, dan pemulihan mode guru

### Perubahan
- `Map58Game.gd`: kecepatan penyeretan player dinaikkan dari 2.0 menjadi 5.2 unit/detik; kecepatan guru mengikuti player dinaikkan dari 2.25 menjadi 6.2 unit/detik.
- `Map58Game.gd`: guru tetap memakai `NavigationAgent3D` dan `move_and_slide()` selama capture. Pemeriksaan menemukan kondisi lama menahan player setiap kali guru menyentuh collision saat jarak mereka melebihi 1.65 unit. Kontak samping dengan furnitur dapat terus mengaktifkan kondisi itu, sehingga setiap waypoint habis timeout. Kondisi yang membekukan player dihapus; player tetap mengikuti waypoint dan collision sendiri, sedangkan guru melanjutkan navigasi/slide.
- `TeacherAI_New.gd`: saat metadata `capture_dragging` aktif, AI tidak menjalankan `_stop()` pada fase `TRANSITION`. Perpindahan fisik tetap dikendalikan `Map58Game.gd`, tetapi `velocity` guru dipertahankan untuk dibaca `TeacherAnimation.gd`, sehingga siklus locomotion tidak langsung mati.
- `Map58Game.gd`: setelah sampai di ruang tamu, player ditempatkan pada dudukan `Sofa_03Seat`, `intro_sitting` diaktifkan, input dikunci, dan tinggi kamera diatur seperti pose duduk ujian pembuka. Ini memakai pose duduk yang sudah ada di `PlayerAnimation.gd`, bukan membuat sistem pose duplikat.
- Ujian hukuman memakai kembali sistem `PENALTY_EXAM` yang sudah ada: label soal, input angka, pergantian indeks, dan lima jawaban. Alur tersebut kini dimulai setelah penyeretan/penempatan player di sofa.
- Mode guru sebelum capture disimpan. Jika capture terjadi saat `RESPONDING`, mode dasar yang disimpan adalah `mode_before_responding`; target `BERSERK` juga disimpan untuk dipulihkan ketika player hidup kembali. State pengejaran lama dibersihkan setelah capture, dan `revive_player()` mengembalikan mode tersimpan, bukan selalu memaksa `GHOST`.
- Saat lima jawaban selesai, alur KO/medkit yang sudah ada tetap berlaku. Pose duduk dan kunci kontrol dibersihkan saat revive.

### Backup
- `Map58Game.gd.pre_capture_speed_seating_mode_fix_20261011.bak`
- `TeacherAI_New.gd.pre_capture_speed_seating_mode_fix_20261011.bak`

### Validasi
- Godot 4.7.2 headless boot: exit code 0; pemindaian log tidak menemukan `SCRIPT ERROR`, `Parse Error`, `Parser Error`, `Failed to load script`, atau `ERROR:`.
- Audit capture terotomasi pada scene `main.tscn`: exit code 0. Navmesh selesai dibangun dengan 2.408 poligon. Player berpindah sekitar 40.5 unit dalam 12.1 detik pada seed/spawn audit tersebut, mencapai area sofa (jarak ke origin sofa sekitar 0.49 unit karena offset dudukan), masuk ke `PENALTY_EXAM`, mengaktifkan `intro_sitting=true` dan `intro_locked=true`.
- Label ujian terdeteksi menampilkan `SOAL HUKUMAN 1/5` dan pertanyaan aktif. Lima jawaban uji memajukan indeks sampai 5 dan masuk ke fase KO. Mode guru pada akhir uji satu pemain menjadi `teacher` sesuai cabang game-over/KO yang aktif pada harness tersebut.
- Pada audit locomotion sebelumnya, guru berpindah sekitar 53.1 unit saat penyeretan dan velocity sampel horizontalnya nonzero. Headless test tidak dapat memastikan kualitas visual animasi seperti yang dilihat pemain; animasi visual masih perlu dicek di F5.
- `git diff --check`: exit code 0; hanya peringatan normalisasi CRLF Git.

### Batasan
- Audit ini menjalankan simulasi terotomasi headless, bukan pengujian visual manual dari sudut pandang pemain. Sofa/pose duduk, sudut kamera, animasi kaki guru, dan perilaku pada variasi rute/furnitur masih perlu dikonfirmasi di editor dengan F5.
- Mode pemulihan diuji melalui alur capture dan cabang KO; seluruh kombinasi `teacher`, `ghost`, `berserk`, dan `responding` belum diuji satu per satu.

## 2026-10-11 — Percepatan siklus animasi guru saat menyeret
- `TeacherAnimation.gd`: `walk_cycle_speed` dinaikkan dari 7.0 menjadi 10.5 dan `chase_cycle_speed` dari 11.0 menjadi 16.0.
- Animasi kini memilih cadence kejar ketika metadata `capture_dragging` aktif, meskipun kecepatan fisik guru berada di bawah ambang 8 unit/detik yang dipakai oleh pengecekan kejar normal. Ini memperbaiki ketidaksesuaian antara kecepatan gerak capture dan kecepatan siklus kaki/tangan.
- Backup: `TeacherAnimation.gd.pre_fast_capture_animation_20261011.bak`.
- Validasi Godot 4.7.2 headless exit code 0, error scan bersih, dan `git diff --check` exit code 0.
- Batasan: validasi ini memeriksa script/boot, bukan visualisasi langsung; cadence baru perlu dikonfirmasi dengan F5.

## 2026-10-11 — Percepatan gerak fisik saat menyeret pemain
- Klarifikasi pengguna: yang terasa lambat adalah kecepatan guru berjalan sambil menyeret pemain, bukan sekadar cadence animasi.
- `Map58Game.gd` fungsi `_move_captured_player_to()`: kecepatan gerak player dinaikkan dari 5.2 menjadi 8.0 unit/detik; kecepatan guru mengikuti dinaikkan dari 6.2 menjadi 9.0 unit/detik.
- Backup sebelum perubahan: `Map58Game.gd.pre_capture_walk_speed_20261011.bak`.
- Validasi Godot 4.7.2 headless editor boot: exit code 0; pemindaian log tidak menemukan `SCRIPT ERROR`, `Parse Error`, `Parser Error`, `Failed to load script`, atau `ERROR:`.
- Batasan: belum memverifikasi visual/feel gerakan secara langsung di F5; perlu cek apakah gerak cepat tetap stabil saat berbelok, melewati pintu, dan bersinggungan dengan furnitur.

## 2026-10-11 — Soal hukuman tetap tampil saat AI guru aktif
- `TeacherAI_New.gd`: AI tidak lagi berhenti total pada fase `PENALTY_EXAM` dan `KO`; AI tetap berhenti untuk briefing/ujian pembuka/transisi/akhir game. Mode guru yang sudah dipulihkan saat masuk ujian hukuman kini bisa menjalankan navigasi/patroli.
- `TeacherAI_New.gd`: tambah `_is_forbidden_player_target()` untuk menolak target yang KO, sedang diseret/animasi capture, atau merupakan `penalty_player`. Pengecekan dipakai untuk target paksa (`berserk`/`responding`), target ghost yang sedang diikuti, dan pencarian target baru.
- `Map58Game.gd`: saat memasuki ujian hukuman, pertahankan target berserk lama hanya bila target itu murid lain yang masih aktif; murid yang baru ditangkap tidak menjadi target.
- `Map58Game.gd`: ketika murid yang menjalani hukuman berhasil dihidupkan, bersihkan referensi `penalty_player` agar setelah revive ia dapat kembali menjadi target yang sah bila mode AI mengizinkan.
- Backup: `Map58Game.gd.pre_teacher_free_during_penalty_20261011.bak`, `TeacherAI_New.gd.pre_teacher_free_during_penalty_20261011.bak`.
- Validasi Godot 4.7.2 headless editor boot exit code 0, error scan tidak menemukan `SCRIPT ERROR`, `Parse Error`, `Parser Error`, `Failed to load script`, atau `ERROR:`; `git diff --check` exit code 0 (peringatan CRLF normal).
- Batasan: belum menjalankan sesi visual interaktif untuk mengamati guru berpatroli sambil soal tampil; validasi ini memastikan script dapat dimuat, bukan kualitas gerak runtime.


## 2026-10-11 — Bot pemain untuk uji target multi-pemain lokal

- Menambahkan BotPlayer.gd dan BotPlayer.tscn. Bot memakai visual karakter murid yang sudah ada, collision capsule, NavigationAgent3D, animasi karakter, dan ItemInventory; otomatis masuk grup players sehingga AI guru dapat memperlakukannya sebagai kandidat target kedua.
- Memperbarui Map58_SpawnManager.gd: opsi enable_test_bot aktif secara default, bot ditempatkan di titik kelas yang paling jauh dari spawn pemain manusia, lalu bergerak otomatis menuju titik spawn kelas lain melalui NavigationAgent.
- Bot berhenti saat metadata intro_locked, capture_animation, capture_dragging, atau knocked_out aktif. Pengaturan dapat dimatikan melalui Inspector pada SpawnManager.enable_test_bot.
- Backup sebelum edit: Map58_SpawnManager.gd.before_test_bot_20261011.bak.
- Validasi: Godot 4.7.2 headless editor scan berhasil; menjalankan main scene headless selama 240 frame keluar dengan kode 0 dan log mengonfirmasi spawn pemain serta bot (BotPlayer: aktif sebagai target uji multiplayer lokal.). Scan log tidak menemukan SCRIPT ERROR, Parse Error, Parser Error, Failed to load script, atau ERROR:.
- Batas validasi: belum dilakukan uji visual manual, belum membuktikan bot selalu berhasil menavigasi semua ruangan/navmesh, dan belum menguji sesi jaringan multiplayer sungguhan. Ini bot simulasi lokal untuk menguji logika beberapa pemain dalam satu instance, bukan implementasi client-server/network replication.


## 2026-10-11 — Perbaikan visibilitas soal hukuman

- Memperkuat UI fase PENALTY_EXAM di Map58Game.gd dengan CanvasLayer terpisah (layer 60), panel kontras di tengah layar, label soal bernomor, dan petunjuk input jawaban. UI hanya ditampilkan saat phase == PHASE_PENALTY_EXAM.
- Saat fase penalti aktif, label HUD generik disembunyikan supaya tidak bertumpuk; jawaban angka tetap memakai input keyboard yang sudah ada (ketik angka, Enter), dan isinya dicerminkan ke panel baru.
- Validasi Godot 4.7.2 headless editor scan selesai tanpa pesan parser/script error yang cocok dengan pola scan. Uji visual manual masih diperlukan untuk memastikan tata letak pada resolusi game pengguna.

## 2026-10-11 � Kunci posisi pemain saat KO
- `Map58Game.gd`: saat pemain ditetapkan KO, simpan `knocked_out_position`; saat revive, hapus metadata tersebut.
- `Player.gd`: saat KO, paksa posisi kembali ke titik KO dan nolkan velocity setiap physics tick; abaikan input mouse agar arah pandang juga tidak berubah saat KO.
- `BotPlayer.gd`: terapkan penguncian posisi yang sama pada bot uji KO.
- Backup sebelum perubahan: `Player.gd.pre_ko_anchor_20261011.bak`, `BotPlayer.gd.pre_ko_anchor_20261011.bak`, `Map58Game.gd.pre_ko_anchor_20261011.bak`.
- Validasi parser/runtime dilakukan setelah edit; pengujian visual manual masih diperlukan untuk memastikan tak ada skrip eksternal lain yang memindahkan node.


## 2026-10-11 — Gerakan merangkak saat KO

- `Player.gd`: mengganti penguncian posisi KO dengan gerakan merangkak pelan (1.55 unit/detik) menggunakan WASD, tetap memakai `move_and_slide()` agar collision dengan dinding/furnitur tetap berlaku, menerapkan gravitasi, dan menurunkan posisi kamera mendekati lantai.
- `PlayerAnimation.gd`: pose KO tetap rebah; saat kecepatan horizontal terdeteksi, lengan dan kaki bergerak bergantian agar terlihat merangkak, bukan meluncur kaku.
- Kondisi `capture_animation`, `capture_dragging`, dan `intro_locked` tetap menghentikan input gerak untuk menjaga cutscene/adegan yang memang terkunci.
- Backup sebelum edit: `Player.gd.pre_ko_crawl_20261011.bak`, `PlayerAnimation.gd.pre_ko_crawl_20261011.bak`.
- Validasi parser/runtime dilakukan setelah perubahan; perlu uji manual F5 untuk memastikan feel merangkak, collision, dan pemulihan kamera setelah revive.

## 2026-10-11 — Perbaikan POV jongkok/KO dan soal hukuman

- `Player.gd`: seluruh `VisualInstance3D` di `PlayerCharacter/world` dipindah ke Visual Layer 2, yang sudah dikecualikan oleh `FirstPersonLocalHeadCulling.gd`. Ini menyembunyikan tubuh lokal dari kamera POV saat jongkok/KO tanpa mematikan model untuk kamera pemain lain.
- `Map58Game.gd`: alur jawaban ruang hukuman dipisahkan secara eksplisit; jawaban benar maupun salah menaikkan indeks, memilih soal baru melalui QuestionDatabase, mengosongkan input, lalu menyegarkan UI langsung. Jawaban salah tetap mengurangi skor dan menampilkan kunci jawaban sebelumnya.
- UI ruang hukuman tidak lagi menampilkan jumlah maksimum/jumlah soal, baik pada judul maupun di atas pertanyaan. Jumlah internal penalti tetap 5 soal; hanya indikator hitungannya yang disembunyikan.
- Backup sebelum edit: `Player.gd.pre_pov_penalty_fix_20261011.bak`, `Map58Game.gd.pre_pov_penalty_fix_20261011.bak`, `PlayerAnimation.gd.pre_pov_penalty_fix_20261011.bak`.
- Validasi parser dan runtime scene dijalankan setelah edit; uji visual POV dan pengiriman jawaban tetap perlu dikonfirmasi manual.

## 2026-10-11 — Integrasi audio interaksi dan horor

- Membuat `assets/audio/{footsteps,teacher,doors,furniture}` dan mengunduh sembilan file audio OGG dari halaman Freesound berlisensi CC0; sumber dan kreator dicatat dalam `AUDIO_CREDITS.md`.
- `AudioManager.gd`: mendaftarkan aset langkah kaki, bisikan hantu, jumpscare, pintu, kunci, laci, kursi, dan lemari; menambah pool audio 3D khusus furnitur; menurunkan volume jumpscare/bisikan; audio tetap opsional jika file tidak tersedia.
- `Map58Game.gd`: memicu jumpscare saat penangkapan dimulai.
- `GameAudioManager.gd`: memicu bisikan sekali saat guru mendekat (ambang 8 m, reset setelah lebih dari 11 m), agar tidak berulang tiap frame.
- `TeacherAI_New.gd`: langkah guru diarahkan ke pool spasial dan bisikan diputar saat mode ghost; tidak mengaitkan suara penggaris ke perilaku agresif.
- `PintuKelas.gd`, `PintuKayu.gd`, `PintuSekolah.gd`, `PintuTengahKepsekGuru.gd`: suara buka/tutup memakai posisi pintu; `PintuKelas.gd` juga memainkan suara kunci saat murid yang memiliki item kunci membuka pintu terkunci.
- `Map58TeacherDeskInteraction.gd`, `LibraryDrawerInteract.gd`, `Map58CabinetInteractive.gd`, `Map58ClassroomCupboard.gd`, dan `Map58RackStorage.gd`: menghubungkan suara laci/lemari/rak ke interaksi yang sudah ada; memperbaiki argumen posisi pada pemanggilan suara rak.
- Pixabay menolak unduhan langsung dari komputer proyek (HTTP 403), sehingga dua audio yang dipilih persis tidak berhasil diambil. Untuk menjaga integrasi, digunakan alternatif CC0 dari Freesound: `qubodup` untuk jumpscare dan `brktkrgll` untuk bisikan. Detailnya ada di `AUDIO_CREDITS.md`.
- Audio kursi sudah diunduh, tetapi belum dipicu karena kursi saat ini tidak memiliki aksi geser yang bisa dimainkan. Efek penggaris tidak diintegrasikan ke aksi agresif.
- Validasi Godot 4.7.2: editor headless scan dan main-scene runtime (`--quit-after 180`) selesai dengan exit code 0; scan tidak menemukan `SCRIPT ERROR`, `Parse Error`, `Parser Error`, `Failed to load script`, atau `ERROR:`. `git diff --check` exit code 0. Belum ada pengujian audio secara langsung di sesi F5.


## 2026-10-11 — Bot tertangkap tidak boleh menghukum pemain manusia

- Akar masalah: `BotPlayer.gd` menambahkan bot ke grup `players`; `TeacherAI_New.gd::_capture_target()` mengirim target apa pun ke `Map58Game.player_caught()`, yang sebelumnya memulai adegan penangkapan dan ujian hukuman tanpa membedakan bot dari pemain manusia.
- Perbaikan di `Map58Game.gd::player_caught()`: jika target memiliki metadata `is_test_bot`, tandai bot `knocked_out` dan simpan posisi tumbangnya lalu keluar dari fungsi. Ini menghentikan gerak bot dan membuat AI mengabaikannya, tanpa memulai cutscene penangkapan, penalti, atau perubahan fase/UI pemain manusia.
- Validasi Godot 4.7.2: editor headless scan exit code 0; main scene runtime `--quit-after 180` exit code 0; scan log tidak menemukan pola error script/parser; `git diff --check` exit code 0.
- Belum dilakukan uji interaksi manual F5 untuk menyaksikan bot tertangkap di game langsung.


## 2026-10-11 — Hukuman soal individual, bukan fase global

- `Map58Game.gd`: menambahkan `_penalty_exam_active` sebagai status UI/input milik murid yang tertangkap; saat penangkapan selesai, game tetap berada di fase gameplay yang berjalan, bukan mengubah seluruh game ke `PHASE_PENALTY_EXAM`.
- Input angka dan pemrosesan jawaban hukuman kini memeriksa status penalti aktif; UI hukuman tampil berdasarkan status tersebut meskipun fase global tetap `HUNT`.
- Setelah 5 soal, hanya `penalty_player` yang ditandai KO. Status penalti dibersihkan dan fase global tidak dipaksa menjadi `PHASE_KO`, sehingga murid lain dan timer AI dapat berlanjut.
- Pemeriksaan kondisi kalah mengecualikan `is_test_bot` agar bot uji yang KO tidak dihitung sebagai murid manusia yang semuanya KO.
- Jika murid lain tertangkap saat satu ujian hukuman sedang aktif, callback ditahan agar tidak menimpa UI/soal murid pertama; guru dapat mencoba menangkapnya lagi setelah penalti aktif selesai.
- Backup sebelum edit: `Map58Game.gd.pre_individual_penalty_20261011.bak`.
- Validasi Godot 4.7.2 editor headless dan runtime main scene lulus (exit code 0); runtime log bersih dari pola error script/parser. Belum diuji manual melalui F5 untuk memverifikasi alur penangkapan dan jawaban secara visual.

## 2026-10-11 — Menghapus bot pemain uji

- Menghapus pemanggilan spawn bot serta ekspor `enable_test_bot`/`test_bot_scene` dari `Map58_SpawnManager.gd`; spawn murid manusia dan spawn guru tetap dipertahankan.
- Menghapus `BotPlayer.gd` dan `BotPlayer.tscn` karena sudah tidak digunakan.
- Menghapus penanganan khusus `is_test_bot` di `Map58Game.gd`; pengecekan seluruh pemain KO kembali memeriksa semua anggota grup `players`.
- Backup sebelum perubahan: `Map58_SpawnManager.gd.pre_remove_bot_20261011.bak`, `Map58Game.gd.pre_remove_bot_20261011.bak`, `PROGRAMMING_AUDIT_20261011.md.pre_remove_bot_20261011.bak`.
- Validasi parser/runtime dilakukan setelah perubahan; lihat hasil pemeriksaan di percakapan ini.
## 2026-10-11 � HUD cleanup sesuai arahan pengguna

- `items/ItemInventory.gd`: kapasitas inventori gameplay diubah dari 5 menjadi 2 slot; UI slot ikut memakai konstanta kapasitas yang sama. Pesan inventori penuh disesuaikan menjadi 2/2.
- `UIManager.gd`: label fase, skor saat bermain, objective, timer, dan proximity guru tidak lagi ditampilkan. Skor tetap ada di panel hasil akhir.
- `UIManager.gd`: stamina bar kanan atas dinonaktifkan agar tidak duplikat; indikator stamina tunggal berada di HUD Player dan hanya tampil ketika benar-benar berlari.
- `UIManager.gd`: ditambahkan radar/minimap sederhana dengan titik hijau pemain di tengah dan titik merah guru relatif terhadap posisi pemain. Ini adalah radar arah/jarak relatif, belum peta denah ruangan.
- `Map58Game.gd`: label fase/skor, objective, dan waktu dari HUD lama disembunyikan agar tidak bertumpuk dengan UI baru; panel ujian/hasil akhir tidak dihapus.
- `Player.gd`: stamina HUD disembunyikan saat tidak berlari dan saat KO/intro terkunci.
- Backup: `UIManager.gd.pre_hud_cleanup_20261011.bak`, `Player.gd.pre_hud_cleanup_20261011.bak`, `items/ItemInventory.gd.pre_hud_cleanup_20261011.bak`, `Map58Game.gd.pre_hud_cleanup_20261011.bak`, `PROGRAMMING_AUDIT_20261011.md.pre_hud_cleanup_20261011.bak`.
- Validasi: Godot 4.7.2 headless editor scan dan main scene `--quit-after 180` berhasil exit code 0 tanpa parse/script error pada output yang diperiksa. `git diff --check` tidak melaporkan whitespace error; hanya peringatan normalisasi CRLF.
- Batasan: belum dilakukan uji visual manual F5. Minimap ini masih radar relatif, bukan denah bangunan dengan bentuk ruang/dinding. Kontrol joystick/tombol mobile sengaja tidak dibuat sesuai arahan.


## 2026-10-11 — Debug HUD dan minimap denah 2D

- UIManager.gd: placeholder radar titik diganti widget Minimap2D.gd.
- Minimap2D.gd: menggambar polygon walkable dari NavigationRegion3D.navigation_mesh ke tampilan top-down; pemain hijau dan guru merah dipetakan ke koordinat dunia yang sama. Geometri cache dibangun ulang jika jumlah vertex/polygon navmesh berubah.
- Map58Game.gd: mode uji debug_start_in_ghost_mode default dimatikan agar alur normal ujian/cutscene tidak dilewati; teks dan log eksplisit DEBUG AI dihapus.
- Backup sebelum perubahan tersedia dengan akhiran .pre_minimap2d_20261011.bak.
- Perlu validasi headless; belum ada uji visual manual.


## 2026-10-11 — Gaya denah minimap mengikuti referensi

- Minimap2D.gd: lantai cokelat, latar cokelat gelap, tepi area navigasi terang. Edge dihitung berdasarkan frekuensi kemunculan untuk menyembunyikan garis triangulasi internal dan menampilkan batas luar area yang bisa dilalui.
- UIManager.gd: panel denah dibuat sedikit lebih lebar mengikuti referensi pengguna.
- Backup: akhiran .pre_floorplan_style_20261011.bak.
- Validasi parser/runtime headless dilakukan setelah patch; pengujian visual F5 masih diperlukan untuk menilai kemiripan dan keterbacaan aktual.

## 2026-10-11 � Pulihkan alur pembuka dan cutscene

- `Map58Game.gd`: jalur uji `_start_debug_ghost_test()` dan export `debug_start_in_ghost_mode` dihapus agar permainan tidak bisa melewati briefing, ujian awal, dan cutscene lewat opsi debug.
- Saat `auto_start` aktif, game sekarang selalu memanggil `_start_game()`; alur normal: briefing 5 detik ? ujian 5 soal selama 20 detik ? cutscene guru meninggalkan kelas ? fase berburu.
- Backup sebelum perubahan: `Map58Game.gd.pre_restore_intro_cutscene_20261011.bak`.
- Validasi headless dicatat setelah perubahan; uji visual manual F5 belum dilakukan.


## 2026-10-11 — Perbaikan freeze minimap

- Minimap2D.gd: menghindari menggambar ribuan polygon lantai tiap refresh; lantai kini satu rectangle, geometri batas navigasi dibuat sekali/cache, dan redraw marker dibatasi maksimal sekitar 4 kali/detik hanya saat posisi marker berubah.
- Ukuran kontrol yang berubah memicu rebuild peta; perubahan posisi pemain/guru tidak membangun ulang geometri.
- Backup: .pre_minimap_freeze_fix_20261011.bak.


## Perubahan peti gudang dan interaksi rak — 2026-10-11

- Menghapus pemasangan interaksi Map58RackStorage dari Map58FurnitureGameplay.gd; rak Rack_* tidak lagi diberi interaksi runtime oleh gameplay layer. Script lama Map58RackStorage.gd dibiarkan sebagai file tidak terpakai agar tidak menghapus aset/kode secara permanen tanpa kebutuhan.
- Menambahkan Map58CrateHiding.gd dan memasangnya hanya ke node LargeStorageCrate.
- Mengubah _build_warehouse.gd agar peti besar memiliki badan terbuka, tutup terpisah berengsel (LidPivot), dan collision per sisi sehingga ruang dalamnya tidak menjadi satu collision solid.
- Interaksi peti memakai kontrak yang sudah ada di PlayerInteractionInput.gd: klik kanan memanggil toggle_hide(player), klik kanan saat tersembunyi memanggilnya lagi untuk keluar.
- Animasi tutup: tween buka sebelum pemain masuk/keluar dan tween tutup setelahnya. Kamera dan transform pemain dipulihkan saat keluar; mesh pemain disembunyikan selama berada di dalam.
- Backup sebelum perubahan: Map58FurnitureGameplay.gd.pre_crate_hide_20261011.bak, _build_warehouse.gd.pre_crate_hide_20261011.bak, Warehouse_Furniture.tscn.pre_crate_hide_20261011.bak.
- Validasi: generator scene selesai menyimpan (ResourceSaver.save = 0), Godot headless editor scan tidak melaporkan error script, runtime scene headless keluar dengan kode 0, git diff --check kode 0. Generator lama masih mengeluarkan warning set_owner pada root scene; scene tetap tersimpan. Belum dilakukan uji visual/interaksi manual melalui F5, sehingga posisi dan timing animasi tetap perlu dikonfirmasi di game.

## 2026-10-11 — Penyelesaian interaksi peti gudang dan celah pandang

- `Warehouse_Furniture.tscn`: mempertahankan seluruh 24 node rak; tidak menjalankan ulang `_build_warehouse.gd`. Model peti besar diubah dari satu mesh solid menjadi lantai dan empat sisi terbuka di bagian atas, dengan `LidPivot` serta mesh tutup yang bergerak bersama engsel.
- Collision peti disusun per sisi dan lantai; collision solid lama dinonaktifkan agar pemain tidak terhalang masuk ke volume peti. Panel tutup tidak memiliki collision fisik terpisah.
- `Map58CrateHiding.gd`: klik kanan membuka tutup, memindahkan pemain ke bagian dalam, menyembunyikan mesh pemain, menutup tutup dengan sudut kecil positif (celah di tepi depan), dan mengembalikan posisi/kamera/collision/visibilitas ketika keluar. Kamera diarahkan ke celah dan mouse-look dikunci saat tersembunyi.
- `Player.gd`: input mouse-look diabaikan ketika metadata `is_hidden` aktif; setelah keluar, input kembali normal.
- Interaksi rak tetap tidak dipasang. `Map58FurnitureGameplay.gd` hanya menambahkan `Map58CrateHiding` ke `LargeStorageCrate`.
- Backup sebelum perubahan: `Warehouse_Furniture.tscn.pre_crate_animation_20261011.bak`, `Map58CrateHiding.gd.pre_crate_animation_20261011.bak`, `Player.gd.pre_crate_hiding_20261011.bak`.
- Validasi: Godot 4.7.2 headless editor scan exit code 0; main-scene runtime headless exit code 0; log editor tidak berisi pola `SCRIPT ERROR`, `Parse Error`, `Parser Error`, `Failed to load script`, atau `ERROR:`; `git diff --check` exit code 0. Pemeriksaan struktur mengonfirmasi 24 rak, satu `LidPivot`, dan blok resource scene berada sebelum node root. Harness Godot `--script res://_test_crate_hiding.gd` juga lulus: scene dimuat, interaksi peti terpasang, animasi mencapai sudut celah, lalu keluar memulihkan mesh, collision, posisi, dan kamera.
- Batasan: belum dilakukan uji visual F5/manual. Bentuk celah, garis pandang kamera, timing animasi, dan kenyamanan masuk/keluar masih perlu dikonfirmasi secara visual dalam game.
## 2026-10-11 — Pulihkan kunci pintu kelas

- `Map58_Furniture.tscn`: memulihkan `required_item_type = "class_key"` pada `PintuKelas_12_D_South` dan `PintuKelas_12_D_North`, yang sebelumnya hilang dari scene aktif. Tidak mengubah posisi pintu, ukuran geser, maupun pintu lain.
- `PintuKelas.gd` sudah memiliki pemeriksaan inventory: murid tanpa `class_key` ditolak dan menerima status pintu terkunci; guru tetap diizinkan membuka pintu terkunci untuk patrol AI.
- Validasi Godot headless: main scene runtime exit 0; tes khusus `res://_test_locked_doors_restore.gd` lulus untuk kedua pintu (terkunci, `class_key` dibutuhkan, interaksi tanpa kunci tidak membuka daun pintu).
- Catatan tes: saat harness tes memuat main scene, log juga mencetak error `Map58Game: tidak menemukan kelas spawn player`; itu berasal dari startup/cutscene dalam konteks headless test, bukan kegagalan assertions kunci pintu. Belum ada uji visual F5.