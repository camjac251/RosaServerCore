---@type Plugin
local plugin = ...

local shared = plugin:require("shared")
local persistence = plugin:require("persistence")

---@param minutes integer
---@return string
local function getCleanReadableTime(minutes)
	local str = ""

	local hours = math.floor(minutes / 60)
	if hours > 0 then
		minutes = minutes - (hours * 60)

		local days = math.floor(hours / 24)
		if days > 0 then
			hours = hours - (days * 24)

			str = str .. days .. "d "
		end

		if hours > 0 then
			str = str .. hours .. "h "
		end
	end

	if minutes > 0 then
		str = str .. minutes .. "m"
	end

	return str
end

plugin.commands["/kick"] = {
	info = "Kick a player.",
	usage = "<phoneNumber/name> [reason]",
	canCall = function(ply)
		return ply.isConsole or isModeratorOrAdmin(ply)
	end,
	autoComplete = shared.autoCompletePlayerFirstArg,
	---@param ply Player
	---@param args string[]
	call = function(ply, _, args)
		assert(#args >= 1, "usage")

		local victim = findOnePlayer(table.remove(args, 1))
		if not victim.connection then
			error("Player not connected")
		end

		local reason = #args > 0 and table.concat(args, " ") or "No reason specified."

		victim.connection.timeoutTime = 50 * server.TPS

		adminLog("%s kicked %s (%s), reason: %s", ply.name, victim.name, dashPhoneNumber(victim.phoneNumber), reason)

		shared.discordEmbed({
			title = "Player Kicked",
			color = 0xF57C00,
			description = string.format(
				"**%s** kicked **%s** (%s)",
				ply.name,
				victim.name,
				dashPhoneNumber(victim.phoneNumber)
			),
			fields = {
				{
					name = "Reason",
					value = reason,
				},
			},
		})
	end,
}

plugin.commands["/punish"] = {
	info = "Ban an account based on previous bans.",
	usage = "<phoneNumber/name> [reason] [count]",
	canCall = function(ply)
		return ply.isConsole or isModeratorOrAdmin(ply)
	end,
	autoComplete = shared.autoCompleteAccountFirstArg,
	---@param ply Player
	---@param args string[]
	call = function(ply, _, args)
		assert(#args >= 1, "usage")

		local acc = findOneAccount(args[1])

		local phoneString = tostring(acc.phoneNumber)
		local reason = args[2] or "No reason specified."

		local count = assert(tonumber(args[3] or 1), "Count is not a number")
		count = math.floor(count)
		assert(count >= 1, "Invalid count")

		local persistentData = persistence.get()

		persistentData.punishments[phoneString] = persistentData.punishments[phoneString] or 0

		local banMinutes = 0
		for _ = 1, count do
			banMinutes = banMinutes + (45 * (2 ^ persistentData.punishments[phoneString]))
			persistentData.punishments[phoneString] = persistentData.punishments[phoneString] + 1
		end

		if not persistentData.warnings[phoneString] then
			persistentData.warnings[phoneString] = {}
		end

		table.insert(persistentData.warnings[phoneString], {
			reason = "Banned for " .. getCleanReadableTime(banMinutes) .. ": " .. reason,
			time = os.time(),
		})

		persistence.save()

		acc.banTime = acc.banTime + banMinutes

		adminLog(
			"%s punished %s (%s) @ %im (x%d), reason: %s",
			ply.name,
			acc.name,
			dashPhoneNumber(acc.phoneNumber),
			banMinutes,
			count,
			reason
		)

		local countString = "a punishment"
		if count > 1 then
			countString = count .. " punishments"
		end

		shared.discordEmbed({
			title = "Player Banned",
			color = 0xD32F2F,
			description = string.format(
				"**%s** added %s to **%s** (%s), ban set at **%s**",
				ply.name,
				countString,
				acc.name,
				dashPhoneNumber(acc.phoneNumber),
				getCleanReadableTime(banMinutes)
			),
			fields = {
				{
					name = "Reason",
					value = reason,
				},
			},
		})
	end,
}

plugin.commands["/unpunish"] = {
	info = "Remove punishments from an account.",
	usage = "<phoneNumber/name> [reason] [count]",
	canCall = function(ply)
		return ply.isConsole or isModeratorOrAdmin(ply)
	end,
	autoComplete = shared.autoCompleteAccountFirstArg,
	---@param ply Player
	---@param args string[]
	call = function(ply, _, args)
		assert(#args >= 1, "usage")

		local acc = findOneAccount(args[1])

		local phoneString = tostring(acc.phoneNumber)
		local reason = args[2] or "No reason specified."

		local count = assert(tonumber(args[3] or 1), "Count is not a number")
		count = math.floor(count)
		assert(count >= 1, "Invalid count")

		local persistentData = persistence.get()

		assert(
			persistentData.punishments[phoneString] and persistentData.punishments[phoneString] >= 1,
			"Account has no punishments"
		)
		assert(persistentData.punishments[phoneString] >= count, "Count is too high")

		local banMinutes = 0
		for _ = 1, count do
			banMinutes = banMinutes + 45 * (2 ^ (persistentData.punishments[phoneString] - 1))
			persistentData.punishments[phoneString] = persistentData.punishments[phoneString] - 1
		end

		persistence.save()

		acc.banTime = math.max(0, acc.banTime - banMinutes)

		adminLog(
			"%s unpunished %s (%s) @ %im (x%d), reason: %s",
			ply.name,
			acc.name,
			dashPhoneNumber(acc.phoneNumber),
			banMinutes,
			count,
			reason
		)

		local countString = "a punishment"
		if count > 1 then
			countString = count .. " punishments"
		end

		shared.discordEmbed({
			title = "Player Unbanned",
			color = 0x388E3C,
			description = string.format(
				"**%s** removed %s from **%s** (%s), deducted **%s**",
				ply.name,
				countString,
				acc.name,
				dashPhoneNumber(acc.phoneNumber),
				getCleanReadableTime(banMinutes)
			),
			fields = {
				{
					name = "Reason",
					value = reason,
				},
			},
		})
	end,
}

plugin.commands["/ban"] = {
	info = "Ban an account.",
	usage = "<phoneNumber/name> [minutes] [reason]",
	canCall = function(ply)
		return ply.isConsole or ply.isAdmin
	end,
	autoComplete = shared.autoCompleteAccountFirstArg,
	---@param ply Player
	---@param args string[]
	call = function(ply, _, args)
		assert(#args >= 1, "usage")
		local acc = findOneAccount(args[1])
		local banTime = args[2]
		local reason
		-- if banTime ends in a "m", remove it, and convert to minutes else if ends in a "h", convert to minutes else if banTime is p or permanent, set banTime to 0
		if banTime then
			-- if banTime doesn't end in a m h d w or permanent, assume the time is 0 and output reason
			if
				banTime:sub(-1) ~= "m"
				and banTime:sub(-1) ~= "h"
				and banTime:sub(-1) ~= "d"
				and banTime:sub(-1) ~= "w"
				and banTime:sub(-1) ~= "p"
			then
				reason = banTime
				banTime = 0
			else
				if banTime:sub(-1) == "m" then
					banTime = tonumber(banTime:sub(1, -2))
				elseif banTime:sub(-1) == "h" then
					banTime = tonumber(banTime:sub(1, -2)) * 60
				elseif banTime:sub(-1) == "d" then
					banTime = tonumber(banTime:sub(1, -2)) * 60 * 24
				elseif banTime:sub(-1) == "w" then
					banTime = tonumber(banTime:sub(1, -2)) * 60 * 24 * 7
				elseif banTime:sub(-1) == "y" then
					banTime = tonumber(banTime:sub(1, -2)) * 60 * 24 * 365
				elseif banTime:sub(-1) == ("p" or "perm" or "permanent") then
					banTime = 0
				end
				assert(tonumber(banTime), "Ban time is not a number")
				reason = args[3] or "No reason specified."
			end
		else
			reason = args[2] or "No reason specified."
			banTime = 0
		end

		local phoneString = tostring(acc.phoneNumber)

		local reason = #args > 0 and table.concat(args, " ") or "No reason specified."

		acc.banTime = banTime

		local persistentData = persistence.get()

		if not persistentData.bans[phoneString] then
			persistentData.bans[phoneString] = {}
		end

		table.insert(persistentData.bans[phoneString], {
			reason = reason,
			time = os.time(),
		})
		persistence.save()

		adminLog(
			"%s banned %s (%s) for %imin, reason: %s",
			ply.name,
			acc.name,
			dashPhoneNumber(acc.phoneNumber),
			banTime,
			reason
		)

		shared.discordEmbed({
			title = "Player Banned",
			color = 0xD32F2F,
			description = string.format(
				"**%s** manually banned **%s** (%s) for **%s**",
				ply.name,
				acc.name,
				dashPhoneNumber(acc.phoneNumber),
				getCleanReadableTime(banTime)
			),
			fields = {
				{
					name = "Reason",
					value = reason,
				},
			},
		})
	end,
}

plugin.commands["/unban"] = {
	info = "Unban an account.",
	usage = "<phoneNumber/name> [reason]",
	canCall = function(ply)
		return ply.isConsole or ply.isAdmin
	end,
	autoComplete = shared.autoCompleteAccountFirstArg,
	---@param ply Player
	---@param args string[]
	call = function(ply, _, args)
		assert(#args >= 1, "usage")

		local acc = findOneAccount(table.remove(args, 1))

		local reason = #args > 0 and table.concat(args, " ") or "No reason specified."

		acc.banTime = 0

		adminLog("%s unbanned %s (%s), reason: %s", ply.name, acc.name, dashPhoneNumber(acc.phoneNumber), reason)

		shared.discordEmbed({
			title = "Player Unbanned",
			color = 0x388E3C,
			description = string.format(
				"**%s** manually unbanned %s (%s)",
				ply.name,
				acc.name,
				dashPhoneNumber(acc.phoneNumber)
			),
			fields = {
				{
					name = "Reason",
					value = reason,
				},
			},
		})
	end,
}

plugin.commands["/kill"] = {
	info = "Kill a player.",
	usage = "<phoneNumber/name>",
	canCall = function(ply)
		return ply.isConsole or ply.isAdmin
	end,
	autoComplete = shared.autoCompletePlayerFirstArg,
	---@param ply Player
	---@param args string[]
	call = function(ply, _, args)
		assert(#args >= 1, "usage")

		local victim = findOnePlayer(table.remove(args, 1))

		local victimMan = victim.human
		assert(victimMan, "Victim not spawned in")

		victimMan.isAlive = false

		adminLog("%s killed %s (%s)", ply.name, victim.name, dashPhoneNumber(victim.phoneNumber))
	end,
}
