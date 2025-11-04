# Unit Hit Profiles

This directory contains HitProfile resources that define how different sections of a unit can be hit from various angles.

## How Hit Profiles Work

Each HitProfile resource defines probability weights for which unit sections can be hit from different attack angles:
- **Front**: Attacks coming from the front (±45° from center)
- **Right**: Attacks coming from the right (45° to 135°)
- **Rear**: Attacks coming from the rear (±135° to 180°)
- **Left**: Attacks coming from the left (-135° to -45°)

## Creating New Hit Profiles

1. Create a new resource in the Godot editor
2. Set the resource type to "HitProfile"
3. Configure the hit weights for each direction
4. Assign the resource to a Unit's hit_profile property

## Weight Interpretation

The values in the hit weight dictionaries are relative probabilities. For example:
- `{"Front": 70, "Left": 15, "Right": 15}` means:
  - 70% chance of hitting the front section
  - 15% chance of hitting the left section  
  - 15% chance of hitting the right section

The total doesn't need to sum to 100 - the system will normalize the values automatically.