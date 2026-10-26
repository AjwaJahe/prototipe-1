extends Node

const SETTINGS_PATH := "user://menu_settings.cfg"
const LANG_ID := "id"
const LANG_EN := "en"

var current_language: String = LANG_ID
signal language_changed(language_code: String)

const META_ORIGINAL := &"loc_original"
const META_LAST := &"loc_last"
const META_TIP_ORIGINAL := &"loc_tip_original"
const META_TIP_LAST := &"loc_tip_last"
const META_TRACKED := &"loc_tracked"
const CACHE_LIMIT := 4000

var _cache: Dictionary = {}
var _tracked: Array = []
var _templates: Array = []
var _prefix_rules: Array = []
# Pemetaan UI inti. String yang belum ada di sini tidak diubah agar isi pemain
# (nama, chat, jawaban, dan soal) tidak diterjemahkan secara keliru.
const ENGLISH := {
	"KELAS MALAM": "NIGHT CLASS", "Horor sekolah  |  Prototipe 1": "School horror  |  Prototype 1",
	"MULAI": "PLAY", "KARAKTER": "CHARACTERS", "TEMAN": "FRIENDS", "AKUN": "PROFILE",
	"PENGATURAN": "SETTINGS", "KREDIT": "CREDITS", "KELUAR": "QUIT", "Versi demo": "Demo version",
	"Volume": "Volume", "Layar penuh": "Fullscreen", "KEMBALI": "BACK", "BAHASA": "LANGUAGE", "Bahasa / Language": "Language",
	"PROFIL PEMAIN": "PLAYER PROFILE", 
	"Masukkan nama pemain": "Enter player name", "SIMPAN": "SAVE", "OKE": "OK",
	"Nama tidak boleh kosong. Masukkan nama profil terlebih dahulu.": "Name cannot be empty. Enter a profile name first.",
	"PILIH KARAKTER": "CHOOSE CHARACTER", 
	"KEMBALI KE MENU UTAMA": "BACK TO MAIN MENU", "MENU PERMAINAN": "GAME MENU", "INTERAKSI": "INTERACT",
	"SEMBUNYI": "HIDE", "LARI: ON": "RUN: ON", "LARI: OFF": "RUN: OFF", "JONGKOK": "CROUCH",
	"KIRIM": "SEND", "TUTUP": "CLOSE", "Tulis pesan (maks. 160 karakter)...": "Type a message (max. 160 characters)...",
	"Tempel Room ID dari host": "Paste the Room ID from the host", "Pilih karakter": "Choose character",
	"UJIAN PEMBUKA": "OPENING EXAM", "Memuat soal...": "Loading questions...", "Jawaban": "Answer",
	"SELESAI MENGERJAKAN": "FINISH", "RUANG HUKUMAN": "DETENTION ROOM", "KERTAS SOAL - 20 DETIK": "EXAM PAPER - 20 SECONDS",
	"Soal sedang dimuat...": "Loading question...", "Ketik jawaban angka, lalu tekan ENTER": "Type a numeric answer, then press ENTER",
	"Suara dimatikan": "Sound muted", "Suara aktif": "Sound on", "Mikrofon aktif": "Microphone on", "Mikrofon mati": "Microphone off",
	"Buang item dari slot terpilih": "Drop item from selected slot", "Soal": "Question", "KAPUR": "CHALK", "PENGHAPUS": "ERASER",
	"MENU": "MENU", "SETTING": "SETTINGS", "PETA SEKOLAH": "SCHOOL MAP", "Mini Map": "Mini Map",
	"Masukkan jawaban melalui kontrol papan.": "Enter your answer using the board controls.", "INVENTORI": "INVENTORY",
	"SOAL KE": "QUESTION",
	"KLIK KIRI": "LEFT CLICK", "KLIK KANAN": "RIGHT CLICK", "Ambil": "Pick up", "Interaksi:": "Interact:",
	"STAMINA": "STAMINA", "LARI": "RUN", "Lompat": "Jump", "LOMPAT": "JUMP",
	"Nama:": "Name:", "Kelas:": "Class:", "Waktu:": "Time:", "detik": "seconds", "Jawaban diisi melalui kolom jawaban pada layar.": "Enter your answers in the on-screen answer fields.",
	"Isi 5 jawaban pada kertas ini. Setelah selesai, tekan tombol selesai.": "Fill in all 5 answers on this paper. When finished, press the finish button.",
	"UJIAN AKAN DIMULAI": "THE EXAM WILL BEGIN", "Kamu duduk di bangku ujian.": "You are seated at the exam desk.", "Saat kertas muncul, isi jawaban untuk 5 soal.": "When the paper appears, answer all 5 questions.", "Kamu memiliki waktu 20 detik.": "You have 20 seconds.", "Bersiaplah...": "Get ready...",
	"PAPAN XII D": "BOARD XII D", "ARAHKAN KE PAPAN XII D, lalu KLIK KIRI untuk mulai soal": "AIM AT BOARD XII D, then LEFT CLICK to start the question",
	
	"KARAKTER TERPILIH": "SELECTED CHARACTER", "Terpilih:": "Selected:", "Karakter": "Character", "tersimpan.": "saved.",
	
	"KELUAR DARI PERMAINAN": "EXIT GAME", "Tutup": "Close", "Kirim": "Send",
	"Fitur ini belum tersedia di prototipe.": "This feature is not available in the prototype yet.",
	"Nama profil disimpan di perangkat ini. Ini bukan akun online.": "Your profile name is saved on this device. This is not an online account.",
	"Profil gagal disimpan (kode %d).": "Failed to save profile (code %d).",
	"KREDIT & SUMBER AUDIO": "CREDITS & AUDIO SOURCES",
	"Undangan": "Invite", "Buat Room": "Create Room", "Gabung Room": "Join Room", "Bergabung": "Join",
	"Room ID": "Room ID", "Salin": "Copy", "Host": "Host", "Pemain": "Players", "Menunggu pemain...": "Waiting for players...",
	"Mulai permainan": "Start game", "Mulai": "Start", "Batal": "Cancel", "Ya": "Yes", "Tidak": "No", "Lanjutkan": "Resume", "Ulangi": "Retry",
	"PAUSE": "PAUSED", "JEDA": "PAUSED", "LANJUTKAN": "RESUME", "ULANGI": "RETRY", "KEMBALI KE PERMAINAN": "RETURN TO GAME",
	"Keluar ke menu utama": "Return to main menu", "Apakah kamu yakin ingin keluar?": "Are you sure you want to quit?",
	"Berhasil": "Success", "Gagal": "Failed", "Peringatan": "Warning", "Kesalahan": "Error", "Informasi": "Information",
	"Memuat...": "Loading...", "Menyimpan...": "Saving...", "Tersimpan": "Saved", "Tidak tersedia": "Unavailable",
	"Tekan E untuk berinteraksi": "Press E to interact", "Tekan E untuk mengambil": "Press E to pick up", "Tekan E untuk bersembunyi": "Press E to hide",
	"Tekan ESC untuk kembali": "Press ESC to go back", "Tekan ENTER untuk melanjutkan": "Press ENTER to continue",
	"Nama pemain": "Player name", "Nama profil": "Profile name", "Pilih bahasa": "Choose language", "Bahasa Indonesia": "Indonesian", "English": "English",
	"Suara": "Sound", "Efek suara": "Sound effects", "Musik": "Music", "Kualitas grafis": "Graphics quality", "Resolusi": "Resolution",
	"AKTIF": "ON", "MATI": "OFF", "HIDUP": "ON", "NONAKTIF": "OFF",
	"Jawaban benar!": "Correct answer!", "Jawaban salah!": "Incorrect answer!", "Jawaban tidak boleh kosong.": "The answer cannot be empty.",
	"Tulisan tidak dapat dikenali": "Handwriting could not be recognized", "Waktu habis!": "Time is up!", "Ujian selesai": "Exam complete",
	"Nilai": "Score", "Benar": "Correct", "Salah": "Incorrect", "Waktu tersisa": "Time remaining", "Nyawa": "Lives",
	"Guru mendekat!": "The teacher is approaching!", "Sembunyi sekarang!": "Hide now!", "Kamu ketahuan!": "You have been caught!",
	"Jangan bergerak": "Don't move", "Kelas": "Classroom", "Lorong": "Hallway", "Perpustakaan": "Library", "Kantin": "Canteen",
	"Ruang guru": "Teachers' room", "Gudang": "Storage room", "Toilet": "Restroom", "Papan tulis": "Blackboard", "Pintu": "Door",
	"Gunakan kapur untuk menulis jawaban.": "Use the chalk to write your answer.", "Hapus tulisan dengan penghapus.": "Erase the writing with the eraser.",
	"Tekan tombol selesai setelah semua jawaban diisi.": "Press Finish after all answers are filled in.",
	"Menunggu host...": "Waiting for host...", "Room tidak ditemukan.": "Room not found.", "Room penuh.": "Room is full.",
	"Koneksi terputus.": "Connection lost.", "Gagal terhubung ke host.": "Failed to connect to host.", "Berhasil bergabung ke room.": "Successfully joined the room.",
	"Pengelola multiplayer belum dimuat. Periksa Autoload MultiplayerSession.": "The multiplayer manager has not loaded. Check the MultiplayerSession autoload.",
	"Nama tidak boleh kosong.": "Name cannot be empty.", "Pemain belum siap.": "Player is not ready yet.", "Kamu": "You",
	# Konten dunia: tulisan cerita pada papan tulis kelas.
	"DUNIA INI TIDAK NYATA...\\nSelesaikan 10 soal untuk kabur!\\nJangan percaya semua yang kamu lihat.": "THIS WORLD IS NOT REAL...\\nSolve 10 questions to escape!\\nDon't believe everything you see.",
	"GURU MENDENGAR LANGKAHMU\\n...DAN JUGA SUARAMU.\\nJangan berisik saat bersembunyi.": "THE TEACHER HEARS YOUR FOOTSTEPS\\n...AND YOUR VOICE TOO.\\nKeep quiet while hiding.",
	"PETUNJUK: Cari soal di papan XII D.\\nTulis jawaban dengan kapur.\\nPastikan bentuk angkanya jelas.": "HINT: Find the questions on the XII D board.\\nWrite your answers with chalk.\\nMake sure the numbers are clear.",
	"JANGAN LARI TERUS!\\nLari memang cepat, tapi langkahmu\\nlebih mudah terdengar.": "STOP RUNNING ALL THE TIME!\\nRunning is fast, but your footsteps\\nare easier to hear.",
	"Kalau guru mendekat, SEMBUNYI.\\nPeti bisa melindungimu...\\nasal kamu tidak membuat suara.": "When the teacher gets close, HIDE.\\nThe crate can protect you...\\nas long as you stay quiet.",
	"10 JAWABAN BENAR = JALAN KELUAR\\nSelesaikan semuanya, lalu cari\\npintu gerbang sekolah.": "10 CORRECT ANSWERS = THE WAY OUT\\nFinish them all, then find\\nthe school gate.",
	"KAPUR + PAPAN = JAWABAN\\nDekati papan XII D, tahan klik kiri\\ndan gambar angkanya.": "CHALK + BOARD = ANSWERS\\nApproach the XII D board, hold left-click,\\nand draw the numbers.",
	"JANGAN BIARKAN DIA MELIHATMU.\\nPutuskan pandangan guru dan\\nsegera cari tempat berlindung.": "DON'T LET HIM SEE YOU.\\nBreak the teacher's line of sight and\\nfind somewhere to hide.",
	"Apa sekolah ini pernah nyata?\\nJam terus berjalan, tapi lorong\\nselalu terasa sama...": "Was this school ever real?\\nThe clock keeps ticking, but the hallways\\nalways feel the same...",
	"DENGARKAN SEKITARMU.\\nSuara bisa membocorkan posisimu.\\nBerjalanlah dengan hati-hati.": "LISTEN TO YOUR SURROUNDINGS.\\nSound can give away your position.\\nWalk carefully.",
	"JANGAN MENYERAH.\\nSelesaikan soal satu demi satu.\\nGerbang adalah satu-satunya jalan keluar.": "DON'T GIVE UP.\\nSolve the questions one by one.\\nThe gate is the only way out.",
	# Pesan gameplay, interaksi objek, papan tulis, dan pengaturan HUD.
	"Inventori penuh (2/2). Pilih slot 1/2 lalu P untuk membuang item.": "Inventory full (2/2). Select slot 1/2, then press P to drop an item.",
	"Inventori penuh (2/2).": "Inventory full (2/2).", "Tidak ada item yang dipilih.": "No item selected.",
	"Item diambil dari rak.": "Item taken from the shelf.", "Item dijatuhkan.": "Item dropped.",
	"Slot ": "Slot ", "Slot %d kosong.": "Slot %d is empty.", "Dipilih: ": "Selected: ",
	"Mengambil ": "Picking up ", "Mengambil Kapur.": "Picking up Chalk.", "Mengambil Kertas Soal.": "Picking up Exam Paper.", "Mengambil Kunci Kelas.": "Picking up the Classroom Key.",
	"Jawaban: ": "Answer: ", "KLIK KIRI — Ambil ": "LEFT CLICK — Pick up ",
	"KLIK KIRI — Ambil Kapur": "LEFT CLICK — Pick up Chalk", "KLIK KIRI — Ambil Kertas Soal": "LEFT CLICK — Pick up Exam Paper", "KLIK KIRI — Ambil Kunci Kelas": "LEFT CLICK — Pick up the Classroom Key",
	"KLIK KANAN — ": "RIGHT CLICK — ", "Interaksi: ": "Interact: ",
	"Ambil ": "Pick up ", "Bersembunyi di bawah kasur": "Hiding under the bed",
	"Tempat Persembunyian ": "Hiding Spot ", "Laci meja guru": "Teacher's desk drawer",
	"Kapur": "Chalk", "Kertas Soal": "Exam Paper", "Kunci Kelas": "Classroom Key", "KELUAR DARI PERSEMBUNYIAN": "EXIT",
	"Sembunyi / Keluar": "Hide / Exit", "Lari": "Run",
	"Rak dibuka.": "Shelf opened.", "Rak ditutup.": "Shelf closed.",
	"Item disimpan di rak. Klik kiri untuk mengambilnya kembali.": "Item stored on the shelf. Left-click to retrieve it.",
	"Seret tombol untuk memindahkan. Pilih tombol lalu atur ukuran.": "Drag a button to move it. Select a button to adjust its size.",
	"Tata letak tersimpan.": "Layout saved.", "Gagal menyimpan tata letak (%s).": "Failed to save layout (%s).",
	"Tata letak khusus dihapus dan posisi HUD awal dipulihkan.": "Custom layout deleted and the default HUD positions restored.",
	"ATUR TOMBOL HUD": "CUSTOMIZE HUD BUTTONS", "Seret tombol di layar. Ukuran diatur untuk tombol terpilih.": "Drag buttons on the screen. Adjust the size of the selected button.",
	"Seret tombol untuk memindahkan.": "Drag buttons to move them.", "Ukuran: 100%": "Size: 100%",
	"Ukuran: %d%%": "Size: %d%%", "SIMPAN TATA LETAK": "SAVE LAYOUT", "RESET POSISI": "RESET POSITION", "SELESAI": "DONE",
	"Karakter terpilih: %s": "Selected character: %s", "Pilih satu dari empat siswa. Pilihan disimpan di perangkat ini.": "Choose one of the four students. Your choice is saved on this device.",
	"Terpilih: %s - %s": "Selected: %s - %s", "Karakter %s tersimpan.": "Character %s saved.",
	"Jawaban disimpan. Isi semua jawaban untuk mengakhiri ujian lebih awal, atau tunggu waktu habis.": "Answer saved. Fill in all answers to end the exam early, or wait for time to run out.",
	"Bank soal untuk tahap ini tidak tersedia.": "The question bank for this stage is unavailable.",
	"Jawaban hukuman dikirim ke host...": "Detention answer sent to the host...", "Masukkan jawaban terlebih dahulu.": "Enter an answer first.",
	"Soal berikutnya gagal dimuat. Coba kirim jawaban lagi.": "The next question failed to load. Try submitting your answer again.",
	"Benar. Soal berikutnya.": "Correct. Next question.", "Salah. Jawaban benar: ": "Incorrect. Correct answer: ",
	"Guru mengamuk. Bersiap...": "The teacher is enraged. Get ready...",
	"Mode Hantu aktif. Guru akan terus mengejar sampai kamu menjawab soal papan tulis dengan benar.": "Ghost Mode is active. The teacher will keep chasing you until you answer the blackboard question correctly.",
	"Pemain harus membawa Kertas Soal.": "You must carry the Exam Paper.", "Pemain harus membawa Kapur.": "You must carry Chalk.",
	"Bawa Kertas Soal terlebih dahulu.": "Pick up the Exam Paper first.", "Bawa Kapur terlebih dahulu.": "Pick up Chalk first.",
	"Guru mengetahui kelasmu. Waktu menjawab: 2 menit.": "The teacher knows your classroom. Time to answer: 2 minutes.",
	"Jawaban benar. Soal berikutnya akan muncul di lokasi baru.": "Correct answer. The next question will appear at a new location.",
	"Waktu habis. Guru mengejarmu lagi.": "Time is up. The teacher is chasing you again.",
	"Guru kembali ke mode guru selama 3 menit.": "The teacher returns to teacher mode for 3 minutes.",
	"10 soal benar. Guru berjalan ke pintu utama dan membukanya. Lewati pintu untuk menang.": "10 correct answers. The teacher walks to the main entrance and opens it. Go through the door to win.",
	"Kamu berhasil keluar dari sekolah. Nilai akhir: ": "You escaped the school. Final grade: ",
	"Tertangkap. Jawab soal untuk keluar dari ruangan hukuman.": "Caught. Answer the question to leave the detention room.",
	"Kamu keluar dari hukuman dalam kondisi KO. Teman dapat memakai Medkit.": "You left detention while knocked out. A friend can use a Medkit.",
	"SEMUA MURID KO. PERMAINAN BERAKHIR.": "ALL STUDENTS ARE KNOCKED OUT. GAME OVER.",
	"Medkit berhasil digunakan. Guru kembali ke mode sebelum penangkapan.": "Medkit used successfully. The teacher returns to its pre-capture mode.",
	"Teman berhasil dihidupkan.": "Your friend has been revived.",
	"Kamu bersembunyi di bawah kasur. Klik kanan untuk keluar.": "You are hiding under the bed. Right-click to exit.",
	"Kamu bersembunyi. Klik kanan untuk keluar.": "You are hiding. Right-click to exit.",
	"Kamu keluar dari tempat persembunyian.": "You left the hiding spot.",
	"Buka rak terlebih dahulu.": "Open the shelf first.", "Rak ini sudah menyimpan satu item.": "This shelf already contains an item.",
	"Inventory tidak ditemukan.": "Inventory not found.", "Data inventory tidak valid.": "Inventory data is invalid.",
	"Pilih item di inventory terlebih dahulu.": "Select an item in the inventory first.", "Item yang dipilih tidak valid.": "The selected item is invalid.",
	"Inventory penuh. Kosongkan satu slot terlebih dahulu.": "Inventory is full. Empty a slot first.",
	"Tempat item dunia tidak ditemukan.": "World item location not found.",
	"Jawaban dihapus. Tahan klik kiri untuk menulis ulang.": "Answer erased. Hold left-click to write again.",
	"Penghapus aktif.": "Eraser active.", "Kapur aktif.": "Chalk active.",
	"Koneksi multiplayer belum siap.": "Multiplayer connection is not ready.",
	"Bawa Kertas Soal + Kapur, lalu klik kiri papan.": "Bring the Exam Paper and Chalk, then left-click the board.",
	"Kamu membutuhkan Kertas Soal dan Kapur.": "You need the Exam Paper and Chalk.",
	"Menulis... klik kanan untuk mengoreksi.": "Writing... right-click to check.",
	"Belum ada jawaban di papan.": "There is no answer on the board yet.",
	"Anda menulis: [sistem belum berhasil membaca angka] | skor: ": "You wrote: [the system could not read the number] | score: ",
	"Inventori penuh": "Inventory full", "KLIK KIRI — INVENTORI PENUH": "LEFT CLICK — INVENTORY FULL",
	"MUAT ULANG": "RELOAD", "BAGIKAN KE TIM": "DISPATCH TO TEAM", "Orchestrator siap.": "Orchestrator ready.",
	"Gagal menulis AI_TASKS.json": "Failed to write AI_TASKS.json", "Pesan ke council...": "Message the council...",

	# Label dan notifikasi yang diisi langsung dari GDScript.
	"Mulai Game": "Start Game", "PILIH BAHASA": "CHOOSE LANGUAGE",
	"Pengaturan": "Settings", "Pengaturan permainan": "Game Settings", "Pengaturan Audio": "Audio Settings",
	"Profil": "Profile", "Teman": "Friends", "Keluar": "Quit", "Kredit": "Credits",
	"Simpan": "Save",
	"Room teman": "Friends' Room", "Buat room": "Create Room", "Gabung room": "Join Room", "ID Room": "Room ID",
	"Salin ID": "Copy ID", "Menyalin...": "Copying...", "ID berhasil disalin": "ID copied successfully",
	"Menunggu pemain lain...": "Waiting for other players...",
	"Siap": "Ready", "Belum siap": "Not ready", "Mulai saat semua siap": "Start when everyone is ready",
	"Terhubung": "Connected", "Menghubungkan...": "Connecting...", "Terputus": "Disconnected",
	"Profil berhasil disimpan.": "Profile saved successfully.", "Gagal menyimpan profil.": "Failed to save profile.",
	"Apakah kamu yakin?": "Are you sure?", "Kembali": "Back", "Lanjut": "Continue", "Keluar permainan": "Quit Game",
	"Tekan untuk melanjutkan": "Press to continue", "Klik untuk memulai": "Click to start", "Klik untuk kembali": "Click to go back",
	# Main menu: teks yang diisi oleh callback, overlay, dan panel dinamis.
	"INFO": "INFO",
	"Tekstur, karakter, furnitur, item, dan aset visual dibuat sendiri untuk Kelas Malam.\\n\\nAudio eksternal (CC0):\\n• Langkah kaki, suara laci — FOSSarts\\n• Pintu berderit — dleverett\\n• Pintu lemari geser — Rudmer_Rotteveel\\n• Handle pintu — XavizardKnight\\n• Jumpscare & kunci — qubodup\\n• Bisikan hantu — brktkrgll\\n• Ambience malam — Yuval\\n• Bunyi kemenangan — SFXMint\\n• Efek horor — shelbyshark\\n": "Textures, characters, furniture, items, and visual assets were created for Kelas Malam.\\n\\nExternal audio (CC0):\\n• Footsteps and drawer sounds — FOSSarts\\n• Creaking door — dleverett\\n• Sliding closet door — Rudmer_Rotteveel\\n• Door handle — XavizardKnight\\n• Jumpscare and keys — qubodup\\n• Ghost whispers — brktkrgll\\n• Night ambience — Yuval\\n• Victory sound — SFXMint\\n• Horror effects — shelbyshark\\n",
	"MULTIPLAYER": "MULTIPLAYER", "BUAT ROOM": "CREATE ROOM", "GABUNG ROOM": "JOIN ROOM",
	"PENGATURAN ROOM": "ROOM SETTINGS", "Mode permainan": "Game mode", "Durasi pengerjaan soal": "Question duration",
	"Privasi room": "Room privacy", "Privat — hanya dengan ID": "Private — invite by ID only", "Publik — dapat ditemukan": "Public — discoverable",
	"Jumlah pemain maksimum": "Maximum players", "menit": "minutes", "pemain": "players",
	"Masukkan Room ID yang ditampilkan pada perangkat host. App ID tidak perlu dimasukkan.": "Enter the Room ID shown on the host device. You do not need to enter the App ID.",
	"Masukkan Room ID dari host.": "Enter the Room ID from the host.", "Room ID terlalu panjang.": "Room ID is too long.",
	"BUAT ROOM LANGSUNG (LAN / playit)": "CREATE DIRECT ROOM (LAN / playit)", "GABUNG LANGSUNG (ALAMAT:PORT)": "JOIN DIRECT (ADDRESS:PORT)",
	"PENGATURAN ROOM LANGSUNG": "DIRECT ROOM SETTINGS", "Koneksi langsung memakai UDP port 7777. Untuk bermain lintas rumah, buat tunnel UDP di playit.gg.": "Direct connection uses UDP port 7777. To play across different homes, create a UDP tunnel in playit.gg.",
	"Alamat publik (opsional, dari playit.gg)": "Public address (optional, from playit.gg)", "nama.at.ply.gg:PORT (opsional)": "name.at.ply.gg:PORT (optional)",
	"Jika alamat publik kosong, alamat LAN akan ditampilkan. Izinkan Godot melewati Windows Firewall pada jaringan Private.": "If the public address is empty, the LAN address will be shown. Allow Godot through Windows Firewall on Private networks.",
	"BUAT ROOM LANGSUNG": "CREATE DIRECT ROOM", "Alamat publik terlalu panjang.": "Public address is too long.",
	"MENYIAPKAN SERVER LANGSUNG": "SETTING UP DIRECT SERVER", "Membuka UDP port 7777…": "Opening UDP port 7777…",
	"Gagal membuka UDP port %d (kode %d). Pastikan port tidak dipakai aplikasi lain.": "Could not open UDP port %d (code %d). Make sure another application is not using the port.",
	"GABUNG LANGSUNG": "JOIN DIRECT", "Masukkan alamat host, misalnya 192.168.1.10:7777 atau nama.at.ply.gg:PORT.": "Enter the host address, e.g. 192.168.1.10:7777 or name.at.ply.gg:PORT.",
	"alamat:port (port boleh dikosongkan)": "address:port (port optional)", "Masukkan alamat host yang valid (maksimum 256 karakter).": "Enter a valid host address (maximum 256 characters).",
	"Format alamat salah. Gunakan alamat:port, misalnya 127.0.0.1:7777.": "Invalid address format. Use address:port, e.g. 127.0.0.1:7777.",
	"Alamat host atau port tidak valid. Port harus 1–65535.": "Invalid host address or port. Port must be 1–65535.",
	"MENGHUBUNGKAN LANGSUNG": "CONNECTING DIRECTLY", "Menghubungkan ke %s:%d…": "Connecting to %s:%d…",
	"Gagal memulai koneksi langsung (kode %d).": "Could not start direct connection (code %d).",
	"Koneksi langsung gagal. Periksa alamat, port UDP, tunnel playit.gg, dan firewall host.": "Direct connection failed. Check the address, UDP port, playit.gg tunnel, and host firewall.",
	"Waktu koneksi langsung habis. Periksa alamat, port UDP, tunnel playit.gg, dan firewall host.": "Direct connection timed out. Check the address, UDP port, playit.gg tunnel, and host firewall.",
	"COBA BUAT ROOM LANGSUNG LAGI": "TRY CREATING DIRECT ROOM AGAIN", "COBA GABUNG LANGSUNG LAGI": "TRY JOINING DIRECT AGAIN",
	"Server langsung aktif. Bagikan alamat ini kepada teman.": "Direct server is active. Share this address with your friends.",
	"Koneksi langsung berhasil. Alamat ini adalah alamat host.": "Direct connection succeeded. This is the host address.",
	"Alamat host disalin ke clipboard.": "Host address copied to clipboard.",
	"SALIN ALAMAT": "COPY ADDRESS", "Mode: %s\\nDurasi soal: %d menit\\nBatas pemain: %d": "Mode: %s\\nQuestion duration: %d minutes\\nPlayer limit: %d",
	"MENGHUBUNGKAN": "CONNECTING", "Menghubungkan ke relay NodeTunnel…\\nTunggu hingga room berhasil dibuat atau ditemukan.": "Connecting to the NodeTunnel relay…\\nWait until the room is created or found.",
	"BATAL": "CANCEL", "NodeTunnelPeer gagal dibuat.": "Failed to create NodeTunnelPeer.",
	"Relay menolak permintaan room (kode %d).": "The relay rejected the room request (code %d).",
	"MENYIAPKAN ROOM": "SETTING UP ROOM", "Autentikasi berhasil. Menunggu relay mengonfirmasi room…": "Authentication succeeded. Waiting for the relay to confirm the room…",
	"KONEKSI GAGAL": "CONNECTION FAILED", "COBA BUAT ROOM LAGI": "TRY CREATING ROOM AGAIN", "COBA GABUNG LAGI": "TRY JOINING AGAIN",
	"KEMBALI KE MULTIPLAYER": "BACK TO MULTIPLAYER", "ROOM BELUM TERHUBUNG": "ROOM NOT CONNECTED", "COBA LAGI": "TRY AGAIN",
	"LOBI ROOM": "ROOM LOBBY", "Koneksi NodeTunnel berhasil. Bagikan Room ID ini kepada teman.": "NodeTunnel connection succeeded. Share this Room ID with your friends.",
	"SALIN ID ROOM": "COPY ROOM ID", "Status: tersambung ke room\\nPemain terdeteksi: %d": "Status: connected to room\\nPlayers detected: %d",
	"STATUS PEMAIN": "PLAYER STATUS", "SIAP": "READY", "BELUM SIAP": "NOT READY", " (Kamu)": " (You)",
	"BATAL SIAP": "NOT READY", "SAYA SIAP": "I'M READY", "Semua pemain harus siap. Semua sudah siap.": "All players must be ready. Everyone is ready.",
	"Semua pemain harus siap. Masih menunggu pemain siap.": "All players must be ready. Waiting for players to get ready.",
	"MULAI PERMAINAN UNTUK SEMUA": "START GAME FOR EVERYONE", "Menunggu host memulai permainan setelah semua pemain siap.": "Waiting for the host to start once everyone is ready.",
	"KELUAR DARI ROOM": "LEAVE ROOM", "Room ID disalin ke clipboard.": "Room ID copied to clipboard.",
	"Hanya host yang dapat memulai permainan.": "Only the host can start the game.",
	"Semua pemain, termasuk host, harus menekan SIAP terlebih dahulu.": "All players, including the host, must press READY first.",
	"Belum ada koneksi room aktif. Buat atau gabung room terlebih dahulu.": "There is no active room connection. Create or join a room first.",
	"Mode: %s\\nDurasi soal: %d menit\\nPrivasi: %s\\nBatas pemain: %d": "Mode: %s\\nQuestion duration: %d minutes\\nPrivacy: %s\\nPlayer limit: %d",
	# Semua teks yang dibuat dinamis oleh RoomFlow harus memiliki padanan Inggris.
	"Mode": "Mode", "SD": "Elementary School", "SMP": "Junior High School", "SMA": "Senior High School", "Dasar": "Basic", "Privat": "Private", "Publik": "Public",
	"%d menit": "%d minutes", "%d pemain": "%d players",
	"Durasi soal: %d menit": "Question duration: %d minutes",
	"Privasi: %s": "Privacy: %s", "Batas pemain: %d": "Player limit: %d",
	"Status: tersambung ke room": "Status: connected to room", "Pemain terdeteksi: %d": "Players detected: %d",
	"Host — SIAP": "Host — READY", "Host — BELUM SIAP": "Host — NOT READY",
	"Pemain %d — SIAP": "Player %d — READY", "Pemain %d — BELUM SIAP": "Player %d — NOT READY",
	"Semua pemain harus siap. %s": "All players must be ready. %s",
	"Semua sudah siap.": "Everyone is ready.", "Masih menunggu pemain siap.": "Still waiting for players to get ready.",
	"Room melebihi batas %d pemain. Keluarkan pemain tambahan sebelum mulai.": "The room exceeds the limit of %d players. Remove extra players before starting.",
	"Pemain %d ditolak karena batas room (%d) sudah penuh.": "Player %d was rejected because the room reached its limit (%d).",
	"Mengirim perintah mulai ke semua pemain…": "Sending the start command to all players…",
	"Relay mengonfirmasi koneksi tetapi Room ID kosong.": "The relay confirmed the connection, but the Room ID is empty.",
	"NodeTunnel: %s": "NodeTunnel: %s",
	"Koneksi ke relay terputus. Buat atau gabung room kembali.": "Connection to the relay was lost. Create or join a room again.",
	"Waktu koneksi habis. Periksa internet lalu coba lagi.": "Connection timed out. Check your internet and try again.",
	"Library NodeTunnel belum dimuat. Pastikan addons/nodetunnel sudah ada dan ekstensi berhasil dimuat.": "The NodeTunnel library is not loaded. Make sure addons/nodetunnel exists and the extension loaded successfully.",
	"Tidak dapat memulai koneksi relay (kode %d).": "Could not start the relay connection (code %d).",
	"Status pemain": "Player status", "Pemain terdeteksi": "Players detected",
	# Pesan gameplay lanjutan: papan tulis, HUD guru, interaksi, dan ujian pembuka.
	"SEMBUHKAN": "HEAL", "MAIN LAGI": "PLAY AGAIN", "JONGKOK: ON": "CROUCH: ON", "JONGKOK: OFF": "CROUCH: OFF",
	"GURU BERPATROLI": "TEACHER PATROLLING", "GURU MENJADI HANTU": "TEACHER BECAME A GHOST",
	"GURU MASUK MODE BERSEK": "TEACHER ENTERED BERSERK MODE", "GURU SEDANG MERESPONS": "TEACHER IS RESPONDING",
	"MODE GURU: %s": "TEACHER MODE: %s", "GURU TERDETEKSI %s": "TEACHER DETECTED %s", "%s GURU DEKAT %s": "%s TEACHER NEARBY %s",
	"INVENTORI [%d/%d]:": "INVENTORY [%d/%d]:", "SOAL KE %s": "QUESTION %s", "WAKTU: %s": "TIME: %s",
	"NILAI AKHIR: %s": "FINAL GRADE: %s", "SKOR TOTAL: %d": "TOTAL SCORE: %d", "SOAL TERJAWAB: %d/10": "QUESTIONS ANSWERED: %d/10",
	"FPS: %d   PING: %s   PEMAIN: %d": "FPS: %d   PING: %s   PLAYERS: %d",
	"Nama: %s": "Name: %s", "Kelas: %s   Waktu: %d detik": "Class: %s   Time: %d seconds",
	"Bersiaplah... %s": "Get ready... %s", "Perhatikan instruksi ujian...": "Pay attention to the exam instructions...",
	"Benar. %s": "Correct. %s", "SALAH. Guru masuk mode BERSEK selama 15 detik.": "WRONG. The teacher enters BERSERK mode for 15 seconds.",
	"Mode Bersek berakhir. Guru kembali ke mode sebelumnya: %s": "Berserk mode ended. The teacher returned to its previous mode: %s",
	"BENAR: %s": "CORRECT: %s", "SALAH: %s": "WRONG: %s", "SOAL:": "QUESTION:",
	"Game belum siap menerima jawaban.": "The game is not ready to receive answers.", "Jawaban belum diterima game. Coba lagi.": "The game has not accepted the answer. Try again.",
	"Jawaban dikirim ke host untuk diperiksa...": "Answer sent to the host for checking...",
	"Kapur aktif. Sentuh dan geser di papan untuk menulis.": "Chalk active. Touch and drag on the board to write.",
	"MODE PAPAN XII D: pilih KAPUR/PENGHAPUS di kiri bawah, lalu geser pada papan.": "BOARD XII D MODE: choose CHALK/ERASER at the bottom left, then drag on the board.",
	"PAPAN XII D: tahan klik kiri = menulis | klik kanan = kirim | BACKSPACE = hapus": "BOARD XII D: hold left click = write | right click = submit | BACKSPACE = erase",
	"Penghapus aktif. Geser di bagian tulisan yang ingin dihapus.": "Eraser active. Drag over the writing you want to erase.",
	"Semua tulisan dihapus.": "All writing erased.", "Soal diterima dari host. Tulis jawaban lalu kirim.": "Question received from the host. Write your answer, then submit.",
	"Soal ditutup. Waktu habis atau jawaban sudah dikirim.": "Question closed. Time is up or the answer was already submitted.",
	"[KLIK KANAN] Bersembunyi / keluar": "[RIGHT CLICK] Hide / exit", "[KLIK KIRI] Ambil %s": "[LEFT CLICK] Pick up %s",
	"[KLIK KIRI] Buka / tutup pintu": "[LEFT CLICK] Open / close door", "[TAHAN KLIK KANAN] Sembuhkan teman": "[HOLD RIGHT CLICK] Heal friend",
	"[TAHAN KLIK KIRI] Gambar jawaban": "[HOLD LEFT CLICK] Draw answer",
	"%s diambil dan dipilih.": "%s picked up and selected.", "%s dibuang.": "%s dropped.", "DIPAKAI: %s": "USED: %s", "Dipilih: %s.": "Selected: %s.",
	"Inventory penuh: %d/%d slot. Buang salah satu item terlebih dahulu.": "Inventory full: %d/%d slots. Drop an item first.",
	"Klik kanan tidak melakukan apa-apa di sini.": "Right click does nothing here.", "Klik kanan tidak melakukan apa-apa pada objek ini.": "Right click does nothing on this object.",
	"Menggambar di papan tulis... tahan klik kiri dan gerakkan pandangan.": "Drawing on the board... hold left click and move your view.",
	"MENYEMBUHKAN %d%%": "HEALING %d%%", "Penyembuhan dibatalkan.": "Healing cancelled.",
	"Pilih Kertas Soal terlebih dahulu.": "Select the Exam Paper first.", "Pilih Medkit di inventory terlebih dahulu.": "Select the Medkit in your inventory first.",
	"Tahan klik kanan sampai selesai.": "Hold right click until finished.", "Teman berhasil disembuhkan. 1 medkit digunakan.": "Friend healed. 1 medkit used.",
	"Teman ini sudah disembuhkan.": "This friend is already healed.", "TEMAN\\nSUDAH DISEMBUHKAN": "FRIEND\\nALREADY HEALED",
	"Tidak ada item yang dipilih untuk dibuang.": "No item selected to drop.",
	"Tidak ada objek yang bisa diinteraksikan tepat di depanmu.": "There is nothing to interact with right in front of you.",
	"Tidak punya kapur. Ambil kapur terlebih dahulu.": "You have no chalk. Pick up chalk first.",
	"Belum ada goresan, jadi kertas dan kapur tidak digunakan.": "No strokes yet, so the paper and chalk were not used.",
	"Jawaban test selesai. 1 kertas + 1 kapur digunakan.": "Test answer finished. 1 paper + 1 chalk used.",
	"Ambil Kertas Soal dan Kapur.": "Pick up the Exam Paper and Chalk.", "Arahkan pandangan ke papan untuk mulai menulis.": "Aim at the board to start writing.",
	"Arahkan pandangan ke papan.": "Aim at the board.", "Jawaban benar.": "Correct answer.", "Kamu membutuhkan Kapur.": "You need Chalk.",
	"Keluar dari papan.": "Left the board.", "Klik kanan harus mengenai papan.": "Right click must hit the board.",	# Template karakter sudah didefinisikan pada bagian kamus UI inti.
}

func _ready() -> void:
	# Tetap berjalan saat game di-pause (menu jeda), dan berjalan PALING AKHIR di setiap
	# frame supaya teks yang ditulis ulang oleh skrip game langsung diterjemahkan sebelum digambar.
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 100000
	_build_rules()
	_load_language()
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_walk_all")

func _process(_delta: float) -> void:
	# Hanya node berteks yang terdaftar yang diperiksa (bukan seluruh pohon scene), dan
	# pemeriksaan murah: teks yang tidak berubah dilewati.
	var index := _tracked.size() - 1
	while index >= 0:
		var entry: Variant = _tracked[index]
		if not is_instance_valid(entry):
			_tracked.remove_at(index)
		elif current_language == LANG_EN and (entry as Node).is_inside_tree():
			_apply_node(entry as Node, false)
		index -= 1

func set_language(language_code: String) -> void:
	var normalized := LANG_EN if language_code.to_lower().begins_with("en") else LANG_ID
	if current_language == normalized:
		return
	current_language = normalized
	_cache.clear()
	_save_language()
	_walk_all()
	language_changed.emit(current_language)

func get_language() -> String:
	return current_language

func translate_text(source_text: String) -> String:
	return _translate_source(source_text)

func _translate_source(source_text: String) -> String:
	if current_language != LANG_EN or source_text.is_empty():
		return source_text
	if _cache.has(source_text):
		return String(_cache[source_text])
	var result := _translate_uncached(source_text)
	if _cache.size() >= CACHE_LIMIT:
		_cache.clear()
	_cache[source_text] = result
	return result

func _translate_uncached(source_text: String) -> String:
	if ENGLISH.has(source_text):
		return String(ENGLISH[source_text])
	# Label3D papan cerita memakai baris baru; cocokkan juga bentuk escape-nya.
	var escaped_text := source_text.replace("\n", "\\n")
	if escaped_text != source_text and ENGLISH.has(escaped_text):
		return String(ENGLISH[escaped_text]).replace("\\n", "\n")
	# Template dengan %s / %d: dicocokkan utuh (bukan hanya awalan) sehingga bagian
	# belakang kalimat ikut diterjemahkan.
	for rule in _templates:
		var matched: RegExMatch = (rule["regex"] as RegEx).search(source_text)
		if matched != null:
			return _fill_template(String(rule["english"]), matched)
	# Awalan label ("Interaksi: ", "KLIK KIRI — Ambil ") diikuti nilai dinamis.
	for rule in _prefix_rules:
		var prefix := String(rule["source"])
		if source_text.begins_with(prefix):
			var remainder := source_text.substr(prefix.length())
			if ENGLISH.has(remainder):
				remainder = String(ENGLISH[remainder])
			return String(rule["english"]) + remainder
	# Teks beberapa baris (kertas ujian, status HUD): terjemahkan per baris.
	if source_text.contains("\n"):
		var lines := source_text.split("\n")
		var changed := false
		var output := PackedStringArray()
		for line in lines:
			var translated_line := _translate_source(line) if not line.strip_edges().is_empty() else line
			if translated_line != line:
				changed = true
			output.append(translated_line)
		if changed:
			return "\n".join(output)
	return source_text

func _build_rules() -> void:
	_templates.clear()
	_prefix_rules.clear()
	for key in ENGLISH.keys():
		var source_key := String(key)
		var english_value := String(ENGLISH[key])
		if source_key.contains("%"):
			var compiled := _compile_template(source_key)
			if compiled != null:
				_templates.append({"regex": compiled, "english": english_value, "weight": source_key.length() - source_key.count("%") * 2})
		elif source_key.length() >= 8 and (source_key.ends_with(" ") or source_key.ends_with(": ")):
			_prefix_rules.append({"source": source_key, "english": english_value})
	# Aturan paling spesifik (paling panjang) dicoba lebih dulu.
	_templates.sort_custom(func(a, b): return int(a["weight"]) > int(b["weight"]))
	_prefix_rules.sort_custom(func(a, b): return String(a["source"]).length() > String(b["source"]).length())

# Mengubah "Slot %d kosong." menjadi regex berjangkar penuh dengan grup tangkapan.
func _compile_template(template_text: String) -> RegEx:
	var pattern := "(?s)^"
	var i := 0
	while i < template_text.length():
		var ch := template_text[i]
		if ch == "%" and i + 1 < template_text.length():
			if template_text[i + 1] == "%":
				pattern += "%"
				i += 2
				continue
			var j := i + 1
			while j < template_text.length() and (template_text[j] == "." or template_text[j] == "-" or template_text[j].is_valid_int()):
				j += 1
			if j < template_text.length() and "sdf".contains(template_text[j]):
				pattern += "(.+?)" if template_text[j] == "s" else "(-?[0-9]+(?:[.,][0-9]+)?)"
				i = j + 1
				continue
		if "\\.^$|()[]{}*+?".contains(ch):
			pattern += "\\"
		pattern += ch
		i += 1
	pattern += "$"
	var regex := RegEx.create_from_string(pattern)
	if regex == null or not regex.is_valid():
		return null
	return regex

func _fill_template(english_template: String, matched: RegExMatch) -> String:
	var output := ""
	var capture_index := 1
	var i := 0
	while i < english_template.length():
		var ch := english_template[i]
		if ch == "%" and i + 1 < english_template.length():
			if english_template[i + 1] == "%":
				output += "%"
				i += 2
				continue
			var j := i + 1
			while j < english_template.length() and (english_template[j] == "." or english_template[j] == "-" or english_template[j].is_valid_int()):
				j += 1
			if j < english_template.length() and "sdf".contains(english_template[j]):
				var captured := matched.get_string(capture_index) if capture_index <= matched.get_group_count() else ""
				# Nilai teks (%s) ikut diterjemahkan bila berupa frasa yang dikenal.
				output += _translate_source(captured) if english_template[j] == "s" else captured
				capture_index += 1
				i = j + 1
				continue
		output += ch
		i += 1
	return output

func _load_language() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		current_language = LANG_EN if String(cfg.get_value("language", "code", LANG_ID)) == LANG_EN else LANG_ID

func _save_language() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("language", "code", current_language)
	cfg.save(SETTINGS_PATH)

func _is_text_node(node: Node) -> bool:
	return node is Label3D or node is Button or node is Label or node is RichTextLabel or node is LineEdit or node is TextEdit

func _text_property(node: Node) -> StringName:
	if node is LineEdit or node is TextEdit:
		return &"placeholder_text"
	return &"text"

func _on_node_added(node: Node) -> void:
	# Hanya mendaftarkan node berteks yang baru muncul. Tidak ada lagi penelusuran
	# seluruh pohon scene untuk setiap node yang ditambahkan.
	if _is_text_node(node):
		_register(node)

func _register(node: Node) -> void:
	if node.has_meta(META_TRACKED):
		return
	node.set_meta(META_TRACKED, true)
	_tracked.append(node)

func _walk_all() -> void:
	if not is_inside_tree():
		return
	_walk(get_tree().root)

func _walk(node: Node) -> void:
	if _is_text_node(node):
		_register(node)
		_apply_node(node, true)
	elif node is Control:
		_apply_property(node, &"tooltip_text", META_TIP_ORIGINAL, META_TIP_LAST, true)
	for child in node.get_children():
		_walk(child)

func _apply_node(node: Node, force: bool) -> void:
	_apply_property(node, _text_property(node), META_ORIGINAL, META_LAST, force)
	if node is Control:
		_apply_property(node, &"tooltip_text", META_TIP_ORIGINAL, META_TIP_LAST, force)

func _apply_property(node: Object, property_name: StringName, key_original: StringName, key_last: StringName, force: bool) -> void:
	var current := String(node.get(property_name))
	if current.is_empty():
		return
	var has_last: bool = node.has_meta(key_last)
	var rendered_by_us: bool = has_last and current == String(node.get_meta(key_last))
	if rendered_by_us and not force:
		return
	# Jika teks sekarang bukan hasil render kita, berarti skrip game baru menulisnya.
	var original := String(node.get_meta(key_original, current)) if rendered_by_us else current
	node.set_meta(key_original, original)
	var shown := _translate_source(_context_override(node, original))
	if current != shown:
		node.set(property_name, shown)
	node.set_meta(key_last, shown)

# Kata yang sama bisa berarti lain tergantung tempatnya: tombol KELUAR pada HUD
# adalah "keluar dari tempat sembunyi", bukan "keluar dari game".
func _context_override(node: Object, original: String) -> String:
	if original == "KELUAR" and node is Button:
		var parent: Node = (node as Node).get_parent()
		while parent != null:
			var parent_name := String(parent.name)
			if parent_name.contains("Mobile") or parent_name.contains("HUD"):
				return "KELUAR DARI PERSEMBUNYIAN"
			parent = parent.get_parent()
	return original
