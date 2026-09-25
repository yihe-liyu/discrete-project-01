extends GutTest
## 玩家数据菜单：符卡记录收集。
## 回归：`_collect_cards()` 曾读 `record.name` —— **`SpellRecord` 根本没这个字段**，
## 打开菜单即崩（Invalid access to property or key 'name'）。名字按设计要**现从花名册取**。

const MENU := preload("res://scenes/ui/player_data_menu.tscn")


func test_collect_cards_resolves_name_from_catalog():
	var backup: Array = SaveData.spell_book.records.duplicate()
	var rec := SpellRecord.new()
	rec.uid = 1
	rec.phase_type = SpellRecord.PhaseType.SPELL
	rec.stage = 1
	rec.phase_index = 1
	rec.difficulty = 1
	rec.boss_index = 0
	SaveData.spell_book.records = [rec]

	var menu = MENU.instantiate()
	add_child_autofree(menu)          # _ready() 里就会走 _collect_cards()
	await get_tree().process_frame

	assert_eq(menu._cards.size(), 1, "应收集到 1 张卡")
	if menu._cards.size() > 0:
		assert_ne(menu._cards[0]["name"], "", "名字应现从花名册取到（记录里没有 name）")
		assert_eq(menu._cards[0]["uid"], 1, "uid 随卡片带出")

	SaveData.spell_book.records = backup
