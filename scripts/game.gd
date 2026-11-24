extends Control
## 화면과 입력. 시안의 1280×720 좌표를 그대로 쓰고, 창이 더 크면 가운데에 놓는다.
## 규칙은 GMatch, 온라인은 GSession 이 맡는다.

const NetScript := preload("res://scripts/net.gd")
const BOLD := preload("res://fonts/IBMPlexSansKR-Bold.ttf")
const REG := preload("res://fonts/IBMPlexSansKR-Regular.ttf")
const TEX_TOWERS := preload("res://art/towers.png")
const TEX_ENEMIES := preload("res://art/enemies.png")
const TEX_ICONS := preload("res://art/icons.png")
const TEX_CASTLE := preload("res://art/castle.png")
const TEX_GATE := preload("res://art/gate.png")

const STAGE := Vector2(1280, 720)
const MAP := Vector2(232, 66)
const CELL := 30.0

const BG := Color("1C2023")
const PANEL := Color("23282C")
const WELL := Color("121518")
const LINE := Color("4A5258")
const INK := Color("E6E2D8")
const SUB := Color("A3ABB0")
const AMBER := Color("D9A21B")
const DANGER := Color("B83A2B")
const LAMP := Color("FF4A3A")
const ICE := Color("9FD8E6")
const FIRE := Color("F07A2A")
const GRASS := Color("6E8550")
const GRASS2 := Color("67804A")
const TUFT := Color("58703F")
const ROAD := Color("A08A6A")
const ROAD_EDGE := Color("4E4232")
const OK_GREEN := Color("5BD06A")

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
var retry_btn: Button
var back_btn: Button


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
	if web:
		room = net.room_param()
	host_btn.visible = room == ""
	join_btn.visible = room != ""
	if not web:
		host_btn.disabled = true
	get_viewport().size_changed.connect(_place)
	_show("menu")
	_place.call_deferred()


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
	b.set_corner_radius_all(radius)
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
	var looks: Dictionary
	var ink := INK
	match kind:
		"pri":
			looks = {"normal": _box(AMBER, Color("8E6A12")), "hover": _box(Color("EDB62A"), Color("8E6A12")), "pressed": _box(Color("B9880F"), Color("8E6A12")), "disabled": _box(Color("33383D"), LINE)}
			ink = Color("1A1D20")
		"clear":
			var none := StyleBoxEmpty.new()
			looks = {"normal": none, "hover": _box(Color(1, 1, 1, 0.07), Color(0, 0, 0, 0)), "pressed": _box(Color(1, 1, 1, 0.12), Color(0, 0, 0, 0)), "disabled": none}
		"tile":
			looks = {"normal": _box(PANEL, LINE), "hover": _box(Color("2E353A"), Color("7B868D")), "pressed": _box(Color("3A3220"), AMBER, 3, 2), "disabled": _box(Color("1E2225"), Color("33383D"))}
		_:
			looks = {"normal": _box(Color("2B3035"), LINE), "hover": _box(Color("383E44"), Color("7B868D")), "pressed": _box(WELL, AMBER), "disabled": _box(Color("1E2225"), Color("33383D"))}
	for k in looks:
		b.add_theme_stylebox_override(k, looks[k])
	b.add_theme_stylebox_override("hover_pressed", looks["pressed"])
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", ink)
	b.add_theme_color_override("font_hover_color", ink)
	b.add_theme_color_override("font_pressed_color", AMBER if kind != "pri" else ink)
	b.add_theme_color_override("font_hover_pressed_color", AMBER if kind != "pri" else ink)
	b.add_theme_color_override("font_disabled_color", Color(SUB, 0.5))


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
	chat_toggle = _btn(stage, Rect2(504, 452, 40, 20), "접기", _on_chat_toggle, "clear", 11)


func _build_menu() -> void:
	host_btn = _btn(menu, Rect2(460, 408, 360, 50), "친구와 함께 · 방 만들기", _on_host, "pri", 15)
	join_btn = _btn(menu, Rect2(460, 408, 360, 50), "초대받은 방 입장", _on_join, "pri", 15)
	solo_btn = _btn(menu, Rect2(460, 468, 360, 44), "혼자 연습 · 봇 동료", _on_solo, "sec", 14)


func _build_lobby() -> void:
	_btn(lobby, Rect2(49, 314, 119, 44), "코드 복사", _on_copy_code)
	_btn(lobby, Rect2(176, 314, 119, 44), "초대 링크", _on_copy_link)
	for c in 4:
		col_btns.append(_btn(lobby, Rect2(), "", _on_color.bind(c), "clear"))
	ready_lobby = _btn(lobby, Rect2(), "준비 완료", _on_lobby_ready, "pri", 14)
	_btn(lobby, Rect2(997, 625, 61, 46), "나가기", _on_leave)
	start_btn = _btn(lobby, Rect2(1074, 625, 153, 50), "시작", _on_start, "pri", 16)


func _build_hud() -> void:
	menu_btn = _btn(hud, Rect2(16, 10, 44, 44), "", _on_menu, "clear")
	quit_btn = _btn(hud, Rect2(16, 58, 150, 38), "경기 나가기", _on_leave)
	var keys := {"gun": "1", "cannon": "2", "cold": "3"}
	var names := ["gun", "cannon", "cold"]
	for i in 3:
		var k: String = names[i]
		build_btns[k] = _btn(hud, Rect2(145 + i * 90, 642, 84, 66), "", _set_mode.bind("build:" + k), "clear")
		build_btns[k].tooltip_text = "단축키 %s" % keys[k]
	for i in 3:
		var locked := _btn(hud, Rect2(415 + i * 90, 642, 84, 66), "", _noop, "clear")
		locked.disabled = true
		locked.tooltip_text = "2단계에서 열려요"
	road_btns["detour"] = _btn(hud, Rect2(28, 398, 88, 50), "우회로\n+4칸 · Z", _set_mode.bind("road:detour"), "sec", 12)
	road_btns["bend"] = _btn(hud, Rect2(120, 398, 88, 50), "굽잇길\n+2칸 · X", _set_mode.bind("road:bend"), "sec", 12)
	confirm_btn = _btn(hud, Rect2(28, 454, 112, 34), "확정 · 기회 1", _on_confirm, "pri", 12)
	cancel_btn = _btn(hud, Rect2(144, 454, 64, 34), "취소", _on_cancel_draft, "sec", 12)
	ability_btn = _btn(hud, Rect2(709, 624, 134, 80), "", _set_mode.bind("ability"), "clear")
	for i in 5:
		var b := _btn(hud, Rect2(858 + i * 44, 653, 40, 44), "", _on_ping_kind.bind(PING_ORDER[i]), "clear")
		b.tooltip_text = GData.PING_KINDS[PING_ORDER[i]]
		ping_btns.append(b)
	ready_btn = _btn(hud, Rect2(1101, 629, 148, 50), "준비 완료", _on_ready, "pri", 16)
	var keys_order := ["first", "strong", "near"]
	var slots := [Rect2(1065, 461, 91, 36), Rect2(1160, 461, 91, 36), Rect2(1160, 503, 91, 36)]
	for i in 3:
		prio_btns[keys_order[i]] = _btn(hud, slots[i], PRIO[keys_order[i]], _on_prio.bind(keys_order[i]), "sec", 12)
		prio_btns[keys_order[i]].toggle_mode = true
	up_btn = _btn(hud, Rect2(1065, 313, 186, 54), "", _on_upgrade.bind(""), "sec", 12)
	a_btn = _btn(hud, Rect2(1065, 313, 186, 54), "", _on_upgrade.bind("a"), "sec", 12)
	b_btn = _btn(hud, Rect2(1065, 373, 186, 54), "", _on_upgrade.bind("b"), "sec", 12)
	move_btn = _btn(hud, Rect2(1065, 546, 94, 40), "이동 무료", _on_move, "sec", 12)
	sell_btn = _btn(hud, Rect2(1165, 546, 86, 40), "판매", _on_sell, "sec", 12)


func _build_result() -> void:
	retry_btn = _btn(result, Rect2(396, 498, 346, 50), "같은 멤버로 재도전", _on_retry, "pri", 15)
	back_btn = _btn(result, Rect2(752, 498, 154, 50), "로비로", _on_back, "sec", 13)


func _noop() -> void:
	pass


func _show(which: String) -> void:
	_screen = which
	menu.visible = which == "menu"
	lobby.visible = which == "lobby"
	hud.visible = which == "game"
	result.visible = which == "result"
	_menu_open = false
	_chat_key = ""
	if web:
		var ui = JavaScriptBridge.get_interface("GilUI")
		if which == "menu" or which == "lobby":
			ui.show("name", "내 이름 (10자)", 10, 0, 0, 10, 1, true)
			if which == "menu":
				ui.put("name", str(ui.saved()))
		else:
			ui.hide("name")
		if which == "menu":
			ui.hide("chat")
		else:
			ui.show("chat", "Enter 를 눌러 채팅", GSession.CHAT_MAX, 0, 0, 10, 1, false)
	_place()


func _place() -> void:
	var v := get_viewport_rect().size
	_off = ((v - STAGE) * 0.5).max(Vector2.ZERO).floor()
	stage.position = _off
	_place_chat()
	if not web:
		return
	var ui = JavaScriptBridge.get_interface("GilUI")
	var canvas = JavaScriptBridge.get_interface("document").querySelector("canvas")
	if canvas == null:
		return
	var scale: float = float(canvas.getBoundingClientRect().width) / maxf(v.x, 1.0)
	if _screen == "menu":
		ui.show("name", "내 이름 (10자)", 10, _off.x + 460, _off.y + 352, 360, scale, true)
	elif _screen == "lobby":
		var x := 351.0 if s != null and s.seat <= 0 else 659.0
		ui.show("name", "내 이름 (10자)", 10, _off.x + x, _off.y + 320, 270, scale, true)
	if _screen == "game" and chat_open:
		ui.show("chat", "Enter 를 눌러 채팅", GSession.CHAT_MAX, _off.x + 252, _off.y + 555, 286, scale, false)
	elif _screen == "game":
		ui.hide("chat")
	elif _screen == "lobby":
		ui.show("chat", "Enter 를 눌러 채팅", GSession.CHAT_MAX, _off.x + 984, _off.y + 526, 248, scale, false)
	elif _screen == "result":
		ui.show("chat", "Enter 를 눌러 채팅", GSession.CHAT_MAX, _off.x + 900, _off.y + 640, 332, scale, false)


func _place_chat() -> void:
	var show_chat := _screen != "menu"
	chat_box.visible = show_chat
	chat_toggle.visible = _screen == "game"
	chat_block.visible = show_chat and (_screen != "game" or chat_open)
	chat_toggle.text = "접기" if chat_open else "펼치기"
	match _screen:
		"game":
			if chat_open:
				chat_block.position = Vector2(240, 448)
				chat_block.size = Vector2(310, 150)
				chat_box.position = Vector2(252, 474)
				chat_box.size = Vector2(286, 76)
				chat_toggle.position = Vector2(504, 452)
			else:
				chat_box.position = Vector2(252, 536)
				chat_box.size = Vector2(286, 62)
				chat_toggle.position = Vector2(504, 514)
			chat_box.mouse_filter = Control.MOUSE_FILTER_STOP if chat_open else Control.MOUSE_FILTER_IGNORE
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


# ── 메뉴·로비 동작 ──

func _player_name() -> String:
	if web:
		var ui = JavaScriptBridge.get_interface("GilUI")
		var n := str(ui.value("name")).strip_edges().left(10)
		if n == "":
			n = "플레이어"
		ui.save(n)
		return n
	return "플레이어"


func _on_host() -> void:
	s = GSession.new(net, _player_name(), net.token())
	_name_sent = s.my_name
	net.host()
	s.open_host()
	_show("lobby")


func _on_join() -> void:
	s = GSession.new(net, _player_name(), net.token())
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
	_menu_open = not _menu_open


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
			_predict(delta)
			_take_fx()
			_update_hover()
			_update_hud()
		elif _screen == "result":
			_update_result()
	for i in range(_fxs.size() - 1, -1, -1):
		_fxs[i]["t"] -= delta
		if _fxs[i]["t"] <= 0.0:
			_fxs.remove_at(i)
	queue_redraw()


## 세션 상태에 맞는 화면으로 옮긴다
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


func _say(text: String) -> void:
	_toast = text
	_toast_t = 2.6


func _update_lobby(delta: float) -> void:
	var mine := s.seat
	var x := 351.0 if mine <= 0 else 659.0
	for c in 4:
		var b: Button = col_btns[c]
		b.position = Vector2(x + c * 42, 394)
		b.size = Vector2(36, 36)
		b.visible = mine >= 0
		var taken := false
		for i in s.seats.size():
			if i != mine and int(s.seats[i]["col"]) == c:
				taken = true
		b.disabled = taken
	ready_lobby.visible = mine >= 0 and mine < s.seats.size()
	ready_lobby.position = Vector2(x, 442)
	ready_lobby.size = Vector2(270, 44)
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
	start_btn.text = "시작 · 준비 %d/2" % ready_n
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
	var key := "%d:%d:%s:%s" % [s.chat.size(), pending, str(chat_open), str(s.chat[-1].get("text", "")).md5_text() if s.chat.size() > 0 else ""]
	if key == _chat_key:
		return
	_chat_key = key
	chat_box.clear()
	var rows: Array = s.chat
	if _screen == "game" and not chat_open:
		rows = rows.slice(maxi(rows.size() - 3, 0))
	for row in rows:
		var who := int(row["seat"])
		if who >= 0:
			var col := _col_of_seat(who)
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
			chat_box.add_text(str(row["text"]))
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
	quit_btn.visible = _menu_open
	for k in build_btns:
		build_btns[k].disabled = not prep or int(me["gold"]) < int(GData.TOWERS[k]["cost"])
		build_btns[k].set_pressed_no_signal(false)
	var owner_turn := m.road_owner == s.seat
	var can_road := prep and owner_turn and m.edits_left > 0
	for k in road_btns:
		road_btns[k].visible = owner_turn and prep
		road_btns[k].disabled = not can_road
	confirm_btn.visible = owner_turn and prep
	cancel_btn.visible = owner_turn and prep
	confirm_btn.disabled = not can_road or m.draft.is_empty()
	cancel_btn.disabled = m.draft.is_empty()
	ability_btn.disabled = m.phase != "combat" or bool(me["used"])
	ready_btn.visible = prep
	if prep:
		var r: bool = me["ready"]
		ready_btn.text = "준비 취소" if r else "준비 완료"
		_style(ready_btn, "sec" if r else "pri")
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
		up_btn.text = "2단계 강화 · %dG" % int(d["up"][0])
		up_btn.disabled = gold < int(d["up"][0])
	elif lv == 2:
		a_btn.visible = true
		b_btn.visible = true
		a_btn.text = "%s · %dG" % [d["a"]["label"], int(d["up"][1])]
		b_btn.text = "%s · %dG" % [d["b"]["label"], int(d["up"][1])]
		a_btn.disabled = gold < int(d["up"][1])
		b_btn.disabled = a_btn.disabled
	sell_btn.text = "판매 +%d" % int(floor(int(t["spent"]) * GData.SELL_RATE))


func _update_result() -> void:
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
	if s == null or not ev.pressed or ev.echo or _typing():
		return
	if ev.keycode == KEY_ENTER or ev.keycode == KEY_KP_ENTER:
		if _screen == "game" and not chat_open:
			_on_chat_toggle()
		if web and _screen != "menu":
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
		KEY_SPACE: _on_ready()
		KEY_ESCAPE:
			mode = ""
			selected = -1


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
	draw_style_box(_box(fill, edge, radius), r)


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
	else:
		draw_arc(ic + Vector2(2, 0), 6.5, PI * 0.62, PI * 1.38, 14, AMBER, 2.2, true)
	_t(center + Vector2(9, -10), str(e + 1), 15, AMBER, true, 1)


# ── 지도 ──

func _p(g: Vector2) -> Vector2:
	return MAP + g * CELL + Vector2(sin(_tick * 60.0), cos(_tick * 53.0)) * _shake * 2.0


func _draw_ground() -> void:
	draw_rect(Rect2(_p(Vector2.ZERO), Vector2(GData.W, GData.H) * CELL), GRASS)
	for y in GData.H:
		for x in GData.W:
			var at := _p(Vector2(x, y))
			if posmod(x - y, 5) == 1:
				draw_rect(Rect2(at, Vector2(CELL, CELL)), GRASS2)
			var h := (x * 73856093) ^ (y * 19349663)
			if posmod(h, 7) == 0:
				var o := at + Vector2(8 + posmod(h, 13), 9 + posmod(h >> 3, 12))
				draw_polyline(PackedVector2Array([o, o + Vector2(2, -3), o + Vector2(4, 0), o + Vector2(6, -3)]), TUFT, 1.0)
	for x in GData.W + 1:
		draw_line(_p(Vector2(x, 0)), _p(Vector2(x, GData.H)), Color(TUFT, 0.3), 1.0)
	for y in GData.H + 1:
		draw_line(_p(Vector2(0, y)), _p(Vector2(GData.W, y)), Color(TUFT, 0.3), 1.0)


func _draw_road(path: Array, fill := ROAD, edge := ROAD_EDGE) -> void:
	for c in path:
		draw_rect(Rect2(_p(Vector2(c)), Vector2(CELL, CELL)), edge)
	for i in path.size():
		var a := _p(Vector2(path[i]))
		draw_rect(Rect2(a + Vector2(3, 3), Vector2(CELL - 6, CELL - 6)), fill)
		if i > 0:
			var b := _p(Vector2(path[i - 1]))
			var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) + Vector2(3, 3)
			var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(CELL - 3, CELL - 3)
			draw_rect(Rect2(lo, hi - lo), fill)


func _draw_chevrons(path: Array, col := Color(0.18, 0.14, 0.09, 0.75)) -> void:
	var d := fmod(_tick * 0.8, 3.0) + 0.5
	while d < path.size() - 1:
		var a := Board.pos_on(path, d)
		var dir := (Board.pos_on(path, d + 0.08) - a).normalized()
		var n := Vector2(-dir.y, dir.x)
		var p := _p(a)
		draw_polyline(PackedVector2Array([p - dir * 4 + n * 5, p + dir * 2, p - dir * 4 - n * 5]), col, 1.8, true)
		d += 3.0


func _draw_castle() -> void:
	var r := GData.CASTLE
	draw_texture_rect(TEX_CASTLE, Rect2(_p(Vector2(r.position)), Vector2(r.size) * CELL), false)


func _draw_gates(m: GMatch) -> void:
	for e in m.board.paths.size():
		var c: Vector2i = m.board.paths[e][0]
		draw_texture_rect_region(TEX_GATE, Rect2(_p(Vector2(c)), Vector2(CELL, CELL)), Rect2(e * 120, 0, 120, 120))
		var bx := 0.5 + 0.6 if e == 0 else 0.5 - 0.6
		_gate_badge(_p(Vector2(c) + Vector2(bx, 1.55)), e)


func _draw_gate_cards(m: GMatch) -> void:
	var w := clampi(m.wave - 1, 0, GData.WAVES.size() - 1)
	for e in 2:
		var counts := {}
		for g in GData.WAVES[w]:
			if int(g[0]) == e:
				counts[g[1]] = int(counts.get(g[1], 0)) + int(g[2])
		var width := 150.0
		var r := Rect2(MAP + Vector2(4, 308), Vector2(width, 56)) if e == 0 else Rect2(MAP + Vector2(810 - width - 8, 142), Vector2(width, 56))
		draw_style_box(_box(Color(0.16, 0.12, 0.07, 0.94), AMBER, 5), r)
		_t(r.position + Vector2(10, 6), "%d번 입구" % (e + 1), 12, INK, true)
		_t(r.position + Vector2(width - 8, 8), "다음 웨이브", 10, SUB, false, 2)
		var x := r.position.x + 8
		for k in counts:
			_enemy_icon(k, Rect2(x, r.position.y + 28, 22, 22))
			_t(Vector2(x + 23, r.position.y + 32), "×%d" % counts[k], 12, INK, true)
			x += 50


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
	var r := Rect2(MAP + Vector2(610, 432), Vector2(196, 66))
	draw_style_box(_box(Color(0.1, 0.11, 0.13, 0.96), LINE, 5), r)
	_t(r.position + Vector2(10, 7), label, 11, SUB)
	_t(r.position + Vector2(10, 26), "%d칸" % before, 22, Color("8C939A"), true)
	_t(r.position + Vector2(76, 30), "→", 16, SUB, true)
	_t(r.position + Vector2(104, 26), "%d칸" % after, 22, AMBER if after > before else (LAMP if after < before else INK), true)


func _banner(text: String, col: Color, danger := false) -> void:
	var w := BOLD.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 34
	var r := Rect2(MAP + Vector2(405 - w * 0.5, 8), Vector2(w, 38))
	draw_style_box(_box(Color("211A0E") if not danger else Color("2A1412"), col, 3, 2), r)
	_t(r.position + Vector2(17, 10), text, 13, INK if not danger else Color("FFB4A8"), true)


func _draw_tower(m: GMatch, t: Dictionary) -> void:
	var at := _p(Vector2(int(t["x"]), int(t["y"])))
	_tower_sprite(t["type"], int(t["lv"]), str(t["branch"]), int(m.players[int(t["owner"])].get("col", 0)) % 4, at, CELL)
	if int(t["id"]) == selected:
		var st := GData.tower_stats(t["type"], int(t["lv"]), str(t["branch"]))
		var center := at + Vector2(CELL, CELL) * 0.5
		draw_circle(center, float(st["range"]) * CELL, Color(ICE, 0.09))
		draw_arc(center, float(st["range"]) * CELL, 0, TAU, 56, Color(1, 1, 1, 0.75), 1.5, true)
		draw_rect(Rect2(at, Vector2(CELL, CELL)), AMBER, false, 1.5)


func _draw_enemy(m: GMatch, en: Dictionary) -> void:
	var path: Array = m.board.paths[int(en["e"])]
	var d: float = _disp.get(int(en["id"]), float(en["dist"]))
	var pos := Board.pos_on(path, d)
	var dir := Board.pos_on(path, d + 0.12) - pos
	var center := _p(pos)
	var size_px: float = ENEMY_SIZE[en["type"]]
	var angle := dir.angle() + PI * 0.5 if dir.length() > 0.001 else 0.0
	draw_set_transform(_off + center, angle)
	_enemy_icon(en["type"], Rect2(-size_px * 0.5, -size_px * 0.5, size_px, size_px))
	draw_set_transform(_off)
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
	var w := BOLD.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var x := clampf(center.x - w * 0.5, MAP.x + 8, MAP.x + 810 - w - 8)
	draw_style_box(_box(Color(0.07, 0.08, 0.09, 0.94), LINE, 4), Rect2(x - 8, center.y - 12, w + 16, 24))
	_t(Vector2(x, center.y - 8), text, 12, INK, true)


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
	if _toast_t > 0.0 and _screen != "game":
		_tip(Vector2(640, 118), _toast)


func _draw_title(at: Vector2, px: int) -> void:
	var cone := Rect2(at, Vector2(px * 1.3, px * 1.3))
	_icon(Vector2i(4, 2), cone)
	_t(at + Vector2(px * 1.5, 0), "길 좀 막아봐", px, INK, true)
	var w := BOLD.get_string_size("길 좀 막아봐", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	_hazard(Rect2(at + Vector2(px * 1.5, px * 1.38), Vector2(w, 9)))


func _draw_menu() -> void:
	_hazard(Rect2(-_off.x, -_off.y, get_viewport_rect().size.x, 12))
	_card(Rect2(420, 170, 440, 370))
	_draw_title(Vector2(494, 196), 40)
	_t(Vector2(640, 276), "친구들과 길을 막고 성을 지키는 협동 타워디펜스", 14, SUB, false, 1)
	_t(Vector2(460, 330), "이름", 12, SUB, true)
	if room != "":
		_t(Vector2(640, 306), "친구의 방에 초대받았어요", 13, AMBER, true, 1)
	if not web:
		_t(Vector2(640, 516), "친구 초대는 웹 빌드에서만 돼요", 12, SUB, false, 1)


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
	_t(Vector2(49, 560), "초원 · 입구 2개 · 거의 대칭", 12, SUB)
	for i in 2:
		_draw_crew(i)
	var r := Rect2(336, 494, 608, 76)
	_dashed_rect(r, Color("5C6268"))
	_icon(Vector2i(3, 2), Rect2(432, 514, 34, 34), Color(1, 1, 1, 0.75))
	_t(Vector2(482, 523), "반장 3 · 반장 4 자리", 13, SUB, true)
	_t(Vector2(616, 524), "3단계 업데이트에서 열려요 · 3인부터 입구 3개", 12, SUB)
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


func _draw_crew(i: int) -> void:
	var x := 336.0 + i * 308.0
	_card(Rect2(x, 140, 300, 340))
	_t(Vector2(x + 15, 160), "반장 %d" % (i + 1), 17, INK, true)
	if i == 0:
		_card(Rect2(x + 248, 157, 37, 22), WELL, WELL)
		_t(Vector2(x + 266, 161), "방장", 11, AMBER, true, 1)
	var prev := Rect2(x + 15, 194, 270, 90)
	draw_rect(prev, GRASS)
	draw_rect(prev, Color("4A5258"), false, 1.0)
	var has := i < s.seats.size()
	var col := int(s.seats[i]["col"]) if has else i
	if has:
		_tower_sprite("cold" if i == 0 else "cannon", 1, "", col, prev.position + Vector2(100, 10), 72.0)
	else:
		_t(Vector2(x + 150, 228), "친구를 기다리는 중", 13, Color(1, 1, 1, 0.82), true, 1)
	_t(Vector2(x + 15, 298), "이름", 12, SUB)
	if i != s.seat:
		_card(Rect2(x + 15, 318, 270, 42), WELL, LINE)
		_t(Vector2(x + 27, 329), str(s.seats[i]["name"]) if has else "-", 14, INK, true)
	_t(Vector2(x + 15, 374), "색과 기호", 12, SUB)
	for c in 4:
		var r := Rect2(x + 15 + c * 42, 394, 36, 36)
		var picked := has and col == c
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
		var is_ready: bool = has and bool(s.seats[i]["ready"])
		var box := Rect2(x + 15, 442, 270, 44)
		_card(box, AMBER if is_ready else Color("33383D"), Color("8E6A12") if is_ready else LINE)
		_t(box.get_center() + Vector2(0, -8), "준비 완료" if is_ready else ("준비 중…" if has else "빈자리"), 14, Color("1A1D20") if is_ready else SUB, true, 1)


func _dashed_rect(r: Rect2, col: Color) -> void:
	var a := r.position
	var b := r.position + Vector2(r.size.x, 0)
	var c := r.end
	var d := r.position + Vector2(0, r.size.y)
	for seg in [[a, b], [b, c], [c, d], [d, a]]:
		draw_dashed_line(seg[0], seg[1], col, 1.5, 6.0)


func _draw_mini(r: Rect2, m) -> void:
	var scale := minf(r.size.x / (GData.W * CELL), r.size.y / (GData.H * CELL))
	var board_size := Vector2(GData.W, GData.H) * CELL * scale
	var at := r.position + (r.size - board_size) * 0.5
	draw_set_transform(_off + at - MAP * scale, 0, Vector2(scale, scale))
	var keep := _shake
	_shake = 0.0
	_draw_ground()
	var paths: Array = m.board.paths if m != null else Board.new().paths
	var worst := -1
	if m != null and not m.cleared and s.state != "lost":
		worst = 0 if int(m.gate_dmg[0]) >= int(m.gate_dmg[1]) else 1
	for e in paths.size():
		if e == worst:
			_draw_road(paths[e], Color("A8564A"), Color("6A2A22"))
		else:
			_draw_road(paths[e])
		_draw_chevrons(paths[e])
	_draw_castle()
	for e in paths.size():
		var c: Vector2i = paths[e][0]
		draw_texture_rect_region(TEX_GATE, Rect2(_p(Vector2(c)), Vector2(CELL, CELL)), Rect2(e * 120, 0, 120, 120))
	if m != null:
		for id in m.towers:
			var t: Dictionary = m.towers[id]
			_tower_sprite(t["type"], int(t["lv"]), str(t["branch"]), int(m.players[int(t["owner"])].get("col", 0)) % 4, _p(Vector2(int(t["x"]), int(t["y"]))), CELL)
	_shake = keep
	draw_set_transform(_off)


func _draw_game() -> void:
	var m := s.m
	var edit := _draft_data(m)
	_draw_ground()
	for path in m.board.paths:
		_draw_road(path)
		_draw_chevrons(path)
	_draw_draft(m, edit)
	_draw_castle()
	_draw_gates(m)
	for id in m.towers:
		_draw_tower(m, m.towers[id])
	for en in m.enemies:
		_draw_enemy(m, en)
	_draw_fx()
	if m.phase == "prep" and edit.is_empty() and not mode.begins_with("road:"):
		_draw_gate_cards(m)
	_draw_pings()
	_draw_cursor(m)
	if _flash_t > 0.0:
		draw_arc(_p(_flash), CELL * (0.8 + 0.25 * sin(_tick * 9.0)), 0, TAU, 28, AMBER, 3.0, true)
	if not edit.is_empty():
		_draw_draft_info(m, edit)
	elif m.phase == "combat" and m.wave == GData.THEME_LEN:
		_banner("보스 등장 · 1번 입구 · 도착하면 성 -15", DANGER, true)
	if s.host_away:
		_banner("방장이 다른 탭을 보고 있어 게임이 잠시 멈췄어요", DANGER, true)
	if _toast_t > 0.0:
		_tip(MAP + Vector2(405, 66), _toast)
	_draw_chat_panel()
	_draw_top(m)
	_draw_team(m)
	_draw_inspector(m)
	_draw_bottom(m)


func _draw_chat_panel() -> void:
	if chat_open:
		draw_rect(Rect2(240, 448, 310, 150), Color(0.12, 0.14, 0.15, 0.9))
		_t(Vector2(252, 456), "방 채팅", 11, SUB)
	else:
		draw_rect(Rect2(240, 512, 310, 86), Color(0.07, 0.08, 0.09, 0.5))
		_t(Vector2(252, 518), "방 채팅 · Enter", 11, SUB)


func _draw_top(m: GMatch) -> void:
	_card(Rect2(16, 10, 44, 44))
	for k in 3:
		draw_rect(Rect2(29, 24 + k * 7, 18, 2), INK)
	_card(Rect2(68, 10, 148, 44))
	_t(Vector2(81, 13), "방 코드" if not s.solo else "모드", 10, SUB)
	_t(Vector2(81, 28), _room_code() if not s.solo else "혼자 연습", 15, INK, true)
	_card(Rect2(380, 8, 520, 50))
	_icon(Vector2i(1, 2), Rect2(394, 18, 30, 30))
	_t(Vector2(438, 18), "성 체력", 12, SUB)
	_t(Vector2(730, 12), "%d / %d" % [m.hp, GData.CASTLE_HP], 18, INK, true, 2)
	var seg := 13.0
	var lit := ceili(float(m.hp) / GData.CASTLE_HP * 20.0)
	for k in 20:
		draw_rect(Rect2(439 + k * 14.6, 42, seg, 12), DANGER.lightened(0.12) if k < lit else Color("33383D"))
	draw_line(Vector2(746, 16), Vector2(746, 50), LINE, 1.0)
	_t(Vector2(760, 12), "웨이브 %d" % m.wave, 18, INK, true)
	for k in GData.LAST_WAVE:
		var r := Rect2(761 + k * 14, 38, 10, 10)
		var boss := k + 1 == GData.THEME_LEN
		if k + 1 < m.wave or (k + 1 == m.wave and m.phase != "prep"):
			draw_rect(r, LAMP if boss else AMBER)
		elif k + 1 == m.wave:
			draw_rect(r, AMBER)
		else:
			draw_rect(r, Color("33383D"))
			draw_rect(r, LINE, false, 1.0)
	_t(Vector2(848, 37), "초원 %d/%d" % [m.wave, GData.LAST_WAVE], 11, SUB)
	_card(Rect2(934, 8, 330, 50))
	_icon(Vector2i(2, 2), Rect2(946, 18, 30, 30))
	_t(Vector2(985, 14), "시제품 구간 · 6웨이브까지", 11, SUB)
	_t(Vector2(985, 32), "초원 — 특수 환경 없음", 14, INK, true)


func _draw_team(m: GMatch) -> void:
	_card(Rect2(16, 72, 200, 428 if m.phase == "prep" and m.road_owner == s.seat else 312))
	_t(Vector2(30, 86), "팀", 15, INK, true)
	var ready_n := 0
	for p in m.players:
		if p["ready"]:
			ready_n += 1
	_t(Vector2(202, 90), ("준비 %d/%d" % [ready_n, m.players.size()]) if m.phase == "prep" else "전투 중", 11, SUB, false, 2)
	var y := 115.0
	for i in m.players.size():
		var p: Dictionary = m.players[i]
		var col := int(p.get("col", i)) % 4
		var h := 84.0 if i == m.road_owner else 68.0
		if i == s.seat:
			draw_rect(Rect2(26, y, 181, h), Color("2B3035"))
		_tag(Vector2(48, y + 22), col, 22.0)
		_t(Vector2(68, y + 12), "%s%s" % [str(p["name"]).left(8), " (나)" if i == s.seat else ""], 14, INK, true)
		draw_circle(Vector2(192, y + 22), 4.5, Color("3FB27F") if p["online"] else Color("6A7076"))
		var chip := "끊김" if not p["online"] else ("전투 중" if m.phase == "combat" else ("준비됨" if p["ready"] else ("길 담당" if i == m.road_owner else "건설 중")))
		var yellow := chip == "준비됨" or chip == "길 담당"
		var cw := BOLD.get_string_size(chip, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 16
		draw_rect(Rect2(35, y + 41, cw, 21), AMBER if yellow else Color("3A3628"))
		_t(Vector2(43, y + 44), chip, 11, Color("1A1D20") if yellow else INK, true)
		_t(Vector2(197, y + 45), "골드 %d" % int(p["gold"]), 11, SUB, false, 2)
		if i == m.road_owner:
			_icon(Vector2i(3, 2), Rect2(36, y + 64, 15, 15))
			_t(Vector2(56, y + 65), "이번 웨이브 길 담당", 11, AMBER, true)
		y += h + 8
	draw_dashed_line(Vector2(30, y + 3), Vector2(204, y + 3), LINE, 1.0, 5.0)
	_t(Vector2(34, y + 14), "길 개조 기회 · 이번 테마", 11, SUB)
	for k in GData.EDITS_PER_THEME:
		_icon(Vector2i(3, 2), Rect2(36 + k * 34, y + 34, 26, 26), Color.WHITE if k < m.edits_left else Color(0.5, 0.5, 0.5, 0.35))
	_t(Vector2(112, y + 36), "%d / %d" % [m.edits_left, GData.EDITS_PER_THEME], 17, INK, true)


func _draw_inspector(m: GMatch) -> void:
	var r := Rect2(1052, 72, 212, 534)
	_card(r)
	var t: Dictionary = m.towers.get(selected, {})
	if t.is_empty():
		_draw_wave_info(m)
		return
	var d: Dictionary = GData.TOWERS[t["type"]]
	var col := int(m.players[int(t["owner"])].get("col", 0)) % 4
	_tower_sprite(t["type"], int(t["lv"]), str(t["branch"]), col, Vector2(1067, 88), 60.0)
	_t(Vector2(1139, 94), str(d["name"]), 18, INK, true)
	_tag(Vector2(1146, 132), col, 12.0)
	_t(Vector2(1160, 125), "%s · %d단계" % [str(m.players[int(t["owner"])]["name"]).left(5), int(t["lv"])], 12, SUB)
	var st := GData.tower_stats(t["type"], int(t["lv"]), str(t["branch"]))
	var rows := [["피해", "%.0f" % st["dmg"]], ["사거리", "%.1f칸" % st["range"]], ["공격 간격", "%.2f초" % st["cd"]]]
	if t["type"] == "cold":
		rows = [["감속", "%d%% · 상한 60%%" % roundi(st["slow"] * 100)], ["범위" if st["aura"] else "사거리", "%.1f칸" % st["range"]],
			["대상", "범위 안 전부" if st["aura"] else "한 대상"], ["공격 간격", "%.2f초" % st["cd"]]]
	if st["splash"] > 0.0:
		rows.append(["폭발 반경", "%.1f칸" % st["splash"]])
	if st["line"]:
		rows.append(["공격", "일직선 관통"])
	if st["pierce"] > 0.0:
		rows.append(["방어 무시", "%.0f" % st["pierce"]])
	var y := 158.0
	var limit := 5 if int(t["lv"]) >= 3 else 4   # 3단계는 강화 버튼이 없어 한 줄 더 들어간다
	for i in mini(rows.size(), limit):
		_t(Vector2(1066, y), rows[i][0], 12, SUB)
		_t(Vector2(1250, y), rows[i][1], 12, INK, true, 2)
		draw_line(Vector2(1065, y + 22), Vector2(1251, y + 22), Color("33383D"), 1.0)
		y += 30
	var mine := int(t["owner"]) == s.seat
	var cover := Board.coverage(Vector2i(int(t["x"]), int(t["y"])), float(st["range"]), m.board.paths)
	if int(t["lv"]) == 2 and mine and m.phase == "prep":
		_t(Vector2(1066, 291), "3단계 · 하나만 고르기", 11, INK, true)
	elif int(t["lv"]) == 1 and mine and m.phase == "prep":
		_t(Vector2(1066, 291), "사거리 안 길 %d칸" % cover, 11, AMBER, true)
	if int(t["lv"]) != 1 or not mine or m.phase != "prep":
		if not (int(t["lv"]) == 2 and mine and m.phase == "prep"):
			_card(Rect2(1065, 314, 186, 64), Color("1C2A2E"), Color("3A6A72"))
			_t(Vector2(1076, 322), "사거리 안 길", 12, ICE, true)
			_t(Vector2(1240, 344), "%d칸" % cover, 15, INK, true, 2)
			if str(t["branch"]) != "":
				_t(Vector2(1076, 349), str(d[t["branch"]]["label"]), 11, SUB)
	if mine:
		_t(Vector2(1066, 441), "목표 우선순위" + (" · 전투 중 변경 가능" if m.phase == "combat" else ""), 11, SUB)
		var locked := Rect2(1065, 503, 91, 36)
		_card(locked, Color("1E2225"), Color("33383D"))
		_t(locked.get_center() + Vector2(0, -7), "치유사", 12, Color(SUB, 0.45), true, 1)
	else:
		_t(Vector2(1066, 441), "친구의 포탑이에요", 12, SUB)


func _draw_wave_info(m: GMatch) -> void:
	_t(Vector2(1066, 88), "웨이브 %d" % m.wave, 18, INK, true)
	_t(Vector2(1250, 94), "다음 적" if m.phase == "prep" else "진행 중", 11, AMBER, true, 2)
	var y := 124.0
	var w := clampi(m.wave - 1, 0, GData.WAVES.size() - 1)
	for e in 2:
		_gate_badge(Vector2(1098, y + 13), e)
		y += 34
		var counts := {}
		for g in GData.WAVES[w]:
			if int(g[0]) == e:
				counts[g[1]] = int(counts.get(g[1], 0)) + int(g[2])
		for k in counts:
			_enemy_icon(k, Rect2(1066, y - 3, 26, 26))
			_t(Vector2(1098, y + 2), str(GData.ENEMIES[k]["name"]), 12, INK)
			_t(Vector2(1250, y + 2), "×%d" % counts[k], 13, INK, true, 2)
			y += 28
		y += 12
	draw_line(Vector2(1065, y), Vector2(1251, y), Color("33383D"), 1.0)
	var tips := ["포탑을 누르면 정보와 강화가 나와요.", "길 담당은 왼쪽 패널의 길 조각으로", "적의 길을 내 포탑 쪽으로 꺾어요."]
	for i in tips.size():
		_t(Vector2(1066, y + 12 + i * 20), tips[i], 11, SUB)


func _draw_bottom(m: GMatch) -> void:
	_card(Rect2(16, 616, 1248, 96))
	var me: Dictionary = m.players[s.seat]
	_t(Vector2(31, 637), "내 골드", 12, SUB)
	_icon(Vector2i(6, 2), Rect2(33, 660, 26, 26))
	_t(Vector2(67, 658), str(int(me["gold"])), 22, INK, true)
	draw_line(Vector2(130, 632), Vector2(130, 700), LINE, 1.0)
	_t(Vector2(145, 622), "건설 · 고른 뒤 빈 칸을 클릭" if m.phase == "prep" else "건설 잠김 · 전투가 끝나면 다시 열려요", 11, SUB)
	_draw_build_tiles(m)
	draw_line(Vector2(694, 632), Vector2(694, 700), LINE, 1.0)
	_draw_ability(m)
	_t(Vector2(858, 632), "핑 · Alt+클릭", 11, SUB)
	for i in 5:
		var r := Rect2(858 + i * 44, 653, 40, 44)
		var active: bool = mode == "ping:" + str(PING_ORDER[i])
		_card(r, PING_COL[i], AMBER if active else WELL)
		_icon(Vector2i(i, 1), Rect2(r.get_center() - Vector2(14, 14), Vector2(28, 28)))
	if m.phase == "prep":
		_t(Vector2(1175, 686), "건설을 바꾸면 준비가 풀려요", 11, SUB, false, 1)
	else:
		_t(Vector2(1102, 632), "전투 배속", 11, SUB)
		var r := Rect2(1102, 653, 147, 44)
		_card(r, WELL, LINE)
		_t(r.get_center() + Vector2(0, -8), "1배 · 2배는 3단계", 12, AMBER, true, 1)


func _draw_build_tiles(_m: GMatch) -> void:
	var names := ["gun", "cannon", "cold"]
	var my_col := int(s.m.players[s.seat].get("col", 0)) % 4
	for i in 6:
		var r := Rect2(145 + i * 90, 642, 84, 66)
		var key: String = names[i] if i < 3 else LOCKED[i - 3][0]
		var label: String = GData.TOWERS[key]["name"] if i < 3 else LOCKED[i - 3][1]
		var usable: bool = i < 3 and not build_btns[key].disabled
		var picked := i < 3 and mode == "build:" + key
		_defer_tile(r, key, label, usable, picked, i, my_col)


func _defer_tile(r: Rect2, key: String, label: String, usable: bool, picked: bool, i: int, col: int) -> void:
	# 버튼이 위에 그려지므로 그림은 버튼 쪽에 맡기지 않고 투명 처리된 타일 위에 얹는다
	_card(r, Color("3A3220") if picked else (PANEL if usable else Color("1E2225")), AMBER if picked else (LINE if usable else Color("33383D")))
	var tint := Color.WHITE if usable else Color(0.55, 0.55, 0.55, 0.65)
	_tower_sprite(key, 1, "", col, r.position + Vector2(27, 9), 30.0, tint)
	var ink := INK if usable else Color(SUB, 0.6)
	var tail := ("%d" % int(GData.TOWERS[key]["cost"])) if i < 3 else "2단계"
	var line := "%s · %s" % [label, tail]
	var px := 10 if line.length() > 8 else 11
	_t(r.position + Vector2(42, 47), line, px, ink, true, 1)


func _draw_ability(m: GMatch) -> void:
	var r := Rect2(709, 624, 134, 80)
	var usable: bool = m.phase == "combat" and not bool(m.players[s.seat]["used"])
	var active := mode == "ability"
	_card(r, ICE if active or usable else Color("2B3338"), AMBER if usable or active else LINE, 4)
	if usable or active:
		draw_rect(r.grow(-1), AMBER, false, 2.0)
	_icon(Vector2i(0, 0), Rect2(r.position + Vector2(11, 23), Vector2(34, 34)), Color.WHITE if usable or active else Color(1, 1, 1, 0.6))
	var ink := Color("121518") if usable or active else INK
	_t(r.position + Vector2(53, 19), "긴급 냉각", 13, ink, true)
	var sub := "전투 중 사용"
	if m.phase == "combat":
		sub = "이번 웨이브 사용함" if bool(m.players[s.seat]["used"]) else "웨이브당 1회 · Q"
	_t(r.position + Vector2(53, 42), sub, 10, Color("121518") if usable or active else SUB)


func _draw_result() -> void:
	_hazard(Rect2(-_off.x, -_off.y, get_viewport_rect().size.x, 12))
	var m := s.m
	var lost := s.state == "lost"
	if lost:
		_t(Vector2(32, 36), "연결 종료", 42, INK, true)
		_t(Vector2(262, 62), "방장과 연결이 끊겼어요 · 패배 기록이 아니에요", 15, SUB)
	elif m != null and m.cleared:
		_t(Vector2(32, 36), "6웨이브 방어 성공", 42, AMBER, true)
		_t(Vector2(452, 62), "시제품 구간을 지켜냈어요 · 다음엔 더 적은 피해로?", 15, SUB)
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
	if m == null:
		return
	var held: int = GData.LAST_WAVE if m.cleared else maxi(m.failed_wave - 1, 0)
	var stats := [["완전히 막은 웨이브", str(held)], ["무너진 웨이브", "-" if m.cleared or m.failed_wave == 0 else str(m.failed_wave)], ["버틴 시간", _clock(m.time)], ["지나온 테마", "1개"]]
	for i in 4:
		var r := Rect2(51 + (i % 2) * 155, 129 + (i / 2) * 87, 147, 79)
		_card(r, Color("2B2F33"), Color("2B2F33"))
		_t(r.position + Vector2(12, 10), stats[i][0], 12, SUB)
		_t(r.position + Vector2(12, 36), stats[i][1], 24, INK, true)
	_t(Vector2(51, 308), "지나온 테마", 12, SUB, true)
	draw_rect(Rect2(51, 337, 38, 26), GRASS)
	_t(Vector2(70, 342), "초원", 12, Color.WHITE, true, 1)
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
	_t(Vector2(63, 459), "성 피해 · 1번 입구 %d / 2번 입구 %d" % [int(m.gate_dmg[0]), int(m.gate_dmg[1])], 12, INK)
	_t(Vector2(410, 126), "마지막 경기장 · 초원 %d/%d" % [m.wave, GData.LAST_WAVE], 12, INK, true)
	if not m.cleared and not lost:
		_t(Vector2(892, 126), "빨간 칸 = 뚫린 길", 11, AMBER, true, 2)
	_draw_mini(Rect2(410, 151, 486, 317), m)
	_t(Vector2(947, 130), "각자 한 일", 18, INK, true)
	for i in m.players.size():
		var p: Dictionary = m.players[i]
		var y := 168.0 + i * 152.0
		_card(Rect2(947, y, 284, 142), Color("2B2F33"), Color("2B2F33"))
		_tag(Vector2(970, y + 22), int(p.get("col", i)) % 4, 18.0)
		_t(Vector2(989, y + 12), str(p["name"]), 14, INK, true)
		var cells := [["피해량", "%d" % int(p["dmg"])], ["처치", "%d" % int(p["kills"])], ["감속 기여", "%.0f" % float(p["slow"])], ["지원 능력", "%d회" % int(p["support"])]]
		for k in 4:
			var at := Vector2(959 + (k % 2) * 135, y + 40 + (k / 2) * 48)
			_t(at, cells[k][0], 11, SUB)
			_t(at + Vector2(0, 17), cells[k][1], 15, INK, true)
	_t(Vector2(947, 490), "항목별로 따로 보여 주고 종합 순위는 매기지 않아요.", 11, SUB)


func _worst_gate(m: GMatch) -> int:
	return 0 if int(m.gate_dmg[0]) >= int(m.gate_dmg[1]) else 1


func _clock(sec: float) -> String:
	var t := int(sec)
	return "%d분 %d초" % [t / 60, t % 60] if t >= 60 else "%d초" % t
