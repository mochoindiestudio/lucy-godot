class_name InteractPanel
extends Control

## Generic "press E to do a thing" prompt. Reused for any Interactable --
## the panel only knows how to display a key + a line of text, it has no
## opinion on what triggered it. HUD owns show/hide timing.

@onready var _key_label: Label = %KeyLabel
@onready var _prompt_label: Label = %PromptLabel

func show_prompt(text: String, key: String = "E") -> void:
	_prompt_label.text = text
	_key_label.text = key
	visible = true

func hide_prompt() -> void:
	visible = false
