-- This early/late indicator was made by SteveReen for the Waterfall theme and
-- later modified for SL.

local player, layout = ...
local mods = SL[ToEnumShortString(player)].ActiveModifiers
local eightMsOverride = mods.EightMs ~= "Off"

local hideEarlyJudgment = mods.HideEarlyDecentWayOffJudgments and true or false

local threshold = nil
for i = 1, NumJudgmentsAvailable() do
    if mods.TimingWindows[i] then
        if i == 1 and mods.ShowFaPlusWindow then
            threshold = GetTimingWindow(1, "FA+", mods.SmallerWhite, eightMsOverride)
        else
            threshold = GetTimingWindow(i)
        end
        break
    end
end

local W2 = SL.Preferences.ITG.TimingWindowSecondsW1 + SL.Preferences.ITG.TimingWindowAdd
local W1 = SL.Preferences["FA+"].TimingWindowSecondsW1 + SL.Preferences.ITG.TimingWindowAdd

local function DisplayText(self, params)
    local score = ToEnumShortString(params.TapNoteScore)
    if score == "W1" or score == "W2" or score == "W3" or score == "W4" or score == "W5" then
        if math.abs(params.TapNoteOffset) > threshold then
            self:finishtweening()

			-- Scale size of early/late text depending on offset (worse errors -> bigger text)
			local noteOffset = math.abs(params.TapNoteOffset)
			local scale1 = 1
			local scale2 = 1
			
			local smallerWhiteWindow = GetTimingWindow(1, "FA+", true, eightMsOverride)
			
			if smallerWhiteWindow < noteOffset and noteOffset <= W1 and mods.SmallerWhite then
				scale1 = (noteOffset - smallerWhiteWindow)/(W1 - smallerWhiteWindow)
			elseif W1 < noteOffset and noteOffset <= W2 then
				scale2 = (noteOffset - W1)/(W2 - W1)
			end
			
			self:diffusealpha(1)
				:x((params.Early and -1 or 1) * 60)
				:zoom(0.15 + (scale1*0.2) + (scale2*0.1))
                :settext(params.Early and "FAST" or "SLOW")
                :diffuse(params.Early and color("#0051db") or color("#ff1605"))
                :sleep(0.5)
                :diffusealpha(0)
        else
            self:finishtweening()
            self:diffusealpha(0)
        end
    end
end

local af = Def.ActorFrame{
    OnCommand = function(self)
        self:xy(GetNotefieldX(player), layout.y-10)
    end,

    LoadFont("Wendy/_wendy small")..{
        Text = "",
        InitCommand = function(self)
            self:zoom(0.25):shadowlength(1)
        end,
        EarlyHitMessageCommand=function(self, params)
            if params.Player ~= player or hideEarlyJudgment then return end
    
            DisplayText(self, params)
        end,
        JudgmentMessageCommand = function(self, params)
            if params.Player ~= player then return end
            if params.HoldNoteScore then return end

            if params.EarlyTapNoteScore ~= nil then
                local tns = ToEnumShortString(params.TapNoteScore)
                local earlyTns = ToEnumShortString(params.EarlyTapNoteScore)
    
                if earlyTns ~= "None" then
                    if SL.Global.GameMode == "FA+" then
                        if tns == "W5" then
                            return
                        end
                    else
                        if tns == "W4" or tns == "W5" then
                            return
                        end
                    end
                end
            end

            DisplayText(self, params)
        end
    },
}

return af
