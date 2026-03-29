-- This actor doesn't seem to have any "easy" access to the particular Player it will be used for.
-- Getting the Player ActorFrame in the BeginCommand works, but feels a little hack-ish
-- and will likely break in whatever edge cases I'm not considering.
--
-- SM5.1's default theme uses ./Graphics/NoteColumn layers.lua to dynamically load HoldJudgments,
-- which seems to make use of SM5's NoteColumn system.  I can dig into that when this fails.

local function ResolvePlayerFromActor(self)
    local p1_af = GetPlayerAF("P1")
    local p2_af = GetPlayerAF("P2")

    local actor = self
    while actor do
        if p1_af and actor == p1_af then return "P1" end
        if p2_af and actor == p2_af then return "P2" end
        actor = actor:GetParent()
    end

    return nil
end

return Def.Sprite{
	BeginCommand=function(self)
		local label = "None 1x2.png"
        local pn = ResolvePlayerFromActor(self)

		-- force EditMode to use Love HoldJudgment for now
		if SCREENMAN:GetTopScreen():GetName():match("ScreenEdit") then
			label = "Love 1x2 (doubleres).png"

		elseif pn then
			label = SL[pn].ActiveModifiers.HoldJudgment or "None 1x2.png"
		end

		self:Load(THEME:GetPathG("", "_HoldJudgments/" .. label))
	end
}
