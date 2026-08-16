
nodeextensions.on_nearby = {}
nodeextensions.p.on_nearby_offset_min = vector.new(-2, -2, -2)
nodeextensions.p.on_nearby_offset_max = vector.new( 2,  3,  2)
nodeextensions.p.on_nearby_step_size = 0.5

function nodeextensions.p.on_nearby_get_detection_bounds(object)
	local pos = object:get_pos()
	return pos + nodeextensions.p.on_nearby_offset_min, pos + nodeextensions.p.on_nearby_offset_max
end

function nodeextensions.p.on_nearby_on_object_step(object, dtime)
	local p1, p2 = nodeextensions.p.on_nearby_get_detection_bounds(object)
	local nodes = core.find_nodes_in_area(p1, p2, "group:on_nearby", true)
	for node_name, list in pairs(nodes) do
		local ndef = core.registered_nodes[node_name]
		if ndef then for i, p in ipairs(list) do
			-- needs to ensure it's still this node and hasn't been modified
			if core.get_node(p).name == node_name then
				ndef._on_nearby(p, object, dtime)
			end
		end end
	end
end

local t = 0
core.register_globalstep(function(dtime)
	if t <= 0 then t = t + nodeextensions.p.on_nearby_step_size else t = t + dtime; return end
	for i, player in ipairs(core.get_connected_players()) do
		nodeextensions.p.on_nearby_on_object_step(player, 1)
	end
end)
