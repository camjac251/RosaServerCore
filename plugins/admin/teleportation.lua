---@type Plugin
local plugin = ...

function MoveItem(item, difference)
	item.pos:add(difference)
	item.rigidBody.pos:add(difference)
end

function TeleportHumanWithItems(man, pos)
	for i2 = 0, 15 do
		local rb = man:getRigidBody(i2)
		if rb.data.isGrabbing then
			rb.data.isGrabbing = nil
		end
		if rb.data.bond ~= nil then
			rb.data.bond:remove()
			rb.data.bond = nil
		end
	end
	local oldPos = man.pos:clone()
	oldPos:mult(-1.0)
	local difference = pos:clone()
	difference:add(oldPos)

	man:teleport(pos)
	man:setVelocity(Vector(0, 0, 0))
	for i = 0, 1 do
		local item = man:getInventorySlot(i).primaryItem
		if item then
			MoveItem(item, difference)
		end
	end
end

plugin.commands["/find"] = {
	info = "Teleport to a player.",
	usage = "<phoneNumber/name>",
	canCall = function(ply)
		return ply.isAdmin
	end,
	---@param ply Player
	---@param man Human?
	---@param args string[]
	call = function(ply, man, args)
		assert(#args >= 1, "usage")
		assert(man, "Not spawned in")

		local victim = findOnePlayer(table.remove(args, 1))
		local victimMan = victim.human
		assert(victimMan, "Victim not spawned in")

		-- Forward yaw plus 180 degrees
		local yaw = victimMan.viewYaw + math.pi / 2
		local distance = 3

		local pos = victimMan.pos:clone()
		pos.x = pos.x + (distance * math.cos(yaw))
		pos.z = pos.z + (distance * math.sin(yaw))

		if man.vehicle ~= nil then
			man.vehicle = nil
		end
		TeleportHumanWithItems(man, pos)

		if victimMan.vehicle ~= nil then
			man.vehicle = victimMan.vehicle
			man.vehicleSeat = 3
		end

		adminLog("%s found %s (%s)", ply.name, victim.name, dashPhoneNumber(victim.phoneNumber))
	end,
}

plugin.commands["/fetch"] = {
	info = "Teleport a player to you.",
	usage = "<phoneNumber/name>",
	canCall = function(ply)
		return ply.isAdmin
	end,
	---@param ply Player
	---@param man Human?
	---@param args string[]
	call = function(ply, man, args)
		assert(#args >= 1, "usage")
		assert(man, "Not spawned in")

		local victim = findOnePlayer(table.remove(args, 1))

		local victimMan = victim.human
		assert(victimMan, "Victim not spawned in")

		-- Forward yaw
		local yaw = man.viewYaw - math.pi / 2
		local distance = 3

		local pos = man.pos:clone()
		pos.x = pos.x + (distance * math.cos(yaw))
		pos.z = pos.z + (distance * math.sin(yaw))

		if victimMan.vehicle ~= nil then
			victimMan.vehicle = nil
		end

		TeleportHumanWithItems(victimMan, pos)
		if man.vehicle ~= nil then
			victimMan.vehicle = man.vehicle
			victimMan.vehicleSeat = 3
		end
		adminLog("%s fetched %s (%s)", ply.name, victim.name, dashPhoneNumber(victim.phoneNumber))
	end,
}

plugin.commands["/teleport"] = {
	info = "TP",
	alias = { "/tp" },

	usage = "<phoneNumber/name> <phoneNumber/name>",
	canCall = function(ply)
		return ply.isAdmin
	end,
	autoComplete = autoCompleteAccountFirstArg,
	---@param ply Player
	---@param args string[]

	call = function(ply, _, args)
		assert(#args >= 1, "usage")
		local p1 = findOnePlayer(args[1])
		local p2 = findOnePlayer(args[2])
		local player1 = p1.human
		local player2 = p2.human

		assert(player1, p1.name .. " is not spawned in")
		assert(player2, p1.name .. " is not spawned in")

		-- Forward yaw
		local yaw = player2.viewYaw - math.pi / 2
		local distance = 3

		local pos = player2.pos:clone()
		pos.x = pos.x + (distance * math.cos(yaw))
		pos.z = pos.z + (distance * math.sin(yaw))

		if player1.vehicle ~= nil then
			player1.vehicle = nil
		end

		if player2.vehicle ~= nil then
			player1.vehicle = player2.vehicle
		end

		TeleportHumanWithItems(player1, pos)
	end,
}

plugin.commands["/hide"] = {
	info = "Teleport to an inaccessible room.",
	canCall = function(ply)
		return ply.isAdmin
	end,
	---@param ply Player
	---@param man Human?
	call = function(ply, man)
		assert(man, "Not spawned in")

		local level = server.loadedLevel
		local pos

		if level == "test2" then
			pos = Vector(1505, 33.1, 1315)
		else
			error("Unsupported map")
		end

		TeleportHumanWithItems(man, pos)

		adminLog("%s hid", ply.name)
	end,
}

plugin.commands["/go"] = {
	info = "Go to where you are pointing.",
	canCall = function(ply)
		return ply.isConsole or isModeratorOrAdmin(ply)
	end,
	---@param ply Player
	---@param man Human?
	call = function(ply, man)
		assert(man, "Not spawned in")

		local dist = 10000

		local yaw = man.viewYaw - math.pi / 2
		local pitch = -man.viewPitch

		local pos = man:getRigidBody(3).pos
		local pos2 = Vector(
			pos.x + (dist * math.cos(yaw) * math.cos(pitch)),
			pos.y + (dist * math.sin(pitch)),
			pos.z + (dist * math.sin(yaw) * math.cos(pitch))
		)

		local ray = physics.lineIntersectLevel(pos, pos2, false)

		if ray.hit then
			local NewPos = ray.pos
			pos.y = pos.y + 2
			TeleportHumanWithItems(man, NewPos)
			man:addVelocity(Vector(-0.025, 0, 0))
		end
		adminLog("%s used go and went to a new position", ply.name)
	end,
}
