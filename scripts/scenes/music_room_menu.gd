# MusicRoomMenu.gd — 音乐室（左右分栏：列表 + 评语）
extends NavPage

const MUSIC_REGISTRY_PATH := "res://data/registry/music_registry.tres"
const GOLD_COLOR := Color(1.0, 0.85, 0.2)
const LOCKED_TEXT := "？？？？？？？？？"

var _music_registry: MusicRegistry
var _music_records: Array[MusicRecord]

# 标题贴图
@onready var _title_texture: TextureRect = $"TitleTexture"

# 右栏 UI
@onready var _comment_text: Label = $"RightPanel/CommentText"

# 试听播放器
var _preview_player: AudioStreamPlayer
var _playing_id: int = -1

# 左栏每项的控件引用
var _list_labels: Array[Label] = []


func _ready() -> void:
	super._ready()  # BasePage._create_overlay() 需要先执行
	# 进入音乐室时停掉外部 BGM
	AudioManager.stop_bgm()
	
	# 加载音乐注册表
	if ResourceLoader.exists(MUSIC_REGISTRY_PATH):
		_music_registry = ResourceLoader.load(MUSIC_REGISTRY_PATH)
	else:
		_music_registry = MusicRegistry.new()
		ResourceSaver.save(_music_registry, MUSIC_REGISTRY_PATH)
	
	_music_records = _music_registry.records
	
	# 创建预览播放器
	_preview_player = AudioStreamPlayer.new()
	_preview_player.bus = _find_bus("BGM")
	add_child(_preview_player)
	_preview_player.finished.connect(_on_preview_finished)
	
	# 标题初始透明
	_title_texture.modulate.a = 0.0
	
	# 重建左栏列表（不设最终颜色，留待 on_enter 的入场动画）
	_rebuild_list()


## 入场动画：遮罩 + 标题 + 列表依次淡入
func on_enter() -> void:
	# 列表项初始隐藏
	for item in _nav_items:
		item.modulate.a = 0.0
		if item is Control:
			item.scale = Vector2(0.95, 0.95)
	
	# 遮罩淡入
	_fade_overlay_in(0.5)
	
	# 标题淡入
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_title_texture, "modulate:a", 1.0, 0.5)
	
	# 列表交错入场
	_play_entrance()


func _rebuild_list() -> void:
	var list_container: VBoxContainer = $"LeftPanel/ListContainer"
	# 清空旧项
	for child in list_container.get_children():
		child.queue_free()
	_list_labels.clear()
	_nav_items.clear()
	
	for i in _music_records.size():
		var record := _music_records[i]
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 32)
		label.name = "Track_%d" % record.music_id
		
		# 设定文字内容
		if not record.unlocked:
			label.set_meta("locked", true)
			label.text = "NO.%02d  %s" % [record.music_id, LOCKED_TEXT]
		else:
			label.text = "NO.%02d  %s" % [record.music_id, record.title]
		
		# 初始透明（on_enter 时渐显）
		label.modulate.a = 0.0
		
		list_container.add_child(label)
		_list_labels.append(label)
		_nav_items.append(label)
	
	if not _nav_items.is_empty():
		_nav_index = _find_first_unlocked()
		if _nav_index < 0:
			_nav_index = 0
	
	_update_display(_nav_index)


func _on_item_selected(index: int) -> void:
	if index < 0 or index >= _music_records.size():
		return
	
	var record := _music_records[index]
	if not record.unlocked:
		return
	
	if _playing_id == record.music_id:
		# 正在播放 → 停止
		_stop_preview()
	else:
		# 播放选中曲
		_play_preview(record)


func _on_cancel() -> void:
	_stop_preview()
	# 退出音乐室，恢复主菜单 BGM
	AudioManager.play_bgm(AssetRegistry.get_bgm("menu"))
	go_back()


# ═══ 试听控制 ═══

func _play_preview(record: MusicRecord) -> void:
	_stop_preview()
	
	# 确保外部 BGM 也停掉
	AudioManager.stop_bgm()
	
	var stream: AudioStream = AssetRegistry.get_bgm(record.bgm_key)
	if not stream:
		return
	
	_preview_player.stream = stream
	_preview_player.play()
	_playing_id = record.music_id
	
	# 解锁（在音乐室试听也算听过）
	if not record.unlocked:
		record.unlocked = true
		ResourceSaver.save(_music_registry, MUSIC_REGISTRY_PATH)
		_rebuild_list()
		# 保持选中项
		if _nav_index >= 0 and _nav_index < _nav_items.size():
			_select(_nav_index)
	
	_update_list_colors()
	_update_display(_nav_index)


func _stop_preview() -> void:
	_preview_player.stop()
	_preview_player.stream = null
	_playing_id = -1
	_update_list_colors()
	_update_display(_nav_index)


func _on_preview_finished() -> void:
	_playing_id = -1
	_update_list_colors()
	_update_display(_nav_index)


# ═══ 显示更新 ═══

func _update_display(_index: int) -> void:
	# 确保 CJK 文本正确换行（WORD_SMART = 按字符边界断行）
	_comment_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# 确保 Label 填满父容器宽度
	_comment_text.size_flags_horizontal = Control.SIZE_FILL
	
	if _playing_id < 0:
		_comment_text.text = ""
		return
	
	var record := _music_registry.get_by_id(_playing_id)
	if record and record.unlocked:
		_comment_text.text = record.comment
		_comment_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	else:
		_comment_text.text = ""


func _update_list_colors() -> void:
	for i in _music_records.size():
		var record := _music_records[i]
		var label := _list_labels[i]
		if not record.unlocked:
			label.modulate = locked_color
			label.text = "NO.%02d  %s" % [record.music_id, LOCKED_TEXT]
		else:
			if _playing_id == record.music_id:
				label.text = "NO.%02d  %s  ♪" % [record.music_id, record.title]
			else:
				label.text = "NO.%02d  %s" % [record.music_id, record.title]
			
			if _playing_id == record.music_id:
				label.modulate = GOLD_COLOR
			elif i == _nav_index:
				label.modulate = highlight_color
			else:
				label.modulate = normal_color


# 覆写导航选择更新
func _select(index: int) -> void:
	if index < 0 or index >= _nav_items.size():
		return
	
	# 旧项停止脉冲
	var prev := _nav_index
	if prev >= 0 and prev < _nav_items.size():
		_stop_pulse()
	
	# 新项
	_nav_index = index
	_start_pulse(_nav_items[index])
	
	# 颜色全部交给 _update_list_colors 统一处理
	_update_list_colors()
	_update_display(index)


# ═══ 输入处理（仅上下导航，R4：事件驱动） ═══

func _nav_directional(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up"):
		_nav_move(-1)
	elif event.is_action_pressed("ui_down"):
		_nav_move(1)


# ═══ 工具 ═══

func _find_bus(bus_name: String) -> StringName:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		return StringName(bus_name)
	return &"Master"


func _exit_tree() -> void:
	_stop_preview()
	if _preview_player and is_instance_valid(_preview_player):
		_preview_player.queue_free()
