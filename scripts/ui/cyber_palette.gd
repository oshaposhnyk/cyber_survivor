class_name CyberPalette
extends RefCounted

# Shared colours and icon paths for code-drawn UI. Keep in sync with assets/ui/cyber_theme.tres.

const YELLOW := Color(0.988, 0.933, 0.039)
const RED := Color(1.0, 0.0, 0.235)
const CYAN := Color(0.0, 0.941, 1.0)
const GREEN := Color(0.2, 1.0, 0.55)
const ORANGE := Color(1.0, 0.55, 0.15)
const TEXT := Color(0.91, 0.91, 0.94)
const DIM := Color(0.55, 0.56, 0.66)
const LOCKED := Color(0.32, 0.33, 0.4)
const BG := Color(0.03, 0.03, 0.055)

const ICON_DIR := "res://assets/sprites/ui/gi/"

static func branch_color(branch: int) -> Color:
	match branch:
		SkillData.Branch.OFFENSE:
			return RED
		SkillData.Branch.DEFENSE:
			return CYAN
		SkillData.Branch.HACK:
			return GREEN
		SkillData.Branch.ENGINEER:
			return ORANGE
	return YELLOW

static func icon(icon_name: String) -> Texture2D:
	var p = ICON_DIR + icon_name + ".png"
	return load(p) if ResourceLoader.exists(p) else null

# Strips emoji and other symbols the UI fonts cannot render (codepoints above the BMP, variation selectors).
static func strip_emoji(s: String) -> String:
	var out := ""
	for i in s.length():
		var c := s.unicode_at(i)
		if c > 0xFFFF or (c >= 0x2600 and c <= 0x27BF) or c == 0xFE0F or c == 0x200D:
			continue
		out += String.chr(c)
	return out.strip_edges()
