--[[--------------------------------------------------------------------
    Copyright (C) 2018 Johnny C. Lam.
    See the file LICENSE.txt for copying permission.
--]]--------------------------------------------------------------------

local ADDON_NAME, addon = ...

-- GLOBALS: GetInspectSpecialization
-- GLOBALS: NotifyInspect
-- GLOBALS: UnitGUID

local inspectPending = nil
local playerGUID = UnitGUID("player")

function addon:QueueRoleCheck()
	if not inspectPending then
		self:Debug("QueueRoleCheck")
		-- Register INSPECT_READY to catch when the inspection request is ready.
		self:RegisterEvent("INSPECT_READY")
		inspectPending = true
		NotifyInspect("player")
	end
end

function addon:INSPECT_READY(event, guid)
	if guid == playerGUID then
		self:Debug(event, guid)
		-- Unregister INSPECT_READY to avoid processing additional events.
		self:UnregisterEvent("INSPECT_READY")
		inspectPending = nil
		self:UpdateRole()
	end
end

-- Map return values from GetInspectSpecialization() to roles.
-- ref: https://www.wowpedia.org/API_GetInspectSpecialization
local roleBySpecialization = {
	-- Death Knight
	[250] = "tank",	-- Blood
	[251] = "damager",	-- Frost
	[252] = "damager",	-- Unholy
	-- Demon Hunter
	[577] = "damager",	-- Havoc
	[581] = "tank",	-- Vengeance
	-- Druid
	[102] = "damager",	-- Balance
	[103] = "damager",	-- Feral
	[104] = "tank",	-- Guardian
	[105] = "healer",	-- Restoration
	-- Hunter
	[253] = "damager",	-- Beast Mastery
	[254] = "damager",	-- Marksmanship
	[255] = "damager",	-- Survival
	-- Mage
	[62] = "damager",	-- Arcane
	[63] = "damager",	-- Fire
	[64] = "damager",	-- Frost
	-- Monk
	[268] = "tank",	-- Brewmaster
	[270] = "healer",	-- Mistweaver
	[269] = "damager",	-- Windwalker
	-- Paladin
	[65] = "healer",	-- "Holy
	[66] = "tank",	-- "Protection
	[67] = "damager",	-- "Retribution
	-- Priest
	[256] = "healer",	-- Discipline
	[257] = "healer",	-- Holy
	[258] = "damager",	-- Shadow
	-- Rogue
	[259] = "damager",	-- Assassination
	[260] = "damager",	-- Outlaw
	[261] = "damager",	-- Subtlety
	-- Shaman
	[262] = "damager",	-- Elemental
	[263] = "damager",	-- Enhancement
	[264] = "healer",	-- Restoration
	-- Warlock
	[265] = "damager",	-- Affliction
	[266] = "damager",	-- Demonology
	[267] = "damager",	-- Destruction
	-- Warrior
	[71] = "damager",	-- Arms
	[72] = "damager",	-- Fury
	[73] = "tank",	-- Protection
}

-- current role based on player's specialization ("tank", "damager", "healer").
local role = "damager"

function addon:GetRole()
	return role
end

function addon:UpdateRole()
	local specialization = GetInspectSpecialization("player")
	local newRole = specialization and roleBySpecialization[specialization] or "damager"
	if role ~= newRole then
		self:Debug("UpdateRole", role, newRole)
		role = newRole
		self:UpdateLossOfControl()
	end
end