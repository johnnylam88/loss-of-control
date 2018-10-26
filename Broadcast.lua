--[[--------------------------------------------------------------------
    Copyright (C) 2018 Johnny C. Lam.
    See the file LICENSE.txt for copying permission.
--]]--------------------------------------------------------------------

local ADDON_NAME, addon = ...

-- GLOBALS: UnitGUID

-- Register prefixes and handlers for broadcast messages.
local CONTROL_GAIN_V1_PREFIX = "LOC_BG"
local CONTROL_GAIN_V2_PREFIX = "LOC_BG2"
local CONTROL_LOST_V1_PREFIX = "LOC_BL"
local CONTROL_LOST_V2_PREFIX = "LOC_BL2"

-- Point to latest versions of the gain and loss prefixes.
local CONTROL_GAIN_PREFIX = CONTROL_GAIN_V2_PREFIX
local CONTROL_LOST_PREFIX = CONTROL_LOST_V2_PREFIX

addon:RegisterCommDispatch(CONTROL_GAIN_V1_PREFIX, "OnBroadcastGainReceived")
addon:RegisterCommDispatch(CONTROL_GAIN_V2_PREFIX, "OnBroadcastGainReceived")
addon:RegisterCommDispatch(CONTROL_LOST_V1_PREFIX, "OnBroadcastLossReceived")
addon:RegisterCommDispatch(CONTROL_LOST_V2_PREFIX, "OnBroadcastLossReceived")

local playerGUID = UnitGUID("player")

function addon:OnBroadcastGainReceived(prefix, message, channel, sender)
	if self.db.profile.alert.enable and self.db.profile.alert.regain
			and sender ~= self:GetNameByGUID(playerGUID) then
		local ok, guid, role, duration
		if prefix == CONTROL_GAIN_V1_PREFIX then
			-- Version 1 "gain" messages have no duration.
			ok, guid, role = self:Deserialize(message)
			duration = 3 -- pretend the Loss Of Control duration is 3 seconds
		else
			ok, guid, role, duration = self:Deserialize(message)
		end
		if ok then
			if duration >= self.db.profile.alert.regainThreshold then
				local msg = self:CreateGainMessage("local", guid, role)
				if self.db.profile.alert.raidWarning then
					self:SendEmphasizedMessage(msg)
				end
				if self.db.profile.alert.chat then
					self:SendLocalMessage(msg)
				end
			end
		else
			-- If not ok, then guid contains the error message from :Deserialize().
			self:Debug(2, "OnBroadcastgainReceived", guid, prefix, message, channel, sender)
		end
	end
end

function addon:OnBroadcastLossReceived(prefix, message, channel, sender)
	if self.db.profile.alert.enable and sender ~= self:GetNameByGUID(playerGUID) then
		local ok, guid, role, spellID, effect, remaining, duration
		if prefix == CONTROL_LOST_V1_PREFIX then
			-- Version 1 "gain" messages have no duration.
			ok, guid, role, spellID, effect, remaining = self:Deserialize(message)
			duration = 3 -- pretend the Loss Of Control duration is 3 seconds
		else
			ok, guid, role, spellID, effect, remaining, duration = self:Deserialize(message)
		end
		if ok then
			if duration >= self.db.profile.alert.threshold then
				local msg = self:CreateLossMessage("local", guid, role, spellID, effect, remaining)
				if self.db.profile.alert.raidWarning then
					self:SendEmphasizedMessage(msg)
				end
				if self.db.profile.alert.chat then
					self:SendLocalMessage(msg)
				end
			end
		else
			-- If not ok, then guid contains the error message from :Deserialize().
			self:Debug(2, "OnBroadcastLossReceived", guid, prefix, message, channel, sender)
		end
	end
end

function addon:BroadcastGain(guid, role, duration)
	local zone = self:GetZone()
	local prefix = CONTROL_GAIN_PREFIX
	local channel = self:GetGroupChannelByZone(zone)
	if channel then
		local message = self:Serialize(guid, role)
		self:Debug(2, "SendCommMessage", prefix, guid, role, channel)
		self:SendCommMessage(prefix, message, channel)
	end
end

function addon:BroadcastLoss(guid, role, spellID, effect, remaining, duration)
	local zone = self:GetZone()
	local prefix = CONTROL_LOST_PREFIX
	local channel = self:GetGroupChannelByZone(zone)
	if channel then
		local message = self:Serialize(guid, role, spellID, effect, remaining, duration)
		self:Debug(2, "SendCommMessage", prefix, guid, role, spellID, effect, remaining, channel)
		self:SendCommMessage(prefix, message, channel)
	end
end