--[[--------------------------------------------------------------------
    Copyright (C) 2018 Johnny C. Lam.
    See the file LICENSE.txt for copying permission.
--]]--------------------------------------------------------------------

local ADDON_NAME, addon = ...
local L = addon.L

---------------------------------------------------------------------
-- Global functions and constants.

local floor = math.floor
local format = string.format
local gmatch = string.gmatch
local ipairs = ipairs
local pairs = pairs
local setmetatable = setmetatable
local strfind = string.find
local strjoin = strjoin
local strlen = string.len
local strlower = string.lower
local strtrim = strtrim
local tonumber = tonumber
local tostringall = tostringall
local type = type
local unpack = unpack
-- GLOBALS: _G
-- GLOBALS: GetAddOnMetadata
-- GLOBALS: GetSchoolString
-- GLOBALS: GetSpellLink
-- GLOBALS: GetTime
-- GLOBALS: InterfaceOptionsFrame_OpenToCategory
-- GLOBALS: IsInGroup
-- GLOBALS: LibStub
-- GLOBALS: UnitDebuff
-- GLOBALS: UnitGUID
-- GLOBALS: UnitIsPlayer
local C_LossOfControl = C_LossOfControl
local C_LossOfControl_GetEventInfo = C_LossOfControl.GetEventInfo
local C_LossOfControl_GetNumEvents = C_LossOfControl.GetNumEvents

local addonName = GetAddOnMetadata(ADDON_NAME, "Title")
_G[ADDON_NAME] = LibStub("AceAddon-3.0"):NewAddon(addon, addonName or ADDON_NAME,
	"AceComm-3.0", "AceConsole-3.0", "AceEvent-3.0", "AceSerializer-3.0", "AceTimer-3.0")

---------------------------------------------------------------------

-- Debugging code from Grid by Phanx.
-- https://github.com/phanx-wow/Grid

function addon:Debug(level, str, ...)
	if not self.db.global.debug then return end
	if not level then return end
	if not str or strlen(str) == 0 then return end

	if level <= self.db.global.debuglevel then
		if (...) then
			if type(str) == "string" and (strfind(str, "%%%.%d") or strfind(str, "%%[dfqsx%d]")) then
				str = format(str, ...)
			else
				str = strjoin(" ", str, tostringall(...))
			end
		end
		local name = self.moduleName or self.name or ADDON_NAME
		local frame = _G[addon.db.global.debugFrame]
		self:Print(frame, str)
	end
end

---------------------------------------------------------------------
-- Initialization.

-- Reference to the frame registered into the Interface Options panel.
local settingsFrame

local MooSpec = LibStub("MooSpec-1.0")
local MooUnit = LibStub("MooUnit-1.0")
local MooZone = LibStub("MooZone-1.0")

local CHAT_COMMAND = "loc"

function addon:OnInitialize()
	local defaultDB = self:GetDefaultDB()
	local options = self:GetOptions()

	self.db = LibStub("AceDB-3.0"):New("LossOfControlDB", defaultDB, true)
	options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)

	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable(self.name, options)
	settingsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(self.name)
end

function addon:OnEnable()
	self:Debug(3, "OnEnable")
	self:RegisterChatCommand(CHAT_COMMAND, "ChatCommand")
	self:RegisterEvent("LOSS_OF_CONTROL_UPDATE", "UpdateLossOfControl")
	self:RegisterEvent("UNIT_AURA", "OnUnitAura")
	MooSpec.RegisterCallback(self, "MooSpec_UnitRoleChanged", "OnUnitRoleChanged")
	MooZone.RegisterCallback(self, "MooZone_ZoneChanged", "UpdateLossOfControl")
	self:RegisterAllComm()
end

function addon:OnDisable()
	self:Debug(3, "OnDisable")
	self:UnregisterChatCommand(CHAT_COMMAND)
	self:UnregisterEvent("LOSS_OF_CONTROL_UPDATE")
	self:UnregisterEvent("UNIT_AURA")
	MooSpec.UnregisterCallback(self, "MooSpec_UnitRoleChanged")
	MooZone.UnregisterCallback(self, "MooZone_ZoneChanged")
end

function addon:OnUnitAura(event, unit)
	if unit == "player" then
		self:UpdateLossOfControl(event)
	end
end

do
	local playerGUID = UnitGUID("player")
	local playerRole = "damager" -- "tank", "healer", "damager"

	function addon:GetRole()
		return playerRole
	end

	function addon:OnUnitRoleChanged(event, guid, unit, oldRole, newRole)
		if guid == playerGUID then
			if newRole == "melee" or newRole == "ranged" then
				newRole = "damager"
			end
			if playerRole ~= newRole then
				self:Debug(2, "Player role changed:", playerRole, newRole)
				playerRole = newRole
				self:UpdateLossOfControl(event)
			end
		end
	end
end

---------------------------------------------------------------------
-- Register prefixes and message handlers for AceComm-3.0.

do
	local dispatch = {}

	function addon:RegisterCommDispatch(prefix, handler)
		dispatch[prefix] = handler
	end

	function addon:RegisterAllComm()
		for prefix, handler in pairs(dispatch) do
			self:RegisterComm(prefix, handler)
		end
	end
end

---------------------------------------------------------------------

function addon:ChatCommand(input)
	if input then
		input = strtrim(input)
	end
	if not input or input == "" then
		self:OpenSettingsFrame()
	else
		local iterator = gmatch(strlower(input), "%w+")
		local word = iterator()
		if word == "version" then
			local version = GetAddOnMetadata(ADDON_NAME, "Version")
			if version == "@" .. "project-version" .. "@" then
				self:Print("developer version")
			else
				self:Print(version)
			end
		elseif word == "announce" then
			-- Toggle announce options.
			local value = not self.db.profile.announce.enable
			self.db.profile.announce.enable = value
			if value then
				self:Print(L["Announcements to the group are on."])
			else
				self:Print(L["Announcements to the group are off."])
			end
		elseif word == "alert" then
			-- Toggle alert options.
			local value = not self.db.profile.alert.enable
			self.db.profile.alert.enable = value
			if value then
				self:Print(L["Alerts from the group are on."])
			else
				self:Print(L["Alerts from the group are off."])
			end
		elseif word == "debug" then
			word = iterator()
			if word then
				local value = tonumber(word)
				if value then
					-- Clamp the debug level.
					if value < 1 then
						value = 1
					elseif value > 3 then
						value = 3
					end
					self.db.global.debug = true
					self.db.global.debuglevel = value
					self:Print(format(L["Debugging is on (level %s)."], value))
				end
			else
				-- Toggle debug option.
				local value = not self.db.global.debug
				self.db.global.debug = value
				if value then
					self:Print(format(L["Debugging is on (level %s)."], self.db.global.debuglevel))
				else
					self:Print(L["Debugging is off."])
				end
			end
		elseif word == "ping" then
			self:VersionCheck() -- from Version.lua
		end
	end
end

function addon:OpenSettingsFrame()
	-- Need to open it twice as the first time just opens up the Interface frame.
	if settingsFrame then
		InterfaceOptionsFrame_OpenToCategory(settingsFrame)
		InterfaceOptionsFrame_OpenToCategory(settingsFrame)
	end
end

---------------------------------------------------------------------

do
	-- Map "locType" (first return value of C_LossOfControl.GetEventInfo()) to option name.
	local LOC_OPTION = {
		CHARM = "charm",
		CONFUSE = "confuse",
		DISARM = "disarm",
		FEAR = "fear",
		FEAR_MECHANIC = "fear",
		PACIFY = "pacify",
		PACIFYSILENCE = {
			"pacify",
			"silence",
		},
		POSSESS = "possess",
		ROOT = "root",
		SCHOOL_INTERRUPT = "interrupt",
		SILENCE = "silence",
		STUN = "stun",
		STUN_MECHANIC = "stun",
	}

	-- Set priorities for Loss Of Control events based on their severity for healers.
	local LOC_PRIORITY = {
		-- Can move and cast spells.
		DISARM = 10,
		-- Cannot move, can cast spells.
		ROOT = 20,
		-- Can move, cannot cast spells.
		SCHOOL_INTERRUPT = 30,
		SILENCE = 30,
		-- Cannot move, cannot cast spells.
		CHARM = 40,
		CONFUSE = 40,
		FEAR = 40,
		FEAR_MECHANIC = 40,
		PACIFY = 40,
		PACIFYSILENCE = 40,
		POSSESS = 40,
		STUN = 40,
		STUN_MECHANIC = 40,
	}

	-- Auras that cause Loss Of Control but are not treated as such by the game.
	local LOC_AURA = {
		[  3589] = { "SILENCE", L["Silenced"] }, -- Deafening Screech
		[ 10730] = { "PACIFY", L["Pacified"] }, -- Pacify
		[ 12480] = { "CHARM", L["Charmed"] }, -- Hex of Jammal'an
		[ 12890] = { "PACIFY", L["Invulnerable"] }, -- Deep Slumber
		[ 17244] = { "CHARM", L["Charmed"] }, -- Possess
		[ 17307] = { "STUN", L["Stunned"] }, -- Knockout
		[ 22519] = { "STUN", L["Stunned"] }, -- Ice Nova
		[ 22651] = { "STUN", L["Stunned"] }, -- Sacrifice
		[ 34661] = { "STUN", L["Stunned"] }, -- Sacrifice
		[ 48278] = { "STUN", L["Stunned"] }, -- Paralyze
		[ 48400] = { "STUN", L["Stunned"] }, -- Frost Tomb
		[ 49735] = { "STUN", L["Stunned"] }, -- Terrifying Countenance
		[ 52086] = { "ROOT", L["Rooted"] }, -- Web Wrap
		[ 52087] = { "STUN", L["Stunned"] }, -- Web Wrap
		[ 53472] = { "STUN", L["Stunned"] }, -- Pound
		[ 55959] = { "STUN", L["Stunned"] }, -- Embrace of the Vampyr
		[ 58526] = { "PACIFY", L["Pacified"] }, -- Azure Bindings
		[ 59433] = { "STUN", L["Stunned"] }, -- Pound (Heroic)
		[ 59513] = { "STUN", L["Stunned"] }, -- Embrace of the Vampyr (Heroic)
		[ 74720] = { "CONFUSE", L["Disoriented"] }, -- Pound
		[ 76312] = { "STUN", L["Stunned"] }, -- Earthsmash
		[ 86780] = { "STUN", L["Stunned"] }, -- Shadow Prison
		[120160] = { "CONFUSE", L["Disoriented"] }, -- Conflagrate
		[149955] = { "STUN", L["Stunned"] }, -- Devouring Blackness
		[150485] = { "ROOT", L["Rooted"] }, -- Web Wrap
		[150486] = { "STUN", L["Stunned"] }, -- Web Wrap
		[150634] = { "STUN", L["Stunned"] }, -- Leviathan's Grip
		[178077] = { "STUN", L["Stunned"] }, -- Frost Prison
		[179056] = { "PACIFY", L["Invulnerable"] }, -- Frost Prison
		[202310] = { "STUN", L["Stunned"] }, -- Hyper Zap-o-matic Ultimate Mark III
		[206413] = { "STUN", L["Stunned"] }, -- Shriek of the Tidemistress
		[209393] = { "STUN", L["Stunned"] }, -- Sigil of Binding
		[214298] = { "STUN", L["Stunned"] }, -- Demonic Bindings
		[223322] = { "STUN", L["Stunned"] }, -- Absorbing Essence
		[223451] = { "STUN", L["Stunned"] }, -- Absorbing Essence
		[227072] = { "STUN", L["Stunned"] }, -- Fel Domination
		[228290] = { "ROOT", L["Rooted"] }, -- Personal Egg
		[234263] = { "STUN", L["Stunned"] }, -- Unconscious
		[234679] = { "STUN", L["Stunned"] }, -- Acquire the Gift
		[235784] = { "STUN", L["Stunned"] }, -- Grasping Fel
		[238619] = { "PACIFY", L["Pacified"] }, -- Piercing Screech
		[241273] = { "CONFUSE", L["Disoriented"] }, -- Piercing Screech
		[251971] = { "STUN", L["Stunned"] }, -- Abyssal Smash
		-- Collossal Strike
	}

	function addon:IsWatchedEvent(locType, spellID)
		local role = self:GetRole()
		local option = LOC_OPTION[locType]
		local watched
		if not option then
			local link = spellID and GetSpellLink(spellID)
			if link then
				self:Debug(1, L["Unknown Loss Of Control event:"], locType, link)
			else
				self:Debug(1, L["Unknown Loss Of Control event:"], locType, spellID)
			end
			watched = true
		elseif type(option) == "string" and self.db.profile.announce[role][option] then
			watched = true
		elseif type(option) == "table" then
			for _, opt in ipairs(option) do
				if self.db.profile.announce[role][opt] then
					watched = true
					break
				end
			end
		end
		return watched
	end

	-- We track the highest priority Loss of Control event with the latest expiration time.
	local locStart      -- Time at which the Loss of Control began.
	local locDuration   -- Total duration of the Loss of Control.
	local locExpiration -- Expiration time for the Loss Of Control event.
	local locSpellID    -- ID of spell that triggered the Loss Of Control event.
	local locEffect     -- Descriptive text of effect caused by the Loss Of Control event.
	local locPriority   -- Priority of the Loss Of Control event.

	function addon:GetStartTime() return locStart end
	function addon:GetExpirationTime() return locExpiration end
	function addon:GetDuration() return locDuration end
	function addon:GetSpellID() return locSpellID end
	function addon:GetEffect() return locEffect end

	function addon:ResetLossOfControl()
		locStart = nil
		locDuration = nil
		locExpiration = nil
		locSpellID = nil
		locEffect = nil
		locPriority = nil
	end

	function addon:AddEvent(spellID, text, priority, duration, expirationTime)
		if not locPriority or locPriority <= priority then
			local changed = false
			local start = expirationTime - duration
			if not locPriority or locPriority < priority then
				locStart = start
				locExpiration = expirationTime
				changed = true
			else -- if locPriority == priority then
				-- Keep the earliest start time.
				if not locStart or locStart > start then
					locStart = start
					changed = true
				end
				-- Keep the latest expiration time.
				if not locExpiration or locExpiration < expirationTime then
					locExpiration = expirationTime
					changed = true
				end
			end
			if changed then
				self:Debug(2, "AddEvent", spellID, text, priority, duration, expirationTime)
			end
			locDuration = locExpiration - locStart
			locSpellID = spellID
			locEffect = text
			locPriority = priority
		end
	end

	-- These values are from FrameXML/LossOfControlFrame.lua.
	local DISPLAY_TYPE_NONE = 0
	local TEXT_OVERRIDE = {
		[ 33786] = L["Cycloned"],
		[209753] = L["Cycloned"],
	}

	function addon:ScanEvents()
		self:Debug(3, "ScanEvents")
		locExpiration = nil
		for index = 1, C_LossOfControl_GetNumEvents() do
			local locType, spellID, text, _, startTime, _, duration, school, _, displayType = C_LossOfControl_GetEventInfo(index)
			if locType and spellID and text and startTime and duration and school and displayType then
				if displayType ~= DISPLAY_TYPE_NONE and self:IsWatchedEvent(locType, spellID) then
					if locType == "SCHOOL_INTERRUPT" then
						-- Replace "Interrupted" with a school-specific lockout text, e.g., "Nature Locked", etc.
						if school and school ~= 0 then
							local schoolString = GetSchoolString(school)
							text = format(L["%s Locked"], schoolString)
						end
					else
						-- Override the text for the spell if the override exists.
						text = TEXT_OVERRIDE[spellID] or text
					end
					local priority = LOC_PRIORITY[locType]
					local expirationTime = startTime + duration
					self:AddEvent(spellID, text, priority, duration, expirationTime)
				end
			end
		end
		for index = 1, 40 do
			local name, _, _, _, duration, expirationTime, _, _, _, spellID = UnitDebuff("player", index)
			if not name then break end
			local t = LOC_AURA[spellID]
			if t then
				local locType, text = unpack(t)
				if locType and self:IsWatchedEvent(locType, spellID) then
					local priority = LOC_PRIORITY[locType]
					self:AddEvent(spellID, text, priority, duration, expirationTime)
				end
			end
		end
		-- postcondition: locExpiration is nil if there are no Loss Of Control events.
	end
end

do
	local guid = UnitGUID("player")

	local function round(x, n)
		n = n or 0
		local factor = 10 ^ n
		return floor(x * factor + 0.5) / factor
	end

	function addon:IsAnnounceEnabled()
		local role = self:GetRole()
		local zone = MooZone:GetZone()
		return (self.db.profile.announce.enable
			and self.db.profile.announce[role]
			and self.db.profile.announce[role].enable
			and self.db.profile.announce.zone[zone]
			and (IsInGroup() or self.db.profile.announce.solo))
	end

	function addon:PlayerControlGained()
		self:Debug(2, "PlayerControlGained")
		local role = self:GetRole()
		local duration = self:GetDuration()
		self:ResetLossOfControl()

		-- Round the duration of Loss Of Control to tenths of a second.
		duration = round(duration, 1)
		if self.db.profile.announce.regain and duration >= self.db.profile.announce.regainThreshold then
			if self:IsAnnounceEnabled() then
				local channel, msgType = self:GetOutputChannel()
				if channel and msgType then
					local chatMessage = self:CreateGainMessage(msgType, guid, role)
					self:SendChatMessage(chatMessage, channel)
				end
			end
			local localMessage = self:CreateGainMessage("local", guid, role)
			if self.db.profile.announce.raidWarning then
				self:SendEmphasizedMessage(localMessage)
			end
			if self.db.profile.announce.chat then
				self:SendLocalMessage(localMessage)
			end
		end

		-- Always broadcast and allow the receiver to decide whether to use the information.
		self:BroadcastGain(guid, role, duration) -- from Broadcast.lua
	end

	function addon:PlayerControlLost()
		self:Debug(2, "PlayerControlLost")

		local role = self:GetRole()
		local expirationTime = self:GetExpirationTime()
		local duration = self:GetDuration()
		local spellID = self:GetSpellID()
		local effect = self:GetEffect()

		-- Round time remaining and duration of Loss Of Control to tenths of a second.
		local now = GetTime()
		local start = self:GetStartTime()
		-- Sanity check!
		if now < start then
			now = start
		end
		local remaining = round(expirationTime - now, 1)
		duration = round(duration, 1)

		if duration > self.db.profile.announce.threshold then
			if self:IsAnnounceEnabled() then
				local channel, msgType = self:GetOutputChannel()
				if channel and msgType then
					local chatMessage = self:CreateLossMessage(msgType, guid, role, spellID, effect, remaining)
					self:SendChatMessage(chatMessage, channel)
				end
			end
			local localMessage = self:CreateLossMessage("local", guid, role, spellID, effect, remaining)
			if self.db.profile.announce.raidWarning then
				self:SendEmphasizedMessage(localMessage)
			end
			if self.db.profile.announce.chat then
				self:SendLocalMessage(localMessage)
			end
		end

		-- Always broadcast and allow the receiver to decide whether to use the information.
		self:BroadcastLoss(guid, role, spellID, effect, remaining, duration) -- from Broadcast.lua
	end
end

function addon:UpdateLossOfControl(event)
	self:Debug(3, "UpdateLossOfControl", event)
	local old = self:GetExpirationTime()
	self:ScanEvents()
	local current = self:GetExpirationTime()
	if current and (not old or current > old) then
		self:PlayerControlLost()
	elseif old and not current then
		self:PlayerControlGained()
	end
end
