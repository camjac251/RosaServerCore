---@type Plugin
local plugin = ...
local persistence = {}

local json = require("main.json")

local persistentData
local persistenceFile = "admin-persistence.json"

function persistence.get()
	return persistentData
end

function persistence.save()
	local f = io.open(persistenceFile, "w")
	if f then
		f:write(json.encode(persistentData))
		f:close()
		plugin:print("Saved persistence")
	end
end

function persistence.load()
	local f = io.open(persistenceFile, "r")
	if f then
		local data = json.decode(f:read("*all"))
		persistentData.claims = data.claims or {}
		persistentData.moderators = data.moderators or {}
		persistentData.punishments = data.punishments or {}
		persistentData.bans = data.bans or {}
		persistentData.warnings = data.warnings or {}

		f:close()
		plugin:print("Loaded persistence")
	end
end

plugin:addEnableHandler(function()
	persistentData = {
		claims = {},
		moderators = {},
		punishments = {},
		bans = {},
		warnings = {},
	}

	persistence.load()
end)

plugin:addDisableHandler(function()
	persistence.save()
	persistentData = nil
end)

return persistence
