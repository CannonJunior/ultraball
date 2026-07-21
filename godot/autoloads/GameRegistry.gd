extends Node

const CLASS_IDS: Array[String] = [
	"spectre", "corsair", "geomancer", "archon",
	"warden", "trickster", "wrecker", "vitalist"
]

var _classes: Dictionary = {}         # class_id -> ClassDefinition
var _abilities: Dictionary = {}       # class_id -> Array[AbilityDefinition] (10 slots)

func _ready() -> void:
	_load_all_data()

func _load_all_data() -> void:
	for class_id in CLASS_IDS:
		var path := "res://data/classes/%s.tres" % class_id
		if not ResourceLoader.exists(path):
			push_error("GameRegistry: missing class resource: " + path)
			continue
		var def: ClassDefinition = load(path)
		_classes[class_id] = def
		_abilities[class_id] = _load_abilities_for_class(class_id)

func _load_abilities_for_class(class_id: String) -> Array:
	var slots: Array = []
	slots.resize(10)
	var dir_path := "res://data/abilities/%s/" % class_id
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("GameRegistry: cannot open ability dir: " + dir_path)
		return slots
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var ability: AbilityDefinition = load(dir_path + file_name)
			if ability and ability.slot >= 1 and ability.slot <= 10:
				slots[ability.slot - 1] = ability
		file_name = dir.get_next()
	dir.list_dir_end()
	return slots

func get_class_definition(class_id: String) -> ClassDefinition:
	if not _classes.has(class_id):
		push_error("GameRegistry: unknown class_id: " + class_id)
		return null
	return _classes[class_id]

func get_ability(class_id: String, slot: int) -> AbilityDefinition:
	if not _abilities.has(class_id):
		push_error("GameRegistry: no abilities for class: " + class_id)
		return null
	var abilities: Array = _abilities[class_id]
	var idx := slot - 1
	if idx < 0 or idx >= abilities.size():
		push_error("GameRegistry: slot %d out of range for class %s" % [slot, class_id])
		return null
	return abilities[idx]

func class_id_for_roster_index(roster_index: int) -> String:
	return CLASS_IDS[roster_index % CLASS_IDS.size()]

func all_class_ids() -> Array[String]:
	return CLASS_IDS
