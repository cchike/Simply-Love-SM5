local player = ...
local pn = ToEnumShortString(player)

local mods = SL[pn].ActiveModifiers
if SL.Global.GameMode == "Casual" then return end
if not mods.CrossoverCues then return end

local columnMapping = GetColumnMapping(player)

-- Disable crossover cues if we couldn't compute valid columnMapping
if columnMapping == nil then return end

local playerState = GAMESTATE:GetPlayerState(player)

local numColumns = GAMESTATE:GetCurrentStyle():ColumnsPerPlayer()
local style = GAMESTATE:GetCurrentStyle(player)
local width = style:GetWidth(player)

local crossoverCues = {}

local yOffset = 80
local reverseOffset = THEME:GetMetric("Player", "ReceptorArrowsYReverse")
local fadeTime = 0.075
local curIndex = 1
local updatedFirstTime = false
local breakTime = 0
local text = nil

local font = mods.ComboFont
if font == "Wendy" or font == "Wendy (Cursed)" then
	font = "Wendy/_wendy small"
else
	font = "_Combo Fonts/" .. font .. "/"
end

local isCrossover = function(beat)
	if beat == nil then return false end
	for tech in ivalues(beat.tech) do
		if ToEnumShortString(tech) == "Crossovers" then
			return true
		end
	end
	return false
end

local getArrowCol = function(beat, isCrossover)
	for col, foot in pairs(beat.footPlacement) do
	-- For crossover steps, determines Left or Right
	-- For non-crossover steps, determines Down or Up
		if isCrossover and (col == 1 or col == 4) then
			return col
		elseif not isCrossover and (col == 2 or col == 3) then
			return col
		end
	end
	return nil
end

local buildCrossoverCues = function(crossoverCues)
	local timingData = SL[pn].Streams.TimingData
	local parsedTech = SL[pn].Streams.NoteAnnotations
	if timingData == nil or parsedTech == nil then
		return
	end	
	local duration = tonumber(mods.CrossoverCueDuration:gsub("ms",""), 10)/1000
	local spacingThreshold = 4/mods.CrossoverCueQuantization + .001 --Add a small buffer for rounding edge cases
	for i=2,#parsedTech do
		local currentBeat = parsedTech[i]
		local prevBeat = parsedTech[i-1]
		local nextBeat = i < #parsedTech and parsedTech[i+1] or nil
		-- if both currentBeat and prevBeat are crossovers, then currentBeat is a scooby which would've been handled when prevBeat was processed, so we can skip it
		if isCrossover(currentBeat) and not isCrossover(prevBeat) then
			-- if nextBeat is a crossover, then we process the current crossover as a scooby
			local isScooby = isCrossover(nextBeat)
			local nextNextBeat = (isScooby and i < #parsedTech+1) and parsedTech[i+2] or nil
			local firstCondition = currentBeat.beat - prevBeat.beat <= spacingThreshold
			local secondCondition = nextBeat ~= nil and nextBeat.beat - currentBeat.beat <= spacingThreshold
			local thirdCondition = nextNextBeat ~= nil and nextNextBeat.beat - nextBeat.beat <= spacingThreshold
			-- if the minimum quantization threshold is satisfied
			if firstCondition or secondCondition or thirdCondition then
				local crossoverCue = {}
				local prevArrowCol = getArrowCol(prevBeat, false)
				local currentArrowCol = getArrowCol(currentBeat, true)
				-- Throw away certain edge cases which don't make sense
				if prevArrowCol ~= nil and currentArrowCol ~= nil then
					local prevArrowTimePosition = timingData:GetElapsedTimeFromBeat(prevBeat.beat)
					crossoverCue.columns = {{colNum=currentArrowCol,isScooby=false},{colNum=prevArrowCol,isScooby=false}}
					crossoverCue.startTime = prevArrowTimePosition - duration
					crossoverCue.duration = duration + fadeTime
					-- If there's a large gap in time between the crossover arrow and the arrow before it,
					-- then we want the crossover cue to last until the actual crossover happens, not the arrow before it
					if not firstCondition then
						local curArrowTimePosition = timingData:GetElapsedTimeFromBeat(currentBeat.beat)
						crossoverCue.duration = crossoverCue.duration + (curArrowTimePosition - prevArrowTimePosition)
					end					
					if isScooby then
						local nextArrowCol = getArrowCol(nextBeat, true)
						crossoverCue.columns[#crossoverCue.columns+1] = {colNum=nextArrowCol,isScooby=true}
					end
					-- Ensure consecutive crossover cues don't overlap
					local prevCue = #crossoverCues > 0 and crossoverCues[#crossoverCues] or nil
					if prevCue ~= nil and crossoverCue.startTime < prevCue.startTime + prevCue.duration then
						local durationDifference = prevCue.startTime + prevCue.duration - crossoverCue.startTime
						crossoverCue.startTime = prevCue.startTime + prevCue.duration - fadeTime
						crossoverCue.duration = crossoverCue.duration - durationDifference + fadeTime
					end
					crossoverCues[#crossoverCues + 1] = crossoverCue
				end
			end
		end
	end
end

local Update = function(self, delta)
	if crossoverCues ~= nil and curIndex <= #crossoverCues then
		local curTime = playerState:GetSongPosition():GetMusicSecondsVisible()
		local columnCue = crossoverCues[curIndex]
		local startTime = columnCue.startTime
		local duration = columnCue.duration
		-- MusicSecondsVisible might be negative before the chart actually starts.
		-- In addition, sometimes charts might start on beat 0, and we still want to
		-- accurately display the first column cue. To do this, we just adjust the
		-- duration and start times of the first cue to account for this negative
		-- time.
		-- We only have to do this for the first column cue as the others should
		-- have accurate start times.
		-- TODO(teejusb): The timing for this seems to be off by a little bit. It's
		-- not toooo bad but see if we can make this more accurate.
		if curIndex == 1 and not updatedFirstTime and curTime < 0 then
			duration = duration - curTime
			startTime = startTime + curTime
			updatedFirstTime = true
		end
		if startTime <= curTime then
			--For Practice Mode: Ignore any cues that begin long before the start time, since legitimate cues will only fire when curTime and startTime are nearly equal
			if curTime - startTime < .01 then
				-- Get the current music rate.
				-- Note that Lua files might change the rate mode so this might not be accurate.
				-- It's hard to handle that case since we don't exactly know when a file will apply a rate mod.
				local rate = SL.Global.ActiveModifiers.MusicRate
				local scaledDuration = duration / rate
				-- Make sure there's still something to display after any potential scaling.
				if scaledDuration > 2 * fadeTime then
					for col_mine in ivalues(columnCue.columns) do
						local col = columnMapping[col_mine.colNum]
						local isScooby = col_mine.isScooby
						self:GetChild("Column"..col):GetChild("ColumnFlash"):playcommand("Flash", {
							duration=scaledDuration,
							isScooby=isScooby
						})
					end
				end
			end
			curIndex = curIndex + 1
		end
	end
end

local af = Def.ActorFrame{
	InitCommand=function(self)
		self:xy( GetNotefieldX(player), yOffset)
		local zoom_factor = 1 - scale( mods.Mini:gsub("%%","")/100, 0, 2, 0, 1)
		self:zoomx( zoom_factor )
		self:queuecommand("SetUpdate")
	end,
	SetUpdateCommand=function(self)
		self:SetUpdateFunction(Update)
	end,
	CurrentSongChangedMessageCommand=function(self)
		playerState = GAMESTATE:GetPlayerState(player)
		crossoverCues = {}
		buildCrossoverCues(crossoverCues)
		curIndex = 1
		updatedFirstTime = false
	end,
	PlayingCommand=function(self)
		curIndex = 1
	end,
}

local IsReversedColumn = function(player, columnIndex)
	local columns = {}
	for i=1, numColumns do
		columns[#columns + 1] = false
	end

	local opts = GAMESTATE:GetPlayerState(player):GetCurrentPlayerOptions()
	if opts:Reverse() == 1 then
		for column,val in ipairs(columns) do
			columns[column] = not val
		end
	end

	if opts:Alternate() == 1 then
		for column,val in ipairs(columns) do
			if column % 2 == 0 then
				columns[column] = not val
			end
		end
	end

	if opts:Split() == 1 then
		for column,val in ipairs(columns) do
			if column > numColumns / 2 then
				columns[column] = not val
			end
		end
	end

	if opts:Cross() == 1 then
		local firstChunk = numColumns / 4
		local lastChunk = numColumns - firstChunk
		for column,val in ipairs(columns) do
			if column > firstChunk and column <= lastChunk then
				columns[column] = not val
			end
		end
	end

	return columns[columnIndex]
end

for columnIndex=1,numColumns do
	af[#af+1] = Def.ActorFrame{
		Name="Column"..columnIndex,
		Def.Quad{
			Name="ColumnFlash",
			InitCommand=function(self)
				self:diffuse(0,0,0,0)
					:x((columnIndex - (numColumns/2 + 0.5)) * (width/numColumns))
					:vertalign(top)
					:setsize(width/numColumns, _screen.h - yOffset - 270)
					:fadebottom(0.333)
				
				local spacing = mods.Spacing:gsub("%%","")/100
				self:addx((columnIndex - (numColumns/2 + 0.5))*2 * (width/numColumns) * spacing)

				if IsReversedColumn(player, columnIndex) then
					self:rotationz(180)
					self:y(yOffset * 2 + reverseOffset + (width/numColumns)/2)
				end
			end,
			FlashCommand=function(self, params)
				local flashDuration = params.duration
				local clr = params.isScooby and color("1,0,0,0.12") or color("0.3,1,1,0.12")
				if mods.ColumnCues then
					self:stoptweening()
						:decelerate(fadeTime)
						:diffuse(clr)
						:sleep(flashDuration - 2*fadeTime)
						:accelerate(fadeTime)
						:diffuse(0,0,0,0)
				end
				if flashDuration >= 5 and mods.ColumnCountdown then
					breakTime = flashDuration
					if text ~= nil then
						text:stoptweening()
							:x((columnIndex - (numColumns/2 + 0.5)) * (width/numColumns))
							:decelerate(fadeTime)
							:diffuse(Color.White)
							:settext(round(flashDuration, 1))
							:playcommand("UpdateBreak")
					end
				end
			end
		},
		Def.BitmapText {
			Name="ColumnText",
			Font=font,
			Text="",
			InitCommand=function(self)
				local zoom_factor = 1 - scale( mods.Mini:gsub("%%","")/100, 0, 2, 0, 1)
				self:zoom(0.5)
					:zoomx(0.5/zoom_factor)
					:diffuse(0,0,0,0)
					:horizalign(center)
					:x((columnIndex - (numColumns/2 + 0.5)) * (width/numColumns))
				
				if IsReversedColumn(player, columnIndex) then
					self:y(260)
				else
					self:y(80)
				end
					
				text = self
			end,
			UpdateBreakCommand=function(self)
				-- if BreakTime == nil then BreakTime = 0 end
				if breakTime > 0.5 then
					breakTime = breakTime - 0.1
					if breakTime > 0.5 then
						self:sleep(0.1)
							:settext(round(breakTime))
							:queuecommand("UpdateBreak")
					else
						self:diffuse(0,0,0,0)
					end
				else
					self:diffuse(0,0,0,0)
				end
			end,
		}
	}
end

buildCrossoverCues(crossoverCues)

return af