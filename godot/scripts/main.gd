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
var camera_yaw := 0.785398
var camera_pitch := 0.68
var camera_distance := 15.0
var rotating_camera := false
var quest_stage := 0
var quest_kills := 0
var quest_reward_claimed := false
var bits := 0
var town_npcs: Array[Node3D] = []

func _ready() -> void:
	_setup_input()
	_build_world()
	_build_town()
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
		var horizontal := camera_distance * cos(camera_pitch)
		var camera_offset := Vector3(sin(camera_yaw) * horizontal, camera_distance * sin(camera_pitch), cos(camera_yaw) * horizontal)
		camera.global_position = camera.global_position.lerp(target + camera_offset, minf(1.0, delta * 7.0))
		camera.look_at(target + Vector3(0.0, 1.0, 0.0), Vector3.UP)
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
	# Derive movement axes from the current orbit-camera yaw, so WASD never
	# changes meaning when the player rotates the camera.
	var forward := Vector3(-sin(camera_yaw), 0.0, -cos(camera_yaw)).normalized()
	var right := Vector3(cos(camera_yaw), 0.0, -sin(camera_yaw)).normalized()
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
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_RIGHT:
			rotating_camera = mouse_button.pressed
			if rotating_camera:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_viewport().set_input_as_handled()
			return
		if mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance = maxf(7.0, camera_distance - 1.2)
			get_viewport().set_input_as_handled()
			return
		if mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = minf(26.0, camera_distance + 1.2)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion and rotating_camera:
		var motion := event as InputEventMouseMotion
		camera_yaw -= motion.relative.x * 0.006
		camera_pitch = clampf(camera_pitch + motion.relative.y * 0.004, 0.22, 1.18)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact"):
		_interact_with_nearest_npc()
	elif event.is_action_pressed("catch_monster"):
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
	_add_key_action("interact", KEY_F)
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
			if abs(tree_pos.x) < 12.0 and tree_pos.z < -7.0 and tree_pos.z > -27.0:
				continue
			var tree_size := 2.4 + float(abs(grid_x * 3 + grid_z * 5) % 4) * 0.42
			var leaf_tint: Color = [Color(0.13, 0.31, 0.18), Color(0.19, 0.39, 0.21), Color(0.24, 0.40, 0.19)][abs(grid_x + grid_z) % 3]
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
	shape.radius = 0.34
	shape.height = 1.75
	collision.shape = shape
	collision.position.y = 0.88
	player.add_child(collision)
	# Stylized adventurer model: tunic, belt, trousers, boots, arms, face and hair.
	_add_box_part(player, "Tunic", Vector3(0.62, 0.68, 0.36), Vector3(0.0, 1.08, 0.0), Color(0.18, 0.36, 0.72))
	_add_box_part(player, "ShoulderCape", Vector3(0.78, 0.20, 0.42), Vector3(0.0, 1.36, 0.03), Color(0.28, 0.58, 0.82))
	_add_box_part(player, "Belt", Vector3(0.64, 0.11, 0.39), Vector3(0.0, 0.83, -0.01), Color(0.30, 0.17, 0.08))
	_add_box_part(player, "Trousers", Vector3(0.48, 0.42, 0.31), Vector3(0.0, 0.53, 0.0), Color(0.16, 0.20, 0.29))
	_add_box_part(player, "LeftBoot", Vector3(0.23, 0.18, 0.34), Vector3(-0.16, 0.12, -0.05), Color(0.12, 0.09, 0.07))
	_add_box_part(player, "RightBoot", Vector3(0.23, 0.18, 0.34), Vector3(0.16, 0.12, -0.05), Color(0.12, 0.09, 0.07))
	_add_box_part(player, "LeftArm", Vector3(0.19, 0.56, 0.22), Vector3(-0.42, 1.04, 0.0), Color(0.87, 0.64, 0.43))
	_add_box_part(player, "RightArm", Vector3(0.19, 0.56, 0.22), Vector3(0.42, 1.04, 0.0), Color(0.87, 0.64, 0.43))
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.25
	head_mesh.height = 0.48
	head.mesh = head_mesh
	head.position = Vector3(0.0, 1.67, 0.0)
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.91, 0.70, 0.49)
	head.material_override = skin
	player.add_child(head)
	var hair := MeshInstance3D.new()
	var hair_mesh := SphereMesh.new()
	hair_mesh.radius = 0.265
	hair_mesh.height = 0.28
	hair.mesh = hair_mesh
	hair.position = Vector3(0.0, 1.84, 0.025)
	var hair_mat := StandardMaterial3D.new()
	hair_mat.albedo_color = Color(0.20, 0.12, 0.08)
	hair.material_override = hair_mat
	player.add_child(hair)
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.025, 0.02, 0.015)
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.035
		eye_mesh.height = 0.06
		eye.mesh = eye_mesh
		eye.material_override = eye_mat
		eye.position = Vector3(side * 0.085, 1.68, -0.225)
		player.add_child(eye)
	_add_box_part(player, "Backpack", Vector3(0.32, 0.40, 0.18), Vector3(0.0, 1.03, 0.25), Color(0.47, 0.25, 0.10))
	player.position = Vector3.ZERO

func _add_box_part(parent: Node3D, part_name: String, dimensions: Vector3, part_position: Vector3, tint: Color) -> void:
	var part := MeshInstance3D.new()
	part.name = part_name
	var part_mesh := BoxMesh.new()
	part_mesh.size = dimensions
	part.mesh = part_mesh
	var part_material := StandardMaterial3D.new()
	part_material.albedo_color = tint
	part_material.roughness = 0.8
	part.material_override = part_material
	part.position = part_position
	parent.add_child(part)

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
	camera.name = "OrbitCamera"
	camera.fov = 48.0
	add_child(camera)
	camera.current = true
	var target := player.global_position if is_instance_valid(player) else Vector3.ZERO
	var horizontal := camera_distance * cos(camera_pitch)
	camera.global_position = target + Vector3(sin(camera_yaw) * horizontal, camera_distance * sin(camera_pitch), cos(camera_yaw) * horizontal)
	camera.look_at(target + Vector3(0.0, 1.0, 0.0), Vector3.UP)

func _build_town() -> void:
	# A small welcoming settlement at the edge of the forest.
	var plaza := MeshInstance3D.new()
	plaza.name = "TownPlaza"
	var plaza_mesh := CylinderMesh.new()
	plaza_mesh.top_radius = 8.0
	plaza_mesh.bottom_radius = 8.0
	plaza_mesh.height = 0.12
	plaza.mesh = plaza_mesh
	var plaza_mat := StandardMaterial3D.new()
	plaza_mat.albedo_color = Color(0.38, 0.39, 0.31)
	plaza_mat.roughness = 1.0
	plaza.material_override = plaza_mat
	plaza.position = Vector3(0.0, 0.03, -17.0)
	add_child(plaza)
	for i in range(12):
		var tile := MeshInstance3D.new()
		var tile_mesh := BoxMesh.new()
		tile_mesh.size = Vector3(1.25, 0.08, 1.25)
		tile.mesh = tile_mesh
		var tile_mat := StandardMaterial3D.new()
		tile_mat.albedo_color = Color(0.49, 0.47, 0.37) if i % 2 == 0 else Color(0.43, 0.43, 0.35)
		tile.material_override = tile_mat
		tile.position = Vector3(-3.3 + float(i % 4) * 2.2, 0.12, -14.0 - float(i / 4) * 2.2)
		add_child(tile)
	_add_town_house("ElderHall", Vector3(-7.0, 0.0, -21.0), Color(0.68, 0.48, 0.28), Color(0.36, 0.16, 0.12), 1.25)
	_add_town_house("Smithy", Vector3(7.0, 0.0, -21.0), Color(0.48, 0.45, 0.39), Color(0.25, 0.28, 0.31), 1.0)
	_add_town_house("Inn", Vector3(0.0, 0.0, -26.0), Color(0.72, 0.57, 0.35), Color(0.46, 0.20, 0.16), 1.0)
	_add_npc("Elder Rowan", Vector3(-2.8, 0.0, -14.5), Color(0.60, 0.26, 0.68), "Quest Giver")
	_add_npc("Mira the Smith", Vector3(3.0, 0.0, -14.5), Color(0.38, 0.42, 0.48), "Blacksmith")
	_add_npc("Tavi the Guide", Vector3(0.0, 0.0, -19.5), Color(0.20, 0.58, 0.40), "Town Guide")
	# Quest board with a bright marker.
	_add_box_part(self, "QuestBoard", Vector3(1.0, 1.35, 0.16), Vector3(0.0, 1.0, -12.0), Color(0.34, 0.20, 0.10))
	_add_box_part(self, "QuestBoardHeader", Vector3(1.18, 0.18, 0.20), Vector3(0.0, 1.72, -12.0), Color(0.88, 0.68, 0.24))

func _add_town_house(house_name: String, house_pos: Vector3, wall_color: Color, roof_color: Color, size_scale: float) -> void:
	var house := Node3D.new()
	house.name = house_name
	house.position = house_pos
	house.scale = Vector3.ONE * size_scale
	add_child(house)
	_add_box_part(house, "Walls", Vector3(4.0, 2.6, 3.2), Vector3(0.0, 1.3, 0.0), wall_color)
	_add_box_part(house, "RoofLeft", Vector3(2.5, 0.18, 4.0), Vector3(-0.95, 2.85, 0.0), roof_color)
	house.get_node("RoofLeft").rotation.z = -0.48
	_add_box_part(house, "RoofRight", Vector3(2.5, 0.18, 4.0), Vector3(0.95, 2.85, 0.0), roof_color)
	house.get_node("RoofRight").rotation.z = 0.48
	_add_box_part(house, "Door", Vector3(0.8, 1.55, 0.12), Vector3(0.0, 0.78, -1.67), Color(0.22, 0.12, 0.07))
	_add_box_part(house, "WindowLeft", Vector3(0.58, 0.55, 0.08), Vector3(-1.25, 1.55, -1.66), Color(0.35, 0.76, 0.85))
	_add_box_part(house, "WindowRight", Vector3(0.58, 0.55, 0.08), Vector3(1.25, 1.55, -1.66), Color(0.35, 0.76, 0.85))

func _add_npc(npc_name: String, npc_pos: Vector3, clothing_color: Color, role_text: String) -> void:
	var npc := Node3D.new()
	npc.name = npc_name.replace(" ", "")
	npc.position = npc_pos
	add_child(npc)
	_add_box_part(npc, "Body", Vector3(0.58, 0.72, 0.36), Vector3(0.0, 1.0, 0.0), clothing_color)
	_add_box_part(npc, "Arms", Vector3(0.78, 0.18, 0.22), Vector3(0.0, 1.15, 0.0), clothing_color.lightened(0.1))
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.24
	head_mesh.height = 0.46
	head.mesh = head_mesh
	head.position.y = 1.62
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.88, 0.67, 0.48)
	head.material_override = skin
	npc.add_child(head)
	var hat := MeshInstance3D.new()
	var hat_mesh := CylinderMesh.new()
	hat_mesh.top_radius = 0.12
	hat_mesh.bottom_radius = 0.32
	hat_mesh.height = 0.18
	hat.mesh = hat_mesh
	hat.position.y = 1.89
	var hat_mat := StandardMaterial3D.new()
	hat_mat.albedo_color = clothing_color.darkened(0.25)
	hat.material_override = hat_mat
	npc.add_child(hat)
	var tag := Label3D.new()
	tag.text = npc_name + "\n" + role_text
	tag.position = Vector3(0.0, 2.35, 0.0)
	tag.font_size = 32
	tag.outline_size = 8
	tag.modulate = Color(1.0, 0.92, 0.65)
	npc.add_child(tag)
	town_npcs.append(npc)

func _interact_with_nearest_npc() -> void:
	var nearest: Node3D = null
	var nearest_distance := 999.0
	for npc in town_npcs:
		if not is_instance_valid(npc):
			continue
		var distance := player.global_position.distance_to(npc.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = npc
	if nearest == null or nearest_distance > 3.6:
		_show_message("No one nearby. Visit the town plaza north of the forest.")
		return
	match nearest.name:
		"ElderRowan":
			if quest_stage == 0:
				quest_stage = 1
				quest_kills = 0
				_show_message("Elder Rowan: Defeat 3 wild Cinderlings to protect our town. Quest accepted!")
			elif quest_stage == 1 and quest_kills < 3:
				_show_message("Elder Rowan: The forest is still dangerous. Cinderlings defeated: %d/3." % quest_kills)
			elif quest_stage == 1:
				quest_stage = 2
				bits += 100
				monster_xp += 60
				while monster_xp >= XP_TO_LEVEL:
					monster_xp -= XP_TO_LEVEL
					monster_level += 1
				_show_message("Quest complete! +60 EXP and +100 bits. Elder Rowan thanks you.")
			else:
				_show_message("Elder Rowan: You are a hero of Veldara. More quests are coming soon.")
		"MiratheSmith":
			_show_message("Mira: Bring me stronger monster cores later. For now, practice combat and explore.")
		_:
			_show_message("Tavi: Follow the stone path north to the town. Press F near villagers to talk.")
	_update_hud()

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var top_panel := PanelContainer.new()
	top_panel.anchor_left = 0.015
	top_panel.anchor_top = 0.02
	top_panel.anchor_right = 0.34
	top_panel.anchor_bottom = 0.22
	layer.add_child(top_panel)
	var column := VBoxContainer.new()
	top_panel.add_child(column)
	hud_label = Label.new()
	hud_label.add_theme_font_size_override("font_size", 17)
	column.add_child(hud_label)
	var controls := Label.new()
	controls.text = "WASD Move | Space/Click Attack | E Catch | V Evolve | F Talk\nRight-click drag: Rotate camera | Mouse wheel: Zoom"
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_theme_font_size_override("font_size", 12)
	column.add_child(controls)
	var fullscreen_button := Button.new()
	fullscreen_button.text = "⛶ Fullscreen"
	fullscreen_button.custom_minimum_size = Vector2(140.0, 38.0)
	fullscreen_button.anchor_left = 1.0
	fullscreen_button.anchor_right = 1.0
	fullscreen_button.offset_left = -160.0
	fullscreen_button.offset_right = -18.0
	fullscreen_button.offset_top = 18.0
	fullscreen_button.offset_bottom = 58.0
	fullscreen_button.pressed.connect(_toggle_fullscreen)
	layer.add_child(fullscreen_button)
	message_label = Label.new()
	message_label.anchor_left = 0.12
	message_label.anchor_right = 0.88
	message_label.anchor_top = 0.78
	message_label.anchor_bottom = 0.91
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 21)
	message_label.add_theme_color_override("font_color", Color(1.0, 0.91, 0.62))
	layer.add_child(message_label)

func _toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

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
		if quest_stage == 1:
			quest_kills += 1
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
	var quest_text := "Quest: Speak to Elder Rowan (F)" if quest_stage == 0 else ("Quest: Defeat Cinderlings %d/3" % quest_kills if quest_stage == 1 else "Quest: Cinderling Hunt complete")
	hud_label.text = "VELDARA  •  FOREST FRONTIER\nCompanion: %s\n%s\n%s\n%s\nBits: %d" % [state, level_text, enemy_text, quest_text, bits]
