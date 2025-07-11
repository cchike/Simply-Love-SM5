local player = ...
local pn = ToEnumShortString(player)

local mods = SL[pn].ActiveModifiers
local IsUltraWide = (GetScreenAspectRatio() > 21/9)
local NumPlayers = #GAMESTATE:GetHumanPlayers()
local IsEX = SL[pn].ActiveModifiers.ShowExScore

-- -----------------------------------------------------------------------
-- first, check for conditions where we might not draw the score actor at all

if mods.HideScore then return end

if NumPlayers > 1
and mods.NPSGraphAtTop
and not IsUltraWide
then
	return
end

-- -----------------------------------------------------------------------
-- set up some preliminary variables and calculations for positioning and zooming

local styletype = ToEnumShortString(GAMESTATE:GetCurrentStyle():GetStyleType())

-- scores are not aligned symmetrically around screen.cx for aesthetic reasons
-- and this is the cause of many code-induced headaches
local pos = {
	[PLAYER_1] = { x=(_screen.cx - clamp(_screen.w, 640, 854)/4.3),  y=56 },
	[PLAYER_2] = { x=(_screen.cx + clamp(_screen.w, 640, 854)/2.75), y=56 },
}

local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats(player)

local StepsOrTrail = (GAMESTATE:IsCourseMode() and GAMESTATE:GetCurrentTrail(player)) or GAMESTATE:GetCurrentSteps(player)
local total_tapnotes = StepsOrTrail:GetRadarValues(player):GetValue( "RadarCategory_Notes" )

-- determine how many digits are needed to express the number of notes in base-10
local digits = (math.floor(math.log10(total_tapnotes)) + 1)
-- subtract 4 from the digit count; we're only really interested in how many digits past 4
-- this stepcount is so we can use it to align the score actor in the StepStats pane if needed
-- aligned-with-4-digits is the default
digits = clamp(math.max(4, digits) - 4, 0, 3)

local NoteFieldIsCentered = (GetNotefieldX(player) == _screen.cx)

local ar_scale = {
	sixteen_ten  = 0.825,
	sixteen_nine = 1
}
local zoom_factor = clamp(scale(GetScreenAspectRatio(), 16/10, 16/9, ar_scale.sixteen_ten, ar_scale.sixteen_nine), 0, 1.125)

-- -----------------------------------------------------------------------

return LoadFont(ThemePrefs.Get("ThemeFont") .. " numbers")..{
	Text="0.00",
	Name=pn.."Score",
	InitCommand=function(self)
		self:valign(1):horizalign(right)
		self:zoom(0.20)
		if IsEX then
			-- If EX Score, let's diffuse it to be the same as the ITG top window.
			-- This will make it consistent with the EX Score Pane.
			self:diffuse(SL.JudgmentColors["ITG"][1])
			self:settext("100.00")
		end
	end,

	BeginCommand=function(self)
		-----------------------------------------------------------------
		-- ultrawide with both players joined is really its own layout
		-- hardcode some numbers for now, return early, and call it a day
		-- until 21:9 displays become more popular
		if IsUltraWide and #GAMESTATE:GetHumanPlayers() > 1 then
			if player==PLAYER_1 then
				self:x(134)
			else
				self:x(_screen.w - 4)
			end

			self:y( 238 )
			return
		end
		-----------------------------------------------------------------

		-- assume "normal" score positioning first, but there are many reasons it will need to be moved
		self:xy( pos[player].x, pos[player].y )

		--if mods.NPSGraphAtTop and
		if styletype ~= "OnePlayerTwoSides" then
			-- if NPSGraphAtTop and Step Statistics and not double,
			-- move the score down into the stepstats pane under
			-- the judgment breakdown
			if mods.DataVisualizations=="Step Statistics" then
				local step_stats = self:GetParent():GetChild("StepStatsPane"..pn)

				-- Step Statistics might be true in the SL table from a previous game session
				-- but current conditions might be such that it won't actually appear.
				-- Ensure the StepStats ActorFrame is present before trying to traverse it.
				if step_stats then
					if player==PLAYER_1 then
						if NoteFieldIsCentered then
							self:x( pos[ OtherPlayer[player] ].x + SL_WideScale(-75, -124) )
							self:y( SL_WideScale(150, 92) )
						else
							self:x( pos[ OtherPlayer[player] ].x + SL_WideScale(-167, -244) )
							self:y( 75 )
						end

					-- PLAYER_2
					else
						if NoteFieldIsCentered then
							self:x( pos[ OtherPlayer[player] ].x + SL_WideScale(32, 65) )
							self:y( SL_WideScale(150, 92) )
						else
							self:x( pos[ OtherPlayer[player] ].x - SL_WideScale(-141, -189))
							self:y( 75 )
						end
					end

					
				end

			-- if not Step Statistics but NPSGraphAtTop 
			elseif mods.NPSGraphAtTop then
				-- if not Center1Player, move the score right or left
				-- within the normal gameplay header to where the
				-- other player's score would be if this were versus
				if not NoteFieldIsCentered then
					self:x( pos[ OtherPlayer[player] ].x )
					self:y( pos[ OtherPlayer[player] ].y )
				end
				-- if NoteFieldIsCentered, no need to move the score
			end
		end
	end,
	JudgmentMessageCommand=function(self)
		self:queuecommand("RedrawScore")
	end,
	RedrawScoreCommand=function(self)
		if not IsEX then
			local dance_points = pss:GetPercentDancePoints()
			local percent = FormatPercentScore( dance_points ):sub(1,-2)
			self:settext(percent)
		end
	end,					
	ExCountsChangedMessageCommand=function(self, params)
		if params.Player ~= player then return end
		if IsEX then
			local total_possible = params.actual_possible
			local counts = params.ExCounts
			exWeights = SL["ExWeights"]
			W0 = exWeights["W0"]
			W1 = exWeights["W1"]
			W2 = exWeights["W2"]
			W3 = exWeights["W3"]
			W4 = exWeights["W4"]
			W5 = exWeights["W5"]
			miss = exWeights["Miss"]
			letGo = exWeights["LetGo"]
			held = exWeights["Held"]
			hitMine = exWeights["HitMine"]
			

			local dp_lost = counts["W1"]*(W0-W1) + counts["W2"]*(W0-W2) + counts["W3"]*(W0-W3) + counts["W4"]*(W0-W4) + counts["W5"]*(W0-W5) + counts["Miss"]*(W0-miss) + counts["LetGo"]*(held-letGo) + counts["HitMine"]*(-hitMine)
			
			self:settext(("%.02f"):format(100*(total_possible-dp_lost)/total_possible))
		end
	end,
}