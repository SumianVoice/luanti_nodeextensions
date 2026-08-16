
---@class ItemStack
---@class ObjectRef

-- just use a lookup table because it's easier
nodeextensions.p.node_dirs = {
	[tostring(vector.new(1, 0, 0))] = 12 + 1,
	[tostring(vector.new(0, 0, -1))] = 8 + 2,
	[tostring(vector.new(0, 0, 1))] = 4 + 0,
	[tostring(vector.new(-1, 0, 0))] = 16 + 3,
	[tostring(vector.new(0, 1, 0))] = 0,
	[tostring(vector.new(0, -1, 0))] = 20,
}

-- returns a vector that has the binary of the best look direction
-- if you put in (0.1, 0.9, 0.2) it will give you (0, 1, 0) because 0.9 is the biggest
function nodeextensions.p.get_face_dir_vector(v)
	if math.abs(v.y) > math.abs(v.x) and math.abs(v.y) > math.abs(v.z) then
		v.x = 0
		v.z = 0
	elseif math.abs(v.x) > math.abs(v.z) then
		v.z = 0
		v.y = 0
	else
		v.x = 0
		v.y = 0
	end
	return v
end

local function get_node_info(pos)
	local node = core.get_node_or_nil(pos)
	if not node then return end
	return node, core.registered_nodes[node.name]
end

local function get_ndef(pos)
	return core.registered_nodes[core.get_node(pos).name]
end

---Gets the position a pointed thing would build to, e.g. if buildable_to it will be `under`.
---@param pointed_thing table
---@return vector|nil
function nodeextensions.get_place_position_from_pointed_thing(pointed_thing)
	local ndef_under = get_ndef(pointed_thing.under)
	local ndef_above = get_ndef(pointed_thing.above)
	if ndef_under.buildable_to then
		return pointed_thing.under
	elseif ndef_above.buildable_to then
		return pointed_thing.above
	else
		return nil -- can't place
	end
end

---Places the node so that the base of the node is attached to the face of the node you're pointing at (see wood logs).
---@param itemstack ItemStack
---@param placer ObjectRef
---@param pointed_thing table|nil
---@return ItemStack|nil
---@return nil
function nodeextensions.rotate_and_place(itemstack, placer, pointed_thing)
	local ret = nodeextensions.try_rightclick(itemstack, placer, pointed_thing, false)
	if ret then
		return ret, nil
	end
	local stack = core.rotate_and_place(ItemStack(itemstack), placer, pointed_thing, nil, {})
	if core.is_player(placer) and core.is_creative_enabled(placer:get_player_name()) then
		return itemstack
	end
	return stack
end

---Rotates so that the +z face is against the node pointed at.
---@param itemstack ItemStack
---@param placer ObjectRef
---@param pointed_thing table
---@param flags table|nil
---@return ItemStack|nil
---@return vector|nil
--[[
## Example:

	nodeextensions.rotate_and_place_against(itemstack, placer, pointed_thing, {
		can_place = function(predict_pos, node) return true or false end,
		no_rightclick = false, -- doesn't call try_rightclick
		copy_same_node = false, -- if true, copies the rotation of the node you're pointing at
	})
--]]
function nodeextensions.rotate_and_place_against(itemstack, placer, pointed_thing, flags)
	itemstack = ItemStack(itemstack)
	if not (flags and flags.no_rightclick) then
		local ret = nodeextensions.try_rightclick(itemstack, placer, pointed_thing, false)
		if ret then return ret, nil end
	end
	-- make sure you don't index nil
	if flags == nil then flags = {} end

	-- get the name of the node
	local wield_name = itemstack:get_name()
	local facedir = 0

	-- copy the node you're placing it to if the flag is set
	local place_node = core.get_node(pointed_thing.under)
	if flags.copy_same_node and place_node and place_node.name == wield_name then
		facedir = place_node.param2
	else
		local dir = vector.subtract(pointed_thing.under, pointed_thing.above)
		facedir = core.dir_to_facedir(dir, true)
	end

	-- predict if under or above, then pipe this to the can_place callback if given
	if flags.can_place then
		local unode, udef = get_node_info(pointed_thing.under)
		local anode, adef = get_node_info(pointed_thing.above)
		local predict_pos = (udef and udef.buildable_to and pointed_thing.under) or (adef and adef.buildable_to and pointed_thing.above)
		if predict_pos then
			local node = {name=wield_name, param2=0, param1=0}
			if not flags.can_place(predict_pos, node) then
				return itemstack, nil
			end
		end
	end

	local retpos
	itemstack, retpos = core.item_place_node(itemstack, placer, pointed_thing, facedir)

	return itemstack, retpos
end

local function get_eyepos(player)
	local eyepos = vector.add(player:get_pos(), vector.multiply(player:get_eye_offset(), 0.1))
	eyepos.y = eyepos.y + player:get_properties().eye_height
	return eyepos
end

local stair_look_dir = {
	[tostring(vector.new(0, 0, 1))] = 0,
	[tostring(vector.new(1, 0, 0))] = 1,
	[tostring(vector.new(0, 0, -1))] = 2,
	[tostring(vector.new(-1, 0, 0))] = 3,
}

---Gets the pointed thing via raycast so it also has intersection_point etc
---@param itemstack ItemStack
---@param player ObjectRef
---@param pointed_thing table
---@param flags table|nil
---@return table|nil
function nodeextensions.get_ray_intersect_from_look(itemstack, player, pointed_thing, flags)
	local lookdir = vector.normalize(player:get_look_dir())
	local pos = get_eyepos(player)
	local range = itemstack:get_definition().range or 12
	local lookpos = vector.multiply(lookdir, range)
	lookpos = vector.add(lookpos, pos)

	local ray = core.raycast(pos, lookpos, false, false)
	for pt in ray do
		if pt.type == "node" then
			pointed_thing = pt
			break
		end
	end
	return pointed_thing
end

---Places node upside down if looking at the top half of a node, and pointing toward the player
---@param itemstack ItemStack
---@param placer ObjectRef
---@param pointed_thing table|nil
---@param flags table
function nodeextensions.rotate_and_place_stair(itemstack, placer, pointed_thing, flags)
	local ret = nodeextensions.try_rightclick(itemstack, placer, pointed_thing, false)
	if ret then return ret end
	if not pointed_thing then return itemstack end
	if pointed_thing.type ~= "node" then return itemstack end
	local def = core.registered_nodes[core.get_node(pointed_thing.above).name]
	if (not def) or not (def.buildable_to) then return itemstack end

	pointed_thing = nodeextensions.get_ray_intersect_from_look(itemstack, placer, pointed_thing, flags)
	if (not pointed_thing) or not pointed_thing.intersection_point then return itemstack end

	local facedir = 0
	local intpos = pointed_thing.intersection_point
	local y_dir = pointed_thing.under.y - pointed_thing.above.y
	intpos.x = math.abs(intpos.x % 1)
	intpos.y = math.abs((intpos.y-y_dir*0.001) % 1)
	intpos.z = math.abs(intpos.z % 1)
	if (intpos.y < 0.5) then
		facedir = 20
	end

	-- copy the node you're placing it to if the flag is set
	local place_node = core.get_node(pointed_thing.under)
	if flags.copy_same_node and place_node and place_node.param2 then
		facedir = place_node.param2
	elseif not (flags and flags.no_yaw) then
		-- local norm = vector.subtract(pointed_thing.under, pointed_thing.above)
		local look_dir = core.yaw_to_dir(placer:get_look_horizontal())
		look_dir = vector.round(nodeextensions.p.get_face_dir_vector(look_dir))
		local result = stair_look_dir[tostring(look_dir)]
		local to_facedir = 0
		if result then to_facedir = result end
		if facedir == 20 and (to_facedir % 2 == 1) then
			to_facedir = (to_facedir + 2) % 4
		end
		facedir = (facedir + to_facedir) % 25
	end

	return core.item_place(itemstack, placer, pointed_thing, facedir)
end


nodeextensions.p.quarter_facedir_map = {
	get_facedir = function(self, pos, face)
		local ta = {
			tostring(face)..":",
			tostring(math.floor(math.abs(pos.x % 1)*2)),
			tostring(math.floor(math.abs(pos.y % 1)*2)),
			tostring(math.floor(math.abs(-pos.z % 1)*2))
		}
		-- ignore axis of face
		local fi = self.face_axis_ignore[face]
		ta[fi] = "1"
		local t = table.concat(ta)
		return (self[t] or 0)%24
	end,
	-- if e.g. the top face of the node, then ignore Y, etc
	face_axis_ignore = {
		[5]=4,
		[4]=4,
		[3]=2,
		[2]=2,
		[1]=3,
		[0]=3,
	},

	["5:101"] = 4,
	["5:111"] = 5,
	["5:011"] = 6,
	["5:001"] = 7,

	["4:111"] = 8,
	["4:101"] = 9,
	["4:001"] = 10,
	["4:011"] = 11,

	["3:100"] = 12,
	["3:101"] = 13,
	["3:111"] = 14,
	["3:110"] = 15,

	["2:110"] = 16,
	["2:111"] = 17,
	["2:101"] = 18,
	["2:100"] = 19,

	["1:111"] = 1,
	["1:011"] = 2,
	["1:010"] = 3,
	["1:110"] = 0,

	["0:010"] = 20,
	["0:011"] = 21,
	["0:111"] = 22,
	["0:110"] = 23,
}

--[[
core.register_tool("nodeextensions:rotator", {
	description = "node rotator debug",
	on_place = function(itemstack, placer, pointed_thing)
		local pos = pointed_thing.under
		local node = core.get_node(pos)
		node.param2 = (node.param2 + 1) % 24
		core.swap_node(pos, node)
		core.log(node.param2)
	end,
})
--]]

---Rotates so that a node's -x, -y, -z face is attached to the "quarter" of the node you're looking at.
---No guarantees on up/down orientation...
---@param itemstack ItemStack
---@param placer ObjectRef
---@param pointed_thing table|nil
---@param flags table|nil
---@return ItemStack|nil
---@return vector|nil
function nodeextensions.rotate_and_place_quarter(itemstack, placer, pointed_thing, flags)
	local ret = nodeextensions.try_rightclick(itemstack, placer, pointed_thing, false)
	if ret then return ret, nil end
	if not pointed_thing then return itemstack, nil end
	if pointed_thing.type ~= "node" then return itemstack end
	local def = core.registered_nodes[core.get_node(pointed_thing.above).name]
	if (not def) or not (def.buildable_to) then return itemstack, nil end

	pointed_thing = nodeextensions.get_ray_intersect_from_look(itemstack, placer, pointed_thing, flags)

	if (not pointed_thing) or not pointed_thing.intersection_point then
		return itemstack, nil end

	local facedir = 0
	local intpos = pointed_thing.intersection_point
	facedir = nodeextensions.p.quarter_facedir_map:get_facedir(
		intpos,
		core.dir_to_wallmounted(pointed_thing.under - pointed_thing.above))

	return core.item_place(itemstack, placer, pointed_thing, facedir)
end

local adjacent = {
	[0] = vector.new( 0,-1, 0),
	[1] = vector.new( 0, 1, 0),
	[2] = vector.new( 1, 0, 0),
	[3] = vector.new(-1, 0, 0),
	[4] = vector.new( 0, 0, 1),
	[5] = vector.new( 0, 0,-1),
}

function nodeextensions.rotate_to_any_walkable(pos)
	local node = core.get_node(pos)
	for i=2, #adjacent do
		local p = vector.subtract(pos, adjacent[i])
		if core.registered_nodes[core.get_node(p).name].walkable then
			node.param2 = core.dir_to_facedir(vector.multiply(adjacent[i], -1))
			core.swap_node(pos, node)
			return true
		end
	end
end

function nodeextensions.rotate_to_group(pos, group)
	local node = core.get_node(pos)
	for i=1, #adjacent+1 do
		local p = vector.subtract(pos, adjacent[i%6])
		if core.get_item_group(core.get_node(p).name, group) ~= 0 then
			node.param2 = (nodeextensions.p.node_dirs[tostring(vector.multiply(adjacent[i%6], 1))])
			core.swap_node(pos, node)
			return true
		end
	end
end

