extends RefCounted

## Сюжетні розмови (D111): ці .dqd іде не звичайним вікном, а сюжетною подачею (D110, Figma 36:65,
## Scenes/UI/story_dialogue.tscn). Головні розмови прологу: дід у його домі, писар і вартовий біля Міської брами,
## Зала мера, Малик і алхімік у Лабораторії. Барки, репліки мимохідь і облачка лишаються, як були; монолог героя
## (усі репліки його) і далі йде облачком (D178) — до вікна не доходить.
##   const StoryDialogues = preload("res://SampleProject/Scripts/Systems/story_dialogues.gd")
##   StoryDialogues.is_story("res://dialogue_quest/OldMan_Decision.dqd")  # true

const STORY: Array[String] = [
	"OldMan_Outside", "OldMan_Healing", "OldMan_Decision",
	"CityGates_Census", "CityGates_Raid",
	"City_MayorHall", "MayorHall_WallBurst", "MayorHall_Defeat",
	"Lab_Cells_Arrival", "Lab_Cells_Injection", "Lab_Cells_Prisoner", "Lab_Acquaintance",
]

const HERO := "KUSAKAM"

## Картка на весь зріст (D112): мовець DialogueQuest → [аркуш спрайта гри, клітинка кадру]. Поки немає окремого
## арту — власні кадри персонажа: герой — кадр Idle, NPC — клітинка «анфас» його аркуша (ті самі, з яких
## Scripts/Tools/build_portraits.gd вирізає голову для портрета), компаньйони — перший кадр idle.
const CAST := {
	"KUSAKAM": ["res://SampleProject/Sprites/Player/Idle/2.png", Rect2i(0, 0, 64, 64)],
	"GRANDFATHER": ["res://SampleProject/Assets/Characters/NPCs/old_man/sheet.png", Rect2i(0, 0, 64, 96)],
	"GATE_SCRIBE": ["res://SampleProject/Assets/Characters/NPCs/gate_scribe/sheet.png", Rect2i(0, 96, 64, 96)],
	"GATE_GUARD": ["res://SampleProject/Assets/Characters/NPCs/gate_guard/sheet.png", Rect2i(0, 0, 64, 96)],
	"MALIK": ["res://SampleProject/Assets/Characters/NPCs/malik/sheet.png", Rect2i(0, 192, 64, 96)],
	"SCIENTIST": ["res://SampleProject/Assets/Characters/NPCs/alchemist/sheet.png", Rect2i(0, 288, 64, 96)],
	"PRISONER": ["res://SampleProject/Assets/Characters/NPCs/prisoner/sheet.png", Rect2i(0, 384, 64, 96)],
	"SCORPICORE_WARRIOR": ["res://SampleProject/Assets/Characters/Bosses/mayor_hall_boss/sheet.png", Rect2i(0, 0, 96, 112)],
	"ALISIA": ["res://SampleProject/Assets/Characters/Companions/alisia/idle.png", Rect2i(0, 0, 64, 64)],
	"ASTRIT": ["res://SampleProject/Assets/Characters/Companions/astrit/idle.png", Rect2i(0, 0, 64, 64)],
	"URIZEN": ["res://SampleProject/Assets/Characters/Companions/urizen/idle.png", Rect2i(0, 0, 64, 64)],
}


## [param path] — шлях розмови, як його дають start_dialogue (повний res://dialogue_quest/<id>.dqd).
static func is_story(path: String) -> bool:
	return path.get_file().get_basename() in STORY


## Кадр мовця для картки; мовець сюжетної розмови без кадру — помилка даних (verify_story_dialogue перевіряє всіх).
static func card(speaker: String) -> AtlasTexture:
	assert(CAST.has(speaker), "StoryDialogues: %s has no full-body frame (CAST)" % speaker)
	var frame := AtlasTexture.new()
	frame.atlas = load(CAST[speaker][0])
	frame.region = Rect2(CAST[speaker][1])
	return frame
