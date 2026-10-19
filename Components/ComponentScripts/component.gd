# component: base class for entity components
class_name Component
extends Node

# the entity that owns this specific component
var entity: Entity 

# assign owner entity
func setup(parent_entity: Entity) -> void:
	entity = parent_entity
