local player = ...
local pn = ToEnumShortString(player)
local mods = SL[pn].ActiveModifiers
local NoteFieldIsCentered = (GetNotefieldX(player) == _screen.cx)

-- if no BackgroundFilter is necessary, it's safe to bail now
if mods.BackgroundFilter == 0 then return end
local quintin_tarandimo = mods.ShowFaPlusWindow and true or false -- do we want to show quint combo when the user doesnt have FA+ window enabled?

local FilterAlpha = {
	Dark = 0.5,
	Darker = 0.75,
	Darkest = 0.95
}

return Def.Quad{
	InitCommand=function(self)
		self:xy(GetNotefieldX(player), _screen.cy )
			:diffuse(Color.Black)
			:diffusealpha( mods.BackgroundFilter / 100 )
			:zoomto( GetNotefieldWidth() + 80, _screen.h )
			:fadeleft(0.1):faderight(0.1)
		if NoteFieldIsCentered and (SL[pn].ActiveModifiers.DataVisualizations ~= "None" or (ThemePrefs.Get("EnableTournamentMode") and ThemePrefs.Get("StepStats") == "Show")) then
			if pn == "P1" then
				self:zoomto( GetNotefieldWidth() + 40, _screen.h ):addx(-20):faderight(0)
			else
				self:zoomto( GetNotefieldWidth() + 40, _screen.h ):addx(20):fadeleft(0)
			end
		end
	end,
	OffCommand=function(self) self:queuecommand("ComboFlash") end,
	JudgmentMessageCommand=function(self, params)
		if params.Player ~= player then return end
		if not params.TapNoteScore then return end
		if params.HoldNoteScore then return end
		
		local tns = ToEnumShortString(params.TapNoteScore)
		if tns == "AvoidMine" then return end

		-- ghetto quint support
		if not IsW0Judgment(params, player) then quintin_tarandimo = false end

	end,
	ComboFlashCommand=function(self)
		local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats(player)
		local FlashColor = nil
		local WorstAcceptableFC = SL.Preferences[SL.Global.GameMode].MinTNSToHideNotes:gsub("TapNoteScore_W", "")

		for i=1, tonumber(WorstAcceptableFC) do
			if pss:FullComboOfScore("TapNoteScore_W"..i) and quintin_tarandimo then
				FlashColor = color("#E928FF")
				break
			elseif pss:FullComboOfScore("TapNoteScore_W"..i) then
				FlashColor = SL.JudgmentColors[SL.Global.GameMode][i]
				break
			end
		end

		if (FlashColor ~= nil) then
			self:accelerate(0.25):diffuse( FlashColor )
				:accelerate(0.5):faderight(1):fadeleft(1)
				:accelerate(0.15):diffusealpha(0)
		end
	end
}