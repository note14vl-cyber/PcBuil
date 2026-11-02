extends Node3D

const PARTS = [
	{"id":"cpu", "name":"Процессор Core i5", "price":180, "color":Color(0.72,0.74,0.78), "size":Vector3(0.18,0.035,0.18)},
	{"id":"ram", "name":"ОЗУ DDR4 8 ГБ", "price":65, "color":Color(0.12,0.55,0.32), "size":Vector3(0.34,0.035,0.075)},
	{"id":"gpu", "name":"Видеокарта GTX 1660", "price":260, "color":Color(0.12,0.16,0.20), "size":Vector3(0.62,0.12,0.22)},
	{"id":"ssd", "name":"SSD 512 ГБ", "price":75, "color":Color(0.15,0.18,0.22), "size":Vector3(0.22,0.025,0.14)},
	{"id":"psu", "name":"Блок питания 600 Вт", "price":90, "color":Color(0.22,0.24,0.27), "size":Vector3(0.30,0.13,0.28)},
	{"id":"cooler", "name":"Кулер башенный", "price":55, "color":Color(0.55,0.58,0.62), "size":Vector3(0.20,0.22,0.20)}
]

var money := 1200
var inventory: Dictionary = {"cpu": 1, "ram": 2, "gpu": 1, "ssd": 1, "psu": 1, "cooler": 1}
var installed: Dictionary = {}
var selected_part := ""
var mode := "build"
var camera: Camera3D
var player: CharacterBody3D
var yaw := 0.0
var pitch := -0.12
var look_touch := -1
var move_touch := -1
var move_vector := Vector2.ZERO
var move_buttons: Dictionary = {}
var touch_start := Vector2.ZERO
var held_part := ""
var held_mesh: MeshInstance3D
var interact_button: Button
var interaction_hint := "Подойди к столу, выбери деталь и нажми ВЗЯТЬ."
var ui_layer: CanvasLayer
var status_label: Label
var money_label: Label
var parts_box: VBoxContainer
var info_panel: PanelContainer
var active_panel := ""
var order_label: Label
var case_root: Node3D
var motherboard: MeshInstance3D
var part_nodes: Dictionary = {}
var desk_top: MeshInstance3D
var part_data_by_id: Dictionary = {}
var slot_nodes: Dictionary = {}
var targeted_slot := ""
var held_rotation := 0.0
var rotate_button: Button

func _ready() -> void:
	for p in PARTS:
		part_data_by_id[p.id] = p
	_build_world()
	_build_ui()
	_update_ui()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

func _build_world() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.48, 0.52, 0.60)
	env.ambient_light_energy = 0.65
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_energy = 1.1
	add_child(sun)

	_make_box("Floor", Vector3(0, -0.12, 0), Vector3(12, 0.2, 12), Color(0.16,0.17,0.19))
	_make_box("Back wall", Vector3(0, 2.1, -4.5), Vector3(12, 4.4, 0.2), Color(0.24,0.25,0.27))
	_make_box("Left wall", Vector3(-5.8, 2.1, 0), Vector3(0.2, 4.4, 9), Color(0.20,0.21,0.23))
	_make_box("Right wall", Vector3(5.8, 2.1, 0), Vector3(0.2, 4.4, 9), Color(0.20,0.21,0.23))
	_make_box("Ceiling", Vector3(0, 4.35, 0), Vector3(12, 0.2, 9), Color(0.13,0.14,0.16))
	# Workshop shelves and storage
	_make_box("Shelf", Vector3(-4.6, 2.2, -3.8), Vector3(1.6,0.12,0.5), Color(0.28,0.29,0.31))
	_make_box("Shelf lower", Vector3(-4.6, 1.1, -3.8), Vector3(1.6,0.12,0.5), Color(0.28,0.29,0.31))
	_make_box("Cabinet", Vector3(4.4,0.9,-3.7), Vector3(1.2,1.8,0.8), Color(0.12,0.14,0.17))
	_make_box("Desk top", Vector3(0,1.05,-1.5), Vector3(3.8,0.16,1.8), Color(0.22,0.16,0.12))
	_make_box("Desk leg L", Vector3(-1.65,0.5,-1.5), Vector3(0.12,1.0,1.45), Color(0.12,0.13,0.15))
	_make_box("Desk leg R", Vector3(1.65,0.5,-1.5), Vector3(0.12,1.0,1.45), Color(0.12,0.13,0.15))
	_make_box("Monitor", Vector3(-1.0,1.85,-2.0), Vector3(1.05,0.62,0.10), Color(0.025,0.035,0.045))
	_make_box("Monitor screen", Vector3(-1.0,1.85,-1.94), Vector3(0.91,0.48,0.012), Color(0.08,0.22,0.30))
	_make_box("Keyboard", Vector3(-0.95,1.18,-0.95), Vector3(0.9,0.035,0.28), Color(0.07,0.08,0.09))

	case_root = Node3D.new()
	case_root.position = Vector3(0.55,1.18,-1.55)
	add_child(case_root)
	_build_case()

	player = CharacterBody3D.new()
	player.position = Vector3(0,0.05,2.8)
	add_child(player)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.65
	capsule.radius = 0.28
	collision.shape = capsule
	collision.position.y = 0.82
	player.add_child(collision)
	camera = Camera3D.new()
	camera.position = Vector3(0,1.55,0)
	camera.current = true
	player.add_child(camera)
	camera.rotation.x = pitch

func _build_case() -> void:
	# Open-sided PC chassis so installed components remain visible.
	_make_child_box(case_root,"Case base",Vector3(0,0,0),Vector3(1.35,0.10,0.72),Color(0.08,0.09,0.11))
	_make_child_box(case_root,"Case rear",Vector3(-0.65,0.62,0),Vector3(0.08,1.18,0.72),Color(0.10,0.12,0.15))
	_make_child_box(case_root,"Case top",Vector3(0,1.20,0),Vector3(1.35,0.08,0.72),Color(0.10,0.12,0.15))
	_make_child_box(case_root,"Case front",Vector3(0.65,0.62,0),Vector3(0.08,1.18,0.72),Color(0.13,0.15,0.18))
	_make_child_box(case_root,"Motherboard",Vector3(-0.12,0.62,-0.31),Vector3(0.92,0.92,0.035),Color(0.035,0.20,0.13))
	# motherboard details
	for i in range(4):
		_make_child_box(case_root,"Board trace %d" % i,Vector3(-0.45 + i*0.20,0.62,-0.285),Vector3(0.025,0.65,0.012),Color(0.65,0.48,0.16))
	_make_child_box(case_root,"PSU bay",Vector3(0.32,0.18,0.12),Vector3(0.55,0.28,0.42),Color(0.12,0.13,0.15))
	_create_slot("cpu", Vector3(-0.18,0.72,-0.235), Vector3(0.34,0.20,0.12), Vector3(0.25,0.16,0.035))
	_create_slot("ram", Vector3(-0.48,0.70,-0.235), Vector3(0.48,0.18,0.12), Vector3(0.40,0.10,0.035))
	_create_slot("gpu", Vector3(-0.10,0.42,-0.15), Vector3(0.78,0.24,0.20), Vector3(0.72,0.15,0.045))
	_create_slot("ssd", Vector3(0.35,0.85,-0.235), Vector3(0.32,0.15,0.12), Vector3(0.28,0.12,0.035))
	_create_slot("psu", Vector3(0.32,0.18,0.12), Vector3(0.62,0.34,0.50), Vector3(0.52,0.24,0.40))
	_create_slot("cooler", Vector3(-0.18,0.91,-0.14), Vector3(0.34,0.34,0.20), Vector3(0.28,0.28,0.12))

func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(root)

	var top := HBoxContainer.new()
	top.position = Vector2(18,14)
	top.add_theme_constant_override("separation",12)
	root.add_child(top)
	money_label = Label.new()
	money_label.add_theme_font_size_override("font_size",24)
	top.add_child(money_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var shop_btn := _button("МАГАЗИН",Callable(self,"_show_shop"))
	top.add_child(shop_btn)
	var order_btn := _button("ЗАКАЗЫ",Callable(self,"_show_orders"))
	top.add_child(order_btn)
	var build_btn := _button("СБОРКА",Callable(self,"_show_build"))
	top.add_child(build_btn)

	info_panel = PanelContainer.new()
	info_panel.position = Vector2(18,75)
	info_panel.custom_minimum_size = Vector2(285,0)
	info_panel.size = Vector2(285,500)
	info_panel.visible = false
	root.add_child(info_panel)
	var panel := info_panel
	var panel_v := VBoxContainer.new()
	panel_v.add_theme_constant_override("separation",8)
	panel.add_child(panel_v)
	var heading := Label.new()
	heading.text = "КОМПЛЕКТУЮЩИЕ"
	heading.add_theme_font_size_override("font_size",19)
	panel_v.add_child(heading)
	parts_box = VBoxContainer.new()
	parts_box.add_theme_constant_override("separation",6)
	panel_v.add_child(parts_box)
	var sep := HSeparator.new()
	panel_v.add_child(sep)
	order_label = Label.new()
	order_label.text = "ЗАДАНИЕ\nСобери рабочий ПК:\nCPU + RAM + GPU + SSD + PSU + кулер"
	order_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel_v.add_child(order_label)

	# Virtual joystick area: drag anywhere in the lower-left zone to move.
	var joystick := Panel.new()
	joystick.name = "TouchJoystick"
	joystick.anchor_left = 0.0
	joystick.anchor_right = 0.0
	joystick.anchor_top = 1.0
	joystick.anchor_bottom = 1.0
	joystick.offset_left = 28
	joystick.offset_top = -190
	joystick.offset_right = 178
	joystick.offset_bottom = -40
	joystick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick.modulate = Color(0.7, 0.85, 1.0, 0.28)
	root.add_child(joystick)
	var joystick_label := Label.new()
	joystick_label.text = "ДВИЖЕНИЕ"
	joystick_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	joystick_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	joystick_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	joystick_label.add_theme_font_size_override("font_size", 13)
	joystick_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick.add_child(joystick_label)

	var bottom := HBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.position = Vector2(18,-68)
	bottom.size = Vector2(-36,54)
	bottom.add_theme_constant_override("separation",10)
	root.add_child(bottom)
	var move_hint := Label.new()
	move_hint.text = "ЛЕВЫЙ НИЖНИЙ УГОЛ: джойстик  •  ПРАВАЯ ЧАСТЬ: поворот камеры"
	move_hint.add_theme_font_size_override("font_size",15)
	bottom.add_child(move_hint)
	interact_button = _button("УСТАНОВИТЬ В СЛОТ",Callable(self,"_interact"))
	interact_button.custom_minimum_size = Vector2(210,54)
	bottom.add_child(interact_button)
	rotate_button = _button("ПОВЕРНУТЬ 90°",Callable(self,"_rotate_held_part"))
	rotate_button.custom_minimum_size = Vector2(150,54)
	rotate_button.disabled = true
	bottom.add_child(rotate_button)
	var run_btn := _button("ПРОВЕРИТЬ ПК",Callable(self,"_test_pc"))
	bottom.add_child(run_btn)

	status_label = Label.new()
	status_label.anchor_left = 0.5
	status_label.anchor_right = 0.5
	status_label.anchor_top = 0.86
	status_label.anchor_bottom = 0.94
	status_label.offset_left = -260
	status_label.offset_right = 260
	status_label.add_theme_font_size_override("font_size",20)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(status_label)

	# Crosshair
	var cross := Label.new()
	cross.text = "+"
	cross.anchor_left = 0.5
	cross.anchor_top = 0.5
	cross.anchor_right = 0.5
	cross.anchor_bottom = 0.5
	cross.offset_left = -8
	cross.offset_top = -16
	cross.offset_right = 8
	cross.offset_bottom = 16
	cross.add_theme_font_size_override("font_size",26)
	cross.add_theme_color_override("font_color",Color(0.8,0.95,1))
	root.add_child(cross)

func _update_ui() -> void:
	money_label.text = "БАЛАНС: $%d" % money
	for child in parts_box.get_children():
		child.queue_free()
	if mode == "shop":
		_build_shop_list()
		return
	for part in PARTS:
		var row := HBoxContainer.new()
		parts_box.add_child(row)
		var label := Label.new()
		var count := int(inventory.get(part.id,0))
		label.text = "%s  x%d" % [part.name,count]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size",14)
		row.add_child(label)
		var btn := Button.new()
		btn.text = "ВЗЯТЬ" if count > 0 and not installed.has(part.id) else ("ГОТОВО" if installed.has(part.id) else "НЕТ")
		btn.disabled = count <= 0 or installed.has(part.id) or held_part != ""
		btn.pressed.connect(_pick_part.bind(part.id))
		row.add_child(btn)

func _pick_part(id: String) -> void:
	if held_part != "" or int(inventory.get(id,0)) <= 0 or installed.has(id):
		return
	held_part = id
	var data: Dictionary = part_data_by_id[id]
	held_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = data.size
	held_mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = data.color
	mat.metallic = 0.4
	mat.roughness = 0.42
	held_mesh.material_override = mat
	held_mesh.position = Vector3(0.32,-0.22,-0.72)
	camera.add_child(held_mesh)
	held_rotation = 0.0
	status_label.text = "В руках: %s. Наведи прицел на подходящий разъём." % data.name
	interact_button.text = "УСТАНОВИТЬ В СЛОТ"
	rotate_button.disabled = false
	_update_ui()

func _interact() -> void:
	if held_part == "":
		status_label.text = "Сначала выбери комплектующую слева и нажми ВЗЯТЬ."
		return
	var distance := player.global_position.distance_to(case_root.global_position)
	if distance > 3.2:
		status_label.text = "Подойди ближе к корпусу и наведи прицел на нужный разъём."
		return
	if targeted_slot == "":
		status_label.text = "Наведи центральный прицел на разъём."
		return
	if targeted_slot != held_part:
		status_label.text = "Это разъём %s, а у тебя в руках %s." % [targeted_slot.to_upper(), held_part.to_upper()]
		return
	var id := held_part
	var data: Dictionary = part_data_by_id[id]
	var slot: Area3D = slot_nodes[id]
	var pos: Vector3 = slot.position
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = data.size
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = data.color
	mat.metallic = 0.4
	mat.roughness = 0.45
	mesh.material_override = mat
	mesh.position = pos
	mesh.rotation.z = deg_to_rad(held_rotation)
	case_root.add_child(mesh)
	part_nodes[id] = mesh
	installed[id] = true
	slot_nodes[id].collision_layer = 0
	var slot_marker := slot.get_child(1) as MeshInstance3D
	slot_marker.visible = false
	inventory[id] = int(inventory.get(id,0)) - 1
	if is_instance_valid(held_mesh):
		held_mesh.queue_free()
	held_mesh = null
	held_part = ""
	held_rotation = 0.0
	rotate_button.disabled = true
	interact_button.text = "УСТАНОВИТЬ В СЛОТ"
	status_label.text = "Деталь установлена в правильный разъём: %s" % data.name
	_update_ui()


func _create_slot(id: String, pos: Vector3, collision_size: Vector3, visual_size: Vector3) -> void:
	var area := Area3D.new()
	area.name = "Socket_" + id
	area.position = pos
	area.collision_layer = 2
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = collision_size
	shape_node.shape = shape
	area.add_child(shape_node)
	var marker := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = visual_size
	marker.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.62, 0.16, 0.38)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.material_override = mat
	area.add_child(marker)
	area.set_meta("part_id", id)
	case_root.add_child(area)
	slot_nodes[id] = area

func _rotate_held_part() -> void:
	if held_part == "" or not is_instance_valid(held_mesh):
		return
	held_rotation = fposmod(held_rotation + 90.0, 360.0)
	held_mesh.rotation.z = deg_to_rad(held_rotation)
	status_label.text = "Поворот детали: %d°" % int(held_rotation)

func _update_slot_target() -> void:
	var previous := targeted_slot
	targeted_slot = ""
	if camera == null:
		return
	var ray_from := camera.global_position
	var ray_to := ray_from + (-camera.global_transform.basis.z * 5.0)
	var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to)
	query.collision_mask = 2
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var collider = hit.get("collider")
		if collider is Area3D and collider.has_meta("part_id"):
			targeted_slot = str(collider.get_meta("part_id"))
	for id in slot_nodes:
		var area: Area3D = slot_nodes[id]
		var marker := area.get_child(1) as MeshInstance3D
		var mat := marker.material_override as StandardMaterial3D
		if str(id) == targeted_slot:
			mat.albedo_color = Color(0.15, 1.0, 0.32, 0.72) if str(id) == held_part else Color(1.0, 0.35, 0.12, 0.72)
		else:
			mat.albedo_color = Color(0.85, 0.62, 0.16, 0.38)
	if targeted_slot != previous and targeted_slot != "":
		status_label.text = "Разъём: %s%s" % [targeted_slot.to_upper(), " — подходит" if targeted_slot == held_part else " — другая деталь"]

func _show_build() -> void:
	if active_panel == "build":
		_close_info_panel()
		return
	active_panel = "build"
	mode = "build"
	info_panel.visible = true
	order_label.text = "СБОРКА\nВыбери комплектующую в списке и установи её в корпус."
	_update_ui()
	status_label.text = "Режим сборки. Выбери деталь."

func _show_shop() -> void:
	if active_panel == "shop":
		_close_info_panel()
		return
	active_panel = "shop"
	mode = "shop"
	info_panel.visible = true
	order_label.text = "МАГАЗИН\nПокупай детали для сборки. Баланс ограничен."
	_build_shop_list()
	status_label.text = "МАГАЗИН: купи запасные комплектующие."

func _build_shop_list() -> void:
	for child in parts_box.get_children():
		child.queue_free()
	for part in PARTS:
		var row := HBoxContainer.new()
		parts_box.add_child(row)
		var label := Label.new()
		label.text = "%s  $%d" % [part.name,part.price]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size",14)
		row.add_child(label)
		var btn := Button.new()
		btn.text = "КУПИТЬ"
		btn.pressed.connect(_buy_part.bind(part.id,int(part.price)))
		row.add_child(btn)

func _show_orders() -> void:
	if active_panel == "orders":
		_close_info_panel()
		return
	active_panel = "orders"
	mode = "orders"
	info_panel.visible = true
	order_label.text = "ЗАКАЗ №001\nКлиенту нужен игровой ПК.\nНаграда: $650\nУстанови все 6 основных компонентов и нажми ПРОВЕРИТЬ ПК."
	for child in parts_box.get_children():
		child.queue_free()
	status_label.text = "Выполни заказ, чтобы получить оплату."

func _close_info_panel() -> void:
	active_panel = ""
	info_panel.visible = false
	mode = "build"
	_update_ui()

func _buy_part(id: String, price: int) -> void:
	if money < price:
		status_label.text = "Недостаточно денег!"
		return
	money -= price
	inventory[id] = int(inventory.get(id,0)) + 1
	status_label.text = "Куплено: %s" % id.to_upper()
	_update_ui()

func _test_pc() -> void:
	var required := ["cpu","ram","gpu","ssd","psu","cooler"]
	for id in required:
		if not installed.has(id):
			status_label.text = "Сборка не готова: не хватает %s" % id.to_upper()
			return
	status_label.text = "ПК успешно запустился! Заказ выполнен: +$650"
	money += 650
	installed.clear()
	for node in part_nodes.values():
		node.queue_free()
	part_nodes.clear()
	_update_ui()

func _make_box(label: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.82
	mesh.material_override = mat
	mesh.position = pos
	add_child(mesh)
	return mesh

func _make_child_box(parent: Node3D, label: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.25
	mat.roughness = 0.55
	mesh.material_override = mat
	mesh.position = pos
	parent.add_child(mesh)
	return mesh

func _button(text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(120,44)
	button.add_theme_font_size_override("font_size",15)
	button.pressed.connect(callback)
	return button

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_rotate_camera(event.relative)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventScreenTouch:
		if event.pressed:
			var screen_size := get_viewport().get_visible_rect().size
			# Leave the top menu and bottom action buttons to the UI.
			var in_control_band := event.position.y < 105.0 or event.position.y > screen_size.y - 105.0
			if not in_control_band and event.position.x < screen_size.x * 0.43 and move_touch == -1:
				move_touch = event.index
				touch_start = event.position
				move_vector = Vector2.ZERO
			elif not in_control_band and event.position.x >= screen_size.x * 0.43 and look_touch == -1:
				look_touch = event.index
		else:
			if event.index == look_touch:
				look_touch = -1
			if event.index == move_touch:
				move_touch = -1
				move_vector = Vector2.ZERO
	elif event is InputEventScreenDrag:
		if event.index == look_touch:
			_rotate_camera(event.relative)
		elif event.index == move_touch:
			move_vector = ((event.position - touch_start) / 65.0).limit_length(1.0)

func _set_move_button(key: String, pressed: bool) -> void:
	move_buttons[key] = pressed
	var x := 0.0
	var y := 0.0
	if bool(move_buttons.get("left", false)): x -= 1.0
	if bool(move_buttons.get("right", false)): x += 1.0
	if bool(move_buttons.get("up", false)): y -= 1.0
	if bool(move_buttons.get("down", false)): y += 1.0
	move_vector = Vector2(x,y).limit_length(1.0)

func _rotate_camera(delta: Vector2) -> void:
	yaw -= delta.x * 0.003
	pitch = clamp(pitch - delta.y * 0.003,-0.85,0.65)
	player.rotation.y = yaw
	camera.rotation.x = pitch

func _physics_process(_delta: float) -> void:
	if player == null:
		return
	var direction := Vector3.ZERO
	var input_x := move_vector.x
	var input_y := move_vector.y
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): input_y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): input_y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): input_x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): input_x += 1.0
	direction += player.global_transform.basis.x * input_x
	direction += -player.global_transform.basis.z * -input_y
	if direction.length() > 1.0:
		direction = direction.normalized()
	player.velocity.x = direction.x * 2.5
	player.velocity.z = direction.z * 2.5
	player.velocity.y = 0.0
	player.move_and_slide()
	player.position.x = clamp(player.position.x,-4.8,4.8)
	player.position.z = clamp(player.position.z,-3.5,4.5)
	_update_slot_target()
