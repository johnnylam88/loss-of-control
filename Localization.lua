--[[--------------------------------------------------------------------
    Copyright (C) 2018 Johnny C. Lam.
    See the file LICENSE.txt for copying permission.
--]]--------------------------------------------------------------------

local _, addon = ...

local setmetatable = setmetatable
-- GLOBALS: LibStub

if not addon.L then
	addon.L = { }
end
local L = setmetatable(addon.L, { __index = function(t, k) t[k] = k; return k end })

local MooZone = LibStub("MooZone-1.0")

-- Seed localization table with localizations already available in global constants.
L["Arena"] = MooZone:GetLocalizedZone("arena")
L["Asleep"] = _G.LOSS_OF_CONTROL_DISPLAY_SLEEP
L["Banished"] = _G.LOSS_OF_CONTROL_DISPLAY_BANISH
L["Battlegrounds"] = MooZone:GetLocalizedZone("battleground")
L["Charmed"] = _G.LOSS_OF_CONTROL_DISPLAY_CHARM
L["Confused"] = _G.LOSS_OF_CONTROL_DISPLAY_CONFUSE
L["Cycloned"] = _G.LOSS_OF_CONTROL_DISPLAY_CYCLONE
L["Damage"] = _G.DAMAGER
L["Dazed"] = _G.LOSS_OF_CONTROL_DISPLAY_DAZE
L["Disarmed"] = _G.LOSS_OF_CONTROL_DISPLAY_DISARM
L["Disoriented"] = _G.LOSS_OF_CONTROL_DISPLAY_DISORIENT
L["Distracted"] = _G.LOSS_OF_CONTROL_DISPLAY_DISTRACT
L["Dungeon"] = MooZone:GetLocalizedZone("dungeon")
L["Dungeon Finder"] = MooZone:GetLocalizedZone("lfg_dungeon")
L["Emote"] = _G.EMOTE
L["Enable"] = _G.ENABLE
L["Feared"] = _G.LOSS_OF_CONTROL_DISPLAY_FEAR
L["Frozen"] = _G.LOSS_OF_CONTROL_DISPLAY_FREEZE
L["Group"] = _G.GROUP
L["Healer"] = _G.HEALER
L["Horrified"] = _G.LOSS_OF_CONTROL_DISPLAY_HORROR
L["Incapacitated"] = _G.LOSS_OF_CONTROL_DISPLAY_INCAPACITATE
L["Interrupt"] = _G.INTERRUPT
L["Interrupted"] = _G.LOSS_OF_CONTROL_DISPLAY_INTERRUPT
L["Invulnerable"] = _G.LOSS_OF_CONTROL_DISPLAY_INVULNERABILITY
L["Pacified"] = _G.LOSS_OF_CONTROL_DISPLAY_PACIFY
L["Polymorphed"] = _G.LOSS_OF_CONTROL_DISPLAY_POLYMORPH
L["Possessed"] = _G.LOSS_OF_CONTROL_DISPLAY_POSSESS
L["Raid"] = MooZone:GetLocalizedZone("raid")
L["Raid Finder"] = MooZone:GetLocalizedZone("lfg_raid")
L["Rooted"] = _G.LOSS_OF_CONTROL_DISPLAY_ROOT
L["Sapped"] = _G.LOSS_OF_CONTROL_DISPLAY_SAP
L["Say"] = _G.SAY
L["Scenarios"] = MooZone:GetLocalizedZone("scenario")
L["Shackled"] = _G.LOSS_OF_CONTROL_DISPLAY_SHACKLE_UNDEAD
L["Silenced"] = _G.LOSS_OF_CONTROL_DISPLAY_SILENCE
L["Stun"] = _G.STUN
L["Stunned"] = _G.LOSS_OF_CONTROL_DISPLAY_STUN
L["Tank"] = _G.TANK
L["World"] = MooZone:GetLocalizedZone("world")
L["Yell"] = _G.YELL