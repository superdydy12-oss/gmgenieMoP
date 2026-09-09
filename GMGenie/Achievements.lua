-- Manual achievement tools for custom MoP 5.4.8 server commands.

GMGenie.Achievements = {};

GMGenie.Achievements.starbornClasses = {
	{ key = "warrior", name = "Warrior" },
	{ key = "paladin", name = "Paladin" },
	{ key = "hunter", name = "Hunter" },
	{ key = "rogue", name = "Rogue" },
	{ key = "priest", name = "Priest" },
	{ key = "deathknight", name = "Death Knight" },
	{ key = "shaman", name = "Shaman" },
	{ key = "mage", name = "Mage" },
	{ key = "warlock", name = "Warlock" },
	{ key = "monk", name = "Monk" },
	{ key = "druid", name = "Druid" }
};

GMGenie.Achievements.starbornCheck = { active = false };

local STARBORN_TIMEOUT = "gmgenieStarbornConditionsTimeout";

local function normalizeClass(className)
	return string.lower(className or ""):gsub("[^a-z]", "");
end

local function stripServerFormatting(message)
	local text = message or "";
	text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "");
	text = text:gsub("|H.-|h%[(.-)%]|h", "%1");
	return text;
end

local function scheduleCheckTimeout()
	Chronos.unscheduleByName(STARBORN_TIMEOUT);
	Chronos.scheduleByName(STARBORN_TIMEOUT, 5, GMGenie.Achievements.starbornCheckTimeout);
end

local function sendAuditCommand(command)
	SendChatMessage(command, "GUILD");
	SendChatMessage(".lo s fakeskill", "GUILD");
	scheduleCheckTimeout();
end

function GMGenie.Achievements.sendCommand(command)
	-- These custom server commands are handled from normal player chat. Using
	-- GUILD works for Trinity GM commands, but custom hooks may only see SAY.
	SendChatMessage(command, "SAY");
	GMGenie.showGMMessage("Command sent: " .. command);
end

function GMGenie.Achievements.onLoad(frame)
	GMGenie.loadWindow(frame, "Manual achievements", false, nil);
	tinsert(UISpecialFrames, frame:GetName());
end

function GMGenie.Achievements.onStarbornCheckLoad(frame)
	GMGenie.loadWindow(frame, "Starborn conditions", false, nil);
	tinsert(UISpecialFrames, frame:GetName());
	local output = GMGenie_StarbornCheck_Output;
	output:SetFontObject(ChatFontNormal);
	output:SetFading(false);
	output:SetMaxLines(200);
	output:SetScript("OnMouseWheel", function(self, delta)
		if delta > 0 then self:ScrollUp(); else self:ScrollDown(); end
	end);
end

function GMGenie.Achievements.clearStarbornCheck()
	GMGenie_StarbornCheck_Output:Clear();
end

function GMGenie.Achievements.cancelStarbornCheck()
	Chronos.unscheduleByName(STARBORN_TIMEOUT);
	GMGenie.Achievements.starbornCheck = { active = false };
end

function GMGenie.Achievements.addStarbornCheckLine(text)
	GMGenie_StarbornCheck_Output:AddMessage(text);
end

function GMGenie.Achievements.startStarbornCheck()
	local name = UnitName("target");
	if not name or not UnitIsPlayer("target") then
		GMGenie.showGMMessage("Select the player whose Starborn conditions should be checked.");
		return false;
	end

	GMGenie.Achievements.cancelStarbornCheck();
	GMGenie.Achievements.starbornCheck = {
		active = true,
		stage = "target_pin",
		targetName = name,
		account = nil,
		characters = {},
		characterSet = {},
		results = {},
		index = 0,
		currentName = nil,
		currentLevel = nil,
		currentClass = nil,
		currentMissing = false
	};

	GMGenie_StarbornCheck:Show();
	GMGenie.Achievements.clearStarbornCheck();
	GMGenie.Achievements.addStarbornCheckLine("|cff37dff5Checking account for " .. name .. "...|r");
	GMGenie.Achievements.addStarbornCheckLine("Reading target account...");
	sendAuditCommand(".pin " .. name);
	return true;
end

function GMGenie.Achievements.addAccountCharacter(name)
	local check = GMGenie.Achievements.starbornCheck;
	if not name or name == "" then return false end
	name = name:gsub("^%s+", ""):gsub("%s+$", "");
	if not string.match(name, "^[%a%-']+$") then return false end
	local key = string.lower(name);
	if check.characterSet[key] then return false end
	check.characterSet[key] = true;
	table.insert(check.characters, name);
	return true;
end

function GMGenie.Achievements.readAccountCharacter(message)
	local hyperlinkName = string.match(message or "", "|Hplayer:([^:|]+)");
	if hyperlinkName then
		return GMGenie.Achievements.addAccountCharacter(hyperlinkName);
	end

	local text = stripServerFormatting(message);
	-- This server lists account characters as:
	-- Name (GUID: 12345, Level: 90) - [Offline]
	local name = string.match(text, "^%s*([%a%-']+)%s+%(GUID:%s*%d+,%s*Level:%s*%d+%)%s*%-%s*%[[Oo]nline%]")
		or string.match(text, "^%s*([%a%-']+)%s+%(GUID:%s*%d+,%s*Level:%s*%d+%)%s*%-%s*%[[Oo]ffline%]")
		or string.match(text, "%[[Oo]nline%]%s*([%a%-']+)")
		or string.match(text, "%[[Oo]ffline%]%s*([%a%-']+)")
		or string.match(text, "^%s*([%a%-']+)%s+%[[Oo]nline%]")
		or string.match(text, "^%s*([%a%-']+)%s+%[[Oo]ffline%]");
	if name then return GMGenie.Achievements.addAccountCharacter(name); end
	return false;
end

function GMGenie.Achievements.beginAccountList()
	local check = GMGenie.Achievements.starbornCheck;
	if not check.account or check.account == "" then
		GMGenie.Achievements.failStarbornCheck("The server did not return the target account name.");
		return;
	end
	check.stage = "account_list";
	GMGenie.Achievements.addStarbornCheckLine("Reading characters on account " .. check.account .. "...");
	sendAuditCommand(".lookup player account " .. check.account);
end

function GMGenie.Achievements.beginNextCharacter()
	local check = GMGenie.Achievements.starbornCheck;
	check.index = check.index + 1;
	if check.index > #check.characters then
		GMGenie.Achievements.finishStarbornCheck();
		return;
	end

	check.stage = "character_pin";
	check.currentName = check.characters[check.index];
	check.currentLevel = nil;
	check.currentClass = nil;
	check.currentMissing = false;
	GMGenie_StarbornCheck_Title_Text:SetText("Starborn conditions (" .. check.index .. "/" .. #check.characters .. ")");
	sendAuditCommand(".pin " .. check.currentName);
end

function GMGenie.Achievements.storeCurrentCharacter()
	local check = GMGenie.Achievements.starbornCheck;
	if check.currentName then
		table.insert(check.results, {
			name = check.currentName,
			level = tonumber(check.currentLevel),
			class = check.currentClass,
			missing = check.currentMissing
		});
	end
end

function GMGenie.Achievements.completeStarbornStage()
	local check = GMGenie.Achievements.starbornCheck;
	if not check.active then return end
	Chronos.unscheduleByName(STARBORN_TIMEOUT);
	if check.stage == "target_pin" then
		GMGenie.Achievements.beginAccountList();
	elseif check.stage == "account_list" then
		if #check.characters == 0 then
			GMGenie.Achievements.failStarbornCheck("No characters could be read from the account lookup.");
		else
			GMGenie.Achievements.addStarbornCheckLine("Checking " .. #check.characters .. " characters...");
			check.index = 0;
			GMGenie.Achievements.beginNextCharacter();
		end
	elseif check.stage == "character_pin" then
		GMGenie.Achievements.storeCurrentCharacter();
		GMGenie.Achievements.beginNextCharacter();
	end
end

function GMGenie.Achievements.starbornCheckTimeout()
	local check = GMGenie.Achievements.starbornCheck;
	if not check.active then return end
	if check.stage == "character_pin" then
		check.currentMissing = true;
		GMGenie.Achievements.storeCurrentCharacter();
		GMGenie.Achievements.beginNextCharacter();
	elseif check.stage == "account_list" and #check.characters > 0 then
		check.index = 0;
		GMGenie.Achievements.addStarbornCheckLine("Checking " .. #check.characters .. " characters...");
		GMGenie.Achievements.beginNextCharacter();
	else
		GMGenie.Achievements.failStarbornCheck("The server response timed out.");
	end
end

function GMGenie.Achievements.failStarbornCheck(reason)
	Chronos.unscheduleByName(STARBORN_TIMEOUT);
	GMGenie.Achievements.starbornCheck.active = false;
	GMGenie_StarbornCheck_Title_Text:SetText("Starborn conditions");
	GMGenie.Achievements.clearStarbornCheck();
	GMGenie.Achievements.addStarbornCheckLine("|cffff3344Conditions not completed|r");
	GMGenie.Achievements.addStarbornCheckLine("|cffff7777" .. reason .. "|r");
end

function GMGenie.Achievements.finishStarbornCheck()
	local check = GMGenie.Achievements.starbornCheck;
	Chronos.unscheduleByName(STARBORN_TIMEOUT);
	check.active = false;
	GMGenie_StarbornCheck_Title_Text:SetText("Starborn conditions");

	local best = {};
	local unread = 0;
	for _, character in ipairs(check.results) do
		local key = normalizeClass(character.class);
		if key ~= "" and character.level then
			if not best[key] or character.level > best[key].level then
				best[key] = character;
			end
		else
			unread = unread + 1;
		end
	end

	local completed = 0;
	local lines = {};
	for _, requiredClass in ipairs(GMGenie.Achievements.starbornClasses) do
		local character = best[requiredClass.key];
		if character and character.level >= 90 then
			completed = completed + 1;
			table.insert(lines, "|cff3ee6a8" .. requiredClass.name .. " - " .. character.name .. ", level " .. character.level .. "|r");
		elseif character then
			table.insert(lines, "|cffff3344" .. requiredClass.name .. " - highest level " .. character.level .. " (" .. character.name .. ")|r");
		else
			table.insert(lines, "|cffff3344" .. requiredClass.name .. " - missing|r");
		end
	end

	GMGenie.Achievements.clearStarbornCheck();
	if completed == #GMGenie.Achievements.starbornClasses then
		GMGenie.Achievements.addStarbornCheckLine("|cff3ee6a8Conditions completed|r");
	else
		GMGenie.Achievements.addStarbornCheckLine("|cffff3344Conditions not completed|r");
	end
	GMGenie.Achievements.addStarbornCheckLine(completed .. " / " .. #GMGenie.Achievements.starbornClasses .. " classes at level 90");
	GMGenie.Achievements.addStarbornCheckLine(" ");
	for _, line in ipairs(lines) do GMGenie.Achievements.addStarbornCheckLine(line); end
	if unread > 0 then
		GMGenie.Achievements.addStarbornCheckLine(" ");
		GMGenie.Achievements.addStarbornCheckLine("|cffffaa33Warning: " .. unread .. " character(s) could not be read.|r");
	end
end

function GMGenie.Achievements.captureStarbornCheck(message)
	local check = GMGenie.Achievements.starbornCheck;
	if not check.active or not message then return false end

	if string.find(message, "No skills found") then
		GMGenie.Achievements.completeStarbornStage();
		return true;
	end

	if string.find(message, "Player not found!") then
		if check.stage == "character_pin" then check.currentMissing = true; end
		GMGenie.Achievements.completeStarbornStage();
		return true;
	end

	if check.stage == "target_pin" then
		local account = string.match(message, "Account: (.*) %(ID: .-%)");
		if account then check.account = account; return true; end
	elseif check.stage == "account_list" then
		if string.find(message, "Characters at account") then return true; end
		if string.find(message, "Account fingerprint:") then return true; end
		if GMGenie.Achievements.readAccountCharacter(message) then return true; end
	elseif check.stage == "character_pin" then
		local level = string.match(message, "Level: ([0-9]+)");
		local _, class = string.match(message, "Race: (.*), (.*)");
		if level then check.currentLevel = level; return true; end
		if class then check.currentClass = class; return true; end
	end

	-- Keep the many unrelated .pin detail lines out of the normal chat while
	-- this dedicated audit is active.
	if check.stage == "target_pin" or check.stage == "character_pin" then
		local text = stripServerFormatting(message);
		if string.find(text, "^Player ") or string.find(text, "^Account:")
			or string.find(text, "^Race:") or string.find(text, "^Level:")
			or string.find(text, "^Last ") or string.find(text, "^OS:")
			or string.find(text, "^Alive") or string.find(text, "^Money:")
			or string.find(text, "^Map:") or string.find(text, "^Guild:")
			or string.find(text, "^Phase:") or string.find(text, "^Played time:")
			or string.find(text, "^Fingerprint:") then return true; end
	end
	return false;
end

function GMGenie.Achievements.updateTargetName()
	local name = UnitName("target");
	if name and UnitIsPlayer("target") then
		GMGenie_Achievements_TargetName:SetText("Current target: |cff3ee6a8" .. name .. "|r");
	else
		GMGenie_Achievements_TargetName:SetText("Current target: |cffff3344no player selected|r");
	end
end

function GMGenie.Achievements.getTargetCharacterId(silent)
	GMGenie.Achievements.updateTargetName();
	local name = UnitName("target");
	if not name or not UnitIsPlayer("target") then
		if not silent then GMGenie.showGMMessage("Select a player first."); end
		return nil;
	end

	local characterId = nil;
	-- Spy receives the server's numeric character GUID via .pinfo. Prefer it
	-- when it belongs to the currently selected target.
	if GMGenie.Spy and GMGenie.Spy.currentRequest
		and GMGenie.Spy.currentRequest["name"] == name then
		characterId = tonumber(GMGenie.Spy.currentRequest["guid"]);
	end

	if not characterId then
		local unitGuid = UnitGUID("target");
		if unitGuid then
			local hexGuid = string.match(unitGuid, "^0x(%x+)$");
			if hexGuid then
				characterId = tonumber(string.sub(hexGuid, -8), 16);
			else
				local decimalGuid = string.match(unitGuid, "%-(%d+)$");
				if decimalGuid then characterId = tonumber(decimalGuid); end
			end
		end
	end

	if not characterId or characterId < 1 then
		if not silent then
			GMGenie.showGMMessage("Could not determine the target's Character ID. Enter it manually.");
		end
		return nil;
	end

	GMGenie_Achievements_CharacterId:SetText(tostring(characterId));
	GMGenie_Achievements_CharacterId:ClearFocus();
	return characterId;
end

function GMGenie.Achievements.toggle()
	if GMGenie_Achievements:IsShown() then
		GMGenie_Achievements:Hide();
	else
		GMGenie_Achievements:Show();
		GMGenie.Achievements.updateTargetName();
		GMGenie.Achievements.getTargetCharacterId(true);
	end
end

function GMGenie.Achievements.addStarborn()
	local name = UnitName("target");
	if not name or not UnitIsPlayer("target") then
		GMGenie.showGMMessage("Select the player who should receive Starborn.");
		return false;
	end
	GMGenie.Achievements.sendCommand(".achievement add 20012");
	return true;
end

function GMGenie.Achievements.readCharacterId()
	local value = strtrim(GMGenie_Achievements_CharacterId:GetText() or "");
	if not string.match(value, "^%d+$") or tonumber(value) < 1 then
		GMGenie.showGMMessage("Enter a valid numeric Character ID or use Target ID.");
		GMGenie_Achievements_CharacterId:SetFocus();
		return nil;
	end
	GMGenie_Achievements_CharacterId:SetText(value);
	GMGenie_Achievements_CharacterId:ClearFocus();
	return value;
end

function GMGenie.Achievements.addSpellHitCredit(spellId, achievementName)
	local characterId = GMGenie.Achievements.readCharacterId();
	if not characterId then return false end
	if type(spellId) ~= "number" then return false end
	GMGenie.Achievements.sendCommand(".addspellhitcredit " .. characterId .. " " .. spellId);
	return true;
end
