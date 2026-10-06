# KELAS MALAM — AI COUNCIL

Dokumen ini adalah **arsip sidang permanen project**. Ini menjadi sumber kebenaran bersama untuk Susanto, Yanto, dan Tono.

## Protokol Sidang

1. Baca file ini sebelum memberi keputusan teknis besar.
2. Jangan menganggap percakapan AI lain otomatis terbaca; konteks antar-chat tidak tersambung dengan sendirinya.
3. Setelah keputusan penting, tambahkan ringkasan keputusan ke file ini.
4. Jangan mengubah Map58 geometry/floorplan, position, atau collision kecuali user secara eksplisit meminta.
5. Sebelum perubahan project: inspeksi file aktual, ubah sekecil mungkin, lalu validasi.
6. Jika ada perbedaan antara ingatan percakapan dan file project, **file aktual adalah acuan**.

---

## Anggota

- **SUSANTO** — ChatGPT / penjaga project.
- **YANTO** — ChatGPT Vqiss / partner project.
- **TONO** — Claude / partner project.

Tujuan: bekerja sebagai satu tim pada project **Kelas Malam**, dengan pembagian sudut pandang tetapi satu sumber kebenaran project.

---

# 1. Proposal Game — Baseline

## Judul
**Kelas Malam**

## Konsep
Game horror/co-op berlatar sekolah pada malam hari. Target pemain **1–4 orang**.

Pemain mengeksplorasi sekolah, mencari dan menggunakan item, membuka akses dengan kunci, mengerjakan soal, menghadapi guru sebagai ancaman, bekerja sama, lalu mencari jalan keluar.

## Gameplay inti
- Eksplorasi sekolah malam hari.
- Mencari dan mengambil item.
- Inventory terbatas.
- Membuka area dengan kunci yang sesuai.
- Mengumpulkan **10 kertas soal**.
- Berinteraksi dengan papan tulis / sistem soal.
- Guru menjadi ancaman dengan beberapa state.
- Kerja sama pemain diperlukan untuk bertahan dan menyelesaikan tujuan.
- Target multiplayer nyata: **1–4 pemain**.
- Sistem mic/speaker diperlukan untuk komunikasi suara.

## Item utama
- Kertas soal.
- Kapur.
- Kunci kelas.
- Kunci merah.
- Kunci biru.
- Kunci kuning.
- Medkit.

## Guru
State utama yang sudah dirancang:
- TEACHER
- GHOST
- BERSERK
- RESPONDING

Aturan penting:
- Jawaban salah dapat memicu BERSERK selama 15 detik.
- Jawaban benar dapat membuat guru tenang selama sekitar 3 menit.
- Saat pemain tertangkap, ada **5 pertanyaan hukuman**.

## KO / Medkit — Keputusan Terbaru
Jika pemain keluar dari **ruang kepala sekolah** dalam kondisi KO, pemain berada di **RUANG TAMU**.

Pemain lain harus menggunakan **medkit** untuk membantu revive.

Ini dimaksudkan sebagai mekanik kerja sama, bukan auto-respawn biasa.

## Pintu / akses
- Guru perlu dapat membuka dan menutup pintu.
- Sistem pintu dan akses area harus mengikuti struktur map yang sudah ada.

---

# 2. Kondisi Project yang Sudah Diketahui

Audit sebelumnya menunjukkan project sudah memiliki sebagian besar fondasi berikut:

- Map/school sudah tersedia dan sebagian besar selesai.
- Teacher.tscn dan TeacherAI.gd tersedia.
- Sistem pickup/inventory sudah ada dengan 2 slot.
- Sistem held item / first-person view model sudah ada.
- Item-item utama sudah tersedia.
- Map58ItemSpawner.gd digunakan untuk penyebaran item pada permukaan furniture.
- Target 10 exam papers dan batas aktif sekitar 5 item sudah ada di sistem terkait.
- Blackboard / exam system tersedia.
- State guru sudah tersedia.
- KO logic, revive_player(), dan konsumsi medkit sudah ada, tetapi revive teammate bergantung pada multiplayer nyata.
- School gate unlock dan animasi school door tersedia.
- Player animation, footstep/door/teacher audio sudah memiliki fondasi.
- Voice chat mic/speaker belum selesai.
- Multiplayer nyata 1–4 belum selesai.
- Integrasi KO ke RUANG TAMU perlu divalidasi pada scene aktual.
- GuestRoom_Furniture.tscn tersedia.

**Catatan:** daftar ini adalah baseline audit, bukan alasan untuk mengubah file tanpa inspeksi aktual.

---

# 3. Masalah / Pekerjaan yang Pernah Dicatat

1. Item belum sepenuhnya tersebar sesuai kebutuhan map.
2. Guru belum sepenuhnya dapat membuka/menutup pintu sesuai kebutuhan gameplay.
3. Gerakan/animasi pemain masih perlu penyempurnaan.
4. Item yang dipegang harus tampil benar di tangan/view model.
5. Sistem mic dan speaker belum selesai.
6. Multiplayer nyata 1–4 belum selesai.
7. KO → RUANG TAMU → revive dengan medkit perlu diuji dalam multiplayer.

Daftar di atas harus dianggap **open items** sampai diverifikasi pada file/game aktual.

---

# 4. Keputusan Kerja Tim

### Susanto
Menjaga arah project, memastikan perubahan sesuai tujuan game dan permintaan user.

### Yanto
Bertugas sebagai partner verifikasi. Jangan menerima asumsi sebagai fakta; cek file aktual dan kondisi project sebelum menyimpulkan.

### Tono
Menjaga perubahan tetap aman: alasan perubahan harus jelas, dampak harus dipahami, backup/rollback dipertimbangkan, dan perubahan tidak boleh melebar ke luar task.

---

# 5. Keterbatasan Sistem Council

Ruang sidang Godot sebelumnya menggunakan bus runtime:
`user://kelas_malam_ai_council.json`

Bus tersebut menyimpan pesan, tetapi **tidak membuat tiga chat AI otomatis terhubung**. Yanto dan Tono tidak akan otomatis menerima konteks percakapan baru hanya karena pesan ditulis ke bus.

Dokumen `AI_COUNCIL.md` ini dibuat untuk mengatasi masalah tersebut sebagai arsip project-local yang dapat dibaca langsung oleh AI yang memiliki akses ke project.

Namun file ini juga **tidak dapat memaksa** chat AI lain untuk membacanya. Setiap AI tetap harus membuka/membaca file ini melalui akses project yang tersedia.

---

# 6. Keputusan Saat Ini

- Proposal dasar **Kelas Malam** dicatat di sini.
- Target pemain: **1–4**.
- KO dari ruang kepala sekolah diarahkan ke **RUANG TAMU**.
- Revive menggunakan **medkit oleh pemain lain**.
- Map58 geometry/floorplan, position, dan collision adalah hard constraint dan tidak boleh diubah tanpa perintah eksplisit user.
- Perubahan project harus dimulai dari inspeksi file aktual dan diakhiri dengan validasi.
- `AI_COUNCIL.md` adalah arsip permanen bersama; jangan mengandalkan `user://` saja.
- `AI_TASKS.json` adalah antrean tugas bersama.
- `AI_RESULTS.json` adalah tempat handoff hasil verifikasi/review.
- `AI_Council.tscn` kini berfungsi sebagai **Orchestrator Board**: satu perintah user dapat dibuat menjadi task tim dengan pembagian peran Susanto/Yanto/Tono.
- Orchestrator tidak dapat memaksa chat AI lain berjalan otomatis; AI lain tetap harus membaca antrean dan menulis hasil melalui akses project mereka.

---

# 7. Log Sidang

## 2026-10-06 — Susanto
Mengusulkan agar pembahasan proposal dan keputusan tim disimpan dalam arsip project-local agar dapat menjadi sumber kebenaran bersama.

## 2026-10-06 — Yanto
Menekankan bahwa verifikasi harus dilakukan terhadap file aktual, bukan hanya konteks percakapan.

## 2026-10-06 — Tono
Menekankan perubahan aman, alasan/dampak/rollback, serta keterbatasan bahwa council bus bukan koneksi langsung antar-AI.

## 2026-10-06 — Tim
Memutuskan membuat `AI_COUNCIL.md` sebagai arsip permanen project.

---

# 8. Format Update Berikutnya

Gunakan format singkat berikut saat menambahkan keputusan:

## YYYY-MM-DD — NAMA AI

- **Temuan:** apa yang benar-benar ditemukan.
- **Keputusan:** apa yang disepakati.
- **Perubahan:** file apa yang diubah, jika ada.
- **Validasi:** bagaimana perubahan diverifikasi.
- **Open issue:** hal yang masih belum selesai.

---

# 9. Peringatan Penting

Jangan menganggap isi dokumen ini lebih benar daripada project aktual. Dokumen ini adalah **rekam keputusan dan konteks**, sedangkan file/scene/script aktual adalah sumber kebenaran teknis.
## 2026-10-06 — YANTO

- **Temuan:** Tidak ada task baru di `AI_TASKS.json`. Audit lanjutan menemukan Godot v4.7.2 sedang aktif, tetapi percobaan headless editor tidak menghasilkan log error dan tidak dapat dianggap sebagai bukti gameplay berhasil. Performa/lag belum tervalidasi dengan profiler runtime. `TeacherAI.gd` dan `PlayerAnimation.gd` sudah memiliki beberapa mekanisme cache/smoothing, namun efeknya belum terukur.
- **Keputusan:** Jangan melakukan optimasi besar atau mengubah Map58 tanpa pengukuran runtime. Open issue multiplayer, voice chat, KO/Ruang Tamu, distribusi item, dan profiling lag tetap terbuka.
- **Perubahan:** `AI_RESULTS.json` diisi dengan hasil audit. Tidak ada script/map gameplay yang diubah.
- **Validasi:** `AI_COUNCIL.md`, `AI_TASKS.json`, dan `AI_RESULTS.json` dibaca; proses Godot terdeteksi pada PC. Headless check selesai tanpa output error, tetapi tidak diklaim sebagai uji gameplay.
- **Open issue:** Profiling runtime dan verifikasi end-to-end masih diperlukan.


# 10. Aturan Pembagian Task Tim

Tujuan aturan ini adalah mencegah pekerjaan tumpang tindih, mencegah task terlantar, dan memastikan keterbatasan engine salah satu anggota tidak menghentikan tim.

## 10.1 Urutan Status Task

Setiap task mengikuti status berikut:

QUEUED -> CLAIMED -> WORKING -> REVIEW -> DONE

Status tambahan:
- BLOCKED — task tidak dapat dilanjutkan karena dependency, error, akses, atau kebutuhan keputusan user.
- CANCELLED — task dihentikan oleh user.

## 10.2 Aturan Claim

1. Task baru selalu masuk sebagai QUEUED.
2. Hanya satu AI yang boleh menjadi owner utama sebuah task pada satu waktu.
3. AI yang mengambil task wajib mengubah/mencatat status, assigned_agent, claimed_at, dan updated_at.
4. AI lain tidak boleh mengerjakan bagian yang sama secara paralel kecuali task tersebut memang dibagi menjadi subtask yang jelas.
5. Jika task tidak memiliki owner aktif, anggota dengan kapasitas paling tersedia mengambil task tersebut.

## 10.3 Prioritas Pembagian Berdasarkan Peran

### SUSANTO — Implementasi / Koordinasi
Prioritas mengambil:
- implementasi fitur utama,
- integrasi antar-sistem,
- perubahan gameplay,
- perubahan yang membutuhkan keputusan arsitektur,
- task yang membutuhkan koordinasi beberapa sistem.

### YANTO — Audit / Verifikasi
Prioritas mengambil:
- audit bug,
- profiling/performance investigation,
- pemeriksaan dependency,
- verifikasi hasil implementasi,
- reproduksi error,
- pengujian file/scene aktual.

Jika SUSANTO sedang sibuk atau tidak tersedia, YANTO boleh mengambil task implementasi yang aman setelah audit dependency terlebih dahulu.

### TONO — Risiko / Review
Prioritas mengambil:
- review risiko,
- pemeriksaan dampak perubahan,
- rollback/backup assessment,
- review perubahan besar,
- validasi agar optimasi tidak merusak sistem lain.

Jika TONO sedang tidak tersedia atau engine terbatas, task TONO tidak boleh menunggu tanpa batas. SUSANTO atau YANTO dapat mengambil alih sesuai jenis pekerjaan.

## 10.4 Aturan Pengambilalihan

Jika owner task sedang offline, engine-nya terbatas, tidak merespons, atau task membutuhkan pekerjaan segera, anggota lain boleh mengambil alih setelah memeriksa status terakhir di AI_TASKS.json dan AI_RESULTS.json.

Pengambilalihan wajib dicatat sebagai:
- previous_agent
- assigned_agent
- alasan pengambilalihan,
- waktu pengambilalihan.

Contoh alasan:
"Dialihkan dari TONO ke YANTO karena keterbatasan engine TONO."

## 10.5 Pembagian Subtask

Jika satu task terlalu besar, jangan biarkan tiga AI mengedit area yang sama.

Pecah menjadi subtask:
- TASK-A — Investigasi
- TASK-B — Implementasi
- TASK-C — Verifikasi
- TASK-D — Review risiko

Contoh untuk masalah lag F5:
1. YANTO: ukur dan cari sumber bottleneck.
2. SUSANTO: implementasikan solusi berdasarkan hasil pengukuran.
3. YANTO: ukur ulang dan verifikasi peningkatan.
4. TONO: review dampak jika tersedia.
5. Jika TONO tidak tersedia, SUSANTO/YANTO melakukan review silang sebelum task dinyatakan DONE.

## 10.6 Aturan Tidak Boleh Menunggu

Tidak boleh ada aturan yang menyebabkan seluruh tim berhenti hanya karena satu anggota belum tersedia.

Jika pekerjaan TONO diperlukan tetapi TONO tidak tersedia, SUSANTO atau YANTO mengambil alih.

Jika pekerjaan YANTO diperlukan tetapi YANTO tidak tersedia, SUSANTO melakukan verifikasi minimum dan mencatat bahwa verifikasi independen belum tersedia.

Jika pekerjaan SUSANTO diperlukan tetapi SUSANTO tidak tersedia, YANTO boleh melakukan perbaikan yang aman dan terukur, kemudian mencatat perubahan untuk review SUSANTO saat tersedia.

## 10.7 Aturan Penyelesaian

Task hanya boleh menjadi DONE jika:
1. perubahan benar-benar dilakukan atau investigasi benar-benar selesai,
2. file aktual sudah diperiksa,
3. validasi yang diperlukan sudah dilakukan,
4. hasil dicatat di AI_RESULTS.json,
5. open issue dicatat jika masih ada,
6. tidak ada klaim pengujian yang sebenarnya belum dilakukan.

Jika syarat belum terpenuhi, status tetap WORKING, REVIEW, atau BLOCKED.

## 10.8 Prioritas Saat Banyak Task

Urutan prioritas:
1. BLOCKER / bug yang menghentikan game
2. Crash / error / masalah F5
3. Performance / lag / stutter
4. Gameplay core
5. Multiplayer / interaksi antar pemain
6. Polish / audio / animasi / visual
7. Eksperimen dan pekerjaan tambahan

Task prioritas tinggi boleh mengambil kapasitas anggota dari task prioritas rendah, tetapi pengalihan harus dicatat.

## 10.9 Sumber Kebenaran

Untuk pembagian task, gunakan urutan sumber berikut:
1. file project aktual,
2. AI_TASKS.json,
3. AI_RESULTS.json,
4. AI_COUNCIL.md,
5. percakapan AI.

Percakapan tidak boleh mengalahkan kondisi file aktual.

## 2026-10-06 — YANTO (Audit independen lag/stutter F5)

- **Temuan:** Audit runtime tidak mendukung kesimpulan bahwa satu script gameplay tertentu adalah bottleneck utama. Direct run dengan fixed view setelah warm-up dapat mencapai sekitar 59.5 FPS (58–60 FPS), dan matrix 11 spawn siswa berada sekitar 55–60.8 FPS. Physics timing berada sekitar 2.9–3.7 ms pada run warm. Ini berarti lag/stutter tidak dapat disederhanakan sebagai physics overload.
- **Rendering:** Draw calls bervariasi besar menurut posisi kamera, tetapi semua spawn yang diuji tetap mendekati 60 FPS setelah warm-up. SceneTree runtime sekitar 6440 nodes dan sekitar 9990 objects. Kompleksitas ini layak diprofilkan, tetapi belum cukup menjadi alasan untuk menghapus/menggabungkan node.
- **CPU/GPU:** Sampling proses direct game menunjukkan kerja CPU nyata sekitar satu logical core penuh, tetapi tidak cukup untuk menyimpulkan CPU script tertentu sebagai bottleneck tanpa profiler. GPU Engine counter yang terpantau rendah dan tidak menunjukkan saturation; ini juga bukan pengukuran GPU lengkap.
- **Shader:** Pipeline compilation monitors pada probe terbaca 0 untuk Canvas/Mesh/Surface/Draw/Specialization. Ini tidak membuktikan shader stutter mustahil, terutama karena project memakai Compatibility/ANGLE, tetapi probe tidak menemukan bukti compilation event yang dapat dijadikan dasar perubahan.
- **F5:** F5 benar-benar dipicu dari editor Godot dan dihentikan kembali dengan F8. Game berjalan embedded pada proses editor. FPS F5 belum dapat diambil otomatis dari remote access, sehingga tidak ada klaim bahwa F5 sudah terbukti 60 FPS.
- **Eksperimen:** Menonaktifkan sementara Map58Whiteboard.gd + PlayerInteractionInput.gd + items/ItemInventory.gd tidak menunjukkan peningkatan yang meyakinkan. Eksperimen TeacherAI ditolak karena view/draw-call berubah sehingga A/B tidak terkontrol. Tidak ada perubahan tersebut yang dipertahankan.
- **Kandidat berikutnya:** Map58Game.gd menjalankan _update_ui() setiap frame dan menulis beberapa Label.text setiap frame, termasuk assignment self pada _answer_label.text. Ini kandidat CPU/UI yang lebih terukur untuk A/B fixed-view, tetapi belum diubah.
- **Keputusan:** Belum menerapkan LOD, occlusion culling, shadow reduction, renderer change, pengurangan kualitas, atau perubahan map. Lanjutkan dengan A/B terkontrol pada Map58Game UI dan pisahkan metrik startup dari steady-state.
- **Referensi resmi:** CPU optimization/profiler, GPU optimization, Optimizing 3D performance, Fixing jitter/stutter/input lag, pipeline/shader compilation, serta renderer Compatibility Godot 4.7 digunakan sebagai dasar metode. Dokumentasi menekankan profiling sebelum optimasi dan menjelaskan bahwa Compatibility tidak memiliki ubershader modern seperti Forward+/Mobile.
- **Perubahan:** Tidak ada perubahan gameplay permanen. Artefak probe dipindahkan ke diagnostics_performance_20261006.
- **Open issue:** GDScript Profiler editor belum dapat direkam secara interaktif melalui akses remote saat ini; F5 embedded belum memiliki FPS counter otomatis; startup/shader stutter belum sepenuhnya terisolasi.



## 2026-10-06 — SUSANTO (Audit langsung performa F5)

- **Temuan:** Project Godot 4.7 memakai GL Compatibility dan Jolt Physics. Audit seluruh scene menemukan sekitar 2790 deklarasi MeshInstance3D dan 48 node lampu. Main.tscn menginstansikan map, furniture, lapangan basket, bleachers, roof, lighting, teacher, dan sistem gameplay sekaligus. Kompleksitas rendering adalah kandidat bottleneck, tetapi belum dibuktikan sebagai penyebab utama.
- **Referensi:** Dokumentasi resmi Godot 4.7 menekankan profiling sebelum optimasi; dokumentasi rendering menjelaskan material reuse, occlusion culling, dan visibility/LOD sebagai teknik optimasi 3D.
- **Perubahan:** Tidak ada perubahan gameplay/map. Hasil audit ditulis ke AI_RESULTS.json.
- **Validasi:** File aktual diperiksa langsung. Tidak mengklaim peningkatan FPS karena profiler runtime belum dilakukan.
- **Open issue:** Pengukuran F5 nyata diperlukan untuk membedakan CPU bottleneck, GPU bottleneck, dan shader compilation stutter.


## 2026-10-06 — SUSANTO (Koreksi implementasi pembukaan 5 soal)

- **Temuan:** Implementasi lama tidak sesuai proposal: 5 soal awal dikerjakan satu per satu melalui input keyboard, tanpa batas 20 detik. Fase transisi sebelumnya 10 detik dan tidak mengunci gerak pemain, tidak menutup pintu kelas, serta tidak memadamkan lampu kelas.
- **Keputusan:** Pembukaan diubah mengikuti kutipan proposal: kertas berisi 5 soal matematika operasi dasar disediakan di awal; pemain terkunci di kelas selama 20 detik; setelah waktu habis fase pembukaan berakhir, pintu kelas ditutup, lampu kelas dipadamkan, lalu guru masuk fase hantu/transisi menuju gameplay utama. Spawn siswa tetap memilih kelas yang tersedia dan XII D memang tidak memiliki Marker spawn; guru tetap di TeacherSpawn ruang guru.
- **Perubahan:** `Map58Game.gd` sekarang membuat 5 soal sekaligus, menyediakan 5 field jawaban, memakai timer 20 detik, mengunci gerak pemain melalui meta `intro_locked`, menghitung jawaban setelah waktu habis, menutup pintu kelas terdekat, dan memadamkan lampu terdekat. `Player.gd` menghormati `intro_locked`. `PintuKelas.gd` dimasukkan ke group `doors` agar dapat ditutup otomatis.
- **Validasi:** Godot 4.7.2 headless editor check selesai dengan exit code 0 setelah perubahan. Tidak ada klaim bahwa tampilan F5 sudah diverifikasi visual; uji visual in-game masih perlu dilakukan.
- **Open issue:** Visual kertas fisik di atas/meja pemain dan animasi guru benar-benar melayang saat meninggalkan kelas masih perlu verifikasi/penyempurnaan visual. Posisi map/furniture tidak diubah.
