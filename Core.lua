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
-- GLOBALS: GetSpellLink
-- GLOBALS: GetTime
-- GLOBALS: InterfaceOptionsFrame_OpenToCategory
-- GLOBALS: IsInGroup
-- GLOBALS: LibStub
-- GLOBALS: UnitDebuff
-- GLOBALS: UnitGUID
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
	self:RegisterChatCommand("loc", "ChatCommand")
	self:RegisterEvent("GROUP_ROSTER_UPDATE", "UpdateGroup")
	self:RegisterEvent("LOSS_OF_CONTROL_UPDATE", "UpdateLossOfControl")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "Update")
	self:RegisterEvent("UNIT_AURA")
	self:RegisterEvent("UNIT_NAME_UPDATE", "UpdateGroup")
	self:RegisterEvent("UNIT_PORTRAIT_UPDATE", "UpdateGroup")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "UpdateZone")
	self:RegisterAllComm()
end

function addon:OnDisable()
	self:Debug(3, "OnDisable")
	self:UnregisterChatCommand("loc")
	self:UnregisterEvent("GROUP_ROSTER_UPDATE")
	self:UnregisterEvent("LOSS_OF_CONTROL_UPDATE")
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	self:UnregisterEvent("UNIT_AURA")
	self:UnregisterEvent("UNIT_NAME_UPDATE")
	self:UnregisterEvent("UNIT_PORTRAIT_UPDATE")
	self:UnregisterEvent("ZONE_CHANGED_NEW_AREA")
end

function addon:UNIT_AURA(event, unit)
	if unit == "player" then
		self:UpdateLossOfControl(event)
	end
end

function addon:Update()
	self:UpdateGroup()
	self:UpdateZone()
	self:QueueRoleCheck()
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
	local locOption = {
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

	local locAura = {
		[ 10730] = { "PACIFY", L["Pacified"] }, -- Pacify
		[ 74720] = { "CONFUSE", L["Disoriented"] }, -- Pound
		[149955] = { "STUN", L["Stunned"] }, -- Devouring Blackness
		[150634] = { "STUN", L["Stunned"] }, -- Leviathan's Grip
	}

	function addon:IsWatchedEvent(locType, spellID)
		local role = self:GetRole()
		local option = locOption[locType]
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

	-- We track only the Loss of Control event with the longest remaining duration.
	-- Time at which the Loss of Control occurred.
	local locStart
	-- Remaining time for the Loss Of Control event.
	local locRemaining
	-- ID of spell that triggered the Loss Of Control event.
	local locSpellID
	-- Descriptive text of effect caused by the Loss Of Control event.
	local locEffect

	function addon:GetStartTime() return locStart end
	function addon:GetRemainingTime() return locRemaining end
	function addon:GetSpellID() return locSpellID end
	function addon:GetEffect() return locEffect end

	function addon:SetStartTime(start) locStart = start end

	function addon:AddEvent(spellID, text, timeRemaining)
		self:Debug(2, "AddEvent", spellID, text, timeRemaining)
		if not locRemaining or locRemaining < timeRemaining then
			locRemaining = timeRemaining
			locSpellID = spellID
			locEffect = text
		end
	end

	function addon:ScanEvents()
		self:Debug(3, "ScanEvents")
		locRemaining = nil
		for index = 1, C_LossOfControl_GetNumEvents() do
			local locType, spellID, text, _, _, timeRemaining = C_LossOfControl_GetEventInfo(index)
			if self:IsWatchedEvent(locType, spellID) then
				self:AddEvent(spellID, text, timeRemaining)
			end
		end
		local now = GetTime()
		for index = 1, 40 do
			local name, _, _, _, _, expirationTime, _, _, _, spellID = UnitDebuff("player", index)
			if not name then break end
			local t = locAura[spellID]
			if t then
				local locType, text = unpack(t)
				if locType and self:IsWatchedEvent(locType, spellID) then
					self:AddEvent(spellID, text, expirationTime - now)
				end
			end
		end
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
		local zone = self:GetZone()
		return (self.db.profile.announce.enable
			and self.db.profile.announce[role].enable
			and self.db.profile.announce.zone[zone]
			and (IsInGroup() or self.db.profile.announce.solo))
	end

	function addon:PlayerControlGained()
		self:Debug(2, "PlayerControlGained")
		local role = self:GetRole()
		local now = GetTime()
		local start = self:GetStartTime()
		-- Round duration of Loss Of Control to tenths of a second.
		local duration = (now and start) and round(now - start, 1) or 0
		self:SetStartTime() -- reset the start time
		if self.db.profile.announce.regain and duration >= self.db.profile.announce.regainThreshold then
			if self:IsAnnounceEnabled() then
				local channel, msgType = self:GetOutputChannel()
				if channel and msgType then
					local chatMessage = self:CreateGainMessage(msgType, guid, role)
					self:SendChatMessage(chatMessage, channel)
				end
			end
			local localMessage = self:CreateGainMessage("local", guid, role)
			self:SendLocalMessage(localMessage)
		end
		-- Always broadcast and allow the receiver to decide whether to use the information.
		self:BroadcastGain(guid, role, duration) -- from Broadcast.lua
	end

	function addon:PlayerControlLost()
		self:Debug(2, "PlayerControlLost")
		local now = GetTime()
		local start = self:GetStartTime()
		if not start then
			start = now
			self:SetStartTime(now)
		end
		local remaining = self:GetRemainingTime()
		-- Round duration of Loss Of Control to tenths of a second.
		local duration = round(now + remaining - start, 1)
		if duration > self.db.profile.announce.threshold then
			local role = self:GetRole()
			local spellID = self:GetSpellID()
			local effect = self:GetEffect()
			local remainingRounded = round(remaining, 1)
			if self:IsAnnounceEnabled() then
				local channel, msgType = self:GetOutputChannel()
				if channel and msgType then
					local chatMessage = self:CreateLossMessage(msgType, guid, role, spellID, effect, remainingRounded)
					self:SendChatMessage(chatMessage, channel)
				end
			end
			local localMessage = self:CreateLossMessage("local", guid, role, spellID, effect, remainingRounded)
			self:SendLocalMessage(localMessage)
			self:BroadcastLoss(guid, role, spellID, effect, remainingRounded, duration) -- from Broadcast.lua
		end
	end
end

function addon:UpdateLossOfControl(event)
	self:Debug(3, "UpdateLossOfControl", event)
	local old = self:GetRemainingTime()
	self:ScanEvents()
	local current = self:GetRemainingTime()
	if current and (not old or old < current) then
		self:PlayerControlLost()
	elseif old and not current then
		self:PlayerControlGained()
	end
end