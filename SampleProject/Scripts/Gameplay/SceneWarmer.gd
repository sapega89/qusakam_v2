extends "res://addons/MetroidvaniaSystem/Template/Scripts/MetSysModule.gd"

## performance_plan, slice 5: сцени, які гра вперше вантажить посеред бою чи розмови, вантажаться у фоні одразу
## після старту гри й тримаються до її кінця (RoomPreloader.pin). Гра не чекає: перша поява ворога, магазин, каст
## навички чи екран смерті беруть готове з кешу, а не компілюють скрипти посеред кадру.
## Шкала здоровʼя ворога вже не окрема сцена (D539) — її тут немає.

const RoomPreloader := preload("res://SampleProject/Scripts/Gameplay/RoomPreloader.gd")
const Merchant := preload("res://SampleProject/Scripts/Gameplay/NPCs/Merchant.gd")
const OathSkillFX := preload("res://SampleProject/Scripts/FX/OathSkillFX.gd")

var _preloader: RoomPreloader
var _started: bool = false


func _init(p_game: MetSysGame, preloader: RoomPreloader) -> void:
	_preloader = preloader
	super(p_game)


func _initialize() -> void:
	game.room_loaded.connect(_on_room_loaded)
	EventBus.skill_unlocked.connect(_warm_skill)


## Усі шляхи, які гріються зараз (для тесту й заміру).
func paths() -> Array[String]:
	var out: Array[String] = []
	for enemy_type: String in EnemySpawnPoint.ENEMY_SCENES:
		out.append(EnemySpawnPoint.ENEMY_SCENES[enemy_type])
		out.append(EnemySpawnPoint.STATS_PATH % enemy_type)
	out.append(Merchant.SHOP_SCENE)
	out.append(GameOverScreen.SCENE_PATH)
	out.append(GameMenuState.GAME_MENU_SCENE_PATH)  # перше відкриття меню і кнопки нових очок на HUD (hud_new_points)
	for skill_id: String in ServiceLocator.get_skill_manager().get_unlocked_skills():
		out.append_array(_skill_paths(skill_id))
	return out


## Перша кімната вже на екрані — далі все у фоні.
func _on_room_loaded() -> void:
	if _started:
		return
	_started = true
	for path: String in paths():
		_preloader.pin(path)


func _warm_skill(skill_id: String) -> void:
	for path: String in _skill_paths(skill_id):
		_preloader.pin(path)


## Ефект касту активної навички (PlayerCombat.begin_cast) і, для навичок клятв, кадри OathSkillFX.
func _skill_paths(skill_id: String) -> Array[String]:
	var out: Array[String] = []
	var definition: SkillDefinition = SkillDatabase.get_skill(skill_id)
	if definition.vfx.is_empty():
		return out  # пасивна навичка — ефекту касту немає (D271)
	out.append(definition.vfx)
	if OathSkillFX.RELEASE_PIN.has(skill_id):
		for i: int in OathSkillFX.CHARGE_FRAMES:
			out.append(OathSkillFX.FRAMES_DIR % [skill_id, "charge", i + 1])
		for i: int in OathSkillFX.RELEASE_FRAMES:
			out.append(OathSkillFX.FRAMES_DIR % [skill_id, "release", i + 1])
	return out
