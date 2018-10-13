--[[--------------------------------------------------------------------
    Copyright (C) 2018 Johnny C. Lam.
    See the file LICENSE.txt for copying permission.
--]]--------------------------------------------------------------------

local ADDON_NAME, addon = ...

local UnitGUID = UnitGUID

-- Register prefixes and handlers for broadcast messages.
addon:RegisterCommDispatch("LOC_BG", "OnBroadcastGainReceived")
addon:RegisterCommDispatch("LOC_BL", "OnBroadcastLossReceived")

local playerGUID = UnitGUID("player")

function addon:OnBroadcastGainReceived(prefix, message, channel, sender)
	if sender ~= self:GetNameByGUID(playerGUID) and self.db.profile.alert.regain then
		local ok, guid, role = self:Deserialize(message)
		if ok then
			local msg = self:CreateGainMessage("local", guid, role)
			self:SendEmphasizedMessage(msg)
			self:SendLocalMessage(msg)
		else
			-- If not ok, then guid contains the error message from :Deserialize().
			self:Debug("OnBroadcastgainReceived", guid, prefix, message, channel, sender)
		end
	end
end

function addon:OnBroadcastLossReceived(prefix, message, channel, sender)
	if sender ~= self:GetNameByGUID(playerGUID) then
		local ok, guid, role, spellID, effect, remaining = self:Deserialize(message)
		if ok then
			local msg = self:CreateLossMessage("local", guid, role, spellID, effect, remaining)
			self:SendEmphasizedMessage(msg)
			self:SendLocalMessage(msg)
		else
			-- If not ok, then guid contains the error message from :Deserialize().
			self:Debug("OnBroadcastLossReceived", guid, prefix, message, channel, sender)
		end
	end
end

function addon:BroadcastGain(guid, role)
	local zone = self:GetZone()
	local prefix = "LOC_BG"
	local channel = self:GetGroupChannelByZone(zone)
	if channel then
		local message = self:Serialize(guid, role)
		self:Debug("SendCommMessage", prefix, guid, role, channel)
		self:SendCommMessage(prefix, message, channel)
	end
end

function addon:BroadcastLoss(guid, role, spellID, effect, remaining)
	local zone = self:GetZone()
	local prefix = "LOC_BL"
	local channel = self:GetGroupChannelByZone(zone)
	if channel then
		local message = self:Serialize(guid, role, spellID, effect, remaining)
		self:Debug("SendCommMessage", prefix, guid, role, spellID, effect, remaining, channel)
		self:SendCommMessage(prefix, message, channel)
	end
end