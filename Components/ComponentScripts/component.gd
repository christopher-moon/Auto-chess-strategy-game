# component: base class for entity components
class_name Component
extends Node

# the entity that owns this specific component
var entity: Entity

# assign owner entity, then let the component read its own stats from the data
func setup(parent_entity: Entity, data: EntityData) -> void:
	entity = parent_entity
	_configure(data)

# override in components to copy stats from the entity's data
func _configure(_data: EntityData) -> void:
	pass
