extends Node

## Loads project fonts from res://assets/fonts/.
## All accessors return null gracefully when TTF files are absent.

var bangers: FontFile = null
var barlow_bold_italic: FontFile = null
var barlow_bold: FontFile = null
var chakra_semibold: FontFile = null
var chakra_bold: FontFile = null

func _ready() -> void:
	bangers            = _try("res://assets/fonts/Bangers-Regular.ttf")
	barlow_bold_italic = _try("res://assets/fonts/BarlowCondensed-BoldItalic.ttf")
	barlow_bold        = _try("res://assets/fonts/BarlowCondensed-Bold.ttf")
	chakra_semibold    = _try("res://assets/fonts/ChakraPetch-SemiBold.ttf")
	chakra_bold        = _try("res://assets/fonts/ChakraPetch-Bold.ttf")

func _try(path: String) -> FontFile:
	# ResourceLoader only sees imported files; fall back to dynamic load for
	# TTFs added to the filesystem without going through the editor importer.
	if ResourceLoader.exists(path):
		return load(path) as FontFile
	if FileAccess.file_exists(path):
		var font := FontFile.new()
		var err := font.load_dynamic_font(path)
		if err == OK:
			return font
	return null

## Combat/display font matching the Flutter Bangers style (Bangers → Barlow Condensed Bold Italic → null).
func combat() -> FontFile:
	return bangers if bangers else barlow_bold_italic

## Best available heading font (Barlow Condensed Bold Italic → Chakra Bold → null).
func heading() -> FontFile:
	return barlow_bold_italic if barlow_bold_italic else chakra_bold

## Best available UI/body font (Chakra Petch SemiBold → Barlow Bold → null).
func body() -> FontFile:
	return chakra_semibold if chakra_semibold else barlow_bold
