extends BaseMenuComponent

# 📊 StatsComponent - Displays player stats and level in Octopath Traveler II style
# Shows level, experience, and character stats with ability to distribute stat points
# Game manager и item_database доступны из BaseMenuComponent

# Character selection buttons
@onready var char_button_1: Button = get_node_or_null("ScrollContainer/HBoxContainer/LeftPanel/CharacterSelection/CharacterGrid/CharacterButton1")
@onready var char_button_2: Button = get_node_or_null("ScrollContainer/HBoxContainer/LeftPanel/CharacterSelection/CharacterGrid/CharacterButton2")
@onready var char_button_3: Button = get_node_or_null("ScrollContainer/HBoxContainer/LeftPanel/CharacterSelection/CharacterGrid/CharacterButton3")
@onready var char_button_4: Button = get_node_or_null("ScrollContainer/HBoxContainer/LeftPanel/CharacterSelection/CharacterGrid/CharacterButton4")
@onready var char_button_5: Button = get_node_or_null("ScrollContainer/HBoxContainer/LeftPanel/CharacterSelection/CharacterGrid/CharacterButton5")
@onready var char_button_6: Button = get_node_or_null("ScrollContainer/HBoxContainer/LeftPanel/CharacterSelection/CharacterGrid/CharacterButton6")
@onready var char_button_7: Button = get_node_or_null("ScrollContainer/HBoxContainer/LeftPanel/CharacterSelection/CharacterGrid/CharacterButton7")
@onready var char_button_8: Button = get_node_or_null("ScrollContainer/HBoxContainer/LeftPanel/CharacterSelection/CharacterGrid/CharacterButton8")

# Character avatars
@onready var avatar_1: ColorRect = get_node_or_null("ScrollContainer/HBoxContainer/LeftPanel/CharacterSelection/CharacterGrid/CharacterButton1/AvatarRect")
@onready var avatar_2: ColorRect = get_node_or_null("ScrollContainer/HBoxContainer/LeftPanel/CharacterSelection/CharacterGrid/CharacterButton2/AvatarRect")
@onready var avatar_3: ColorRect = get_node_or_null("ScrollContainer/HBoxContainer/LeftPanel/CharacterSelection/CharacterGrid/CharacterButton3/AvatarRect")
@onready var avatar_4: ColorRect = get_node_or_null("ScrollContainer/HBoxContainer/LeftPanel/CharacterSelection/CharacterGrid/CharacterButton4/AvatarRect")
@onready var avatar_5: ColorRect = get_node_or_null("ScrollContainer/HBoxContainer/LeftPanel/CharacterSelection/CharacterGrid/CharacterButton5/AvatarRect")
@onready var avatar_6: ColorRect = get_node_or_null("ScrollContainer/HBoxContainer/LeftPanel/CharacterSelection/CharacterGrid/CharacterButton6/AvatarRect")
@onready var avatar_7: ColorRect = get_node_or_null("ScrollContainer/HBoxContainer/LeftPanel/CharacterSelection/CharacterGrid/CharacterButton7/AvatarRect")
@onready var avatar_8: ColorRect = get_node_or_null("ScrollContainer/HBoxContainer/LeftPanel/CharacterSelection/CharacterGrid/CharacterButton8/AvatarRect")

# Character info (left panel)
@onready var character_name_label: Label = get_node_or_null("ScrollContainer/HBoxContainer/LeftPanel/CharacterInfo/CharacterNameLabel")
@onready var class_name_label: Label = get_node_or_null("ScrollContainer/HBoxContainer/LeftPanel/CharacterInfo/ClassNameLabel")
@onready var class_desc_label: Label = get_node_or_null("ScrollContainer/HBoxContainer/LeftPanel/CharacterInfo/ClassDescLabel")
@onready var level_label: Label = get_node_or_null("ScrollContainer/HBoxContainer/LeftPanel/CharacterInfo/LevelInfo/LevelLabel")
@onready var exp_label: Label = get_node_or_null("ScrollContainer/HBoxContainer/LeftPanel/CharacterInfo/LevelInfo/ExpLabel")
@onready var exp_bar: ProgressBar = get_node_or_null("ScrollContainer/HBoxContainer/LeftPanel/CharacterInfo/LevelInfo/ExpBar")
@onready var stat_points_label: Label = get_node_or_null("ScrollContainer/HBoxContainer/LeftPanel/CharacterInfo/StatPointsLabel")

# Base stats (left panel)
@onready var strength_value: Label = get_node_or_null("ScrollContainer/HBoxContainer/LeftPanel/CharacterInfo/BaseStatsContainer/StrengthContainer/StrengthValue")
@onready var strength_button: Button = get_node_or_null("ScrollContainer/HBoxContainer/LeftPanel/CharacterInfo/BaseStatsContainer/StrengthContainer/StrengthButton")
@onready var intelligence_value: Label = get_node_or_null("ScrollContainer/HBoxContainer/LeftPanel/CharacterInfo/BaseStatsContainer/IntelligenceContainer/IntelligenceValue")
@onready var intelligence_button: Button = get_node_or_null("ScrollContainer/HBoxContainer/LeftPanel/CharacterInfo/BaseStatsContainer/IntelligenceContainer/IntelligenceButton")
@onready var dexterity_value: Label = get_node_or_null("ScrollContainer/HBoxContainer/LeftPanel/CharacterInfo/BaseStatsContainer/DexterityContainer/DexterityValue")
@onready var dexterity_button: Button = get_node_or_null("ScrollContainer/HBoxContainer/LeftPanel/CharacterInfo/BaseStatsContainer/DexterityContainer/DexterityButton")
@onready var constitution_value: Label = get_node_or_null("ScrollContainer/HBoxContainer/LeftPanel/CharacterInfo/BaseStatsContainer/ConstitutionContainer/ConstitutionValue")
@onready var constitution_button: Button = get_node_or_null("ScrollContainer/HBoxContainer/LeftPanel/CharacterInfo/BaseStatsContainer/ConstitutionContainer/ConstitutionButton")

# Character sprite (center panel)
@onready var character_sprite: ColorRect = get_node_or_null("ScrollContainer/HBoxContainer/CenterPanel/CharacterSpriteContainer/CharacterSprite")

# Attributes (center panel)
@onready var max_hp_value: Label = get_node_or_null("ScrollContainer/HBoxContainer/CenterPanel/AttributesContainer/MaxHPContainer/MaxHPValue")
@onready var phys_atk_value: Label = get_node_or_null("ScrollContainer/HBoxContainer/CenterPanel/AttributesContainer/PhysAtkContainer/PhysAtkValue")
@onready var phys_def_value: Label = get_node_or_null("ScrollContainer/HBoxContainer/CenterPanel/AttributesContainer/PhysDefContainer/PhysDefValue")
@onready var speed_value: Label = get_node_or_null("ScrollContainer/HBoxContainer/CenterPanel/AttributesContainer/SpeedContainer/SpeedValue")
@onready var dodge_value: Label = get_node_or_null("ScrollContainer/HBoxContainer/CenterPanel/AttributesContainer/DodgeContainer/DodgeValue")
@onready var magic_atk_value: Label = get_node_or_null("ScrollContainer/HBoxContainer/CenterPanel/AttributesContainer/MagicAtkContainer/MagicAtkValue")

# Skills (right panel) - СКРЫТЫ, так как функционал еще не реализован
@onready var skills_header: Label = get_node_or_null("ScrollContainer/HBoxContainer/RightPanel/SkillsHeader")
@onready var skills_container: VBoxContainer = get_node_or_null("ScrollContainer/HBoxContainer/RightPanel/SkillsContainer")
@onready var job_skills_list: VBoxContainer = get_node_or_null("ScrollContainer/HBoxContainer/RightPanel/SkillsContainer/JobSkillsList")
@onready var support_skills_list: VBoxContainer = get_node_or_null("ScrollContainer/HBoxContainer/RightPanel/SkillsContainer/SupportSkillsList")

func _initialize_component():
	"""Инициализация компонента статистики (вызывается из BaseMenuComponent._ready)"""
	# BaseMenuComponent уже получил game_manager
	
	# Initialize characters if not already initialized
	if game_manager and game_manager.characters.is_empty():
		game_manager._initialize_characters()
	
	# Connect character selection buttons
	if char_button_1:
		char_button_1.pressed.connect(func(): _on_character_selected("player_1"))
	if char_button_2:
		char_button_2.pressed.connect(func(): _on_character_selected("player_2"))
	if char_button_3:
		char_button_3.pressed.connect(func(): _on_character_selected("player_3"))
	if char_button_4:
		char_button_4.pressed.connect(func(): _on_character_selected("player_4"))
	if char_button_5:
		char_button_5.pressed.connect(func(): _on_character_selected("player_5"))
	if char_button_6:
		char_button_6.pressed.connect(func(): _on_character_selected("player_6"))
	if char_button_7:
		char_button_7.pressed.connect(func(): _on_character_selected("player_7"))
	if char_button_8:
		char_button_8.pressed.connect(func(): _on_character_selected("player_8"))
	
	# Connect stat buttons
	if strength_button:
		strength_button.pressed.connect(func(): _add_stat_point("strength"))
	if intelligence_button:
		intelligence_button.pressed.connect(func(): _add_stat_point("intelligence"))
	if dexterity_button:
		dexterity_button.pressed.connect(func(): _add_stat_point("dexterity"))
	if constitution_button:
		constitution_button.pressed.connect(func(): _add_stat_point("constitution"))
	
	# Connect to signals
	if game_manager and game_manager.has_signal("level_up"):
		game_manager.level_up.connect(_on_level_up)
	if game_manager and game_manager.has_signal("character_changed"):
		game_manager.character_changed.connect(_on_character_changed)
	
	# Скрываем панель скиллов, так как функционал еще не реализован
	if skills_header:
		skills_header.visible = false
	if skills_container:
		skills_container.visible = false
	
	# Initial update
	_update_character_selection()
	update_display()

func _notification(what):
	"""Updates display when component becomes visible"""
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		update_display()

func _update_character_selection():
	"""Updates character selection UI"""
	if not game_manager:
		return
	
	var all_chars = game_manager.get_all_characters()
	var active_id = game_manager.active_character_id
	
	# Update all characters
	for i in range(1, 9):
		var char_id = "player_%d" % i
		if not all_chars.has(char_id):
			continue
		
		var character_data = all_chars[char_id]
		var avatar = null
		var button = null
		
		match i:
			1:
				avatar = avatar_1
				button = char_button_1
			2:
				avatar = avatar_2
				button = char_button_2
			3:
				avatar = avatar_3
				button = char_button_3
			4:
				avatar = avatar_4
				button = char_button_4
			5:
				avatar = avatar_5
				button = char_button_5
			6:
				avatar = avatar_6
				button = char_button_6
			7:
				avatar = avatar_7
				button = char_button_7
			8:
				avatar = avatar_8
				button = char_button_8
		
		if avatar:
			avatar.color = character_data.avatar_color
		if button:
			# Безопасное установление цвета с явным типом
			if active_id == char_id:
				button.modulate = Color(1.0, 1.0, 1.0, 1.0)
			else:
				button.modulate = Color(0.7, 0.7, 0.7, 1.0)
	
	# Update class info and character sprite
	_update_class_info()
	_update_character_sprite()

func _update_class_info():
	"""Updates class name and description"""
	if not game_manager:
		return
	
	var state = game_manager.player_state
	var active_char = game_manager.get_active_character()
	var class_data = game_manager.get_class_data(state.class_id, state.subclass_id)
	
	if character_name_label and active_char:
		character_name_label.text = active_char.name
	
	if class_name_label:
		var class_name_str = class_data.get("name", "Unknown")
		var subclass_name = ""
		if class_data.has("subclass"):
			subclass_name = class_data.subclass.get("name", "")
		if subclass_name != "":
			class_name_label.text = "%s - %s" % [class_name_str, subclass_name]
		else:
			class_name_label.text = class_name_str
	
	if class_desc_label:
		if class_data.has("subclass"):
			class_desc_label.text = class_data.subclass.get("description", "")
		else:
			class_desc_label.text = class_data.get("description", "")

func _update_character_sprite():
	"""Updates character sprite color based on active character"""
	if not game_manager or not character_sprite:
		return
	
	var active_char = game_manager.get_active_character()
	if active_char:
		character_sprite.color = active_char.avatar_color

func _on_character_selected(character_id: String):
	"""Handles character selection"""
	if game_manager.switch_character(character_id):
		_update_character_selection()
		update_display()

func _on_character_changed(_character_id: String):
	"""Handles character change signal"""
	_update_character_selection()
	update_display()

func update_display():
	"""Updates all stat displays"""
	if not game_manager:
		return
	
	var state = game_manager.player_state
	
	# Update level and experience
	if level_label:
		level_label.text = "Level: %d" % state.level
	
	if exp_label:
		exp_label.text = "Experience: %d / %d" % [state.experience, state.experience_to_next_level]
	
	if exp_bar:
		exp_bar.max_value = state.experience_to_next_level
		exp_bar.value = state.experience
		exp_bar.show_percentage = false
	
	# Update stat points
	if stat_points_label:
		if state.stat_points > 0:
			stat_points_label.text = "Stat Points: %d" % state.stat_points
		else:
			stat_points_label.text = "Stat Points: 0"
	
	# Update stats
	_update_stat_display("strength", strength_value, strength_button, state.strength)
	_update_stat_display("intelligence", intelligence_value, intelligence_button, state.intelligence)
	_update_stat_display("dexterity", dexterity_value, dexterity_button, state.dexterity)
	_update_stat_display("constitution", constitution_value, constitution_button, state.constitution)
	
	# Update calculated attributes
	_update_attributes()

func _update_stat_display(_stat_name: String, value_label: Label, button: Button, value: int):
	"""Updates display for a single stat"""
	if value_label:
		value_label.text = str(value)
	
	if button:
		# Enable/disable button based on available stat points
		button.disabled = (game_manager.player_state.stat_points <= 0)
		# Безопасное установление текста с явным типом
		if game_manager.player_state.stat_points > 0:
			button.text = "+"
		else:
			button.text = ""

func _add_stat_point(stat_name: String):
	"""Adds a stat point to specified stat"""
	if not game_manager:
		return
	
	if game_manager.add_stat_point(stat_name):
		# Update display after adding point
		update_display()
		
		# If constitution was increased, update player health
		if stat_name == "constitution":
			var player = game_manager.get_current_player()
			if player:
				player.apply_stats_from_game_manager()

func _update_attributes():
	"""Updates calculated attribute values"""
	if not game_manager:
		return
	
	# Max HP (from constitution)
	if max_hp_value:
		var max_hp = game_manager.calculate_max_health()
		max_hp_value.text = str(max_hp)
	
	# Physical Attack (from strength)
	if phys_atk_value:
		var phys_atk = game_manager.calculate_physical_damage()
		phys_atk_value.text = str(phys_atk)
	
	# Physical Defense (base value, can be expanded later)
	if phys_def_value:
		phys_def_value.text = "0"  # Placeholder for now
	
	# Attack Speed (from dexterity)
	if speed_value:
		var speed_mult = game_manager.calculate_attack_speed()
		speed_value.text = "%.2fx" % speed_mult
	
	# Dodge Chance (from dexterity)
	if dodge_value:
		var dodge_chance = game_manager.calculate_dodge_chance()
		dodge_value.text = "%.1f%%" % (dodge_chance * 100.0)
	
	# Magic Attack (from intelligence)
	if magic_atk_value:
		var magic_atk = game_manager.calculate_magic_damage()
		magic_atk_value.text = str(magic_atk)

func _on_level_up(new_level: int, stat_points: int):
	"""Handles level up event"""
	print("📊 StatsComponent: Level up detected! Level: ", new_level, ", Stat points: ", stat_points)
	update_display()
