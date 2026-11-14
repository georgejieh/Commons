class_name TipHost
extends PanelContainer
## A panel whose tooltip is a wrapped slip: a title, rules text with its keywords
## marked, and what each keyword means. An empty rule shows no tooltip.

var _title: String = ""
var _rule: String = ""


func set_tip(title: String, rule: String) -> void:
	_title = title
	_rule = rule
	# The engine only asks for a tooltip when there is tooltip text.
	tooltip_text = "" if rule.is_empty() else "%s\n%s" % [title, rule]


## The rule the tooltip shows, for tests.
func tip_rule() -> String:
	return _rule


func _make_custom_tooltip(_for_text: String) -> Object:
	return Keywords.slip(_rule, _title)
