--[[--------------------------------------------------------------------
    Copyright (C) 2018 Johnny C. Lam.
    See the file LICENSE.txt for copying permission.
--]]--------------------------------------------------------------------

local ADDON_NAME, addon = ...
local L = addon.L

local format = format
local tostring = tostring
-- GLOBALS: Ambiguate
-- GLOBALS: GetClassColor
-- GLOBALS: GetRaidTargetIndex
-- GLOBALS: GetSpellLink
-- GLOBALS: IsInGroup
-- GLOBALS: IsInRaid
-- GLOBALS: LibStub
-- GLOBALS: RaidNotice_AddMessage -- Interface/FrameXML/RaidWarningFrame.lua
-- GLOBALS: SendChatMessage
local DEFAULT_CHAT_FRAME = DEFAULT_CHAT_FRAME -- Interface/FrameXML/ChatFrame.lua
local ChatTypeInfo = ChatTypeInfo -- Interface/FrameXML/ChatFrame.lua
local RaidWarningFrame = RaidWarningFrame -- Interface/FrameXML/RaidWarningFrame.xml

local MooSpec = LibStub("MooSpec-1.0")
local MooUnit = LibStub("MooUnit-1.0")
local MooZone = LibStub("MooZone-1.0")

---------------------------------------------------------------------

do
	-- Map zones to the correct channel for group messages.
	local groupChannelByZone = {
		arena = "PARTY",
		battleground = "BATTLEGROUND",
		dungeon = "PARTY",
		lfg_dungeon = "INSTANCE_CHAT",
		lfg_raid = "INSTANCE_CHAT",
		raid = "RAID",
		scenario = "INSTANCE_CHAT",
		--world = "PARTY" or "RAID",
	}

	-- Returns channel for group chat or nil if not in a group or the zone is unknown.
	function addon:GetGroupChannelByZone(zone)
		local channel
		if zone == "world" then
			if IsInRaid() then
				channel = "RAID"
			elseif IsInGroup() then
				channel = "PARTY"
			end
		else
			channel = groupChannelByZone[zone]
		end
		return channel
	end
end

do
	local channelByOutput = {
		emote = "EMOTE",
		--group = smart group channel
		say = "SAY",
		yell = "YELL",
	}

	local msgTypeByOutput = {
		emote = "emote",
		group = "long",
		say = "short",
		yell = "short",
	}

	function addon:GetOutputChannel()
		local output = self.db.profile.announce.output
		local channel, msgType
		if output == "group" then
			local zone = MooZone:GetZone()
			channel = self:GetGroupChannelByZone(zone) or "SAY"
		else
			channel = channelByOutput[output]
		end
		msgType = msgTypeByOutput[output]
		return channel, msgType
	end
end

function addon:SendChatMessage(message, channel)
	SendChatMessage(message, channel)
end

function addon:SendEmphasizedMessage(message)
	RaidNotice_AddMessage(RaidWarningFrame, message, ChatTypeInfo["SAY"])
end

function addon:SendLocalMessage(message)
	self:Print(message)
end

---------------------------------------------------------------------

do
	local iconTextByRole = setmetatable({
		damager = "\124TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES.blp:15:15:0:0:64:64:20:39:22:41\124t",
		healer = "\124TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES.blp:15:15:0:0:64:64:20:39:1:20\124t",
		tank = "\124TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES.blp:15:15:0:0:64:64:0:19:22:41\124t",
	}, { __index = function(t, k) return "(" .. L[k] .. ")" end })

	local raidTargetChatString = setmetatable({
		[1] = "{rt1}",
		[2] = "{rt2}",
		[3] = "{rt3}",
		[4] = "{rt4}",
		[5] = "{rt5}",
		[6] = "{rt6}",
		[7] = "{rt7}",
		[8] = "{rt8}",
	}, { __index = function(t, k) return "" end })

	local raidTargetIconText = setmetatable({
		[1] = "\124TInterface\\TARGETINGFRAME\\UI-RaidTargetingIcon_1.blp:0\124t",
		[2] = "\124TInterface\\TARGETINGFRAME\\UI-RaidTargetingIcon_2.blp:0\124t",
		[3] = "\124TInterface\\TARGETINGFRAME\\UI-RaidTargetingIcon_3.blp:0\124t",
		[4] = "\124TInterface\\TARGETINGFRAME\\UI-RaidTargetingIcon_4.blp:0\124t",
		[5] = "\124TInterface\\TARGETINGFRAME\\UI-RaidTargetingIcon_5.blp:0\124t",
		[6] = "\124TInterface\\TARGETINGFRAME\\UI-RaidTargetingIcon_6.blp:0\124t",
		[7] = "\124TInterface\\TARGETINGFRAME\\UI-RaidTargetingIcon_7.blp:0\124t",
		[8] = "\124TInterface\\TARGETINGFRAME\\UI-RaidTargetingIcon_8.blp:0\124t",
	}, { __index = function(t, k) return "" end })

	local function CreateClassColorName(name, class)
		local _, _, _, hex = GetClassColor(class)
		return format("\124c%s%s\124r", hex, name)
	end

	function addon:GetDecoratedName(msgType, guid, role)
		local name = MooUnit:GetNameByGUID(guid)
		if name then name = Ambiguate(name, "none") end

		local decoratedName
		local markerText = ""
		local nameText = name or ""
		local roleText = ""
		if msgType == "emote" then
			-- keep defaults
		else
			local unit = MooUnit:GetUnitByGUID(guid)
			local index = unit and GetRaidTargetIndex(unit)
			if msgType == "short" or msgType == "long" then
				-- say/yell/party/raid/instance/battleground chat: no UI escape sequences allowed.
				markerText = index and (raidTargetChatString[index] .. " ") or ""
			elseif msgType == "local" then
				-- local frames via :AddMessage()
				local class = MooSpec:GetClass(guid)
				local colorizedName = class and CreateClassColorName(name, class)
				markerText = index and raidTargetIconText[index] or ""
				nameText = colorizedName or name
				roleText = iconTextByRole[role]
			end
		end
		decoratedName = markerText .. nameText .. roleText
		if decoratedName == "" then
			decoratedName = nil
		end
		return decoratedName
	end

	function addon:CreateGainMessage(msgType, guid, role)
		local fmt, msg
		if msgType == "emote" then
			msg = L["is back!"]
		else
			local name = self:GetDecoratedName(msgType, guid, role)
			fmt = L["%s is back!"]
			msg = format(fmt, name)
		end
		return msg
	end

	function addon:CreateLossMessage(msgType, guid, role, spellID, effect, remaining)
		local fmt, msg
		if msgType == "emote" then
			fmt = L["is %s for %s seconds."]
			msg = format(fmt, effect, tostring(remaining))
		else
			local name = self:GetDecoratedName(msgType, guid, role)
			if msgType == "short" then
				fmt = L["%s is %s!"]
				msg = format(fmt, name, effect)
			else
				if msgType == "long" or msgType == "local" then
					local link = spellID and GetSpellLink(spellID)
					if link then
						fmt = L["%s is %s for %s seconds: %s"]
						msg = format(fmt, name, effect, tostring(remaining), link)
					else
						fmt = L["%s is %s for %s seconds"]
						msg = format(fmt, name, effect, tostring(remaining))
					end
				end
			end
		end
		return msg
	end
end