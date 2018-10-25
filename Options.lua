--[[--------------------------------------------------------------------
    Copyright (C) 2018 Johnny C. Lam.
    See the file LICENSE.txt for copying permission.
--]]--------------------------------------------------------------------

local ADDON_NAME, addon = ...
local L = addon.L

-- GLOBALS: GetAddOnMetadata

local defaultDB = {
	global = {
		debug = false,
		debuglevel = 1,
		debugFrame = "ChatFrame1",
	},
	profile = {
		-- Make announcements only in dungeons.
		announce = {
			enable = true, -- Enable announcements.
			zone = {
				dungeon = true,
				lfg_dungeon = true,
			},
			output = "emote", -- Use emotes (least intrusive option).
			threshold = 1.5, -- Only announce for events lasting longer than 1.5 seconds.
			regain = false, -- Don't announce when player control is regained.
			regainThreshold = 5, -- Only announce player regaining control after Loss Of Control lasting longer than 5 seconds.
			solo = false, -- No announcements if the player is not in a group.
			tank = {
				-- Default to enabling announcements for tanks for events that prevent all actions.
				enable = true,
				charm = true,
				confuse = true,
				fear = true,
				pacify = true,
				possess = true,
				stun = true,
			},
			damager = {
				-- Default to disabling announcements for DPS; don't broadcast when you fail to mechanics ;)
				enable = false,
			},
			healer = {
				-- Default to enabling announcements for tanks for events that prevent all actions or spellcasts.
				enable = true,
				charm = true,
				confuse = true,
				fear = true,
				interrupt = true,
				pacify = true,
				possess = true,
				silence = true,
				stun = true,
			},
		},
		alert = {
			enable = true, -- Enable alerts from other group members.
			chat = true, -- Alert in chat window.
			raidWarning = true, -- Alert as raid warning message.
			regain = true, -- Alert for other group members regaining control.
			regainThreshold = 5, -- Only announce members regaining control after Loss Of Control lasting longer than 5 seconds.
		}
	},
}

local eventOptions = {
	disarm = {
		name = L["Disarm"],
		desc = L["Disarmed of main-hand weapon."],
		type = "toggle",
		order = 10,
	},
	charm = {
		name = L["Charm"],
		desc = L["Charmed or seduced."],
		type = "toggle",
		order = 20,
	},
	confuse = {
		name = L["Confuse"],
		desc = L["Disoriented or confused."],
		type = "toggle",
		order = 30,
	},
	fear = {
		name = L["Fear"],
		desc = L["Feared or horrified."],
		type = "toggle",
		order = 40,
	},
	interrupt = {
		name = L["Interrupt"],
		desc = L["Interrupted while casting and locked out of spell school."],
		type = "toggle",
		order = 50,
	},
	pacify = {
		name = L["Pacify"],
		desc = L["Polymorphed, hexed, or put to sleep."],
		type = "toggle",
		order = 60,
	},
	possess = {
		name = L["Possess"],
		desc = L["Mind-controlled."],
		type = "toggle",
		order = 70,
	},
	root = {
		name = L["Root"],
		desc = L["Rooted and unable to move."],
		type = "toggle",
		order = 80,
	},
	silence = {
		name = L["Silence"],
		desc = L["Silenced from casting spells."],
		type = "toggle",
		order = 90,
	},
	stun = {
		name = L["Stun"],
		desc = L["Stunned and unable to perform any actions."],
		type = "toggle",
		order = 100,
	},
}

local options = {
	name = GetAddOnMetadata(ADDON_NAME, "Title"),
	type = "group",
	args = {
		announce = {
			name = L["Announcements"],
			desc = L["Manage how announcements are made."],
			type = "group",
			order = 10,
			disabled = function()
				return not addon.db.profile.announce.enable
			end,
			get = function(info)
				return addon.db.profile.announce[info[#info]]
			end,
			set = function(info, value)
				addon.db.profile.announce[info[#info]] = value
				addon:UpdateLossOfControl()
			end,
			args = {
				desc = {
					name = L["Set conditions for making announcements based on zone, role, and event duration."],
					type = "description",
					order = 1,
				},
				enable = {
					name = L["Enable"],
					desc = L["Enable announcements for Loss Of Control events."],
					type = "toggle",
					order = 5,
					width = "full",
					disabled = false,
				},
				zones = {
					name = L["Enabled Zones"],
					type = "group",
					order = 10,
					inline = true,
					get = function(info)
						return addon.db.profile.announce.zone[info[#info]]
					end,
					set = function(info, value)
						addon.db.profile.announce.zone[info[#info]] = value
						addon:UpdateLossOfControl()
					end,
					args = {
						world = {
							name = L["World"],
							desc = L["Enable announcements while in the open world."],
							type = "toggle",
							order = 10,
						},
						battleground = {
							name = L["Battlegrounds"],
							desc = L["Enable announcements while in a battleground."],
							type = "toggle",
							order = 20,
						},
						arena = {
							name = L["Arena"],
							desc = L["Enable announcements while in an arena."],
							type = "toggle",
							order = 30,
						},
						dungeon = {
							name = L["Dungeon"],
							desc = L["Enable announcements while in a manually-created dungeon group."],
							type = "toggle",
							order = 40,
						},
						raid = {
							name = L["Raid"],
							desc = L["Enable announcements while in a manually-created raid group."],
							type = "toggle",
							order = 50,
						},
						lfg_dungeon = {
							name = L["LFG Dungeon"],
							desc = L["Enable announcements while in a Looking For Group dungeon."],
							type = "toggle",
							order = 60,
						},
						lfg_raid = {
							name = L["LFG Raid"],
							desc = L["Enable announcements while in a Looking For Group raid."],
							type = "toggle",
							order = 70,
						},
					},
				},
				output = {
					name = L["Announcement Channel"],
					desc = L["Set the channel to where announcements are sent."],
					type = "select",
					order = 20,
					values = {
						emote = L["Emote"],
						group = L["Group"],
						say = L["Say"],
						yell = L["Yell"],
					},
				},
				threshold = {
					name = L["Minimum duration"],
					desc = L["Only announce events if the duration exceeds a minimum number of seconds."],
					type = "range",
					order = 30,
					min = 0,
					max = 10,
					step = 0.1,
				},
				regain = {
					name = L["Announce when regaining control"],
					desc = L["Enable announcing when the player regains control."],
					type = "toggle",
					order = 40,
					width = "full",
				},
				regainThreshold = {
					name = L["Minimum regain duration"],
					desc = L["Only announce when the player regains control if the duration of the Loss Of Control exceeds a minimum number of seconds."],
					type = "range",
					order = 45,
					min = 0,
					max = 15,
					step = 0.1,
					disabled = function()
						return not (addon.db.profile.announce.enable and addon.db.profile.announce.regain)
					end,
				},
				solo = {
					name = L["Announce while solo"],
					desc = L["Enable announcements even if the player is not a group."],
					type = "toggle",
					order = 50,
					width = "full",
				},
				tank = {
					name = L["Tank"],
					type = "group",
					order = 10,
					get = function(info)
						return addon.db.profile.announce.tank[info[#info]]
					end,
					set = function(info, value)
						addon.db.profile.announce.tank[info[#info]] = value
						addon:UpdateLossOfControl()
					end,
					args = {
						desc = {
							name = L["Manage Loss Of Control events for tank role."],
							type = "description",
							order = 1,
						},
						enable = {
							name = L["Enable"],
							desc = L["Enable announcements as tank role."],
							type = "toggle",
							order = 10,
						},
						events = {
							name = L["Events"],
							desc = L["Events to track as tank role."],
							type = "group",
							order = 20,
							inline = true,
							disabled = function()
								return not addon.db.profile.announce.tank.enable
							end,
							args = eventOptions,
						},
					},
				},
				healer = {
					name = L["Healer"],
					type = "group",
					order = 20,
					get = function(info)
						return addon.db.profile.announce.healer[info[#info]]
					end,
					set = function(info, value)
						addon.db.profile.announce.healer[info[#info]] = value
						addon:UpdateLossOfControl()
					end,
					args = {
						desc = {
							name = L["Manage Loss Of Control events for healer role."],
							type = "description",
							order = 1,
						},
						enable = {
							name = L["Enable"],
							desc = L["Enable announcements as healer role."],
							type = "toggle",
							order = 10,
						},
						events = {
							name = L["Events"],
							desc = L["Events to track as healer role."],
							type = "group",
							order = 20,
							inline = true,
							disabled = function()
								return not addon.db.profile.announce.healer.enable
							end,
							args = eventOptions,
						},
					},
				},
				damager = {
					name = L["Damage"],
					type = "group",
					order = 30,
					get = function(info)
						return addon.db.profile.announce.damager[info[#info]]
					end,
					set = function(info, value)
						addon.db.profile.announce.damager[info[#info]] = value
						addon:UpdateLossOfControl()
					end,
					args = {
						desc = {
							name = L["Manage Loss Of Control events for damage role."],
							type = "description",
							order = 1,
						},
						enable = {
							name = L["Enable"],
							desc = L["Enable announcements as damage role."],
							type = "toggle",
							order = 10,
						},
						events = {
							name = L["Events"],
							desc = L["Events to track as damage role."],
							type = "group",
							order = 20,
							inline = true,
							disabled = function()
								return not addon.db.profile.announce.damager.enable
							end,
							args = eventOptions,
						},
					},
				},
			},
		},
		alert = {
			name = L["Alerts"],
			desc = L["Manage alerts when listening for Loss Of Control events from other members of the group."],
			type = "group",
			order = 30,
			disabled = function()
				return not addon.db.profile.alert.enable
			end,
			get = function(info)
				return addon.db.profile.alert[info[#info]]
			end,
			set = function(info, value)
				addon.db.profile.alert[info[#info]] = value
			end,
			args = {
				desc = {
					name = L["Manage alerts when listening for Loss Of Control events from other members of the group."],
					type = "description",
					order = 1,
				},
				enable = {
					name = L["Enable"],
					desc = L["Enable alerts for Loss Of Control events from group memebers."],
					type = "toggle",
					order = 5,
					width = "full",
					disabled = false,
				},
				chat = {
					name = L["Show alerts in local chat window."],
					desc = L["Enable showing alerts in the local chat window."],
					type = "toggle",
					order = 10,
					width = "full",
				},
				raidWarning = {
					name = L["Show alerts in raid warning area."],
					desc = L["Enable showing alerts in the raid warning message area."],
					type = "toggle",
					order = 20,
					width = "full",
				},
				regain = {
					name = L["Alert when other members regain control"],
					desc = L["Enable alerts when other members of the group regain control."],
					type = "toggle",
					order = 30,
					width = "full",
				},
				regainThreshold = {
					name = L["Minimum regain duration"],
					desc = L["Only alert when other members regain control if the duration of the Loss Of Control exceeds a minimum number of seconds."],
					type = "range",
					order = 40,
					min = 0,
					max = 15,
					step = 0.1,
					disabled = function()
						return not (addon.db.profile.alert.enable and addon.db.profile.alert.regain)
					end,
				},
			},
		},
		debugging = {
			name = L["Debugging"],
			desc = L["Debugging menu."],
			type = "group",
			order = 40,
			get = function(info)
				return addon.db.global[info[#info]]
			end,
			set = function(info, value)
				addon.db.global[info[#info]] = value
			end,
			args = {
				desc = {
					name = L["Regular users should leave debugging turned off except when troubleshooting a problem for a bug report."],
					type = "description",
					order = 1,
				},
				debug = {
					name = L["Debug"],
					desc = L["Toggle debugging output."],
					type = "toggle",
					order = 10,
				},
				debuglevel = {
					name = L["Debug level"],
					desc = L["The level of debugging information to output."],
					type = "range",
					order = 15,
					min = 1,
					max = 3,
					step = 1,
				},
				debugFrame = {
					name = L["Output frame"],
					desc = L["Send debugging output to this frame."],
					type = "select",
					order = 20,
					values = {
						ChatFrame1  = "ChatFrame1",
						ChatFrame2  = "ChatFrame2",
						ChatFrame3  = "ChatFrame3",
						ChatFrame4  = "ChatFrame4",
						ChatFrame5  = "ChatFrame5",
						ChatFrame6  = "ChatFrame6",
						ChatFrame7  = "ChatFrame7",
						ChatFrame8  = "ChatFrame8",
						ChatFrame8  = "ChatFrame9",
						ChatFrame10 = "ChatFrame10",
					}
				},
			},
		},
	},
}

function addon:GetDefaultDB()
	return defaultDB
end

function addon:GetOptions()
	return options
end