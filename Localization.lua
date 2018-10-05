--[[--------------------------------------------------------------------
    Copyright (C) 2018 Johnny C. Lam.
    See the file LICENSE.txt for copying permission.
--]]--------------------------------------------------------------------

local _, addon = ...

if not addon.L then
	addon.L = { }
end
local L = setmetatable(addon.L, { __index = function(t, k) t[k] = k; return k end })

-- Seed localization table with localizations already available in global constants.
L["Arena"] = _G.ARENA
L["Battlegrounds"] = _G.BATTLEFIELDS
L["Damage"] = _G.DAMAGER
L["Emote"] = _G.EMOTE
L["Enable"] = _G.ENABLE
L["Group"] = _G.GROUP
L["Healer"] = _G.HEALER
L["Interrupt"] = _G.INTERRUPT
L["Party"] = _G.PARTY
L["Raid"] = _G.RAID
L["Say"] = _G.SAY
L["Stun"] = _G.STUN
L["Stunned"] = _G.STUNNED
L["Tank"] = _G.TANK
L["World"] = _G.CHANNEL_CATEGORY_WORLD
L["Yell"] = _G.YELL