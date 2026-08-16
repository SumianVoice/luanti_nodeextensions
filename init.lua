local mod_name = core.get_current_modname()
local mod_path = core.get_modpath(mod_name)

nodeextensions = {}
-- Private methods and data, avoid using.
nodeextensions.p = {}

dofile(mod_path .. "/scripts/helpers.lua")
dofile(mod_path .. "/scripts/on_nearby.lua")
dofile(mod_path .. "/scripts/rotation.lua")
dofile(mod_path .. "/scripts/shapes.lua")
dofile(mod_path .. "/scripts/placement_rules.lua")
