# UI/ContextualTooltip.gd
extends Panel
class_name ContextualTooltip

var current_target = null
var hover_timer := 0.0

func _get_hovered_element() -> Variant:
    var viewport = get_viewport()
    var mouse_pos = viewport.get_mouse_position()
    
    # Check if mouse is over UI elements
    if _is_mouse_over_ui(mouse_pos):
        return null
    
    # Convert to world coordinates
    var camera = viewport.get_camera_3d()
    var from = camera.project_ray_origin(mouse_pos)
    var to = from + camera.project_ray_normal(mouse_pos) * 1000
    
    # Terrain detection
    var space_state = viewport.world_3d.direct_space_state
    var query = PhysicsRayQueryParameters3D.create(from, to)
    var result = space_state.intersect_ray(query)
    
    if result.is_empty():
        return null
    
    # Check for hex cell
    var cell = HexGridManager.instance.world_to_axial(result.position)
    var hex = HexGridManager.instance.get_cell(cell.x, cell.y)
    
    if hex:
        # Check for units in cell
        var units = UnitManager.instance.get_units_in_hex(cell)
        if units.size() > 0:
            return units[0]  # Return first unit in cell
        return hex
    
    return null

func _is_mouse_over_ui(mouse_pos: Vector2) -> bool:
    var ui_controls = get_tree().get_nodes_in_group("ui_control")
    for control in ui_controls:
        if control.get_global_rect().has_point(mouse_pos):
            return true
    return false

func _process(delta: float) -> void:
    var hovered = _get_hovered_element()
    if hovered != current_target:
        hover_timer = 0.0
        current_target = hovered
        hide()
    
    if current_target:
        hover_timer += delta
        if hover_timer > 0.5 and !visible:
            update_tooltip()
            show()

func update_tooltip() -> void:
    var text = ""
    
    if current_target is HexCell:
        text = _get_terrain_tooltip(current_target)
    elif current_target is Unit:
        text = _get_unit_tooltip(current_target)
    
    $Label.text = text

func _get_terrain_tooltip(cell: HexCell) -> String:
    var _tooltip_text = """[b]{terrain}[/b]
Elevation: {elevation}
Cover: {cover}%
    
[b]Movement Costs:[/b]
""".format({
        "terrain": cell.terrain_data.name,
        "elevation": cell.elevation,
        "cover": cell.cover_value * 100
    })
    
    # Get mobility type names with costs
    var mobility_names = {
        Unit.MobilityType.BIPEDAL: "Bipedal",
        Unit.MobilityType.WHEELED: "Wheeled",
        Unit.MobilityType.HOVER: "Hover",
        Unit.MobilityType.TRACKED: "Tracked",
        Unit.MobilityType.AERIAL: "Aerial"
    }
    
    # Add costs for each mobility type
    for mobility_type in cell.terrain_data.mobility_costs:
        var type_name = mobility_names.get(mobility_type, "Unknown")
        var cost = cell.terrain_data.mobility_costs[mobility_type]
        _tooltip_text += "%s: %s MP\n" % [type_name, cost]
    
    # Add elevation modifier
    _tooltip_text += "\nElevation Modifier: +%s MP/level" % cell.terrain_data.elevation_cost_multiplier
    
    return _tooltip_text

func _get_unit_tooltip(unit: Unit) -> String:
    var _tooltip_text = """[b]{name}[/b]
[sub]Class: {class}[/sub]
----------------------------
[Armor] {armor}
[Structure] {structure}
[Heat] {heat}
[Movement] {mp}
----------------------------""".format({
        "name": unit.display_name,
        "class": unit.classification,
        "armor": _format_armor(unit),
        "structure": _format_structure(unit),
        "heat": _format_heat(unit),
        "mp": "%d/%d" % [unit.remaining_mp, unit.stats.movement_range]
    })
    
    # Weapons section
    _tooltip_text += "\n[b]Weapons:[/b]"
    if unit.weapons.is_empty():
        _tooltip_text += "\nNone"
    else:
        for weapon in unit.weapons:
            _tooltip_text += "\n- %s (%s)" % [
                weapon.weapon_name, 
                _weapon_status(weapon)
            ]
            if weapon.uses_ammo:
                _tooltip_text += " %d/%d" % [weapon.current_ammo, weapon.max_ammo]

    # Active effects
    var active_effects = unit.get_active_effects()
    if !active_effects.is_empty():
        _tooltip_text += "\n----------------------------\n[b]Effects:[/b]"
        for effect in active_effects:
            _tooltip_text += "\n- %s (%d turns)" % [effect.name, effect.duration]

    return _tooltip_text

# Helper functions
func _format_armor(unit: Unit) -> String:
    var total = unit.get_total_armor()
    var _max = unit.get_total_max_armor()
    return "%d/%d" % [total, _max]

func _format_structure(unit: Unit) -> String:
    var total = unit.get_total_structure()
    var _max = unit.get_total_max_structure()
    return "%d/%d" % [total, _max]

func _format_heat(unit: Unit) -> String:
    return "%d/%d (%d%%)" % [
        unit.heat_system.current_heat,
        unit.heat_system.max_heat,
        unit.heat_system.heat_percentage
    ]

func _weapon_status(weapon: ComponentData) -> String:

        if weapon.is_operational: return "Ready"
        #weapon.is_jammed: return "[color=red]Jammed[/color]"
        if !weapon.is_operational==false : return "[color=#888]Destroyed[/color]"
        return "Unknown"    