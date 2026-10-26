$ErrorActionPreference='Stop'
$dir='C:\Users\LENOVO\Documents\prototipe-1'
$p=Join-Path $dir 'Map58Game.gd'
$s=[IO.File]::ReadAllText($p)
$pattern='(?s)\t\tPHASE_HUNT:\r?\n.*?(?=\t\tPHASE_BOARD_SOLVING:)'
$replacement=@'
		PHASE_HUNT:
			if initial_teacher_remaining > 0.0:
				initial_teacher_remaining = maxf(0.0, initial_teacher_remaining - delta)
				if initial_teacher_remaining <= 0.0:
					_start_ghost_mode()
			elif berserk_remaining > 0.0:
				berserk_remaining = maxf(0.0, berserk_remaining - delta)
				if berserk_remaining <= 0.0 and teacher_mode == BERSERK:
					berserk_target = null
					_set_teacher_mode(GHOST, null)
					_set_status("Mode bersek berakhir. Guru kembali mengejar secara normal.")
			elif calm_remaining > 0.0:
				calm_remaining = maxf(0.0, calm_remaining - delta)
				if calm_remaining <= 0.0:
					_start_ghost_mode()
'@
$s2=[regex]::Replace($s,$pattern,[System.Text.RegularExpressions.MatchEvaluator]{param($m) $replacement+"`r`n"},1)
if($s2 -eq $s){throw 'PHASE_HUNT block not found'}
$s=$s2
$pattern='(?s)func _start_hunt\(\) -> void:.*?(?=\r?\nfunc begin_board_question\()'
$replacement=@'
func _start_hunt() -> void:
	var ending_transition := phase == PHASE_TRANSITION
	if ending_transition:
		intro_blackout_remaining = -1.0
		intro_departure_active = false
		_set_intro_locked(false)
		_hide_intro_paper()
		var player := get_tree().get_first_node_in_group("players") as CharacterBody3D
		if player != null:
			player.set_meta("intro_sitting", false)
	_set_phase(PHASE_HUNT)
	berserking_end()
	calm_remaining = 0.0
	berserk_remaining = 0.0
	hunt_remaining = 0.0
	initial_teacher_remaining = randf_range(INITIAL_TEACHER_MIN_TIME, INITIAL_TEACHER_MAX_TIME)
	_set_teacher_mode(TEACHER, null)
	_set_status("Cari Kunci Kelas, Kertas Soal, dan Kapur. Guru masih berpatroli.")
	_update_objective()


func _start_ghost_mode() -> void:
	if phase != PHASE_HUNT or calm_remaining > 0.0 or berserk_remaining > 0.0:
		return
	initial_teacher_remaining = 0.0
	hunt_remaining = 0.0
	_set_teacher_mode(GHOST, null)
	_set_status("Mode Hantu aktif. Guru akan terus mengejar sampai kamu menjawab soal papan tulis dengan benar.")
'@
$s2=[regex]::Replace($s,$pattern,[System.Text.RegularExpressions.MatchEvaluator]{param($m) $replacement+"`r`n"},1)
if($s2 -eq $s){throw 'start hunt block not found'}
$s=$s2.Replace('active_timer = max(calm_remaining, hunt_remaining, berserk_remaining)','active_timer = max(initial_teacher_remaining, calm_remaining, hunt_remaining, berserk_remaining)')
[IO.File]::WriteAllText($p,$s,(New-Object System.Text.UTF8Encoding($false)))
$p=Join-Path $dir 'PintuKelas.gd'
$s=[IO.File]::ReadAllText($p)
$old=@'
        # Pintu berkunci benar-benar menolak semua aktor, termasuk guru.
        if _is_teacher_actor(player):
            return
        if player == null:
            return

        var inventory := player.get_node_or_null("ItemInventory")
        if inventory == null or not inventory.has_item(required_item_type):
            _set_locked_status(player)
            return
'@
$new=@'
        # Guru boleh membuka pintu untuk patroli; murid tetap perlu kunci.
        if not _is_teacher_actor(player):
            if player == null:
                return

            var inventory := player.get_node_or_null("ItemInventory")
            if inventory == null or not inventory.has_item(required_item_type):
                _set_locked_status(player)
                return
'@
if(-not $s.Contains($old)){throw 'locked-door code not found'}
$s=$s.Replace($old,$new)
[IO.File]::WriteAllText($p,$s,(New-Object System.Text.UTF8Encoding($false)))
'Patched timer state, HUD timer, and teacher access to locked classroom doors.'