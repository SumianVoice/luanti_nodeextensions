# Node Extensions
Provides helpers and backend functionality for nodes.

## Scope
- defining nodes and node shapes
- how entities interact with nodes and the inverse
- node placement, rotation, conditions on placement etc

## Planned Scope
- how nodes interact with other nodes (grass spreading etc)
- how nodes change over time

## Usage
For example usage, see either the comments within the code, or use autocomplete to show examples (which are included in comments so they show up in your code editor).

## API
Currently implemented features.

### Shapes
```lua
-- create all shapes, and awaits any missing shapes
nodeextensions.register_all_shapes_for_node(node_name, flags)
-- creates only this shape, and the shape def can be found via `nodeextensions.shape_map[shape_name]`
nodeextensions.register_shape_for_node(node_name, shape_definition, flags)
-- defines a shape and registers any shapes that are awaiting from the above
nodeextensions.register_shape_process(shape_name, shape_definition)
```

## Placement rules
```lua
nodeextensions.dig_and_collect_node(pos, digger)
nodeextensions.only_place_above(itemstack, placer, pointed_thing, groups)
nodeextensions.item_place_node(itemstack, placer, pointed_thing, param2, prevent_after_place)
-- likely to be deprecated / changed substantially:
nodeextensions.has_pointable_node_at(pos, group)
```

## Placement and rotation
```lua
nodeextensions.get_place_position_from_pointed_thing(pointed_thing)
nodeextensions.rotate_and_place(itemstack, placer, pointed_thing)
nodeextensions.rotate_and_place_against(itemstack, placer, pointed_thing, flags)
nodeextensions.get_ray_intersect_from_look(itemstack, player, pointed_thing, flags)
nodeextensions.rotate_and_place_stair(itemstack, placer, pointed_thing, flags)
nodeextensions.rotate_and_place_quarter(itemstack, placer, pointed_thing, flags)
nodeextensions.rotate_to_any_walkable(pos)
nodeextensions.rotate_to_group(pos, group)
```

### Various other features
```lua
core.register_node(name, {
	-- when a player or other object is near a node
	-- by default, dtime will be `0.5` as it runs twice per second
	_on_nearby = function(pos, object, dtime) end,
})
```
