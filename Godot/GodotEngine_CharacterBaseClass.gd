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

extends KinematicBody

# THIS IS AN ABSTRACT CLASS. YOU SHOULD NOT Instantiate it.
class_name Character

###################
# Utilize Character
export(Resource) var _character


################### 
# System Variables
export(bool) var debug_mode
export(bool) var init_as_player
export(Material) var body_material setget set_body_material


###################
# Character Attributes
export(float) var character_height = 1.0
export(float) var default_locomotion_speed = 1.0


#############
# Character Status
var battle_mode : bool = false

###################
# Battle Experience, Attacks
export(int) var health = 100
export(int) var mana = 100

var attack_list = [
	Attack.new('AttackPunch', Attack.ATTACK_TYPE.FRONTAL_ASSAULT,
		1.0, 2.0, 'AttackPunch',
		[AttackRule.new('distance', 2000.0)]),
	Attack.new('AttackBowShot', Attack.ATTACK_TYPE.RANGED,
		1.0, 2.0, 'AttackBowShot',
		[AttackRule.new('distance', 6.0, false, true)]),
	Attack.new('AttackGreatSwordSlash', Attack.ATTACK_TYPE.FRONTAL_ASSAULT,
		1.0, 2.0, 'AttackGreatSwordSlash',
		[AttackRule.new('distance', 2000.0)])
]


###################
# AI Settings

#### Battle Strategy
enum BATTLE_STRATEGY { OFFENSIVE, DEFENSIVE }
enum BATTLE_POSITION { RANGED, CLOSE_COMBAT }
export(BATTLE_STRATEGY) var battle_strategy = BATTLE_STRATEGY.OFFENSIVE
export(BATTLE_POSITION) var battle_position = BATTLE_POSITION.RANGED

#### Patrol
export(Array, NodePath) var waypoints
export(bool) var patrol_waypoints = false

#### Hostility
# 1 - Will run. 
# 2 - Attacks if attacked. 
# 3 - Attacks if attacked and will chase you
# 4 - Attacks in you are in sight.
enum HOSTILITY_LEVELS { IDLE=0, PREY=1, DEFENSIVE=2, AGRESSIVE=3, HUNTER=4, ALLY=5, ALLY_PREY=6 }
export(HOSTILITY_LEVELS) var hostility_level = HOSTILITY_LEVELS.get('PREY')

#### Hunter Specific
export(float) var time_to_search_for_target = 5.0

#### Character Movement
const INTERVAL_TO_CHECK_DISTANCE_MOVED = 1
var time_distance_moved = 0
var beginning_position:Vector3 = Vector3()
var lock_character_movement = false

#### Navigation
export(NodePath) var navLevelPath
var navLevel

#### Failure Fallback
var CHARACTER_STUCK_DEADZONE:float = .2
export(bool) var teleport_on_fail = false
const MAX_ERRORS = 10
var errors = 0

# If I cannot access my destination time (whether there is someone in the way or
# I simply cannot get there...then teleport me there.
const DESTINATION_ACCESS_TIME = 6000
var remaining_access_time = DESTINATION_ACCESS_TIME


##################
# The Senses - Field of View

export var field_of_view = 45
export(float) var field_of_view_resolution = 1.0
export(float) var vision_max_distance = 20.0
export(float) var radius_of_awareness = 12.0
var actual_radius_of_awareness : float = 12.0

##################
# TODO: GD Script Enum character type:
# TODO: Armature driven? Static Body? :)


#############
# Script Attachments
var _Controller
var _Debug

var _AnimationTree
var _CharacterBase
var _Awareness

func endow():

	print('Endowing Character with Player Powers.')

	remove_child(_Controller)
	#get_node('characterAIScript').queue_free()

	_Controller = load("res://Gameplay/Characters/Character_Player.gd").new()
	_Controller.name = 'characterPlayerScript'
	_Controller.me = self
	add_child(_Controller)

	actual_radius_of_awareness = radius_of_awareness

	print('ENDOW')

func relinquish():

	print('Relinquishing Character('+str(self.name)+') of Player Powers.')

	remove_child(_Controller)
	#get_node('characterPlayerScript').queue_free()

	_Controller = load("res://Gameplay/Characters/Character_AI.gd").new()
	_Controller.name = 'characterAIScript'
	_Controller.me = self
	add_child(_Controller)

	actual_radius_of_awareness = radius_of_awareness

	#print('~~~~BLENDTREE AI~~~~~~~~~~~~~~~~~~~~')
	#$AnimationTree.tree_root = preload("res://Gameplay/AnimationTrees/BlendTree_AI.tres")
	#print('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~')

# Add All Scripts into the Character.
func _ready():
	
	# Character must be in a level, otherwise just skip the character creation and script instantiation
	if not get_owner():
		return
	
	print('ready: ', self.name)
	# If a custom character is specified, then load in that character as well as their associated properties.
	if _character:
		var existingCharacterBase = find_node('CharacterBase', true, true)
		remove_child(existingCharacterBase)
		
		var characterLoaded = _character.instance()
		characterLoaded.name = "CharacterBase"

		#characterLoaded.transform.rotated(Vector3.UP, deg2rad(180))
		#characterLoaded.global_transform.rotated(Vector3.UP, deg2rad(180))
		characterLoaded.add_child(generate_animation_player(characterLoaded))
		characterLoaded.get_node('AnimationPlayer').root_node = '..'
		add_child(characterLoaded)
		#get_node('CharacterBase').set_rotation_degrees(Vector3(0,180,0))

		$AnimationTree.anim_player = '../CharacterBase/AnimationPlayer'
		$AnimationTree.root_motion_track = 'Armature/Skeleton:Root'
		$AnimationTree.active = true
	
	_CharacterBase = $CharacterBase
	_AnimationTree = $AnimationTree
	_Awareness = $Awareness
	_Awareness.me = self

	# Debug Script Helper object, to draw paths, echo character's log data, etc
	_Debug = load("res://Gameplay/Characters/Character_Debug.gd")
	_Debug = _Debug.new()
	_Debug.name = '_Debug'
	_Debug.me = self
	add_child(_Debug)

	navLevel = get_node(navLevelPath)
	if not navLevel or not navLevel.is_class('Navigation') :
		for nd in get_owner().get_children():
			if nd.is_class('Navigation'):
				navLevel = nd
				break

	# Normally handled by the game manager
	# Game manager will specify who will be endowed by the player according to the Scene Rules (If Any),
	# located in something like a GameManagerData node
	if init_as_player:
		_GameManager.set_player(self)
	else:
		relinquish()


func set_body_material(mat: Material):
	if find_node('SimpleManMesh'):
		find_node('SimpleManMesh').set_surface_material(0, mat)

func generate_animation_player(characterLoaded):

	var createAnimationPlayer = AnimationPlayer.new()
	createAnimationPlayer.playback_process_mode = AnimationPlayer.ANIMATION_PROCESS_IDLE
	createAnimationPlayer.playback_speed = 1.0
	createAnimationPlayer.root_node = 'CharacterBase'

	if characterLoaded.anim_walking:
		createAnimationPlayer.add_animation('anim_walking', load(characterLoaded.anim_walking.get_path()) )
	else:
		createAnimationPlayer.add_animation('anim_walking', load('res://Characters/_humanoid_animations/anim_walking.anim'))

	if characterLoaded.anim_running:
		createAnimationPlayer.add_animation('anim_running', load(characterLoaded.anim_running.get_path()) )
	else:
		createAnimationPlayer.add_animation('anim_running', load('res://Characters/_humanoid_animations/anim_running.anim'))

	if characterLoaded.anim_idle_basic:
		createAnimationPlayer.add_animation('anim_idle_basic', load(characterLoaded.anim_idle_basic.get_path()))
	else:
		createAnimationPlayer.add_animation('anim_idle_basic', load('res://Characters/_humanoid_animations/anim_idle_basic.anim'))
	
	if characterLoaded.anim_idle_battle:
		createAnimationPlayer.add_animation('anim_idle_battle', load(characterLoaded.anim_idle_battle.get_path()))
	else:
		createAnimationPlayer.add_animation('anim_idle_battle', load('res://Characters/_humanoid_animations/anim_idle_battle.anim'))

	if characterLoaded.anim_jog_forward:
		createAnimationPlayer.add_animation('anim_jog_forward', load(characterLoaded.anim_jog_forward.get_path()))
	else:
		createAnimationPlayer.add_animation('anim_jog_forward', load('res://Characters/_humanoid_animations/anim_jog_forward.anim'))

	if characterLoaded.anim_jog_backward:
		createAnimationPlayer.add_animation('anim_jog_backward', load(characterLoaded.anim_jog_backward.get_path()))
	else:
		createAnimationPlayer.add_animation('anim_jog_backward', load('res://Characters/_humanoid_animations/anim_jog_backward.anim'))

	if characterLoaded.anim_jog_strafe_right:
		createAnimationPlayer.add_animation('anim_jog_strafe_right', load(characterLoaded.anim_jog_strafe_right.get_path()))
	else:
		createAnimationPlayer.add_animation('anim_jog_strafe_right', load('res://Characters/_humanoid_animations/anim_jog_strafe_right.anim'))

	if characterLoaded.anim_jog_strafe_left:
		createAnimationPlayer.add_animation('anim_jog_strafe_left', load(characterLoaded.anim_jog_strafe_left.get_path()))
	else:
		createAnimationPlayer.add_animation('anim_jog_strafe_left', load('res://Characters/_humanoid_animations/anim_jog_strafe_left.anim'))

	if characterLoaded.anim_melee_weak_montage_1:
		createAnimationPlayer.add_animation('anim_melee_weak_montage_1', load(characterLoaded.anim_melee_weak_montage_1.get_path()))
	else:
		createAnimationPlayer.add_animation('anim_melee_weak_montage_1', load('res://Characters/_humanoid_animations/anim_melee_weak_montage_1.anim'))

	if characterLoaded.anim_melee_weak_montage_2:
		createAnimationPlayer.add_animation('anim_melee_weak_montage_2', load(characterLoaded.anim_melee_weak_montage_2.get_path()))
	else:
		createAnimationPlayer.add_animation('anim_melee_weak_montage_2', load('res://Characters/_humanoid_animations/anim_melee_weak_montage_2.anim'))

	if characterLoaded.anim_melee_weak_montage_3:
		createAnimationPlayer.add_animation('aanim_melee_weak_montage_3', load(characterLoaded.anim_melee_weak_montage_3.get_path()))
	else:
		createAnimationPlayer.add_animation('anim_melee_weak_montage_3', load('res://Characters/_humanoid_animations/anim_melee_weak_montage_3.anim'))

	if characterLoaded.anim_mana_attack:
		createAnimationPlayer.add_animation('anim_mana_attack', load(characterLoaded.anim_mana_attack.get_path()))
	else:
		createAnimationPlayer.add_animation('anim_mana_attack', load('res://Characters/_humanoid_animations/anim_mana_attack.anim'))

	if characterLoaded.anim_special_attack:
		createAnimationPlayer.add_animation('anim_special_attack', load(characterLoaded.anim_special_attack.get_path()))
	else:
		createAnimationPlayer.add_animation('anim_special_attack', load('res://Characters/_humanoid_animations/anim_special_attack.anim'))
	
	if characterLoaded.anim_ranged_weak_montage_1:
		createAnimationPlayer.add_animation('anim_ranged_weak_montage_1', load(characterLoaded.anim_ranged_weak_montage_1.get_path()))
	else:
		createAnimationPlayer.add_animation('anim_ranged_weak_montage_1', load('res://Characters/_humanoid_animations/anim_ranged_weak_montage_1.anim'))
	
	createAnimationPlayer.name = 'AnimationPlayer'

	if characterLoaded.find_node('AnimationPlayer'):
		remove_child(characterLoaded.find_node('AnimationPlayer'))

	return createAnimationPlayer
