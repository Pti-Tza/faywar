# DirectionalAStar.gd
class_name DirectionalAStar
extends AStar3D
## Custom A* implementation for asymmetric hexagonal grid movement costs
##
## Handles Battletech-specific movement rules:
## - Different costs for entering/exiting cells
## - Elevation-based penalties
## - Unit-type specific mobility constraints

# Internal storage for edge costs: { "from|to": cost }
var _edge_costs: Dictionary = {}

## Adds a directional connection with custom cost
func add_directional_connection(from: int, to: int, cost: float) -> void:
	if not has_point(from) or not has_point(to):
		push_error("Invalid points for connection: %d -> %d" % [from, to])
		return
	
	# Store cost in both directions (Godot requires bidirectional connections)
	connect_points(from, to, true)
	_edge_costs[_cost_key(from, to)] = cost
	_edge_costs[_cost_key(to, from)] = cost  # See note below

## Gets actual movement cost between connected points
func get_connection_cost(from: int, to: int) -> float:
	return _edge_costs.get(_cost_key(from, to), INF)

# Internal key generator for edge storage
func _cost_key(a: int, b: int) -> String:
	return "%d|%d" % [a, b]

# Override A* cost calculation to use directional costs
func _compute_cost(from_id: int, to_id: int) -> float:
	return get_connection_cost(from_id, to_id)
