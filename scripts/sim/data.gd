class_name GData
extends RefCounted
## 첫 플레이 테스트 기준 수치. 규칙 코드는 여기 값만 읽는다.

const W := 27
const H := 18
const CASTLE := Rect2i(12, 7, 3, 3)
const MAX_PATH := 36
const LAST_WAVE := 6          # 1단계 내부 검증 구간
const THEME_LEN := 5          # 이 웨이브마다 테마 경계 (길 개조 기회 재지급)
const CASTLE_HP := 100
const START_GOLD := 220
const EDITS_PER_THEME := 2
const SELL_RATE := 0.8
const SLOW_CAP := 0.6
const MAX_ALIVE := 60
const TICK := 0.05
static var hp_mul := 3.5     # 적 체력 배율 (밸런스 조정용)

const BASE_PATHS := [
	[[0, 8], [1, 8], [2, 8], [3, 8], [4, 8], [4, 7], [4, 6], [4, 5], [5, 5], [6, 5], [7, 5], [8, 5], [8, 6], [8, 7], [8, 8], [9, 8], [10, 8], [11, 8]],
	[[26, 8], [25, 8], [24, 8], [23, 8], [22, 8], [22, 9], [22, 10], [22, 11], [21, 11], [20, 11], [19, 11], [18, 11], [18, 10], [18, 9], [18, 8], [17, 8], [16, 8], [15, 8]],
]

const PIECES := {
	"detour": {"name": "우회로", "span": 2, "depth": 2, "desc": "짧은 구간을 ㄷ자로 돌린다 (+4칸)"},
	"bend": {"name": "굽잇길", "span": 3, "depth": 1, "desc": "길을 옆으로 꺾어 붙인다 (+2칸)"},
}

const TOWERS := {
	"gun": {
		"name": "기관포탑", "cost": 60, "up": [70, 120],
		"lv": [{"dmg": 5.0, "cd": 0.4, "range": 3.0}, {"dmg": 8.0, "cd": 0.36, "range": 3.2}],
		"a": {"label": "속사", "dmg": 9.0, "cd": 0.2, "range": 3.2},
		"b": {"label": "철갑탄", "dmg": 24.0, "cd": 0.5, "range": 3.6, "pierce": 6.0},
	},
	"cannon": {
		"name": "대포탑", "cost": 90, "up": [90, 150],
		"lv": [{"dmg": 14.0, "cd": 1.5, "range": 3.4, "splash": 1.2}, {"dmg": 22.0, "cd": 1.4, "range": 3.6, "splash": 1.3}],
		"a": {"label": "폭발 범위 확대", "dmg": 28.0, "cd": 1.4, "range": 3.6, "splash": 2.1},
		"b": {"label": "좁은 범위 고피해", "dmg": 62.0, "cd": 1.5, "range": 3.8, "splash": 0.9},
	},
	"cold": {
		"name": "냉각탑", "cost": 70, "up": [60, 100],
		"lv": [{"dmg": 1.0, "cd": 1.0, "range": 2.6, "splash": 1.0, "slow": 0.3}, {"dmg": 2.0, "cd": 0.9, "range": 2.9, "splash": 1.1, "slow": 0.38}],
		"a": {"label": "강한 냉각", "dmg": 2.0, "cd": 0.8, "range": 2.9, "splash": 1.1, "slow": 0.55},
		"b": {"label": "넓은 냉기", "dmg": 3.0, "cd": 0.9, "range": 3.8, "splash": 1.9, "slow": 0.4},
	},
}

const ENEMIES := {
	"grunt": {"name": "일반병", "hp": 34.0, "armor": 0.0, "speed": 1.25, "hit": 1},
	"swarm": {"name": "떼거리", "hp": 13.0, "armor": 0.0, "speed": 1.6, "hit": 1},
	"heavy": {"name": "중장갑", "hp": 120.0, "armor": 4.0, "speed": 0.8, "hit": 3},
	"rusher": {"name": "돌격병", "hp": 42.0, "armor": 0.0, "speed": 2.4, "hit": 1},
	"boss": {"name": "초원 대장", "hp": 900.0, "armor": 3.0, "speed": 0.62, "hit": 15},
}

## 입구(e)별 묶음: [적, 수, 간격(초), 시작(초)]
const WAVES := [
	[[0, "grunt", 6, 1.1, 0.0], [1, "grunt", 6, 1.1, 0.0]],
	[[0, "grunt", 7, 0.9, 0.0], [1, "swarm", 10, 0.45, 1.0]],
	[[0, "swarm", 14, 0.4, 0.0], [1, "grunt", 9, 0.8, 0.0], [1, "swarm", 6, 0.4, 7.0]],
	[[0, "heavy", 3, 3.0, 0.0], [1, "heavy", 3, 3.0, 1.0], [0, "grunt", 6, 0.9, 4.0], [1, "grunt", 6, 0.9, 4.0]],
	[[0, "boss", 1, 0.0, 3.0], [1, "grunt", 10, 0.8, 0.0], [0, "swarm", 12, 0.45, 0.0], [1, "heavy", 2, 3.5, 5.0]],
	[[0, "rusher", 9, 0.7, 0.0], [1, "rusher", 9, 0.7, 2.0], [0, "heavy", 3, 2.6, 5.0], [1, "heavy", 3, 2.6, 5.0], [1, "swarm", 14, 0.35, 8.0]],
]

const PING_KINDS := {
	"look": "주목", "danger": "위험!", "build": "건설 요청", "road": "길 변경 제안", "mine": "여긴 내가 맡을게",
}


static func wave_gold(wave: int) -> int:
	return 90 + wave * 15


## 지금 단계의 포탑 능력치
static func tower_stats(type: String, level: int, branch: String) -> Dictionary:
	var d: Dictionary = TOWERS[type]
	var s: Dictionary
	if level >= 3 and branch != "":
		s = d[branch]
	else:
		s = d["lv"][clampi(level - 1, 0, 1)]
	return {
		"dmg": float(s.get("dmg", 0.0)), "cd": float(s.get("cd", 1.0)), "range": float(s.get("range", 3.0)),
		"splash": float(s.get("splash", 0.0)), "slow": float(s.get("slow", 0.0)), "pierce": float(s.get("pierce", 0.0)),
	}
