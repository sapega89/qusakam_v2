extends Node

## Автозавантаження AppConfig. Від аддона Maaacks беремо лише перепризначення клавіш (D48):
## відновлюємо збережені біндинги з player_config.cfg.
##
## Штатний app_config.gd аддона ще й ставив вікну розмір, повноекранність і гучність зі свого
## конфіга та записував кожну зміну розміру вікна. Це друга система дисплея поруч із нашою
## (SettingsModule → DisplayManager / AudioManager), і вбудованому у редактор вікну вона
## нав'язувала 1920×1080: курсор миші влучав у рядок вище, ніж показував (Sapega, 2026-10-16).

func _ready() -> void:
	AppSettings.set_default_inputs()
	AppSettings.set_inputs_from_config()
