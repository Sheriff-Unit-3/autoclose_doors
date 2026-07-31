-- Auto-closing doors
-- forked from homedecor's door code

autoclose_doors = {}

local S = core.get_translator()

autoclose_doors.gettext = S

function autoclose_doors.get_nodedef_field(nodename, fieldname)
	if not core.registered_nodes[nodename] then
		return nil
	end
	return core.registered_nodes[nodename][fieldname]
end

-- the model file

local modpath = core.get_modpath("autoclose_doors")
dofile(modpath .. "/door_models.lua")

-- check if a door is marked as closed

local function getClosed(pos)
	local c = core.get_meta(pos):get_string("closed")
	if c == "true" then
		return true
	else
		return false
	end
end

-- register the nodes

local sides = { "left", "right" }
local rsides = { "right", "left" }

for i in ipairs(sides) do
	local side = sides[i]
	local rside = rsides[i]

	for j in ipairs(autoclose_doors.door_models) do
		local doorname = autoclose_doors.door_models[j][1]
		local doordesc = autoclose_doors.door_models[j][2]
		local nodeboxes_top = autoclose_doors.door_models[j][5]
		local nodeboxes_bottom = autoclose_doors.door_models[j][6]
		local texalpha = false

		if side == "left" then
			nodeboxes_top = autoclose_doors.door_models[j][3]
			nodeboxes_bottom = autoclose_doors.door_models[j][4]
		end

		local lower_top_side = "autoclose_doors_" .. doorname .. "_tb.png"
		local upper_bottom_side = "autoclose_doors_" .. doorname .. "_tb.png"

		local tiles_upper = {
			"autoclose_doors_" .. doorname .. "_tb.png",
			upper_bottom_side,
			"autoclose_doors_" .. doorname .. "_lrt.png",
			"autoclose_doors_" .. doorname .. "_lrt.png",
			"autoclose_doors_" .. doorname .. "_" .. rside .. "_top.png",
			"autoclose_doors_" .. doorname .. "_" .. side .. "_top.png",
		}

		local tiles_lower = {
			lower_top_side,
			"autoclose_doors_" .. doorname .. "_tb.png",
			"autoclose_doors_" .. doorname .. "_lrb.png",
			"autoclose_doors_" .. doorname .. "_lrb.png",
			"autoclose_doors_" .. doorname .. "_" .. rside .. "_bottom.png",
			"autoclose_doors_" .. doorname .. "_" .. side .. "_bottom.png",
		}

		local selectboxes_top = {
			type = "fixed",
			fixed = { -0.5, -1.5, 6 / 16, 0.5, 0.5, 8 / 16 },
		}

		local selectboxes_bottom = {
			type = "fixed",
			fixed = { -0.5, -0.5, 6 / 16, 0.5, 1.5, 8 / 16 },
		}

		core.register_node("autoclose_doors:" .. doorname .. "_top_" .. side, {
			description = doordesc .. " " .. S("(Top Half, @1-opening)", side),
			drawtype = "nodebox",
			tiles = tiles_upper,
			paramtype = "light",
			paramtype2 = "facedir",
			groups = { snappy = 3, not_in_creative_inventory = 1 },
			is_ground_content = false,
			sounds = default.node_sound_wood_defaults(),
			walkable = true,
			use_texture_alpha = texalpha,
			selection_box = selectboxes_top,
			node_box = {
				type = "fixed",
				fixed = nodeboxes_top,
			},
			drop = "autoclose_doors:" .. doorname .. "_bottom_" .. side,
			after_dig_node = function(pos, oldnode, oldmetadata, digger)
				if
					core.get_node({ x = pos.x, y = pos.y - 1, z = pos.z }).name
					== "autoclose_doors:" .. doorname .. "_bottom_" .. side
				then
					core.remove_node({ x = pos.x, y = pos.y - 1, z = pos.z })
				end
			end,
			on_rightclick = function(pos, node, clicker)
				autoclose_doors.flip_door({ x = pos.x, y = pos.y - 1, z = pos.z }, node, clicker, doorname, side)
			end,
		})

		local dgroups = { snappy = 3, not_in_creative_inventory = 1 }
		if side == "left" then
			dgroups = { snappy = 3 }
		end

		core.register_node("autoclose_doors:" .. doorname .. "_bottom_" .. side, {
			description = doordesc .. " " .. S("(@1-opening)", side),
			drawtype = "nodebox",
			tiles = tiles_lower,
			inventory_image = "autoclose_doors_" .. doorname .. "_left_inv.png",
			wield_image = "autoclose_doors_" .. doorname .. "_left_inv.png",
			paramtype = "light",
			paramtype2 = "facedir",
			groups = dgroups,
			is_ground_content = false,
			sounds = default.node_sound_wood_defaults(),
			walkable = true,
			use_texture_alpha = texalpha,
			selection_box = selectboxes_bottom,
			on_timer = function(pos, elapsed)
				if not getClosed(pos) then
					local node = core.get_node(pos)
					autoclose_doors.flip_door(pos, node, nil, doorname, side, false)
				end
			end,
			node_box = {
				type = "fixed",
				fixed = nodeboxes_bottom,
			},
			after_dig_node = function(pos, oldnode, oldmetadata, digger)
				if
					core.get_node({ x = pos.x, y = pos.y + 1, z = pos.z }).name
					== "autoclose_doors:" .. doorname .. "_top_" .. side
				then
					core.remove_node({ x = pos.x, y = pos.y + 1, z = pos.z })
				end
			end,
			on_place = function(itemstack, placer, pointed_thing)
				local keys = placer:get_player_control()
				autoclose_doors.place_door(itemstack, placer, pointed_thing, doorname, keys["sneak"])
				return itemstack
			end,
			on_rightclick = function(pos, node, clicker)
				autoclose_doors.flip_door(pos, node, clicker, doorname, side)
			end,
			drop = "autoclose_doors:" .. doorname .. "_bottom_left",
			mesecons = {
				effector = {
					action_on = function(pos, node)
						local isClosed = getClosed(pos)
						if isClosed then
							autoclose_doors.flip_door(pos, node, nil, doorname, side, isClosed)
						end
					end,
					action_off = function(pos, node)
						local isClosed = getClosed(pos)
						if not isClosed then
							autoclose_doors.flip_door(pos, node, nil, doorname, side, isClosed)
						end
					end,
				},
			},
		})
	end
end

----- helper functions

function autoclose_doors.place_door(itemstack, placer, pointed_thing, name, forceright)
	local pointed = pointed_thing.under
	local pnode = core.get_node(pointed)
	local pname = pnode.name
	local rnodedef = core.registered_nodes[pname]

	if rnodedef then
		if rnodedef.on_rightclick then
			rnodedef.on_rightclick(pointed_thing.under, pnode, placer, itemstack)
			return
		end

		local pos1
		local pos2

		if rnodedef["buildable_to"] then
			pos1 = pointed
			pos2 = { x = pointed.x, y = pointed.y + 1, z = pointed.z }
		else
			pos1 = pointed_thing.above
			pos2 = { x = pointed_thing.above.x, y = pointed_thing.above.y + 1, z = pointed_thing.above.z }
		end

		local node_bottom = core.get_node(pos1)
		local node_top = core.get_node(pos2)

		if core.is_protected(pos1, placer:get_player_name()) then
			core.record_protection_violation(pos1, placer:get_player_name())
			return
		end

		if core.is_protected(pos2, placer:get_player_name()) then
			core.record_protection_violation(pos2, placer:get_player_name())
			return
		end

		if
			not autoclose_doors.get_nodedef_field(node_bottom.name, "buildable_to")
			or not autoclose_doors.get_nodedef_field(node_top.name, "buildable_to")
		then
			core.chat_send_player(placer:get_player_name(), S("Not enough space above that spot to place a door!"))
		else
			local fdir = core.dir_to_facedir(placer:get_look_dir())
			local p_tests = {
				{ x = pos1.x - 1, y = pos1.y, z = pos1.z },
				{ x = pos1.x, y = pos1.y, z = pos1.z + 1 },
				{ x = pos1.x + 1, y = pos1.y, z = pos1.z },
				{ x = pos1.x, y = pos1.y, z = pos1.z - 1 },
			}
			print("fdir=" .. fdir)
			local testnode = core.get_node(p_tests[fdir + 1])
			local side = "left"

			if string.find(testnode.name, "autoclose_doors:" .. name .. "_bottom_left") or forceright then
				side = "right"
			end

			core.add_node(pos1, { name = "autoclose_doors:" .. name .. "_bottom_" .. side, param2 = fdir })
			core.add_node(pos2, { name = "autoclose_doors:" .. name .. "_top_" .. side, param2 = fdir })
			core.get_meta(pos1):set_string("closed", "true")
			if not autoclose_doors.expect_infinite_stacks then
				itemstack:take_item()
				return itemstack
			end
		end
	end
end

-- to open a door, you switch left for right and subtract from param2, or vice versa right for left
-- that is to say open "right" doors become left door nodes, and open left doors right door nodes.
-- also adjusting param2 so the node is at 90 degrees.

function autoclose_doors.flip_door(pos, node, player, name, side, isClosed)
	if isClosed == nil then
		isClosed = getClosed(pos)
	end

	-- this is where we swap the isClosed status!
	-- i.e. if isClosed, we're adding an open door
	-- and if not isClosed, a closed door
	isClosed = not isClosed

	local rside
	local nfdir
	local ofdir = node.param2 or 0
	if side == "left" then
		rside = "right"
		nfdir = ofdir - 1
		if nfdir < 0 then
			nfdir = 3
		end
	else
		rside = "left"
		nfdir = ofdir + 1
		if nfdir > 3 then
			nfdir = 0
		end
	end
	local sound
	if isClosed then
		sound = "close"
	else
		sound = "open"
	end
	core.sound_play("autoclose_doors_" .. sound, {
		pos = pos,
		max_hear_distance = 5,
		gain = 2,
	})
	-- XXX: does the top half have to remember open/closed too?
	core.add_node(
		{ x = pos.x, y = pos.y + 1, z = pos.z },
		{ name = "autoclose_doors:" .. name .. "_top_" .. rside, param2 = nfdir }
	)
	core.add_node(pos, { name = "autoclose_doors:" .. name .. "_bottom_" .. rside, param2 = nfdir })

	if isClosed then
		core.get_meta(pos):set_string("closed", "true")
	else
		core.get_node_timer(pos):start(10)
		core.get_meta(pos):set_string("closed", "false")
	end
end
