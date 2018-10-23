--[[--------------------------------------------------------------------
    Copyright (C) 2018 Johnny C. Lam.
    See the file LICENSE.txt for copying permission.
--]]--------------------------------------------------------------------

local ADDON_NAME, addon = ...

-- GLOBALS: IsInGroup
-- GLOBALS: IsInInstance
-- GLOBALS: IsInRaid
local LE_PARTY_CATEGORY_INSTANCE = LE_PARTY_CATEGORY_INSTANCE

local zoneNames = {
	"arena",
	"battleground",
	"scenario",
	"dungeon",
	"raid",
	"lfg_dungeon",
	"lfg_raid",
	"world",
}

local zone = "world"

function addon:GetZone()
	return zone
end

function addon:UpdateZone()
	local newZone
	if IsInRaid(LE_PARTY_CATEGORY_INSTANCE) then
		newZone = "lfg_raid"
	elseif IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
		newZone = "lfg_dungeon"
	else
		-- instanceType is "arena", "none", "party", "pvp", "raid", or "scenario".
		local _, instanceType = IsInInstance()
		if instanceType == "arena" then
			newZone = "arena"
		elseif instanceType == "party" then
			newZone = "dungeon"
		elseif instanceType == "pvp" then
			newZone = "battleground"
		elseif instanceType == "scenario" then
			newZone = "scenario"
		elseif IsInRaid() then
			newZone = "raid"
		else
			newZone = "world"
		end
	end
	if zone ~= newZone then
		self:Debug(3, "UpdateZone", zone, newZone)
		zone = newZone
	end
end