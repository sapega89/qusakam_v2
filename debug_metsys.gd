extends SceneTree

func _init():
	var metsys = Engine.get_singleton("MetSys")
	if not metsys:
		print("MetSys NOT found")
		quit()
		return
	
	print("MetSys Settings map_root_folder: ", metsys.settings.map_root_folder)
	print("MapData Path: ", metsys.map_data.get_map_data_path())
	print("Assigned Scenes count: ", metsys.map_data.assigned_scenes.size())
	
	if metsys.map_data.assigned_scenes.size() > 0:
		print("First 5 keys in assigned_scenes:")
		var keys = metsys.map_data.assigned_scenes.keys()
		for i in range(min(5, keys.size())):
			print("  ", keys[i])
	
	quit()
