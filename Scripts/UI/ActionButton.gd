# UI/ActionButton.gd
# Custom button class for action buttons with a configure method
extends Button
class_name ActionButton

## Configures the button with text, icon, and enabled state
## @param text: String - The text to display on the button
## @param icon: Texture - The icon to display on the button
## @param enabled: bool - Whether the button should be enabled
func configure(text: String, icon: Texture, enabled: bool) -> void:
	self.text = text
	self.icon = icon
	self.disabled = not enabled
	self.modulate.a = 1.0 if enabled else 0.5  # Visual feedback for disabled state