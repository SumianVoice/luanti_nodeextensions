
---@class vector

---Circumvents engine deleting the drops that you would have gotten then placing into a buildable_to node.
---@param pos vector
---@param digger any
function nodeextensions.dig_and_collect_node(pos, digger)
	local node = core.get_node(pos)
	local ndef = core.registered_nodes[node.name]
	if not ndef.diggable then return end
	if not core.is_player(digger) then core.dig_node(pos); return end
	local drops = core.get_node_drops(node, ItemStack(digger:get_wielded_item()):get_name())
	local inv = digger:get_inventory()
	-- use after since otherwise, itemstack will be overwritten by the return value from other functions
	-- #FIXME
	core.after(0.0001, function()
		for i, itemstring in ipairs(drops) do
			drops[i] = inv:add_item("main", ItemStack(itemstring))
			if drops[i] and drops[i]:get_count() > 0 then
				core.add_item(pos, drops[i])
			end
		end
	end)
end

---Prevents placement if not above a type of node.
---@param itemstack table ItemStack
---@param placer table ObjectRef
---@param pointed_thing table
---@param groups table
---@return table|nil ItemStack
function nodeextensions.only_place_above(itemstack, placer, pointed_thing, groups)
	local ret = nodeextensions.try_rightclick(itemstack, placer, pointed_thing, false)
	if ret then return ret end
	local pos = nodeextensions.get_place_position_from_pointed_thing(pointed_thing)
	if not pos then return end
	local node = core.get_node_or_nil(pos)
	if not node then return end
	local on_pos = vector.offset(pos, 0, -1, 0)
	if #core.find_nodes_in_area(on_pos, on_pos, groups) > 0 then
		if node and node.name ~= "air" then
			nodeextensions.dig_and_collect_node(pos, placer)
		end
		return core.item_place(itemstack, placer, pointed_thing)
	end
	return itemstack
end

---Avoids the engine not calling `on_place` by default in `core.item_place_node`
---@param itemstack table ItemStack
---@param placer table ObjectRef
---@param pointed_thing table
---@param param2 number|nil
---@param prevent_after_place boolean|nil
---@return table|nil ItemStack
---@return table|nil vector
function nodeextensions.item_place_node(itemstack, placer, pointed_thing, param2, prevent_after_place)
	local idef = itemstack:get_definition()
	if not idef then return end
	local placed_pos
	if idef.on_place then
		itemstack = idef.on_place(ItemStack(itemstack), placer, pointed_thing) or itemstack
	else
		local new_stack
		new_stack, placed_pos = core.item_place_node(ItemStack(itemstack), placer, pointed_thing, param2, prevent_after_place)
		if new_stack and placed_pos then
			itemstack = new_stack
		end
	end
	return itemstack, placed_pos
end


function nodeextensions.has_pointable_node_at(pos, group)
	local ray = core.raycast(pos, pos, false, false)
	for pointed_thing in ray do
		if pointed_thing.type == "node" then
			if group then
				if core.get_item_group(core.get_node(pointed_thing.under).name, group) > 0 then
					return true
				end
			end
		end
	end
	return false
end