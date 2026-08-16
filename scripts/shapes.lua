local mod_name = core.get_current_modname()
local mod_path = core.get_modpath(mod_name)
local S = core.get_translator(mod_name)

nodeextensions.shapes = {}
nodeextensions.p.shape_list = {}
nodeextensions.shape_map = {}
nodeextensions.p.registered_shape_processes = {}
nodeextensions.p.nodes_awaiting_shape_registration = {}


local function texture_align_world(tiles)
	local r = {}
	for i, t in pairs(tiles) do
		if t.name then
			r[i] = {name = t.name}
		else
			r[i] = {name = t}
		end
		r[i].align_style = "world"
		r[i].scale = t.scale or 1
	end
	return r
end


local function on_shape_for_node(node_name)
	if core.registered_nodes[node_name]._full_node_name ~= nil then return end
	core.override_item(node_name, {
		_full_node_name = node_name
	})
end

---Lists a new shape, which nodes can register for themselves.
---Race conditions are avoided.
---@param shape_name string
---@param shape_def table
---@return nil
--[[
## Example:

	nodeextensions.register_shape_process("slab", {
		groups = {full_solid = 0, slab = 1,},
		process = function(self, node_name, def, flags)
			def.description = S("@1 Slab", def.description)
			def.node_box = {type = "fixed", fixed = {
				-8/16,  -8/16, -8/16,
				8/16,   0,     8/16
			}}
			if flags.offset_textures == true then
				def.tiles[3] = "[combine:16x16:0,8="..def.tiles[3]
				def.use_texture_alpha = "clip"
			end
			def.on_place = function(itemstack, placer, pointed_thing)
				local ctrl = core.is_player(placer) and placer:get_player_control()
				if ctrl and not (ctrl.sneak and ctrl.aux1) then
					return nodeextensions.rotate_and_place_stair(itemstack, placer, pointed_thing, {no_yaw=true})
				else
					return core.rotate_and_place(itemstack, placer, pointed_thing, nil, {force_facedir=true})
				end
			end
		end,
	})
]]
function nodeextensions.register_shape_process(shape_name, shape_def)
	shape_def.name = shape_name
	nodeextensions.p.registered_shape_processes[shape_name] = shape_def
	table.insert(nodeextensions.p.shape_list, shape_name)
	nodeextensions.shape_map[shape_name] = shape_def
	nodeextensions.p.check_shapes_are_registered(shape_name)
end

---Registers only this shape, for this node. If missing, waits until shape defined.
---@param node_name string
---@param shape_def table
---@param flags table|nil
---@return nil
--[[
## Example:

	nodeextensions.register_shape_for_node("my_mod:my_node", nodeextensions.shape_map.slab, {
		-- Flags will be given to the "process" function in the shape as well and
		-- can contain arbitrary data / flags.
		-- All flags are optional.
		shapes = {"slab", "stair"}, -- limits registration to only these shapes
		drawtype = "nodebox",
		paramtype = "light",
		paramtype2 = "facedir",
		groups = {stone = 0, shaped_stone = 1}, -- changes groups listed to those values
		tiles = TileDef or "texture.png",
		offset_textures = true,
		no_world_align = false,
		drop = DropTable or "my_mod:my_item",
	})
]]
function nodeextensions.register_shape_for_node(node_name, shape_def, flags)
	assert(
		core.registered_nodes[node_name],
		"[node_shapes] cannot register shapes for non-existent node: " .. node_name
	)
	if not flags then flags = {} end
	on_shape_for_node(node_name)
	local def = table.copy(core.registered_nodes[node_name])
	def.name = ":" .. node_name .. "_" .. shape_def.name
	if core.registered_nodes[def.name] then return end

	def.drawtype = flags.drawtype or shape_def.drawtype or "nodebox"
	def.paramtype = flags.paramtype or shape_def.paramtype or "light"
	def.paramtype2 = flags.paramtype2 or shape_def.paramtype2 or "facedir"

	def.groups = table.copy(def.groups)
	for k, v in pairs(shape_def.groups) do
		if v == 0 then def.groups[k] = nil
		else def.groups[k] = v end
	end
	for k, v in pairs(flags.groups or {}) do
		if v == 0 then def.groups[k] = nil
		else def.groups[k] = v end
	end

	def.tiles = table.copy(def.tiles)
	if flags.tiles then
		def.tiles = flags.tiles
	elseif flags.offset_textures == true then
		-- let sdef do this
	elseif not flags.no_world_align then
		def.tiles = texture_align_world(def.tiles)
	end

	def._shape_name = shape_def.name
	if flags.drop then def.drop = flags.drop end

	if shape_def.process then
		shape_def:process(node_name, def, flags)
	end
	core.register_node(def.name, def)
end

---Registers all shapes for a node, and awaits new shapes being defined
---in order to register those too.
---@param node_name string
---@param flags table|nil
---@return nil
--[[
## Example:

	nodeextensions.register_all_shapes_for_node("my_mod:my_node", {
		-- Flags will be given to the "process" function in the shape as well and
		-- can contain arbitrary data / flags.
		-- All flags are optional.
		shapes = {"slab", "stair"}, -- limits registration to only these shapes
		drawtype = "nodebox",
		paramtype = "light",
		paramtype2 = "facedir",
		groups = {stone = 0, shaped_stone = 1}, -- changes groups listed to those values
		tiles = TileDef or "texture.png",
		offset_textures = true,
		no_world_align = false,
		drop = DropTable or "my_mod:my_item",
	})
]]
function nodeextensions.register_all_shapes_for_node(node_name, flags)
	if not flags then flags = {} end
	local shapes = flags.shapes or nodeextensions.p.shape_list

	local all_awaiting = nodeextensions.p.nodes_awaiting_shape_registration
	local awaiting_list = all_awaiting[node_name]
	if not awaiting_list then
		awaiting_list = {}
		all_awaiting[node_name] = awaiting_list
	end

	local awaiting_def = {
		shapes = {},
		flags = table.copy(flags),
	}
	table.insert(awaiting_list, awaiting_def)

	for i, shape_name in ipairs(shapes) do
		local shape_def = nodeextensions.p.registered_shape_processes[shape_name]
		if shape_def then
			nodeextensions.register_shape_for_node(node_name, shape_def, flags)
		else
			table.insert(awaiting_def.shapes, shape_name)
		end
	end

	-- when all shapes declared, stop tracking
	if flags.shapes and #awaiting_def.shapes == 0 then
		table.remove(awaiting_list, #awaiting_list)
	end
end


function nodeextensions.p.check_shapes_are_registered(shape_name)
	for node_name, awaiting_list in pairs(nodeextensions.p.nodes_awaiting_shape_registration) do
		for k = #awaiting_list, 1, -1 do
			local awaiting_def = awaiting_list[k]
			local i = table.indexof(awaiting_def.shapes, shape_name)
			if i > 0 then
				local sdef = nodeextensions.p.registered_shape_processes[shape_name]
				if sdef then
					nodeextensions.register_shape_for_node(node_name, sdef, awaiting_def.flags)
				end
			end
			table.remove(awaiting_def.shapes, i)
			if #awaiting_def.shapes == 0 then
				table.remove(awaiting_list, k)
			end
		end
	end
end


core.register_on_mods_loaded(function()
	nodeextensions.p.nodes_awaiting_shape_registration = nil
end)
