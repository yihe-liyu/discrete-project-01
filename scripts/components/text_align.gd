class_name TextAlign
## 全角对齐工具：字母数字/标点转全角（等宽 1em）+ 全角空格补位（右对齐）
## 供菜单/UI 显示对齐用（不硬调 Label 宽度）

## 半角字母数字转全角（０-９／Ａ-Ｚ／ａ-ｚ）+ 句点／斜杠全角
static func full(text: String) -> String:
	var out := ""
	for i in text.length():
		var code := text[i].unicode_at(0)
		if code >= 48 and code <= 57:
			out += char(code - 48 + 0xFF10)      # 0-9 → ０-９
		elif code >= 65 and code <= 90:
			out += char(code - 65 + 0xFF21)      # A-Z → Ａ-Ｚ
		elif code >= 97 and code <= 122:
			out += char(code - 97 + 0xFF41)      # a-z → ａ-ｚ
		elif code == 46:
			out += "．"                          # . → ．(U+FF0E)
		elif code == 47:
			out += "／"                          # / → ／(U+FF0F)
		else:
			out += text[i]
	return out


## 全角空格（U+3000）左补到 width 字符宽（不补前导零；对齐靠全角空格，不硬调 Label 宽度）
static func pad_cn(v: Variant, width: int) -> String:
	var text := str(v)
	while text.length() < width:
		text = "　" + text
	return text
