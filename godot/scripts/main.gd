extends Node3D
## Small playable 2.5D foundation. Placeholder meshes are generated in code
## so the project can be opened without external art assets.

const MOVE_SPEED := 6.0
const ATTACK_DAMAGE := 25
const XP_PER_KILL := 30
const XP_TO_LEVEL := 60
const EVOLUTION_LEVEL := 3

var player: CharacterBody3D
var companion: Node3D
var wild_monster: Node3D
var camera: Camera3D
var hud_label: Label
var message_label: Label
var monster_level := 1
var monster_xp := 0
var monster_hp := 60
var monster_max_hp := 60
var attack_cooldown := 0.0
var monster_respawn_time := 0.0
var caught := false
var evolved := false
var message_time := 0.0

func _ready() -> void:
	_setup_input()
	_build_world()
	_build_player()
	_build_companion()
	_build_wild_monster()
	_build_camera()
	_build_hud()
	_show_message("WASD / Arrows: Move | Space / Left Click: Attack | E: Catch | V: Evolve")

func _process(delta: float) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	if monster_respawn_time > 0.0:
		monster_respawn_time -= delta
		if monster_respawn_time <= 0.0 and not is_instance_valid(wild_monster):
			_build_wild_monster()
	message_time = maxf(0.0, message_time - delta)
	if message_time <= 0.0:
		message_label.text = ""
	_update_hud()
	if is_instance_valid(camera) and is_instance_valid(player):
		var target := player.global_position
		var camera_offset := Vector3(9.0, 10.0, 9.0)
		camera.global_position = camera.global_position.lerp(target + camera_offset, minf(1.0, delta * 5.0))
		camera.look_at(target + Vector3(0.0, 0.8, 0.0), Vector3.UP)
	if is_instance_valid(companion) and is_instance_valid(player):
		var follow := player.global_position + Vector3(-1.6, 0.0, 1.2)
		companion.global_position = companion.global_position.lerp(follow, delta * 4.0)

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	var input_dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_up") - Input.get_action_strength("move_down")
	)
	# Camera-relative movement makes directions feel natural from the isometric view.
	var forward := Vector3(-1.0, 0.0, -1.0).normalized()
	var right := Vector3(1.0, 0.0, -1.0).normalized()
	var direction := (right * input_dir.x + forward * input_dir.y).normalized()
	player.velocity.x = direction.x * MOVE_SPEED
	player.velocity.z = direction.z * MOVE_SPEED
	player.velocity.y = 0.0
	player.move_and_slide()
	if direction.length() > 0.01:
		player.rotation.y = atan2(direction.x, direction.z)
	if Input.is_action_just_pressed("attack"):
		_try_attack()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("catch_monster"):
		_try_catch()
	elif event.is_action_pressed("attack"):
		_try_attack()
	elif event.is_action_pressed("evolve_monster"):
		_try_evolve()

func _setup_input() -> void:
	_add_key_action("move_up", KEY_W)
	_add_key_action("move_up", KEY_UP)
	_add_key_action("move_down", KEY_S)
	_add_key_action("move_down", KEY_DOWN)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_left", KEY_LEFT)
	_add_key_action("move_right", KEY_D)
	_add_key_action("move_right", KEY_RIGHT)
	_add_key_action("catch_monster", KEY_E)
	_add_key_action("attack", KEY_SPACE)
	_add_key_action("evolve_monster", KEY_V)
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
	var mouse_attack := InputEventMouseButton.new()
	mouse_attack.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack", mouse_attack)

func _add_key_action(action_name: String, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action_name, event)

func _build_world() -> void:
	var world_env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.58, 0.67, 0.82)
	environment.ambient_light_energy = 0.65
	world_env.environment = environment
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -30.0, 0.0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)

	var floor_body := StaticBody3D.new()
	floor_body.name = "Ground"
	add_child(floor_body)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80.0, 80.0)
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.19, 0.31, 0.22)
	ground_mat.roughness = 1.0
	plane.material = ground_mat
	floor_mesh.mesh = plane
	floor_body.add_child(floor_mesh)
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(80.0, 0.2, 80.0)
	floor_collision.shape = floor_shape
	floor_collision.position.y = -0.1
	floor_body.add_child(floor_collision)

	# Simple crystal landmarks give the placeholder map a readable silhouette.
	for i in range(7):
		var crystal := MeshInstance3D.new()
		var mesh := PrismMesh.new()
		mesh.size = Vector3(0.8, 1.8 + float(i % 3) * 0.5, 0.8)
		crystal.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.15, 0.62, 0.78)
		mat.emission_enabled = true
		mat.emission = Color(0.04, 0.24, 0.36)
		crystal.material_override = mat
		crystal.position = Vector3(-10.0 + i * 3.5, mesh.size.y * 0.5, -7.0 - (i % 2) * 4.0)
		add_child(crystal)

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Tamer"
	add_child(player)
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.38
	shape.height = 1.6
	collision.shape = shape
	collision.position.y = 0.8
	player.add_child(collision)
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.38
	capsule.height = 1.6
	body.mesh = capsule
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.38, 0.78)
	body.material_override = mat
	body.position.y = 0.8
	player.add_child(body)
	player.position = Vector3.ZERO

func _build_companion() -> void:
	companion = _make_creature("Companion", Color(0.9, 0.57, 0.2), 0.8)
	companion.position = Vector3(-1.6, 0.0, 1.2)
	add_child(companion)

func _build_wild_monster() -> void:
	wild_monster = _make_creature("Wild Cinderling", Color(0.82, 0.25, 0.17), 1.0)
	wild_monster.position = Vector3(4.0, 0.0, -2.0)
	monster_hp = monster_max_hp
	add_child(wild_monster)

func _make_creature(creature_name: String, tint: Color, scale_value: float) -> Node3D:
	var root := Node3D.new()
	root.name = creature_name
	var body := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.55 * scale_value
	mesh.height = 1.1 * scale_value
	body.mesh = mesh
	body.position.y = 0.55 * scale_value
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.72
	body.material_override = material
	root.add_child(body)
	# Add a crest and feet to make the placeholder silhouette less generic.
	var crest := MeshInstance3D.new()
	var crest_mesh := PrismMesh.new()
	crest_mesh.size = Vector3(0.42 * scale_value, 0.5 * scale_value, 0.35 * scale_value)
	crest.mesh = crest_mesh
	var crest_mat := StandardMaterial3D.new()
	crest_mat.albedo_color = tint.lightened(0.18)
	crest.material_override = crest_mat
	crest.position = Vector3(0.0, 1.0 * scale_value, 0.18 * scale_value)
	root.add_child(crest)
	for side in [-1.0, 1.0]:
		var foot := MeshInstance3D.new()
		var foot_mesh := SphereMesh.new()
		foot_mesh.radius = 0.2 * scale_value
		foot_mesh.height = 0.25 * scale_value
		foot.mesh = foot_mesh
		foot.position = Vector3(side * 0.32 * scale_value, 0.12 * scale_value, 0.02 * scale_value)
		foot.material_override = material
		root.add_child(foot)
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.04, 0.035, 0.03)
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.075 * scale_value
		eye_mesh.height = 0.15 * scale_value
		eye.mesh = eye_mesh
		eye.material_override = eye_mat
		eye.position = Vector3(side * 0.19 * scale_value, 0.66 * scale_value, -0.42 * scale_value)
		root.add_child(eye)
	return root

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "IsometricCamera"
	camera.fov = 45.0
	camera.position = Vector3(10.0, 12.0, 10.0)
	add_child(camera)
	camera.current = true
	camera.look_at(Vector3.ZERO, Vector3.UP)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(18.0, 18.0)
	panel.custom_minimum_size = Vector2(420.0, 145.0)
	layer.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	hud_label = Label.new()
	hud_label.add_theme_font_size_override("font_size", 17)
	column.add_child(hud_label)
	var controls := Label.new()
	controls.text = "WASD / Arrows: Move   Space / Left Click: Attack   E: Catch   V: Evolve"
	controls.add_theme_font_size_override("font_size", 12)
	column.add_child(controls)
	message_label = Label.new()
	message_label.position = Vector2(18.0, 150.0)
	message_label.add_theme_font_size_override("font_size", 16)
	layer.add_child(message_label)

func _try_catch() -> void:
	if caught:
		_show_message("You already have a companion. Train it with T!")
		return
	if player.global_position.distance_to(wild_monster.global_position) > 3.2:
		_show_message("Move closer to the wild Cinderling to catch it.")
		return
	caught = true
	wild_monster.queue_free()
	companion.queue_free()
	companion = _make_creature("Cinderling", Color(0.82, 0.25, 0.17), 0.8)
	add_child(companion)
	_show_message("Caught Cinderling! Your new companion is ready to train.")

func _try_attack() -> void:
	if attack_cooldown > 0.0:
		return
	attack_cooldown = 0.42
	if not is_instance_valid(wild_monster):
		_show_message("No wild monster nearby. A new one will appear soon.")
		return
	var distance := player.global_position.distance_to(wild_monster.global_position)
	if distance > 2.8:
		_show_message("Too far away! Move closer to attack.")
		return
	monster_hp = maxi(0, monster_hp - ATTACK_DAMAGE)
	if monster_hp <= 0:
		wild_monster.queue_free()
		monster_respawn_time = 3.0
		monster_xp += XP_PER_KILL
		var levelled_up := false
		while monster_xp >= XP_TO_LEVEL:
			monster_xp -= XP_TO_LEVEL
			monster_level += 1
			levelled_up = true
		if levelled_up:
			_show_message("Monster defeated! +%d EXP. Cinderling reached Lv. %d!" % [XP_PER_KILL, monster_level])
		else:
			_show_message("Monster defeated! +%d EXP. %d/%d EXP to next level." % [XP_PER_KILL, monster_xp, XP_TO_LEVEL])
	else:
		_show_message("Hit! Wild Cinderling HP: %d/%d" % [monster_hp, monster_max_hp])

func _try_evolve() -> void:
	if not caught:
		_show_message("You need a companion before it can evolve.")
	elif monster_level < EVOLUTION_LEVEL:
		_show_message("Cinderling needs level %d to evolve (current level %d)." % [EVOLUTION_LEVEL, monster_level])
	elif evolved:
		_show_message("Cinderling has already evolved in this prototype.")
	else:
		evolved = true
		companion.scale = Vector3.ONE * 1.45
		var body := companion.get_child(0) as MeshInstance3D
		if body and body.material_override is StandardMaterial3D:
			(body.material_override as StandardMaterial3D).albedo_color = Color(0.42, 0.2, 0.82)
		_show_message("Evolution! Cinderling became an Emberkin. (Prototype form)")

func _show_message(text_value: String) -> void:
	message_label.text = text_value
	message_time = 4.0

func _update_hud() -> void:
	var state := "Wild encounter nearby" if not caught else ("Emberkin (Evolved)" if evolved else "Cinderling")
	var level_text := "Lv. %d  |  EXP %d/%d" % [monster_level, monster_xp, XP_TO_LEVEL] if caught else "Catch a wild monster to begin"
	var enemy_text := "Wild Cinderling HP: %d/%d" % [monster_hp, monster_max_hp] if is_instance_valid(wild_monster) else "Wild monster respawning..."
	hud_label.text = "VELDARA  •  2.5D PROTOTYPE\nCompanion: %s\n%s\n%s" % [state, level_text, enemy_text]
