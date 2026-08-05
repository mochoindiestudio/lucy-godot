class_name InteractPanel
extends Control

## Generic "press E to do a thing" prompt. Reused for any Interactable --
## the panel only knows how to display a key + a line of text, it has no
## opinion on what triggered it. HUD owns show/hide timing.

@onready var _key_label: Label = %KeyLabel
@onready var _prompt_label: Label = %PromptLabel
@onready var _sparkles: GPUParticles2D = %Sparkles

func show_prompt(text: String, key: String = "E") -> void:
	_prompt_label.text = text
	_key_label.text = key
	visible = true
	_sparkles.emitting = true

func hide_prompt() -> void:
	visible = false
	_sparkles.emitting = false
