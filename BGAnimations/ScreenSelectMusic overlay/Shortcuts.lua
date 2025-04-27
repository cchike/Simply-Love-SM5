local ShortcutHandler = function(event)
	if not event then return end

	if event.type == "InputEventType_FirstPress" then
		if event.DeviceInput.button == "DeviceButton_s" then
            -- Song Search
            SCREENMAN:GetTopScreen():GetChild("Overlay"):queuecommand("DirectInputToEngineForSongSearch")
		elseif event.DeviceInput.button == "DeviceButton_t" then
            -- Test Input
            SCREENMAN:GetTopScreen():GetChild("Overlay"):queuecommand("DirectInputToTestInput")
		elseif event.DeviceInput.button == "DeviceButton_p" then
            -- Practice Mode
            SCREENMAN:GetTopScreen():SetNextScreenName("ScreenPractice")
			SCREENMAN:GetTopScreen():StartTransitioningScreen("SM_GoToNextScreen")
		elseif event.DeviceInput.button == "DeviceButton_l" then
			-- Load New Songs
			SCREENMAN:GetTopScreen():SetNextScreenName("ScreenReloadSongsSSM")
			SCREENMAN:GetTopScreen():StartTransitioningScreen("SM_GoToNextScreen")
        end
	end
end

local t = Def.ActorFrame{
	Name="ShortcutHandlerAF",
	OnCommand=function(self)
		if ThemePrefs.Get("KeyboardFeatures") and PREFSMAN:GetPreference("EventMode") and not GAMESTATE:IsCourseMode() then
			SCREENMAN:GetTopScreen():AddInputCallback(ShortcutHandler)				
		end
	end
}

return t
