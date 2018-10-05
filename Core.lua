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
local ipairs = ipairs
local pairs = pairs
local setmetatable = setmetatable
local strfind = string.find
local strjoin = strjoin
local strlen = string.len
local strlower = string.lower
local strtrim = strtrim
local tostringall = tostringall
local type = type
local C_LossOfControl = C_LossOfControl
local C_LossOfControl_GetEventInfo = C_LossOfControl.GetEventInfo
local C_LossOfControl_GetNumEvents = C_LossOfControl.GetNumEvents
local GetAddOnMetadata = GetAddOnMetadata
local InterfaceOptionsFrame_OpenToCategory = InterfaceOptionsFrame_OpenToCategory
local LibStub = LibStub
local UnitGUID = UnitGUID

local addonName = GetAddOnMetadata(ADDON_NAME, "Title")
_G[ADDON_NAME] = LibStub("AceAddon-3.0"):NewAddon(addon, addonName or ADDON_NAME,
	"AceComm-3.0", "AceConsole-3.0", "AceEvent-3.0", "AceSerializer-3.0", "AceTimer-3.0")

---------------------------------------------------------------------

-- Debugging code from Grid by Phanx.
-- https://github.com/phanx-wow/Grid

function addon:Debug(str, ...)
	if not self.db.global.debug then return end
	if not str or strlen(str) == 0 then return end

	if (...) then
		if strfind(str, "%%%.%d") or strfind(str, "%%[dfqsx%d]") then
			str = format(str, ...)
		else
			str = strjoin(" ", str, tostringall(...))
		end
	end

	local name = self.moduleName or self.name or ADDON_NAME
	local frame = _G[addon.db.global.debugFrame]
	local message = format("\124cff00d1ff%s\124r: %s", name, str)
	frame:AddMessage(message)
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
	self:Debug("OnEnable")
	self:RegisterChatCommand("loc", "ChatCommand")
	self:RegisterEvent("GROUP_ROSTER_UPDATE", "UpdateGroup")
	self:RegisterEvent("LOSS_OF_CONTROL_UPDATE", "UpdateLossOfControl")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "Update")
	self:RegisterEvent("UNIT_NAME_UPDATE", "UpdateGroup")
	self:RegisterEvent("UNIT_PORTRAIT_UPDATE", "UpdateGroup")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "UpdateZone")
	self:RegisterAllComm()
end

function addon:OnDisable()
	self:Debug("OnDisable")
	self:UnregisterChatCommand("loc")
	self:UnregisterEvent("GROUP_ROSTER_UPDATE")
	self:UnregisterEvent("LOSS_OF_CONTROL_UPDATE")
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	self:UnregisterEvent("UNIT_NAME_UPDATE")
	self:UnregisterEvent("UNIT_PORTRAIT_UPDATE")
	self:UnregisterEvent("ZONE_CHANGED_NEW_AREA")
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
		input = strlower(input)
		if input == "version" then
			local version = GetAddOnMetadata(ADDON_NAME, "Version")
			if version == "@" .. "project-version" .. "@" then
				self:Print("developer version")
			else
				self:Print(version)
			end
		elseif input == "ping" then
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

	function addon:IsWatchedEvent(locType)
		local role = self:GetRole()
		local option = locOption[locType]
		local watched
		if not option then
			self:Debug("IsWatchedEvent", "unknown effect", locType)
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
	-- Remaining time for the Loss Of Control event.
	local locRemaining
	-- ID of spell that triggered the Loss Of Control event.
	local locSpellID
	-- Descriptive text of effect caused by the Loss Of Control event.
	local locEffect

	function addon:GetRemainingTime()
		return locRemaining
	end

	function addon:GetSpellID()
		return locSpellID
	end

	function addon:GetEffect()
		return locEffect
	end

	function addon:ScanEvents()
		self:Debug("ScanEvents")
		locRemaining = nil
		for index = 1, C_LossOfControl_GetNumEvents() do
			local locType, spellID, text, _, _, timeRemaining = C_LossOfControl_GetEventInfo(index)
			if self:IsWatchedEvent(locType) then
				self:Debug("ScanEvents", locType, spellID, text, timeRemaining)
				if not locRemaining or locRemaining < timeRemaining then
					locRemaining = timeRemaining
					locSpellID = spellID
					locEffect = text
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

	function addon:PlayerControlGained()
		self:Debug("PlayerControlGained")
		local role = self:GetRole()
		if self.db.profile.announce.regain then
			local channel, msgType = self:GetOutputChannel()
			local chatMessage = self:CreateGainMessage(msgType, guid, role)
			local localMessage = self:CreateGainMessage("local", guid, role)
			self:SendChatMessage(chatMessage, channel)
			self:SendLocalMessage(localMessage)
		end
		-- Always broadcast and allow the receiver to decide whether to use the information.
		self:BroadcastGain(guid, role) -- from Broadcast.lua
	end

	function addon:PlayerControlLost()
		self:Debug("PlayerControlLost")
		local remaining = self:GetRemainingTime()
		-- Round to tenths of a second.
		local remainingRounded = round(remaining, 1)
		if remainingRounded > self.db.profile.announce.threshold then
			local role = self:GetRole()
			local spellID = self:GetSpellID()
			local effect = self:GetEffect()
			local channel, msgType = self:GetOutputChannel()
			local chatMessage = self:CreateLossMessage(msgType, guid, role, spellID, effect, remainingRounded)
			local localMessage = self:CreateLossMessage("local", guid, role, spellID, effect, remainingRounded)
			self:SendChatMessage(chatMessage, channel)
			self:SendLocalMessage(localMessage)
			self:BroadcastLoss(guid, role, spellID, effect, remainingRounded) -- from Broadcast.lua
		end
	end
end

function addon:UpdateLossOfControl()
	self:Debug("UpdateLossOfControl")
	local old = self:GetRemainingTime()
	self:ScanEvents()
	local current = self:GetRemainingTime()
	if current and (not old or old < current) then
		self:PlayerControlLost()
	elseif old and not current then
		self:PlayerControlGained()
	end
end