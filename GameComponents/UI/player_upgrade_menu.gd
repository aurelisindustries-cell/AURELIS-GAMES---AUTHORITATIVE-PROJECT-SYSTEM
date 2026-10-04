extends CanvasLayer
class_name PlayerUpgradeMenu

const META := "testing_upgrade_overrides"
const BASELINE := "testing_upgrade_baseline"
const MOVEMENT := {
	"dash": ["Ground dash", "Quick horizontal burst on the ground."],
	"slide": ["Slide", "Slide along the ground and through low passages."],
	"double_jump": ["Double jump", "Jump again while airborne."],
	"air_dash": ["Air dash", "Dash while airborne."],
	"propulsor_step": ["Propulsor step", "Earn another jump by landing an airborne dagger hit."],
	"wall_slide": ["Wall slide", "Slow your fall against a wall."],
	"wall_jump": ["Wall jump", "Push away from a wall with a jump."],
	"ledge_flow": ["Ledge grab & vault", "Catch ledges and climb over them."],
}
const CASTER := {
	"has_buster_v1": ["Buster Module V1", "Dr. Trevor Lowe. Hold the normal caster button for 0.5 seconds, then release for a charged shot."],
	"has_piercing_module": ["Piercing module", "Allow the piercing shot in its equipped module slot."],
	"has_spread_module": ["Spread module", "Allow spread shots in their equipped module slot."],
	"has_guided_module": ["Guided module", "Allow guided shots in their equipped module slot."],
	"has_charged_caster": ["Charged caster", "Allow charged shots when requested by the combat system."],
	"has_dash_shot": ["Dash-shot damage bonus", "Add bonus caster damage during a dash."],
}
const DAGGER := {
	"has_extended_edge_1": ["Extended Edge I", "Dr. Brian Conner. Increase dagger reach by 25%."],
	"has_extended_edge_2": ["Extended Edge II", "Dr. Brian Conner. Increase dagger reach to 150%. Also enables Extended Edge I."],
	"has_reinforced_edge_1": ["Reinforced Edge I", "Dr. Kevin Evered. Add 2 damage to dagger strikes."],
	"has_reinforced_edge_2": ["Reinforced Edge II", "Dr. Kevin Evered. Add 4 total damage. Also enables Reinforced Edge I."],
	"has_up_slash": ["Upward slash", "Aim the dagger upward."],
	"has_downstab": ["Downward stab", "Aim the dagger down while airborne."],
	"has_pogo": ["Downstab rebound", "Bounce upward after a successful downward stab."],
}
const EVOLVED := {
	"has_burrow": ["Burrow", "Stand on burrowable soil and press R. Move underground with left/right; R or Jump surfaces. Q/E switches abilities."],
	"has_vine_whip": ["Vine Whip", "Press R / the evolved-ability button to lash in your aim direction. Staggers enemies; blocked by terrain."],
}
var player: Node2D
var menu_root: Control
var tabs: TabContainer
var empty_label: Label
var status: Label
var toggles: Dictionary = {}
var health_count: SpinBox
var module_left: OptionButton
var module_right: OptionButton
var bulk_buttons: Array[Button] = []
var was_paused := false
var opened := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 200
	_build_ui()
	menu_root.hide()


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_F2:
		if opened: close_menu()
		else: open_menu()
		get_viewport().set_input_as_handled()
	elif opened and event.keycode == KEY_ESCAPE:
		close_menu()
		get_viewport().set_input_as_handled()


func _find_player() -> Node2D:
	for node in get_tree().get_nodes_in_group("player"):
		if not node is Node2D or not node.find_child("CharacterController", true, false) is CharacterController: continue
		var ancestor: Node = node
		var disabled := false
		while ancestor:
			if ancestor.process_mode == Node.PROCESS_MODE_DISABLED: disabled = true
			ancestor = ancestor.get_parent()
		if not disabled: return node
	return null


func open_menu() -> void:
	if opened: return
	player = _find_player()
	if is_instance_valid(player):
		_ensure_baseline(player)
		if not player.tree_exiting.is_connected(_on_player_exiting): player.tree_exiting.connect(_on_player_exiting)
	was_paused = get_tree().paused
	opened = true
	get_tree().paused = true
	menu_root.show()
	refresh()


func close_menu() -> void:
	if not opened: return
	menu_root.hide()
	opened = false
	get_tree().paused = was_paused
	if is_instance_valid(player) and player.tree_exiting.is_connected(_on_player_exiting):
		player.tree_exiting.disconnect(_on_player_exiting)


func _on_player_exiting() -> void:
	close_menu()
	player = null


func _exit_tree() -> void:
	if opened: get_tree().paused = was_paused


func _build_ui() -> void:
	menu_root = Control.new()
	add_child(menu_root)
	menu_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.04, 0.88)
	menu_root.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	menu_root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -440
	panel.offset_right = 440
	panel.offset_top = -300
	panel.offset_bottom = 300
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.065, 0.09, 0.12)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 22)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	var title := Label.new()
	title.text = "PLAYER UPGRADES"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_button(header, "Resume  /  F2", close_menu)
	_help(content, "Gameplay is paused. Changes apply now, for this play session; earned save progress stays unchanged.")
	empty_label = Label.new()
	empty_label.text = "No active player. Start a game or a playtest, then press F2."
	content.add_child(empty_label)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(tabs)
	var movement := _page("Movement")
	for id in ["dash", "slide", "double_jump", "air_dash", "propulsor_step"]:
		_toggle(movement, id, MOVEMENT[id][0], MOVEMENT[id][1])
	var walls := _page("Walls & ledges")
	for id in ["wall_slide", "wall_jump", "ledge_flow"]:
		_toggle(walls, id, MOVEMENT[id][0], MOVEMENT[id][1])
	var caster := _page("Arc Caster")
	for id in CASTER: _toggle(caster, id, CASTER[id][0], CASTER[id][1])
	_help(caster, "Equip a module in a slot to use it. Disabled modules fire a normal shot.")
	var slots := HBoxContainer.new()
	caster.add_child(slots)
	module_left = _module_option(slots, "Left slot")
	module_right = _module_option(slots, "Right slot")
	module_left.item_selected.connect(func(index: int): _set_value("left_caster_module", ["piercing", "spread", "guided"][index]))
	module_right.item_selected.connect(func(index: int): _set_value("right_caster_module", ["piercing", "spread", "guided"][index]))
	var dagger := _page("Arc Dagger")
	_toggle(dagger, "combo_1", "Second combo hit", "Unlock the second strike in the normal dagger combo.")
	_toggle(dagger, "combo_2", "Third combo hit", "Unlock the finisher. Also enables the second hit.")
	for id in DAGGER: _toggle(dagger, id, DAGGER[id][0], DAGGER[id][1])
	var evolved := _page("Evolved")
	for id in EVOLVED: _toggle(evolved, id, EVOLVED[id][0], EVOLVED[id][1])
	_help(evolved, "Vine Whip: press R (controller Y / Triangle). Aim with I/J/K/L or the right stick; otherwise it lashes forward.")
	_help(evolved, "Burrow: stand on a Burrowable Soil strip, then press R. Left/right digs; R or Jump surfaces. Q/E (controller bumpers) switches abilities. Place soil from the editor's OBJECTS tab, leaving its interior free of painted tiles.")
	var vitality := _page("Health")
	_toggle(vitality, "health", "Health upgrades", "Enable extra maximum health. Disable to return to 16.")
	_help(vitality, "Number of health upgrades (each adds 4 maximum health)")
	health_count = SpinBox.new()
	health_count.min_value = 1
	health_count.max_value = 200
	health_count.step = 1
	vitality.add_child(health_count)
	health_count.value_changed.connect(func(value: float): _set_value("health_count", int(value)))
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	content.add_child(footer)
	bulk_buttons.append(_button(footer, "Enable all", func(): set_all(true)))
	bulk_buttons.append(_button(footer, "Disable all", func(): set_all(false)))
	bulk_buttons.append(_button(footer, "Restore normal upgrades", restore_normal))
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_color_override("font_color", Color(0.4, 0.95, 0.7))
	content.add_child(status)


func _page(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(page)
	return page


func _help(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(0.7, 0.79, 0.85))
	parent.add_child(label)


func _toggle(parent: Control, id: String, title: String, description: String) -> void:
	var button := CheckButton.new()
	button.text = title
	button.tooltip_text = description
	button.custom_minimum_size.y = 40
	button.toggled.connect(set_upgrade.bind(id))
	parent.add_child(button)
	toggles[id] = button


func _button(parent: Control, title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size.y = 36
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _module_option(parent: Control, title: String) -> OptionButton:
	var label := Label.new()
	label.text = title
	parent.add_child(label)
	var option := OptionButton.new()
	for module in ["Piercing", "Spread", "Guided"]: option.add_item(module)
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(option)
	return option


func _world_for(target: Node) -> Node:
	var ancestor := target.get_parent()
	while ancestor:
		if ancestor.has_method("refresh_upgrade_overrides"): return ancestor
		ancestor = ancestor.get_parent()
	return null


func _ensure_baseline(target: Node) -> void:
	if target.has_meta(BASELINE): return
	var controller := target.find_child("CharacterController", true, false) as CharacterController
	var combat := target.find_child("PlayerCombatController", true, false) as PlayerCombatController
	var health := target.find_child("HealthComponent", true, false) as HealthComponent
	var baseline := {}
	for id in MOVEMENT: baseline[id] = controller.get("has_" + id)
	if combat:
		for id in CASTER: baseline[id] = combat.get(id)
		for id in DAGGER: baseline[id] = combat.get(id)
		for id in EVOLVED: baseline[id] = combat.get(id)
		for id in ["dagger_combo_upgrades", "left_caster_module", "right_caster_module"]: baseline[id] = combat.get(id)
	baseline.health_max = health.max_health if health else 16
	target.set_meta(BASELINE, baseline)


func refresh() -> void:
	var valid := is_instance_valid(player)
	empty_label.visible = not valid
	tabs.visible = valid
	for button in bulk_buttons: button.disabled = not valid
	if not valid:
		status.text = "F3 opens the level editor from the test world."
		return
	var controller := player.find_child("CharacterController", true, false) as CharacterController
	var combat := player.find_child("PlayerCombatController", true, false) as PlayerCombatController
	var health := player.find_child("HealthComponent", true, false) as HealthComponent
	for id in MOVEMENT: toggles[id].set_pressed_no_signal(controller.get("has_" + id))
	for id in CASTER:
		toggles[id].disabled = combat == null
		toggles[id].set_pressed_no_signal(combat.get(id) if combat else false)
	for id in DAGGER:
		toggles[id].disabled = combat == null
		toggles[id].set_pressed_no_signal(combat.get(id) if combat else false)
	for id in EVOLVED:
		toggles[id].disabled = combat == null
		toggles[id].set_pressed_no_signal(combat.get(id) if combat else false)
	toggles.combo_1.set_pressed_no_signal(combat != null and combat.dagger_combo_upgrades >= 1)
	toggles.combo_2.set_pressed_no_signal(combat != null and combat.dagger_combo_upgrades >= 2)
	var count := maxi(0, (health.max_health - 16) / 4) if health else 0
	toggles.health.set_pressed_no_signal(count > 0)
	health_count.set_value_no_signal(maxi(1, count))
	health_count.editable = count > 0
	if combat:
		module_left.select(["piercing", "spread", "guided"].find(combat.left_caster_module))
		module_right.select(["piercing", "spread", "guided"].find(combat.right_caster_module))
	status.text = "Current player  /  Max health: %d  /  F2 or Escape to resume" % (health.max_health if health else 0)


func set_upgrade(enabled: bool, id: String) -> void:
	if not is_instance_valid(player): return
	if id.begins_with("has_extended_edge_") or id.begins_with("has_reinforced_edge_"):
		var overrides: Dictionary = player.get_meta(META, {})
		overrides[id] = enabled
		var prefix := id.left(id.length() - 1)
		if id.ends_with("2") and enabled: overrides[prefix + "1"] = true
		if id.ends_with("1") and not enabled: overrides[prefix + "2"] = false
		player.set_meta(META, overrides)
		_apply_current()
		refresh()
		return
	if id == "combo_1" or id == "combo_2":
		var combat := player.find_child("PlayerCombatController", true, false) as PlayerCombatController
		var level := combat.dagger_combo_upgrades
		if id == "combo_1": level = maxi(level, 1) if enabled else 0
		else: level = 2 if enabled else mini(level, 1)
		_set_value("dagger_combo_upgrades", level)
	elif id == "health":
		_set_value("health_count", int(health_count.value) if enabled else 0)
	else:
		_set_value(id, enabled)


func _set_value(id: String, value: Variant) -> void:
	if not is_instance_valid(player): return
	_ensure_baseline(player)
	var overrides: Dictionary = player.get_meta(META, {})
	overrides[id] = value
	player.set_meta(META, overrides)
	_apply_current()
	refresh()


func set_all(enabled: bool) -> void:
	if not is_instance_valid(player): return
	var overrides: Dictionary = player.get_meta(META, {})
	for catalog in [MOVEMENT, CASTER, DAGGER, EVOLVED]:
		for id in catalog: overrides[id] = enabled
	overrides.dagger_combo_upgrades = 2 if enabled else 0
	overrides.health_count = int(health_count.value) if enabled else 0
	player.set_meta(META, overrides)
	_apply_current()
	refresh()


func restore_normal() -> void:
	if not is_instance_valid(player): return
	var baseline: Dictionary = player.get_meta(BASELINE, {})
	player.set_meta(META, baseline.duplicate())
	apply_player_overrides(player)
	player.remove_meta(META)
	var runner := _world_for(player)
	if runner:
		runner.refresh_upgrade_overrides()
	else:
		var health := player.find_child("HealthComponent", true, false) as HealthComponent
		if health: health.set_max_health(int(baseline.get("health_max", 16)), false)
	refresh()


func _apply_current() -> void:
	var runner := _world_for(player)
	if runner: runner.refresh_upgrade_overrides()
	else: apply_player_overrides(player)


func apply_player_overrides(target: Node) -> void:
	var overrides: Dictionary = target.get_meta(META, {})
	if overrides.is_empty(): return
	var controller := target.find_child("CharacterController", true, false) as CharacterController
	var combat := target.find_child("PlayerCombatController", true, false) as PlayerCombatController
	var health := target.find_child("HealthComponent", true, false) as HealthComponent
	for id in MOVEMENT:
		if overrides.has(id): controller.set("has_" + id, bool(overrides[id]))
	if not controller.has_propulsor_step: controller.propulsor_jump_available = false
	if combat:
		for catalog in [CASTER, DAGGER, EVOLVED]:
			for id in catalog:
				if overrides.has(id): combat.set(id, bool(overrides[id]))
		for id in ["dagger_combo_upgrades", "left_caster_module", "right_caster_module"]:
			if overrides.has(id): combat.set(id, overrides[id])
		if not combat.has_buster_v1 or not combat.has_charged_caster: combat.cancel_charge()
		if not combat.has_vine_whip: combat.cancel_vine_whip()
		if not combat.has_burrow and is_instance_valid(combat.burrow) and combat.burrow.is_inside_tree(): combat.burrow.finish(true)
	if health and overrides.has("health_count"):
		health.set_max_health(16 + clampi(int(overrides.health_count), 0, 200) * 4, false)
	# Stop indefinite wall/ledge states when their upgrade is disabled.
	var state := controller.state_machine.current_state
	if state and ((state.name == "WallSlide" and not controller.has_wall_slide) or (state.name == "LedgeHang" and not controller.has_ledge_flow)):
		controller.state_machine.change_state("Airborne")
