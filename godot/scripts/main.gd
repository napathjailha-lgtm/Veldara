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
	# Soft forest lighting and distant atmospheric fog.
	var world_env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.10, 0.22, 0.25)
	sky_material.sky_horizon_color = Color(0.55, 0.68, 0.55)
	sky_material.ground_bottom_color = Color(0.08, 0.13, 0.09)
	sky_material.ground_horizon_color = Color(0.27, 0.37, 0.25)
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.48, 0.62, 0.43)
	environment.ambient_light_energy = 0.8
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.47, 0.59, 0.43)
	environment.fog_density = 0.008
	world_env.environment = environment
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	sun.light_color = Color(1.0, 0.91, 0.72)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)

	# Mossy forest floor.
	var floor_body := StaticBody3D.new()
	floor_body.name = "ForestGround"
	add_child(floor_body)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(100.0, 100.0)
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.16, 0.25, 0.14)
	ground_mat.roughness = 1.0
	plane.material = ground_mat
	floor_mesh.mesh = plane
	floor_body.add_child(floor_mesh)
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(100.0, 0.2, 100.0)
	floor_collision.shape = floor_shape
	floor_collision.position.y = -0.1
	floor_body.add_child(floor_collision)

	# Soft patches of moss and leaf litter break up the flat ground color.
	for i in range(34):
		var patch := MeshInstance3D.new()
		var patch_mesh := SphereMesh.new()
		patch_mesh.radius = 1.0
		patch_mesh.height = 0.12
		patch.mesh = patch_mesh
		var patch_mat := StandardMaterial3D.new()
		patch_mat.albedo_color = [Color(0.21, 0.30, 0.13), Color(0.12, 0.22, 0.12), Color(0.25, 0.29, 0.15)][i % 3]
		patch_mat.roughness = 1.0
		patch.material_override = patch_mat
		patch.position = Vector3(sin(float(i) * 12.7) * 22.0, 0.015, cos(float(i) * 7.3) * 22.0)
		patch.scale = Vector3(1.5 + float(i % 4) * 0.35, 0.18, 1.0 + float(i % 3) * 0.4)
		add_child(patch)

	# Dense but spaced-out trees frame the play area and leave the starting
	# position and first wild encounter unobstructed.
	for grid_x in range(-7, 8, 2):
		for grid_z in range(-7, 8, 2):
			if abs(grid_x) <= 1 and abs(grid_z) <= 1:
				continue
			if (grid_x * 13 + grid_z * 7) % 3 != 0:
				continue
			var offset_x := sin(float(grid_x * 5 + grid_z)) * 1.0
			var offset_z := cos(float(grid_z * 4 - grid_x)) * 1.0
			var tree_pos := Vector3(float(grid_x) * 3.8 + offset_x, 0.0, float(grid_z) * 3.8 + offset_z)
			var tree_size := 2.4 + float(abs(grid_x * 3 + grid_z * 5) % 4) * 0.42
			var leaf_tint := [Color(0.13, 0.31, 0.18), Color(0.19, 0.39, 0.21), Color(0.24, 0.40, 0.19)][abs(grid_x + grid_z) % 3]
			_add_forest_tree(tree_pos, tree_size, leaf_tint)

	# Fallen logs, stones, and little glowing flowers add foreground detail.
	for i in range(18):
		var rock := MeshInstance3D.new()
		var rock_mesh := SphereMesh.new()
		rock_mesh.radius = 0.45 + float(i % 3) * 0.15
		rock_mesh.height = 0.55 + float(i % 2) * 0.15
		rock.mesh = rock_mesh
		var rock_mat := StandardMaterial3D.new()
		rock_mat.albedo_color = [Color(0.28, 0.31, 0.25), Color(0.36, 0.34, 0.27), Color(0.20, 0.28, 0.23)][i % 3]
		rock_mat.roughness = 1.0
		rock.material_override = rock_mat
		rock.position = Vector3(sin(float(i) * 8.1) * 15.0, 0.22, cos(float(i) * 5.4) * 15.0)
		rock.scale = Vector3(1.0, 0.65, 0.9)
		add_child(rock)

	for i in range(20):
		var flower := MeshInstance3D.new()
		var flower_mesh := SphereMesh.new()
		flower_mesh.radius = 0.11
		flower_mesh.height = 0.22
		flower.mesh = flower_mesh
		var flower_mat := StandardMaterial3D.new()
		flower_mat.albedo_color = [Color(0.86, 0.73, 0.34), Color(0.61, 0.78, 0.49), Color(0.65, 0.73, 0.88)][i % 3]
		flower_mat.emission_enabled = true
		flower_mat.emission = flower_mat.albedo_color * 0.12
		flower.material_override = flower_mat
		flower.position = Vector3(sin(float(i) * 6.7) * 10.0, 0.16, cos(float(i) * 4.9) * 10.0)
		add_child(flower)

func _add_forest_tree(tree_position: Vector3, tree_size: float, leaf_color: Color) -> void:
	var tree := Node3D.new()
	tree.name = "ForestTree"
	tree.position = tree_position
	add_child(tree)

	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.22 * tree_size / 3.0
	trunk_mesh.bottom_radius = 0.34 * tree_size / 3.0
	trunk_mesh.height = tree_size * 1.25
	trunk.mesh = trunk_mesh
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color(0.25, 0.16, 0.09)
	bark.roughness = 1.0
	trunk.material_override = bark
	trunk.position.y = trunk_mesh.height * 0.5
	tree.add_child(trunk)

	# Three overlapping crowns create a layered, stylized canopy.
	for layer_index in range(3):
		var crown := MeshInstance3D.new()
		var crown_mesh := SphereMesh.new()
		crown_mesh.radius = tree_size * (0.46 - float(layer_index) * 0.055)
		crown_mesh.height = tree_size * (0.78 - float(layer_index) * 0.06)
		crown.mesh = crown_mesh
		var foliage := StandardMaterial3D.new()
		foliage.albedo_color = leaf_color.darkened(float(layer_index) * 0.07)
		foliage.roughness = 1.0
		crown.material_override = foliage
		crown.position = Vector3(0.0, tree_size * (0.92 + float(layer_index) * 0.27), 0.0)
		tree.add_child(crown)

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
