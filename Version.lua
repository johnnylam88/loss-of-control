--[[--------------------------------------------------------------------
    Copyright (C) 2018 Johnny C. Lam.
    See the file LICENSE.txt for copying permission.
--]]--------------------------------------------------------------------

local ADDON_NAME, addon = ...

local format = format
local ipairs = ipairs
local next = next
local pairs = pairs
local tinsert = table.insert
local tsort = table.sort
local wipe = table.wipe
local GetAddOnMetadata = GetAddOnMetadata
local UnitGUID = UnitGUID

-- Register prefixes and handlers for version check messages.
addon:RegisterCommDispatch("LOC_V", "OnVersionCheckReceived")
addon:RegisterCommDispatch("LOC_VR", "OnVersionCheckReplyReceived")

local addonVersion = GetAddOnMetadata(ADDON_NAME, "Version")
local guid = UnitGUID("player")
local timer
local versions = {}
local t = {}

function addon:OnVersionCheckReceived(prefix, message, channel, sender)
	self:Debug("OnVersionCheckReceived", prefix, message, channel, sender)
	self:SendCommMessage("LOC_VR", addonVersion, channel)
end

function addon:OnVersionCheckReplyReceived(prefix, message, channel, sender)
	self:Debug("OnVersionCheckReplyReceived", prefix, message, channel, sender)
	versions[sender] = message
end

function addon:VersionCheck()
	if not timer then
		wipe(versions)
		local zone = self:GetZone()
		if zone ~= "world" and self:IsInGroup() then
			local prefix = "LOC_V"
			local channel = self:GetChannelByZone(zone)
			self:Debug("SendCommMessage", prefix, addonVersion, channel)
			self:SendCommMessage(prefix, addonVersion, channel)
		else
			-- Solo, so just add our own version as a reply.
			local name = self:GetNameByGUID(guid)
			versions[name] = addonVersion
		end
		timer = self:ScheduleTimer("PrintVersionCheck", 1)
	end
end

function addon:PrintVersionCheck()
	timer = nil
	if next(versions) then
		wipe(t)
		for sender, version in pairs(versions) do
			tinsert(t, format(">>> %s is using %s", sender, version))
		end
		tsort(t)
		for _, v in ipairs(t) do
			self:Print(v)
		end
	else
		self:Print(">>> No other users present.")
	end
end