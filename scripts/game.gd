extends Control
## 화면과 입력. 규칙은 GMatch, 온라인은 GSession 이 맡는다.

const NetScript := preload("res://scripts/net.gd")
const BOLD := preload("res://fonts/IBMPlexSansKR-Bold.ttf")
const LEFT_W := 216.0
const RIGHT_W := 240.0
const TOP_H := 52.0
const BOTTOM_H := 112.0
const P_COLORS := [Color("4fa8ff"), Color("ff9f43")]
const P_MARKS := ["●", "◆"]
const TOWER_COLORS := {"gun": Color("d9dde3"), "cannon": Color("e0764a"), "cold": Color("6fdcf2")}
const ENEMY_COLORS := {"grunt": Color("c9524f"), "swarm": Color("e8b23f"), "heavy": Color("7d8794"), "rusher": Color("c65fd0"), "boss": Color("8c1f3f")}
const PRIO := {"first": "선두", "last": "후미", "strong": "강한 적"}

var net: Node
var s: GSession
var web := false
var room := ""

var cell := 34.0
var origin := Vector2.ZERO
var mode := ""            # build:gun | road:detour | move:id | ability | ping:look
var selected := -1
var hover := Vector2(-1, -1)
var hover_edit := {}
var _sent_draft := ""
var _fxs: Array = []
var _disp := {}
var _shake := 0.0
var _flash := Vector2(-1, -1)
var _flash_t := 0.0
var _toast := ""
var _toast_t := 0.0
var _chat_n := -1
var _sync_key := ""
var _ui_key := ""
var _tick := 0.0

var menu: Control
var menu_msg: Label
var lobby: Control
var lobby_info: Label
var lobby_start: Button
var hud: Control
var top_label: Label
var team_label: Label
var chat_box: RichTextLabel
var info_label: Label
var up_btn: Button
var a_btn: Button
var b_btn: Button
var move_btn: Button
var sell_btn: Button
var prio_row: HBoxContainer
var build_btns := {}
var road_btns := {}
var confirm_btn: Button
var cancel_btn: Button
var ability_btn: Button
var ping_btn: Button
var ready_btn: Button
var ping_row: HBoxContainer
var overlay: PanelContainer
var overlay_label: Label
var overlay_btn: Button


func _ready() -> void:
	net = NetScript.new()
	add_child(net)
	web = OS.has_feature("web") and net.available
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_menu()
	_build_lobby()
	_build_hud()
	_show("menu")
	if web:
		room = net.room_param()
	if room != "":
		menu_msg.text = "친구의 방에 초대받았어요. 이름을 정하고 입장하세요."
	get_viewport().size_changed.connect(_place_fields)
	_place_fields.call_deferred()
	_refresh_menu_buttons()


# ── 화면 만들기 ──

func _panel(rect: Rect2, parent: Control = self) -> PanelContainer:
	var p := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.09, 0.12, 0.10, 0.96)
	st.border_color = Color(0.27, 0.34, 0.26)
	st.set_border_width_all(1)
	st.set_corner_radius_all(6)
	st.set_content_margin_all(9)
	p.add_theme_stylebox_override("panel", st)
	p.position = rect.position
	p.size = rect.size
	parent.add_child(p)
	return p


func _btn(parent: Control, text: String, cb: Callable, w := 0.0, h := 34.0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(w, h)
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", Color("f4f1e4"))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color("1b1a12"))
	b.add_theme_color_override("font_hover_pressed_color", Color("1b1a12"))
	b.add_theme_color_override("font_disabled_color", Color(0.72, 0.74, 0.68, 0.48))
	var looks := {"normal": Color("3c5240"), "hover": Color("4f6d53"), "pressed": Color("f0c75e"), "hover_pressed": Color("f0c75e"), "disabled": Color("232c25")}
	for k in looks:
		var box := StyleBoxFlat.new()
		box.bg_color = looks[k]
		box.border_color = Color("70886f") if k != "disabled" else Color("364036")
		box.set_border_width_all(1)
		box.set_corner_radius_all(5)
		box.set_content_margin_all(3)
		b.add_theme_stylebox_override(k, box)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _label(parent: Control, text := "", size_px := 14, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	if bold:
		l.add_theme_font_override("font", BOLD)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l


func _build_menu() -> void:
	menu = Control.new()
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(menu)
	var box := VBoxContainer.new()
	box.name = "Box"
	box.custom_minimum_size = Vector2(360, 0)
	box.add_theme_constant_override("separation", 10)
	menu.add_child(box)
	var title := _label(box, "길 좀 막아봐", 46, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := _label(box, "친구와 적의 길을 고치고, 포탑을 세워 성을 지키세요", 14)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var gap := Control.new()
	gap.name = "NameGap"
	gap.custom_minimum_size = Vector2(0, 58)
	box.add_child(gap)
	_btn(box, "친구와 함께 (방 만들기)", _on_host, 0, 44).name = "HostBtn"
	_btn(box, "초대받은 방 입장", _on_join, 0, 44).name = "JoinBtn"
	_btn(box, "혼자 연습 (봇 동료)", _on_solo, 0, 44)
	menu_msg = _label(box, "", 13)
	menu_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _build_lobby() -> void:
	lobby = Control.new()
	lobby.set_anchors_preset(Control.PRESET_FULL_RECT)
	lobby.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lobby)
	var box := VBoxContainer.new()
	box.name = "Box"
	box.custom_minimum_size = Vector2(400, 0)
	box.add_theme_constant_override("separation", 12)
	lobby.add_child(box)
	var t := _label(box, "대기실", 30, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lobby_info = _label(box, "", 16)
	lobby_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_btn(box, "초대 링크 복사", _on_copy, 0, 40)
	lobby_start = _btn(box, "경기 시작", _on_start, 0, 46)
	_btn(box, "나가기", _on_leave, 0, 34)


func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)

	var top := _panel(Rect2(), hud)
	top.name = "Top"
	top_label = _label(top, "", 16, true)
	top_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var left := _panel(Rect2(), hud)
	left.name = "Left"
	var lv := VBoxContainer.new()
	left.add_child(lv)
	team_label = _label(lv, "", 13)
	chat_box = RichTextLabel.new()
	chat_box.bbcode_enabled = false      # 사용자 입력이 서식으로 해석되지 않게
	chat_box.scroll_following = true
	chat_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_box.add_theme_font_size_override("normal_font_size", 13)
	chat_box.meta_clicked.connect(_on_chat_link)
	lv.add_child(chat_box)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 38)
	lv.add_child(pad)

	var right := _panel(Rect2(), hud)
	right.name = "Right"
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 6)
	right.add_child(rv)
	info_label = _label(rv, "", 13)
	info_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	prio_row = HBoxContainer.new()
	rv.add_child(prio_row)
	for k in PRIO:
		var b := _btn(prio_row, PRIO[k], _on_prio.bind(k), 0, 30)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.toggle_mode = true
		b.set_meta("prio", k)
	up_btn = _btn(rv, "강화", _on_upgrade.bind(""))
	a_btn = _btn(rv, "A", _on_upgrade.bind("a"))
	b_btn = _btn(rv, "B", _on_upgrade.bind("b"))
	var row := HBoxContainer.new()
	rv.add_child(row)
	move_btn = _btn(row, "이동 (무료)", _on_move)
	sell_btn = _btn(row, "판매", _on_sell)
	move_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var bottom := _panel(Rect2(), hud)
	bottom.name = "Bottom"
	var bv := VBoxContainer.new()
	bottom.add_child(bv)
	ping_row = HBoxContainer.new()
	bv.add_child(ping_row)
	for k in GData.PING_KINDS:
		_btn(ping_row, GData.PING_KINDS[k], _on_ping_kind.bind(k), 0, 28)
	ping_row.visible = false
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 5)
	bv.add_child(bar)
	var keys := {"gun": "1", "cannon": "2", "cold": "3"}
	for k in ["gun", "cannon", "cold"]:
		build_btns[k] = _btn(bar, "%s\n%dG [%s]" % [GData.TOWERS[k]["name"], GData.TOWERS[k]["cost"], keys[k]], _set_mode.bind("build:" + k), 82, 56)
	bar.add_child(VSeparator.new())
	road_btns["detour"] = _btn(bar, "우회로\n+4칸 [Q]", _set_mode.bind("road:detour"), 72, 56)
	road_btns["bend"] = _btn(bar, "굽잇길\n+2칸 [W]", _set_mode.bind("road:bend"), 72, 56)
	var cv := VBoxContainer.new()
	bar.add_child(cv)
	confirm_btn = _btn(cv, "길 확정 [E]", _on_confirm, 78, 27)
	cancel_btn = _btn(cv, "취소", _on_cancel_draft, 78, 27)
	bar.add_child(VSeparator.new())
	ability_btn = _btn(bar, "긴급 냉각\n[F]", _set_mode.bind("ability"), 72, 56)
	ping_btn = _btn(bar, "핑\n[G]", _on_ping_menu, 44, 56)
	ready_btn = _btn(bar, "준비 완료\n[Space]", _on_ready, 86, 56)

	overlay = _panel(Rect2(), hud)
	overlay.name = "Overlay"
	var ov := VBoxContainer.new()
	ov.add_theme_constant_override("separation", 10)
	overlay.add_child(ov)
	overlay_label = _label(ov, "", 15)
	overlay_btn = _btn(ov, "같은 멤버로 재도전", _on_overlay, 0, 42)
	overlay.visible = false


func _show(which: String) -> void:
	menu.visible = which == "menu"
	lobby.visible = which == "lobby"
	hud.visible = which == "game"
	if web:
		var ui = JavaScriptBridge.get_interface("GilUI")
		if which == "menu":
			var saved := str(ui.saved())
			ui.show("name", "내 이름 (10자)", 10, 0, 0, 10, 1, true)
			ui.put("name", saved)
		else:
			ui.hide("name")
		if which != "game":
			ui.hide("chat")
	_place_fields()


func _place_fields() -> void:
	var v := get_viewport_rect().size
	_layout(v)
	for parent in [menu, lobby]:
		var box: Control = parent.get_node("Box")
		box.reset_size()
		box.position = (v - box.size) * 0.5
	if not web:
		return
	var ui = JavaScriptBridge.get_interface("GilUI")
	var canvas = JavaScriptBridge.get_interface("document").querySelector("canvas")
	var scale: float = float(canvas.getBoundingClientRect().width) / maxf(v.x, 1.0)
	if menu.visible:
		var gap: Control = menu.get_node("Box/NameGap")
		ui.show("name", "내 이름 (10자)", 10, gap.global_position.x, gap.global_position.y + 10, gap.size.x, scale, true)
	if hud.visible:
		ui.show("chat", "Enter로 채팅", GSession.CHAT_MAX, 12.0, v.y - BOTTOM_H + 66, LEFT_W - 16, scale, false)


func _layout(v: Vector2) -> void:
	var map_w := v.x - LEFT_W - RIGHT_W - 16
	var map_h := v.y - TOP_H - BOTTOM_H - 12
	cell = floorf(minf(map_w / GData.W, map_h / GData.H))
	origin = Vector2(LEFT_W + 8 + (map_w - cell * GData.W) * 0.5, TOP_H + 6 + (map_h - cell * GData.H) * 0.5)
	var top: Control = hud.get_node("Top")
	top.position = Vector2(LEFT_W + 8, 4)
	top.size = Vector2(v.x - LEFT_W - RIGHT_W - 16, TOP_H - 8)
	var left: Control = hud.get_node("Left")
	left.position = Vector2(4, 4)
	left.size = Vector2(LEFT_W, v.y - 8)
	var right: Control = hud.get_node("Right")
	right.position = Vector2(v.x - RIGHT_W - 4, 4)
	right.size = Vector2(RIGHT_W, v.y - 8)
	var bottom: Control = hud.get_node("Bottom")
	bottom.position = Vector2(LEFT_W + 8, v.y - BOTTOM_H + 18)
	bottom.size = Vector2(v.x - LEFT_W - RIGHT_W - 16, BOTTOM_H - 22)
	overlay.size = Vector2(460, 0)
	overlay.reset_size()
	overlay.size.x = 460
	overlay.position = Vector2((v.x - 460) * 0.5, maxf(70, (v.y - overlay.size.y) * 0.5))


# ── 메뉴 동작 ──

func _player_name() -> String:
	if web:
		var ui = JavaScriptBridge.get_interface("GilUI")
		var n := str(ui.value("name")).strip_edges().left(10)
		if n == "":
			n = "플레이어"
		ui.save(n)
		return n
	return "플레이어"


func _refresh_menu_buttons() -> void:
	var host_btn: Button = menu.get_node("Box/HostBtn")
	var join_btn: Button = menu.get_node("Box/JoinBtn")
	join_btn.visible = room != ""
	host_btn.visible = room == ""
	if not web:
		host_btn.disabled = true
		host_btn.tooltip_text = "친구 초대는 웹 빌드에서만 돼요"


func _on_host() -> void:
	s = GSession.new(net, _player_name(), net.token())
	net.host()
	s.open_host()
	_show("lobby")


func _on_join() -> void:
	s = GSession.new(net, _player_name(), net.token())
	s.open_client()
	net.join(room)
	_show("lobby")


func _on_solo() -> void:
	s = GSession.new(null, _player_name(), "me")
	s.open_host(true)
	_enter_game()


func _on_copy() -> void:
	net.copy(net.invite_url(net.code()))
	_say("초대 링크를 복사했어요")


func _on_start() -> void:
	var err := s.start_match()
	if err != "":
		_say(err)
	else:
		_enter_game()


func _on_leave() -> void:
	net.close()
	s = null
	_show("menu")


func _enter_game() -> void:
	mode = ""
	selected = -1
	_chat_n = -1
	_fxs = []
	_disp = {}
	_show("game")


# ── 매 프레임 ──

func _process(delta: float) -> void:
	_tick += delta
	_toast_t -= delta
	_shake = maxf(_shake - delta * 3.0, 0.0)
	_flash_t -= delta
	if s == null:
		queue_redraw()
		return
	s.tick(delta)
	while not s.toasts.is_empty():
		_say(str(s.toasts.pop_front()))
	if s.state == "game" and not hud.visible:
		_enter_game()
	if lobby.visible:
		_update_lobby()
	if hud.visible and s.m:
		_take_chat()
		_predict(delta)
		_take_fx()
		_update_hover()
		_update_hud()
	for i in range(_fxs.size() - 1, -1, -1):
		_fxs[i]["t"] -= delta
		if _fxs[i]["t"] <= 0.0:
			_fxs.remove_at(i)
	queue_redraw()


func _say(text: String) -> void:
	_toast = text
	_toast_t = 2.6
	if menu_msg and menu.visible:
		menu_msg.text = text


func _update_lobby() -> void:
	var lines := []
	if s.is_host:
		var st: String = net.status()
		if st == "hosting":
			lines.append("방 코드  %s" % net.code().to_upper())
		elif st == "error":
			lines.append("방을 열지 못했어요: %s" % net.error_text())
		else:
			lines.append("방을 여는 중…")
	else:
		var st: String = net.status()
		if st == "error":
			lines.append(net.error_text())
		elif s.seat < 0:
			lines.append("방에 들어가는 중…")
		else:
			lines.append("방장이 시작하기를 기다리는 중")
	for i in s.seats.size():
		lines.append("%s %d번  %s" % [P_MARKS[i], i + 1, s.seats[i]["name"]])
	if s.seats.size() < GSession.MAX_SEATS and s.is_host:
		lines.append("친구를 기다리는 중…")
	lobby_info.text = "\n".join(lines)
	lobby_start.visible = s.is_host
	lobby_start.disabled = s.seats.size() < 2


func _take_chat() -> void:
	if web:
		var ui = JavaScriptBridge.get_interface("GilUI")
		var sent = JSON.parse_string(str(ui.take("chat")))
		if sent is Array:
			for text in sent:
				s.command({"op": "chat", "text": str(text)})
	var pending := 0
	for o in s.outbox:
		if o["c"].get("op", "") == "chat":
			pending += 1
	var key := "%d:%d" % [s.chat.size(), pending]
	if s.chat.is_empty() and pending == 0:
		key = "0"
	if s.chat.size() > 0:
		key += str(str(s.chat[-1].get("text", "")).hash())
	if key == _sync_key:
		return
	_sync_key = key
	chat_box.clear()
	for row in s.chat:
		var who := int(row["seat"])
		var col: Color = Color("9fb39a") if who < 0 else P_COLORS[who % 2]
		chat_box.push_color(col)
		chat_box.add_text(("%s %s: " % [P_MARKS[who % 2], row["name"]]) if who >= 0 else "· ")
		chat_box.pop()
		if row.has("x"):
			chat_box.push_meta("%f,%f" % [float(row["x"]), float(row["y"])])
			chat_box.push_color(Color("ffd76a"))
			chat_box.add_text(str(row["text"]))
			chat_box.pop()
			chat_box.pop()
		else:
			chat_box.add_text(str(row["text"]))
		chat_box.newline()
	if pending > 0:
		chat_box.push_color(Color(1, 1, 1, 0.45))
		chat_box.add_text("전송 중… (%d)" % pending)
		chat_box.pop()


func _on_chat_link(meta) -> void:
	var p := str(meta).split(",")
	if p.size() == 2:
		_flash = Vector2(float(p[0]), float(p[1]))
		_flash_t = 2.5


func _predict(delta: float) -> void:
	var alive := {}
	for en in s.m.enemies:
		var id := int(en["id"])
		alive[id] = true
		if not s.is_host:
			en["dist"] = float(en["dist"]) + float(GData.ENEMIES[en["type"]]["speed"]) * (1.0 - float(en["slow"])) * delta
		var cur: float = _disp.get(id, float(en["dist"]))
		_disp[id] = lerpf(cur, float(en["dist"]), 1.0 - exp(-14.0 * delta))
	for id in _disp.keys():
		if not alive.has(id):
			_disp.erase(id)


func _take_fx() -> void:
	for f in s.fx:
		match str(f["k"]):
			"shot":
				_fxs.append({"k": "shot", "ty": f["ty"], "a": Vector2(f["x"], f["y"]), "b": Vector2(f["tx"], f["ty2"]), "r": float(f["r"]), "t": 0.16, "life": 0.16})
			"ability":
				_fxs.append({"k": "ability", "a": Vector2(f["x"], f["y"]), "o": int(f["o"]), "t": 0.8, "life": 0.8})
			"hit":
				_shake = 1.0
	s.fx = []
	if _fxs.size() > 90:
		_fxs = _fxs.slice(_fxs.size() - 90)


func _update_hover() -> void:
	var mouse := get_local_mouse_position()
	var grid := (mouse - origin) / cell
	var inside := grid.x >= 0 and grid.y >= 0 and grid.x < GData.W and grid.y < GData.H and get_viewport().gui_get_hovered_control() == self
	hover = grid if inside else Vector2(-1, -1)
	hover_edit = {}
	if mode.begins_with("road:") and inside and s.m.phase == "prep" and s.m.road_owner == s.seat and s.m.edits_left > 0:
		hover_edit = s.m.board.best_edit(grid, mode.substr(5), s.m.tower_cells())


func _update_hud() -> void:
	var m := s.m
	var phase_text := {"prep": "준비", "combat": "전투", "over": "종료"}
	top_label.text = "성 %d/%d   ·   웨이브 %d/%d (%s)   ·   초원   ·   길 개조 %d회" % [m.hp, GData.CASTLE_HP, m.wave, GData.LAST_WAVE, phase_text[m.phase], m.edits_left]
	var lines := []
	for i in m.players.size():
		var p: Dictionary = m.players[i]
		var tags := []
		if i == m.road_owner:
			tags.append("길 담당")
		if not p["online"]:
			tags.append("끊김")
		elif p["ready"]:
			tags.append("준비됨")
		lines.append("%s %s%s  %dG\n   %s" % [P_MARKS[i], p["name"], " (나)" if i == s.seat else "", p["gold"], " · ".join(tags)])
	team_label.text = "\n".join(lines)
	_update_right()
	_update_bottom()
	_update_overlay()


func _update_right() -> void:
	var m := s.m
	if selected >= 0 and not m.towers.has(selected):
		selected = -1
	var t: Dictionary = m.towers.get(selected, {})
	var mine := not t.is_empty() and int(t["owner"]) == s.seat
	var prep := m.phase == "prep"
	prio_row.visible = mine
	up_btn.visible = false
	a_btn.visible = false
	b_btn.visible = false
	move_btn.get_parent().visible = mine and prep
	if t.is_empty():
		info_label.text = _next_wave_text()
		return
	var d: Dictionary = GData.TOWERS[t["type"]]
	var st := GData.tower_stats(t["type"], int(t["lv"]), str(t["branch"]))
	var cover := Board.coverage(Vector2i(int(t["x"]), int(t["y"])), float(st["range"]), m.board.paths)
	var text := "%s  %d단계\n소유: %s %s\n\n피해 %.0f · 간격 %.2f초\n사거리 %.1f칸" % [d["name"], t["lv"], P_MARKS[int(t["owner"])], m.players[int(t["owner"])]["name"], st["dmg"], st["cd"], st["range"]]
	if st["splash"] > 0.0:
		text += " · 범위 %.1f" % st["splash"]
	if st["slow"] > 0.0:
		text += "\n감속 %d%%" % roundi(st["slow"] * 100)
	if st["pierce"] > 0.0:
		text += "\n방어 관통 %.0f" % st["pierce"]
	text += "\n\n사거리 안 길: %d칸" % cover
	if str(t["branch"]) != "":
		text += "\n강화: %s" % d[t["branch"]]["label"]
	info_label.text = text
	for b in prio_row.get_children():
		b.set_pressed_no_signal(b.get_meta("prio") == t["prio"])
	if mine and prep:
		var gold: int = m.players[s.seat]["gold"]
		var lv := int(t["lv"])
		if lv == 1:
			up_btn.visible = true
			up_btn.text = "2단계 강화 (%dG)" % d["up"][0]
			up_btn.disabled = gold < int(d["up"][0])
		elif lv == 2:
			a_btn.visible = true
			b_btn.visible = true
			a_btn.text = "%s (%dG)" % [d["a"]["label"], d["up"][1]]
			b_btn.text = "%s (%dG)" % [d["b"]["label"], d["up"][1]]
			a_btn.disabled = gold < int(d["up"][1])
			b_btn.disabled = a_btn.disabled
		sell_btn.text = "판매 +%dG" % int(floor(int(t["spent"]) * GData.SELL_RATE))


func _next_wave_text() -> String:
	var m := s.m
	var counts := [{}, {}]
	for g in GData.WAVES[clampi(m.wave - 1, 0, GData.WAVES.size() - 1)]:
		var e := int(g[0])
		counts[e][g[1]] = int(counts[e].get(g[1], 0)) + int(g[2])
	var out := "웨이브 %d 적 구성\n" % m.wave
	for e in 2:
		out += "\n%d번 입구\n" % (e + 1)
		for k in counts[e]:
			out += "  %s ×%d\n" % [GData.ENEMIES[k]["name"], counts[e][k]]
	out += "\n맵의 포탑을 누르면 정보와 강화가 나와요.\n길 담당자는 우회로·굽잇길로 적의 길을 늘릴 수 있어요."
	return out


func _update_bottom() -> void:
	var m := s.m
	var prep := m.phase == "prep"
	var gold: int = m.players[s.seat]["gold"] if s.seat >= 0 else 0
	for k in build_btns:
		build_btns[k].disabled = not prep or gold < int(GData.TOWERS[k]["cost"])
	var can_road := prep and m.road_owner == s.seat and m.edits_left > 0
	for k in road_btns:
		road_btns[k].disabled = not can_road
	confirm_btn.disabled = not can_road or m.draft.is_empty()
	cancel_btn.disabled = m.road_owner != s.seat or m.draft.is_empty()
	ability_btn.disabled = m.phase != "combat" or bool(m.players[s.seat]["used"])
	ready_btn.disabled = not prep
	ready_btn.text = ("준비 취소\n[Space]" if m.players[s.seat]["ready"] else "준비 완료\n[Space]")


func _update_overlay() -> void:
	var m := s.m
	if s.state == "lost":
		overlay.visible = true
		overlay_label.text = "연결 종료\n\n방장과 연결이 끊겼어요. 패배 기록이 아니에요.\n방장이 돌아왔다면 다시 접속할 수 있어요."
		overlay_btn.text = "다시 접속"
		overlay_btn.disabled = false
		_layout(get_viewport_rect().size)
		return
	if m.phase != "over":
		overlay.visible = false
		return
	overlay.visible = true
	var head := "6웨이브 방어 성공! (테스트 구간 완료)" if m.cleared else "성이 무너졌어요"
	var last_ok: int = GData.LAST_WAVE if m.cleared else m.failed_wave - 1
	var text := "%s\n\n방어한 웨이브 %d" % [head, last_ok]
	if not m.cleared:
		text += " · 실패한 웨이브 %d" % m.failed_wave
	text += " · 전투 시간 %d초\n" % int(m.time)
	for i in m.players.size():
		var p: Dictionary = m.players[i]
		text += "\n%s %s\n   피해 %d · 처치 %d · 감속 %.0f · 지원 %d회" % [P_MARKS[i], p["name"], int(p["dmg"]), p["kills"], float(p["slow"]), p["support"]]
	overlay_label.text = text
	overlay_btn.text = "같은 멤버로 재도전" if s.is_host else "방장의 재도전을 기다리는 중"
	overlay_btn.disabled = not s.is_host
	_layout(get_viewport_rect().size)


# ── 입력 ──

func _set_mode(v: String) -> void:
	mode = "" if mode == v else v
	ping_row.visible = false
	if mode != "":
		selected = -1


func _on_ready() -> void:
	if s and s.m and s.m.phase == "prep":
		s.command({"op": "ready", "v": not bool(s.m.players[s.seat]["ready"])})
		mode = ""


func _on_prio(v: String) -> void:
	s.command({"op": "prio", "id": selected, "v": v})


func _on_upgrade(branch: String) -> void:
	s.command({"op": "upgrade", "id": selected, "branch": branch})


func _on_move() -> void:
	if selected >= 0:
		mode = "move:%d" % selected


func _on_sell() -> void:
	s.command({"op": "sell", "id": selected})
	selected = -1


func _on_confirm() -> void:
	var d: Dictionary = s.m.draft
	if d.is_empty():
		return
	s.command({"op": "edit", "e": d["e"], "i": d["i"], "kind": d["kind"], "side": d["side"]})
	mode = ""
	_sent_draft = ""


func _on_cancel_draft() -> void:
	s.command({"op": "draft"})
	_sent_draft = ""


func _on_ping_menu() -> void:
	ping_row.visible = not ping_row.visible


func _on_ping_kind(k: String) -> void:
	mode = "ping:" + k
	ping_row.visible = false


func _on_overlay() -> void:
	if s.state == "lost":
		net.join(net.code())
		s.state = "lobby"
		overlay.visible = false
	elif s.is_host:
		s.rematch()
		selected = -1


func _gui_input(ev: InputEvent) -> void:
	if s == null or s.m == null or not hud.visible:
		return
	if ev is InputEventMouseButton and ev.pressed:
		var grid: Vector2 = (ev.position - origin) / cell
		var inside := grid.x >= 0 and grid.y >= 0 and grid.x < GData.W and grid.y < GData.H
		if ev.button_index == MOUSE_BUTTON_RIGHT:
			mode = ""
			selected = -1
		elif ev.button_index == MOUSE_BUTTON_LEFT and inside:
			if ev.alt_pressed:
				s.command({"op": "ping", "kind": "look", "x": grid.x, "y": grid.y})
			else:
				_click(grid)


func _click(grid: Vector2) -> void:
	var c := Vector2i(grid)
	if mode.begins_with("build:"):
		s.command({"op": "build", "type": mode.substr(6), "x": c.x, "y": c.y})
		if not Input.is_key_pressed(KEY_SHIFT):
			mode = ""
	elif mode.begins_with("move:"):
		s.command({"op": "move", "id": int(mode.substr(5)), "x": c.x, "y": c.y})
		mode = ""
	elif mode.begins_with("road:"):
		if hover_edit.is_empty():
			_say("여기에는 이 길 조각을 놓을 수 없어요")
		else:
			s.command({"op": "draft", "e": hover_edit["e"], "i": hover_edit["i"], "kind": hover_edit["kind"], "side": hover_edit["side"]})
	elif mode == "ability":
		s.command({"op": "ability", "x": grid.x, "y": grid.y})
		mode = ""
	elif mode.begins_with("ping:"):
		s.command({"op": "ping", "kind": mode.substr(5), "x": grid.x, "y": grid.y})
		mode = ""
	else:
		var cells := s.m.tower_cells()
		selected = int(cells[c]) if cells.has(c) else -1


func _typing() -> bool:
	return web and bool(JavaScriptBridge.get_interface("GilUI").typing())


func _unhandled_key_input(ev: InputEvent) -> void:
	if s == null or s.m == null or not hud.visible or not ev.pressed or ev.echo or _typing():
		return
	match ev.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			if web:
				JavaScriptBridge.get_interface("GilUI").focus("chat")
		KEY_1: _key_mode("build:gun", build_btns["gun"])
		KEY_2: _key_mode("build:cannon", build_btns["cannon"])
		KEY_3: _key_mode("build:cold", build_btns["cold"])
		KEY_Q: _key_mode("road:detour", road_btns["detour"])
		KEY_W: _key_mode("road:bend", road_btns["bend"])
		KEY_E:
			if not confirm_btn.disabled:
				_on_confirm()
		KEY_F: _key_mode("ability", ability_btn)
		KEY_G: _on_ping_menu()
		KEY_SPACE: _on_ready()
		KEY_ESCAPE:
			mode = ""
			selected = -1
			ping_row.visible = false


func _key_mode(v: String, b: Button) -> void:
	if not b.disabled:
		_set_mode(v)


# ── 그리기 ──

func _p(g: Vector2) -> Vector2:
	return origin + g * cell + Vector2(sin(_tick * 60.0), cos(_tick * 53.0)) * _shake * 2.0


func _draw() -> void:
	if s == null or s.m == null or not hud.visible:
		_draw_menu_bg()
		return
	var m := s.m
	_draw_ground(m)
	for e in m.board.paths.size():
		_draw_path(m.board.paths[e], Color("a98a5b"), Color("8c7048"))
		_draw_arrows(m.board.paths[e])
	_draw_castle(m)
	_draw_gates(m)
	_draw_draft(m)
	for id in m.towers:
		_draw_tower(m.towers[id])
	for en in m.enemies:
		_draw_enemy(m, en)
	_draw_fx()
	_draw_pings()
	_draw_cursor(m)
	if _flash_t > 0.0:
		draw_arc(_p(_flash), cell * (0.7 + 0.3 * sin(_tick * 9.0)), 0, TAU, 28, Color("ffd76a"), 3.0)
	if _toast_t > 0.0:
		_text_box(Vector2(origin.x + cell * GData.W * 0.5, origin.y + 22), _toast, 15, Color("ffe6a6"))
	if s.host_away:
		_text_box(Vector2(origin.x + cell * GData.W * 0.5, origin.y + cell * GData.H - 18), "방장이 다른 탭을 보고 있어 게임이 잠시 멈췄어요", 15, Color("ff9f8f"))


func _draw_menu_bg() -> void:
	var v := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, v), Color("1a241d"))
	var size_px := 44.0
	var nx := int(v.x / size_px) + 1
	var ny := int(v.y / size_px) + 1
	for y in ny:
		for x in nx:
			if (x + y) % 2 == 0:
				draw_rect(Rect2(x * size_px, y * size_px, size_px, size_px), Color("1e2a21"))
	var pts := PackedVector2Array([Vector2(0, v.y * 0.2), Vector2(v.x * 0.16, v.y * 0.2), Vector2(v.x * 0.16, v.y * 0.72), Vector2(v.x * 0.3, v.y * 0.72)])
	draw_polyline(pts, Color(0.66, 0.54, 0.36, 0.28), 30.0)
	var pts2 := PackedVector2Array([Vector2(v.x, v.y * 0.8), Vector2(v.x * 0.84, v.y * 0.8), Vector2(v.x * 0.84, v.y * 0.28), Vector2(v.x * 0.7, v.y * 0.28)])
	draw_polyline(pts2, Color(0.66, 0.54, 0.36, 0.28), 30.0)
	if _toast_t > 0.0:
		_text_box(Vector2(v.x * 0.5, 40), _toast, 15, Color("ffe6a6"))


func _draw_ground(_m: GMatch) -> void:
	for y in GData.H:
		for x in GData.W:
			var col := Color("3f6b3c") if (x + y) % 2 == 0 else Color("3a643a")
			draw_rect(Rect2(_p(Vector2(x, y)), Vector2(cell, cell)), col)


func _draw_path(path: Array, col: Color, edge: Color) -> void:
	for c in path:
		draw_rect(Rect2(_p(Vector2(c)), Vector2(cell, cell)), edge)
	for c in path:
		draw_rect(Rect2(_p(Vector2(c)) + Vector2(1.5, 1.5), Vector2(cell - 3, cell - 3)), col)
	for i in range(1, path.size()):
		var a := _p(Vector2(path[i - 1]) + Vector2(0.5, 0.5))
		var b := _p(Vector2(path[i]) + Vector2(0.5, 0.5))
		draw_line(a, b, col, cell - 3)


func _draw_arrows(path: Array) -> void:
	var phase := fmod(_tick * 1.4, 3.0)
	var d := phase
	while d < path.size() - 1:
		var a := Board.pos_on(path, d)
		var b := Board.pos_on(path, d + 0.1)
		var dir := (b - a).normalized()
		var p := _p(a)
		var n := Vector2(-dir.y, dir.x)
		var tip := p + dir * cell * 0.17
		draw_colored_polygon(PackedVector2Array([tip, p - dir * cell * 0.1 + n * cell * 0.15, p - dir * cell * 0.1 - n * cell * 0.15]), Color(0.3, 0.22, 0.12, 0.55))
		d += 3.0


func _draw_castle(m: GMatch) -> void:
	var r := GData.CASTLE
	var at := _p(Vector2(r.position))
	var w := r.size.x * cell
	var h := r.size.y * cell
	draw_rect(Rect2(at, Vector2(w, h)), Color("4e5560"))
	draw_rect(Rect2(at + Vector2(4, 4), Vector2(w - 8, h - 8)), Color("6d7581"))
	for i in 4:
		var bx := at.x + 4 + (w - 8 - cell * 0.42) * i / 3.0
		draw_rect(Rect2(bx, at.y - cell * 0.18, cell * 0.42, cell * 0.42), Color("8a93a0"))
		draw_rect(Rect2(bx, at.y + h - cell * 0.24, cell * 0.42, cell * 0.42), Color("8a93a0"))
	draw_rect(Rect2(at + Vector2(w * 0.38, h * 0.5), Vector2(w * 0.24, h * 0.42)), Color("2e2a27"))
	draw_line(at + Vector2(w * 0.5, h * 0.42), at + Vector2(w * 0.5, h * 0.12), Color("e9e4d6"), 2.0)
	draw_colored_polygon(PackedVector2Array([at + Vector2(w * 0.5, h * 0.12), at + Vector2(w * 0.72, h * 0.2), at + Vector2(w * 0.5, h * 0.28)]), Color("e2574c"))
	var ratio := float(m.hp) / GData.CASTLE_HP
	draw_rect(Rect2(at + Vector2(4, -cell * 0.42), Vector2(w - 8, 6)), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(at + Vector2(4, -cell * 0.42), Vector2((w - 8) * ratio, 6)), Color("62d26f").lerp(Color("e2574c"), 1.0 - ratio))


func _draw_gates(m: GMatch) -> void:
	for e in m.board.paths.size():
		var c: Vector2i = m.board.paths[e][0]
		var center := _p(Vector2(c) + Vector2(0.5, 0.5))
		draw_circle(center, cell * 0.46, Color("2b1f26"))
		draw_arc(center, cell * 0.46, 0, TAU, 24, Color("ffd76a"), 2.0)
		_center_text(center, str(e + 1), int(cell * 0.56), Color("ffd76a"))


func _draw_draft(m: GMatch) -> void:
	var edit: Dictionary = hover_edit
	var shared := false
	if edit.is_empty() and not m.draft.is_empty():
		var r := m.board.reroute(int(m.draft["e"]), int(m.draft["i"]), str(m.draft["kind"]), int(m.draft["side"]), m.tower_cells())
		if r.has("path"):
			edit = m.draft.duplicate()
			edit["path"] = r["path"]
			shared = true
	if edit.is_empty():
		return
	var path: Array = edit["path"]
	var old: Array = m.board.paths[int(edit["e"])]
	var col := Color("ffd76a") if shared else Color("fff2bd")
	for c in path:
		if not old.has(c):
			draw_rect(Rect2(_p(Vector2(c)) + Vector2(2, 2), Vector2(cell - 4, cell - 4)), Color(col, 0.42))
	for c in old:
		if not path.has(c):
			var a := _p(Vector2(c))
			draw_line(a + Vector2(5, 5), a + Vector2(cell - 5, cell - 5), Color("e2574c"), 2.0)
			draw_line(a + Vector2(cell - 5, 5), a + Vector2(5, cell - 5), Color("e2574c"), 2.0)
	for i in range(1, path.size()):
		draw_dashed_line(_p(Vector2(path[i - 1]) + Vector2(0.5, 0.5)), _p(Vector2(path[i]) + Vector2(0.5, 0.5)), col, 2.5, 6.0)
	var trial: Array = m.board.paths.duplicate()
	trial[int(edit["e"])] = path
	var gain := 0
	for id in m.towers:
		var t: Dictionary = m.towers[id]
		var st := GData.tower_stats(t["type"], int(t["lv"]), str(t["branch"]))
		var c := Vector2i(int(t["x"]), int(t["y"]))
		gain += Board.coverage(c, float(st["range"]), trial) - Board.coverage(c, float(st["range"]), m.board.paths)
	var label := "%s경로 %+d칸 · 포탑 사거리 안 %+d칸" % ["담당자 미리보기 · " if shared else "", path.size() - old.size(), gain]
	_text_box(_p(Vector2(path[int(edit["i"])]) + Vector2(0.5, -0.7)), label, 13, col)


func _draw_tower(t: Dictionary) -> void:
	var g := Vector2(int(t["x"]), int(t["y"]))
	var at := _p(g)
	var center := at + Vector2(cell, cell) * 0.5
	var owner := int(t["owner"])
	var col: Color = TOWER_COLORS[t["type"]]
	draw_rect(Rect2(at + Vector2(2, 2), Vector2(cell - 4, cell - 4)), Color("23291f"))
	draw_rect(Rect2(at + Vector2(2, 2), Vector2(cell - 4, cell - 4)), P_COLORS[owner], false, 2.0)
	match str(t["type"]):
		"gun":
			draw_circle(center, cell * 0.25, col)
			draw_line(center, center + Vector2(cell * 0.36, -cell * 0.08), col, 3.0)
			draw_line(center, center + Vector2(cell * 0.36, cell * 0.08), col, 3.0)
		"cannon":
			draw_circle(center, cell * 0.31, col)
			draw_circle(center, cell * 0.14, Color("2c1a14"))
		"cold":
			for k in 3:
				var dir := Vector2.from_angle(PI * k / 3.0)
				draw_line(center - dir * cell * 0.32, center + dir * cell * 0.32, col, 2.5)
			draw_circle(center, cell * 0.09, Color.WHITE)
	for k in int(t["lv"]):
		draw_circle(at + Vector2(6 + k * 6, cell - 6), 2.2, Color("ffd76a"))
	_center_text(at + Vector2(cell - 8, 8), P_MARKS[owner], int(cell * 0.3), P_COLORS[owner])
	if int(t["id"]) == selected:
		var st := GData.tower_stats(t["type"], int(t["lv"]), str(t["branch"]))
		draw_circle(center, float(st["range"]) * cell, Color(1, 1, 1, 0.07))
		draw_arc(center, float(st["range"]) * cell, 0, TAU, 48, Color(1, 1, 1, 0.65), 1.5)


func _draw_enemy(m: GMatch, en: Dictionary) -> void:
	var path: Array = m.board.paths[int(en["e"])]
	var d: float = _disp.get(int(en["id"]), float(en["dist"]))
	var center := _p(Board.pos_on(path, d))
	var col: Color = ENEMY_COLORS[en["type"]]
	var r := cell * 0.24
	match str(en["type"]):
		"swarm":
			r = cell * 0.15
			draw_circle(center, r, col)
		"heavy":
			r = cell * 0.31
			draw_rect(Rect2(center - Vector2(r, r), Vector2(r, r) * 2), col)
			draw_rect(Rect2(center - Vector2(r, r), Vector2(r, r) * 2), Color("c6ced8"), false, 2.0)
		"rusher":
			draw_colored_polygon(PackedVector2Array([center + Vector2(0, -r * 1.2), center + Vector2(r * 1.1, r), center + Vector2(-r * 1.1, r)]), col)
		"boss":
			r = cell * 0.46
			var pts := PackedVector2Array()
			for k in 10:
				pts.append(center + Vector2.from_angle(TAU * k / 10.0 + _tick) * (r if k % 2 == 0 else r * 0.68))
			draw_colored_polygon(pts, col)
			draw_circle(center, r * 0.3, Color("ffd76a"))
		_:
			draw_circle(center, r, col)
			draw_arc(center, r, 0, TAU, 16, Color(0, 0, 0, 0.4), 1.5)
	if float(en["slow"]) > 0.0:
		draw_arc(center, r + 3, 0, TAU, 18, Color("6fdcf2"), 2.0)
	var w := maxf(r * 2.0, cell * 0.5)
	var bar := center + Vector2(-w * 0.5, -r - 7)
	draw_rect(Rect2(bar, Vector2(w, 3)), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(bar, Vector2(w * float(en["hp"]) / maxf(float(en["max"]), 1.0), 3)), Color("67dd76"))


func _draw_fx() -> void:
	for f in _fxs:
		var k: float = float(f["t"]) / float(f["life"])
		if f["k"] == "shot":
			var a := _p(f["a"])
			var b := _p(f["b"])
			match str(f["ty"]):
				"gun":
					draw_line(a, b, Color(1, 0.95, 0.65, k), 1.5)
				"cannon":
					draw_circle(a.lerp(b, 1.0 - k), 3.5, Color("ffb35c"))
					draw_circle(b, float(f["r"]) * cell * (1.0 - k * 0.5), Color(1, 0.55, 0.2, k * 0.34))
				"cold":
					draw_line(a, b, Color(0.5, 0.92, 1, k), 2.0)
					draw_circle(b, float(f["r"]) * cell, Color(0.45, 0.88, 1, k * 0.16))
		else:
			var center := _p(f["a"])
			draw_circle(center, 2.2 * cell, Color(0.45, 0.88, 1, k * 0.28))
			draw_arc(center, 2.2 * cell * (1.2 - k * 0.2), 0, TAU, 40, Color(0.7, 0.95, 1, k), 2.0)


func _draw_pings() -> void:
	var marks := {"look": "!", "danger": "⚠", "build": "+", "road": "↝", "mine": "✓"}
	for p in s.pings:
		var who := int(p["seat"])
		var center := _p(Vector2(float(p["x"]), float(p["y"])))
		var pulse := fmod(_tick * 1.6, 1.0)
		draw_arc(center, cell * (0.35 + pulse * 0.6), 0, TAU, 24, Color(P_COLORS[who % 2], 1.0 - pulse), 2.5)
		draw_circle(center, cell * 0.3, P_COLORS[who % 2])
		_center_text(center, marks.get(str(p["kind"]), "!"), int(cell * 0.42), Color("10130f"))
		_text_box(center + Vector2(0, -cell * 0.72), "%s %s" % [P_MARKS[who % 2], GData.PING_KINDS[p["kind"]]], 12, Color.WHITE)


func _draw_cursor(m: GMatch) -> void:
	if hover.x < 0:
		return
	var c := Vector2i(hover)
	var center := _p(Vector2(c) + Vector2(0.5, 0.5))
	if mode.begins_with("build:") or mode.begins_with("move:"):
		var type: String
		var lv := 1
		var branch := ""
		var cells := m.tower_cells()
		if mode.begins_with("build:"):
			type = mode.substr(6)
		else:
			var t: Dictionary = m.towers.get(int(mode.substr(5)), {})
			if t.is_empty():
				return
			type = t["type"]
			lv = int(t["lv"])
			branch = str(t["branch"])
		var ok := m.board.can_build(c, cells) == ""
		var col := Color("74e07f") if ok else Color("e2574c")
		var st := GData.tower_stats(type, lv, branch)
		draw_rect(Rect2(_p(Vector2(c)), Vector2(cell, cell)), Color(col, 0.42))
		draw_circle(center, float(st["range"]) * cell, Color(col, 0.08))
		draw_arc(center, float(st["range"]) * cell, 0, TAU, 48, Color(col, 0.8), 1.5)
		if ok:
			_text_box(center + Vector2(0, -cell * 0.8), "사거리 안 길 %d칸" % Board.coverage(c, float(st["range"]), m.board.paths), 12, Color.WHITE)
	elif mode == "ability":
		draw_circle(_p(hover), 2.2 * cell, Color(0.45, 0.88, 1, 0.16))
		draw_arc(_p(hover), 2.2 * cell, 0, TAU, 40, Color("6fdcf2"), 2.0)
	elif mode.begins_with("ping:"):
		draw_arc(_p(hover), cell * 0.5, 0, TAU, 20, Color.WHITE, 2.0)
	elif mode == "":
		draw_rect(Rect2(_p(Vector2(c)), Vector2(cell, cell)), Color(1, 1, 1, 0.25), false, 1.0)


func _center_text(center: Vector2, text: String, size_px: int, col: Color) -> void:
	var w := BOLD.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px)
	draw_string(BOLD, center + Vector2(-w.x * 0.5, size_px * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)


func _text_box(center: Vector2, text: String, size_px: int, col: Color) -> void:
	var w := BOLD.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px)
	var x := clampf(center.x - w.x * 0.5, origin.x + 6.0, maxf(origin.x + 6.0, origin.x + cell * GData.W - w.x - 6.0))
	draw_rect(Rect2(x - 6, center.y - size_px * 0.95, w.x + 12, size_px + 8), Color(0.05, 0.07, 0.06, 0.86))
	draw_string(BOLD, Vector2(x, center.y + size_px * 0.18), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)
