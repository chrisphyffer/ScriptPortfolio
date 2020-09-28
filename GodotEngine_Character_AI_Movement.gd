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

extends Node

class_name Character_AI_Movement

var me : Spatial = null

var find_nearest_waypoint_behind : bool = false

var on_alert : bool = false
var sweep_for_player_in_range : bool = false

var chosen_attack : bool= false

var duration_search_for_target : float = 0.0


func _ready():
	
	me._AnimationTree["parameters/default_locomotion/blend_position"] = 0.0
	me._AnimationTree["parameters/battle_locomotion/blend_position"] = Vector2(0.0, 0.0)

	#$AnimationTree["parameters/Locomotion/blend_position"] = 1
	
	#me._Debug.echo('My hostility level is : ' + str(me.hostility_level))
	set_physics_process(false)


var random_ally_idle_follow_range = 2
var is_following_player = false
var follow_speed 
var point_near_player
var target_player_point_circle
var last_recorded_player_location

var TIME_TO_BEGIN_FOLLOWING_PLAYER = 2
var follow_player_timer = 0.0
func wait_to_check_ally_player_locations(delta:float):
	follow_player_timer += delta
	
	if follow_player_timer >= TIME_TO_BEGIN_FOLLOWING_PLAYER:
		stop_tracking_player = false
		follow_player_timer = 0.0

var stop_tracking_player = true
func follow_player(delta:float):
	
	#me._Debug.echo('FOLLOWING PLAYER.', true)
	is_following_player = true
	
	if not point_near_player:
		last_recorded_player_location = _GameManager.player.transform.origin
		point_near_player = choose_point_near_player()
	
	# If player not anywhere near where they were last recorded 
	var PA = (last_recorded_player_location - _GameManager.player.transform.origin)
	if PA.length() > random_ally_idle_follow_range - 1:
		last_recorded_player_location = _GameManager.player.transform.origin
		point_near_player = choose_point_near_player()
		follow_player_timer = 0.0
		stop_tracking_player = false
		
	_GameManager.ally_idle_positions[me.name] = point_near_player
	
	wait_to_check_ally_player_locations(delta)
	
	if stop_tracking_player: 
		return
		
	var points_invalid = true
	var poi = false
	while points_invalid:
		if not me._Controller._PathFinding.check_navigation_path(point_near_player):
			point_near_player = choose_point_near_player()
		else:
			poi = false
			for i in _GameManager.ally_idle_positions:
				if _GameManager.ally_idle_positions[i] == point_near_player \
					and str(i) != me.name:
						#print('POINT TAKEN.. : ', point_near_player)
						poi = true
						pass
			
			if poi:
				point_near_player = choose_point_near_player()
				#print('SO NEW POINT: ', point_near_player)
			else:
				points_invalid = false
		
	_GameManager.ally_idle_positions[me.name] = point_near_player
	#print(me.name, ' ----> ', point_near_player)

	PA = (point_near_player - me.transform.origin)
	
	if PA.length() <= 3:
		is_following_player = false
		#me._Debug.echo('I am within range of my Friend the player.', true)
		me._Controller._PathFinding.set_travel_speed(0, true)
	elif PA.length() <= random_ally_idle_follow_range + 3:
		me._Controller._PathFinding.set_navigation_path(point_near_player)
		me._Controller._PathFinding.set_travel_speed(1)
	else:
		me._Controller._PathFinding.set_navigation_path(point_near_player)
		me._Controller._PathFinding.set_travel_speed(2)
		
	stop_tracking_player = true

func choose_point_near_player(target_slice:int = -1):
	
	var final_point_near_player = Vector3()
	var slice
	
	var cx = _GameManager.player.transform.origin.x
	var cy = _GameManager.player.transform.origin.y
	
	slice = int(rand_range(0, 31))
	
	var x = cx + random_ally_idle_follow_range * cos(deg2rad(slice * 60))
	var y = cy + random_ally_idle_follow_range * sin(deg2rad(slice * 60))
	
	final_point_near_player = Vector3(x, y, _GameManager.player.transform.origin.z)
	
	#me._Debug.echo('SLICE CHOSEN: ' + str(slice))
	return final_point_near_player

func grab_random_waypoint():
	if me.waypoints.empty():
		me._Debug.echo('No waypoints specified in waypoints array.')
		return false
		
	me._Debug.echo(str(me.waypoints.size()) )

	var waypoint = me.waypoints[ int( round( rand_range( 0, me.waypoints.size() - 1 ) ) ) ].get_name(0)
	#find_node is slow...may remove later
	#print(me.waypoints[ int( round( rand_range( 0, me.waypoints.size() - 1 ) ) ) ].get_name(1))
	me._Debug.echo('Grabbing for waypoint: ' + str(waypoint))
	return get_tree().get_root().find_node(waypoint, true, false) 