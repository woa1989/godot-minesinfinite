@tool
extends EditorPlugin

const CREATE_ICON_FILENAME := "user://CreateIcon.gd"
const IconCreatorScene := preload("res://addons/godot_icon/IconCreator.tscn")
const IconReplacerScene := preload("res://addons/godot_icon/IconReplacer.tscn")

var icon_creator: ConfirmationDialog
var icon_replacer: ConfirmationDialog


func _enter_tree() -> void:
	add_tool_menu_item("Icon Creator", show_icon_creator)
	add_tool_menu_item("Icon Replacer", show_icon_replacer)


func _exit_tree() -> void:
	remove_tool_menu_item("Icon Creator")
	remove_tool_menu_item("Icon Replacer")
	if icon_creator:
		icon_creator.queue_free()
	if icon_replacer:
		icon_replacer.queue_free()


func show_icon_creator() -> void:
	if not icon_creator:
		icon_creator = IconCreatorScene.instantiate()
		get_editor_interface().get_editor_main_screen().add_child(icon_creator)
	icon_creator.popup_centered()


func show_icon_replacer() -> void:
	if not icon_replacer:
		icon_replacer = IconReplacerScene.instantiate()
		get_editor_interface().get_editor_main_screen().add_child(icon_replacer)
	icon_replacer.popup_centered()
