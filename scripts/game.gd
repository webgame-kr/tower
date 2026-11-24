extends Control
## 화면과 입력. UI 시안(UI DNA)의 1280×720 좌표를 그대로 쓰고, 지도는 화면 전체에 깐다.
## 규칙은 GMatch, 온라인은 GSession 이 맡는다.

const NetScript := preload("res://scripts/net.gd")
const BOLD := preload("res://fonts/IBMPlexSansKR-Bold.ttf")
const REG := preload("res://fonts/IBMPlexSansKR-Regular.ttf")
const TEX_TOWERS := preload("res://art/towers.png")
const TEX_ENEMIES := preload("res://art/enemies.png")
const TEX_ICONS := preload("res://art/icons.png")

const STAGE := Vector2(1280, 720)
const FRAME := Rect2(0, 0, 1280, 720)     # 지형이 깔리는 화면 전체
const MAP := Vector2(262, 100)            # 플레이 칸의 시작점
const CELL := 28.0
const MINI_VIEW := Rect2(190, 60, 900, 600)   # 작은 지도에 보여 줄 범위
const TRANSITION := 2.5

## UI DNA 색 토큰 (생성기 출력값)
const BG := Color("282b30")
const PANEL := Color("454a4f")
const PANEL_HI := Color("50555a")
const PANEL_LO := Color("3d4247")
const WELL := Color("1c1e22")
const LINE := Color("405068")
const INK := Color("eff5ff")
const SUB := Color("9aaabe")
const AMBER := Color("f4bb60")
const AMBER_HI := Color("f6c679")
const AMBER_INK := Color("2a2214")
const DANGER := Color("f47679")
const WARN := Color("e5be68")
const LAMP := Color("FF4A3A")
const ICE := Color("9FD8E6")
const FIRE := Color("F07A2A")
const GRASS := Color("6E8550")
const GRASS2 := Color("67804A")
const TUFT := Color("58703F")
const ROAD := Color("A08A6A")
const ROAD_EDGE := Color("4E4232")
const OK_GREEN := Color("64d4a3")
const CFG_DEFAULT := {"font": 100, "fx_low": false, "thick": false, "shake": 30, "pattern": true, "dmg": true}

const OWNER := [Color("E0533D"), Color("3D6FD1"), Color("E9B935"), Color("38A672")]
const OWNER_TEXT := [Color("FF8A78"), Color("7FA6F0"), Color("E9B935"), Color("5FCB97")]
const MARK := ["●", "▲", "■", "◆"]
const TOWER_ROW := {"gun": 0, "cannon": 1, "cold": 2, "oil": 3, "flame": 4, "magnet": 5}
const LOCKED := [["oil", "기름분사탑"], ["flame", "불꽃탑"], ["magnet", "자석탑"]]
const ENEMY_COL := {"grunt": 0, "swarm": 1, "heavy": 2, "rusher": 3, "boss": 5}
const ENEMY_SIZE := {"grunt": 36.0, "swarm": 34.0, "heavy": 34.0, "rusher": 34.0, "boss": 58.0}
const PRIO := {"first": "앞선 적", "strong": "강한 적", "near": "가까운 적"}
const PING_ORDER := ["look", "danger", "build", "road", "mine"]
const PING_COL := [Color("3F9BD6"), Color("D2452F"), Color("E9B935"), Color("C9A15F"), Color("38A672")]

var net: Node
var s: GSession
var web := false
var room := ""

var _off := Vector2.ZERO
var mode := ""            # build:gun | road:detour | move:id | ability | ping:look
var selected := -1
var hover := Vector2(-1, -1)
var hover_edit := {}
var chat_open := true
var _screen := "menu"
var _fxs: Array = []
var _disp := {}
var _shake := 0.0
var _flash := Vector2(-1, -1)
var _flash_t := 0.0
var _toast := ""
var _toast_t := 0.0
var _chat_key := ""
var _name_sent := ""
var _name_t := 0.0
var _tick := 0.0
var _menu_open := false
var _theme := 0           # 지금 그리는 테마
var _theme_goal := 0
var _trans_t := 0.0
var _notice_t := 0.0
var _theme_tex := {}
var fx_low := false
var cfg := CFG_DEFAULT.duplicate()
var _cfg_draft := {}
var _paused := false
var _panel := ""           # "" | settings | help | mute
var _tab := 3
var _muted := {}
var _chat_typing := false
var _type_t := 0.0
var _code_open := false
var _menu_focus := 0
var _record := {}
var _record_done := false

var stage: Control
var menu: Control
var lobby: Control
var hud: Control
var result: Control
var chat_box: RichTextLabel
var chat_block: Control
var chat_toggle: Button

var host_btn: Button
var join_btn: Button
var solo_btn: Button
var start_btn: Button
var ready_lobby: Button
var col_btns: Array = []
var build_btns := {}
var road_btns := {}
var confirm_btn: Button
var cancel_btn: Button
var ability_btn: Button
var ping_btns: Array = []
var ready_btn: Button
var prio_btns := {}
var up_btn: Button
var a_btn: Button
var b_btn: Button
var move_btn: Button
var sell_btn: Button
var menu_btn: Button
var quit_btn: Button
var fx_btn: Button
var retry_btn: Button
var back_btn: Button
var pause: Control
var pause_block: Control
var pause_btns := {}
var set_tabs: Array = []
var font_btns: Array = []
var toggle_btns := {}
var shake_btn: Button
var mute_btns: Array = []
var cfg_btns := {}
var menu_items: Array = []
var code_go: Button
var speed_btns: Array = []
var _none := StyleBoxEmpty.new()


func _ready() -> void:
	net = NetScript.new()
	add_child(net)
	web = OS.has_feature("web") and net.available
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	stage = Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.size = STAGE
	add_child(stage)
	menu = _layer()
	lobby = _layer()
	hud = _layer()
	result = _layer()
	_build_chat()
	_build_menu()
	_build_lobby()
	_build_hud()
	_build_result()
	pause = _layer()
	_build_pause()
	_load_cfg()
	if web:
		room = net.room_param()
	get_viewport().size_changed.connect(_place)
	_show("menu")
	_place.call_deferred()


func _load_cfg() -> void:
	if not web:
		return
	var ui = JavaScriptBridge.get_interface("GilUI")
	var raw := str(ui.load_key("cfg"))
	var saved = JSON.parse_string(raw) if raw.begins_with("{") else null
	if saved is Dictionary:
		for k in CFG_DEFAULT:
			if saved.has(k):
				cfg[k] = saved[k]
	var raw_rec := str(ui.load_key("record"))
	var rec = JSON.parse_string(raw_rec) if raw_rec.begins_with("{") else null
	if rec is Dictionary:
		_record = rec
	fx_low = bool(cfg["fx_low"])


func _save_cfg() -> void:
	fx_low = bool(cfg["fx_low"])
	_chat_key = ""
	chat_box.add_theme_font_size_override("normal_font_size", roundi(13 * float(cfg["font"]) / 100.0))
	if web:
		JavaScriptBridge.get_interface("GilUI").save_key("cfg", JSON.stringify(cfg))


func _layer() -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size = STAGE
	stage.add_child(c)
	return c


# ── 버튼 ──

func _box(fill: Color, edge: Color, radius := 3, width := 1) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	b.border_color = edge
	b.set_border_width_all(width)
	b.set_corner_radius_all(0)
	b.corner_radius_top_left = radius + 2
	b.corner_radius_bottom_right = radius + 2
	b.corner_detail = 1
	b.set_content_margin_all(3)
	return b


func _btn(parent: Control, r: Rect2, text: String, cb: Callable, kind := "sec", font_px := 13) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.position = r.position
	b.size = r.size
	b.clip_text = false
	b.add_theme_font_override("font", BOLD)
	b.add_theme_font_size_override("font_size", font_px)
	b.pressed.connect(cb)
	_style(b, kind)
	parent.add_child(b)
	return b


func _style(b: Button, kind: String) -> void:
	if b.get_meta("kind", "") == kind:
		return
	b.set_meta("kind", kind)
	for k in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(k, _none)
	var ink := AMBER_INK if kind == "pri" else INK
	b.add_theme_color_override("font_color", ink)
	b.add_theme_color_override("font_hover_color", ink)
	b.add_theme_color_override("font_pressed_color", ink)
	b.add_theme_color_override("font_hover_pressed_color", ink)
	b.add_theme_color_override("font_focus_color", ink)
	b.add_theme_color_override("font_disabled_color", Color(SUB, 0.55))


func _cut(r: Rect2, c: float) -> PackedVector2Array:
	return PackedVector2Array([r.position + Vector2(c, 0), Vector2(r.end.x, r.position.y), r.end - Vector2(0, c), r.end - Vector2(c, 0),
		Vector2(r.position.x, r.end.y), r.position + Vector2(0, c)])


## 금속 판: 위 하이라이트, 아래 음영, 7px 절단 모서리
func _metal(r: Rect2, top: Color, bottom: Color, edge := LINE, c := 7.0) -> void:
	var pts := _cut(r, c)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(top.lerp(bottom, clampf((p.y - r.position.y) / maxf(r.size.y, 1.0), 0.0, 1.0)))
	draw_polygon(pts, cols)
	var ring := pts.duplicate()
	ring.append(pts[0])
	draw_polyline(ring, edge, 1.0)
	draw_line(r.position + Vector2(c, 1.5), Vector2(r.end.x - 1, r.position.y + 1.5), Color(1, 1, 1, 0.22), 1.0)
	draw_line(Vector2(r.position.x + 1, r.end.y - 1.5), r.end - Vector2(c, 1.5), Color(0, 0, 0, 0.35), 1.0)


func _plate(b: Button) -> void:
	var kind: String = b.get_meta("kind", "sec")
	if kind == "clear" or not b.is_visible_in_tree():
		return
	var r := Rect2(b.position, b.size)
	var parent := b.get_parent()
	while parent != stage and parent != null:
		r.position += parent.position
		parent = parent.get_parent()
	var mode_ := b.get_draw_mode()
	var down := mode_ == BaseButton.DRAW_PRESSED or mode_ == BaseButton.DRAW_HOVER_PRESSED
	var hot := mode_ == BaseButton.DRAW_HOVER or mode_ == BaseButton.DRAW_HOVER_PRESSED
	if b.disabled:
		_metal(r, Color("3a3e43"), Color("33373b"), Color("3a4352"))
		return
	if down and not b.toggle_mode:
		r.position.y += 1
	if kind == "pri":
		var top := AMBER_HI if hot else Color("f8cd86")
		_metal(r, top, Color("e6a44c") if not down else Color("d99640"), Color("a9803d"))
	else:
		_metal(r, PANEL_HI.lightened(0.08) if hot else PANEL_HI, PANEL_LO, AMBER if b.button_pressed and b.toggle_mode else LINE)
	if b.toggle_mode and b.button_pressed:
		draw_rect(Rect2(r.position.x + 3, r.end.y - 3, r.size.x - 10, 3), AMBER)


func _draw_plates(parent: Control) -> void:
	if not parent.is_visible_in_tree():
		return
	for b in parent.get_children():
		if b is Button:
			_plate(b)


# ── 화면 구성 ──

func _build_chat() -> void:
	chat_block = Control.new()
	chat_block.mouse_filter = Control.MOUSE_FILTER_STOP
	stage.add_child(chat_block)
	chat_box = RichTextLabel.new()
	chat_box.bbcode_enabled = false      # 사용자 입력이 서식으로 해석되지 않게
	chat_box.scroll_following = true
	chat_box.add_theme_font_size_override("normal_font_size", 13)
	chat_box.add_theme_color_override("default_color", INK)
	chat_box.add_theme_constant_override("line_separation", 3)
	chat_box.meta_clicked.connect(_on_chat_link)
	stage.add_child(chat_box)
	chat_toggle = _btn(stage, Rect2(256, 456, 52, 18), "ENTER", _open_chat, "clear", 10)
	chat_toggle.add_theme_color_override("font_color", SUB)


func _build_menu() -> void:
	var rows := [["방 만들기", _on_host, "pri"], ["코드로 참가", _on_code, "sec"], ["혼자 연습 · 봇 동료", _on_solo, "sec"],
		["이어서 하기 · 지원 예정", _noop, "sec"], ["설정", _open_settings, "sec"]]
	for i in rows.size():
		var b := _btn(menu, Rect2(64, 260 + i * 54, 300, 46), str(rows[i][0]), rows[i][1], str(rows[i][2]), 15)
		menu_items.append(b)
	menu_items[3].disabled = true
	host_btn = menu_items[0]
	solo_btn = menu_items[2]
	join_btn = _btn(menu, Rect2(64, 260, 300, 46), "초대받은 방 입장", _on_join, "pri", 15)
	code_go = _btn(menu, Rect2(600, 318, 72, 46), "입장", _on_code_go, "pri", 14)


func _build_lobby() -> void:
	_btn(lobby, Rect2(49, 314, 119, 44), "코드 복사", _on_copy_code)
	_btn(lobby, Rect2(176, 314, 119, 44), "초대 링크", _on_copy_link)
	for c in 4:
		col_btns.append(_btn(lobby, Rect2(), "", _on_color.bind(c), "clear"))
	ready_lobby = _btn(lobby, Rect2(), "준비 완료", _on_lobby_ready, "pri", 14)
	_btn(lobby, Rect2(997, 625, 61, 46), "나가기", _on_leave)
	start_btn = _btn(lobby, Rect2(1074, 625, 153, 50), "시작", _on_start, "pri", 16)


func _build_hud() -> void:
	menu_btn = _btn(hud, Rect2(1220, 14, 44, 44), "II", _toggle_pause, "sec", 15)
	quit_btn = _btn(hud, Rect2(-100, -100, 1, 1), "", _noop, "clear")
	fx_btn = _btn(hud, Rect2(-100, -100, 1, 1), "", _noop, "clear")
	quit_btn.visible = false
	fx_btn.visible = false
	var names := ["gun", "cannon", "cold"]
	for i in 3:
		var k: String = names[i]
		build_btns[k] = _btn(hud, Rect2(347 + i * 75, 634, 70, 72), "", _set_mode.bind("build:" + k), "clear")
		build_btns[k].tooltip_text = "단축키 %d" % (i + 1)
	for i in 3:
		var locked := _btn(hud, Rect2(347 + (i + 3) * 75, 634, 70, 72), "", _noop, "clear")
		locked.disabled = true
		locked.tooltip_text = "2단계에서 열려요"
	road_btns["detour"] = _btn(hud, Rect2(28, 160, 86, 46), "우회로 +4\nZ", _set_mode.bind("road:detour"), "sec", 12)
	road_btns["bend"] = _btn(hud, Rect2(118, 160, 86, 46), "굽잇길 +2\nX", _set_mode.bind("road:bend"), "sec", 12)
	confirm_btn = _btn(hud, Rect2(28, 212, 116, 34), "확정 · E", _on_confirm, "pri", 12)
	cancel_btn = _btn(hud, Rect2(148, 212, 56, 34), "취소", _on_cancel_draft, "sec", 12)
	ability_btn = _btn(hud, Rect2(186, 624, 132, 74), "", _set_mode.bind("ability"), "clear")
	for i in 5:
		var b := _btn(hud, Rect2(822 + i * 38, 655, 32, 32), "", _on_ping_kind.bind(PING_ORDER[i]), "clear")
		b.tooltip_text = GData.PING_KINDS[PING_ORDER[i]]
		ping_btns.append(b)
	ready_btn = _btn(hud, Rect2(1065, 628, 150, 48), "준비 완료", _on_ready, "pri", 15)
	speed_btns.append(_btn(hud, Rect2(1065, 650, 72, 40), "1배", _on_speed.bind(false), "sec", 13))
	speed_btns.append(_btn(hud, Rect2(1141, 650, 74, 40), "2배", _on_speed.bind(true), "sec", 13))
	for b in speed_btns:
		b.toggle_mode = true
	var keys_order := ["first", "strong", "near"]
	for i in 3:
		prio_btns[keys_order[i]] = _btn(hud, Rect2(), PRIO[keys_order[i]], _on_prio.bind(keys_order[i]), "sec", 12)
		prio_btns[keys_order[i]].toggle_mode = true
	up_btn = _btn(hud, Rect2(), "", _on_upgrade.bind(""), "sec", 12)
	a_btn = _btn(hud, Rect2(), "", _on_upgrade.bind("a"), "sec", 12)
	b_btn = _btn(hud, Rect2(), "", _on_upgrade.bind("b"), "sec", 12)
	move_btn = _btn(hud, Rect2(), "이동", _on_move, "sec", 12)
	sell_btn = _btn(hud, Rect2(), "판매", _on_sell, "sec", 12)


## 일시정지 메뉴와 설정 창 (타이틀에서도 설정 창을 쓴다)
func _build_pause() -> void:
	pause_block = Control.new()
	pause_block.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_block.position = Vector2(-3000, -3000)
	pause_block.size = Vector2(8000, 8000)
	pause.add_child(pause_block)
	pause_btns["back"] = _btn(pause, Rect2(140, 237, 262, 44), "게임으로 돌아가기", _toggle_pause, "pri", 14)
	pause_btns["settings"] = _btn(pause, Rect2(140, 291, 262, 42), "설정", _open_settings, "sec", 14)
	pause_btns["help"] = _btn(pause, Rect2(140, 343, 262, 42), "조작 안내", _open_panel.bind("help"), "sec", 14)
	pause_btns["mute"] = _btn(pause, Rect2(140, 395, 262, 42), "채팅 음소거 관리", _open_panel.bind("mute"), "sec", 14)
	pause_btns["leave"] = _btn(pause, Rect2(140, 455, 262, 42), "방 나가기", _on_leave, "sec", 14)
	var tabs := ["그래픽", "조작", "오디오", "접근성"]
	var x := 464.0
	for i in tabs.size():
		var w := 70.0 if i != 1 else 58.0
		var b := _btn(pause, Rect2(x, 194, w, 34), tabs[i], _on_tab.bind(i), "sec", 13)
		b.toggle_mode = true
		set_tabs.append(b)
		x += w + 2
	for i in 4:
		var b := _btn(pause, Rect2(773 + i * 68, 249, 62, 30), "%d%%" % [90, 100, 120, 140][i], _on_font.bind([90, 100, 120, 140][i]), "sec", 13)
		b.toggle_mode = true
		font_btns.append(b)
	for k in ["fx_low", "dmg", "thick", "pattern"]:
		toggle_btns[k] = _btn(pause, Rect2(), "", _on_toggle.bind(k), "clear")
	shake_btn = _btn(pause, Rect2(840, 0, 178, 26), "", _noop, "clear")
	for i in GSession.MAX_SEATS:
		mute_btns.append(_btn(pause, Rect2(950, 250 + i * 54, 90, 34), "음소거", _on_mute.bind(i), "sec", 12))
	cfg_btns["close"] = _btn(pause, Rect2(1012, 150, 32, 32), "X", _close_panel, "sec", 13)
	cfg_btns["default"] = _btn(pause, Rect2(817, 516, 68, 40), "기본값", _on_cfg_default, "clear", 13)
	cfg_btns["cancel"] = _btn(pause, Rect2(895, 516, 56, 40), "취소", _close_panel, "sec", 13)
	cfg_btns["apply"] = _btn(pause, Rect2(959, 516, 86, 40), "적용", _on_cfg_apply, "pri", 13)


func _build_result() -> void:
	retry_btn = _btn(result, Rect2(396, 498, 346, 50), "같은 멤버로 재도전", _on_retry, "pri", 15)
	back_btn = _btn(result, Rect2(752, 498, 154, 50), "로비로", _on_back, "sec", 13)


func _noop() -> void:
	pass


func _show(which: String) -> void:
	_screen = which
	menu.visible = which == "menu"
	lobby.visible = which == "lobby"
	hud.visible = which == "game" and not _paused
	result.visible = which == "result"
	_menu_open = false
	_chat_key = ""
	_code_open = false
	if which != "game":
		_paused = false
	if which != "menu" and _panel != "" and not _paused:
		_panel = ""
	if web:
		var ui = JavaScriptBridge.get_interface("GilUI")
		if which == "lobby":
			ui.show("name", "내 이름 (10자)", 10, 0, 0, 10, 1, true)
			ui.put("name", str(ui.saved()))
		else:
			ui.hide("name")
		ui.hide("code")
		if which == "menu" or which == "game":
			ui.hide("chat")
		else:
			ui.show("chat", "Enter 를 눌러 채팅", GSession.CHAT_MAX, 0, 0, 10, 1, false)
	_evict()
	_place()


## 지금 쓰는 테마와 다음 테마 그림만 메모리에 둔다
func _evict() -> void:
	var keep := {}
	if _screen == "menu" or _screen == "lobby":
		keep[3] = true
		keep[0] = true
	elif s != null and s.m != null:
		var t := GData.theme_of(s.m.wave)
		keep[t] = true
		keep[mini(t + 1, GData.THEMES.size() - 1)] = true
		keep[_theme] = true
	for key in _theme_tex.keys():
		if not keep.has(int(str(key).left(1))):
			_theme_tex.erase(key)


func _place() -> void:
	var v := get_viewport_rect().size
	_off = ((v - STAGE) * 0.5).max(Vector2.ZERO).floor()
	stage.position = _off
	_place_chat()
	_place_pause()
	if not web:
		return
	var ui = JavaScriptBridge.get_interface("GilUI")
	var canvas = JavaScriptBridge.get_interface("document").querySelector("canvas")
	if canvas == null:
		return
	var scale: float = float(canvas.getBoundingClientRect().width) / maxf(v.x, 1.0)
	if _screen == "lobby":
		var at := _crew_rect(maxi(s.seat, 0) if s != null else 0).position + Vector2(108, 40)
		ui.show("name", "내 이름 (10자)", 10, _off.x + at.x, _off.y + at.y, 177, scale, true)
	if _screen == "menu" and _code_open:
		ui.show("code", "방 코드 6자리", 7, _off.x + 382, _off.y + 322, 210, scale, false)
	else:
		ui.hide("code")
	if _screen == "game" and _chat_typing and not _paused:
		ui.show("chat", "메시지 입력 · Enter 전송 · Esc 닫기", GSession.CHAT_MAX, _off.x + 16, _off.y + 560, 300, scale, false)
	elif _screen == "game":
		ui.hide("chat")
	elif _screen == "lobby":
		ui.show("chat", "Enter 를 눌러 채팅", GSession.CHAT_MAX, _off.x + 984, _off.y + 526, 248, scale, false)
	elif _screen == "result":
		ui.show("chat", "Enter 를 눌러 채팅", GSession.CHAT_MAX, _off.x + 900, _off.y + 640, 332, scale, false)


func _place_chat() -> void:
	var show_chat := _screen != "menu" and not (_screen == "game" and _paused)
	chat_box.visible = show_chat
	chat_toggle.visible = _screen == "game" and not _paused
	chat_block.visible = show_chat
	match _screen:
		"game":
			chat_block.position = Vector2(16, 452)
			chat_block.size = Vector2(300, 100)
			chat_box.position = Vector2(28, 474)
			chat_box.size = Vector2(280, 74)
			chat_box.mouse_filter = Control.MOUSE_FILTER_STOP
		"lobby":
			chat_block.position = Vector2(968, 140)
			chat_block.size = Vector2(280, 440)
			chat_box.position = Vector2(984, 180)
			chat_box.size = Vector2(248, 334)
			chat_box.mouse_filter = Control.MOUSE_FILTER_STOP
		"result":
			chat_block.position = Vector2(32, 606)
			chat_block.size = Vector2(1216, 92)
			chat_box.position = Vector2(48, 632)
			chat_box.size = Vector2(830, 60)
			chat_box.mouse_filter = Control.MOUSE_FILTER_STOP


func _place_pause() -> void:
	var on := _paused or _panel != ""
	pause.visible = on
	pause_block.visible = on
	for k in pause_btns:
		pause_btns[k].visible = _paused
	pause_btns["leave"].text = "방 나가기" if not (s != null and s.solo) else "연습 그만하기"
	var settings := _panel == "settings"
	for i in set_tabs.size():
		set_tabs[i].visible = settings
		set_tabs[i].set_pressed_no_signal(i == _tab)
	for k in cfg_btns:
		cfg_btns[k].visible = _panel != "" and (settings or k == "close")
	var rows := _settings_rows() if settings else []
	for b in font_btns:
		b.visible = false
	for k in toggle_btns:
		toggle_btns[k].visible = false
	shake_btn.visible = false
	for i in rows.size():
		var y := 263.0 + i * 52.0
		var row: Array = rows[i]
		if row[0] == "font":
			for j in font_btns.size():
				font_btns[j].visible = true
				font_btns[j].position = Vector2(773 + j * 68, y - 14)
				font_btns[j].set_pressed_no_signal(int(_cfg_draft.get("font", 100)) == [90, 100, 120, 140][j])
		elif row[0] == "toggle":
			var b: Button = toggle_btns[row[1]]
			b.visible = true
			b.position = Vector2(999, y - 12)
			b.size = Vector2(46, 24)
		elif row[0] == "slider":
			shake_btn.visible = true
			shake_btn.position = Vector2(840, y - 13)
	for i in mute_btns.size():
		var b: Button = mute_btns[i]
		b.visible = _panel == "mute" and s != null and i < _player_count() and i != s.seat
		if b.visible:
			b.text = "해제" if _muted.has(i) else "음소거"


# ── 메뉴·로비 동작 ──

func _player_name() -> String:
	if web:
		var ui = JavaScriptBridge.get_interface("GilUI")
		var n := str(ui.saved()).strip_edges().left(10)
		return n if n != "" else "플레이어"
	return "플레이어"


func _on_host() -> void:
	s = GSession.new(net, _player_name(), net.token())
	s.my_tab = net.tab_id()
	_name_sent = s.my_name
	net.host()
	s.open_host()
	_show("lobby")


func _on_join() -> void:
	s = GSession.new(net, _player_name(), net.token())
	s.my_tab = net.tab_id()
	_name_sent = s.my_name
	s.open_client()
	net.join(room)
	_show("lobby")


func _on_solo() -> void:
	s = GSession.new(null, _player_name(), "me")
	s.open_host(true)
	_enter_game()


func _on_copy_code() -> void:
	net.copy(_room_code())
	_say("방 코드를 복사했어요")


func _on_copy_link() -> void:
	net.copy(net.invite_url(net.code()))
	_say("초대 링크를 복사했어요")


func _room_code() -> String:
	var c: String = net.code().to_upper()
	return c.left(3) + "-" + c.substr(3) if c.length() == 6 else c


func _on_color(c: int) -> void:
	s.set_seat({"col": c})


func _on_lobby_ready() -> void:
	if s.seat >= 0 and s.seat < s.seats.size():
		s.set_seat({"ready": not bool(s.seats[s.seat]["ready"])})


func _on_start() -> void:
	var err := s.start_match()
	if err != "":
		_say(err)
	else:
		_enter_game()


func _on_leave() -> void:
	net.close()
	s = null
	mode = ""
	selected = -1
	_show("menu")


func _on_menu() -> void:
	_toggle_pause()


func _toggle_pause() -> void:
	if _screen != "game":
		return
	_paused = not _paused
	_panel = ""
	mode = ""
	_chat_typing = false
	hud.visible = not _paused
	_place()


func _open_settings() -> void:
	_cfg_draft = cfg.duplicate()
	_open_panel("settings")


func _open_panel(which: String) -> void:
	_panel = which
	_place()


func _close_panel() -> void:
	_panel = ""
	_place()


func _on_tab(i: int) -> void:
	_tab = i
	_place()


func _on_font(v: int) -> void:
	_cfg_draft["font"] = v
	_place()


func _on_toggle(k: String) -> void:
	_cfg_draft[k] = not bool(_cfg_draft.get(k, false))


func _on_cfg_default() -> void:
	_cfg_draft = CFG_DEFAULT.duplicate()
	_place()


func _on_cfg_apply() -> void:
	cfg = _cfg_draft.duplicate()
	_save_cfg()
	_close_panel()


func _on_mute(i: int) -> void:
	if _muted.has(i):
		_muted.erase(i)
	else:
		_muted[i] = true
	_chat_key = ""
	_place()


func _player_count() -> int:
	if s == null:
		return 0
	return s.m.players.size() if s.m != null else s.seats.size()


func _settings_rows() -> Array:
	match _tab:
		0:
			return [["toggle", "fx_low", "효과 줄이기 (눈·불씨·안개 수 제한)"], ["toggle", "dmg", "피해 숫자 표시"], ["slider", "shake", "화면 흔들림"]]
		3:
			return [["font", "font", "글자 크기"], ["toggle", "fx_low", "효과 줄이기 (눈·불씨·안개 수 제한)"], ["toggle", "thick", "위험 구역 테두리 굵게"],
				["slider", "shake", "화면 흔들림"], ["toggle", "pattern", "색 대신 무늬로 팀 구분"]]
	return []


func _on_speed(fast: bool) -> void:
	if s and s.m:
		s.command({"op": "speed", "v": fast})


func _open_chat() -> void:
	if not web or _screen != "game":
		return
	_chat_typing = true
	_type_t = 0.0
	_place()
	JavaScriptBridge.get_interface("GilUI").focus("chat")


func _on_code() -> void:
	_code_open = not _code_open
	_place()
	if _code_open and web:
		JavaScriptBridge.get_interface("GilUI").focus("code")


func _on_code_go() -> void:
	if not web:
		return
	var ui = JavaScriptBridge.get_interface("GilUI")
	var code := str(ui.value("code")).strip_edges().to_lower().replace("-", "").replace(" ", "")
	if code.length() != 6:
		_say("방 코드 6자리를 넣어 주세요")
		return
	room = code
	_code_open = false
	_on_join()


func _on_retry() -> void:
	if s.state == "lost":
		net.join(net.code())
		s.state = "lobby"
		_show("lobby")
	elif s.is_host:
		s.rematch()
		_enter_game()


func _on_back() -> void:
	if s.state == "lost" or s.solo:
		_on_leave()
	elif s.is_host:
		s.to_lobby()
		_show("lobby")
	else:
		_on_leave()


func _enter_game() -> void:
	mode = ""
	selected = -1
	_fxs = []
	_disp = {}
	chat_open = true
	_paused = false
	_panel = ""
	_record_done = false
	_theme = GData.theme_of(s.m.wave) if s and s.m else 0
	_theme_goal = _theme
	_trans_t = 0.0
	_notice_t = 3.5 if _theme > 0 else 0.0
	_show("game")


# ── 매 프레임 ──

func _process(delta: float) -> void:
	_tick += delta
	_toast_t -= delta
	_shake = maxf(_shake - delta * 3.0, 0.0)
	_flash_t -= delta
	if s != null:
		s.tick(delta)
		while not s.toasts.is_empty():
			_say(str(s.toasts.pop_front()))
		_route()
		if _screen != "menu":
			_take_chat()
		if _screen == "lobby":
			_update_lobby(delta)
		elif _screen == "game" and s.m:
			_update_theme(delta)
			_predict(delta)
			_take_fx()
			_update_hover()
			_update_hud()
			_update_chat_input(delta)
		elif _screen == "result":
			_update_result()
	if _screen == "menu":
		_update_title()
	if _panel == "settings" and shake_btn.visible and shake_btn.is_pressed():
		var x := get_local_mouse_position().x - _off.x
		_cfg_draft["shake"] = clampi(roundi((x - 849.0) / 160.0 * 100.0), 0, 100)
	for i in range(_fxs.size() - 1, -1, -1):
		_fxs[i]["t"] -= delta
		if _fxs[i]["t"] <= 0.0:
			_fxs.remove_at(i)
	queue_redraw()


func _update_title() -> void:
	join_btn.visible = room != ""
	host_btn.visible = room == ""
	code_go.visible = _code_open
	if not web:
		host_btn.disabled = true
		menu_items[1].disabled = true
	if web and _code_open:
		var sent = JSON.parse_string(str(JavaScriptBridge.get_interface("GilUI").take("code")))
		if sent is Array and not sent.is_empty():
			_on_code_go()


## 채팅 입력창은 Enter 로 열고, 전송 뒤 비우거나 Esc 로 닫으면 숨긴다
func _update_chat_input(delta: float) -> void:
	if not _chat_typing:
		return
	_type_t += delta
	if _type_t > 0.25 and web and not bool(JavaScriptBridge.get_interface("GilUI").typing()):
		_chat_typing = false
		_place()


func _route() -> void:
	var want := _screen
	if s.state == "lost":
		want = "result"
	elif s.state == "lobby":
		want = "lobby"
	elif s.state == "game" and s.m:
		want = "result" if s.m.phase == "over" else "game"
	if want != _screen:
		if want == "game":
			_enter_game()
		else:
			_show(want)


## 테마가 바뀌면 판정은 그대로 두고 그림만 전환 연출과 함께 교체한다
func _update_theme(delta: float) -> void:
	var m := s.m
	_notice_t -= delta
	var goal := GData.theme_of(m.wave)
	if goal != _theme_goal and m.phase != "over":
		_theme_goal = goal
		_trans_t = TRANSITION
		mode = ""
		_tex(goal, "base")
		_tex(goal, "over")
	if _trans_t > 0.0:
		var before := _trans_t
		_trans_t -= delta
		if before > TRANSITION - 1.4 and _trans_t <= TRANSITION - 1.4:
			_theme = _theme_goal
		if _trans_t <= 0.0:
			_theme = _theme_goal
			_notice_t = 4.0
	elif m.wave % GData.THEME_LEN == 0 and goal + 1 < GData.THEMES.size():   # 다음 테마를 예고 시점부터 준비
		_tex(goal + 1, "base")
		_tex(goal + 1, "over")


func _tex(theme: int, part: String) -> Texture2D:
	var key := "%d%s" % [theme, part]
	if not _theme_tex.has(key):
		_theme_tex[key] = load("res://art/map/%s_%s.png" % [GData.THEMES[theme]["id"], part])
	return _theme_tex[key]


func _say(text: String) -> void:
	_toast = text
	_toast_t = 2.6


func _update_lobby(delta: float) -> void:
	var mine := s.seat
	var crew := _crew_rect(maxi(mine, 0)).position
	for c in 4:
		var b: Button = col_btns[c]
		b.position = crew + Vector2(108 + c * 44, 94)
		b.size = Vector2(38, 38)
		b.visible = mine >= 0
		var taken := false
		for i in s.seats.size():
			if i != mine and int(s.seats[i]["col"]) == c:
				taken = true
		b.disabled = taken
	ready_lobby.visible = mine >= 0 and mine < s.seats.size()
	ready_lobby.position = crew + Vector2(15, 162)
	ready_lobby.size = Vector2(270, 42)
	if ready_lobby.visible:
		var r: bool = s.seats[mine]["ready"]
		ready_lobby.text = "준비 취소" if r else "준비 완료"
		_style(ready_lobby, "sec" if r else "pri")
	var ready_n := 0
	for st in s.seats:
		if st["ready"]:
			ready_n += 1
	start_btn.visible = s.is_host
	start_btn.disabled = s.seats.size() < 2 or ready_n < s.seats.size()
	start_btn.text = "시작 · 준비 %d/%d" % [ready_n, s.seats.size()]
	_place()
	_name_t -= delta
	if web and _name_t <= 0.0 and mine >= 0:
		_name_t = 0.4
		var n := str(JavaScriptBridge.get_interface("GilUI").value("name")).strip_edges().left(10)
		if n != "" and n != _name_sent:
			_name_sent = n
			JavaScriptBridge.get_interface("GilUI").save(n)
			s.set_seat({"name": n})


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
	var key := "%d:%d:%d:%s:%s" % [_theme + _muted.size() * 100 + int(cfg["font"]) * 1000, s.chat.size(), pending, str(chat_open), str(s.chat[-1].get("text", "")).md5_text() if s.chat.size() > 0 else ""]
	if key == _chat_key:
		return
	_chat_key = key
	chat_box.clear()
	var rows: Array = s.chat
	if _screen == "game" and not chat_open:
		rows = rows.slice(maxi(rows.size() - 3, 0))
	for row in rows:
		var who := int(row["seat"])
		if _muted.has(who):
			continue
		if who >= 0:
			var col := int(row.get("col", _col_of_seat(who))) % 4
			chat_box.push_color(OWNER_TEXT[col])
			chat_box.add_text("%s %s  " % [MARK[col], row["name"]])
			chat_box.pop()
		else:
			chat_box.push_color(SUB)
			chat_box.add_text("— ")
			chat_box.pop()
		if row.has("x"):
			chat_box.push_meta("%f,%f" % [float(row["x"]), float(row["y"])])
			chat_box.push_color(AMBER)
			chat_box.add_text("[%s] %s" % [s.place_name(float(row["x"]), float(row["y"])), row["text"]])
			chat_box.pop()
			chat_box.pop()
		else:
			if who < 0:
				chat_box.push_color(SUB)
			chat_box.add_text(str(row["text"]))
			if who < 0:
				chat_box.pop()
		chat_box.newline()
	if pending > 0:
		chat_box.push_color(Color(SUB, 0.7))
		chat_box.add_text("전송 중… (%d)" % pending)
		chat_box.pop()


func _col_of_seat(seat: int) -> int:
	if s.m and seat >= 0 and seat < s.m.players.size():
		return int(s.m.players[seat].get("col", seat)) % 4
	if seat >= 0 and seat < s.seats.size():
		return int(s.seats[seat].get("col", seat)) % 4
	return maxi(seat, 0) % 4


func _on_chat_link(meta) -> void:
	var p := str(meta).split(",")
	if p.size() == 2:
		_flash = Vector2(float(p[0]), float(p[1]))
		_flash_t = 2.5


func _on_chat_toggle() -> void:
	chat_open = not chat_open
	_chat_key = ""
	_place()


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
				_fxs.append({"k": "shot", "ty": f["ty"], "a": Vector2(f["x"], f["y"]), "b": Vector2(f["tx"], f["ty2"]), "r": float(f["r"]), "t": 0.18, "life": 0.18})
			"ability":
				_fxs.append({"k": "ability", "a": Vector2(f["x"], f["y"]), "o": int(f["o"]), "t": 0.9, "life": 0.9})
			"hit":
				_shake = 1.0
				_fxs.append({"k": "hit", "n": int(f["n"]), "t": 1.0, "life": 1.0})
	s.fx = []
	if _fxs.size() > 90:
		_fxs = _fxs.slice(_fxs.size() - 90)


func _update_hover() -> void:
	var grid := (get_local_mouse_position() - _off - MAP) / CELL
	var inside := grid.x >= 0 and grid.y >= 0 and grid.x < GData.W and grid.y < GData.H and get_viewport().gui_get_hovered_control() == self
	hover = grid if inside else Vector2(-1, -1)
	hover_edit = {}
	if mode.begins_with("road:") and inside and s.m.phase == "prep" and s.m.road_owner == s.seat and s.m.edits_left > 0:
		hover_edit = s.m.board.best_edit(grid, mode.substr(5), s.m.tower_cells())


func _update_hud() -> void:
	var m := s.m
	var prep := m.phase == "prep"
	var me: Dictionary = m.players[s.seat]
	var locked := _trans_t > 0.0
	for k in build_btns:
		build_btns[k].disabled = locked or not prep or int(me["gold"]) < int(GData.TOWERS[k]["cost"])
		build_btns[k].set_pressed_no_signal(false)
	var owner_turn := m.road_owner == s.seat
	var can_road := prep and not locked and owner_turn and m.edits_left > 0
	for k in road_btns:
		road_btns[k].visible = owner_turn and prep
		road_btns[k].disabled = not can_road
		road_btns[k].toggle_mode = true
		road_btns[k].set_pressed_no_signal(mode == "road:" + k)
	confirm_btn.visible = owner_turn and prep
	cancel_btn.visible = owner_turn and prep
	confirm_btn.disabled = not can_road or m.draft.is_empty()
	cancel_btn.disabled = m.draft.is_empty()
	ability_btn.disabled = m.phase != "combat" or bool(me["used"])
	ready_btn.visible = prep
	ready_btn.disabled = locked
	if prep:
		var r: bool = me["ready"]
		ready_btn.text = "준비 취소" if r else "✓  준비 완료"
		_style(ready_btn, "sec" if r else "pri")
	for b in speed_btns:
		b.visible = not prep
	if not prep:
		var votes := m.fast_votes()
		speed_btns[1].text = "2배" if m.speed == 2 else "2배 %d/%d" % [votes, m.online_count()]
	_update_inspector(prep)


func _update_inspector(prep: bool) -> void:
	var m := s.m
	if selected >= 0 and not m.towers.has(selected):
		selected = -1
	var t: Dictionary = m.towers.get(selected, {})
	var mine := not t.is_empty() and int(t["owner"]) == s.seat
	for k in prio_btns:
		prio_btns[k].visible = mine
		if mine:
			prio_btns[k].set_pressed_no_signal(k == t["prio"])
	up_btn.visible = false
	a_btn.visible = false
	b_btn.visible = false
	move_btn.visible = mine and prep
	sell_btn.visible = mine and prep
	if not (mine and prep):
		return
	var d: Dictionary = GData.TOWERS[t["type"]]
	var gold: int = m.players[s.seat]["gold"]
	var lv := int(t["lv"])
	if lv == 1:
		up_btn.visible = true
		up_btn.text = "MK-2 강화 · %dG" % int(d["up"][0])
		up_btn.disabled = gold < int(d["up"][0])
	elif lv == 2:
		a_btn.visible = true
		b_btn.visible = true
		a_btn.text = str(d["a"]["label"])
		b_btn.text = str(d["b"]["label"])
		a_btn.disabled = gold < int(d["up"][1])
		b_btn.disabled = a_btn.disabled
	sell_btn.text = "판매 +%d" % int(floor(int(t["spent"]) * GData.SELL_RATE))


func _save_record() -> void:
	if _record_done or s == null or s.m == null or not web:
		return
	_record_done = true
	var m := s.m
	var reached := m.wave if not m.cleared else GData.LAST_WAVE
	if reached <= int(_record.get("wave", 0)):
		return
	var friends := []
	for i in m.players.size():
		if i != s.seat:
			friends.append(str(m.players[i]["name"]))
	_record = {"wave": reached, "friend": ", ".join(friends) if not s.solo else "연습", "theme": str(GData.THEMES[GData.theme_of(m.wave)]["name"])}
	JavaScriptBridge.get_interface("GilUI").save_key("record", JSON.stringify(_record))


func _update_result() -> void:
	_save_record()
	var lost := s.state == "lost"
	retry_btn.text = "다시 접속" if lost else ("같은 멤버로 재도전" if s.is_host else "방장의 재도전을 기다리는 중")
	retry_btn.disabled = not (lost or s.is_host) or (lost and s.is_host)
	back_btn.text = "나가기" if (lost or s.solo or not s.is_host) else "로비로"


# ── 입력 ──

func _set_mode(v: String) -> void:
	mode = "" if mode == v else v
	if mode != "" and not mode.begins_with("road:"):   # 길 미리보기 중에는 고른 포탑의 사거리 변화를 계속 보여 준다
		selected = -1


func _on_ready() -> void:
	if s and s.m and s.m.phase == "prep" and _trans_t <= 0.0:
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


func _on_cancel_draft() -> void:
	s.command({"op": "draft"})


func _on_ping_kind(k: String) -> void:
	_set_mode("ping:" + k)


func _gui_input(ev: InputEvent) -> void:
	if s == null or s.m == null or _screen != "game":
		return
	if ev is InputEventMouseButton and ev.pressed:
		_menu_open = false
		var grid: Vector2 = (ev.position - _off - MAP) / CELL
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
	if _trans_t > 0.0 and (mode.begins_with("build:") or mode.begins_with("move:") or mode.begins_with("road:")):
		return
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
	if not ev.pressed or ev.echo or _typing():
		return
	if ev.keycode == KEY_ESCAPE:
		if _panel != "":
			_close_panel()
		elif _code_open:
			_code_open = false
			_place()
		elif _screen == "game" and (mode != "" or selected >= 0) and not _paused:
			mode = ""
			selected = -1
		elif _screen == "game":
			_toggle_pause()
		return
	if _screen == "menu" and _panel == "":
		var dir := 0
		if ev.keycode == KEY_DOWN:
			dir = 1
		elif ev.keycode == KEY_UP:
			dir = -1
		if dir != 0:
			for _i in menu_items.size():
				_menu_focus = posmod(_menu_focus + dir, menu_items.size())
				if not menu_items[_menu_focus].disabled:
					break
		elif ev.keycode == KEY_ENTER or ev.keycode == KEY_KP_ENTER:
			var b: Button = menu_items[_menu_focus]
			if _menu_focus == 0 and room != "":
				_on_join()
			elif not b.disabled:
				b.pressed.emit()
		return
	if s == null or _paused or _panel != "":
		return
	if ev.keycode == KEY_ENTER or ev.keycode == KEY_KP_ENTER:
		if _screen == "game":
			_open_chat()
		elif web and _screen != "menu":
			JavaScriptBridge.get_interface("GilUI").focus("chat")
		return
	if s.m == null or _screen != "game":
		return
	match ev.keycode:
		KEY_1: _key_mode("build:gun", build_btns["gun"])
		KEY_2: _key_mode("build:cannon", build_btns["cannon"])
		KEY_3: _key_mode("build:cold", build_btns["cold"])
		KEY_Z: _key_mode("road:detour", road_btns["detour"])
		KEY_X: _key_mode("road:bend", road_btns["bend"])
		KEY_E:
			if confirm_btn.visible and not confirm_btn.disabled:
				_on_confirm()
		KEY_Q: _key_mode("ability", ability_btn)
		KEY_SPACE, KEY_R: _on_ready()


func _key_mode(v: String, b: Button) -> void:
	if not b.disabled:
		_set_mode(v)


# ── 그리기 공통 ──

func _t(p: Vector2, text: String, px: int, col := INK, bold := false, align := 0, width := -1.0) -> void:
	var font: Font = BOLD if bold else REG
	var at := p + Vector2(0, px)
	if align != 0:
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		at.x -= w * (0.5 if align == 1 else 1.0)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, width, px, col)


func _card(r: Rect2, fill := PANEL, edge := LINE, radius := 3) -> void:
	var c := 7.0 if minf(r.size.x, r.size.y) >= 30.0 else 4.0
	if fill == PANEL:
		_metal(r, PANEL_HI, PANEL_LO, edge, c)
	else:
		draw_colored_polygon(_cut(r, c), fill)
		if edge.a > 0.0 and edge != fill:
			var ring := _cut(r, c)
			ring.append(ring[0])
			draw_polyline(ring, edge, 1.0)


func _hazard(r: Rect2) -> void:
	draw_rect(r, Color("1A1D20"))
	var x := r.position.x - r.size.y
	var end := r.position.x + r.size.x
	while x < end:
		var a := maxf(x, r.position.x)
		var b := minf(x + 16.0, end)
		var top := r.position.y
		var bot := r.position.y + r.size.y
		if b > a:
			var pts := PackedVector2Array([
				Vector2(clampf(x + r.size.y, r.position.x, end), top),
				Vector2(clampf(x + 16.0 + r.size.y, r.position.x, end), top),
				Vector2(clampf(x + 16.0, r.position.x, end), bot),
				Vector2(clampf(x, r.position.x, end), bot)])
			if pts[0].x < pts[1].x or pts[3].x < pts[2].x:
				draw_colored_polygon(pts, AMBER)
		x += 32.0


func _blueprint() -> void:
	var v := get_viewport_rect().size
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(Vector2.ZERO, v), BG)
	var grid := Color(0.55, 0.63, 0.67, 0.07)
	var x := 0.0
	while x < v.x:
		draw_line(Vector2(x, 0), Vector2(x, v.y), grid, 1.0)
		x += 24.0
	var y := 0.0
	while y < v.y:
		draw_line(Vector2(0, y), Vector2(v.x, y), grid, 1.0)
		y += 24.0
	draw_set_transform(_off)


func _icon(index: Vector2i, r: Rect2, tint := Color.WHITE) -> void:
	draw_texture_rect_region(TEX_ICONS, r, Rect2(index.x * 64, index.y * 64, 64, 64), tint)


func _tag(center: Vector2, col: int, size_px := 18.0) -> void:
	var h := size_px * 0.5
	draw_rect(Rect2(center - Vector2(h, h), Vector2(size_px, size_px)), WELL)
	draw_rect(Rect2(center - Vector2(h - 1.5, h - 1.5), Vector2(size_px - 3, size_px - 3)), OWNER[col])
	var r := size_px * 0.26
	var w := maxf(size_px * 0.11, 1.4)
	match col:
		0:
			draw_arc(center, r, 0, TAU, 18, Color.WHITE, w, true)
		1:
			var p := PackedVector2Array([center + Vector2(0, -r * 1.15), center + Vector2(r * 1.1, r * 0.8), center + Vector2(-r * 1.1, r * 0.8), center + Vector2(0, -r * 1.15)])
			draw_polyline(p, Color.WHITE, w, true)
		2:
			draw_rect(Rect2(center - Vector2(r, r), Vector2(r, r) * 2), Color.WHITE, false, w)
		_:
			var p := PackedVector2Array([center + Vector2(0, -r * 1.25), center + Vector2(r * 1.25, 0), center + Vector2(0, r * 1.25), center + Vector2(-r * 1.25, 0), center + Vector2(0, -r * 1.25)])
			draw_polyline(p, Color.WHITE, w, true)


func _tower_sprite(type: String, lv: int, branch: String, col: int, cell_pos: Vector2, cell_px: float, tint := Color.WHITE) -> void:
	var mk := 0 if lv <= 1 else (1 if lv == 2 else (2 if branch == "a" else 3))
	var src := Rect2((mk * 4 + col) * 128, int(TOWER_ROW[type]) * 128, 128, 128)
	var u := cell_px / 100.0
	draw_texture_rect_region(TEX_TOWERS, Rect2(cell_pos - Vector2(8, 14) * u, Vector2(116, 116) * u), src, tint)


func _enemy_icon(type: String, r: Rect2, tint := Color.WHITE) -> void:
	draw_texture_rect_region(TEX_ENEMIES, r, Rect2(int(ENEMY_COL[type]) * 128, 0, 128, 128), tint)


func _gate_badge(center: Vector2, e: int) -> void:
	var w := 30.0
	var h := 12.0
	var pts := PackedVector2Array([center + Vector2(-w, 0), center + Vector2(-w + 9, -h), center + Vector2(w - 9, -h), center + Vector2(w, 0), center + Vector2(w - 9, h), center + Vector2(-w + 9, h)])
	draw_colored_polygon(pts, Color("2A1E12"))
	pts.append(pts[0])
	draw_polyline(pts, AMBER, 2.0, true)
	var ic := center + Vector2(-11, 0)
	if e == 0:
		var star := PackedVector2Array()
		for k in 10:
			star.append(ic + Vector2.from_angle(-PI * 0.5 + TAU * k / 10.0) * (7.0 if k % 2 == 0 else 3.0))
		draw_colored_polygon(star, AMBER)
	elif e == 1:
		draw_arc(ic + Vector2(2, 0), 6.5, PI * 0.62, PI * 1.38, 14, AMBER, 2.2, true)
	else:
		draw_colored_polygon(PackedVector2Array([ic + Vector2(2, -8), ic + Vector2(-5, 1), ic + Vector2(-1, 1), ic + Vector2(-3, 8), ic + Vector2(5, -2), ic + Vector2(1, -2)]), AMBER)
	_t(center + Vector2(9, -10), str(e + 1), 15, AMBER, true, 1)


# ── 지도 ──

func _p(g: Vector2) -> Vector2:
	return MAP + g * CELL + Vector2(sin(_tick * 60.0), cos(_tick * 53.0)) * _shake * 2.0 * float(cfg["shake"]) / 30.0


func _frame_rect() -> Rect2:
	return Rect2(_p(Vector2.ZERO) - MAP, FRAME.size)


func _draw_ground(theme := -1) -> void:
	var tex := _tex(_theme if theme < 0 else theme, "base")
	var v := get_viewport_rect().size
	if v.x > STAGE.x + 1 or v.y > STAGE.y + 1:      # 화면이 더 크면 같은 지형을 어둡게 늘려 가장자리를 채운다
		var sc := maxf(v.x / STAGE.x, v.y / STAGE.y)
		draw_texture_rect(tex, Rect2(-_off - (STAGE * sc - v) * 0.5, STAGE * sc), false, Color(0.55, 0.55, 0.58))
	draw_texture_rect(tex, _frame_rect(), false)


func _draw_grid(m: GMatch) -> void:
	var building := mode.begins_with("build:") or mode.begins_with("move:")
	var editing := mode.begins_with("road:")
	var alpha := 0.32 if building else (0.18 if editing else 0.045)
	var line := Color(1, 1, 1, alpha)
	if building:
		var cells := m.tower_cells()
		for y in GData.H:
			for x in GData.W:
				var c := Vector2i(x, y)
				var at := _p(Vector2(c))
				if m.board.can_build(c, cells) == "":
					draw_rect(Rect2(at + Vector2(1, 1), Vector2(CELL - 2, CELL - 2)), Color(1, 1, 1, 0.14))
				elif m.board.is_path(c):
					draw_line(at + Vector2(3, CELL - 3), at + Vector2(CELL - 3, 3), Color(LAMP, 0.55), 1.4)
	if building or editing:
		var r := GData.LANDMARK
		var a := _p(Vector2(r.position))
		var b := _p(Vector2(r.end))
		draw_rect(Rect2(a, b - a), Color(LAMP, 0.1))
		_dashed_rect(Rect2(a, b - a), Color(LAMP, 0.75))
		_dashed_rect(Rect2(_p(Vector2.ZERO), Vector2(GData.W, GData.H) * CELL), Color(1, 1, 1, 0.5))
	for x in GData.W + 1:
		draw_line(_p(Vector2(x, 0)), _p(Vector2(x, GData.H)), line, 1.0)
	for y in GData.H + 1:
		draw_line(_p(Vector2(0, y)), _p(Vector2(GData.W, y)), line, 1.0)


## 실제 효과 구역: 밝은 점선 테두리와 태그가 항상 붙는다 (장식과 구분)
func _draw_zones() -> void:
	var zone := str(GData.THEMES[_theme]["zone"])
	match zone:
		"ice":
			for r in GData.ice_zones(s.m.board.paths.size()):
				_zone_cells(r, Color("BFE8F7"), Color("5FC7EA"), "빙판 · 가속", Vector2i(0, 2))
		"lava":
			for r in GData.lava_zones(s.m.board.paths.size()):
				_zone_cells(r, FIRE, Color("FFE08A"), "용암 · 지속 피해", Vector2i(2, 0))
		"sand":
			var center := _p(GData.SAND_CENTER)
			var radius := GData.SAND_RADIUS * CELL
			draw_circle(center, radius, Color("E8C35A", 0.16))
			for i in 5:
				var y := -radius * 0.6 + i * radius * 0.3
				var half := sqrt(maxf(radius * radius - y * y, 0.0)) * 0.72
				var drift := fmod(_tick * 9.0 + i * 7.0, 14.0) - 7.0
				draw_line(center + Vector2(-half + drift, y), center + Vector2(half + drift, y), Color("8C673A", 0.55), 1.4)
			_dash_ring(center, radius, Color("FFE9A8"), 4.0 if bool(cfg["thick"]) else 2.0)
			_zone_tag(center + Vector2(0, radius + 12), "모래바람 · 사거리 -25%", Color("FFE9A8"))


func _zone_cells(r: Rect2i, fill: Color, edge: Color, label: String, _icon_cell: Vector2i) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var at := _p(Vector2(x, y))
			draw_rect(Rect2(at + Vector2(3, 3), Vector2(CELL - 6, CELL - 6)), Color(fill, 0.82))
			if fill == FIRE:
				draw_rect(Rect2(at + Vector2(6, 6), Vector2(CELL - 12, CELL - 12)), Color("FFB347", 0.72 + 0.2 * sin(_tick * 3.0 + x + y)))
			else:
				var c := at + Vector2(CELL, CELL) * 0.5
				draw_polyline(PackedVector2Array([c + Vector2(-5, -2), c + Vector2(0, 3), c + Vector2(5, -2)]), Color("3F8FB0"), 1.6, true)
	var a := _p(Vector2(r.position))
	var b := _p(Vector2(r.end))
	_dashed_rect(Rect2(a, b - a), edge)
	if bool(cfg["thick"]):
		_dashed_rect(Rect2(a, b - a).grow(1.5), edge)
		_dashed_rect(Rect2(a, b - a).grow(-1.5), edge)
	_zone_tag((a + b) * 0.5 + Vector2(0, (b.y - a.y) * 0.5 + 11), label, edge)


func _zone_tag(center: Vector2, text: String, edge: Color) -> void:
	var w := BOLD.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 12
	var x := clampf(center.x - w * 0.5, MAP.x, MAP.x + GData.W * CELL - w)
	draw_style_box(_box(Color(0.07, 0.08, 0.09, 0.92), edge, 2), Rect2(x, center.y - 8, w, 17))
	_t(Vector2(x + 6, center.y - 7), text, 10, Color.WHITE, true)


func _draw_road(path: Array, theme := -1, broken := false) -> void:
	var layers: Array = GData.THEMES[_theme if theme < 0 else theme]["road"]
	for layer in layers:
		var col := Color(str(layer[0]), float(layer[3]))
		if broken:
			col = col.lerp(Color("B83A2B"), 0.62)
		var w := CELL * float(layer[1])
		for i in range(1, path.size()):
			var a := _p(Vector2(path[i - 1]) + Vector2(0.5, 0.5))
			var b := _p(Vector2(path[i]) + Vector2(0.5, 0.5))
			if int(layer[2]) == 1:
				draw_dashed_line(a, b, col, w, 5.0)
			else:
				draw_line(a, b, col, w)
		if int(layer[2]) == 0 and w > 3.0:
			for c in path:
				draw_circle(_p(Vector2(c) + Vector2(0.5, 0.5)), w * 0.5, col)


func _draw_chevrons(path: Array, col := Color(0.1, 0.08, 0.05, 0.8)) -> void:
	var marks: Array = [1.0, 2.6, path.size() - 2.4]
	if mode.begins_with("road:"):      # 경로 확인 중에는 전체 방향을 보여 준다
		marks = []
		var k := 1.0
		while k < path.size() - 1:
			marks.append(k)
			k += 2.0
	for d in marks:
		var a := Board.pos_on(path, float(d))
		var dir := (Board.pos_on(path, float(d) + 0.08) - a).normalized()
		var n := Vector2(-dir.y, dir.x)
		var p := _p(a)
		draw_polyline(PackedVector2Array([p - dir * 3 + n * 4, p + dir * 2, p - dir * 3 - n * 4]), col, 1.6, true)


func _draw_over(theme := -1) -> void:
	draw_texture_rect(_tex(_theme if theme < 0 else theme, "over"), _frame_rect(), false)


## 체력이 줄면 연기·경고등·외벽 손상 (테마 장식과 별개)
func _draw_castle_damage(m: GMatch) -> void:
	var ratio := float(m.hp) / GData.CASTLE_HP
	if ratio >= 0.75:
		return
	var r := GData.CASTLE
	var at := _p(Vector2(r.position))
	var size_px := Vector2(r.size) * CELL
	draw_polyline(PackedVector2Array([at + size_px * Vector2(0.14, 0.2), at + size_px * Vector2(0.24, 0.32), at + size_px * Vector2(0.18, 0.42)]), Color(0.05, 0.05, 0.05, 0.9), 1.6)
	if ratio < 0.5:
		draw_polyline(PackedVector2Array([at + size_px * Vector2(0.86, 0.62), at + size_px * Vector2(0.76, 0.72), at + size_px * Vector2(0.82, 0.86)]), Color(0.05, 0.05, 0.05, 0.9), 1.6)
		var blink := 0.45 + 0.55 * absf(sin(_tick * 4.0))
		draw_circle(at + size_px * Vector2(0.5, 0.06), 3.2, Color(LAMP, blink))
	if not fx_low:
		var puffs := 3 if ratio >= 0.5 else 6
		for i in puffs:
			var k := fmod(_tick * 0.45 + i / float(puffs), 1.0)
			var p := at + size_px * Vector2(0.3 + 0.08 * i, 0.2) + Vector2(sin(k * 5.0 + i) * 5.0, -k * 26.0)
			draw_circle(p, 3.0 + k * 6.0, Color(0.16, 0.16, 0.16, 0.42 * (1.0 - k)))


## 환경 움직임. 수에 상한을 두고, 낮은 효과 설정에서는 더 줄인다
func _draw_env() -> void:
	var id := str(GData.THEMES[_theme]["id"])
	var f := FRAME
	var scale_n := 0.3 if fx_low else 1.0
	match id:
		"snow":
			for i in int(46 * scale_n):
				var x := fposmod(i * 73.3 + sin(_tick * 0.7 + i) * 12.0 + _tick * 9.0, f.size.x)
				var y := fposmod(i * 41.7 + _tick * (26.0 + i % 5 * 5.0), f.size.y)
				draw_circle(f.position + Vector2(x, y), 1.0 + (i % 3) * 0.5, Color(1, 1, 1, 0.68))
		"sand":
			for i in int(28 * scale_n):
				var x := fposmod(i * 91.0 + _tick * (70.0 + i % 4 * 18.0), f.size.x)
				var y := fposmod(i * 37.3, f.size.y)
				var p := f.position + Vector2(x, y)
				draw_line(p, p + Vector2(minf(14.0, f.end.x - p.x), 0.5), Color("F0DCA8", 0.34), 1.0)
		"lava":
			for i in int(24 * scale_n):
				var k := fmod(_tick * (0.12 + i % 4 * 0.03) + i * 0.137, 1.0)
				var x := fposmod(i * 83.1 + sin(k * 7.0 + i) * 8.0, f.size.x)
				var y := f.size.y * (1.0 - k)
				draw_circle(f.position + Vector2(x, y), 1.4, Color(1.0, 0.55 + 0.3 * (1.0 - k), 0.2, 0.85 * (1.0 - k)))
		"ghost":
			if not fx_low:
				for i in 6:      # 낮은 안개는 길 바깥쪽 위아래로만 흐른다
					var top := i % 2 == 0
					var y := (f.position.y + 18.0 + i * 5.0) if top else (f.end.y - 18.0 - i * 5.0)
					var x := f.position.x + fposmod(i * 151.0 + _tick * (9.0 + i), f.size.x + 180.0) - 90.0
					var w := minf(90.0, minf(x - f.position.x + 90.0, f.end.x - x))
					if w > 8.0:
						draw_rect(Rect2(clampf(x - w * 0.5, f.position.x, f.end.x), y - 7, minf(w, f.end.x - clampf(x - w * 0.5, f.position.x, f.end.x)), 14), Color(0.75, 0.9, 0.85, 0.07))
			for i in int(12 * scale_n):
				var k := fmod(_tick * 0.09 + i * 0.21, 1.0)
				draw_circle(f.position + Vector2(fposmod(i * 113.0 + sin(k * 6.0) * 10.0, f.size.x), f.size.y * k), 1.2, Color("9FF0D0", 0.5 * sin(k * PI)))
		_:
			if not fx_low:
				for i in 7:
					var k := fmod(_tick * 0.08 + i * 0.17, 1.0)
					draw_circle(f.position + Vector2(fposmod(i * 139.0 + k * 90.0, f.size.x), fposmod(i * 83.0, f.size.y)), 2.0 + k * 3.0, Color(0.72, 0.62, 0.44, 0.2 * sin(k * PI)))


## 공통 가림 효과 + 도착 테마 색
func _draw_transition() -> void:
	if _trans_t <= 0.0:
		return
	var t := 1.0 - _trans_t / TRANSITION
	var p := clampf((t - 0.16) / 0.8, 0.0, 1.0)
	var col := Color(str(GData.THEMES[_theme_goal]["wipe"]))
	var left := lerpf(-1.25, 1.0, p)
	var a := FRAME.position.x + FRAME.size.x * clampf(left, 0.0, 1.0)
	var b := FRAME.position.x + FRAME.size.x * clampf(left + 1.25, 0.0, 1.0)
	if b > a:
		draw_rect(Rect2(a, FRAME.position.y, b - a, FRAME.size.y), Color(col, 0.97))
		for i in 18:
			var y := FRAME.position.y + fposmod(i * 37.0, FRAME.size.y)
			var x0 := lerpf(a, b, fposmod(i * 0.37 + t * 2.0, 1.0))
			draw_line(Vector2(x0, y), Vector2(minf(x0 + 70.0, b), y), Color(1, 1, 1, 0.3), 1.5)
	_banner("%s 도착" % GData.THEMES[_theme_goal]["name"], AMBER)


func _draft_data(m: GMatch) -> Dictionary:
	if not hover_edit.is_empty():
		return hover_edit
	if m.draft.is_empty():
		return {}
	var r := m.board.reroute(int(m.draft["e"]), int(m.draft["i"]), str(m.draft["kind"]), int(m.draft["side"]), m.tower_cells())
	if not r.has("path"):
		return {}
	var edit: Dictionary = m.draft.duplicate()
	edit["path"] = r["path"]
	edit["shared"] = true
	return edit


func _draw_draft(m: GMatch, edit: Dictionary) -> void:
	if edit.is_empty():
		return
	var path: Array = edit["path"]
	var old: Array = m.board.paths[int(edit["e"])]
	var fresh := []
	for i in path.size():
		if not old.has(path[i]):
			fresh.append(i)
	if fresh.is_empty():
		return
	var from := maxi(int(fresh[0]) - 1, 0)
	var to := mini(int(fresh[-1]) + 1, path.size() - 1)
	for i in range(from + 1, to + 1):
		draw_line(_p(Vector2(path[i - 1]) + Vector2(0.5, 0.5)), _p(Vector2(path[i]) + Vector2(0.5, 0.5)), WELL, 18.0)
	for i in range(from, to + 1):
		var c := _p(Vector2(path[i]) + Vector2(0.5, 0.5))
		draw_rect(Rect2(c - Vector2(9, 9), Vector2(18, 18)), WELL)
	for i in range(from + 1, to + 1):
		draw_line(_p(Vector2(path[i - 1]) + Vector2(0.5, 0.5)), _p(Vector2(path[i]) + Vector2(0.5, 0.5)), AMBER, 13.0)
	for i in range(from, to + 1):
		var c := _p(Vector2(path[i]) + Vector2(0.5, 0.5))
		draw_rect(Rect2(c - Vector2(6.5, 6.5), Vector2(13, 13)), AMBER)
	for i in range(from + 1, to + 1):
		draw_dashed_line(_p(Vector2(path[i - 1]) + Vector2(0.5, 0.5)), _p(Vector2(path[i]) + Vector2(0.5, 0.5)), WELL, 2.0, 6.0)
	for c in old:
		if not path.has(c):
			var a := _p(Vector2(c))
			draw_rect(Rect2(a + Vector2(3, 3), Vector2(CELL - 6, CELL - 6)), Color(0.31, 0.26, 0.2, 0.9))
			draw_line(a + Vector2(8, 8), a + Vector2(CELL - 8, CELL - 8), Color.WHITE, 2.4)
			draw_line(a + Vector2(CELL - 8, 8), a + Vector2(8, CELL - 8), Color.WHITE, 2.4)


func _draw_draft_info(m: GMatch, edit: Dictionary) -> void:
	if edit.is_empty():
		return
	var path: Array = edit["path"]
	var e := int(edit["e"])
	var old: Array = m.board.paths[e]
	var who: Dictionary = m.players[m.road_owner]
	var piece: String = GData.PIECES[str(edit["kind"])]["name"]
	_banner("%s 님이 %s 미리보는 중 · 확정 전엔 실제 길이 바뀌지 않아요   %d번 길 %d → %d칸 / 최대 %d" % [who["name"], piece, e + 1, old.size(), path.size(), GData.MAX_PATH], AMBER)
	var trial: Array = m.board.paths.duplicate()
	trial[e] = path
	var before := 0
	var after := 0
	var label := "전체 포탑 사거리 안 길"
	if m.towers.has(selected):
		var t: Dictionary = m.towers[selected]
		var st := GData.tower_stats(t["type"], int(t["lv"]), str(t["branch"]))
		var c := Vector2i(int(t["x"]), int(t["y"]))
		before = Board.coverage(c, float(st["range"]), m.board.paths)
		after = Board.coverage(c, float(st["range"]), trial)
		label = "%s %s 사거리 안 길" % [m.players[int(t["owner"])]["name"], GData.TOWERS[t["type"]]["name"]]
	else:
		for id in m.towers:
			var t: Dictionary = m.towers[id]
			var st := GData.tower_stats(t["type"], int(t["lv"]), str(t["branch"]))
			var c := Vector2i(int(t["x"]), int(t["y"]))
			before += Board.coverage(c, float(st["range"]), m.board.paths)
			after += Board.coverage(c, float(st["range"]), trial)
	var r := Rect2(Vector2(808, 520), Vector2(196, 66))
	draw_style_box(_box(Color(0.1, 0.11, 0.13, 0.96), LINE, 5), r)
	_t(r.position + Vector2(10, 7), label, 11, SUB)
	_t(r.position + Vector2(10, 26), "%d칸" % before, 22, Color("8C939A"), true)
	_t(r.position + Vector2(76, 30), "→", 16, SUB, true)
	_t(r.position + Vector2(104, 26), "%d칸" % after, 22, AMBER if after > before else (LAMP if after < before else INK), true)


func _banner(text: String, col: Color, danger := false) -> void:
	var px := roundi(13 * float(cfg["font"]) / 100.0)
	var w := BOLD.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + 44
	var r := Rect2(Vector2(640 - w * 0.5, 98), Vector2(w, 32))
	_metal(r, Color("3a2422") if danger else Color(0.13, 0.14, 0.16, 0.94), Color("2a1a19") if danger else Color(0.1, 0.11, 0.12, 0.94), col, 5.0)
	draw_rect(Rect2(r.position + Vector2(12, 12), Vector2(8, 8)), col)
	_t(r.position + Vector2(28, (32 - px) * 0.5 - 2), text, px, Color("ffd2d3") if danger else INK, true)


func _draw_tower(m: GMatch, t: Dictionary) -> void:
	var at := _p(Vector2(int(t["x"]), int(t["y"])))
	var owner_col := int(m.players[int(t["owner"])].get("col", 0)) % 4
	_tower_sprite(t["type"], int(t["lv"]), str(t["branch"]), owner_col, at, CELL)
	if bool(cfg["pattern"]):      # 색 대신 무늬: 주인 기호를 크게
		_tag(at + Vector2(CELL * 0.8, CELL * 0.18), owner_col, 11.0)
	if int(t["id"]) == selected:
		var radius := m.tower_range(t) * CELL
		var center := at + Vector2(CELL, CELL) * 0.5
		draw_circle(center, radius, Color(ICE, 0.09))
		draw_arc(center, radius, 0, TAU, 56, Color(1, 1, 1, 0.75), 1.5, true)
		draw_rect(Rect2(at, Vector2(CELL, CELL)), AMBER, false, 1.5)


func _draw_enemy(m: GMatch, en: Dictionary) -> void:
	var path: Array = m.board.paths[int(en["e"])]
	var d: float = _disp.get(int(en["id"]), float(en["dist"]))
	var pos := Board.pos_on(path, d)
	var dir := Board.pos_on(path, d + 0.12) - pos
	var center := _p(pos)
	var size_px: float = float(ENEMY_SIZE[en["type"]]) * 0.96
	var ghost := m.is_ghost(en)
	draw_arc(center, size_px * 0.42, 0, TAU, 18, Color(1, 1, 1, 0.42), 1.2, true)   # 어떤 바닥에서도 읽히는 발밑 테두리
	var angle := dir.angle() + PI * 0.5 if dir.length() > 0.001 else 0.0
	draw_set_transform(_off + center, angle)
	_enemy_icon(en["type"], Rect2(-size_px * 0.5, -size_px * 0.5, size_px, size_px), Color(0.72, 1, 0.92, 0.42) if ghost else Color.WHITE)
	draw_set_transform(_off)
	if ghost:
		_dash_ring(center, size_px * 0.52, Color("7FE8D0"), 1.6)
	var ratio: float = clampf(float(en["hp"]) / maxf(float(en["max"]), 1.0), 0.0, 1.0)
	var segs := 8
	var w := 3.0 if size_px < 50 else 5.0
	var left := center + Vector2(-(segs * (w + 1)) * 0.5, -size_px * 0.5 - 3)
	draw_rect(Rect2(left - Vector2(1, 1), Vector2(segs * (w + 1) + 1, 5)), WELL)
	var col := OK_GREEN if ratio > 0.5 else (AMBER if ratio > 0.25 else LAMP)
	var lit := ceili(ratio * segs)
	for k in lit:
		draw_rect(Rect2(left + Vector2(k * (w + 1), 0), Vector2(w, 3)), col)
	if float(en["slow"]) > 0.0:
		_icon(Vector2i(0, 0), Rect2(center + Vector2(size_px * 0.22, -size_px * 0.5 - 2), Vector2(13, 13)))


func _draw_fx() -> void:
	for f in _fxs:
		var k: float = float(f["t"]) / float(f["life"])
		match str(f["k"]):
			"shot":
				var a := _p(f["a"] * 1.0)
				var b := _p(f["b"] * 1.0)
				match str(f["ty"]):
					"gun":
						draw_line(a, b, Color(1, 0.92, 0.6, k), 1.6)
					"cannon":
						var radius: float = float(f["r"]) * CELL * (1.05 - k * 0.5)
						draw_circle(b, radius, Color(FIRE, k * 0.42))
						draw_circle(b, radius * 0.5, Color(1, 0.86, 0.5, k * 0.8))
						for n in 8:
							var dir := Vector2.from_angle(TAU * n / 8.0)
							draw_line(b + dir * radius * 0.9, b + dir * radius * 1.25, Color(FIRE, k), 2.0)
					"cold":
						draw_line(a, b, Color(ICE, k), 2.0)
						draw_circle(b, float(f["r"]) * CELL, Color(ICE, k * 0.16))
			"ability":
				var c := _p(f["a"] * 1.0)
				var rr := GData.ABILITY_RADIUS * CELL
				draw_circle(c, rr, Color(ICE, k * 0.3))
				_dash_ring(c, rr * (1.15 - k * 0.15), Color.WHITE, 2.4, k)
			"hit":
				if not bool(cfg["dmg"]):
					continue
				var r := GData.CASTLE
				var at := _p(Vector2(r.position.x + r.size.x, r.position.y)) + Vector2(-6, -8 - (1.0 - k) * 22.0)
				_t(at, "-%d" % int(f["n"]), 17, Color(LAMP, k), true)


func _dash_ring(center: Vector2, radius: float, col: Color, w: float, alpha := 1.0) -> void:
	var n := 16
	for i in n:
		var a0 := TAU * i / n + _tick * 0.5
		draw_arc(center, radius, a0, a0 + TAU / n * 0.55, 6, Color(col, alpha), w, true)


func _draw_pings() -> void:
	for p in s.pings:
		var who := int(p["seat"])
		if _muted.has(who):
			continue
		var idx := PING_ORDER.find(str(p["kind"]))
		var center := _p(Vector2(float(p["x"]), float(p["y"])))
		var size_px := 46.0
		var r := Rect2(center - Vector2(size_px * 0.5, size_px * 0.62), Vector2(size_px, size_px))
		draw_texture_rect_region(TEX_ICONS, r, Rect2(maxi(idx, 0) * 128, 192, 128, 128))
		_tag(r.position + Vector2(size_px * 0.585, size_px * 0.255), _col_of_seat(who), 9.0)


func _draw_cursor(m: GMatch) -> void:
	if hover.x < 0:
		return
	var c := Vector2i(hover)
	var at := _p(Vector2(c))
	var center := at + Vector2(CELL, CELL) * 0.5
	if mode.begins_with("build:") or mode.begins_with("move:"):
		var type: String
		var lv := 1
		var branch := ""
		if mode.begins_with("build:"):
			type = mode.substr(6)
		else:
			var t: Dictionary = m.towers.get(int(mode.substr(5)), {})
			if t.is_empty():
				return
			type = t["type"]
			lv = int(t["lv"])
			branch = str(t["branch"])
		var ok := m.board.can_build(c, m.tower_cells()) == ""
		var col := AMBER if ok else LAMP
		var st := GData.tower_stats(type, lv, branch)
		st["range"] = m.tower_range({"type": type, "lv": lv, "branch": branch, "x": c.x, "y": c.y})
		draw_circle(center, float(st["range"]) * CELL, Color(col, 0.09))
		_dash_ring(center, float(st["range"]) * CELL, col, 1.6)
		_tower_sprite(type, lv, branch, int(m.players[s.seat].get("col", 0)) % 4, at, CELL, Color(1, 1, 1, 0.75))
		draw_rect(Rect2(at, Vector2(CELL, CELL)), col, false, 2.0)
		if ok:
			_tip(center + Vector2(0, -CELL * 0.95), "사거리 안 길 %d칸" % Board.coverage(c, float(st["range"]), m.board.paths))
	elif mode == "ability":
		var p := _p(hover)
		var rr := GData.ABILITY_RADIUS * CELL
		draw_circle(p, rr, Color(ICE, 0.18))
		_dash_ring(p, rr, Color.WHITE, 2.4)
		_tip(p + Vector2(0, rr + 16), "긴급 냉각 · 반경 %.1f칸 · %d초 · 감속 %d%%" % [GData.ABILITY_RADIUS, int(GData.ABILITY_TIME), roundi(GData.ABILITY_SLOW * 100)])
	elif mode.begins_with("ping:"):
		draw_arc(_p(hover), CELL * 0.5, 0, TAU, 20, AMBER, 2.0, true)
	elif mode == "":
		draw_rect(Rect2(at, Vector2(CELL, CELL)), Color(1, 1, 1, 0.3), false, 1.0)


func _tip(center: Vector2, text: String) -> void:
	var px := roundi(12 * float(cfg["font"]) / 100.0)
	var w := BOLD.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var x := clampf(center.x - w * 0.5, 8, 1272 - w - 8)
	var r := Rect2(x - 9, center.y - 13, w + 18, 26)
	draw_colored_polygon(_cut(r, 4.0), Color(0.11, 0.12, 0.13, 0.95))
	var ring := _cut(r, 4.0)
	ring.append(ring[0])
	draw_polyline(ring, LINE, 1.0)
	_t(Vector2(x, center.y - px * 0.6 - 1), text, px, INK, true)


# ── 화면별 그리기 ──

func _draw() -> void:
	_blueprint()
	match _screen:
		"menu":
			_draw_menu()
		"lobby":
			if s != null:
				_draw_lobby()
		"game":
			if s != null and s.m != null:
				_draw_game()
		"result":
			if s != null:
				_draw_result()
	if _paused or _panel != "":
		_draw_pause()
	if _toast_t > 0.0 and _screen != "game":
		_tip(Vector2(640, 118), _toast)


func _draw_title(at: Vector2, px: int) -> void:
	var cone := Rect2(at, Vector2(px * 1.3, px * 1.3))
	_icon(Vector2i(4, 2), cone)
	_t(at + Vector2(px * 1.5, 0), "길 좀 막아봐", px, INK, true)
	var w := BOLD.get_string_size("길 좀 막아봐", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	_hazard(Rect2(at + Vector2(px * 1.5, px * 1.38), Vector2(w, 9)))


func _draw_menu() -> void:
	var v := get_viewport_rect().size
	# 배경: 실제 경기장(화산)을 오른쪽에 두고 왼쪽 34% 를 어둡게 누른다
	var sc := 26.0 / 28.0
	var shift := Vector2(449, 120) - MAP * sc
	var tex := _tex(3, "base")
	var cover := maxf(v.x / STAGE.x, v.y / STAGE.y)
	draw_texture_rect(tex, Rect2(-_off - (STAGE * cover - v) * 0.5, STAGE * cover), false, Color(0.5, 0.5, 0.52))
	draw_set_transform_matrix(Transform2D(0.0, Vector2(sc, sc), 0.0, _off + shift))
	var keep := _shake
	_shake = 0.0
	draw_texture_rect(tex, Rect2(Vector2.ZERO, STAGE), false)
	for path in Board.new(2).paths:
		_draw_road(path, 3)
	draw_texture_rect(_tex(3, "over"), Rect2(Vector2.ZERO, STAGE), false)
	var demo := [["gun", Vector2i(5, 6), 0], ["cannon", Vector2i(6, 7), 1], ["cold", Vector2i(9, 7), 0], ["gun", Vector2i(19, 7), 1], ["cannon", Vector2i(18, 10), 0], ["cold", Vector2i(22, 7), 1]]
	for d in demo:
		_tower_sprite(d[0], 2, "", d[2], _p(Vector2(d[1])), CELL)
	_shake = keep
	draw_set_transform(_off)
	var dim := PackedVector2Array([-_off, Vector2(434, -_off.y), Vector2(560, -_off.y + v.y), Vector2(-_off.x, -_off.y + v.y)])
	draw_polygon(dim, PackedColorArray([Color(0.1, 0.11, 0.12, 0.93), Color(0.1, 0.11, 0.12, 0.5), Color(0.1, 0.11, 0.12, 0.0), Color(0.1, 0.11, 0.12, 0.93)]))
	draw_rect(Rect2(-_off.x, -_off.y, 434 + _off.x, v.y), Color(0.11, 0.12, 0.13, 0.55))
	_t(Vector2(64, 90), "CO-OP ENDLESS DEFENSE", 13, AMBER, true)
	_t(Vector2(60, 106), "길 좀 막아봐", 58, INK, true)
	_hazard(Rect2(64, 180, 260, 10))
	_t(Vector2(64, 206), "친구와 길을 바꾸고 포탑을 세워 본부를 지킵니다.", 14, SUB)
	if room != "":
		_t(Vector2(64, 236), "친구의 방에 초대받았어요", 13, AMBER, true)
	if _code_open:
		_card(Rect2(372, 312, 312, 58))
	var r := Rect2(64, 560, 300, 64)
	_card(r)
	if _record.is_empty():
		_t(r.position + Vector2(14, 12), "최고 기록", 11, SUB)
		_t(r.position + Vector2(14, 32), "아직 기록이 없어요", 14, INK, true)
	else:
		_t(r.position + Vector2(14, 10), "최고 기록", 11, SUB)
		_t(r.position + Vector2(14, 28), "W%d" % int(_record.get("wave", 0)), 22, INK, true)
		_t(r.position + Vector2(92, 10), "함께한 친구", 11, SUB)
		_t(r.position + Vector2(92, 30), str(_record.get("friend", "-")).left(6), 14, INK, true)
		_t(r.position + Vector2(190, 10), "마지막 테마", 11, SUB)
		_t(r.position + Vector2(190, 30), str(_record.get("theme", "-")), 14, INK, true)
	_t(Vector2(1256, 20), "v0.4 · 최대 4인", 11, SUB, true, 2)
	_draw_plates(menu)
	if 0 <= _menu_focus and _menu_focus < menu_items.size() and _menu_focus != 0:
		var fb: Button = menu_items[_menu_focus]
		var ring := _cut(Rect2(fb.position, fb.size).grow(3), 9.0)
		ring.append(ring[0])
		draw_polyline(ring, AMBER, 2.0)
	_draw_menu_icons()
	var keys := [["↑↓", "이동"], ["ENTER", "선택"], ["ESC", "뒤로"]]
	var kx := 1018.0
	_card(Rect2(1002, 670, 254, 34), Color(0.1, 0.11, 0.12, 0.85), LINE)
	for k in keys:
		_key_chip(Vector2(kx, 678), str(k[0]))
		var w := BOLD.get_string_size(str(k[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 12
		_t(Vector2(kx + w + 6, 679), str(k[1]), 12, INK, true)
		kx += w + 50


func _draw_menu_icons() -> void:
	for i in menu_items.size():
		var b: Button = menu_items[i]
		if not b.visible:
			continue
		var tw := BOLD.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var c := Vector2(b.position.x + b.size.x * 0.5 - tw * 0.5 - 20, b.position.y + 23)
		var col := AMBER_INK if i == 0 else (Color(SUB, 0.6) if b.disabled else INK)
		match i:
			0:
				draw_circle(c + Vector2(-3, -4), 4.0, col, false, 1.6)
				draw_arc(c + Vector2(-3, 7), 7.0, PI, TAU, 10, col, 1.6)
				draw_arc(c + Vector2(6, 5), 5.0, PI * 1.2, TAU, 8, col, 1.6)
			1:
				draw_circle(c + Vector2(-4, 0), 4.5, col, false, 1.6)
				draw_line(c + Vector2(0, 0), c + Vector2(9, 0), col, 1.6)
				draw_line(c + Vector2(7, 0), c + Vector2(7, 4), col, 1.6)
			2:
				draw_rect(Rect2(c - Vector2(6, 6), Vector2(12, 12)), col, false, 1.6)
				draw_circle(c, 2.0, col)
			3:
				draw_polyline(PackedVector2Array([c + Vector2(-4, -7), c + Vector2(6, 0), c + Vector2(-4, 7), c + Vector2(-4, -7)]), col, 1.6)
			4:
				draw_circle(c, 4.0, col, false, 1.6)
				for a in 8:
					var d := Vector2.from_angle(TAU * a / 8.0)
					draw_line(c + d * 6.0, c + d * 8.5, col, 1.6)


func _key_chip(at: Vector2, text: String) -> void:
	var w := BOLD.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 12
	draw_rect(Rect2(at, Vector2(w, 18)), Color(AMBER, 0.12))
	draw_rect(Rect2(at, Vector2(w, 18)), AMBER, false, 1.0)
	_t(at + Vector2(6, 2), text, 11, AMBER, true)


func _draw_lobby() -> void:
	_hazard(Rect2(-_off.x, -_off.y, get_viewport_rect().size.x, 12))
	_draw_title(Vector2(36, 34), 40)
	_t(Vector2(1248, 56), "친구들과 길을 막고 성을 지키는 협동 타워디펜스", 14, SUB, true, 2)
	_card(Rect2(32, 140, 280, 440))
	_t(Vector2(49, 160), "현장 출입증", 18, INK, true)
	_card(Rect2(49, 197, 246, 107), WELL, WELL)
	_t(Vector2(63, 212), "방 코드", 12, SUB)
	var code: String = _room_code() if s.is_host or net.code() != "" else "연결 중"
	if s.is_host and net.status() != "hosting":
		code = "여는 중…" if net.status() != "error" else "실패"
	_t(Vector2(63, 236), code, 36, AMBER, true)
	_t(Vector2(49, 380), "경기장", 14, INK, true)
	_draw_mini(Rect2(49, 408, 218, 146), null)
	_t(Vector2(49, 560), "초원 · 입구 %d개 · %d/%d명" % [GData.lanes_for(s.seats.size()), s.seats.size(), GSession.MAX_SEATS], 12, SUB)
	for i in GSession.MAX_SEATS:
		_draw_crew(i)
	_card(Rect2(968, 140, 280, 440), WELL, Color("1A1D20"))
	_t(Vector2(984, 156), "방 채팅 · 경기 중에도 이어져요", 12, SUB)
	_card(Rect2(32, 604, 1216, 92))
	_t(Vector2(53, 630), "기본 작전은 채팅으로 정하고, 입구 담당은 강제로 나누지 않아요", 14, INK, true)
	_t(Vector2(53, 654), "경기 도중 새로 들어오기는 아직 안 돼요 · 나갔다 다시 들어오기는 돼요", 12, SUB)
	if not s.is_host:
		var st: String = net.status()
		var msg := "방장이 시작하기를 기다리는 중"
		if st == "error":
			msg = str(net.error_text())
		elif s.seat < 0:
			msg = "방에 들어가는 중…"
		_t(Vector2(1228, 640), msg, 13, AMBER, true, 2)
	_draw_plates(lobby)


func _crew_rect(i: int) -> Rect2:
	return Rect2(336 + (i % 2) * 308, 140 + (i / 2) * 224, 300, 216)


func _draw_crew(i: int) -> void:
	var box := _crew_rect(i)
	var at := box.position
	var has := i < s.seats.size()
	if not has:
		_dashed_rect(box, Color("5C6268"))
		_icon(Vector2i(3, 2), Rect2(at + Vector2(132, 56), Vector2(36, 36)), Color(1, 1, 1, 0.55))
		_t(at + Vector2(150, 104), "반장 %d 자리" % (i + 1), 14, SUB, true, 1)
		_t(at + Vector2(150, 128), "초대 링크로 친구를 불러 주세요", 12, SUB, false, 1)
		return
	_card(box)
	_t(at + Vector2(15, 12), "반장 %d" % (i + 1), 16, INK, true)
	if i == 0:
		_card(Rect2(at + Vector2(248, 11), Vector2(37, 22)), WELL, WELL)
		_t(at + Vector2(266, 15), "방장", 11, AMBER, true, 1)
	var prev := Rect2(at + Vector2(15, 40), Vector2(82, 112))
	draw_rect(prev, GRASS)
	draw_rect(prev, LINE, false, 1.0)
	var col := int(s.seats[i]["col"])
	_tower_sprite(["cold", "cannon", "gun", "cannon"][i], 1, "", col, prev.position + Vector2(13, 36), 56.0)
	if i != s.seat:
		_card(Rect2(at + Vector2(108, 40), Vector2(177, 38)), WELL, LINE)
		_t(at + Vector2(118, 49), str(s.seats[i]["name"]), 14, INK, true)
	for c in 4:
		var r := Rect2(at + Vector2(108 + c * 44, 94), Vector2(38, 38))
		var picked := col == c
		var taken := false
		for k in s.seats.size():
			if k != i and int(s.seats[k]["col"]) == c:
				taken = true
		_card(r, Color("2B3035"), AMBER if picked else LINE)
		if picked:
			draw_rect(r.grow(-1), AMBER, false, 2.0)
		_tag(r.get_center(), c, 22.0)
		if taken:
			draw_rect(r.grow(-1), Color(0.14, 0.16, 0.17, 0.72))
	if i != s.seat:
		var is_ready: bool = s.seats[i]["ready"]
		var state := Rect2(at + Vector2(15, 162), Vector2(270, 42))
		_card(state, AMBER if is_ready else Color("33383D"), Color("8E6A12") if is_ready else LINE)
		_t(state.get_center() + Vector2(0, -8), "준비 완료" if is_ready else "준비 중…", 14, Color("1A1D20") if is_ready else SUB, true, 1)


func _dashed_rect(r: Rect2, col: Color) -> void:
	var a := r.position
	var b := r.position + Vector2(r.size.x, 0)
	var c := r.end
	var d := r.position + Vector2(0, r.size.y)
	for seg in [[a, b], [b, c], [c, d], [d, a]]:
		draw_dashed_line(seg[0], seg[1], col, 1.5, 6.0)


func _draw_mini(r: Rect2, m) -> void:
	var view := MINI_VIEW
	var scale := minf(r.size.x / view.size.x, r.size.y / view.size.y)
	var at := r.position + (r.size - view.size * scale) * 0.5
	var base := Transform2D(0.0, Vector2(scale, scale), 0.0, _off + at - view.position * scale)
	draw_set_transform_matrix(base)
	var keep := _shake
	_shake = 0.0
	var theme: int = GData.theme_of(m.wave) if m != null else 0
	var k := 1600.0 / 1280.0
	draw_texture_rect_region(_tex(theme, "base"), view, Rect2(view.position * k, view.size * k))
	var paths: Array = m.board.paths if m != null else Board.new(GData.lanes_for(s.seats.size())).paths
	var worst := -1
	if m != null and not m.cleared and s.state != "lost":
		worst = _worst_gate(m)
	for e in paths.size():
		_draw_road(paths[e], theme, e == worst)
	draw_texture_rect_region(_tex(theme, "over"), view, Rect2(view.position * k, view.size * k))
	if paths.size() >= 3:
		_draw_gate3(paths[2][0], theme, base)
	if m != null:
		for id in m.towers:
			var t: Dictionary = m.towers[id]
			_tower_sprite(t["type"], int(t["lv"]), str(t["branch"]), int(m.players[int(t["owner"])].get("col", 0)) % 4, _p(Vector2(int(t["x"]), int(t["y"]))), CELL)
	_shake = keep
	draw_set_transform(_off)


func _draw_gate3(cell: Vector2i, theme: int, base: Transform2D) -> void:
	var k := CELL / 15.0
	var door := _p(Vector2(cell) + Vector2(0.5, 0.5)) + Vector2(0, 2.25 * k)
	draw_set_transform_matrix(base * Transform2D(-PI * 0.5, door))
	var size_px := 55.0 * k
	draw_texture_rect(_tex(theme, "gate3"), Rect2(-size_px * 0.668, -size_px * 0.5, size_px, size_px), false)
	draw_set_transform_matrix(base)
	_gate_badge(_p(Vector2(cell) + Vector2(2.2, 0.5)), 2)


func _draw_game() -> void:
	var m := s.m
	var edit := _draft_data(m)
	_draw_ground()                     # 00~02 외곽·지면·절벽
	for path in m.board.paths:         # 03 길
		_draw_road(path)
		_draw_chevrons(path)
	_draw_zones()                      # 실제 효과 구역
	_draw_grid(m)
	_draw_draft(m, edit)
	_draw_over()                       # 04~05 작업장·랜드마크·본부·입구
	if m.board.paths.size() >= 3:
		_draw_gate3(m.board.paths[2][0], _theme, Transform2D(0.0, _off))
	_draw_castle_damage(m)
	if m.phase == "prep" and m.towers.has(selected) and mode == "":
		_draw_range_focus(m)
	for id in m.towers:
		_draw_tower(m, m.towers[id])
	for en in m.enemies:
		_draw_enemy(m, en)
	_draw_fx()
	_draw_env()                        # 07 환경 효과
	_draw_pings()                      # 08 선택·핑·건설 정보
	_draw_cursor(m)
	if _flash_t > 0.0:
		draw_arc(_p(_flash), CELL * (0.8 + 0.25 * sin(_tick * 9.0)), 0, TAU, 28, AMBER, 3.0, true)
	if _paused:
		draw_rect(Rect2(-_off, get_viewport_rect().size), Color(0.08, 0.09, 0.1, 0.45))
		_draw_vitals(m)
		return
	if not edit.is_empty():
		_draw_draft_info(m, edit)
	elif m.phase == "combat" and m.wave % GData.THEME_LEN == 0:
		_banner("보스 접근 · 1번 입구 · 도착 시 본부 −15", DANGER, true)
	elif _notice_t > 0.0 and _trans_t <= 0.0:
		var th: Dictionary = GData.THEMES[_theme]
		_banner("%s — %s" % [th["name"], th["desc"]], AMBER)
	if s.host_away:
		_banner("방장이 다른 탭을 보고 있어 게임이 잠시 멈췄어요", DANGER, true)
	_draw_transition()
	if _toast_t > 0.0:
		_tip(Vector2(640, 150), _toast)
	_draw_vitals(m)
	_draw_team(m)
	_draw_side(m)
	_draw_chat()
	_draw_hint(m)
	_draw_bar(m)
	_draw_plates(hud)
	_draw_bar_art(m)


## 본부 내구도(왼쪽 위)와 웨이브(가운데 위)
func _draw_vitals(m: GMatch) -> void:
	var r := Rect2(16, 14, 330, 76)
	_card(r)
	_icon(Vector2i(1, 2), Rect2(30, 30, 30, 30))
	_t(Vector2(78, 36), "본부 내구도", 12, SUB, true)
	var w := BOLD.get_string_size("/ %d" % GData.CASTLE_HP, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	_t(Vector2(330 - w, 40), "/ %d" % GData.CASTLE_HP, 13, SUB, true)
	_t(Vector2(330 - w - 6, 20), str(m.hp), 30, INK, true, 2)
	var lit := ceili(float(m.hp) / GData.CASTLE_HP * 20.0)
	for k in 20:
		draw_rect(Rect2(78 + k * 12.7, 62, 10.5, 14), DANGER if k < lit else Color("33373b"))
	var wv := Rect2(490, 14, 300, 76)
	_card(wv)
	var step := (m.wave - 1) % GData.THEME_LEN + 1
	var now: Dictionary = GData.THEMES[GData.theme_of(m.wave)]
	var boss := step == GData.THEME_LEN
	_t(Vector2(568, 40), "웨이브", 13, SUB, true)
	_t(Vector2(612, 26), "%02d" % m.wave, 30, INK, true)
	_t(Vector2(658, 40), "%s %d/%d%s" % [now["name"], step, GData.THEME_LEN, " · 보스" if boss else ""], 13, DANGER if boss else AMBER, true)
	for k in GData.THEME_LEN:
		var done := k + 1 < step or (k + 1 == step and m.phase != "prep")
		var col := Color("5a5f66")
		if done or k + 1 == step:
			col = DANGER if k + 1 == GData.THEME_LEN else AMBER
		draw_rect(Rect2(587 + k * 22, 66, 18, 5), col)


## 팀원 (오른쪽 위) + 일시정지 버튼
## 팀원 (오른쪽 위) + 일시정지 버튼
func _draw_team(m: GMatch) -> void:
	var n := m.players.size()
	var row_h := 24.0 if n <= 2 else 21.0
	var h := maxf(76.0, 14.0 + n * row_h + 10.0)
	_card(Rect2(938, 14, 270, h))
	for i in n:
		var p: Dictionary = m.players[i]
		var y := 24.0 + i * row_h + (8.0 if n <= 2 else 0.0)
		var col := int(p.get("col", i)) % 4
		if i == s.seat:
			draw_rect(Rect2(948, y - 2, 252, row_h - 2), Color(1, 1, 1, 0.06))
		_tag(Vector2(960, y + 9), col, 15.0)
		_t(Vector2(976, y + 1), str(p["name"]).left(5), 13, INK, true)
		var state := "끊김" if not p["online"] else ("전투 중" if m.phase == "combat" else ("준비 완료" if p["ready"] else ("길 담당" if i == m.road_owner else "건설 중")))
		_t(Vector2(1030, y + 2), state, 12, AMBER if state == "준비 완료" or state == "길 담당" else SUB, true)
		_t(Vector2(1186, y + 1), "%dG" % int(p["gold"]), 13, AMBER, true, 2)
		draw_rect(Rect2(1191, y + 5, 7, 7), OK_GREEN if p["online"] else Color("6a7076"))
	_t(Vector2(1242, 62), "ESC", 10, SUB, true, 1)


func _team_bottom(m: GMatch) -> float:
	var n := m.players.size()
	return 14.0 + maxf(76.0, 14.0 + n * (24.0 if n <= 2 else 21.0) + 10.0)


## 왼쪽: 길 개조 기회 + 길 담당 도구 / 오른쪽: 다음 테마, 선택한 포탑 또는 다음 웨이브
func _draw_side(m: GMatch) -> void:
	var chip := Rect2(16, 98, 172, 30)
	_card(chip, Color(0.11, 0.12, 0.13, 0.9), LINE)
	_t(chip.position + Vector2(10, 7), "길 개조 기회", 12, INK, true)
	for k in GData.EDITS_PER_THEME:
		_icon(Vector2i(3, 2), Rect2(chip.position + Vector2(96 + k * 18, 7), Vector2(16, 16)), Color.WHITE if k < m.edits_left else Color(0.5, 0.5, 0.5, 0.35))
	_t(chip.position + Vector2(162, 7), "%d/%d" % [m.edits_left, GData.EDITS_PER_THEME], 12, AMBER, true, 2)
	if road_btns["detour"].visible:
		_card(Rect2(16, 136, 200, 118))
		var who: Dictionary = m.players[m.road_owner]
		_t(Vector2(28, 142), "길 조각 · 이번 담당 %s" % str(who["name"]).left(5), 11, SUB, true)
	var top := _team_bottom(m) + 8.0
	var idx := GData.theme_of(m.wave)
	if idx + 1 < GData.THEMES.size():
		var next: Dictionary = GData.THEMES[idx + 1]
		var text := "다음 · %s %s" % [next["name"], next["desc"]]
		var w := BOLD.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 40
		var r := Rect2(1208 - w, top, w, 28)
		_card(r, Color(0.11, 0.12, 0.13, 0.9), LINE)
		_t(r.position + Vector2(12, 6), "»", 13, AMBER, true)
		_t(r.position + Vector2(28, 7), text, 11, INK, true)
	top += 38.0
	_side_top = top
	if m.towers.has(selected):
		_draw_inspector(m, top)
	else:
		_draw_wave_info(m, top)


var _side_top := 150.0


func _draw_chat() -> void:
	var r := Rect2(16, 452, 300, 100)
	_card(r, Color(0.11, 0.12, 0.13, 0.88), LINE)
	_t(Vector2(28, 458), "방 채팅", 11, SUB, true)


## 조작 안내는 무언가를 고른 순간에만 액션바 바로 위에
func _draw_hint(m: GMatch) -> void:
	var parts := []
	var text := ""
	if mode.begins_with("build:"):
		var key := mode.substr(6)
		parts = [str(["gun", "cannon", "cold"].find(key) + 1), "클릭", "SHIFT 연속", "ESC 취소"]
		text = "빈 칸을 클릭해 %s 배치 · %dG" % [GData.TOWERS[key]["name"], int(GData.TOWERS[key]["cost"])]
	elif mode == "ability":
		parts = ["Q", "클릭", "ESC 취소"]
		text = "범위를 확인하고 클릭해 사용 · 반경 %.1f칸 · %d초" % [GData.ABILITY_RADIUS, int(GData.ABILITY_TIME)]
	elif mode.begins_with("road:"):
		parts = ["클릭", "E 확정", "ESC 취소"]
		text = "바꿀 구간 가까이를 클릭해 미리보기 · 기회 %d" % m.edits_left
	elif mode.begins_with("move:"):
		parts = ["클릭", "ESC 취소"]
		text = "옮길 빈 칸을 클릭 · 무료"
	elif mode.begins_with("ping:"):
		parts = ["클릭", "ESC 취소"]
		text = "알릴 위치를 클릭 · %s" % GData.PING_KINDS[mode.substr(5)]
	if text == "":
		return
	var w := 0.0
	for p in parts:
		w += BOLD.get_string_size(str(p), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 18
	w += BOLD.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 28
	var r := Rect2(640 - w * 0.5, 566, w, 34)
	_card(r, Color(0.11, 0.12, 0.13, 0.94), LINE)
	var x := r.position.x + 12
	for p in parts:
		_key_chip(Vector2(x, 574), str(p))
		x += BOLD.get_string_size(str(p), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 18
	_t(Vector2(x + 4, 574), text, 13, INK, true)


## 하단 액션바: 골드 → 지원 능력 → 건설 → 핑 → 준비/배속
func _draw_bar(m: GMatch) -> void:
	var r := Rect2(50, 612, 1180, 98)
	_metal(r, Color("4b5055"), Color("3a3f44"), LINE, 9.0)
	var me: Dictionary = m.players[s.seat]
	_t(Vector2(66, 628), "내 골드", 12, SUB, true)
	draw_circle(Vector2(76, 662), 8.0, AMBER)
	draw_circle(Vector2(76, 662), 5.0, Color("c98d36"))
	_t(Vector2(92, 648), str(int(me["gold"])), 24, INK, true)
	_t(Vector2(66, 682), "+%d / 웨이브" % GData.wave_gold(m.wave), 11, SUB)
	draw_line(Vector2(172, 626), Vector2(172, 696), LINE, 1.0)
	_t(Vector2(347, 616), "건설 · 1~6" + (" · 전투 중 잠김" if m.phase != "prep" else ""), 11, SUB, true)
	draw_line(Vector2(806, 626), Vector2(806, 696), LINE, 1.0)
	_t(Vector2(822, 634), "핑 · Alt+클릭", 11, SUB, true)
	draw_line(Vector2(1046, 626), Vector2(1046, 696), LINE, 1.0)
	if m.phase == "prep":
		_t(Vector2(1140, 684), "R · 바꾸면 준비 해제", 11, SUB, false, 1)
	else:
		_t(Vector2(1065, 630), "전투 배속 · 2배는 전원 동의", 11, SUB, true)


func _draw_bar_art(m: GMatch) -> void:
	var me: Dictionary = m.players[s.seat]
	var my_col := int(me.get("col", 0)) % 4
	# 긴급 냉각
	var ab := Rect2(186, 624, 132, 74)
	var usable: bool = m.phase == "combat" and not bool(me["used"])
	var on := mode == "ability"
	if usable or on:
		_metal(ab, Color("4a4334"), Color("3c3628"), AMBER)
		draw_rect(Rect2(ab.position.x + 3, ab.end.y - 3, ab.size.x - 10, 3), AMBER)
	else:
		_metal(ab, PANEL_HI, PANEL_LO, LINE)
	var box := Rect2(ab.position + Vector2(12, 18), Vector2(38, 38))
	draw_rect(box, Color(0.1, 0.11, 0.12))
	draw_rect(box, AMBER if usable or on else LINE, false, 1.0)
	_icon(Vector2i(0, 0), box.grow(-5), Color.WHITE if usable or on else Color(1, 1, 1, 0.45))
	_t(ab.position + Vector2(60, 18), "긴급 냉각", 14, INK, true)
	var sub := "전투 중에만"
	if m.phase == "combat":
		sub = "이번 웨이브 사용함" if bool(me["used"]) else "Q · 1회"
	_t(ab.position + Vector2(60, 40), sub, 11, AMBER if usable else SUB, true)
	# 건설 슬롯: 그림 : 글자 : 여백 ≈ 5 : 3 : 2
	var names := ["gun", "cannon", "cold", "oil", "flame", "magnet"]
	var labels := ["기관포탑", "대포탑", "냉각탑", "기름분사탑", "불꽃탑", "자석탑"]
	var costs := [100, 150, 120, 110, 130, 140]
	for i in 6:
		var t := Rect2(347 + i * 75, 634, 70, 72)
		var real := i < 3
		var b: Button = build_btns[names[i]] if real else null
		var usable_t: bool = real and not b.disabled
		var picked: bool = real and mode == "build:" + names[i]
		var hot: bool = real and b.is_hovered() and usable_t
		if usable_t:
			_metal(t, PANEL_HI.lightened(0.1) if hot else PANEL_HI, PANEL_LO, LINE)
		else:
			_metal(t, Color("3a3e43"), Color("33373b"), Color("3a4352"))
		if picked:
			draw_rect(Rect2(t.position.x + 3, t.end.y - 3, t.size.x - 10, 3), AMBER)
		var tint := Color.WHITE if usable_t else Color(0.6, 0.6, 0.6, 0.55)
		_tower_sprite(names[i], 1, "", my_col, t.position + Vector2(20, 9), 30.0, tint)
		_t(t.position + Vector2(6, 3), str(i + 1), 10, SUB, true)
		if not real or m.phase != "prep":
			_lock(t.position + Vector2(58, 8))
		_t(t.position + Vector2(35, 42), labels[i], 11, INK if usable_t else Color(SUB, 0.6), true, 1)
		_t(t.position + Vector2(35, 56), str(costs[i]), 11, AMBER if usable_t else Color(SUB, 0.5), true, 1)
	# 핑
	for i in 5:
		var pr := Rect2(822 + i * 38, 655, 32, 32)
		var active := mode == "ping:" + str(PING_ORDER[i])
		_metal(pr, PANEL_HI, PANEL_LO, AMBER if active else LINE, 4.0)
		_icon(Vector2i(i, 1), pr.grow(-5), PING_COL[i])
	if m.phase != "prep":
		speed_btns[0].set_pressed_no_signal(m.speed == 1)
		speed_btns[1].set_pressed_no_signal(m.speed == 2)


func _lock(at: Vector2) -> void:
	draw_arc(at + Vector2(0, -1), 3.0, PI, TAU, 8, SUB, 1.3)
	draw_rect(Rect2(at + Vector2(-4, 0), Vector2(8, 6)), SUB)


func _draw_range_focus(m: GMatch) -> void:
	var t: Dictionary = m.towers[selected]
	var center := Vector2(int(t["x"]), int(t["y"])) + Vector2(0.5, 0.5)
	var radius := m.tower_range(t)
	draw_rect(_frame_rect(), Color(0.04, 0.05, 0.06, 0.34))
	for path in m.board.paths:
		for c in path:
			if center.distance_to(Vector2(c) + Vector2(0.5, 0.5)) <= radius:
				var at := _p(Vector2(c))
				draw_rect(Rect2(at + Vector2(1, 1), Vector2(CELL - 2, CELL - 2)), Color(ICE, 0.32))
				draw_rect(Rect2(at + Vector2(1, 1), Vector2(CELL - 2, CELL - 2)), ICE, false, 1.2)


## 흔들림으로 지형이 틀 밖 패널에 비치지 않게 가장자리를 덮는다
## 3~4인은 한 사람을 두 줄로 줄여 보여 준다
func _draw_inspector(m: GMatch, top: float) -> void:
	var t: Dictionary = m.towers[selected]
	var mine := int(t["owner"]) == s.seat
	var prep := m.phase == "prep"
	var lv := int(t["lv"])
	var h := 200.0 + (44.0 if mine else 0.0) + (110.0 if mine and prep and lv == 2 else (54.0 if mine and prep and lv == 1 else 0.0)) + (46.0 if mine and prep else 0.0)
	var r := Rect2(1028, top, 236, h)
	_card(r)
	var d: Dictionary = GData.TOWERS[t["type"]]
	var col := int(m.players[int(t["owner"])].get("col", 0)) % 4
	var head := Rect2(r.position + Vector2(14, 14), Vector2(44, 44))
	draw_rect(head, Color(0.1, 0.11, 0.12))
	draw_rect(head, LINE, false, 1.0)
	_tower_sprite(t["type"], lv, str(t["branch"]), col, head.position + Vector2(5, 7), 34.0)
	_t(r.position + Vector2(70, 16), str(d["name"]), 17, INK, true)
	var mk := "MK-%d" % lv if lv < 3 else "MK-3%s" % str(t["branch"]).to_upper()
	_t(r.position + Vector2(70, 40), "%s · %s" % [str(m.players[int(t["owner"])]["name"]).left(5), mk], 12, SUB, true)
	var st := GData.tower_stats(t["type"], lv, str(t["branch"]))
	st["range"] = m.tower_range(t)
	var rows: Array = []
	if t["type"] == "cold":
		rows = [["감속", "%d%% / 60%%" % roundi(st["slow"] * 100)], ["범위" if st["aura"] else "사거리", "%.1f" % st["range"]]]
	else:
		rows = [["피해", "%.0f" % st["dmg"]], ["사거리", "%.1f" % st["range"]]]
	var cover := Board.coverage(Vector2i(int(t["x"]), int(t["y"])), float(st["range"]), m.board.paths)
	var edit := _draft_data(m)
	if not edit.is_empty():
		var trial: Array = m.board.paths.duplicate()
		trial[int(edit["e"])] = edit["path"]
		rows.append(["사거리 안 길", "%d → %d" % [cover, Board.coverage(Vector2i(int(t["x"]), int(t["y"])), float(st["range"]), trial)]])
	else:
		rows.append(["사거리 안 길", "%d칸" % cover])
	rows.append(["간격", "%.2fs" % st["cd"]])
	var y := r.position.y + 72
	for row in rows:
		_t(Vector2(r.position.x + 14, y), str(row[0]), 12, SUB, true)
		_t(Vector2(r.end.x - 14, y), str(row[1]), 13, INK, true, 2)
		draw_line(Vector2(r.position.x + 14, y + 22), Vector2(r.end.x - 14, y + 22), Color(LINE, 0.6), 1.0)
		y += 28
	y += 6
	if mine and prep and lv == 2:
		_t(Vector2(r.position.x + 14, y), "MK-3 · 하나만 선택", 12, INK, true)
		_t(Vector2(r.end.x - 14, y), "%dG" % int(d["up"][1]), 12, AMBER, true, 2)
	elif not mine:
		_t(Vector2(r.position.x + 14, y), "친구의 포탑이에요", 12, SUB, true)
	if mine:
		var py := r.end.y - (46.0 if prep else 0.0) - 44.0
		_t(Vector2(r.position.x + 14, py - 2), "목표 우선순위" + (" · 전투 중 변경" if not prep else ""), 11, SUB, true)
	_inspector_layout(r, mine, prep, lv)


func _inspector_layout(r: Rect2, mine: bool, prep: bool, lv: int) -> void:
	var y := r.position.y + 72 + 28 * 4 + 6 + 20
	up_btn.position = Vector2(r.position.x + 12, y)
	up_btn.size = Vector2(212, 40)
	a_btn.position = Vector2(r.position.x + 12, y)
	a_btn.size = Vector2(212, 40)
	b_btn.position = Vector2(r.position.x + 12, y + 46)
	b_btn.size = Vector2(212, 40)
	var py := r.end.y - (46.0 if prep else 0.0) - 30.0
	var keys := ["first", "strong", "near"]
	for i in 3:
		prio_btns[keys[i]].position = Vector2(r.position.x + 12 + i * 72, py)
		prio_btns[keys[i]].size = Vector2(68, 28)
	move_btn.position = Vector2(r.position.x + 12, r.end.y - 42)
	move_btn.size = Vector2(102, 32)
	sell_btn.position = Vector2(r.position.x + 120, r.end.y - 42)
	sell_btn.size = Vector2(104, 32)


func _draw_wave_info(m: GMatch, top: float) -> void:
	var groups := m.wave_plan()
	var lanes := m.board.paths.size()
	var lines := 0
	for e in lanes:
		var seen := {}
		for g in groups:
			if int(g[0]) == e:
				seen[g[1]] = true
		lines += seen.size()
	var r := Rect2(1028, top, 236, 52 + lanes * 30 + lines * 24)
	_card(r)
	_t(r.position + Vector2(14, 14), "웨이브 %d" % m.wave, 15, INK, true)
	_t(Vector2(r.end.x - 14, r.position.y + 17), "다음 적" if m.phase == "prep" else "진행 중", 11, AMBER, true, 2)
	var y := r.position.y + 50
	for e in lanes:
		_gate_badge(Vector2(r.position.x + 46, y + 11), e)
		y += 30
		var counts := {}
		for g in groups:
			if int(g[0]) == e:
				counts[g[1]] = int(counts.get(g[1], 0)) + int(g[2])
		for k in counts:
			_enemy_icon(k, Rect2(r.position.x + 14, y - 4, 24, 24))
			_t(Vector2(r.position.x + 44, y), str(GData.ENEMIES[k]["name"]), 12, INK, true)
			_t(Vector2(r.end.x - 14, y), "×%d" % counts[k], 13, AMBER, true, 2)
			y += 24


func _draw_result() -> void:
	_hazard(Rect2(-_off.x, -_off.y, get_viewport_rect().size.x, 12))
	var m := s.m
	var lost := s.state == "lost"
	if lost:
		_t(Vector2(32, 36), "연결 종료", 42, INK, true)
		_t(Vector2(262, 62), "방장과 연결이 끊겼어요 · 패배 기록이 아니에요", 15, SUB)
	elif m != null and m.cleared:
		_t(Vector2(32, 36), "%d웨이브 방어 성공" % GData.LAST_WAVE, 42, AMBER, true)
		_t(Vector2(480, 62), "다섯 테마를 모두 버텨냈어요 · 다음엔 더 적은 피해로?", 15, SUB)
	else:
		_t(Vector2(32, 36), "성이 무너졌어요", 42, INK, true)
		if m != null:
			_t(Vector2(372, 62), "웨이브 %d에서 멈췄어요 · 다음엔 %d번 길을 더 길게?" % [m.failed_wave, _worst_gate(m) + 1], 15, SUB)
	_card(Rect2(32, 110, 340, 480))
	_card(Rect2(396, 110, 510, 372), Color("121A18"), Color("1F2723"))
	_card(Rect2(930, 110, 318, 480))
	_card(Rect2(32, 606, 1216, 92), WELL, Color("1A1D20"))
	_t(Vector2(48, 612), "방 채팅 · 이어서", 11, SUB)
	if lost:
		_t(Vector2(651, 560), "방장이 돌아오면 다시 접속할 수 있어요", 12, SUB, false, 1)
	_draw_plates(result)
	if m == null:
		return
	var held: int = GData.LAST_WAVE if m.cleared else maxi(m.failed_wave - 1, 0)
	var stats := [["완전히 막은 웨이브", str(held)], ["무너진 웨이브", "-" if m.cleared or m.failed_wave == 0 else str(m.failed_wave)], ["버틴 시간", _clock(m.time)], ["지나온 테마", "%d개" % (GData.theme_of(m.wave) + 1)]]
	for i in 4:
		var r := Rect2(51 + (i % 2) * 155, 129 + (i / 2) * 87, 147, 79)
		_card(r, Color("2B2F33"), Color("2B2F33"))
		_t(r.position + Vector2(12, 10), stats[i][0], 12, SUB)
		_t(r.position + Vector2(12, 36), stats[i][1], 24, INK, true)
	_t(Vector2(51, 308), "지나온 테마", 12, SUB, true)
	var chip_x := 51.0
	for i in GData.theme_of(m.wave) + 1:
		var th: Dictionary = GData.THEMES[i]
		var chip_w := BOLD.get_string_size(str(th["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 14
		var wipe := Color(str(th["wipe"]))
		draw_rect(Rect2(chip_x, 337, chip_w, 26), wipe)
		_t(Vector2(chip_x + 7, 342), str(th["name"]), 12, Color("121518") if wipe.get_luminance() > 0.5 else Color.WHITE, true)
		chip_x += chip_w + 5
	_card(Rect2(51, 381, 302, 107), WELL, WELL)
	_t(Vector2(63, 394), "무너진 이유" if not m.cleared else "성에 닿은 적", 12, AMBER, true)
	var worst := _worst_gate(m)
	_gate_badge(Vector2(100, 434), worst)
	var x := 146.0
	var names := []
	var ranked: Array = m.leaks.keys()
	ranked.sort_custom(func(a, b): return int(m.leaks[a]) > int(m.leaks[b]))
	for k in ranked.slice(0, 2):
		_enemy_icon(str(k), Rect2(x, 418, 32, 32))
		names.append(str(GData.ENEMIES[str(k)]["name"]))
		x += 38
	_t(Vector2(x + 2, 426), " + ".join(names) if not names.is_empty() else "없음", 12, INK)
	var by_gate := []
	for e in m.gate_dmg.size():
		by_gate.append("%d번 %d" % [e + 1, int(m.gate_dmg[e])])
	_t(Vector2(63, 459), "성 피해 · " + " / ".join(by_gate), 12, INK)
	_t(Vector2(410, 126), "마지막 경기장 · %s %d/%d" % [GData.THEMES[GData.theme_of(m.wave)]["name"], (m.wave - 1) % GData.THEME_LEN + 1, GData.THEME_LEN], 12, INK, true)
	if not m.cleared and not lost:
		_t(Vector2(892, 126), "빨간 칸 = 뚫린 길", 11, AMBER, true, 2)
	_draw_mini(Rect2(410, 151, 486, 317), m)
	_t(Vector2(947, 130), "각자 한 일", 18, INK, true)
	for i in m.players.size():
		var p: Dictionary = m.players[i]
		if m.players.size() > 2:
			_result_row(p, i, 168.0 + i * 79.0)
			continue
		var y := 168.0 + i * 152.0
		_card(Rect2(947, y, 284, 142), Color("2B2F33"), Color("2B2F33"))
		_tag(Vector2(970, y + 22), int(p.get("col", i)) % 4, 18.0)
		_t(Vector2(989, y + 12), str(p["name"]), 14, INK, true)
		var cells := [["피해량", "%d" % int(p["dmg"])], ["처치", "%d" % int(p["kills"])], ["감속 기여", "%.0f" % float(p["slow"])], ["지원 능력", "%d회" % int(p["support"])]]
		for k in 4:
			var at := Vector2(959 + (k % 2) * 135, y + 40 + (k / 2) * 48)
			_t(at, cells[k][0], 11, SUB)
			_t(at + Vector2(0, 17), cells[k][1], 15, INK, true)
	_t(Vector2(947, 500), "항목별로 따로 보여 주고 종합 순위는 매기지 않아요.", 11, SUB)


func _result_row(p: Dictionary, i: int, y: float) -> void:
	_card(Rect2(947, y, 284, 73), Color("2B2F33"), Color("2B2F33"))
	_tag(Vector2(966, y + 16), int(p.get("col", i)) % 4, 15.0)
	_t(Vector2(981, y + 7), str(p["name"]), 13, INK, true)
	var cells := [["피해량", "%d" % int(p["dmg"])], ["처치", "%d" % int(p["kills"])], ["감속", "%.0f" % float(p["slow"])], ["지원", "%d회" % int(p["support"])]]
	var xs := [957.0, 1046.0, 1112.0, 1176.0]
	for k in 4:
		_t(Vector2(xs[k], y + 31), cells[k][0], 10, SUB)
		_t(Vector2(xs[k], y + 46), cells[k][1], 14, INK, true)


func _worst_gate(m: GMatch) -> int:
	var best := 0
	for e in m.gate_dmg.size():
		if int(m.gate_dmg[e]) > int(m.gate_dmg[best]):
			best = e
	return best


func _clock(sec: float) -> String:
	var t := int(sec)
	return "%d분 %d초" % [t / 60, t % 60] if t >= 60 else "%d초" % t


func _draw_pause() -> void:
	var v := get_viewport_rect().size
	if _screen == "menu":
		draw_rect(Rect2(-_off, v), Color(0.06, 0.07, 0.08, 0.6))
	if _paused:
		var m := Rect2(120, 140, 300, 420)
		_card(m)
		_t(Vector2(140, 160), "일시정지 · 팀원 화면은 계속 진행", 12, AMBER, true)
		_t(Vector2(140, 188), "메뉴", 22, INK, true)
		_t(Vector2(271, 506), "방장이 나가면 방이 닫힙니다" if s != null and s.is_host and not s.solo else ("" if s != null and s.solo else "다시 초대 링크로 들어올 수 있어요"), 11, Color("8fb4e8"), true, 1)
	if _panel != "":
		var r := Rect2(444, 130, 620, 460)
		_card(r)
		match _panel:
			"settings":
				_t(Vector2(464, 152), "설정", 22, INK, true)
				draw_line(Vector2(464, 228), Vector2(1044, 228), LINE, 1.0)
				_draw_settings_rows()
			"help":
				_t(Vector2(464, 152), "조작 안내", 22, INK, true)
				var keys := [["1 · 2 · 3", "포탑 고르기 (빈 칸 클릭, Shift 로 연속)"], ["Z · X", "길 조각 (길 담당만) · E 확정"], ["Q", "긴급 냉각 (전투 중 1회)"],
					["Alt + 클릭", "주목 핑 · 아래 핑 버튼으로 다른 핑"], ["R · Space", "준비 완료 / 취소"], ["Enter", "채팅 입력 · Esc 로 닫기"], ["Esc", "취소 · 일시정지"], ["우클릭", "선택 해제"]]
				for i in keys.size():
					_key_chip(Vector2(464, 206 + i * 44), str(keys[i][0]))
					_t(Vector2(600, 207 + i * 44), str(keys[i][1]), 14, INK, true)
			"mute":
				_t(Vector2(464, 152), "채팅 음소거 관리", 22, INK, true)
				_t(Vector2(464, 190), "음소거한 사람의 채팅과 핑을 내 화면에서만 숨겨요.", 12, SUB)
				for i in _player_count():
					var y := 250.0 + i * 54.0
					var name_ := str(s.m.players[i]["name"]) if s.m != null else str(s.seats[i]["name"])
					_tag(Vector2(480, y + 17), _col_of_seat(i), 18.0)
					_t(Vector2(500, y + 6), name_ + (" (나)" if i == s.seat else ""), 15, INK, true)
					if _muted.has(i):
						_t(Vector2(930, y + 8), "숨김", 13, DANGER, true, 2)
	_draw_plates(pause)
	if _panel == "settings":
		_draw_settings_art()


func _draw_settings_rows() -> void:
	match _tab:
		1:
			_t(Vector2(464, 252), "조작은 키보드·마우스 기본값으로 고정돼 있어요.", 14, INK, true)
			_t(Vector2(464, 282), "자세한 키는 메뉴의 ‘조작 안내’에서 볼 수 있어요.", 13, SUB)
		2:
			_t(Vector2(464, 252), "소리는 아직 준비 중이에요.", 14, INK, true)
			_t(Vector2(464, 282), "효과음이 들어오면 여기서 크기를 조절해요.", 13, SUB)
	var rows := _settings_rows()
	for i in rows.size():
		var y := 263.0 + i * 52.0
		_t(Vector2(464, y - 9), str(rows[i][2]), 14, INK, true)
		draw_line(Vector2(464, y + 26), Vector2(1044, y + 26), Color(LINE, 0.6), 1.0)


func _draw_settings_art() -> void:
	for k in toggle_btns:
		var b: Button = toggle_btns[k]
		if not b.visible:
			continue
		var on := bool(_cfg_draft.get(k, false))
		var r := Rect2(b.position, b.size)
		draw_rect(r, Color(0.12, 0.13, 0.14))
		draw_rect(r, AMBER if on else LINE, false, 1.0)
		draw_rect(Rect2(r.position + Vector2(24 if on else 4, 4), Vector2(18, 16)), AMBER if on else Color("6a7076"))
	if shake_btn.visible:
		var y := shake_btn.position.y + 13
		var v := float(_cfg_draft.get("shake", 30)) / 100.0
		draw_rect(Rect2(849, y - 3, 160, 6), Color("2f3337"))
		draw_rect(Rect2(849, y - 3, 160 * v, 6), AMBER)
		draw_rect(Rect2(849 + 160 * v - 7, y - 10, 14, 20), INK)
		_t(Vector2(1044, y - 8), str(int(_cfg_draft.get("shake", 30))), 12, INK, true, 2)
