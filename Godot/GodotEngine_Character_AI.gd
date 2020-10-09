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

######################
# Character_AI.gd
# THE BRAIN of the artificial intelligence, handled by _physics_process

extends Node

class_name Character_AI

var me : Spatial = null

var _Movement
var _Battle
var _PathFinding

func _ready():

	_Movement = load("res://Gameplay/Characters/Character_AI_Movement.gd").new()
	_Movement.name = 'CharacterAIMovementScript'
	_Movement.me = me
	add_child(_Movement)

	_Battle = load("res://Gameplay/Characters/Character_AI_Battle.gd").new()
	_Battle.name = 'CharacterAIBattleScript'
	_Battle.me = me
	add_child(_Battle)

	_PathFinding = load("res://Gameplay/Characters/Character_PathFinding.gd").new()
	_PathFinding.name = 'CharacterMovementPathFinding'
	_PathFinding.me = me
	add_child(_PathFinding)

	_Movement.set_physics_process(true)
	_Battle.set_physics_process(true)
	_PathFinding.set_physics_process(true)


# THE BRAIN
func _physics_process(delta):
#	if me._Controller._Battle.is_attacking:
#		me._Debug.echo('I am attacking', true)
#	
#	if _PathFinding.path_fail:
#		me._Debug.echo('I AM EXPERIENCING A PATH FAILURE.')
#		_PathFinding.process_movement = false
#		return
#	
#	if me.hostility_level == me.HOSTILITY_LEVELS.HUNTER:
#		
#		if me._Awareness.i_can_see_the_character:
#			do_battle()
#			duration_search_for_target = 0
#		
#		# Character is here somewhere...
#		if _Battle.engaged and me._Awareness.target_character and not me._Awareness.i_can_see_the_character:
#			#me._Debug.echo('This character must be behind me, around my field of vision..', true)
#			# Travel to whether (the character was) - a stop distance. This way, they can go
#			# around a wall to see if the character is still there.
#			duration_search_for_target += delta
#			
#		elif _Battle.engaged and not me._Awareness.target_character:
#			#me._Debug.echo('This character is far, so I must be on alert...', true)
#			on_alert = true
#			duration_search_for_target += delta
#	
#	if duration_search_for_target >= me.time_to_search_for_target:
#		#me._Debug.echo('I am done trying to find target, going back to normal routine.')
#		battle_mode = false
#		duration_search_for_target = 0.0
#	
	if me.patrol_waypoints and not _Battle.engaged:
		me._Debug.echo('On Patrol Now...', true)
		if _PathFinding.navigation_path.empty():
			me._Debug.echo('Patrolling Navigation Path')
			var waypoint = _Movement.grab_random_waypoint()
	
			if not waypoint:
				me._Debug.echo('Not a real waypoint: ' + str(waypoint))
				_PathFinding.process_movement = false
				return
			
			if _PathFinding.set_navigation_path( waypoint.get_translation() ):
				_PathFinding.set_travel_speed(1.0)
				_PathFinding.process_movement = true
			else:
				_PathFinding.process_movement = false
				return
				# Try again, otherwise, just idle this pawn.
	
			me.remaining_access_time = me.DESTINATION_ACCESS_TIME

	if me.hostility_level == me.HOSTILITY_LEVELS.ALLY and not _Battle.engaged:
		_Movement.follow_player(delta)
		
	if me.hostility_level == me.HOSTILITY_LEVELS.ALLY_PREY and not _Battle.engaged:
		_Movement.follow_player(delta)