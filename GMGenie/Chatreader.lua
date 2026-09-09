--This file is part of Game Master Genie.
--Copyright 2011-2014 Chocochaos

--Game Master Genie is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 3 of the License.
--Game Master Genie is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
--You should have received a copy of the GNU General Public License along with Game Master Genie. If not, see <http://www.gnu.org/licenses/>.

TicketTab = "General";

-- Best-effort player class cache used by clickable names in GM/system messages.
-- System messages themselves often contain only a character name and no GUID,
-- so we learn classes from normal chat GUIDs, visible units, guild roster data
-- and /spy results. Unknown names keep the normal GM Genie cyan colour.
GMGenie.PlayerClassCache = GMGenie.PlayerClassCache or {};

local GMGENIE_CLASS_NAME_TO_TOKEN = {
    ["warrior"] = "WARRIOR",
    ["paladin"] = "PALADIN",
    ["hunter"] = "HUNTER",
    ["rogue"] = "ROGUE",
    ["priest"] = "PRIEST",
    ["deathknight"] = "DEATHKNIGHT",
    ["death knight"] = "DEATHKNIGHT",
    ["shaman"] = "SHAMAN",
    ["mage"] = "MAGE",
    ["warlock"] = "WARLOCK",
    ["monk"] = "MONK",
    ["druid"] = "DRUID",
};

local function GMGenie_NormalizeCharacterName(name)
    if not name or name == "" then return nil; end
    local baseName = string.match(name, "^([^%-]+)") or name;
    return string.lower(baseName);
end

local function GMGenie_NormalizeClassToken(classNameOrToken)
    if not classNameOrToken or classNameOrToken == "" then return nil; end
    local candidate = string.upper(string.gsub(classNameOrToken, "%s+", ""));
    if RAID_CLASS_COLORS and RAID_CLASS_COLORS[candidate] then
        return candidate;
    end
    return GMGENIE_CLASS_NAME_TO_TOKEN[string.lower(classNameOrToken)];
end

function GMGenie_CachePlayerClass(name, classNameOrToken)
    local key = GMGenie_NormalizeCharacterName(name);
    local token = GMGenie_NormalizeClassToken(classNameOrToken);
    if not key or not token then return; end
    GMGenie.PlayerClassCache[key] = token;
    if GMGenie_SavedVars then
        GMGenie_SavedVars.playerClassCache = GMGenie_SavedVars.playerClassCache or {};
        GMGenie_SavedVars.playerClassCache[key] = token;
    end
end

local function GMGenie_FindPlayerClassFromUnits(playerName)
    local wanted = GMGenie_NormalizeCharacterName(playerName);
    if not wanted then return nil; end

    local units = { "player", "target", "focus", "mouseover" };
    for i = 1, 4 do table.insert(units, "party" .. i); end
    for i = 1, 40 do table.insert(units, "raid" .. i); end
    for i = 1, 5 do
        table.insert(units, "arena" .. i);
        table.insert(units, "boss" .. i);
    end

    for _, unit in ipairs(units) do
        if UnitExists(unit) and UnitIsPlayer(unit) then
            local unitName = UnitName(unit);
            if unitName and GMGenie_NormalizeCharacterName(unitName) == wanted then
                local _, classToken = UnitClass(unit);
                if classToken then
                    GMGenie_CachePlayerClass(unitName, classToken);
                    return classToken;
                end
            end
        end
    end
    return nil;
end

local function GMGenie_FindPlayerClassFromGuild(playerName)
    if not GetNumGuildMembers or not GetGuildRosterInfo then return nil; end
    local wanted = GMGenie_NormalizeCharacterName(playerName);
    if not wanted then return nil; end

    local count = GetNumGuildMembers() or 0;
    for i = 1, count do
        local name, _, _, _, _, _, _, _, _, _, classFileName = GetGuildRosterInfo(i);
        if name and GMGenie_NormalizeCharacterName(name) == wanted and classFileName then
            GMGenie_CachePlayerClass(name, classFileName);
            return classFileName;
        end
    end
    return nil;
end

function GMGenie_GetPlayerClassToken(playerName)
    local key = GMGenie_NormalizeCharacterName(playerName);
    if not key then return nil; end

    local cached = GMGenie.PlayerClassCache[key];
    if cached then return cached; end

    local token = GMGenie_FindPlayerClassFromUnits(playerName);
    if token then return token; end

    token = GMGenie_FindPlayerClassFromGuild(playerName);
    if token then return token; end

    return nil;
end

function GMGenie_GetPlayerClassColorHex(playerName)
    local token = GMGenie_GetPlayerClassToken(playerName);
    if not token or not RAID_CLASS_COLORS then return nil; end
    local color = RAID_CLASS_COLORS[token];
    if not color then return nil; end

    if color.colorStr and string.len(color.colorStr) >= 6 then
        return string.sub(color.colorStr, -6);
    end

    local r = math.floor((color.r or 1) * 255 + 0.5);
    local g = math.floor((color.g or 1) * 255 + 0.5);
    local b = math.floor((color.b or 1) * 255 + 0.5);
    return string.format("%02x%02x%02x", r, g, b);
end


-- Unknown classes intentionally keep the cyan fallback.
-- We do not issue automatic /who queries because they alter the player's Who list and can cause unsolicited Who UI spam.

function GMGenie_InitPlayerClassResolver()
    GMGenie.PlayerClassCache = GMGenie.PlayerClassCache or {};
    if GMGenie_SavedVars then
        GMGenie_SavedVars.playerClassCache = GMGenie_SavedVars.playerClassCache or {};
        for name, token in pairs(GMGenie_SavedVars.playerClassCache) do
            local normalizedToken = GMGenie_NormalizeClassToken(token);
            if normalizedToken then
                GMGenie.PlayerClassCache[name] = normalizedToken;
            end
        end
    end
end

-- Convert the player name in server-formatted lines such as
-- [time] [channel] [Player] message into a normal WoW player hyperlink.
-- This keeps the original text/colours while allowing our SetItemRef hook
-- to provide left-click Spy and right-click GM menu behaviour.
local function GMGenie_MakeThirdBracketNameClickable(message)
    if not message or message == "" then
        return message;
    end

    -- Do not touch lines that already contain a player hyperlink.
    if string.find(message, "|Hplayer:", 1, true) then
        return message;
    end

    local prefix, playerName, suffix = string.match(message, "^(.-%[[^%]]+%].-%[[^%]]+%].-)%[([^%]]+)%](.*)$");
    if not playerName then
        return message;
    end

    playerName = string.gsub(playerName, "^%s+", "");
    playerName = string.gsub(playerName, "%s+$", "");

    -- Character names on the server are simple names, not arbitrary bracket text.
    -- Accept letters plus the common apostrophe/hyphen characters and avoid
    -- turning unrelated third-bracket labels into links.
    if playerName == "" or not string.match(playerName, "^[%a%-']+$") then
        return message;
    end

    local classColor = GMGenie_GetPlayerClassColorHex(playerName);
    if classColor then
        return prefix .. "|cff" .. classColor .. "|Hplayer:" .. playerName .. "|h[" .. playerName .. "]|h|r" .. suffix;
    end
    return prefix .. "|Hplayer:" .. playerName .. "|h[" .. playerName .. "]|h" .. suffix;
end

-- Some server-side warnings do not put the character name in brackets.  A
-- common example is: "Bad movement. Player Demonbender moved ...".  Turn the
-- word immediately following "Player" into a normal player hyperlink as well.
-- The visible name stays unbracketed, matching the original server message.
local function GMGenie_GetPlayerKeywordName(message)
    if not message or message == "" or string.find(message, "|Hplayer:", 1, true) then
        return nil;
    end
    local playerName = string.match(message, "Player%s+([A-Z][%a%-']*)");
    return playerName;
end

local function GMGenie_MakePlayerKeywordNameClickable(message)
    if not message or message == "" then
        return message;
    end

    -- Never nest/duplicate an existing player hyperlink.
    if string.find(message, "|Hplayer:", 1, true) then
        return message;
    end

    local prefix, playerName, suffix = string.match(message, "^(.-Player%s+)([A-Z][%a%-']*)(.*)$");
    if not playerName or playerName == "" then
        return message;
    end

    -- Use the same player: hyperlink consumed by the SetItemRef hook in
    -- Spy.lua: left click -> /spy, right click -> classic GM/player menu.
    -- Prefer the normal WoW class colour when the class is already known;
    -- fall back to cyan when the server message gives us only the name.
    local classColor = GMGenie_GetPlayerClassColorHex(playerName) or "00ccff";
    return prefix .. "|cff" .. classColor .. "|Hplayer:" .. playerName .. "|h" .. playerName .. "|h|r" .. suffix;
end

-- 1d2h3m4s to number in seconds
function GMGenie.timeStrToSeconds(timeStr)
    local days = string.match(timeStr, "([0-9]+)d");
    if not days then
        days = 0;
    end
    local hours = string.match(timeStr, "([0-9]+)h");
    if not hours then
        hours = 0;
    end
    local minutes = string.match(timeStr, "([0-9]+)m");
    if not minutes then
        minutes = 0;
    end
    local seconds = string.match(timeStr, "([0-9]+)s");
    if not seconds then
        seconds = 0;
    end
    return (((((tonumber(days) * 24) + tonumber(hours)) * 60) + tonumber(minutes)) * 60) + tonumber(seconds);
end

-- Read from chat
local ORIG_ChatFrame_MessageEventHandler = ChatFrame_MessageEventHandler;
function ChatFrame_MessageEventHandler(self, event, ...)
    local arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16 = ...;

    -- MoP chat events normally carry the author's GUID as arg12.  Learning
    -- the class here lets later GM/system warnings colour that name without
    -- issuing any extra server query.
    if arg2 and arg2 ~= "" and arg12 and arg12 ~= "" and GetPlayerInfoByGUID then
        local _, classToken, _, _, _, guidName = GetPlayerInfoByGUID(arg12);
        if classToken then
            GMGenie_CachePlayerClass(arg2, classToken);
            if guidName and guidName ~= "" then GMGenie_CachePlayerClass(guidName, classToken); end
        end
    end

    local ActionTaken = false;

    -- development code to analize chat messages
    --local excapedarg = string.gsub(arg1, "%|", "%%");
    --GMGenie.showGMMessage("1: " .. excapedarg);

    -- check for system messages of interest

	local noherb, nomine, noskin, notail, nofish, noarch = true, true, true, true, true, true;

		
	local herb, mine, skin, tail, fish, arch = "", "", "", "", "", "";

    if (event == "CHAT_MSG_SYSTEM") then
        -- Archive requests use the same server commands as the live ticket /
        -- complaint viewers.  Give the archive first chance to consume only
        -- replies belonging to its currently requested ID.
        if GMGenie.Archive and GMGenie.Archive.capture and GMGenie.Archive.capture(arg1) then
            return;
        end

		-- Route lookup replies to the dedicated result window instead of chat.
		if GMGenie.Lookup and GMGenie.Lookup.capture and GMGenie.Lookup.capture(arg1) then
			return;
		end
		if GMGenie.Achievements and GMGenie.Achievements.captureStarbornCheck
			and GMGenie.Achievements.captureStarbornCheck(arg1) then
			return;
		end

		if (cmplSys.status.chatreader == 1) then
			local cheaterpos = string.match(arg1, "Cheater position");
			if cheaterpos then
--				GMGenie.showGMMessage("Debug from chatreader: Cheater coordinates seen");
				local cheatcoords2 = string.gsub(arg1,"|cff00ff00Cheater position|r: ","");
				local cheatcoords = string.gsub(cheatcoords2," map","");				
				local cheatzeroes = string.match (arg1, "0.000 0.000 0.000");
				if cheatzeroes then
--					GMGenie.showGMMessage("from Chatreader: Invalid cheater GPS detected: " .. cheatcoords);
					cmplSys.cheatcoords = "";
					ActionTaken = false;
					cmplSys.status.chatreader = 0;
					return;
				else
					GMGenie.showGMMessage("|cff00ff00Cheat report coordinates + map|r: " .. cheatcoords);
					cmplSys.cheatcoords = cheatcoords;
					ActionTaken = false;
					cmplSys.status.chatreader = 0;
					return
				end
			else
				ActionTaken = false;
			end
		end

	
--		if GMGenie.Hud.waitingForHyjalGath then
--			local findwho = string.match(arg1, "Level ");
--			local zeroplayers = string.match(arg1, "^0(.*)players(.*)total");
--			local finishedplayers = string.match(arg1, "(.*)players(.*)total");
--			if zeroplayers then
--				GMGenie.showGMMessage("Mount Hyjal: No characters seen in zone");
--				GMGenie.Hud.waitingForHyjalGath = false
--				ActionTaken = true;
--				return
--			elseif finishedplayers then
--				ActionTaken = true;
--				GMGenie.showGMMessage("Mount Hyjal: Search Complete");
--				GMGenie.Hud.waitingForHyjalGath = false
--				return
--			else
--				if findwho then
--					if (zoneplayer == arg1) then
--					else
--						zoneplayer = arg1;
--						ActionTaken = true;
--						GMGenie.showGMMessage("Mount Hyjal: " .. zoneplayer);
--					end
--				end
--			end			
--		end	
		

--		if GMGenie.Hud.waitingForUldumGath then
--			GMGenie.showGMMessage("Chatreader.lua: Uldum debug");
--			GMGenie.Hud.waitingForUldumGath = false
--			return
--			local skipuldum = string.match(arg1, "0 players total");
--			if skipuldum then
--				GMGenie.showGMMessage("Uldum: No gathering characters found");
--				GMGenie.Hud.waitingForUldumGath = false;
--				ActionTaken = true;
--				return
--			end
--		end	

		if GMGenie.Spy.waitingForPlayerOnline then
			local fakeskill = string.match(arg1, "No skills found");
			if fakeskill then
				GMGenie.Spy.waitingForPlayerOnline = false;
				ActionTaken = true;
				if GMGenie.Spy.FoundOnlineChar then
				else
				    DEFAULT_CHAT_FRAME:AddMessage("  .. No online character on account " .. GMGenie.Spy.currentRequest["account"]);
				end
				return
			end
			local charline = string.match(arg1, "Characters at account");
			local offlinechar = string.match(arg1, "%[Offline%]");
			local onlinechar = string.match(arg1, "%[Online%]")
			if charline then
				ActionTaken = true;
			elseif offlinechar then
				ActionTaken = true;
			elseif onlinechar then
				ActionTaken = false;
				GMGenie.Spy.FoundOnlineChar = true;
			else
				ActionTaken = false;
			end
		end
				
		if GMGenie.Spy.waitingForIpOnline then
			local fakeskill = string.match(arg1, "No skills found");
			if fakeskill then
				 GMGenie.Spy.waitingForIpOnline = false;
				 ActionTaken = true;
				 return
			end
			local charline = string.match(arg1, "Characters at account");
			local offlinechar = string.match(arg1, "%[Offline%]");
			if charline then
				ActionTaken = true;
			elseif offlinechar then
				ActionTaken = true;
			else
				ActionTaken = false;
			end
		end
		
		if GMGenie.Spy.waitingForFPOnline then
			local fakeskill = string.match(arg1, "No skills found");
			if fakeskill then
				 GMGenie.Spy.waitingForFPOnline = false;
				 ActionTaken = true;
				 return
			end
			local fpline = string.match(arg1, "Fingerprint ");
			local fpaccountline = string.match(arg1, "Accounts with fingerprint like ");
			local charline = string.match(arg1, "Characters at account");
			local offlinechar = string.match(arg1, "%[Offline%]");
			if fpline then
				ActionTaken = true;
			elseif fpaccountline then
				ActionTaken = true;
			elseif charline then
				ActionTaken = true;
			elseif offlinechar then
				ActionTaken = true;
			else
				ActionTaken = false;
			end
		end

		if GMGenie.Spy.waitingForAllProffs then
			local skipproffs = string.match(arg1, "Player not found!");
            if skipproffs then
				GMGenie.Spy.waitingForAllProffs = false;
				ActionTaken = true;
				return
			else
				local blackhole = string.match(arg1, "0/0");
				local fish = string.match(arg1, "356 (.*)");
				if blackhole then
					ActionTaken = true;
				end
				if fish then
					if blackhole then
						ActionTaken = true;
					end
					
					GMGenie.Spy.waitingForAllProffs = false;
				end
				if skipproffs then
					GMGenie.Spy.waitingForAllProffs = false;
					return
				end
			end
		end
		
				
		
        if GMGenie.Spy.waitingForProffs then
            if string.find(arg1, "Player not found!") then
				GMGenie.Spy.waitingForProffs = false;
				ActionTaken = true;
				GMGenie.Spy.clearBotProfs();
				cmplSys.pushright = 0;
				return
            else
                if GMGenie.Spy.waitingForProffs then
					local skipproffs = string.match(arg1, "Player not found!");
					local herb = string.match(arg1, "182 (.*)");
                    local mine = string.match(arg1, "186 (.*)");
					local skin = string.match(arg1, "393 (.*)");
					local tail = string.match(arg1, "197 (.*)");
					local fish = string.match(arg1, "356 (.*)");
					local arch = string.match(arg1, "794 (.*)");	
									
					if skipproffs then
						GMGenie.Spy.waitingForProffs = false;
						ActionTaken = true;
						GMGenie.Spy.clearBotProfs();
						cmplSys.pushright = 0;
						return
					end
					
					if herb then
						noherb = false;
						ActionTaken = true;
                        GMGenie.Spy.processPinHerb(herb, arg1);
                    end
                    if mine then
						nomine = false;
						ActionTaken = true;
                        GMGenie.Spy.processPinMine(mine, arg1);
                    end
					if skin then
--						GMGenie.showGMMessage("Debug from chatreader: starting skinning block");
						noskin = false;
						ActionTaken = true;
                        GMGenie.Spy.processPinSkin(skin, arg1);
                    end
                    if tail then
--						GMGenie.showGMMessage("Debug from chatreader: starting tailoring block");
						notail = false;
						ActionTaken = true;
                        GMGenie.Spy.processPinTail(tail, arg1);
                    end
                    if fish then
--						GMGenie.showGMMessage("Debug from chatreader: starting fishing block");
						nofish = false;
						ActionTaken = true;
                        GMGenie.Spy.processPinFish(fish, arg1);
                    end
                    if arch then
--						GMGenie.showGMMessage("Debug from chatreader: starting archaeology block");
						noarch = false;
						ActionTaken = true;
                        GMGenie.Spy.processPinArch(arch, arg1);
                    end					
				end
			end
		else
			noherb = true;
			nomine = true;
			noskin = true;
			notail = true;
			nofish = true;
			noarch = true;
		end
		
				
	
        -- Showing list of open tickets whose creator is online.
        if string.find(arg1, "Showing list of open tickets") then
            Chronos.scheduleByName('ticketreupdate', 0.5, GMGenie.Tickets.update);
            ActionTaken = true;
        end
        -- ticket list or reading ticket
        local ticketId, name, createStr, lastModifiedStr, rest = string.match(arg1, "^%|cffaaffaaTicket%|r:%|cffaaccff%s([0-9]+).%|r%s%|cff00ff00Created%sby%|r:%|cff00ccff%s(.+)%|r%s%|cff00ff00Created%|r:%|cff00ccff%s([a-zA-Z0-9%s]+)%sago%|r%s%|cff00ff00Last%schange%|r:%|cff00ccff%s([a-zA-Z0-9%s]+)%sago%|r%s(.*)$");

        if ticketId and name and createStr and lastModifiedStr then
            ticketId = tonumber(ticketId);
            local createStamp = GMGenie.timeStrToSeconds(createStr);
            local lastModifiedStamp = GMGenie.timeStrToSeconds(lastModifiedStr);
            if GMGenie.Tickets.tempList then
                GMGenie.Tickets.listTicket(ticketId, name, createStr, createStamp, lastModifiedStr, lastModifiedStamp);
            end

            local assignedTo = string.match(rest, "%|cff00ff00Assigned%sto%|r:%|cff00ccff%s([a-zA-Z]+)%|r%s");
            if assignedTo then
                GMGenie.Tickets.setAssigned(ticketId, assignedTo);
            end
            local message = string.match(rest, "%|cff00ff00Ticket%sMessage%|r:%s%[(.-)%]%|r");
            local ticketCorrect = false;
            if message then
                ticketCorrect = GMGenie.Tickets.readTicket(ticketId, message);
            else
                local message = string.match(rest, "%|cff00ff00Ticket%sMessage%|r:%s%[(.*)");
                if message then
                    ticketCorrect = GMGenie.Tickets.readTicket(ticketId, message);
                    if ticketCorrect then
                        GMGenie.Tickets.messageOpen = true;
                    end
                end
            end

            local comment = string.match(rest, "%|cff00ff00GM%sComment%|r:%s%[(.*)%]%|r");
            if comment then
                GMGenie.Tickets.comment(ticketId, comment);
            end

            if ticketCorrect or GMGenie.Tickets.tempList then
                ActionTaken = true;
            end
        elseif GMGenie.Tickets.messageOpen then
            ActionTaken = true;
            local message, rest = string.match(arg1, "(.-)%]%|r(.*)");
            if message then
                GMGenie.Tickets.messageOpen = false;
                GMGenie.Tickets.addLine(message);
            else
                if string.find(arg1, "%]%|r") then
                    rest = string.match(arg1, "%]%|r(.*)");
                    GMGenie.Tickets.messageOpen = false;
                else
                    GMGenie.Tickets.addLine(arg1);
                end
            end

            if rest then
                local comment = string.match(rest, "%|cff00ff00GM%sComment%|r:%s%[(.*)%]%|r");
                if comment and GMGenie.Tickets.currentTicket['ticketId'] then
                    GMGenie.Tickets.comment(GMGenie.Tickets.currentTicket['ticketId'], comment);
                end
            end
        else
            -- Ticket edited
            local name, ticketId = string.match(arg1, "^%|cff00ff00Character%|r%|cffff00ff%s([a-zA-Z]+)%s%|r%|cff00ff00edited%shis/her%sticket:%|r%|cffff00ff%s([0-9]+).%|r$");
            if name and ticketId then
                if GMGenie.Tickets.isOpen() then
                    GMGenie.Tickets.refresh();
                end
                ActionTaken = true;
            end
            -- Ticket abandoned
            local name, ticketId = string.match(arg1, "^%|cff00ff00Character%|r%|cffff00ff%s([a-zA-Z]+)%s%|r%|cff00ff00abandoned%sticket%sentry:%|r%|cffff00ff%s([0-9]+).%|r$");
            if name and ticketId then
                -- The HUD counter must also decrease when the ticket window
                -- is closed, so refresh the server-backed counts here too.
                GMGenie.Tickets.refresh();
                ActionTaken = true;
            end
            -- New Ticket
            local name, ticketId = string.match(arg1, "^%|cff00ff00New%sticket%sfrom%|r%|cffff00ff%s([a-zA-Z]+).%|r%s%|cff00ff00Ticket%sentry:%|r%|cffff00ff%s([0-9]+).%|r$");
            if name and ticketId then
                if GMGenie.Notifications then
                    GMGenie.Notifications.newTicket(ticketId, name);
                end

                -- Keep the HUD counter in sync even when the ticket window is
                -- closed.  The new-ticket broadcast itself does not tell us
                -- whether the creator is still online, so ask the server for
                -- the normal ticket list + online list instead of guessing.
                -- updateView() will then redraw Tickets (online / offline)
                -- with the authoritative counts.
                GMGenie.Tickets.refresh();

                ActionTaken = true;
            end
        end

        -- read coords from chat
        if GMGenie.Spawns.waitingForGps == 1 then
            if string.find(arg1, "^You are outdoors") or string.find(arg1, "^no VMAP available for area info") then
                ActionTaken = true;
            end
            local map = string.match(arg1, "^Map:%s([0-9]+)%s");
            if map then
                GMGenie.Spawns.waitingForGps = 2;
                GMGenie.Spawns.setMap(map);
                ActionTaken = true;
            end
        end
        if GMGenie.Spawns.waitingForGps == 2 then
            local x, y, z, o = string.match(arg1, "^X:%s([0-9%.%-]+)%sY:%s([0-9%.%-]+)%sZ:%s([0-9%.%-]+)%sOrientation:%s([0-9%.%-]+)$");
            if x and y and z and o then
                GMGenie.Spawns.waitingForGps = 3;
                GMGenie.Spawns.move(x, y, z, o);
                ActionTaken = true;
            end
        end
        if GMGenie.Spawns.waitingForGps == 3 then
            if string.find(arg1, "^grid") or string.find(arg1, "^ ZoneX") then
                ActionTaken = true;
            end
            if string.find(arg1, "^GroundZ") then
                GMGenie.Spawns.waitingForGps = 0;
                ActionTaken = true;
            end
        end

        if GMGenie.Spy.waitingForPin or GMGenie.Macros.Discipline.IpBan.waitingForPin then
            if string.find(arg1, "Player not found!") then
--				GMGenie.showGMMessage("Debug from chatreader: bailing because Player not found!");
				GMGenie.Spy.waitingForPin = false;
				GMGenie.Macros.Discipline.IpBan.waitingForPin = false;
            else
                if GMGenie.Spy.waitingForPin then
                    local offline, name1, _, guid = string.match(arg1, "Player  ?(.*) %|cffffffff%|Hplayer:(.*)%|h%[(.*)%]%|h%|r %(guid: (.*)%)");
                    local phase = string.match(arg1, "Phase: (.*)");
                    local account, accountId, gmLevel = string.match(arg1, "Account: (.*) %(ID: (.*)%), GMLevel: (.*)");
					local fingerprint = string.match(arg1, "Fingerprint: (.*)");
                    local login, failedLogins = string.match(arg1, "Last Login: (.*) %(Failed Logins: (.*)%)");
                    local os, latency = string.match(arg1, "OS: (.*) %- Latency: (.*) ms");					
					
					--[[
					local email = string.match(arg1, "Mail: (.*)");
                    if not email then
                        email = string.match(arg1, "Email: (.*)");
                    end
					--]]
					
                    local ip, locked = string.match(arg1, "Last IP: (.*) %(Locked: (.*)%)");
                    local level = string.match(arg1, "Level: ([0-9]+)");
                    local race, class = string.match(arg1, "Race: (.*), (.*)");
                    local alive = string.match(arg1, "Alive %?: (.*)");
                    local money = string.match(arg1, "Money: (.*)");
                    local map, area, zone = string.match(arg1, "Map: (.*), Area: (.*), Zone: (.*)");
                    local guild, guildId = string.match(arg1, "Guild: (.*) %(ID: (.*)%)");
                    local guildRank = string.match(arg1, "Rank: (.*)");
                    local note = string.match(arg1, "Note: (.*)");
                    local officerNote = string.match(arg1, "O. Note: (.*)");
                    local playedTime = string.match(arg1, "Played time: (.*)");

					if offline then
                        GMGenie.Spy.processPin01(offline, name1, guid, arg1);
                        ActionTaken = true;
                    end
                    if phase then
                        GMGenie.Spy.processPin02(phase, arg1);
                        ActionTaken = true;
                    end
                    if account then
                        GMGenie.Spy.processPin03(account, accountId, gmLevel, arg1);
                        ActionTaken = true;
                    end
					if fingerprint then
                        GMGenie.Spy.processPin20(fingerprint, arg1);
                        ActionTaken = true;
                    end
                    if login then
                        GMGenie.Spy.processPin04(login, failedLogins, arg1);
                        ActionTaken = true;
                    end
                    if os then
                        GMGenie.Spy.processPin05(os, latency, arg1);
                        ActionTaken = true;
                    end
					
					--[[
                    if email then
                        GMGenie.Spy.processPin06(email, arg1);
                        ActionTaken = true;
                    end
					--]]
					
                    if ip then
						GMGenie.Spy.processPin07(ip, locked, arg1);
                        ActionTaken = true;
                    end					
			
                    if level then
                        GMGenie.Spy.processPin08(level, arg1);
                        ActionTaken = true;
                    end
                    if race then
                        GMGenie.Spy.processPin09(race, class, arg1);
                        ActionTaken = true;
                    end
                    if alive then
                        GMGenie.Spy.processPin10(alive, arg1);
                        ActionTaken = true;
                    end
                    if money then
                        GMGenie.Spy.processPin11(money, arg1);
                        ActionTaken = true;
                    end
                    if map then
                        GMGenie.Spy.processPin12(map, area, zone, arg1);
                        ActionTaken = true;
                    end
                    if guild then
                        GMGenie.Spy.processPin13(guild, guildId, arg1);
                        ActionTaken = true;
                    end
                    if guildRank then
                        --GMGenie.Spy.processPin14(guildRank, arg1);
						GMGenie.Spy.processPin135(guildRank, arg1);
                        ActionTaken = true;
                    end
                    if note then
                        GMGenie.Spy.processPin15(note, arg1);
                        ActionTaken = true;
                    end
                    if officerNote then
                        GMGenie.Spy.processPin16(officerNote, arg1);
                        ActionTaken = true;
                    end
                    if playedTime then
                        GMGenie.Spy.processPin17(playedTime, arg1);
                        ActionTaken = true;
                    end
                else
                    local ip, locked = string.match(arg1, "Last IP: (.*) %(Locked: (.*)%)")

                    if ip then
                        GMGenie.Macros.Discipline.IpBan.processPin(ip);
                        ActionTaken = true;
                    end
                end
            end
        end
        if GMGenie.Spy.waitingForMail then
            local read, total = string.match(arg1, "Mails: (.*) Read/(.*) Total");
            if read then
                GMGenie.Spy.processPin18(read, total, arg1);
                ActionTaken = true;
            end
        end

        if GMGenie.Spawns.waitingForObject then
            local name, guid, id = string.match(arg1, "%|cffffffff%|Hgameobject:.*%|h%[(.*)%]%|h%|r%sGUID:%s(.*)%sID:%s(.*)");
            if name and guid and id then
                GMGenie.Spawns.deleteObject(name, guid, id);
                ActionTaken = true;
            elseif string.find(arg1, "X:%s.*%sY:%s.*%sZ:%s.*%sMapId:%s.*") or string.find(arg1, "Orientation:%s.*") or string.find(arg1, "Phasemask%s.*") then
                ActionTaken = true;
            elseif string.find(arg1, "SpawnTime:%sFull:.*%sRemain:.*") then
                ActionTaken = true;
                GMGenie.Spawns.waitingForObject = false;
            elseif string.find(arg1, "Nothing found!") then
                GMGenie.Spawns.waitingForObject = false;
            end
        end

        if GMGenie.Spawns.waitingForObjectDelete then
            if string.find(arg1, "Game Object %(GUID: .*%) removed") then
                ActionTaken = true;
                GMGenie.Spawns.waitingForObjectDelete = false;
            end
        end

        local charName = UnitName("player");
        if string.match(arg1, "%|cffffffff%|Hplayer:" .. charName .. "%|h%[" .. charName .. "%]%|h%|r%'s Fly Mode on") then
            GMGenie.Hud.flyStatus(true);
        elseif string.match(arg1, "%|cffffffff%|Hplayer:" .. charName .. "%|h%[" .. charName .. "%]%|h%|r%'s Fly Mode off") then
            GMGenie.Hud.flyStatus(false);
        elseif arg1 == "Accepting Whisper: ON" or arg1 == "Accepting Whisper: on" then
            GMGenie.Hud.whisperStatus(true);
        elseif arg1 == "Accepting Whisper: OFF" or arg1 == "Accepting Whisper: off" then
            GMGenie.Hud.whisperStatus(false);
        elseif arg1 == "You are: visible" then
            GMGenie.Hud.visibilityStatus(true);
        elseif arg1 == "You are: invisible" then
            GMGenie.Hud.visibilityStatus(false);
        end

        local characterName = string.match(arg1, "%|cFFFFBF00%[AntiCheat%]%:%|cFFFFFFFF %[(.*)%] %|cFF00FFFFdetected as possible cheater%.");
        if characterName then
            arg1 = "|cFFFFBF00[AntiCheat]:|r |Hanticheat:" .. characterName .. "|h[" .. characterName .. "]|h detected as possible cheater.";
        end
    end

    -- if nothing was done, just display the message
    if not ActionTaken then
--		GMGenie.showGMMessage("Dumping to chat due to No Action Taken");
        if event == "CHAT_MSG_SYSTEM" then
            -- Colour the clickable player name only when the class is already
            -- known from safe local sources (chat GUID, visible unit, guild,
            -- /spy cache). Unknown names remain the original pale cyan.
            arg1 = GMGenie_MakeThirdBracketNameClickable(arg1);
            arg1 = GMGenie_MakePlayerKeywordNameClickable(arg1);
        end
        ORIG_ChatFrame_MessageEventHandler(self, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16);
    end
end
