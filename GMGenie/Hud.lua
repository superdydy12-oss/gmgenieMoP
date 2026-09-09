--This file is part of Game Master Genie.
--Copyright 2011-2014 Chocochaos

--Game Master Genie is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 3 of the License.
--Game Master Genie is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
--You should have received a copy of the GNU General Public License along with Game Master Genie. If not, see <http://www.gnu.org/licenses/>.

GMGenie.Hud = {};
GMGenie.Lookup = {
	active = false,
	resultCount = 0,
	results = {},
};

--GMGenie.Hud.waitingForUldumGath = false;
--GMGenie.Hud.waitingForHyjalGath = false;

function GMGenie.Hud.onLoad()
    GMGenie_Hud:RegisterEvent("PLAYER_ENTERING_WORLD");
    GMGenie_Hud:RegisterEvent("UI_ERROR_MESSAGE");
    GMGenie_Hud:SetScript("OnEvent", GMGenie.Hud.readNotice);
    GMGenie_Hud_GM:SetAttribute("macrotext1", "/run GMGenie.Hud.toggleGm();");
    GMGenie_Hud_Chat:SetAttribute("macrotext1", "/run GMGenie.Hud.toggleChat();");
	SendChatMessage(".gm visible off", "GUILD");
--    GMGenie_Hud_Visibility:SetAttribute("macrotext1", "/run GMGenie.Hud.toggleVisibility();");
    GMGenie_Hud_Whisper:SetAttribute("macrotext1", "/run GMGenie.Hud.toggleWhisper();");
    GMGenie_Hud_Fly:SetAttribute("macrotext1", "/target " .. UnitName("player") .. " \n/run GMGenie.Hud.toggleFly();");

    if GMGenie_SavedVars.SavedSpeed then
	else
		GMGenie_SavedVars.SavedSpeed = 10;
		GMGenie.showGMMessage("No default speed found, setting to 10.");
    end
	GMGenie_Hud_Speed:SetText(GMGenie_SavedVars.SavedSpeed);
	
	if GMGenie_SavedVars.hudClosed then
        GMGenie.Hud.toggle();
    end

    Chronos.schedule(1, GMGenie.Hud.checkStatus);
    GMGenie.Hud.flyStatus(false);
end

function GMGenie.Hud.toggle()
    if GMGenie_Hud:IsVisible() then
        GMGenie_Hud:Hide();
        GMGenie_SavedVars.hudClosed = true;
    else
        GMGenie_Hud:Show();
        GMGenie_SavedVars.hudClosed = false;
    end
end

function GMGenie.Hud.setPresetSpeed(speed)
	GMGenie_Hud_Speed:SetText(tostring(speed));
	GMGenie.Hud.setSpeed();
end

function GMGenie.Hud.setStatusButton(button, label, status)
	if not button then return end
	if status then
		button:SetText("|cff3ee6a8" .. label .. "  ON|r");
		button:SetBackdropColor(0.02, 0.2, 0.14, 0.98);
		button:SetBackdropBorderColor(0.24, 0.95, 0.65, 1);
	else
		button:SetText("|cff8492a6" .. label .. "  OFF|r");
		button:SetBackdropColor(0.025, 0.055, 0.085, 0.98);
		button:SetBackdropBorderColor(0.12, 0.38, 0.46, 1);
	end
end

function GMGenie.Hud.setVisibilityMode(mode)
	local buttons = {
		visible = GMGenie_Hud_VisibilityON,
		invisible = GMGenie_Hud_VisibilityOFF,
		gm = GMGenie_Hud_VisibilityGM,
	};
	for buttonMode, button in pairs(buttons) do
		if buttonMode == mode then
			button:SetBackdropColor(0.24, 0.16, 0.015, 0.98);
			button:SetBackdropBorderColor(1, 0.78, 0.2, 1);
		else
			button:SetBackdropColor(0.025, 0.055, 0.085, 0.98);
			button:SetBackdropBorderColor(0.12, 0.48, 0.58, 1);
		end
	end
	GMGenie.Hud.visibilityMode = mode;
end

function GMGenie.Hud.lookup(lookupType)
	local allowedTypes = {
		creature = true,
		item = true,
		quest = true,
	};
	if not allowedTypes[lookupType] then
		GMGenie.showGMMessage("Invalid lookup type.");
		return false;
	end

	local query = GMGenie_Hud_LookupText:GetText() or "";
	query = strtrim(query);
	query = string.gsub(query, "[\r\n\"]", "");
	query = strtrim(query);
	if query == "" then
		GMGenie.showGMMessage("Enter a creature, item or quest name first.");
		GMGenie_Hud_LookupText:SetFocus();
		return false;
	end

	-- Keep the complete chat command comfortably below the MoP message limit.
	query = string.sub(query, 1, 180);
	GMGenie_Hud_LookupText:SetText(query);
	GMGenie_Hud_LookupText:ClearFocus();
	GMGenie.Lookup.start(lookupType, query);
	SendChatMessage(".lookup " .. lookupType .. " " .. query, "GUILD");
	return true;
end

function GMGenie.Lookup.onLoad(frame)
	GMGenie.loadWindow(frame, "Lookup results", false, nil);
	local output = GMGenie_LookupResults_Output;
	output:SetFontObject(ChatFontNormal);
	output:SetFading(false);
	output:SetMaxLines(500);
	output:SetHyperlinksEnabled(true);
	output:SetScript("OnMouseWheel", function(self, delta)
		if delta > 0 then self:ScrollUp(); else self:ScrollDown(); end
	end);
	output:SetScript("OnHyperlinkClick", function(self, link, text, button)
		SetItemRef(link, text, button, self);
	end);
end

function GMGenie.Lookup.start(lookupType, query)
	GMGenie.Lookup.active = true;
	GMGenie.Lookup.resultCount = 0;
	GMGenie.Lookup.results = {};
	GMGenie.Lookup.colourRetries = 0;
	GMGenie.Lookup.lookupType = lookupType;
	GMGenie.Lookup.query = query;
	GMGenie.Lookup.lastMessage = nil;
	GMGenie.Lookup.lastMessageAt = nil;

	GMGenie_LookupResults:Show();
	GMGenie_LookupResults_Title_Text:SetText("Lookup results: " .. lookupType);
	local output = GMGenie_LookupResults_Output;
	output:Clear();
	Chronos.unscheduleByName("gmgenieLookupItemColours");
	Chronos.scheduleByName("gmgenieLookupTimeout", 4, GMGenie.Lookup.finish);
end

function GMGenie.Lookup.finish()
	GMGenie.Lookup.active = false;
end

function GMGenie.Lookup.clear()
	GMGenie.Lookup.results = {};
	Chronos.unscheduleByName("gmgenieLookupItemColours");
	if GMGenie_LookupResults_Output then
		GMGenie_LookupResults_Output:Clear();
	end
end

function GMGenie.Lookup.getItemDisplay(id)
	local _, itemLink, quality = GetItemInfo(tonumber(id));
	if quality ~= nil and itemLink then
		return itemLink, false;
	end
	-- GetItemInfo also requests uncached item data from the server.
	return nil, true;
end

function GMGenie.Lookup.redraw()
	if not GMGenie_LookupResults_Output then return end
	GMGenie_LookupResults_Output:Clear();
	local waitingForItem = false;

	for _, result in ipairs(GMGenie.Lookup.results) do
		local itemLink = nil;
		if result.isResult and result.lookupType == "item" then
			local waiting;
			itemLink, waiting = GMGenie.Lookup.getItemDisplay(result.id);
			if waiting then waitingForItem = true end
		end

		if result.isResult and result.lookupType == "item" and result.id and itemLink then
			-- GetItemInfo supplies the complete native link. Keep the entry ID
			-- white and make only the quality-coloured item name interactive.
			GMGenie_LookupResults_Output:AddMessage("|cffffffff" .. result.id .. "|r - " .. itemLink);
		elseif result.isResult and result.lookupType == "item" then
			-- Temporary uncached state; redraw() replaces this with itemLink.
			GMGenie_LookupResults_Output:AddMessage("|cffffffff" .. result.plain .. "|r");
		elseif result.isResult and result.id and result.linkType then
			local linkedMessage = "|cffffff00|H" .. result.linkType .. ":" .. result.id
				.. "|h" .. result.plain .. "|h|r";
			GMGenie_LookupResults_Output:AddMessage(linkedMessage);
		else
			GMGenie_LookupResults_Output:AddMessage("|cffffff00" .. result.plain .. "|r");
		end
	end

	if waitingForItem and GMGenie.Lookup.colourRetries < 10 then
		GMGenie.Lookup.colourRetries = GMGenie.Lookup.colourRetries + 1;
		Chronos.scheduleByName("gmgenieLookupItemColours", 0.5, GMGenie.Lookup.redraw);
	end
end

function GMGenie.Lookup.capture(message)
	if not GMGenie.Lookup.active or type(message) ~= "string" then
		return false;
	end

	local plain = string.gsub(message, "|c%x%x%x%x%x%x%x%x", "");
	plain = string.gsub(plain, "|r", "");
	plain = string.gsub(plain, "|H.-|h", "");
	plain = string.gsub(plain, "|h", "");
	local lower = string.lower(plain);
	-- Names can contain hidden WoW hyperlink markers between the dash and the
	-- visible text, so only the stable "numeric ID -" prefix is required.
	local isResult = string.match(plain, "^%s*%d+%s*%-%s*") ~= nil;
	local isEmpty = string.find(lower, "no creatures found", 1, true)
		or string.find(lower, "no items found", 1, true)
		or string.find(lower, "no quests found", 1, true);

	if not isResult and not isEmpty then
		return false;
	end

	-- A system event can be dispatched to more than one chat frame. Suppress
	-- that duplicate without adding the same row to the result window twice.
	local now = GetTime();
	if GMGenie.Lookup.lastMessage == message and GMGenie.Lookup.lastMessageAt
		and now - GMGenie.Lookup.lastMessageAt < 0.1 then
		return true;
	end
	GMGenie.Lookup.lastMessage = message;
	GMGenie.Lookup.lastMessageAt = now;

	local id = string.match(plain, "^%s*(%d+)%s*%-");
	local linkTypes = {
		creature = "creature_entry",
		item = "item",
		quest = "quest",
	};
	local linkType = linkTypes[GMGenie.Lookup.lookupType];
	-- Store results so uncached item qualities can be recoloured as soon as
	-- GetItemInfo receives their data. creature_entry remains the custom link
	-- type used by Spawns.lua for the GM action menu.
	table.insert(GMGenie.Lookup.results, {
		plain = plain,
		id = id,
		linkType = linkType,
		lookupType = GMGenie.Lookup.lookupType,
		isResult = isResult,
	});
	GMGenie.Lookup.redraw();
	GMGenie.Lookup.resultCount = GMGenie.Lookup.resultCount + 1;
	Chronos.scheduleByName("gmgenieLookupTimeout", 2, GMGenie.Lookup.finish);
	return true;
end

--------------------------------------------------
------------ HUD status functionality ------------
--------------------------------------------------
function GMGenie.Hud.checkStatus()
    SendChatMessage(".gm on", "WHISPER", nil, ".");
    SendChatMessage(".gm chat on", "WHISPER", nil, ".");
    SendChatMessage(".gm vis", "WHISPER", nil, ".");
    SendChatMessage(".whispers off", "WHISPER", nil, ".");
	local TheTarget = UnitName("target");
	if UnitName("target") == UnitName("player") or UnitName("target") == nil then 
		SendChatMessage(".mod speed all " .. GMGenie_SavedVars.SavedSpeed, "GUILD");
    else
        GMGenie.showGMMessage("Speed & transparency NOT changed! (Your target is: " .. TheTarget .. ")");
    end
    SendChatMessage(".gm fly on", "WHISPER", nil, ".");
	SendChatMessage(".complaint list", "WHISPER", nil, ".");
	-- The server-side .fishbots command uses a broken printf template (%u)
	-- and returns an "invalid format specifier" error instead of candidates.
	-- Keep the working bot scan; Spy then checks Fishing skill 356 via .lo s.
	SendChatMessage(".bots", "WHISPER", nil, ".");
end

function GMGenie.Hud.gmStatus(status)
    GMGenie.Hud.gm = status;
    GMGenie.Hud.setStatusButton(GMGenie_Hud_GM, "GM mode", status);
end

function GMGenie.Hud.chatStatus(status)
    GMGenie.Hud.chat = status;
    GMGenie.Hud.setStatusButton(GMGenie_Hud_Chat, "Chat badge", status);
end

function GMGenie.Hud.visibilityStatus(status)
    GMGenie.Hud.visibility = status;
    if status then
        GMGenie.Hud.setVisibilityMode("visible");
    else
        GMGenie.Hud.setVisibilityMode("invisible");
    end
end



function GMGenie.Hud.whisperStatus(status)
    GMGenie.Hud.whisper = status;
    GMGenie.Hud.setStatusButton(GMGenie_Hud_Whisper, "Whispers", status);
end

function GMGenie.Hud.flyStatus(status)
    GMGenie.Hud.fly = status;
    GMGenie.Hud.setStatusButton(GMGenie_Hud_Fly, "Flight mode", status);
end

function GMGenie.Hud.readNotice(_, event, notice)
    if event == "UI_ERROR_MESSAGE" then
        if notice == "GM mode is ON" then
            GMGenie.Hud.gmStatus(true);
        elseif notice == "GM mode is OFF" then
            GMGenie.Hud.gmStatus(false);
        elseif notice == "GM Chat Badge is ON" then
            GMGenie.Hud.chatStatus(true);
        elseif notice == "GM Chat Badge is OFF" then
            GMGenie.Hud.chatStatus(false);
			
--        elseif notice == "You are now visible." then
--            GMGenie.Hud.visibilityStatus = 1;

--        elseif notice == "You are now invisible." then
--            GMGenie.Hud.visibilityStatus = 2;
--            GMGenie.Hud.toggleWhisper(GMGenie.Hud.whisper);

--        elseif notice == "You are now visible only to GMs" then
--            GMGenie.Hud.visibilityStatus = 3;
			
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
		if GMGenie.Hud.fly == true then
			GMGenie.Hud.toggleFly(GMGenie.Hud.fly);
		end
		-- ComplaintSystem.lua is loaded after the HUD. Refresh shortly after
		-- entering the world so the HUD count is available without opening it.
		Chronos.scheduleByName("gmgenieComplaintCount", 2, function()
			if getComplaintList then
				getComplaintList();
			end
		end);
    end
end

function GMGenie.Hud.toggleGm(status)
    if (not GMGenie.Hud.gm and status == nil) or status == true then
        SendChatMessage(".gm on", "GUILD");
    else
        SendChatMessage(".gm off", "GUILD");
    end
end

function GMGenie.Hud.toggleChat(status)
    if (not GMGenie.Hud.chat and status == nil) or status == true then
        SendChatMessage(".gm chat on", "GUILD");
    else
        SendChatMessage(".gm chat off", "GUILD");
    end
end

 function GMGenie.Hud.toggleVisibility(status)
--    if (not GMGenie.Hud.visibility and status == nil) or status == true then
--        SendChatMessage(".gm visible on", "GUILD");
--    else
--        SendChatMessage(".gm visible off", "GUILD");
--    end
SendChatMessage(".gm visible off", "GUILD");

end

function GMGenie.Hud.toggleWhisper(status)
    if (not GMGenie.Hud.whisper and status == nil) or status == true then
        SendChatMessage(".whispers on", "GUILD");
    else
        SendChatMessage(".whispers off", "GUILD");
    end
end

function GMGenie.Hud.toggleFly(status)
    if UnitName("target") == UnitName("player") or UnitName("target") == nil then
        if (not GMGenie.Hud.fly and status == nil) or status == true then
            SendChatMessage(".gm fly on", "GUILD");
        else
            SendChatMessage(".gm fly off", "GUILD");
        end
    else
        GMGenie.showGMMessage("Could not target self to change flight mode.");
    end
end

function GMGenie.Hud.setSpeed()
	local TheTarget = UnitName("target");
	if UnitName("target") == UnitName("player") or UnitName("target") == nil then 
		local speed = GMGenie_Hud_Speed:GetText();
		if speed == "" then
			speed = GMGenie_SavedVars.SavedSpeed;
			GMGenie_Hud_Speed:SetText(GMGenie_SavedVars.SavedSpeed);
			GMGenie_Hud_Speed:ClearFocus();
		end
		local n = tonumber(speed);
		if n == nil then
			GMGenie_Hud_Speed:SetText(GMGenie_SavedVars.SavedSpeed);
			GMGenie_Hud_Speed:ClearFocus();
			GMGenie.showGMMessage("Invalid speed specified [range: 0.10 - 50]");
		elseif n < 50.01 and n > 0.09 then
			GMGenie_Hud_Speed:ClearFocus();
			GMGenie_SavedVars.SavedSpeed = n;
			GMGenie_Hud_Speed:SetText(GMGenie_SavedVars.SavedSpeed);
			SendChatMessage(".mod speed all " .. GMGenie_SavedVars.SavedSpeed, "GUILD");
		else
			GMGenie_Hud_Speed:SetText(GMGenie_SavedVars.SavedSpeed);
			GMGenie.showGMMessage("Invalid speed specified [range: 0.10 - 50]");
			GMGenie_Hud_Speed:ClearFocus();
		end
	else
		GMGenie.showGMMessage("Speed NOT changed! (Your target is: " .. TheTarget .. ")");
		GMGenie_Hud_Speed:ClearFocus();
	end
end


function schedule(code, ...)
  local c = coroutine.create(code)
  local t = nil
  local f = CreateFrame("Frame")
  local function update(success, time_or_error)
    if not success then
      return error(time_or_error)
    end
    local s = coroutine.status(c)
    if s == 'dead' then
      return
    end
    t = time_or_error
  end
  f:SetScript("OnUpdate", function(self, elapsed)
    if not t then
      f:SetScript("OnUpdate", nil)
    else
      t = t - elapsed
      if t <= 0 then
        t = nil
        update(coroutine.resume(c))
      end
    end
  end)
  update(coroutine.resume(c))
end


function GMGenie.Hud.loadDropdown(_, level)

-- outdated level exploiter scan
--[[
    local info = UIDropDownMenu_CreateInfo();
    info.hasArrow = false;
    info.notCheckable = true;
    info.text = 'Who: Hotspots for Level Exploiters';
    info.func = GMGenie.Hud.Hotspots;
    UIDropDownMenu_AddButton(info, level);
]]
	
--    local info = UIDropDownMenu_CreateInfo();
--    info.hasArrow = false;
--    info.notCheckable = true;
--    info.text = 'Search: Hyjal Gatherers';
--    info.func = GMGenie.Hud.GathHyjal;
--    UIDropDownMenu_AddButton(info, level);

--    local info = UIDropDownMenu_CreateInfo();
--    info.hasArrow = false;
--    info.notCheckable = true;
--    info.text = 'Search: Uldum Gatherers';
--    info.func = GMGenie.Hud.GathUldum;
--    UIDropDownMenu_AddButton(info, level);

-- Below are outdated level exploiting scans, removing from the dropdown for now	
--[[
    local info = UIDropDownMenu_CreateInfo();
    info.hasArrow = false;
    info.notCheckable = true;
    info.text = 'Who: Northrend Level Exploiters';
    info.func = GMGenie.Hud.Northrend;
    UIDropDownMenu_AddButton(info, level);
	
	local info = UIDropDownMenu_CreateInfo();
    info.hasArrow = false;
    info.notCheckable = true;
    info.text = 'Who: Outland Level Exploiters';
    info.func = GMGenie.Hud.Outland;
    UIDropDownMenu_AddButton(info, level);

	local info = UIDropDownMenu_CreateInfo();
    info.hasArrow = false;
    info.notCheckable = true;
    info.text = 'Who: Eastern Kingdoms Level Exploiters';
    info.func = GMGenie.Hud.Eastern;
    UIDropDownMenu_AddButton(info, level);
	
	local info = UIDropDownMenu_CreateInfo();
    info.hasArrow = false;
    info.notCheckable = true;
    info.text = 'Who: Kalimdor & Misc. Level Exploiters';
    info.func = GMGenie.Hud.Kalimdor;
    UIDropDownMenu_AddButton(info, level);
	]]
	
    local info = UIDropDownMenu_CreateInfo();
    info.hasArrow = false;
    info.notCheckable = true;
    info.text = 'IP: Russian Hosting Mafia (Mass Gold Farm Bots)';
    info.func = GMGenie.Hud.RussianMafiaScan;
    UIDropDownMenu_AddButton(info, level);

	local info = UIDropDownMenu_CreateInfo();
    info.hasArrow = false;
    info.notCheckable = true;
    info.text = 'IP: Strongtechnology.net VPN (Bots)';
    info.func = GMGenie.Hud.StrongTechnologyScan;
    UIDropDownMenu_AddButton(info, level);

	local info = UIDropDownMenu_CreateInfo();
    info.hasArrow = false;
    info.notCheckable = true;
    info.text = 'IP: VPN Account Hacker (Gold theft)';
    info.func = GMGenie.Hud.VPN_Acc_Hacker_Scan;
    UIDropDownMenu_AddButton(info, level);
	
	local info = UIDropDownMenu_CreateInfo();
    info.hasArrow = false;
    info.notCheckable = true;
    info.text = 'IP: Riserank Sp. z o.o. (Bots)';
    info.func = GMGenie.Hud.ZooScan;
    UIDropDownMenu_AddButton(info, level);
	
	local info = UIDropDownMenu_CreateInfo();
    info.hasArrow = false;
    info.notCheckable = true;
    info.text = 'IP: Algeria Telecom (Possible Raid Hacker)';
    info.func = GMGenie.Hud.AlgeriaScan;
    UIDropDownMenu_AddButton(info, level);	
	
	
	local info = UIDropDownMenu_CreateInfo();
    info.hasArrow = false;
    info.notCheckable = true;
    info.text = 'IP: Full Zenlayer (Poss. Bots/Goldsellers, 7 minute scan)';
    info.func = GMGenie.Hud.ZenlayerFullScan;
    UIDropDownMenu_AddButton(info, level);

-- below will add all non-shop mounts to the target, commented out because its use is so rare
--[[	
	local info = UIDropDownMenu_CreateInfo();
    info.hasArrow = false;
    info.notCheckable = true;
    info.text = 'Add all mounts to target';
    info.func = GMGenie.Hud.AddAllMounts;
    UIDropDownMenu_AddButton(info, level);
]]
	
	local info = UIDropDownMenu_CreateInfo();
    info.hasArrow = false;
    info.notCheckable = true;
    info.text = 'Stop All Scans / Searches';
    info.func = GMGenie.Hud.StopScans;
    UIDropDownMenu_AddButton(info, level);
	
end

function GMGenie.Hud.Hotspots()

	schedule(function()
	DEFAULT_CHAT_FRAME:AddMessage("Starting Hotspots for Level Exploiters search, please wait.");
	local count = 0;
	cancel = 0;
	for i, v in ipairs(Level_List_Hotspots) do
		DEFAULT_CHAT_FRAME:AddMessage(v);
		--i is index (1, 2, 3, ...)
		--v is the value
		count = (count + 1);
		SendWho(v);
		coroutine.yield(4.0) -- wait 4 seconds
		if (cancel == 1) then
			break
		end
	end
	DEFAULT_CHAT_FRAME:AddMessage("Hotspots for Level Exploiters search complete.");
	end)
	
end

-- below does not work, we need to use a library to do this the way I want

--function GMGenie.Hud.GathHyjal()
--	DEFAULT_CHAT_FRAME:AddMessage("Mount Hyjal gatherer search underway, please wait.");
--	GMGenie.Hud.waitingForHyjalGath = true;
-- SendWho("z-\"Mount Hyjal\"");
--	SendWho("Herberty");
--end


	
--function GMGenie.Hud.GathUldum()

--	GMGenie.Hud.waitingForUldumGath = true;
--	DEFAULT_CHAT_FRAME:AddMessage("Uldum gatherer search underway, please wait.");
--	SendWho("Uldum");

--	schedule(function()
--	DEFAULT_CHAT_FRAME:AddMessage("Starting Hotspots for Level Exploiters search, please wait.");
--	local count = 0;
--	cancel = 0;
--	for i, v in ipairs(Level_List_Hotspots) do
--		DEFAULT_CHAT_FRAME:AddMessage(v);
--		--i is index (1, 2, 3, ...)
--		--v is the value
--		count = (count + 1);
--		SendWho(v);
--		coroutine.yield(4.0) -- wait 4 seconds
--		if (cancel == 1) then
--			break
--		end
--	end
--	DEFAULT_CHAT_FRAME:AddMessage("Hotspots for Level Exploiters search complete.");
--	end)
	
--end



function GMGenie.Hud.StopScans()
	DEFAULT_CHAT_FRAME:AddMessage("Stopping all in-progress scans, please wait.");
	cancel = 1;
end


function GMGenie.Hud.Northrend()

	schedule(function()
	DEFAULT_CHAT_FRAME:AddMessage("Starting search for Northrend level exploiters, please wait.");
	cancel = 0;
	local count = 0;
	for i, v in ipairs(Level_List_Northrend) do
		DEFAULT_CHAT_FRAME:AddMessage(v);
		--i is index (1, 2, 3, ...)
		--v is the value
		count = (count + 1);
		SendWho(v);
		coroutine.yield(4.0) -- wait 4 seconds
		if (cancel == 1) then
			break
		end
	end
	DEFAULT_CHAT_FRAME:AddMessage("Northrend search complete.");
	end)
	
end

function GMGenie.Hud.Outland()
	schedule(function()
	DEFAULT_CHAT_FRAME:AddMessage("Starting search for Outland level exploiters, please wait.");
	local count = 0;
	cancel = 0;
	for i, v in ipairs(Level_List_Outland) do
		DEFAULT_CHAT_FRAME:AddMessage(v);
		--i is index (1, 2, 3, ...)
		--v is the value
		count = (count + 1);
		SendWho(v);
		coroutine.yield(4.0) -- wait 4 seconds
		if (cancel == 1) then
			break
		end
	end
	DEFAULT_CHAT_FRAME:AddMessage("Outland search complete.");
	end)
	
end


function GMGenie.Hud.Eastern()

	schedule(function()
	DEFAULT_CHAT_FRAME:AddMessage("Starting search for Eastern Kingdoms level exploiters, please wait.");
	local count = 0;
	cancel = 0;
	for i, v in ipairs(Level_List_Eastern) do
		DEFAULT_CHAT_FRAME:AddMessage(v);
		--i is index (1, 2, 3, ...)
		--v is the value
		count = (count + 1);
		SendWho(v);
		coroutine.yield(4.0) -- wait 4 seconds
		if (cancel == 1) then
			break
		end
	end
	DEFAULT_CHAT_FRAME:AddMessage("Eastern Kingdoms search complete.");
	end)
	
end

function GMGenie.Hud.Kalimdor()

	schedule(function()
	DEFAULT_CHAT_FRAME:AddMessage("Starting search for Kalimdor & misc level exploiters, please wait.");
	local count = 0;
	cancel = 0;
	for i, v in ipairs(Level_List_Kalimdor) do
		DEFAULT_CHAT_FRAME:AddMessage(v);
		--i is index (1, 2, 3, ...)
		--v is the value
		count = (count + 1);
		SendWho(v);
		coroutine.yield(4.0) -- wait 4 seconds
		if (cancel == 1) then
			break
		end
	end
	DEFAULT_CHAT_FRAME:AddMessage("Kalimdor & Misc. search complete.");
	end)
	
end

function GMGenie.Hud.RussianMafiaScan()

	local thingsToHide = {
		"No matches found.",
	}

	ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(frame, event, message, sender, ...)
		for i, v in ipairs(thingsToHide) do
			if message:find(v) then
				return true -- hide this message
			end
		end
	end)
	
	schedule(function()
	DEFAULT_CHAT_FRAME:AddMessage("Starting IP address search for Russian Hosting Mafia, please wait.");
	local count = 0;
	cancel = 0;
	for i, v in ipairs(RHM_List) do
		--i is index (1, 2, 3, ...)
		--v is the value
		count = (count + 1);
		if (count == 20) then 
			DEFAULT_CHAT_FRAME:AddMessage(i .." netblocks scanned ");
			count = 0;	
		end
		SendChatMessage(".lo p ips "..v, "GUILD");
		coroutine.yield(0.3) -- wait 300 ms
		if (cancel == 1) then
			break
		end
	end
	DEFAULT_CHAT_FRAME:AddMessage("Search complete.");
	end)
	
end

function GMGenie.Hud.StrongTechnologyScan()

	local thingsToHide = {
		"No matches found.",
	}

	ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(frame, event, message, sender, ...)
		for i, v in ipairs(thingsToHide) do
			if message:find(v) then
				return true -- hide this message
			end
		end
	end)
	
	schedule(function()
	DEFAULT_CHAT_FRAME:AddMessage("Starting IP address search for strongtechnology.net VPN, please wait.");
	local count = 0;
	cancel = 0;
	for i, v in ipairs(STRONGTECH_List) do
		--i is index (1, 2, 3, ...)
		--v is the value
		count = (count + 1);
		if (count == 20) then 
			DEFAULT_CHAT_FRAME:AddMessage(i .." netblocks scanned ");
			count = 0;	
		end
		SendChatMessage(".lo p ips "..v, "GUILD");
		coroutine.yield(0.3) -- wait 300 ms
		if (cancel == 1) then
			break
		end
	end
	DEFAULT_CHAT_FRAME:AddMessage("Search complete.");
	end)
	
end

function GMGenie.Hud.AlgeriaScan()

	local thingsToHide = {
		"No matches found.",
	}

	ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(frame, event, message, sender, ...)
		for i, v in ipairs(thingsToHide) do
			if message:find(v) then
				return true -- hide this message
			end
		end
	end)
	
	schedule(function()
	DEFAULT_CHAT_FRAME:AddMessage("Starting IP address search for Algeria Telecom, Please wait.");
	local count = 0;
	cancel = 0;
	local totalseen = 0;
	for i, v in ipairs(TELCOM_ALGERIA_LIST) do
		--i is index (1, 2, 3, ...)
		--v is the value
		count = (count + 1);
		if (count == 20) then 
			DEFAULT_CHAT_FRAME:AddMessage(i .." netblocks scanned ");
			count = 0;	
		end
		SendChatMessage(".lo p ips "..v, "GUILD");
		coroutine.yield(0.3) -- wait 300 ms
		if (cancel == 1) then
			break
		end
		totalseen = i;
	end
	DEFAULT_CHAT_FRAME:AddMessage("Scan complete.");
	end)


end


function GMGenie.Hud.ZooScan()

	local thingsToHide = {
		"No matches found.",
	}

	ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(frame, event, message, sender, ...)
		for i, v in ipairs(thingsToHide) do
			if message:find(v) then
				return true -- hide this message
			end
		end
	end)
	
	schedule(function()
	DEFAULT_CHAT_FRAME:AddMessage("Starting IP address search for Riserank Sp. z o.o., Please wait.");
	local count = 0;
	cancel = 0;
	local totalseen = 0;
	for i, v in ipairs(ZOO_List) do
		--i is index (1, 2, 3, ...)
		--v is the value
		count = (count + 1);
		if (count == 20) then 
			DEFAULT_CHAT_FRAME:AddMessage(i .." netblocks scanned ");
			count = 0;	
		end
		SendChatMessage(".lo p ips "..v, "GUILD");
		coroutine.yield(0.3) -- wait 300 ms
		if (cancel == 1) then
			break
		end
		totalseen = i;
	end
	DEFAULT_CHAT_FRAME:AddMessage("Scan complete.");
	end)


end


function GMGenie.Hud.VPN_Acc_Hacker_Scan()

	local thingsToHide = {
		"No matches found.",
	}

	ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(frame, event, message, sender, ...)
		for i, v in ipairs(thingsToHide) do
			if message:find(v) then
				return true -- hide this message
			end
		end
	end)
	
	schedule(function()
	DEFAULT_CHAT_FRAME:AddMessage("Starting IP address search for VPN Account Hacker, Please wait.");
	DEFAULT_CHAT_FRAME:AddMessage("Proxy exits he used September-November 2022, could change.")
	local count = 0;
	cancel = 0;
	local totalseen = 0;
	for i, v in ipairs(VPNHacker_List) do
		--i is index (1, 2, 3, ...)
		--v is the value
		count = (count + 1);
		if (count == 20) then 
			DEFAULT_CHAT_FRAME:AddMessage(i .." netblocks scanned ");
			count = 0;	
		end
		SendChatMessage(".lo p ips "..v, "GUILD");
		coroutine.yield(0.3) -- wait 300 ms
		if (cancel == 1) then
			break
		end
		totalseen = i;
	end
	DEFAULT_CHAT_FRAME:AddMessage("Scan complete.");
	end)


end




function GMGenie.Hud.ZenlayerFullScan()

	local thingsToHide = {
		"No matches found.",
	}

	ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(frame, event, message, sender, ...)
		for i, v in ipairs(thingsToHide) do
			if message:find(v) then
				return true -- hide this message
			end
		end
	end)
	
	schedule(function()
	DEFAULT_CHAT_FRAME:AddMessage("Starting IP address search for Zenlayer (Full). This takes about 7 minutes. UI reload will interrupt this scan. Please wait.");
	local count = 0;
	cancel = 0;
	for i, v in ipairs(ZENFULL_List) do
		--i is index (1, 2, 3, ...)
		--v is the value
		count = (count + 1);
		if (count == 20) then 
			DEFAULT_CHAT_FRAME:AddMessage(i .." netblocks scanned ");
			count = 0;	
		end
		SendChatMessage(".lo p ips "..v, "GUILD");
		coroutine.yield(0.3) -- wait 300 ms
		if (cancel == 1) then
			break
		end
	end
	DEFAULT_CHAT_FRAME:AddMessage("Scan complete.");
	end)


end



function GMGenie.Hud.AddAllMounts()

	local thingsToHide = {
		"No matches found.",
	}

	ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(frame, event, message, sender, ...)
		for i, v in ipairs(thingsToHide) do
			if message:find(v) then
				return true -- hide this message
			end
		end
	end)
	
	schedule(function()
	DEFAULT_CHAT_FRAME:AddMessage("Adding all non-store mounts to your target (spell ID based). Hope you know what you're doing.");
	local count = 0;
	cancel = 0;
	for i, v in ipairs(Mount_list) do
		--i is index (1, 2, 3, ...)
		--v is the value
		count = (count + 1);
		if (count == 20) then 
			DEFAULT_CHAT_FRAME:AddMessage(i .." mounts added ");
			count = 0;	
		end
		SendChatMessage(".learn "..v, "GUILD");
		coroutine.yield(0.5) -- wait .5 seconds
		if (cancel == 1) then
			break
		end
	end
	DEFAULT_CHAT_FRAME:AddMessage("Mount additem complete, " ..v, "mounts were added.");
	end)
	
end
