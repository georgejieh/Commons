class_name ControlsScreen
extends Control
## The Controls page at the title (ADR 0035), opened from the settings sheet: the page's
## header over the ControlsPage. Back and Escape go back to Settings.

var _page: ControlsPage = null


func open(app: DemoApp) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var column: VBoxContainer = ScreenKit.page(self)
	column.add_child(ScreenKit.header(tr("controls.eyebrow"), tr("controls.title")))
	_page = ControlsPage.new()
	# As wide as its sheet, so the scroll's bar stands beside the keys, not at the far
	# side of the page.
	_page.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_page.leave.connect(func() -> void: app.back())
	column.add_child(_page)
	ScreenKit.reveal(column)
	_page.focus_first()


## The page, for tests.
func page() -> ControlsPage:
	return _page
