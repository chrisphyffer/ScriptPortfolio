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

class_name Character_AI_Battle

var me

var engaged

func _ready():
	set_physics_process(false)
	pass

func _physics_process(delta):
	pass

var is_charging = false
func do_battle():
	
	#me._Debug.echo('Engaging In Battle..', true)
	me._battle.engaged = true
	
	if me._Controller._Battle.is_attacking:
		return
	
	# Character Personality
	# What attacks the character prefers
	# 1.) Is this character more of a ranged person
	# 2.) Does this character have a target character who's personality
	#     this character can exploit?
	#var chosen_attack = false
	#for p in range(possible_attacks.size()):
	#	if possible_attacks[p].attack_type == 'ranged':
	#		pass
	
	# Choose a random attack, ask programmer for probability formula
	#var sum_chance = 0.0
	#var chance_ratio = 0.0
	#for i in range(possible_attacks.size()):
	#	sum_chance += possible_attacks[i].chance
	#	chance_ratio = sum_chance / 100
	
	if not chosen_attack:
		chosen_attack = choose_attack()
		
	if not chosen_attack:
		#me._Debug.echo("I can't attack this character. !Roar of frustration!...", true)
		return

	if chosen_attack.attack_type == Attack.ATTACK_TYPE.RANGED:
		# Stay where you are. Play whatever animation is specified
		# play(me.attack_list[i].animation)
		# Let the animation call the necessary particle fx and character specific functions.
		
		#me._Debug.echo('I choose a ranged Attack: ' + str(chosen_attack), true)
		me.clear_navigation_path()
		me._MOVEMENT.set_travel_speed(0)
		attack()
		
	elif chosen_attack.attack_type == Attack.ATTACK_TYPE.FRONTAL_ASSAULT:
		#me._Debug.echo('I choose a Frontal Attack: ' + str(chosen_attack), true)
		
		charge_to_attack()
		
		# Am I within Striking Distance?
		if not is_charging:
			attack()


# Get within Striking Distance, Run into player to attack!
func charge_to_attack():
	is_charging = true
	
	var target_location = me._Awareness.target_character.transform.origin
	var PA = (target_location - me.transform.origin)
	
	# When I reach this character's destination, fuk him up.
	#if vec_dist_for_anim <= chosen_attack.min_distance:
	if PA.length() <= chosen_attack.striking_distance:
		#me._Debug.echo('I am within distance to attack this character.', true)
		me.clear_navigation_path()
		me._MOVEMENT.set_travel_speed(0)
		is_charging = false
	else:
		#me._MOVEMENT.navigation_path[me._MOVEMENT.navigation_path.size()-1] = vec_dist_for_anim
		me.set_navigation_path(target_location)
		me._MOVEMENT.set_travel_speed(chosen_attack.travel_speed)
		#me._Debug.echo('I ('+str(round(PA.length()))+') must meet the minimum distance of ('+str(chosen_attack.min_distance)+') to attack this character.', true)
		#me._Debug.echo('I '+str(me.transform.origin)+' @ ('+str(PA.length())+')must meet the minimum distance of ('+str(chosen_attack.min_distance)+') to attack this character ' + str(target_location), true)



func choose_attack():
	
	#me._Debug.echo('Choosing an appropriate attack.', true)
	
	# Figure out what kind of attack to perform.
	# Grab the distance that the attack may affect. for example, if my arm reach
	# to punch the character's origin is 2.0, then subtract 2.0 from the magnitude
	# of the vector that arrives at the character's origin.
	
	# Factors that determine usable attacks:
	# 1.) How far is the player? (Not necessary if this player is a melee player)
	# 2.) How much health do I have left?
	# 3.) Is the player behind me? Must I do a tornado? An instant teleport?
	#     run toward the character based on hearing and intuition?
	var possible_attacks = []
	var rules_failed = {}
	var target_pos = me._Awareness.target_character.transform.origin

	for attack in me.attack_list:
		var rules =  attack.rules
		var all_rules_met = true
		
		if not rules_failed.get(attack.name):
			rules_failed[attack.name] = Array()
			pass
		
		for rule in rules:
			if rule['name'] == 'distance':
				if rule['less_than'] and not \
					target_pos.distance_to(me.transform.origin) < rule['distance']:
						rules_failed[attack.name].append(\
							str(target_pos.distance_to(me.transform.origin)) + ' distance less_than ' + str(rule['distance']) )
						all_rules_met = false
						break
				if rule['greater_than'] and not \
					target_pos.distance_to(me.transform.origin) > rule['distance']:
						rules_failed[attack.name].append(\
							str(target_pos.distance_to(me.transform.origin)) + ' distance greater_than ' + str(rule['distance']) )
						all_rules_met = false
						break
			
			if rule['name'] == 'character_out_of_fov' and me._Awareness.i_can_see_the_character:
				rules_failed[attack.name].append(rule['name'])
				all_rules_met = false
				break
				
			if rule['name'] == 'character_in_fov' and not me._Awareness.i_can_see_the_character:
				rules_failed[attack.name].append(rule['name'])
				all_rules_met = false
				break
			
			if rule['name'] == 'max_health' and me.health > rule['at_health']:
				rules_failed[attack.name].append(rule['name'])
				all_rules_met = false
				break
			
		if all_rules_met:
			possible_attacks.append(attack)
	
	if not possible_attacks.empty():
		#me._Debug.echo('I have '+str(possible_attacks.size())+' attacks available to use.', true)
		
		var attacks_from_strategy = []
		for attack in possible_attacks:
			#me._Debug.echo('ATTACK STRATEGY: ' + str(attack.attack_type) + ' ' + str(attack.ATTACK_TYPE.RANGED))
			#me._Debug.echo('BATTLE POSITION: ' + str(me.battle_position) + ' ' + str(Character.BATTLE_POSITION.RANGED))
			if attack.attack_type == Attack.ATTACK_TYPE.RANGED and\
				me.battle_position == Character.BATTLE_POSITION.RANGED:
					attacks_from_strategy.append(attack)
		
		if not attacks_from_strategy.empty():
			#me._Debug.echo('Attacking from strategy..')
			return attacks_from_strategy[rand_range(0, attacks_from_strategy.size()-1) ]
		
		#me._Debug.echo('No attacks from strategy...')
		return possible_attacks[rand_range(0, possible_attacks.size()-1) ]
	else:
		#me._Debug.echo('I have no possible attacks available to me..', true)
		print(rules_failed)
		for failed in rules_failed:
			me._Debug.echo(str(failed), true)
		# I can't attack this character now...
		return false


func attack():
	# Spend My Attack
	if not me._Controller._Battle.is_attacking:
		me._AnimationTree["parameters/" + chosen_attack.animation + "/active"] = true
		chosen_attack = false

func ____UNUSED_physics_process(delta):

	# Is our character unable to reach their destination in time?
	if me.remaining_access_time <= 0:
		me.remaining_access_time = me.DESTINATION_ACCESS_TIME

		if me.teleport_on_fail:
			me.global_transform.origin = me._MOVEMENT.navigation_path[me._MOVEMENT.navigation_path.size()-1]
			me._MOVEMENT.navigation_path = []
		else:
			var waypoint = grab_random_waypoint()
			if not waypoint:
				me._Controller._Pathfinding.process_movement = false
				return

			if not me.get_navigation_path( waypoint.get_translation() ):
				me._Controller._Pathfinding.process_movement = false
				return
				
		#me._Debug.echo('Could Not reach destination in time.. Teleporting: ', me.teleport_on_fail)

	me.remaining_access_time -= delta

	# Is our character stuck?
	me.time_distance_moved += delta

	if me.time_distance_moved >= me.INTERVAL_TO_CHECK_DISTANCE_MOVED: #If one second has elapsed
		var total_position = me.transform.origin - me.beginning_position # Generate a Vector difference between the two.
		if total_position.length() < me.CHARACTER_STUCK_DEADZONE: # The character might be stuck.

			# Find nearest waypoint behind the character.
			find_nearest_waypoint_behind = true

			#get_navigation_path( grab_random_waypoint() )

		me.beginning_position = me.transform.origin # Record this beginning position
		me.time_distance_moved = 0