extends Sprite2D

## Емоція над головою актора кат-сцени (D460): «!» подив, «?» розгубленість, «…» мовчання, крапля поту — страх, серце — ласка (D740).
## Ставить Cutscene.react(): вузол — над маківкою, значок стоїть на ньому низом; вискакує, тримається, гасне й зникає.

const ICONS := {
	&"surprise": preload("res://SampleProject/Assets/UI/Icons/emote_surprise.svg"),
	&"confusion": preload("res://SampleProject/Assets/UI/Icons/emote_confusion.svg"),
	&"silence": preload("res://SampleProject/Assets/UI/Icons/emote_silence.svg"),
	&"fear": preload("res://SampleProject/Assets/UI/Icons/emote_fear.svg"),
	&"love": preload("res://SampleProject/Assets/UI/Icons/emote_love.svg"),
}
const COLORS := {
	&"surprise": UITokens.EMOTE_SURPRISE,
	&"confusion": UITokens.EMOTE_CONFUSION,
	&"silence": UITokens.EMOTE_SILENCE,
	&"fear": UITokens.EMOTE_FEAR,
	&"love": UITokens.EMOTE_LOVE,
}

var kind: StringName


func pop(emote: StringName) -> void:
	kind = emote
	texture = ICONS[emote]
	modulate = COLORS[emote]
	offset = Vector2(0, -texture.get_height() / 2.0)
	scale = Vector2.ZERO
	var tween := create_tween()
	tween.tween_property(self, ^"scale", Vector2.ONE * UITokens.EMOTE_SCALE, UITokens.EMOTE_POP) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(UITokens.EMOTE_HOLD)
	tween.tween_property(self, ^"modulate:a", 0.0, UITokens.EMOTE_FADE)
	tween.tween_callback(queue_free)
