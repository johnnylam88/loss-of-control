--[[--------------------------------------------------------------------
    Copyright (C) 2018 Johnny C. Lam.
    See the file LICENSE.txt for copying permission.
--]]--------------------------------------------------------------------

local ADDON_NAME, addon = ...

local ipairs = ipairs
local pairs = pairs
local tinsert = table.insert
local tostring = tostring
local IsInGroup = IsInGroup
local IsInRaid = IsInRaid
local UnitClass = UnitClass
local UnitExists = UnitExists
local UnitGUID = UnitGUID
local UnitName = UnitName
local MAX_PARTY_MEMBERS = MAX_PARTY_MEMBERS -- Interface/FrameXML/PartyMemberFrame.lua
local MAX_RAID_MEMBERS = MAX_RAID_MEMBERS -- Interface/FrameXML/RaidFrame.lua

---------------------------------------------------------------------
-- Set whether the player is currently in a group.

local grouped -- true if the player is in a group, or nil otherwise.

function addon:IsInGroup()
	return grouped
end

function addon:UpdateInGroup()
	local inGroup = IsInGroup()
	if grouped ~= inGroup then
		self:Debug("UpdateInGroup", tostring(grouped), tostring(inGroup))
		grouped = inGroup
		self:UpdateLossOfControl()
	end
end

---------------------------------------------------------------------
-- Update the mappings from GUID <==> unit <==> name <==> class.

local guidByUnit = {} -- guidByUnit[unit] = guid
local classByGUID = {} -- classByGUID[guid] = class
local nameByGUID = {} -- nameByGUID[guid] = name
local realmByGUID = {} -- realmByGUID[guid] = realm
local unitByGUID = {} -- unitByGUID[guid] = unit

function addon:GetClassByGUID(guid)
	return classByGUID[guid]
end

function addon:GetFullNameByGUID(guid)
	local name = nameByGUID[guid]
	local realm = realmByGUID[guid]
	if realm then
		return name .. "-" .. realm
	else
		return name
	end
end

function addon:GetNameByGUID(guid)
	return nameByGUID[guid]
end

function addon:GetGUIDByUnit(unit)
	return guidByUnit[unit]
end

function addon:GetUnitByGUID(guid)
	return unitByGUID[guid]
end

do
	local partyUnits = {}
	local raidUnits = {}

	tinsert(partyUnits, "player")
	for i = 1, MAX_PARTY_MEMBERS do
		tinsert(partyUnits, "party" .. i)
	end
	for i = 1, MAX_RAID_MEMBERS do
		tinsert(raidUnits, "raid" .. i)
	end

	local nonexistentGUID = {}
	local updated

	function addon:UpdateUnit(unit)
		local guid = UnitGUID(unit)

		if guid then
			nonexistentGUID[guid] = nil

			local _, class = UnitClass(unit)
			local name, realm = UnitName(unit)
			if realm == "" then realm = nil end

			if classByGUID[guid] ~= class or nameByGUID[guid] ~= name or realmByGUID[guid] ~= realm
					or unitByGUID[guid] ~= unit or guidByUnit[unit] ~= guid then
				self:Debug("UpdateUnit", tostring(classByGUID[guid]), tostring(class),
					tostring(nameByGUID[guid]), tostring(name), tostring(realmByGUID[guid]), tostring(realm),
					tostring(unitByGUID[guid]), unit, tostring(guidByUnit[unit]), guid)
				classByGUID[guid] = class
				nameByGUID[guid] = name
				realmByGUID[guid] = realm
				unitByGUID[guid] = unit
				guidByUnit[unit] = guid
				updated = true
			end
		else
			updated = true
		end
	end

	function addon:UpdateGroup()
		for guid in pairs(unitByGUID) do
			nonexistentGUID[guid] = true
		end

		local units = IsInRaid() and raidUnits or partyUnits
		for _, unit in ipairs(units) do
			if UnitExists(unit) then
				self:UpdateUnit(unit)
			end
		end
		for guid in pairs(nonexistentGUID) do
			classByGUID[guid] = nil
			nameByGUID[guid] = nil
			realmByGUID[guid] = nil
			unitByGUID[guid] = nil
			nonexistentGUID[guid] = nil
		end
		for unit, guid in pairs(guidByUnit) do
			if unitByGUID[guid] ~= unit then
				guidByUnit[unit] = nil
				updated = true
			end
		end
		if updated then
			self:Debug("UpdateGroup")
			updated = nil
		end
		self:UpdateInGroup()
	end
end