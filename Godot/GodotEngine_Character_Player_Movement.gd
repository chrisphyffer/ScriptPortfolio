"""
Sample Character Operation Scripts for Godot Engine 3.2
Christopher Phyffer 2020
https://phyffer.com

These sets of scripts (starting with the Base class `Character.gd`) allows any 
Character to be controlled by a Player, or controlled by AI and therefore
make appropriate decisions. Each character has the ability to Attack, Defend, and Manuever.

The purpose of these sets of Scripts is to allow the player to inhabit any character in their party, similar
to the gameplay of Mass Effect and Dragon Age. 

I found the gameplay conventions of Unreal to make good sense, in terms of:
A.) The `Character Controller` (UE) is assigned to all characters and can be driven by Player or AI.
B.) Each Character can be considered UE's equivalent of a `Pawn`.
C.) A Player can take control of a pawn, UE's equivalent of `Possess`.

The AI can interact with the player from a distance using a navigation mesh agent, walking over to them.

The AI developed in these scripts have the ability to do the following:
A.) Patrol to a set of Waypoints developed by the Level or Gameplay Designer
B.) Their Behavior is based on a `HOSTILITY_LEVEL` enum: Whether they are NPC, Neutral, Hostile, Active Prey
C.) If an AI Hostility level is HUNTER, they will attack player given their `field_of_view` and pursue the player so far as they can see or `sense` them.
D.) If an AI is DEFENSIVE, it will attack the player until no longer bothered.
E.) If an AI is ALLY, they will protect you. 
"""

#########################
# CharacterMovement.gd 
# Should be appropriately named CharacterPlayerMovement, this
# script handles applies the player's input to the Character's 
# movement.

extends Node

class_name Character_Player_Movement

var me

################
# MOVEMENT

var is_sprinting = false
var root_motion = Transform()
var velocity = Vector3()
const GRAVITY = Vector3(0,-9.8, 0)

var orientation = Transform()
var motion = Vector2()
const MOTION_INTERPOLATE_SPEED = 10
const ROTATION_INTERPOLATE_SPEED = 10

func _ready():

	#orientation = me._CharacterBase.global_transform
	orientation = me.global_transform
	orientation.origin = Vector3()

	#	set_physics_process(true)
	#else:
	set_physics_process(false)
			

func _input(event):
	pass
	
	# Point and Click Adventure!
	#if _GameManager.gameplay_type == _GameManager.GAMEPLAY_TYPE.POINT_AND_CLICK:
	#	if (event.is_class("InputEventMouseButton") and event.button_index == BUTTON_LEFT and event.pressed):
	#		var from = _CameraManager.activeCamera.project_ray_origin(event.position)
	#		var to = from + _CameraManager.activeCamera.project_ray_normal(event.position)*100
	#		var end = me.navLevel.get_closest_point_to_segment(from, to)
	#		
	#		if me.set_navigation_path(end):
	#			me._Controller._PathFinding.set_travel_speed(me.default_locomotion_speed)
			
func _physics_process(delta):
	process_movement(delta)

	#if not me._Controller._PathFinding.navigation_path:
	#	me._Controller._PathFinding.set_travel_speed(0)


# Process movement utilizing the Kinematic Character's Root Motion
# 1.) Gather Input from player
# 2.) Set the appropriate animation tree properties
# 3.) If a user performs an action like a dodge or a jump, then
#     perform that action and calculate it into the root motion as well.

func process_movement(delta):
	
	if me.lock_character_movement:
		me._AnimationTree["parameters/battle_locomotion/blend_position"] = Vector2.ZERO
		me._AnimationTree["parameters/default_locomotion/blend_position"] = Vector2.ZERO
		return false
		
	var motion_target = Vector2( 	Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
									Input.get_action_strength("move_forward") - Input.get_action_strength("move_back") )

	motion = motion.linear_interpolate(motion_target, MOTION_INTERPOLATE_SPEED * delta)

	var q_from = Quat(orientation.basis)
	var q_to = Quat()
	
	# Change locomotion to Fighting Stance
	if me._Controller._Battle.in_battle_mode:
		
		# Send Root Motion Data into the Blendspace 2D
		me._AnimationTree["parameters/movement_state/current"] = 0
		#me._CharacterBase.get_node('AnimationPlayer').playback_speed=4
		
		me._AnimationTree["parameters/battle_locomotion/blend_position"]=motion

		if Input.is_action_pressed("dodge"):
			pass
		
		if me._Controller._Battle.target_opponent:
			
			me._AnimationTree["parameters/LocomotionTimeScale/scale"] = 1.5
			
			var planet : Spatial = me
			var sun = me._Controller._Battle.target_opponent
			
			
			var target = sun.global_transform.origin
			target.y = me.global_transform.origin.y
			
			# https://answers.unity.com/questions/132592/lookat-in-opposite-direction.html
			# Horrible...
			q_to = Quat(me.global_transform.looking_at(\
				(2 * me.global_transform.origin - target),\
				 Vector3.UP).basis)
				
			#https://godotengine.org/qa/34248/rotate-around-a-fixed-point-in-3d-space
			var q_camera_to = Quat(me.global_transform.looking_at(\
				(2 * me.global_transform.origin - sun.global_transform.origin),\
				 Vector3.UP).basis)
			
			if me.global_transform.origin.distance_to(target) > 2:
				orientation.basis = Basis(q_from.slerp(q_to, delta*ROTATION_INTERPOLATE_SPEED))
				var camera_basis = Basis(q_from.slerp(q_camera_to, delta*ROTATION_INTERPOLATE_SPEED))
			
				_CameraManager.rotation.y = camera_basis.get_euler().y
				_CameraManager.rotation.x = camera_basis.get_euler().x

			_GameManager.set_target_opponent_engaged(sun)

		else:
			# Get Wherever the Camera is looking (global_transform.basis)
			q_to = Quat( _CameraManager.global_transform.basis )
		
			# interpolate current rotation to desired rotation
			orientation.basis = Basis(q_from.slerp(q_to, delta*ROTATION_INTERPOLATE_SPEED))

			_GameManager.unset_target_opponent_engaged()
			pass


	elif not me._Controller._Battle.in_battle_mode:
		# Get the Camera's Rotation
		# Z IS REVERSED IN GODOT.
		var cam_z = - _CameraManager.activeCamera.global_transform.basis.z
		var cam_x = _CameraManager.activeCamera.global_transform.basis.x
	
		cam_z.y=0
		cam_z = cam_z.normalized()
		cam_x.y=0
		cam_x = cam_x.normalized()
		
		# Set movement state to the default_locomotion
		me._AnimationTree["parameters/movement_state/current"] = 1

		var motion_length = motion.length()

		is_sprinting = Input.is_action_pressed("run")

		if is_sprinting:
			motion_length *= 2
			
		me._CharacterBase.get_node('AnimationPlayer').playback_speed=4
		me._AnimationTree["parameters/default_locomotion/blend_position"] = motion_length
		me._AnimationTree["parameters/LocomotionTimeScale/scale"] = me.default_locomotion_speed
		
		# SMOOTHLY LERP ROTATE FROM ONE QUATERNION TO ANOTHER:
		# ROTATES CHARACTER TO THE CAMERA.
		var target = - cam_x * motion.x -  cam_z * motion.y
		if (target.length() > 0.001):
			q_to = Quat(Transform().looking_at(target,Vector3(0,1,0)).basis)

		_GameManager.unset_target_opponent_engaged()

	# interpolate current rotation with desired one
	orientation.basis = Basis(q_from.slerp(q_to,delta*ROTATION_INTERPOLATE_SPEED))
		
	#######################
	# Character movement processing.

	# get root motion transform
	root_motion = me._AnimationTree.get_root_motion_transform()

	# apply root motion to orientation
	orientation *= root_motion

	var h_velocity = orientation.origin / delta
	velocity.x = h_velocity.x
	velocity.z = h_velocity.z
	velocity += GRAVITY * delta
	velocity = me.move_and_slide(velocity,Vector3(0,1,0))

	orientation.origin = Vector3() #clear accumulated root motion displacement (was applied to speed)
	# orthonormalize orientation, make sure it's orthogonal to normal.
	orientation = orientation.orthonormalized()

	# Basis stores the rotation and scale of a spatial.
	#me._CharacterBase.global_transform.basis = orientation.basis
	me.global_transform.basis = orientation.basis