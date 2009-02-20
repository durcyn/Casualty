Casualty = LibStub("AceAddon-3.0"):NewAddon("Casualty", "AceEvent-3.0", "AceConsole-3.0", "AceTimer-3.0", "LibSink-2.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local L = LibStub:GetLibrary("AceLocale-3.0"):GetLocale("Casualty")

local media = LibStub("LibSharedMedia-3.0")
local sounds = media:List("sound")

local bitband = bit.band
local tinsert = table.insert
local getn = table.getn 
local strsub = string.sub
local ipairs = ipairs
local pairs = pairs

local function GetLSMIndex(t, value)
        for k, v in pairs(media:List(t)) do
                if v == value then
			return k
		end
	end
	return nil
end

local defaults = {
	profile = {
		sinkOptions = {
			sink20OutputSink = "ChatFrame",
		},
		delay = 1,
		mass = 8,
		catastrophe = true,
		wipe = true,
		sinkOptions = {},
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
					order = 1,
					type = 'range',
					name = L["Announcement Delay"],
					desc = L["Minimum delay between announcements"],
					min = 0,
					max = 5,
					step = 1,
					get = function()
						return Casualty.db.profile.delay
						end,
					set = function(i,v)
						Casualty.db.profile.delay = v
					end
				},
				color = {
					order = 2,
					type = 'color',
					name = L["Announcement Color"],
					desc = L["Color to use for announcements"],
					hasAlpha = false,
					get = function()
						return  unpack(Casualty.db.profile.color)
					end,
					set = function(i,r,g,b)
						Casualty.db.profile.color = {r,g,b}
					end
				},
				noise = {
					order = 3,
					type = 'toggle',
					name = L["Toggle Sound"],
					desc = L["Enable sounds"],
					get = function()
						return Casualty.db.profile.noise
					end,
					set = function(i,v)
						Casualty.db.profile.noise = v
					end
				},
				catastrophe = {
					order = 4,
					type = 'toggle',
					name = L["Catastrophe Announcements"],
					desc = L["Enable Catastrophe announcemen"],
					get = function()
						return Casualty.db.profile.catastrophe
					end,
					set = function(i,v)
						Casualty.db.profile.catastrophe = v
					end
				},
				threshold = {
					order = 5,
					type = 'range',
					name = L["Catastrophe Threshold"],
					desc = L["Number of simultaneous deaths to trigger Catastrophe announcement"],
					min = 1,
					max = 40,
					step = 1,
					get = function()
					return Casualty.db.profile.mass
						end,
					set = function(i,v)
						Casualty.db.profile.mass = v
					end
				},
				wipe = {
					order = 6,
					type = 'toggle',
					name = L["Wipe"],
					desc = L["Enable wipe announcement"],
					get = function()
						return Casualty.db.profile.wipe
					end,
					set = function(i,v)
						Casualty.db.profile.wipe = v
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
					order = 1,
					type = "select",
					name = L["Single Casualty"],
					desc = L["Single Casualty"],
					values = sounds,
					get = function(info) return GetLSMIndex("sound", Casualty.db.profile.sound.casualty) end,
					set = function(info, v)
						Casualty.db.profile.sound.casualty = sounds[v]
						PlaySoundFile(media:Fetch("sound", sounds[v]))
						end,
				},
				casualties = {
					order = 2,
					type = "select",
					name = L["Multiple Casualties"],
					desc = L["Multiple Casualties"],
					values = sounds,
					get = function(info) return GetLSMIndex("sound", Casualty.db.profile.sound.casualties) end,
					set = function(info, v)
						Casualty.db.profile.sound.casualties = sounds[v]
						PlaySoundFile(media:Fetch("sound", sounds[v]))
						end,
				},
				catastrophe = {
					order = 3,
					type = "select",
					name = L["Catastrophe"],
					desc = L["Catastrophe"],
					values = sounds,
					get = function(info) return GetLSMIndex("sound", Casualty.db.profile.sound.catastrophe) end,
					set = function(info, v)
						Casualty.db.profile.sound.catastrophe = sounds[v]
						PlaySoundFile(media:Fetch("sound", sounds[v]))
						end,
				},
				wipe = {
					order = 4,
					type = "select",
					name = L["Wipe"],
					desc = L["Wipe"],
					values = sounds,
					get = function(info) return GetLSMIndex("sound", Casualty.db.profile.sound.wipe) end,
					set = function(info, v)
						Casualty.db.profile.sound.wipe = sounds[v]
						PlaySoundFile(media:Fetch("sound", sounds[v]))
						end,
				},
			},
		},
	},
}

function Casualty:OnInitialize()
	AceConfig:RegisterOptionsTable("Casualty", options)
	self.db = LibStub("AceDB-3.0"):New("CasualtyDB", defaults, "Default")
	self:RegisterChatCommand("casualty", function() LibStub("AceConfigDialog-3.0"):Open("Casualty") end)
	local optFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Casualty", "Casualty")
	options.args.profile = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
	self:SetSinkStorage(self.db.profile.sinkOptions)

	self.units = {}
	self.dead = {}
	self.group = nil

	media:Register("sound", "Casualty: Single Casualty", [[Interface\Addons\Casualty\Sounds\casualty.wav]])
	media:Register("sound", "Casualty: Multiple Casualties", [[Interface\Addons\Casualty\Sounds\casualties.wav]])
	media:Register("sound", "Casualty: Catastrophe", [[Interface\Addons\Casualty\Sounds\mass_casualties.wav]])
	media:Register("sound", "Casualty: Wipe", [[Interface\Addons\Casualty\Sounds\no_survivors.wav]])
end

function Casualty:OnEnable()
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
end

function Casualty:OnDisable()
	self:UnregisterAllEvents()
end

function Casualty:COMBAT_LOG_EVENT_UNFILTERED(event, timestamp, eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, ...)
	if (eventType ~= "UNIT_DIED") then return end
	local isPlayer = (bitband(destFlags, COMBATLOG_OBJECT_TYPE_PLAYER) ~= 0)
	local isGroup  = (bitband(destFlags, COMBATLOG_OBJECT_AFFILIATION_OUTSIDER) == 0)

	if not isPlayer or not isGroup or UnitIsFeignDeath(destName) then return end

	if getn(self.dead) == 0 then
		self:ScheduleTimer(Casualty.Report, self.db.profile.delay)
	end
	tinsert(self.dead, destName)
end

function Casualty:WipeCheck()
	local result = true
	if UnitInRaid("player") then
		for i=1,GetNumRaidMembers() do
			local unit = "raid"..i
			if not (UnitIsDead(unit) or UnitIsGhost(unit)) then
				result = false
			end
		end
	elseif GetNumPartyMembers ~= 0 then
		for i=0, GetNumPartyMembers() do
			local unit = "party"..i
			if not (UnitIsDead(unit) or UnitIsGhost(unit))then
				result = false
			end
		end
	else
		result = false
	end
	return result
end

function Casualty:Report()
	local L = LibStub:GetLibrary("AceLocale-3.0"):GetLocale("Casualty")
	local dead = getn(Casualty.dead)
	local wipe = Casualty:WipeCheck()
	local msg = L["Casualty"]..": "
	local snd = Casualty.db.profile.sound.casualty

	if Casualty.db.profile.wipe and wipe then
		msg = L["Casualty"]..": "..L["No Survivors"]
		snd = Casualty.db.profile.sound.wipe
	else
		if dead > 1 then
			msg = L["Casualties"]..": "
			if dead < Casualty.db.profile.mass then
				snd = Casualty.db.profile.sound.casualties
			else
				snd = Casualty.db.profile.sound.catastrophe
			end
		end
		for k,v in ipairs(Casualty.dead) do
			msg = msg .. v..", "
		end
		msg = strsub(msg, 1, -3)
	end

	Casualty:Pour(msg, Casualty.db.profile.color.r, Casualty.db.profile.color.g, Casualty.db.profile.color.b)
	if Casualty.db.profile.noise then
		local media = LibStub("LibSharedMedia-3.0")
		local sound = media:Fetch("sound",snd)
		if sound then PlaySoundFile(sound) end
	end
	Casualty.dead = {}
end

function Casualty:Test()
	self.dead = {"Alice", "Bob", "Charlie"}
	self:ScheduleTimer(Casualty.Report, self.db.profile.delay)
end
