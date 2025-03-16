
extends IStateController
class_name InterMissionController

## Manages strategic operations between combat missions
##
## Handles player progression, unit management, and mission preparation activities.
## Coordinates narrative sequences and economic interactions between battles.

#region Signals
## Emitted when mission parameters are finalized and ready for deployment
signal mission_prepared(mission_data: MissionData)
## Emitted when story sequence completes
signal narrative_completed
## Emitted when player closes the equipment store
signal store_closed
#endregion

#region Exported Properties
@export_category("Systems")
## Persistent campaign progression data resource
@export var campaign_data: CampaignResource
## Unit roster and deployment management system
@export var unit_manager: UnitManager
## Prefab for equipment store UI
@export var store_ui: PackedScene

@export_category("Configuration")
## Maximum weight limit for mission deployments
@export var default_tonnage_limit: int = 400
## Maximum number of deployable units per mission
@export var max_deployable_units: int = 8
#endregion

#region Private Variables
var _current_contract: ContractData       # Active mission contract
var _active_store: Control = null        # Current store UI instance
#endregion

#region State Lifecycle Methods
## Called when entering intermission state
## @param context: Dictionary containing transition data from previous state
func enter_state(context: Dictionary) -> void:
    super(context)
    # Load campaign progression data
    _load_campaign_data(context)
    # Set up mission preparation systems
    _initialize_mission_prep()
    # Begin narrative presentation
    _start_narrative_sequence()

## Called when exiting intermission state
## @return: Dictionary containing mission deployment data
func exit_state() -> Dictionary:
    var transition_data = super()
    # Package campaign progression state
    transition_data["campaign"] = campaign_data.serialize()
    # Include selected deployment forces
    transition_data["deployment"] = unit_manager.get_deployment_list()
    return transition_data

## Get unique identifier for this state
## @return: String constant representing intermission state
func get_state_name() -> String:
    return "INTERMISSION"
#endregion

#region Public Methods
## Open equipment store interface
func open_store() -> void:
    if _active_store: 
        return  # Prevent duplicate stores
    
    # Instantiate and configure store UI
    _active_store = store_ui.instantiate()
    _active_store.inventory = campaign_data.inventory
    add_child(_active_store)
    _active_store.connect("closed", _on_store_closed)
#endregion

#region Private Implementation
## Load campaign data from context or create new
## @param context: Transition data containing persisted campaign state
func _load_campaign_data(context: Dictionary) -> void:
    if context.has("campaign"):
        # Load existing campaign progress
        campaign_data.deserialize(context["campaign"])
    else:
        # Initialize fresh campaign
        campaign_data.initialize_new()

## Configure unit management for mission preparation
func _initialize_mission_prep() -> void:
    # Set deployment constraints
    unit_manager.set_tonnage_limit(default_tonnage_limit)
    unit_manager.set_max_deployables(max_deployable_units)
    # Load available units from campaign unlocks
    unit_manager.load_roster(campaign_data.unlocked_units)

## Play narrative sequence and await completion
func _start_narrative_sequence() -> void:
    var narrative = NarrativeSystem.get_next_sequence()
    NarrativeSystem.play_sequence(narrative)
    await NarrativeSystem.sequence_finished
    narrative_completed.emit()

## Handle store UI closure
func _on_store_closed() -> void:
    store_closed.emit()
    _active_store.queue_free()
    _active_store = null
#endregion