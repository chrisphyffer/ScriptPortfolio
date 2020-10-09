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
# This file handles movement of the character across a 
# Navigation Mesh, should be called CharacterNavMeshMovement

extends Node

class_name CharacterMovementPathFinding

export(float) var travel_acceleration = 2
export(float) var travel_deceleration = 2

var travel_speed = 0
var travel_speed_deadzone = .01
var clear_navigation_when_zero_travel_speed = false

var navigation_path:Array = []

export var ACCEPTABLE_PATH_DISTANCE:float = .5

export(float) var rotation_speed = 1.0
var accumulated_rotation = 0
var arrived_at_position = false
var rotated_to_position = false
var orientation = Transform()
var velocity = Vector3()
const GRAVITY = Vector3(0,-9.8, 0)

const PATH_FAIL_MAX = 3

var path_fail : bool = false

var me : Character


var process_movement : bool = true

func _ready():
	
	# Set Initial Movement.
	orientation = me.global_transform
	#orientation.basis = Basis().rotated(Vector3.UP, deg2rad(180))
	orientation.origin = Vector3()

	print('Initializing Orientation for ' , me.name, ' ', str(orientation))
	set_physics_process(false)

func _physics_process(delta):
	
	if _GameManager.gameplay_type == _GameManager.GAMEPLAY_TYPE.POINT_AND_CLICK or _GameManager.player != me:
		_process_movement(delta)
		interp_travel_speed(delta)

func set_travel_speed(speed:float, clear_navigation_when_finished:bool = false):
	travel_speed = speed
	clear_navigation_when_zero_travel_speed = clear_navigation_when_finished

func interp_travel_speed(delta:float):
	var current_speed = me.get_node('AnimationTree')["parameters/default_locomotion/blend_position"]
	var deadzone_met = false
	
	if (current_speed + travel_speed_deadzone) < travel_speed:
		current_speed += delta * travel_acceleration
	elif (current_speed - travel_speed_deadzone) > travel_speed:
		current_speed -= delta * travel_deceleration 
	else:
		deadzone_met = true
	
	if deadzone_met: 
		if travel_speed == 0 and clear_navigation_when_zero_travel_speed:
			clear_navigation_path()
			clear_navigation_when_zero_travel_speed = false
		me.get_node('AnimationTree')["parameters/default_locomotion/blend_position"] = travel_speed
	else:
		me.get_node('AnimationTree')["parameters/default_locomotion/blend_position"] = current_speed
	
	

func is_moving():
	if navigation_path:
		return true
	else:
		return false


func _process_movement(delta):
	
	if not process_movement:
		return

	if typeof(navigation_path) != TYPE_ARRAY or navigation_path.empty():
		me._Debug.echo('Navigation Path is not valid type or empty...')
		me.get_node('AnimationTree')["parameters/default_locomotion/blend_position"] = 0
		return

	#me.get_node('AnimationTree')["parameters/Locomotion/blend_position"] = locomotion_speed
	me.get_node('AnimationTree')["parameters/LocomotionTimeScale/scale"] = me.default_locomotion_speed

	if me.global_transform.origin.distance_to(navigation_path[0]) < ACCEPTABLE_PATH_DISTANCE:
		accumulated_rotation = 0
		navigation_path.remove(0)

		if navigation_path.empty():
			me._Debug.do_debug_draw_path(true)
			return

	var t = me.transform
	navigation_path[0].y = t.origin.y


	# looking_at points -z towards target...
	## https://answers.unity.com/questions/132592/lookat-in-opposite-direction.html
	var rotTransform = t.looking_at(2 * me.global_transform.origin - navigation_path[0], Vector3.UP)

	var thisRotation = Quat(t.basis).slerp( rotTransform.basis, clamp(accumulated_rotation, 0, 1) )

	accumulated_rotation += delta * rotation_speed

	if accumulated_rotation > 1:
		accumulated_rotation = 1

	if not rotated_to_position:
		orientation.basis = Transform(thisRotation, t.origin).basis

	orientation.basis = Transform(rotTransform.basis, t.origin).basis

	var root_motion = me.get_node('AnimationTree').get_root_motion_transform()

	# apply root motion to orientation
	orientation *= root_motion # Push this character forward.

	var h_velocity = orientation.origin / delta
	velocity.x = h_velocity.x # NEGATIVES DUE TO FLIPPED Z FRONT...
	velocity.z = h_velocity.z # NEGATIVES DUE TO FLIPPED Z FRONT...
	velocity += GRAVITY * delta
	velocity = me.move_and_slide(velocity, Vector3(0,1,0))

	orientation.origin = Vector3() #clear accumulated root motion displacement (was applied to speed)
	orientation = orientation.orthonormalized() # orthonormalize orientation

	me.global_transform.basis = orientation.basis

	pass





func set_navigation_path(end: Vector3):
	var _paths = me.navLevel.generate_path(me, end)
	if typeof(_paths) == TYPE_ARRAY and not _paths.empty():
		
		navigation_path = _paths
		me._Debug.echo('I have generated a path to : ' + str(end), true)
		me._Debug.do_debug_draw_path()
		return true
	
	me._Debug.echo('I cannot generate a path to : ' + str(end), true)
	path_fail = true
	return false
	
func check_navigation_path(end: Vector3):
	var _paths = me.navLevel.generate_path(me, end)
	if typeof(_paths) != TYPE_ARRAY or _paths.empty():
		return false
		
	return true

func clear_navigation_path():
	navigation_path = []