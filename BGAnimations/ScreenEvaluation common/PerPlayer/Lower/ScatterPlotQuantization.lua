-- if we're in CourseMode, bail now
-- the normal LifeMeter graph (Def.GraphDisplay) will be drawn
if GAMESTATE:IsCourseMode() then return end

-- arguments passed in from Graphs.lua
local args = ...
local player = args.player
local GraphWidth = args.GraphWidth
local GraphHeight = args.GraphHeight
local red, blue, purple, green, pink, yellow, light_pink, teal = color("#e80000"), color("#0066ff"), color("#9500ff"), color("#00ff00"), color("#ff6699"), color("#ffff00"), color("#ffcde0"), color("#00e8e5")

local pn = ToEnumShortString(player)
local mods = SL[pn].ActiveModifiers

-- sequential_offsets gathered in ./BGAnimations/ScreenGameplay overlay/JudgmentOffsetTracking.lua
local sequential_offsets = SL[pn].Stages.Stats[SL.Global.Stages.PlayedThisGame + 1].sequential_offsets
local death_second = SL[pn].Stages.Stats[SL.Global.Stages.PlayedThisGame + 1].DeathSecond
local MusicRate = SL.Global.ActiveModifiers.MusicRate

-- a table to store the AMV's vertices
-- this will be a table of tables, to get around ActorMultiVertex limitations on D3D renderer
local vertsTable= {}
local Steps = GAMESTATE:GetCurrentSteps(player)
local TimingData = Steps:GetTimingData()
-- FirstSecond and LastSecond are used in scaling the x-coordinates of the AMV's vertices
local FirstSecond = math.min(TimingData:GetElapsedTimeFromBeat(0), 0)
local LastSecond = GAMESTATE:GetCurrentSong():GetLastSecond()

-- Parsed tech object used for determining quantization (required)
local parsedTech = SL[pn].Streams.NoteAnnotations
if parsedTech == nil then return end

-- variables that will be used and re-used in the loop while calculating the AMV's vertices
local Offset, CurrentSecond, TimingWindow, x, y, c, r, g, b

-- ---------------------------------------------
-- scale worst_window to the worst judgment hit in the song
-- start at Excellent window as the worst window since most quads are
-- hard to make sense of visually
-- EDIT: Removed Excellent start point
local worst_window = GetTimingWindow(GetWorstJudgment(sequential_offsets))

-- cap worst_window to Excellent if selected by the player
if mods.ScaleGraph then
	worst_window = math.min(worst_window, SL.Global.GameMode == "FA+" and GetTimingWindow(3) or GetTimingWindow(2))
end

-- ---------------------------------------------

vertsTable[#vertsTable+1] = {}
local stepCount = 0
for t in ivalues(sequential_offsets) do
	stepCount = stepCount + 1
	if stepCount >= 8192 then
		stepCount = 0
		vertsTable[#vertsTable+1] = {}
	end
	local verts = vertsTable[#vertsTable]
	
	CurrentSecond = t[1]
	Offset = t[2]
	
	-- Include a small buffer for edge cases
	local currentBeat = parsedTech[stepCount].beat + 0.001
	if currentBeat % (1/1) < 0.01 then
		-- 4th note
		c = red
	elseif currentBeat % (1/2) < 0.01 then
		-- 8th note
		c = blue
	elseif currentBeat % (1/3) < 0.01 then
		-- 12th note
		c = purple
	elseif currentBeat % (1/4) < 0.01 then
		-- 16th note
		c = green
	elseif currentBeat % (1/6) < 0.01 then
		-- 24th note
		c = pink
	elseif currentBeat % (1/8) < 0.01 then
		-- 32nd note
		c = yellow
	elseif currentBeat % (1/12) < 0.01 then
		-- 48th note
		c = light_pink
	else
		-- 64th or 192nd note
		c = teal
	end
	
	EarlyHit = t[6]
	EarlyOffset = t[7]
	HeldMiss = t[8]

	if Offset ~= "Miss" then
		CurrentSecond = CurrentSecond - Offset
	else
		CurrentSecond = CurrentSecond - worst_window
	end

	-- pad the right end because the time measured seems to lag a little...
	x = scale(CurrentSecond, FirstSecond, LastSecond + 0.05, 0, GraphWidth)

	-- get the red, green, and blue values from that color
	r = c[1]
	g = c[2]
	b = c[3]

	if Offset ~= "Miss" and (math.abs(Offset) <= worst_window or not mods.ScaleGraph) then
		-- DetermineTimingWindow() is defined in ./Scripts/SL-Helpers.lua
		TimingWindow = DetermineTimingWindow(Offset)
		y = scale(Offset, worst_window, -worst_window, 0, GraphHeight)

		-- insert four datapoints into the verts tables, effectively generating a single quadrilateral
		-- top left,  top right,  bottom right,  bottom left
		if death_second ~= nil and CurrentSecond / MusicRate > death_second then
			table.insert( verts, {{x,y,0}, {r,g,b,0.333}} )
			table.insert( verts, {{x+1.5,y,0}, {r,g,b,0.333}} )
			table.insert( verts, {{x+1.5,y+1.5,0}, {r,g,b,0.333}} )
			table.insert( verts, {{x,y+1.5,0}, {r,g,b,0.333}} )
		else
			table.insert( verts, {{x,y,0}, {r,g,b,0.666}} )
			table.insert( verts, {{x+1.5,y,0}, {r,g,b,0.666}} )
			table.insert( verts, {{x+1.5,y+1.5,0}, {r,g,b,0.666}} )
			table.insert( verts, {{x,y+1.5,0}, {r,g,b,0.666}} )
		end
		
		-- Plot early hits if they are being tracked, at lower opacity
		if EarlyHit then
			-- DetermineTimingWindow() is defined in ./Scripts/SL-Helpers.lua
			TimingWindow = DetermineTimingWindow(EarlyOffset)
			y = scale(EarlyOffset, worst_window, -worst_window, 0, GraphHeight)

			-- insert four datapoints into the verts tables, effectively generating a single quadrilateral
			-- top left,  top right,  bottom right,  bottom left
			if death_second ~= nil and CurrentSecond / MusicRate > death_second then
				table.insert( verts, {{x,y,0}, {r,g,b,0.15}} )
				table.insert( verts, {{x+1.5,y,0}, {r,g,b,0.15}} )
				table.insert( verts, {{x+1.5,y+1.5,0}, {r,g,b,0.15}} )
				table.insert( verts, {{x,y+1.5,0}, {r,g,b,0.15}} )
			else
				table.insert( verts, {{x,y,0}, {r,g,b,0.3}} )
				table.insert( verts, {{x+1.5,y,0}, {r,g,b,0.3}} )
				table.insert( verts, {{x+1.5,y+1.5,0}, {r,g,b,0.3}} )
				table.insert( verts, {{x,y+1.5,0}, {r,g,b,0.3}} )
			end
		end
	else
		-- else, a miss should be a quadrilateral that is the height of half of the graph and red
		-- if the miss is held, fill the upper half. otherwise, fill the lower half
		-- if the graph is capped to Greats, use these too
		local h1 = HeldMiss and GraphHeight/2 or 0
		local h2 = HeldMiss and GraphHeight or GraphHeight/2
		if Offset ~= "Miss" then
			h1 = Offset>0 and 0 or GraphHeight/2
			h2 = Offset>0 and GraphHeight/2 or GraphHeight
		end
		if death_second ~= nil and CurrentSecond / MusicRate > death_second then
			col = {r,g,b,0.08}
			table.insert( verts, {{x, h1, h1}, col} )
			table.insert( verts, {{x+1, h1, h1}, col} )
			table.insert( verts, {{x+1, h2, h2}, col} )
			table.insert( verts, {{x, h2, h2}, col} )
		else
			col = {r,g,b,0.3}
			table.insert( verts, {{x, h1, h1}, col} )
			table.insert( verts, {{x+1, h1, h1}, col} )
			table.insert( verts, {{x+1, h2, h2}, col} )
			table.insert( verts, {{x, h2, h2}, col} )
		end
	end
end

-- the scatter plot will use an ActorMultiVertex in "Quads" mode
-- this is more efficient than drawing n Def.Quads (one for each judgment)
-- because the entire AMV will be a single Actor rather than n Actors with n unique Draw() calls.
local af = Def.ActorFrame{Name="QuantizationPlot"}

for verts in ivalues(vertsTable) do
	local amv = Def.ActorMultiVertex{
		InitCommand=function(self) self:x(-GraphWidth/2) end,
		OnCommand=function(self)
			self:SetDrawState({Mode="DrawMode_Quads"})
				:SetVertices(verts)
		end,
	}
	af[#af+1] = amv
end

return af
