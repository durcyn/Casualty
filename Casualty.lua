local _G = getfenv(0)
local LibStub = _G.LibStub
local Casualty = LibStub("AceAddon-3.0"):NewAddon("Casualty", "AceEvent-3.0", "AceTimer-3.0", "LibSink-2.0")
local L = LibStub:GetLibrary("AceLocale-3.0"):GetLocale("Casualty")
local media = LibStub("LibSharedMedia-3.0")
local lsmlist = _G.AceGUIWidgetLSMlists

local dead = {}

local pairs = _G.pairs
local unpack = _G.unpack
local wipe = _G.wipe
local fmt = _G.string.format
local join = _G.string.join
local bitband = _G.bit.band
local tinsert = _G.table.insert
local tconcat = _G.table.concat

local COMBATLOG_OBJECT_TYPE_PLAYER = _G.COMBATLOG_OBJECT_TYPE_PLAYER
local COMBATLOG_OBJECT_AFFILIATION_OUTSIDER = _G.COMBATLOG_OBJECT_AFFILIATION_OUTSIDER

local UnitInRaid = _G.UnitInRaid
local UnitIsDeadOrGhost = _G.UnitIsDeadOrGhost
local UnitIsFeignDeath = _G.UnitIsFeignDeath
local GetNumPartyMembers = _G.GetNumPartyMembers
local GetNumRaidMembers = _G.GetNumRaidMembers
local PlaySoundFile = _G.PlaySoundFile

local db
local defaults = {
	profile = {
		sinkOptions = {
			sink20OutputSink = "ChatFrame",
		},
		delay = 1,
		mass = 8,
		catastrophe = true,
		wipe = true,
		noise = true,
		sound = {
			casualty = "Casualty: Single Casualty",
			casualties = "Casualty: Multiple Casualties",
			catastrophe = "Casualty: Catastrophe",
			wipe = "Casualty: Wipe",
		},
		color = { r=1, g=1, b=1, },
	},
}

local options = {
	type = 'group',
	args = {
		test = {
			type = 'execute',
			name = L["Test"],
			desc = L["Test an announcement using current settings"],
			func = function()
				Casualty:Test()
			end
		},
		casualty = {
			type = 'group',
			name = L["Casualty"],
			desc = L["Casualty"],
			args = {
				delay = {
					order = 10,
					type = 'range',
					name = L["Announcement Delay"],
					desc = L["Minimum delay between announcements"],
					min = 0,
					max = 10,
					step = 1,
					get = function()
						return db.delay
						end,
					set = function(i,v)
						db.delay = v
					end
				},
				color = {
					order = 20,
					type = 'color',
					name = L["Announcement Color"],
					desc = L["Color to use for announcements"],
					hasAlpha = false,
					get = function()
						return  unpack(db.color)
					end,
					set = function(i,r,g,b)
						db.color = {r,g,b}
					end
				},
				noise = {
					order = 30,
					type = 'toggle',
					name = L["Toggle Sound"],
					desc = L["Enable sounds"],
					get = function()
						return db.noise
					end,
					set = function(i,v)
						db.noise = v
					end
				},
				catastrophe = {
					order = 40,
					type = 'toggle',
					name = L["Catastrophe Announcements"],
					desc = L["Enable Catastrophe announcemen"],
					get = function()
						return db.catastrophe
					end,
					set = function(i,v)
						db.catastrophe = v
					end
				},
				threshold = {
					order = 50,
					type = 'range',
					name = L["Catastrophe Threshold"],
					desc = L["Number of simultaneous deaths to trigger Catastrophe announcement"],
					min = 1,
					max = 40,
					step = 1,
					get = function()
					return db.mass
						end,
					set = function(i,v)
						db.mass = v
					end
				},
				wipe = {
					order = 60,
					type = 'toggle',
					name = L["Wipe"],
					desc = L["Enable wipe announcement"],
					get = function()
						return db.wipe
					end,
					set = function(i,v)
						db.wipe = v
					end
				},
			},
		},
		output = Casualty:GetSinkAce3OptionsDataTable(),
		sound = {
			type = 'group',
			name = L["Sound"],
			desc = L["Sound"],
			args = {
				casualty = {
					order = 10,
					type = "select",
					dialogControl = 'LSM30_Sound',
					name = L["Single Casualty"],
					desc = L["Single Casualty"],
					values = lsmlist.sound,
					get = function(info) return db.sound.casualty end,
					set = function(info, v)
						db.sound.casualty = v
						end,
				},
				casualties = {
					order = 20,
					type = "select",
					dialogControl = 'LSM30_Sound',
					name = L["Multiple Casualties"],
					desc = L["Multiple Casualties"],
					values = lsmlist.sound,
					get = function(info) return db.sound.casualties end,
					set = function(info, v)
						db.sound.casualties = v
						end,
				},
				catastrophe = {
					order = 30,
					type = "select",
					dialogControl = 'LSM30_Sound',
					name = L["Catastrophe"],
					desc = L["Catastrophe"],
					values = lsmlist.sound,
					get = function(info) return db.sound.catastrophe end,
					set = function(info, v)
						db.sound.catastrophe = v
						end,
				},
				wipe = {
					order = 40,
					type = "select",
					dialogControl = 'LSM30_Sound',
					name = L["Wipe"],
					desc = L["Wipe"],
					values = lsmlist.sound,
					get = function(info) return db.sound.wipe end,
					set = function(info, v)
						db.sound.wipe = v
						end,
				},
			},
		},
	},
}

function Casualty:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("CasualtyDB", defaults, "Default")
	db = self.db.profile
	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("Casualty", options)
	options.args.profile = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)

	Casualty.optFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Casualty", "Casualty")

	self:SetSinkStorage(self.db.profile.sinkOptions)

	self.db.RegisterCallback(self, "OnProfileChanged", "UpdateProfile")
	self.db.RegisterCallback(self, "OnProfileCopied", "UpdateProfile")
	self.db.RegisterCallback(self, "OnProfileReset", "UpdateProfile")

	media:Register("sound", "Casualty: Single Casualty", [[Interface\Addons\Casualty\Sounds\casualty.mp3]])
	media:Register("sound", "Casualty: Multiple Casualties", [[Interface\Addons\Casualty\Sounds\casualties.mp3]])
	media:Register("sound", "Casualty: Catastrophe", [[Interface\Addons\Casualty\Sounds\mass_casualties.mp3]])
	media:Register("sound", "Casualty: Wipe", [[Interface\Addons\Casualty\Sounds\no_survivors.mp3]])
end

function Casualty:OnEnable()
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
end

function Casualty:OnDisable()
	self:UnregisterAllEvents()
end

function Casualty:UpdateProfile()
	db = self.db.profile
end

function Casualty:COMBAT_LOG_EVENT_UNFILTERED(event, timestamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, sourceFlags2, destGUID, destName, destFlags, destFlags2)
	if eventType == "UNIT_DIED" then
		if UnitIsFeignDeath(destName) then return end

		local isPlayer = (bitband(destFlags, COMBATLOG_OBJECT_TYPE_PLAYER) ~= 0)
		local isGroup  = (bitband(destFlags, COMBATLOG_OBJECT_AFFILIATION_OUTSIDER) == 0)
		
		if isPlayer and isGroup then
			if #dead == 0 then
				self:ScheduleTimer(Casualty.Report, db.delay)
			end
			tinsert(dead, destName)
		end
	end
end

function Casualty:WipeCheck()
	local result = true
	if UnitInRaid("player") then
		for i=1,GetNumRaidMembers() do
			if not UnitIsDeadOrGhost(fmt("raid%s", i)) then
				result = false
			end
		end
	elseif GetNumPartyMembers ~= 0 then
		for i=0, GetNumPartyMembers() do
			if not UnitIsDeadOrGhost(fmt("party%s", i)) then
				result = false
			end
		end
	else
		result = false
	end
	return result
end

function Casualty:Report()
	local count = #dead
	local msg = fmt("|cffffff7f%s:|r %s", L["Casualty"], "%s")
	local snd = db.sound.casualty

	if db.wipe and Casualty:WipeCheck() then
		msg = fmt("|cffffff7f%s:|r %s", L["Casualty"], L["No Survivors"])
		snd = db.sound.wipe
	else
		if count > 1 then
			msg = fmt("|cffffff7f%s:|r %s", L["Casualties"], "%s")
			if count < db.mass then
				snd = db.sound.casualties
			else
				snd = db.sound.catastrophe
			end
		end
		msg = fmt(msg, tconcat(dead, ", "))
	end
	Casualty:Pour(msg, db.color.r, db.color.g, db.color.b)
	if db.noise then
		local sound = media:Fetch("sound",snd)
		if sound then PlaySoundFile(sound) end
	end
	wipe(dead)
end

function Casualty:Test()
	tinsert(dead, "Alice")
	tinsert(dead, "Bob")
	tinsert(dead, "Charlie")
	self:ScheduleTimer(Casualty.Report, db.delay)
end

