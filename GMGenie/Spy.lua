--This file is part of Game Master Genie.
--Copyright 2011-2014 Chocochaos

--Game Master Genie is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 3 of the License.
--Game Master Genie is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
--You should have received a copy of the GNU General Public License along with Game Master Genie. If not, see <http://www.gnu.org/licenses/>.

GMGenie.Spy = {};
GMGenie.Spy.waitingForPin = false;
GMGenie.Spy.pinCache = "";
WindowSize = 340;

function GMGenie.Spy.antiCheat(name)
    GMGenie.Spy.spy(name);
    GMGenie.Spy.antiCheatPlayer();
    GMGenie.Hud.toggleVisibility(false);
    GMGenie.Spy.appear();
end

function GMGenie.Spy.spy(name)
    if not name or string.len(name) < 1 or name == "%t" then
        name = UnitName("target");
    end
    if name and string.len(name) > 1 then
        GMGenie.Spy.waitingForPin = true;
		GMGenie.Spy.currentRequest = { offline = "", account = "", accountId = "", class = "", fingerprint = "", gmLevel = "", guid = "", guild = "", guild2 = "", ip = "", latency = "", level = "", location = "", login = "", money = "", name = "", phase = "", playedTime = "", race = "" , alive = "", pinherb = "", pinmine = "", pinskin = "", pintail = "", pinfish = "", pinarch = ""};
        GMGenie.Spy.clearCache();
        GMGenie.Spy.resetBoxes();
        GMGenie.Spy.currentRequest["name"] = name;
        GMGenie.Spy.clearCache();
		SendChatMessage(".pin " .. name, "GUILD");

    else
        GMGenie.showGMMessage("Please enter a name or make sure you have someone targeted.");
    end
end

function GMGenie.Spy.clearCache()
    GMGenie.Spy.pinCache = "";
end

function GMGenie.Spy.addToCache(pin)
    GMGenie.Spy.pinCache = GMGenie.Spy.pinCache .. pin .. "\n";
end

function GMGenie.Spy.processPin01(offline, name1, guid, pin)
    GMGenie.Spy.currentRequest["name"] = name1;
    GMGenie.Spy.currentRequest["offline"] = offline;
    GMGenie.Spy.currentRequest["guid"] = guid;
    GMGenie.Spy.addToCache(pin);
end

function GMGenie.Spy.processPin02(phase, pin)
    if GMGenie.Spy.currentRequest["phase"] == phase then return end
    GMGenie.Spy.currentRequest["phase"] = phase;

    GMGenie.Spy.addToCache(pin);
end

function GMGenie.Spy.processPin03(account, accountId, gmLevel, pin)
    if GMGenie.Spy.currentRequest["account"] == account then return end
    GMGenie.Spy.currentRequest["account"] = account;
    GMGenie.Spy.currentRequest["accountId"] = accountId;
    GMGenie.Spy.currentRequest["gmLevel"] = gmLevel;

    GMGenie.Spy.addToCache(pin);
end

function GMGenie.Spy.processPin20(fingerprint, pin)
    if GMGenie.Spy.currentRequest["fingerprint"] == fingerprint then return end
    GMGenie.Spy.currentRequest["fingerprint"] = fingerprint;

    GMGenie.Spy.addToCache(pin);
end

function GMGenie.Spy.processPin04(login, failedLogins, pin)
    GMGenie.Spy.currentRequest["login"] = login;
    -- todo failedLogins

    GMGenie.Spy.addToCache(pin);
end

function GMGenie.Spy.processPin05(os, latency, pin)
    if GMGenie.Spy.currentRequest["latency"] == latency then return end
    -- todo os
    GMGenie.Spy.currentRequest["latency"] = latency;

    GMGenie.Spy.addToCache(pin);
end

--[[
function GMGenie.Spy.processPin06(email, pin)
    GMGenie.Spy.currentRequest["email"] = email;

    GMGenie.Spy.addToCache(pin);
end
--]]

function GMGenie.Spy.processPin07(ip, locked, pin)
    if GMGenie.Spy.currentRequest["ip"] == ip then return end
    GMGenie.Spy.currentRequest["ip"] = ip;
    GMGenie.Spy.addToCache(pin);
	if GMGenie.Spy.currentRequest["ip"] == "Unauthorized" then 
		DEFAULT_CHAT_FRAME:AddMessage ("Debug");
		return
	end
    GMGenie.Spy.LookupIP(ip);
end

function GMGenie.Spy.LookupIP(ip)
	
	local ipfound = 0;
	for i, v in ipairs(RHM_List) do
		--i is index (1, 2, 3, ...)
		--v is the value
		if string.match(ip, v) then
			DEFAULT_CHAT_FRAME:AddMessage ("[Abuse] IP address may be Russian Hosting Mafia, check this network: " .. v);
			ipfound = 1;
			do return end
		end
	end	
	for i, v in ipairs(STRONGTECH_List) do
		--i is index (1, 2, 3, ...)
		--v is the value
		if string.match(ip, v) then
			DEFAULT_CHAT_FRAME:AddMessage ("[Abuse] IP address may be Strongtechnology.net VPN, check this network: " .. v);
			ipfound = 1;
			do return end
		end
	end		
	if ipfound == 0 then
		for i, v in ipairs(ZOO_List) do
			--i is index (1, 2, 3, ...)
			--v is the value
			if string.match(ip, v) then
				DEFAULT_CHAT_FRAME:AddMessage ("[Abuse] ip address may be Riserank Sp. z o.o., check this network: " .. v);
				ipfound = 1;
				do return end
			end
		end
	end
	if ipfound == 0 then
		for i, v in ipairs(ZENFULL_List) do
			--i is index (1, 2, 3, ...)
			--v is the value
			if string.match(ip, v) then
				DEFAULT_CHAT_FRAME:AddMessage ("[Abuse] Ip address may be Zenlayer hosting, check this network: " .. v);
				ipfound = 1;
				do return end
			end
		end
	end
	if ipfound == 0 then
		for i, v in ipairs(TELCOM_ALGERIA_LIST) do
			--i is index (1, 2, 3, ...)
			--v is the value
			if string.match(ip, v) then
				DEFAULT_CHAT_FRAME:AddMessage ("[Abuse] Ip address may be Algeria Telecom, check this network: " .. v);
				ipfound = 1;
				do return end
			end
		end
	end
end

function GMGenie.Spy.processPin08(level, pin)
    if GMGenie.Spy.currentRequest["level"] == level then return end
    GMGenie.Spy.currentRequest["level"] = level;

    GMGenie.Spy.addToCache(pin);
end

function GMGenie.Spy.processPin09(race, class, pin)
    if GMGenie.Spy.currentRequest["race"] == race then return end
    GMGenie.Spy.currentRequest["race"] = race;
    GMGenie.Spy.currentRequest["class"] = class;

    if GMGenie_CachePlayerClass and GMGenie.Spy.currentRequest["name"] and GMGenie.Spy.currentRequest["name"] ~= "" then
        GMGenie_CachePlayerClass(GMGenie.Spy.currentRequest["name"], class);
    end

    GMGenie.Spy.addToCache(pin);
end

function GMGenie.Spy.processPin10(alive, pin)
    if GMGenie.Spy.currentRequest["alive"] == alive then return end
    GMGenie.Spy.currentRequest["alive"] = alive;

    GMGenie.Spy.addToCache(pin);
end

function GMGenie.Spy.processPin11(money, pin)
    if GMGenie.Spy.currentRequest["money"] == money then return end
    GMGenie.Spy.currentRequest["money"] = money;
    GMGenie.Spy.addToCache(pin);
end

function GMGenie.Spy.processPin12(map, area, zone, pin)
    GMGenie.Spy.currentRequest["location"] = map;
    if map ~= area then
        GMGenie.Spy.currentRequest["location"] = area .. ', ' .. GMGenie.Spy.currentRequest["location"];
    end
    if string.upper(zone) ~= '<UNKNOWN>' then
        GMGenie.Spy.currentRequest["location"] = zone .. ', ' .. GMGenie.Spy.currentRequest["location"];
    end;
    GMGenie.Spy.addToCache(pin);
end

function GMGenie.Spy.processPin13(guild, guildId, pin)
    local formattedGuild = '<' .. guild .. '> (' .. guildId .. ')';
    if GMGenie.Spy.currentRequest["guild"] == formattedGuild then return end
    GMGenie.Spy.currentRequest["guild"] = formattedGuild;

    GMGenie.Spy.addToCache(pin);
end

function GMGenie.Spy.processPin135(guildRank, pin)
    local formattedRank = '"' .. guildRank .. '" of';
    if GMGenie.Spy.currentRequest["guild2"] == formattedRank then return end
	GMGenie.Spy.currentRequest["guild2"] = formattedRank;

    GMGenie.Spy.addToCache(pin);
	
end

--[[
function GMGenie.Spy.processPin14(guildRank, pin)
	GMGenie.Spy.currentRequest["guild"] = '"' .. guildRank .. '" of ' .. GMGenie.Spy.currentRequest["guild"];

    GMGenie.Spy.addToCache(pin);
	
end
]]--

function GMGenie.Spy.processPin15(note, pin)
	-- todo Note
	
    GMGenie.Spy.addToCache(pin);
end

function GMGenie.Spy.processPin16(officerNote, pin)
    if GMGenie.Spy.currentRequest["officerNote"] == officerNote then return end
    -- todo officerNote
    GMGenie.Spy.addToCache(pin);
end

function GMGenie.Spy.processPin17(playedTime, pin)
    if GMGenie.Spy.currentRequest["playedTime"] == playedTime then return end
    GMGenie.Spy.currentRequest["playedTime"] = playedTime;
    GMGenie.Spy.addToCache(pin);
    GMGenie.Spy.waitingForPin = false;
	GMGenie.Spy.waitingForMail = true;
    Chronos.scheduleByName('mailinpinprotection', 2, GMGenie.Spy.abortWaitingForMail);
	if GMGenie.Spy.waitingForProffs then
	else
		GMGenie.Spy.Profscan()
	end
    GMGenie.Spy.resetBoxes();
	GMGenie_Spy_InfoWindow:Show();
end

function GMGenie.Spy.Profscan()

		GMGenie.Spy.waitingForProffs = true;
		SendChatMessage(".lo s herb " .. GMGenie.Spy.currentRequest["name"], "GUILD");

end	


function GMGenie.Spy.processPinHerb(herb, arg1)
    if string.match(GMGenie.Spy.currentRequest["pinherb"], 'Herbalism') then
		return end
    if GMGenie.Spy.currentRequest["pinherb"] == herb then 	return end
		herb = herb:gsub(" %[known%] ", "");
		herb = herb:gsub("-", "");
		herb = herb:gsub(" %]", "]");
		herb = herb:gsub("%(", "");
		herb = herb:gsub("%)", "");
		herb = herb:gsub(" %+perm 0", "");
		herb = herb:gsub(" %+temp 0", "");
		GMGenie.Spy.currentRequest["pinherb"] = herb;
		SendChatMessage(".lo s mining " .. GMGenie.Spy.currentRequest["name"], "GUILD");
--		GMGenie.Spy.resetBoxes();
--		GMGenie_Spy_InfoWindow:Show();
	end
function GMGenie.Spy.processPinMine(mine, arg1)
    if string.match(GMGenie.Spy.currentRequest["pinmine"], 'Mining') then
		return end
    if GMGenie.Spy.currentRequest["pinmine"] == mine then 	return end
		mine = mine:gsub(" %[known%] ", "");
		mine = mine:gsub("-", "");
		mine = mine:gsub(" %]", "]");
		mine = mine:gsub("%(", "");
		mine = mine:gsub("%)", "");
		mine = mine:gsub(" %+perm 0", "");
		mine = mine:gsub(" %+temp 0", "");
		GMGenie.Spy.currentRequest["pinmine"] = mine;
		SendChatMessage(".lo s skin " .. GMGenie.Spy.currentRequest["name"], "GUILD");
--		GMGenie.Spy.resetBoxes();
--		GMGenie_Spy_InfoWindow:Show();
	end
function GMGenie.Spy.processPinSkin(skin, arg1)
    if string.match(GMGenie.Spy.currentRequest["pinskin"], 'Skinning') then
		return end
    if GMGenie.Spy.currentRequest["pinskin"] == skin then return end
		skin = skin:gsub(" %[known%] ", "");
		skin = skin:gsub("-", "");
		skin = skin:gsub(" %]", "]");
		skin = skin:gsub("%(", "");
		skin = skin:gsub("%)", "");
		skin = skin:gsub(" %+perm 0", "");
		skin = skin:gsub(" %+temp 0", "");
		GMGenie.Spy.currentRequest["pinskin"] = skin;
		SendChatMessage(".lo s tail " .. GMGenie.Spy.currentRequest["name"], "GUILD");
--		GMGenie.Spy.resetBoxes();
--		GMGenie_Spy_InfoWindow:Show();
	end
function GMGenie.Spy.processPinTail(tail, arg1)
    if string.match(GMGenie.Spy.currentRequest["pintail"], 'Tailoring') then
		return end
    if GMGenie.Spy.currentRequest["pintail"] == tail then return end
		tail = tail:gsub(" %[known%] ", "");
		tail = tail:gsub("-", "");
		tail = tail:gsub(" %]", "]");
		tail = tail:gsub("%(", "");
		tail = tail:gsub("%)", "");
		tail = tail:gsub(" %+perm 0", "");
		tail = tail:gsub(" %+temp 0", "");
		GMGenie.Spy.currentRequest["pintail"] = tail;
		SendChatMessage(".lo s fish " .. GMGenie.Spy.currentRequest["name"], "GUILD");
--		GMGenie.Spy.resetBoxes();
--		GMGenie_Spy_InfoWindow:Show();
	end
function GMGenie.Spy.processPinFish(fish, arg1)
    if string.match(GMGenie.Spy.currentRequest["pinfish"], 'Fishing') then
		return end
		fish = fish:gsub(" %[known%] ", "");
		fish = fish:gsub("-", "");
		fish = fish:gsub(" %]", "]");
		fish = fish:gsub("%(", "");
		fish = fish:gsub("%)", "");
		fish = fish:gsub(" %+perm 0", "");
		fish = fish:gsub(" %+temp 0", "");
		GMGenie.Spy.currentRequest["pinfish"] = fish;
		SendChatMessage(".lo s arch " .. GMGenie.Spy.currentRequest["name"], "GUILD");
--		GMGenie.Spy.resetBoxes();
--		GMGenie_Spy_InfoWindow:Show();
	end
function GMGenie.Spy.processPinArch(arch, arg1)
    if GMGenie.Spy.currentRequest["pinarch"] == arch then return end
		arch = arch:gsub(" %[known%] ", "");
		arch = arch:gsub("-", "");
		arch = arch:gsub(" %]", "]");
		arch = arch:gsub("%(", "");
		arch = arch:gsub("%)", "");
		arch = arch:gsub(" %+perm 0", "");
		arch = arch:gsub(" %+temp 0", "");
		GMGenie.Spy.currentRequest["pinarch"] = arch;
		GMGenie.Spy.waitingForProffs = false;
		GMGenie.Spy.resetBoxes();
		GMGenie_Spy_InfoWindow:Show();
		cmplSys.pushright = 0;
	end

function GMGenie.Spy.processPin18(read, total, pin)
    GMGenie.Spy.addToCache(pin);
    GMGenie.Spy.waitingForMail = false;
    Chronos.unscheduleByName('mailinpinprotection');
--    GMGenie.Spy.resetBoxes();
--    GMGenie_Spy_InfoWindow:Show();
end

function GMGenie.Spy.abortWaitingForMail()
    GMGenie.Spy.waitingForMail = false;
end

function GMGenie.Spy.resetBoxes()
	local base64 = LibStub('LibBase64-1.0');

    GMGenie_Spy_InfoWindow_Info_CharInfo:SetText("Level " .. GMGenie.Spy.currentRequest["level"] .. " " .. GMGenie.Spy.currentRequest["race"] .. " " .. GMGenie.Spy.currentRequest["class"]);
	
	if (GMGenie.Spy.currentRequest["guild"] == "") then
		GMGenie.Spy.currentRequest["guild"] = " ";
	end
	
	GMGenie_Spy_InfoWindow_Info_Guild:SetText(GMGenie.Spy.currentRequest["guild"]);
	
	if (GMGenie.Spy.currentRequest["guild2"] == "") then
		GMGenie.Spy.currentRequest["guild2"] = " ";
	end
	
	GMGenie_Spy_InfoWindow_Info_Guild2:SetText(GMGenie.Spy.currentRequest["guild2"]);
		
	GMGenie_Spy_InfoWindow_Info_Proff1:SetText("");
	GMGenie_Spy_InfoWindow_Info_Proff2:SetText("");
	GMGenie_Spy_InfoWindow_Info_Proff3:SetText("");
	GMGenie_Spy_InfoWindow_Info_Proff4:SetText("");
	GMGenie_Spy_InfoWindow_Info_Proff5:SetText("");
	GMGenie_Spy_InfoWindow_Info_Proff6:SetText("");
local prof1done = 0;
local prof2done = 0;
local prof3done = 0;
local prof4done = 0;
-- this would return nonsense on gm characters that had more than 2 primary skills learned

	if (GMGenie.Spy.currentRequest["pinherb"]) then
		if string.find(GMGenie.Spy.currentRequest["pinherb"], "0/0") then
		else
			GMGenie_Spy_InfoWindow_Info_Proff1:SetText(GMGenie.Spy.currentRequest["pinherb"]);
			prof1done = 1;
		end
	end
	
	if (GMGenie.Spy.currentRequest["pinmine"]) then
		if string.find(GMGenie.Spy.currentRequest["pinmine"], "0/0") then
		else
			if prof1done == 0 then
				GMGenie_Spy_InfoWindow_Info_Proff1:SetText(GMGenie.Spy.currentRequest["pinmine"]);
				prof1done = 1;
			else
				GMGenie_Spy_InfoWindow_Info_Proff2:SetText(GMGenie.Spy.currentRequest["pinmine"]);
				prof2done = 1;
			end
		end
	end
	if (GMGenie.Spy.currentRequest["pinskin"]) then
		if string.find(GMGenie.Spy.currentRequest["pinskin"], "0/0") then
		else
			if prof1done == 0 then
				GMGenie_Spy_InfoWindow_Info_Proff1:SetText(GMGenie.Spy.currentRequest["pinskin"]);
				prof1done = 1;
			else
				GMGenie_Spy_InfoWindow_Info_Proff2:SetText(GMGenie.Spy.currentRequest["pinskin"]);
				prof2done = 1;
			end
		end
	end
	if (GMGenie.Spy.currentRequest["pintail"]) then
		if string.find(GMGenie.Spy.currentRequest["pintail"], "0/0") then
		else
			if prof1done == 0 then
				GMGenie_Spy_InfoWindow_Info_Proff1:SetText(GMGenie.Spy.currentRequest["pintail"]);
				prof1done = 1;
			else
				GMGenie_Spy_InfoWindow_Info_Proff2:SetText(GMGenie.Spy.currentRequest["pintail"]);
				prof2done = 1;
			end
		end
	end
	if (GMGenie.Spy.currentRequest["pinfish"]) then
		if string.find(GMGenie.Spy.currentRequest["pinfish"], "0/0") then
		else
			if prof1done == 0 then
				GMGenie_Spy_InfoWindow_Info_Proff1:SetText(GMGenie.Spy.currentRequest["pinfish"]);
				prof1done = 1;
			elseif prof2done == 0 then
				GMGenie_Spy_InfoWindow_Info_Proff2:SetText(GMGenie.Spy.currentRequest["pinfish"]);
				prof2done = 1;
			else
				GMGenie_Spy_InfoWindow_Info_Proff3:SetText(GMGenie.Spy.currentRequest["pinfish"]);
				prof3done = 1;
			end
		end
	end
	
	if (GMGenie.Spy.currentRequest["pinarch"]) then
		if string.find(GMGenie.Spy.currentRequest["pinarch"], "0/0") then
		else
			if prof1done == 0 then
				GMGenie_Spy_InfoWindow_Info_Proff1:SetText(GMGenie.Spy.currentRequest["pinarch"]);
				prof1done = 1;
			elseif prof2done == 0 then
				GMGenie_Spy_InfoWindow_Info_Proff2:SetText(GMGenie.Spy.currentRequest["pinarch"]);
				prof2done = 1;
			elseif prof3done == 0 then
				GMGenie_Spy_InfoWindow_Info_Proff3:SetText(GMGenie.Spy.currentRequest["pinarch"]);
				prof3done = 1;
			else
				GMGenie_Spy_InfoWindow_Info_Proff4:SetText(GMGenie.Spy.currentRequest["pinarch"]);
				prof4done = 1;
			end
		end
		if prof1done == 0 then
			GMGenie_Spy_InfoWindow_Info_Proff1:SetText("");
			GMGenie_Spy_InfoWindow_Info_Proff2:SetText("");
			GMGenie_Spy_InfoWindow_Info_Proff3:SetText("");
			GMGenie_Spy_InfoWindow_Info_Proff4:SetText("");
			GMGenie_Spy_InfoWindow_Info_Proff5:SetText("- 0  Bot Skills -");
		end

		if prof1done == 1 then
			if prof2done == 0 then
-- if only 1 bot skill is detected, we want to use the centered profession slot (proff5) in /spy window
				GMGenie_Spy_InfoWindow_Info_Proff1:SetText("");
				if string.find(GMGenie.Spy.currentRequest["pinherb"], "0/0") then
				else
					GMGenie_Spy_InfoWindow_Info_Proff5:SetText(GMGenie.Spy.currentRequest["pinherb"]);
				end
				if string.find(GMGenie.Spy.currentRequest["pinmine"], "0/0") then
				else
					GMGenie_Spy_InfoWindow_Info_Proff5:SetText(GMGenie.Spy.currentRequest["pinmine"]);
				end
				if string.find(GMGenie.Spy.currentRequest["pinskin"], "0/0") then
				else
					GMGenie_Spy_InfoWindow_Info_Proff5:SetText(GMGenie.Spy.currentRequest["pinskin"]);
				end
				if string.find(GMGenie.Spy.currentRequest["pintail"], "0/0") then
				else
					GMGenie_Spy_InfoWindow_Info_Proff5:SetText(GMGenie.Spy.currentRequest["pintail"]);
				end
				if string.find(GMGenie.Spy.currentRequest["pinfish"], "0/0") then
				else
					GMGenie_Spy_InfoWindow_Info_Proff5:SetText(GMGenie.Spy.currentRequest["pinfish"]);
				end
				if string.find(GMGenie.Spy.currentRequest["pinarch"], "0/0") then
				else
					GMGenie_Spy_InfoWindow_Info_Proff5:SetText(GMGenie.Spy.currentRequest["pinarch"]);
				end
			end	
		end
		
		if prof1done == 1 then
			if prof2done == 1 then
				if prof3done == 1 then
					if prof4done == 0 then

-- if 3 bots skills are detected, we want to use the centered profession slot (proff6) for skill #3
						GMGenie_Spy_InfoWindow_Info_Proff3:SetText("");
						if string.find(GMGenie.Spy.currentRequest["pinskin"], "0/0") then
						else
							GMGenie_Spy_InfoWindow_Info_Proff6:SetText(GMGenie.Spy.currentRequest["pinskin"]);
						end
						if string.find(GMGenie.Spy.currentRequest["pintail"], "0/0") then
						else
							GMGenie_Spy_InfoWindow_Info_Proff6:SetText(GMGenie.Spy.currentRequest["pintail"]);
						end
						if string.find(GMGenie.Spy.currentRequest["pinfish"], "0/0") then
						else
							GMGenie_Spy_InfoWindow_Info_Proff6:SetText(GMGenie.Spy.currentRequest["pinfish"]);
						end
						if string.find(GMGenie.Spy.currentRequest["pinarch"], "0/0") then
						else
							GMGenie_Spy_InfoWindow_Info_Proff6:SetText(GMGenie.Spy.currentRequest["pinarch"]);
						end
					end
				end
			end	
		end


	end

	GMGenie_Spy_InfoWindow_Title_Text:SetFontObject(GenieFontHighlightSmall);
	GMGenie_Spy_InfoWindow_Title_Text:SetText("               " .. GMGenie.Spy.currentRequest["name"]);
	if (cmplSys.pushright) == 1 then
		GMGenie_Spy_InfoWindow_Title_Text:SetFontObject(GenieFontGreenSmall);
		GMGenie_Spy_InfoWindow_Title_Text:SetText("       " .. GMGenie.Spy.currentRequest["name"] .. " (Reporter)");
	end
	if (cmplSys.pushright) == 2 then
		GMGenie_Spy_InfoWindow_Title_Text:SetFontObject(GenieFontRedSmall);
		GMGenie_Spy_InfoWindow_Title_Text:SetText("               " .. GMGenie.Spy.currentRequest["name"]);
	end
    GMGenie_Spy_InfoWindow_Character_Name:SetText(GMGenie.Spy.currentRequest["name"]);
    GMGenie_Spy_InfoWindow_Character_Id:SetText(GMGenie.Spy.currentRequest["guid"]);
    GMGenie_Spy_InfoWindow_Account_Name:SetText(GMGenie.Spy.currentRequest["account"]);
    GMGenie_Spy_InfoWindow_Account_Id:SetText(GMGenie.Spy.currentRequest["accountId"]);
--	GMGenie.Spy.currentRequest["fingerprint"] = "Unauthorized";
	GMGenie_Spy_InfoWindow_Fingerprint_Fingerprint:SetText(GMGenie.Spy.currentRequest["fingerprint"]);
	if GMGenie.Spy.currentRequest["fingerprint"] == "<none>" then
--	    DEFAULT_CHAT_FRAME:AddMessage("Debug FP is none");
	elseif GMGenie.Spy.currentRequest["fingerprint"] == "Unauthorized" then
--	    DEFAULT_CHAT_FRAME:AddMessage("Debug FP is Unauthorized");
	else
		local decoded = base64:decode(GMGenie.Spy.currentRequest["fingerprint"]);
		GMGenie_Spy_InfoWindow_Decode_Decode:SetPoint("TOPLEFT", "GMGenie_Spy_InfoWindow_Fingerprint_Fingerprint", "BOTTOMLEFT", 0, 0);
		GMGenie_Spy_InfoWindow_Decode_Decode:SetPoint("BOTTOMRIGHT", "GMGenie_Spy_InfoWindow_IpLat_Latency", "TOPRIGHT", 0, 0);
		GMGenie_Spy_InfoWindow_Decode_Decode:SetTextInsets(4,4,4,4);
		GMGenie_Spy_InfoWindow_Decode_Decode:SetMultiLine();
		decoded = decoded:gsub("%|", ", ")
		GMGenie_Spy_InfoWindow_Decode_Decode:SetText(decoded);
	end
    GMGenie_Spy_InfoWindow_IpLat_Ip:SetText(GMGenie.Spy.currentRequest["ip"]);
	if ipfound == 1 then
		GMGenie_Spy_InfoWindow_IpLat_Ip:SetFontObject(GenieFontRedSmall);
	else
		GMGenie_Spy_InfoWindow_IpLat_Ip:SetFontObject(GenieFontHighlightSmall);
	end
	
    if tonumber(GMGenie.Spy.currentRequest["latency"]) and tonumber(GMGenie.Spy.currentRequest["latency"]) > 1000 then
        GMGenie_Spy_InfoWindow_IpLat_Latency:SetFontObject(GenieFontRedSmall);
    else
        GMGenie_Spy_InfoWindow_IpLat_Latency:SetFontObject(GenieFontHighlightSmall);
    end
    GMGenie_Spy_InfoWindow_IpLat_Latency:SetText(GMGenie.Spy.currentRequest["latency"]);
    GMGenie_Spy_InfoWindow_LastLogin_LastLogin:SetText(GMGenie.Spy.currentRequest["login"]);
	if (GMGenie.Spy.currentRequest["alive"]) == "No" then
		GMGenie_Spy_InfoWindow_LastLogin_Alive:SetFontObject(GenieFontRedSmall);
	else
		GMGenie_Spy_InfoWindow_LastLogin_Alive:SetFontObject(GenieFontHighlightSmall);
	end
	GMGenie_Spy_InfoWindow_LastLogin_Alive:SetText(GMGenie.Spy.currentRequest["alive"]);
	if (GMGenie.Spy.currentRequest["offline"]) == "\(offline\)" then
		GMGenie_Spy_InfoWindow_PlayedGM_Online:SetFontObject(GenieFontRedSmall);
		online = "No";
	else
		GMGenie_Spy_InfoWindow_PlayedGM_Online:SetFontObject(GenieFontHighlightSmall);
		online = "Yes";
	end
    GMGenie_Spy_InfoWindow_PlayedGM_PlayedTime:SetText(GMGenie.Spy.currentRequest["playedTime"]);
    GMGenie_Spy_InfoWindow_PlayedGM_GM:SetText(GMGenie.Spy.currentRequest["gmLevel"]);
	GMGenie_Spy_InfoWindow_PlayedGM_Online:SetText(online);
	if cSyncSelectedComplaintOnlineState then
		cSyncSelectedComplaintOnlineState();
	end
    GMGenie_Spy_InfoWindow_MoneyPhase_Money:SetText(GMGenie.Spy.currentRequest["money"]);
    GMGenie_Spy_InfoWindow_MoneyPhase_Phase:SetText(GMGenie.Spy.currentRequest["phase"]);
-- new location window
		GMGenie_Spy_InfoWindow_Location_Location:SetPoint("TOPLEFT", "GMGenie_Spy_InfoWindow_MoneyPhase_Money", "BOTTOMLEFT", 0, 0);
		GMGenie_Spy_InfoWindow_Location_Location:SetPoint("BOTTOMRIGHT", "GMGenie_Spy_InfoWindow_DropdownbuttonsOne", "TOPRIGHT", 0, 0);
		GMGenie_Spy_InfoWindow_Location_Location:SetTextInsets(4,4,4,4);
		GMGenie_Spy_InfoWindow_Location_Location:SetMultiLine();
-- end new location window	
	    GMGenie_Spy_InfoWindow_Location_Location:SetText(GMGenie.Spy.currentRequest["location"]);
		GMGenie_Spy_InfoWindow_Location_Location:SetCursorPosition(0);
end

function GMGenie.Spy.loadDropdown(_, level)
    local info = UIDropDownMenu_CreateInfo();
    info.hasArrow = false;
    info.notCheckable = true;
    info.text = 'Ban Info';
    info.func = GMGenie.Spy.banInfo;
    UIDropDownMenu_AddButton(info, level);
	
	local info = UIDropDownMenu_CreateInfo();
    info.hasArrow = false;
    info.notCheckable = true;
    info.text = 'Mute Info';
    info.func = GMGenie.Spy.muteInfo;
    UIDropDownMenu_AddButton(info, level);

    local info = UIDropDownMenu_CreateInfo();
    info.hasArrow = false;
    info.notCheckable = true;
    info.text = 'Account Info';
    info.func = GMGenie.Spy.lookupPlayer;
    UIDropDownMenu_AddButton(info, level);
	
    local info = UIDropDownMenu_CreateInfo();
    info.hasArrow = false;
    info.notCheckable = true;
    info.text = 'Account (Online)';
    info.func = GMGenie.Spy.lookupPlayerOnline;
    UIDropDownMenu_AddButton(info, level);
	
	local info = UIDropDownMenu_CreateInfo();
    info.hasArrow = false;
    info.notCheckable = true;
    info.text = 'IP Address';
    info.func = GMGenie.Spy.lookupPlayerIp;
    UIDropDownMenu_AddButton(info, level);

	local info = UIDropDownMenu_CreateInfo();
    info.hasArrow = false;
    info.notCheckable = true;
    info.text = 'IP Address (Online)';
    info.func = GMGenie.Spy.lookupPlayerIpOnline;
    UIDropDownMenu_AddButton(info, level);
	
	local info = UIDropDownMenu_CreateInfo();
    info.hasArrow = false;
    info.notCheckable = true;
    info.text = 'IP Network /24 (Online)';
    info.func = GMGenie.Spy.lookupPlayerNetCOnline;
    UIDropDownMenu_AddButton(info, level);
	
	local info = UIDropDownMenu_CreateInfo();
    info.hasArrow = false;
    info.notCheckable = true;
    info.text = 'IP Network /16 (Online)';
    info.func = GMGenie.Spy.lookupPlayerNetBOnline;
    UIDropDownMenu_AddButton(info, level);
	
	local info = UIDropDownMenu_CreateInfo();
    info.hasArrow = false;
    info.notCheckable = true;
    info.text = 'IP Network /8 (Online)';
    info.func = GMGenie.Spy.lookupPlayerNetAOnline;
    UIDropDownMenu_AddButton(info, level);
	
	local info = UIDropDownMenu_CreateInfo();
    info.hasArrow = false;
    info.notCheckable = true;
    info.text = 'Fingerprint';
    info.func = GMGenie.Spy.lookupPlayerFingerprint;
    UIDropDownMenu_AddButton(info, level);
	
	local info = UIDropDownMenu_CreateInfo();
    info.hasArrow = false;
    info.notCheckable = true;
    info.text = 'Fingerprint (Online)';
    info.func = GMGenie.Spy.lookupPlayerFPOnline;
    UIDropDownMenu_AddButton(info, level);

	
	local info = UIDropDownMenu_CreateInfo();
    info.hasArrow = false;
    info.notCheckable = true;
    info.text = 'Fingerprint (RAM truncated 3-4)';
    info.func = GMGenie.Spy.lookupPlayerFingerprint4;
    UIDropDownMenu_AddButton(info, level);
	
	local info = UIDropDownMenu_CreateInfo();
    info.hasArrow = false;
    info.notCheckable = true;
    info.text = 'Fingerprint (RAM truncated 5-6)';
    info.func = GMGenie.Spy.lookupPlayerFingerprint6;
    UIDropDownMenu_AddButton(info, level);

	local info = UIDropDownMenu_CreateInfo();
    info.hasArrow = false;
    info.notCheckable = true;
    info.text = 'Professions';
    info.func = GMGenie.Spy.lookupProfs;
    UIDropDownMenu_AddButton(info, level);
	
end

SLASH_SPY1 = "/spy";
SlashCmdList["SPY"] = GMGenie.Spy.spy;

function GMGenie.Spy.grouplist()
    GMGenie.Macros.grouplist(GMGenie.Spy.currentRequest["name"]);
end

function GMGenie.Spy.copyPin()
    GMGenie.showGMMessage(GMGenie.Spy.pinCache);
end

function GMGenie.Spy.listauras()
	SendChatMessage(".list auras ", "GUILD");
end

function GMGenie.Spy.listids()
	SendChatMessage(".inst listbinds ", "GUILD");
end

function GMGenie.Spy.whisper()
    ChatFrame_SendTell(GMGenie.Spy.currentRequest["name"]);
end

function GMGenie.Spy.summon()
    GMGenie.Macros.summon(GMGenie.Spy.currentRequest["name"]);
end

function GMGenie.Spy.appear()
    GMGenie.Macros.appear(GMGenie.Spy.currentRequest["name"]);
end

function GMGenie.Spy.revive()
    GMGenie.Macros.revive(GMGenie.Spy.currentRequest["name"]);
end

function GMGenie.Spy.freeze()
    GMGenie.Macros.freeze(GMGenie.Spy.currentRequest["name"]);
end

function GMGenie.Spy.unfreeze()
    GMGenie.Macros.unfreeze(GMGenie.Spy.currentRequest["name"]);
end

function GMGenie.Spy.rename()
    GMGenie.Macros.rename(GMGenie.Spy.currentRequest["name"]);
end

function GMGenie.Spy.antiCheatPlayer()
    GMGenie.Macros.antiCheatPlayer(GMGenie.Spy.currentRequest["name"]);
end

function GMGenie.Spy.customize()
    GMGenie.Macros.customize(GMGenie.Spy.currentRequest["name"]);
end

function GMGenie.Spy.changefaction()
    GMGenie.Macros.changefaction(GMGenie.Spy.currentRequest["name"]);
end

function GMGenie.Spy.changerace()
    GMGenie.Macros.changerace(GMGenie.Spy.currentRequest["name"]);
end

function GMGenie.Spy.banInfo()
    CloseDropDownMenus()
	DEFAULT_CHAT_FRAME:AddMessage("Start of account baninfo lookup");
    SendChatMessage(".baninfo account " .. GMGenie.Spy.currentRequest["account"], "GUILD");
    --SendChatMessage(".baninfo character " .. GMGenie.Spy.currentRequest["name"], "GUILD");
    SendChatMessage(".baninfo ip " .. GMGenie.Spy.currentRequest["ip"], "GUILD");
end

function GMGenie.Spy.muteInfo()
    CloseDropDownMenus()
	DEFAULT_CHAT_FRAME:AddMessage("Start of account muteinfo lookup");
    SendChatMessage(".muteinfo account " .. GMGenie.Spy.currentRequest["account"], "GUILD");
end

function GMGenie.Spy.lookupPlayer()
    CloseDropDownMenus()
	DEFAULT_CHAT_FRAME:AddMessage("Start of account lookup");
    SendChatMessage(".lookup player account " .. GMGenie.Spy.currentRequest["account"], "GUILD");
    --SendChatMessage(".lookup player email " .. GMGenie.Spy.currentRequest["email"], "GUILD");
    --SendChatMessage(".lookup player ip " .. GMGenie.Spy.currentRequest["ip"], "GUILD");
end

function GMGenie.Spy.lookupPlayerOnline()
    CloseDropDownMenus()
	DEFAULT_CHAT_FRAME:AddMessage("Checking for online characters on account " .. GMGenie.Spy.currentRequest["account"]);
	GMGenie.Spy.waitingForPlayerOnline = true;
	GMGenie.Spy.FoundOnlineChar = false;
    SendChatMessage(".lookup player account " .. GMGenie.Spy.currentRequest["account"], "GUILD");
	SendChatMessage(".lo s fakeskill", "GUILD");
end

function GMGenie.Spy.lookupPlayerIp()
    CloseDropDownMenus()
	DEFAULT_CHAT_FRAME:AddMessage("Start of ip address lookup for " .. GMGenie.Spy.currentRequest["ip"]);
    SendChatMessage(".lookup player ip " .. GMGenie.Spy.currentRequest["ip"], "GUILD");
end

function GMGenie.Spy.lookupPlayerIpOnline()
    CloseDropDownMenus()
	DEFAULT_CHAT_FRAME:AddMessage("Start of ip address (Online) lookup for " .. GMGenie.Spy.currentRequest["ip"]);
	GMGenie.Spy.waitingForIpOnline = true;
    SendChatMessage(".lookup player ip " .. GMGenie.Spy.currentRequest["ip"], "GUILD");
	SendChatMessage(".lo s fakeskill", "GUILD");
end
function GMGenie.Spy.lookupPlayerNetCOnline()
    CloseDropDownMenus()
	GMGenie.Spy.firstdot = strfind (GMGenie.Spy.currentRequest["ip"], "%.");
	GMGenie.Spy.seconddot = strfind (GMGenie.Spy.currentRequest["ip"], "%.", (GMGenie.Spy.firstdot + 1));
	GMGenie.Spy.thirddot = strfind (GMGenie.Spy.currentRequest["ip"], "%.", (GMGenie.Spy.seconddot + 1));
	GMGenie.Spy.classc = strsub (GMGenie.Spy.currentRequest["ip"],0,(GMGenie.Spy.thirddot));
	DEFAULT_CHAT_FRAME:AddMessage("Start of ip network /24 (Online) lookup for " .. GMGenie.Spy.currentRequest["ip"] .. " (" .. GMGenie.Spy.classc .. "0/24" .. ")");
	GMGenie.Spy.waitingForIpOnline = true;
    SendChatMessage(".lookup player ips " .. GMGenie.Spy.classc, "GUILD");
	SendChatMessage(".lo s fakeskill", "GUILD");
end
function GMGenie.Spy.lookupPlayerNetBOnline()
    CloseDropDownMenus()
	GMGenie.Spy.firstdot = strfind (GMGenie.Spy.currentRequest["ip"], "%.");
	GMGenie.Spy.seconddot = strfind (GMGenie.Spy.currentRequest["ip"], "%.", (GMGenie.Spy.firstdot + 1));
	GMGenie.Spy.classb = strsub (GMGenie.Spy.currentRequest["ip"],0,(GMGenie.Spy.seconddot));
	DEFAULT_CHAT_FRAME:AddMessage("Start of ip network /16 (Online) lookup for " .. GMGenie.Spy.currentRequest["ip"] .. " (" .. GMGenie.Spy.classb .. "0.0/16" .. ")");
	GMGenie.Spy.waitingForIpOnline = true;
    SendChatMessage(".lookup player ips " .. GMGenie.Spy.classb, "GUILD");
	SendChatMessage(".lo s fakeskill", "GUILD");
end
function GMGenie.Spy.lookupPlayerNetAOnline()
    CloseDropDownMenus()
	GMGenie.Spy.firstdot = strfind (GMGenie.Spy.currentRequest["ip"], "%.");
	GMGenie.Spy.classa = strsub (GMGenie.Spy.currentRequest["ip"],0,(GMGenie.Spy.firstdot));
	DEFAULT_CHAT_FRAME:AddMessage("Start of ip network /8 (Online) lookup for " .. GMGenie.Spy.currentRequest["ip"] .. " (" .. GMGenie.Spy.classa .. "0.0.0/8" .. ")");
	GMGenie.Spy.waitingForIpOnline = true;
    SendChatMessage(".lookup player ips " .. GMGenie.Spy.classa, "GUILD");
	SendChatMessage(".lo s fakeskill", "GUILD");
end

function GMGenie.Spy.lookupPlayerFingerprint()
    CloseDropDownMenus()
	DEFAULT_CHAT_FRAME:AddMessage("Start of fingerprint lookup"); 
    SendChatMessage(".lookup player fingerprint " .. GMGenie.Spy.currentRequest["fingerprint"], "GUILD");
end

function GMGenie.Spy.lookupPlayerFPOnline()
    CloseDropDownMenus()
	DEFAULT_CHAT_FRAME:AddMessage("Start of fingerprint (Online) lookup for " .. GMGenie.Spy.currentRequest["fingerprint"]);
	GMGenie.Spy.waitingForFPOnline = true;
    SendChatMessage(".lookup player f " .. GMGenie.Spy.currentRequest["fingerprint"], "GUILD");
	SendChatMessage(".lo s fakeskill", "GUILD");
end

function GMGenie.Spy.lookupPlayerFingerprint4()
	if GMGenie.Spy.currentRequest["fingerprint"] == "<none>" then
--	    DEFAULT_CHAT_FRAME:AddMessage("Debug FP is none");
	elseif GMGenie.Spy.currentRequest["fingerprint"] == "Unauthorized" then
--	    DEFAULT_CHAT_FRAME:AddMessage("Debug FP is Unauthorized");
	else
		local base64 = LibStub('LibBase64-1.0');
		CloseDropDownMenus()
		fplen = strlen (GMGenie.Spy.currentRequest["fingerprint"]);
		fplen = (fplen - 8);
		fpcut = strsub (GMGenie.Spy.currentRequest["fingerprint"], 0, fplen);
		local decoded2 = base64:decode(fpcut);
		decoded2 = decoded2:gsub("%|", ", ")
		DEFAULT_CHAT_FRAME:AddMessage("Start of fingerprint lookup (RAM truncated 3-4 chars): " .. decoded2);
		SendChatMessage(".lookup player fingerprint " .. fpcut, "GUILD");
	end
end


function GMGenie.Spy.lookupPlayerFingerprint6()
	if GMGenie.Spy.currentRequest["fingerprint"] == "<none>" then
--	    DEFAULT_CHAT_FRAME:AddMessage("Debug FP is none");
	elseif GMGenie.Spy.currentRequest["fingerprint"] == "Unauthorized" then
--	    DEFAULT_CHAT_FRAME:AddMessage("Debug FP is Unauthorized");
	else
		local base64 = LibStub('LibBase64-1.0');
		CloseDropDownMenus()
		fplen = strlen (GMGenie.Spy.currentRequest["fingerprint"]);
		fplen = (fplen - 12);
		fpcut = strsub (GMGenie.Spy.currentRequest["fingerprint"], 0, fplen);
		local decoded2 = base64:decode(fpcut);
		decoded2 = decoded2:gsub("%|", ", ")
		DEFAULT_CHAT_FRAME:AddMessage("Start of fingerprint lookup (RAM truncated 5-6 chars): " .. decoded2);
		SendChatMessage(".lookup player fingerprint " .. fpcut, "GUILD");
	end
end


function GMGenie.Spy.lookupProfs()
		if (online == "No") then
			DEFAULT_CHAT_FRAME:AddMessage("Can not query professions on offline players");
			return
		else
			DEFAULT_CHAT_FRAME:AddMessage("All learned professions for " .. GMGenie.Spy.currentRequest["name"] .. ":");
			GMGenie.Spy.waitingForAllProffs = true;
			SendChatMessage(".lo s herb " .. GMGenie.Spy.currentRequest["name"], "GUILD");
			SendChatMessage(".lo s mining " .. GMGenie.Spy.currentRequest["name"], "GUILD");
			SendChatMessage(".lo s skinning " .. GMGenie.Spy.currentRequest["name"], "GUILD");
			SendChatMessage(".lo s tailoring " .. GMGenie.Spy.currentRequest["name"], "GUILD");
			SendChatMessage(".lo s alchemy " .. GMGenie.Spy.currentRequest["name"], "GUILD");
			SendChatMessage(".lo s blacksmithing " .. GMGenie.Spy.currentRequest["name"], "GUILD");
			SendChatMessage(".lo s leatherworking " .. GMGenie.Spy.currentRequest["name"], "GUILD");
			SendChatMessage(".lo s inscription " .. GMGenie.Spy.currentRequest["name"], "GUILD");
			SendChatMessage(".lo s engineering " .. GMGenie.Spy.currentRequest["name"], "GUILD");
			SendChatMessage(".lo s jewelcrafting " .. GMGenie.Spy.currentRequest["name"], "GUILD");
			SendChatMessage(".lo s cooking " .. GMGenie.Spy.currentRequest["name"], "GUILD");
			SendChatMessage(".lo s archaeology " .. GMGenie.Spy.currentRequest["name"], "GUILD");
			SendChatMessage(".lo s first " .. GMGenie.Spy.currentRequest["name"], "GUILD");
			SendChatMessage(".lo s fishing " .. GMGenie.Spy.currentRequest["name"], "GUILD");
		end
end

function GMGenie.Spy.clearBotProfs()
	GMGenie.Spy.currentRequest["pinherb"] = "";
	GMGenie.Spy.currentRequest["pinmine"] = "";
	GMGenie.Spy.currentRequest["pinskin"] = "";
	GMGenie.Spy.currentRequest["pintail"] = "";
	GMGenie.Spy.currentRequest["pinfish"] = "";
	GMGenie.Spy.currentRequest["pinarch"] = "";
	GMGenie_Spy_InfoWindow_Info_Proff1:SetText("");
	GMGenie_Spy_InfoWindow_Info_Proff2:SetText("");
	GMGenie_Spy_InfoWindow_Info_Proff3:SetText("");
	GMGenie_Spy_InfoWindow_Info_Proff4:SetText("");
	GMGenie_Spy_InfoWindow_Info_Proff5:SetText("");
	GMGenie_Spy_InfoWindow_Info_Proff6:SetText("");
end

local Saved_SetItemRef = SetItemRef;
function SetItemRef(link, text, button, chatFrame)
    if (strsub(link, 1, 9) == "anticheat") then
        local _, name = strsplit(":", link);
        if (button == "LeftButton") then
            GMGenie.Spy.antiCheat(name);
        elseif (button == "RightButton") then
            FriendsFrame_ShowDropdown(name, 1);
        end
        return;
    end

    -- GM Genie player links:
    -- left click = /spy <name>
    -- right click = the classic Blizzard/GM player context menu.
    if (strsub(link, 1, 7) == "player:") then
        local name = string.match(link, "^player:([^:]+)");
        if name and name ~= "" then
            if (button == "LeftButton") then
                GMGenie.Spy.spy(name);
            elseif (button == "RightButton") then
                FriendsFrame_ShowDropdown(name, 1);
            else
                Saved_SetItemRef(link, text, button, chatFrame);
            end
            return;
        end
    end

    Saved_SetItemRef(link, text, button, chatFrame);
end
