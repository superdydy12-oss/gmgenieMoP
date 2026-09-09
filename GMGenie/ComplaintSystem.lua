cmplSys = {};
cmplSys.temp = {};

cmplSys.status = {};
cmplSys.status.NONE = 0;
cmplSys.status.LOADING_LIST = 1;
cmplSys.status.LOADING_ONE = 2;
cmplSys.status.LOADED = 3;

cmplSys.formats={};
cmplSys.formats.CMPL_FORMAT_LIST = "|cffaaffaaComplaint|r:|cffaaccff (%d+).|r |cff00ff00Type|r:|cffffaa00 (.+)|r |cff00ff00Subject|r:|cffff4444(.+)|r |cff00ff00Created by|r:|cff00ccff(.+)|r |cff00ff00Created|r:|cff00ccff (%d*%a*%d*%a*%d*%a*%d*%a*) ago|r";
cmplSys.formats.CMPL_FORMAT_LIST_COMMENT = "|cff00ff00GM Comment|r:|cffff66cc .(.+).|r ";
-- cmplSys.formats.CMPL_FORMAT_CHAT_LOG = "|(.+)%((%a*)%) %- %[(.+) (.+)%] |r(.-)%[(.-)%].+%((%d+)%) (%a*)%]: (.+)";
cmplSys.formats.CMPL_FORMAT_CHAT_LOG = "|(.+)%((%a*)%) %- %[(.+) (.+)%] |r(.-)%[(.-)%].+%((%d+)%) (%a*)%-?[%a()]*%]: (.+)";

cmplSys.commands = {};
cmplSys.commands.LIST = ".complaint list";
cmplSys.commands.VIEW = ".complaint view";
cmplSys.commands.ASSIGN = ".complaint assign";
cmplSys.commands.UNASSIGN = ".complaint unassign";
cmplSys.commands.CLOSE = ".complaint close";
cmplSys.commands.COMMENT = ".complaint comment";

--Init values
cmplSys.lastEditTime = 0;
cmplSys.status.current = cmplSys.status.NONE;
cmplSys.complaints = {};
cmplSys.perPage = 10;
cmplSys.currentPage = 1;
cmplSys.pages = 1;
cmplSys.Colours = { ["current"] = "ffffffff", ["online"] = "ffbfbfff", ["offline"] = "ffff0000" };
cmplSys.done = 0;
cmplSys.doneLoaded = false;
cmplSys.pendingClosed = {};
cmplSys.windowWidth = 900;

local frame

function cSaveComplaintWindowPosition()
    if not frame or not GMGenie_SavedVars then
        return
    end

    local point, _, relativePoint, x, y = frame:GetPoint(1)
    if not point then
        return
    end

    GMGenie_SavedVars.complaintsWindowPosition = {
        point = point,
        relativePoint = relativePoint or point,
        x = x or 0,
        y = y or 0,
    }
end

function cRestoreComplaintWindowPosition()
    if not frame then
        return
    end

    local position = GMGenie_SavedVars and GMGenie_SavedVars.complaintsWindowPosition
    frame:ClearAllPoints()
    if position and position.point then
        frame:SetPoint(position.point, UIParent, position.relativePoint or position.point, position.x or 0, position.y or 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    if ValidateFramePosition then
        ValidateFramePosition(frame)
    end
end

function cUpdateComplaintCount()
	local count = getn(cmplSys.complaints);
	if GMGenie_Hud_Complaints then
		local countColor = "ff8492a6";
		if count > 0 then
			countColor = "ffff3344";
		end
		GMGenie_Hud_Complaints:SetText("Complaints (|c" .. countColor .. count .. "|r)");
	end
end

cUpdateComplaintCount();

local function cStripComplaintFormatting(text)
	if not text then
		return ""
	end
	text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
	text = string.gsub(text, "|r", "")
	text = string.gsub(text, "|H.-|h(.-)|h", "%1")
	return strtrim(text)
end

local function cBuildComplaintChatKey(date, time, channel, guid, name, message)
	return table.concat({
		tostring(date or ""),
		tostring(time or ""),
		tostring(channel or ""),
		tostring(guid or ""),
		tostring(name or ""),
		tostring(message or "")
	}, "\031")
end

local function cAddReportedComplaintText(text)
	local plainText = cStripComplaintFormatting(text)
	if plainText == "" then
		return false
	end

	cmplSys.temp.reportedText = plainText
	messageFrame:AddMessage("|cffffd200Reported message:|r " .. plainText)
	return true
end

function myChatFilterCompl(self, event, msg, author, lineID, ...)
	
	--[[
	if(UnitName("Player") == "Pick" and msg:find("Bad movement")) then
		return true
	end
	]]--
	
	if (cmplSys.status.current == cmplSys.status.LOADING_LIST or cmplSys.status.current == cmplSys.status.LOADING_ONE) and cmplSys.lastEditTime > 0 and cmplSys.lastEditTime + 3 < GetTime() then
		-- Do not filter complains related messages from chat after LOADING_LIST them into chat.
		cmplSys.status.current = cmplSys.status.LOADED;
	end
	
	if(cmplSys.status.current == cmplSys.status.LOADING_LIST and msg:find(cmplSys.formats.CMPL_FORMAT_LIST)) then
		local _, _, cmplId, cmplType, cmplSubject, cmplCreatedBy, cmplCreated = msg:find(cmplSys.formats.CMPL_FORMAT_LIST)
		local cmplSubject = strtrim(cmplSubject);
		local cmplCreatedBy = strtrim(cmplCreatedBy);

		if (isComplaintProcessed(cmplId)) then
			return true;
		end
		local cmplGmComment = "";
		if msg:find(cmplSys.formats.CMPL_FORMAT_LIST_COMMENT) then
			 local _, _, parsedComment = msg:find(cmplSys.formats.CMPL_FORMAT_LIST_COMMENT)
			 cmplGmComment = parsedComment;
		end

		local cmplAssignedTo = "";
		if msg:find("|cff00ff00Assigned To|r:|cff00ccff %a+|r") then
			 local _, _, parsedAssignedTo = msg:find("|cff00ff00Assigned To|r:|cff00ccff (%a+)|r")
			 cmplAssignedTo = parsedAssignedTo;
		end
		
		if GMGenie.Archive and GMGenie.Archive.observeId then GMGenie.Archive.observeId("complaint", cmplId); end

		local c = {
			id = cmplId,
			type = cmplType,
			subject = cmplSubject,
			createdBy = cmplCreatedBy,
			created = cmplCreated,
			gmComment = cmplGmComment,
			msg = msg,
			assigned = cmplAssignedTo,
			online = false,
			chatLog = {},
		};

		table.insert(cmplSys.complaints, c)
		cmplSys.lastEditTime = GetTime();
		cUpdateComplaintCount();
		if cIsLoaded() then
			cUpdateLeftList();
		end
		return true;
	elseif(cmplSys.status.current == cmplSys.status.LOADING_ONE and string.find(msg, "Player subject", 1, true)) then
		-- The server can send the specifically reported message either on the
		-- same line as "Player subject" or on the following system-message line.
		-- Older GMGenie code swallowed this information completely.
		local plainLine = cStripComplaintFormatting(msg)
		local reportedText = string.match(plainLine, "Player subject%s*:%s*(.+)")
		if not reportedText then
			reportedText = string.match(plainLine, "Player subject%s*%-?%s*(.+)")
		end

		if reportedText and strtrim(reportedText) ~= "" then
			cAddReportedComplaintText(reportedText)
			cmplSys.temp.expectPlayerSubject = false
		else
			cmplSys.temp.expectPlayerSubject = true
		end
		cmplSys.lastEditTime = GetTime();
		return true;
	elseif(cmplSys.status.current == cmplSys.status.LOADING_ONE and msg:find(cmplSys.formats.CMPL_FORMAT_CHAT_LOG)) then

		local _, _, cmplColor,cmplReporter, cmplDate, cmplTime, cmplChannelColor, cmplChannel, cmplNumber, cmplPlayerName, cmplMessage = msg:find(cmplSys.formats.CMPL_FORMAT_CHAT_LOG)
		local chatKey = cBuildComplaintChatKey(cmplDate, cmplTime, cmplChannel, cmplNumber, cmplPlayerName, cmplMessage)
		cmplSys.temp.seenChatMessages = cmplSys.temp.seenChatMessages or {}

		-- Some server builds send each history row twice.  Do not blindly drop
		-- every second row: only suppress a row when the complete parsed message
		-- is actually identical to one already received for this complaint.
		if cmplSys.temp.seenChatMessages[chatKey] then
			cmplSys.lastEditTime = GetTime();
			return true;
		end
		cmplSys.temp.seenChatMessages[chatKey] = true

		local wasExpectedPlayerSubject = cmplSys.temp.expectPlayerSubject == true
		cmplSys.temp.expectPlayerSubject = false

		local cChatMsg = {
			color = cmplColor,
			reporter = cmplReporter,
			date = cmplDate,
			time = cmplTime,
			cmplChannelColor = cmplChannelColor,
			channel = cmplChannel,
			guid = cmplNumber,
			name = cmplPlayerName,
			msg = cmplMessage
		}
		if(cChatMsg.color == "cff555500") then
			cChatMsg.color = "cffffffff";
		end

		table.insert(cmplSys.complaints[cmplSys.temp.loadingId].chatLog, cChatMsg)

		local v = cChatMsg;
		local formattedLine = "|"..v.color..v.time..v.cmplChannelColor.." ["..v.channel.."]: "..getPlayerLink(v.name).." "..v.msg
		if wasExpectedPlayerSubject then
			messageFrame:AddMessage("|cffffd200Reported message:|r " .. formattedLine)
			cmplSys.temp.reportedText = cStripComplaintFormatting(formattedLine)
		else
			messageFrame:AddMessage(formattedLine)
		end

		cmplSys.lastEditTime = GetTime();
		return true;
	elseif(cmplSys.status.current == cmplSys.status.LOADING_ONE and cmplSys.temp.expectPlayerSubject) then
		-- If "Player subject" is only a heading, capture the next payload line.
		-- Do not mistake the next section header for the reported message.
		if msg:find(cmplSys.formats.CMPL_FORMAT_LIST) or string.find(msg, "Chat history", 1, true) then
			cmplSys.temp.expectPlayerSubject = false
		else
			cAddReportedComplaintText(msg)
			cmplSys.temp.expectPlayerSubject = false
		end
		cmplSys.lastEditTime = GetTime();
		return true;
	elseif((cmplSys.status.current == cmplSys.status.LOADING_ONE) and (msg:find(cmplSys.formats.CMPL_FORMAT_LIST) or string.find(msg, "Chat history", 1, true))) then
		-- Complaint summary and section headers are already represented by the UI.
		cmplSys.temp.expectPlayerSubject = false
		cmplSys.lastEditTime = GetTime();
		return true;
	elseif(msg:find("Closed by") and msg:find("Complaint")) then
		local _, _, cId = msg:find("|cffaaffaaComplaint|r:|cffaaccff (%d+)") -- /run myChatFilterCompl("","","Closed by |cffaaffaaComplaint|r:|cffaaccff 13.")
		
		local i = 1
		while cmplSys.complaints[i] do
			if(cmplSys.complaints[i].id == cId) then
				table.remove(cmplSys.complaints,i);
				break;
			end
			
			i = i + 1;
		end
		if cmplSys.pendingClosed[cId] then
			cmplSys.pendingClosed[cId] = nil
		else
			cmplSys.done = cmplSys.done + 1;
			if GMGenie_SavedVars then
				GMGenie_SavedVars.complaintsDone = cmplSys.done;
			end
		end
		cUpdateComplaintCount();
		if cIsLoaded() then
			cUpdateLeftList();
		end
		return false;
	elseif((msg:find("Assigned to") or msg:find("Unassigned by")) and msg:find("Complaint")) then
		getComplaintList();
		return false;
	elseif msg:find("|cff00ff00New complaint from|r|cffff00ff") and msg:find(":|r|cffff00ff %d+.|r") then
		local plainNotification = cStripComplaintFormatting(msg)
		local complaintName, complaintId = string.match(plainNotification, "New complaint from%s*([^:]+):%s*(%d+)")
		if GMGenie.Notifications then
			GMGenie.Notifications.newComplaint(complaintId, complaintName)
		end
		getComplaintList();
		return false;
	elseif (cmplSys.status.current == cmplSys.status.LOADING_ONE) then
		cmplSys.status.chatreader = 1;
		if (cmplSys.cheatcoords) then
--			GMGenie.showGMMessage("from cmplSys: " .. cmplSys.cheatcoords);
		end
	else
		cmplSys.status.chatreader = 0;
	end

end
ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", myChatFilterCompl)
-- /run loadComplaints()
function getComplaintList()
	cmplSys.complaints = {};
	cmplSys.currentPage = 1;
	cUpdateComplaintCount();
	cmplSys.lastEditTime = GetTime();
	cmplSys.status.current = cmplSys.status.LOADING_LIST;
	
	SendChatMessage(cmplSys.commands.LIST);
end

-- /run getComplaint(10)
function getComplaintInfo(id)
	local complaint = cmplSys.complaints[id];
	
	cmplSys.status.current = cmplSys.status.LOADING_ONE ;
	cmplSys.lastEditTime = GetTime();
	cmplSys.temp.loadingId = id;
	cmplSys.temp.messagesRead = 0;
	cmplSys.temp.seenChatMessages = {};
	cmplSys.temp.expectPlayerSubject = false;
	cmplSys.temp.reportedText = nil;
	
	cUpdateComplaintHeader(complaint)

	SendChatMessage(cmplSys.commands.VIEW.." "..complaint.id);
	
	if GMGenie_SavedVars.useSpy then
		if (cmplSys.pushright == 2) then
			GMGenie.Spy.spy(complaint.subject);
		else
			GMGenie.Spy.spy(complaint.createdBy);
		end
	end

end

function isComplaintProcessed(id)
	for i,v in pairs(cmplSys.complaints) do 
		if v['id'] == id then 
			return true 
		end
	end
	return false;
end

function getPlayerLink(playerName)
	if playerName == nil then 
		return "" 
	end
	return  "\124Hplayer:"..playerName.."\124h["..playerName.."]\124h"
end
---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
----UI Source: https://www.wowinterface.com/forums/showthread.php?t=42408 -------
---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
---------------------------------------------------------------------------------

function cRemoveSelectedC()
	cmplSys.cSelected = {}
	cmplSys.selectedComplaintId = nil
	messageFrame:Clear()
	cUpdateComplaintHeader(nil)

	if cRefreshSelectedComplaintHighlight then
		cRefreshSelectedComplaintHighlight()
	end
end

frame = CreateFrame("Frame", "PicksComplaintFrame", UIParent)
frame.width  = cmplSys.windowWidth
frame.height = 350
frame:SetFrameStrata("DIALOG")
-- frame:SetScale(0.9)
frame:SetFrameLevel(0)
frame:SetSize(frame.width, frame.height)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
frame:SetBackdrop({
	bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile     = true,
	tileSize = 12,
	edgeSize = 12,
	insets   = { left = 3, right = 3, top = 3, bottom = 3}
})
frame:SetBackdropColor(0.012, 0.028, 0.045, 0.98)
frame:SetBackdropBorderColor(0.1, 0.55, 0.65, 1)
frame:EnableMouse(true)
frame:EnableMouseWheel(true)

-- Use the same compact title bar as the other GMGenie windows.
local complaintTitle = CreateFrame("Frame", nil, frame)
complaintTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
complaintTitle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -36, 0)
complaintTitle:SetHeight(18)
complaintTitle:SetBackdrop({
	bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile     = true,
	tileSize = 12,
	edgeSize = 12,
	insets   = { left = 3, right = 3, top = 3, bottom = 3}
})
complaintTitle:SetBackdropColor(0.02, 0.07, 0.11, 0.98)
complaintTitle:SetBackdropBorderColor(0.1, 0.55, 0.65, 1)
local complaintTitleText = complaintTitle:CreateFontString(nil, "OVERLAY", "GenieFontHighlightSmall")
complaintTitleText:SetPoint("CENTER", complaintTitle, "CENTER", 18, 0)
complaintTitleText:SetText("Complaints")
frame.complaintTitle = complaintTitle

-- Make movable/resizable
frame:SetMovable(true)
frame:SetResizable(enable)
frame:SetMinResize(100, 100)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    cSaveComplaintWindowPosition()
end)
frame:SetScript("OnMouseUp", function(self)
    self:StopMovingOrSizing()
    cSaveComplaintWindowPosition()
end)
frame:SetClampedToScreen(true)

tinsert(UISpecialFrames, "PicksComplaintFrame")

function cShowComplaintSystem()
	if PicksComplaintFrame:IsShown() then
		PicksComplaintFrame:Hide();
	else
		getComplaintList();
		cRestoreComplaintWindowPosition();
		PicksComplaintFrame:Show();
		if (not cIsLoaded()) then cCreateLeftList(); end
	end
end

function cIsLoaded()
	return frame.cComplaintsLoaded == true;
end

---------- UI List
local COMPLAINT_BORDER_NORMAL = { 0.12, 0.48, 0.58, 1 }
local COMPLAINT_BORDER_SELECTED = { 1.00, 0.82, 0.10, 1 }
local COMPLAINT_TEXT_COLOURS = {
	online = "ffffffff",
	offline = "ffff0000",
}

local function cSetComplaintButtonSelected(button, selected)
	if not button then
		return
	end
	if selected then
		button:LockHighlight()
	else
		button:UnlockHighlight()
	end
end

function cRefreshSelectedComplaintHighlight()
	local count = btnCount or 10
	for btnId = 0, count - 1 do
		local button = _G["cListBtn"..btnId]
		local selected = button
			and button:IsShown()
			and button.c
			and cmplSys.selectedComplaintId
			and tostring(button.c.id) == tostring(cmplSys.selectedComplaintId)

		cSetComplaintButtonSelected(button, selected)
	end
end

local function cGetComplaintColour(c)
	if c and cmplSys.selectedComplaintId and tostring(c.id) == tostring(cmplSys.selectedComplaintId) then
		return cmplSys.Colours["current"]
	end
	if c and c.online == false then
		return cmplSys.Colours["offline"]
	end
	return cmplSys.Colours["online"]
end

local function cSetRowFont(fs, x, width, justify)
	fs:SetPoint("LEFT", x, 0)
	fs:SetWidth(width)
	fs:SetJustifyH(justify or "LEFT")
	fs:SetPoint("TOP", 0, -1)
	fs:SetPoint("BOTTOM", 0, 1)
end

local function cCreateHeaderButton(name, textLabel, width, anchorTo, relativePoint, offsetX)
	local button = CreateFrame("Button", name, frame, "GMGenie_LeftButton")
	button:SetHeight(16)
	button:SetWidth(width)
	button:SetNormalFontObject(GenieFontHighlightSmall)
	button:SetHighlightFontObject(GenieFontHighlightSmall)
	if anchorTo then
		button:SetPoint("LEFT", anchorTo, relativePoint or "RIGHT", offsetX or 0, 0)
	else
		button:SetPoint("TOPLEFT", frame, "TOPLEFT", 3 + (offsetX or 0), -30)
	end
	button:SetText(textLabel)
	return button
end

local function cUpdateComplaintButtonText(button, c)
	if not button then
		return
	end
	if not c then
		button.cId:SetText("")
		button.cName:SetText("")
		button.cType:SetText("")
		button.cCreated:SetText("")
		button.cAssigned:SetText("")
		return
	end

	local colour = "|c" .. cGetComplaintColour(c)
	local suffix = "|r"
	local createdText = tostring(c.created or "")
	if c.createdBy and c.createdBy ~= "" then
		createdText = createdText .. " - " .. c.createdBy
	end

	button.cId:SetText(colour .. tostring(c.id or "") .. suffix)
	button.cName:SetText(colour .. tostring(c.subject or "") .. suffix)
	button.cType:SetText(colour .. tostring(c.type or "") .. suffix)
	button.cCreated:SetText(colour .. createdText .. suffix)
	button.cAssigned:SetText(colour .. tostring(c.assigned or "") .. suffix)
end


local function cBuildComplaintDetailTitle(c)
	if not c or not c.id then
		return "Select a complaint"
	end
	local subject = c.subject or c.createdBy or "Complaint"
	return subject .. "'s Complaint"
end

local function cBuildComplaintMeta(c)
	return ""
end

function cUpdateComplaintHeader(c)
	if cLblSubject then
		cLblSubject:SetText(cBuildComplaintDetailTitle(c))
		cLblSubject:Show()
	end
	if cLblMeta then
		cLblMeta:SetText("")
		cLblMeta:Hide()
	end
end

function cSyncSelectedComplaintOnlineState()
	if not (cmplSys and cmplSys.cSelected and cmplSys.cSelected.id and GMGenie and GMGenie.Spy and GMGenie.Spy.currentRequest) then
		return
	end
	local currentName = GMGenie.Spy.currentRequest["name"]
	if not currentName or currentName == "" then
		return
	end
	if currentName == cmplSys.cSelected.subject or currentName == cmplSys.cSelected.createdBy then
		cmplSys.cSelected.online = (GMGenie.Spy.currentRequest["offline"] ~= "\(offline\)")
		cUpdateLeftList()
	end
end

function cCreateBtnList(count)-- Load list button
	local columnIdWidth = 40
	local columnNameWidth = 80
	local columnTypeWidth = 80
	local columnCreatedWidth = 80
	local columnAssignedWidth = 80

	frame.cHeaderId = cCreateHeaderButton("cHeaderComplaintId", "#", columnIdWidth, nil, nil, 2)
	frame.cHeaderId:ClearAllPoints()
	frame.cHeaderId:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -19)
	frame.cHeaderId:SetHeight(18)

	frame.cHeaderName = cCreateHeaderButton("cHeaderComplaintName", "Name", columnNameWidth, frame.cHeaderId, "RIGHT", 0)
	frame.cHeaderName:SetHeight(18)
	frame.cHeaderType = cCreateHeaderButton("cHeaderComplaintType", "Type", columnTypeWidth, frame.cHeaderName, "RIGHT", 0)
	frame.cHeaderType:SetHeight(18)
	frame.cHeaderCreated = cCreateHeaderButton("cHeaderComplaintCreated", "Created", columnCreatedWidth, frame.cHeaderType, "RIGHT", 0)
	frame.cHeaderCreated:SetHeight(18)
	frame.cHeaderAssigned = cCreateHeaderButton("cHeaderComplaintAssigned", "Assigned To", columnAssignedWidth, frame.cHeaderCreated, "RIGHT", 0)
	frame.cHeaderAssigned:SetHeight(18)

	for variable = 0, count-1, 1 do
		local btnName = "cListBtn"..variable;
		_G[btnName] = CreateFrame("Button", btnName, frame, "GMGenie_Tickets_StatusTemplate")
		if variable == 0 then
			_G[btnName]:SetPoint("TOPLEFT", frame.cHeaderId, "BOTTOMLEFT", 0, 0)
		else
			_G[btnName]:SetPoint("TOPLEFT", _G["cListBtn"..(variable - 1)], "BOTTOMLEFT", 0, 0)
		end
		_G[btnName]:RegisterForClicks("LeftButtonUp","RightButtonUp");
		_G[btnName]:SetHeight(16)
		_G[btnName]:SetWidth(360)
		_G[btnName]:SetFrameLevel(2)

		_G[btnName].cId = _G[btnName .. "_ticketId"]
		_G[btnName].cName = _G[btnName .. "_name"]
		_G[btnName].cType = _G[btnName .. "_createStr"]
		_G[btnName].cCreated = _G[btnName .. "_lastModifiedStr"]
		_G[btnName].cAssigned = _G[btnName .. "_assignedTo"]

		_G[btnName]:SetScript("OnClick", function(self, button, down)
			if (button == "LeftButton") then
				cmplSys.pushright = 2;
				cmplSys.cheatcoords = "";
			else
				cmplSys.pushright = 1;
				cmplSys.cheatcoords = "";
			end
			messageFrame:Clear()
			cmplSys.status.current = cmplSys.status.LOADED;
			cmplSys.cSelected = self.c;
			cmplSys.selectedComplaintId = self.c and self.c.id or nil;
			if GMGenie.Notifications and self.c then
				GMGenie.Notifications.markSeen("complaint", self.c.id)
			end
			cRefreshSelectedComplaintHighlight();
			cUpdateLeftList();
			getComplaintInfo(self.value)
		end)
		_G[btnName]:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT");
			GameTooltip:AddLine("Created "..self.c.created.." ago");
			if (self.c.type ~= nil and self.c.type ~= "") then
				GameTooltip:AddLine("Type: "..self.c.type);
			end
			if (self.c.createdBy ~= nil and self.c.createdBy ~= "") then
				GameTooltip:AddLine("by "..self.c.createdBy);
			end
			if (self.c.gmComment ~= nil and self.c.gmComment ~= "") then
				GameTooltip:AddLine("GM Comment: "..self.c.gmComment);
			end
			if (self.c.assigned ~= nil and self.c.assigned ~= "") then
				GameTooltip:AddLine("Assigned to: "..self.c.assigned);
			end
			GameTooltip:Show();
		end)
		_G[btnName]:SetScript("OnLeave", function(self)
			GameTooltip:Hide();
		end)
		frame[btnName] = _G[btnName]
	end

	local loadListBtn = CreateFrame("Button", nil, frame, "GMGenie_Button")
	loadListBtn:SetPoint("TOPRIGHT", -18, 0)
	loadListBtn:SetHeight(18)
	loadListBtn:SetWidth(18)
	loadListBtn:SetText("R")
	loadListBtn:SetScript("OnClick", function(self)
		getComplaintList();
		cRemoveSelectedC();
	end)
	frame.loadListBtn = loadListBtn
	
	local cCloseBtn = CreateFrame("Button", nil, frame, "GMGenie_Button")
	cCloseBtn:SetPoint("TOPRIGHT", 0, 0)
	cCloseBtn:SetHeight(18)
	cCloseBtn:SetWidth(18)
	cCloseBtn:SetText("X")
	cCloseBtn:SetScript("OnClick", function(self)
		cShowComplaintSystem();
	end)
	frame.cCloseBtn = cCloseBtn

	frame.cPrevBtn = CreateFrame("Button", "GMGenie_Complaints_Previous", frame, "GMGenie_PreviousButton")
	frame.cPrevBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 2, 1)
	frame.cPrevBtn:SetScript("OnClick", function() cGoToPreviousPage(); end)

	frame.cNextBtn = CreateFrame("Button", "GMGenie_Complaints_Next", frame, "GMGenie_NextButton")
	frame.cNextBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 329, 1)
	frame.cNextBtn:SetScript("OnClick", function() cGoToNextPage(); end)

	frame.cInfo = CreateFrame("Frame", "GMGenie_Complaints_Info", frame)
	frame.cInfo:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 60, 9)
	frame.cInfo:SetWidth(260)
	frame.cInfo:SetHeight(30)
	frame.cInfo.text = frame.cInfo:CreateFontString("GMGenie_Complaints_Info_Text", "OVERLAY", "GenieFontNormalSmall")
	frame.cInfo.text:SetPoint("TOP", frame.cInfo, "TOP", 0, 0)
	frame.cInfo.text:SetJustifyH("CENTER")
	frame.cInfo.page = frame.cInfo:CreateFontString("GMGenie_Complaints_Info_Page", "OVERLAY", "GenieFontNormalSmall")
	frame.cInfo.page:SetPoint("TOP", frame.cInfo.text, "BOTTOM", 0, 0)
	frame.cInfo.page:SetJustifyH("CENTER")
end

function updateLeftButtons(startIndex)
	for btnId = 0, btnCount - 1, 1 do
		local btnName = "cListBtn"..btnId;
		local cId = 1 + startIndex + btnId;
		local c = cmplSys.complaints[cId];
		local button = _G[btnName]
		
		if(c == nil) then
			button.c = nil;
			button.value = nil;
			cUpdateComplaintButtonText(button, nil)
			cSetComplaintButtonSelected(button, false);
			button:Hide()
		else
			button.value = cId;
			button.c = c;
			cUpdateComplaintButtonText(button, c)
			cSetComplaintButtonSelected(button, cmplSys.selectedComplaintId and tostring(c.id) == tostring(cmplSys.selectedComplaintId));
			button:Show()
		end
	end
end

local function cUpdateComplaintPagingInfo(total, onlineCount, offlineCount)
	if not cmplSys.doneLoaded and GMGenie_SavedVars then
		cmplSys.done = GMGenie_SavedVars.complaintsDone or 0
		cmplSys.doneLoaded = true
	end
	local plural = (total == 1) and "" or "s"
	if frame.cInfo and frame.cInfo.text then
		frame.cInfo.text:SetText(total .. " complaint" .. plural .. " (|c" .. cmplSys.Colours["online"] .. onlineCount .. " online,|r |c" .. cmplSys.Colours["offline"] .. offlineCount .. " offline|r), " .. cmplSys.done .. " done")
		frame.cInfo.page:SetText("Page " .. cmplSys.currentPage .. " of " .. cmplSys.pages)
	end
end

function cUpdateLeftList()
	cUpdateComplaintCount();
	local total = getn(cmplSys.complaints)
	local onlineCount = 0
	local offlineCount = 0
	for _, complaint in ipairs(cmplSys.complaints) do
		if complaint.online == false then
			offlineCount = offlineCount + 1
		else
			onlineCount = onlineCount + 1
		end
	end

	cmplSys.pages = math.ceil(total / cmplSys.perPage)
	if cmplSys.pages < 1 then
		cmplSys.pages = 1
	end
	if cmplSys.currentPage > cmplSys.pages then
		cmplSys.currentPage = cmplSys.pages
	elseif cmplSys.currentPage < 1 then
		cmplSys.currentPage = 1
	end

	cUpdateComplaintPagingInfo(total, onlineCount, offlineCount)
	if frame.cPrevBtn then
		if cmplSys.currentPage <= 1 then frame.cPrevBtn:Disable() else frame.cPrevBtn:Enable() end
	end
	if frame.cNextBtn then
		if cmplSys.currentPage >= cmplSys.pages then frame.cNextBtn:Disable() else frame.cNextBtn:Enable() end
	end

	local startIndex = (cmplSys.currentPage - 1) * cmplSys.perPage
	updateLeftButtons(startIndex)
	cRefreshSelectedComplaintHighlight()
end

btnCount = 10;
cCreateBtnList(btnCount);

function cGoToNextPage()
	if cmplSys.currentPage < cmplSys.pages then
		cmplSys.currentPage = cmplSys.currentPage + 1
		cUpdateLeftList()
	end
end

function cGoToPreviousPage()
	if cmplSys.currentPage > 1 then
		cmplSys.currentPage = cmplSys.currentPage - 1
		cUpdateLeftList()
	end
end

function cCreateLeftList()
	frame.cComplaintsLoaded = true;
	if scrollBarLeft then
		scrollBarLeft:Hide()
	end
	cUpdateLeftList()
end


-- ScrollingMessageFrame
messageFrame = CreateFrame("ScrollingMessageFrame", nil, frame)
messageFrame:SetPoint("TOPRIGHT",-3, -30)
messageFrame:SetSize(400, frame.height - 90)
messageFrame:SetFontObject(ChatFontNormal)
messageFrame:SetTextColor(1, 1, 1, 1) -- default color
messageFrame:SetJustifyH("LEFT")
messageFrame:SetHyperlinksEnabled(true)
messageFrame:SetFading(false)
messageFrame:SetMaxLines(300)
frame.messageFrame = messageFrame

---------------------------------------------------------------------------
-- Scroll bar
-------------------------------------------------------------------------------
local scrollBar = CreateFrame("Slider", "GMGenie_Complaints_ScrollBar", frame, "UIPanelScrollBarTemplate")
scrollBar:SetPoint("LEFT", messageFrame, "LEFT", -25, -10)
scrollBar:SetSize(30, frame.height - 90)
scrollBar:SetMinMaxValues(0, 50)
scrollBar:SetValueStep(1)
scrollBar.scrollStep = 1
frame.scrollBar = scrollBar

scrollBar:SetScript("OnValueChanged", function(self, value)
	messageFrame:SetScrollOffset(select(2, scrollBar:GetMinMaxValues()) - value)
end)

scrollBar:SetValue(select(2, scrollBar:GetMinMaxValues()))

messageFrame:SetScript("OnMouseWheel", function(self, delta)
	--print(messageFrame:GetNumMessages(), messageFrame:GetNumLinesDisplayed())

	local cur_val = scrollBar:GetValue()
	local min_val, max_val = scrollBar:GetMinMaxValues()

	if delta < 0 and cur_val < max_val then
		cur_val = math.min(max_val, cur_val + 1)
		scrollBar:SetValue(cur_val)
	elseif delta > 0 and cur_val > min_val then
		cur_val = math.max(min_val, cur_val - 1)
		scrollBar:SetValue(cur_val)
	end
end)

local complaintDetailPane = CreateFrame("Frame", "GMGenie_Complaints_InlinePane", frame)
complaintDetailPane:SetFrameLevel(frame:GetFrameLevel() + 1)
complaintDetailPane:SetBackdrop({
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileSize = 12,
	edgeSize = 12,
	insets = { left = 3, right = 3, top = 3, bottom = 3 }
})
complaintDetailPane:SetBackdropColor(0.012, 0.028, 0.045, 0.94)
complaintDetailPane:SetBackdropBorderColor(0.08, 0.38, 0.46, 1)
frame.complaintDetailPane = complaintDetailPane

local complaintMessageBox = CreateFrame("Frame", nil, complaintDetailPane)
complaintMessageBox:SetFrameLevel(complaintDetailPane:GetFrameLevel() + 1)
complaintMessageBox:SetBackdrop({
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileSize = 12,
	edgeSize = 12,
	insets = { left = 3, right = 3, top = 3, bottom = 3 }
})
complaintMessageBox:SetBackdropColor(0.012, 0.028, 0.045, 0.98)
complaintMessageBox:SetBackdropBorderColor(0.08, 0.38, 0.46, 1)
frame.complaintMessageBox = complaintMessageBox

messageFrame:SetParent(complaintDetailPane)
messageFrame:SetFrameLevel(complaintMessageBox:GetFrameLevel() + 1)
scrollBar:SetParent(complaintDetailPane)
scrollBar:SetFrameLevel(messageFrame:GetFrameLevel() + 1)

cLblSubject = complaintDetailPane:CreateFontString(nil, "OVERLAY", "GenieFontHighlightSmall")
cLblSubject:SetJustifyH("CENTER")
cLblSubject:SetText("")
frame.cLblSubject = cLblSubject

cLblMeta = complaintDetailPane:CreateFontString(nil, "OVERLAY", "GenieFontNormalSmall")
cLblMeta:SetJustifyH("LEFT")
cLblMeta:SetText("")
cLblMeta:Hide()
frame.cLblMeta = cLblMeta

local cEditBox = CreateFrame("EditBox", nil, messageFrame, "GMGenie_Input_Text")
cEditBox:SetPoint("BOTTOMLEFT", messageFrame, 0, -25)
cEditBox:SetHeight(25)
-- cEditBox:SetWidth(235)
cEditBox:SetWidth(300)
frame.cEditBox = cEditBox;

local cCommentBtn = CreateFrame("Button", nil, messageFrame, "GMGenie_Button")
cCommentBtn:SetPoint("TOPRIGHT", cEditBox, 75, 0)
cCommentBtn:SetHeight(25)
cCommentBtn:SetWidth(75)
cCommentBtn:SetText("Comment")
cCommentBtn:SetScript("OnClick", function(self)
	if(cmplSys.cSelected == nil or cmplSys.cSelected.id == nil) then return end
	SendChatMessage(cmplSys.commands.COMMENT.." "..cmplSys.cSelected.id.." "..cEditBox:GetText());
	cEditBox:ClearFocus()
end)
frame.cCommentBtn = cCommentBtn

local cCloseBtn = CreateFrame("Button", nil, messageFrame, "GMGenie_Button")
cCloseBtn:SetPoint("BOTTOMLEFT", messageFrame, 0, -53)
cCloseBtn:SetHeight(25)
cCloseBtn:SetWidth(75)
cCloseBtn:SetText("Close")
cCloseBtn:SetScript("OnClick", function(self)
	if(cmplSys.cSelected == nil or cmplSys.cSelected.id == nil) then return end
	cmplSys.pendingClosed[cmplSys.cSelected.id] = true
	SendChatMessage(cmplSys.commands.CLOSE.." "..cmplSys.cSelected.id)
	cmplSys.done = cmplSys.done + 1
	if GMGenie_SavedVars then
		GMGenie_SavedVars.complaintsDone = cmplSys.done
	end
	cRemoveSelectedC();
	cUpdateLeftList()
end)
frame.cCloseBtn = cCloseBtn

local cAssignBtn = CreateFrame("Button", nil,messageFrame, "GMGenie_Button")
cAssignBtn:SetPoint("BOTTOMLEFT", messageFrame, 75, -53)
cAssignBtn:SetHeight(25)
cAssignBtn:SetWidth(75)
cAssignBtn:SetText("Assign")
cAssignBtn:SetScript("OnClick", function(self)
	if(cmplSys.cSelected == nil or cmplSys.cSelected.id == nil) then return end
	local playerName = UnitName("Player")
	cmplSys.cSelected.assigned = playerName
	SendChatMessage(cmplSys.commands.ASSIGN.." "..cmplSys.cSelected.id.." "..playerName)
	cUpdateLeftList()
end)
frame.cAssignBtn = cAssignBtn

local cUnassignBtn = CreateFrame("Button", nil, messageFrame, "GMGenie_Button")
cUnassignBtn:SetPoint("BOTTOMLEFT", messageFrame, 75*2, -53)
cUnassignBtn:SetHeight(25)
cUnassignBtn:SetWidth(75)
cUnassignBtn:SetText("Unassign")
cUnassignBtn:SetScript("OnClick", function(self)
	if(cmplSys.cSelected == nil or cmplSys.cSelected.id == nil) then return end
	cmplSys.cSelected.assigned = ""
	SendChatMessage(cmplSys.commands.UNASSIGN.." "..cmplSys.cSelected.id.." "..UnitName("Player"))
	cUpdateLeftList()
end)
frame.cUnassignBtn = cUnassignBtn

local cGPSBtn = CreateFrame("Button", nil, messageFrame, "GMGenie_Button")
cGPSBtn:SetPoint("BOTTOMLEFT", messageFrame, 75*3, -53)
cGPSBtn:SetHeight(25)
cGPSBtn:SetWidth(85)
cGPSBtn:SetText("Cheat TP")
cGPSBtn:SetScript("OnClick", function(self)
if(cmplSys.cheatcoords == "") then 
	GMGenie.showGMMessage("No cheater coordinates for this complaint");
	return
else
--	GMGenie.showGMMessage("TPing to " .. cmplSys.cheatcoords);
-- mop server .go xyz actually uses orientation, complaint system feeds coords back w/o this so not compatible
--	local cheatmap = (cmplSys.cheatcoords):match('[^ ]+$');
--	SendChatMessage(".go xyz " .. cmplSys.cheatcoords .. " " .. cheatmap);
--	cmplSys.cheatcoords:gsub('([^ ]+)$', '0 %1');
--	SendChatMessage(".go xyz " .. cmplSys.cheatcoords);
--	GMGenie.showGMMessage("TPing to " .. cmplSys.cheatcoords .. " " .. cheatmap);
    local coords = cmplSys.cheatcoords:gsub('([^ ]+)$', '0 %1');
    SendChatMessage(".go xyz " .. coords);
	GMGenie.showGMMessage("TPing to " .. coords);
end

end)
frame.cGPSBtn = cGPSBtn;

local function cApplyComplaintLayout()
	local contentLeft = 372
	local detailWidth = cmplSys.windowWidth - 388

	complaintDetailPane:ClearAllPoints()
	complaintDetailPane:SetPoint("TOPLEFT", frame, "TOPLEFT", 371, -19)
	complaintDetailPane:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 5)

	cLblSubject:ClearAllPoints()
	cLblSubject:SetPoint("TOPLEFT", complaintDetailPane, "TOPLEFT", 8, -5)
	cLblSubject:SetPoint("TOPRIGHT", complaintDetailPane, "TOPRIGHT", -8, -5)
	cLblSubject:SetJustifyH("CENTER")
	cLblSubject:Show()

	cLblMeta:Hide()

	complaintMessageBox:ClearAllPoints()
	complaintMessageBox:SetPoint("TOPLEFT", complaintDetailPane, "TOPLEFT", 6, -24)
	complaintMessageBox:SetPoint("BOTTOMRIGHT", complaintDetailPane, "BOTTOMRIGHT", -6, 111)

	messageFrame:ClearAllPoints()
	messageFrame:SetPoint("TOPLEFT", complaintMessageBox, "TOPLEFT", 6, -6)
	messageFrame:SetPoint("BOTTOMRIGHT", complaintMessageBox, "BOTTOMRIGHT", -28, 6)

	scrollBar:ClearAllPoints()
	scrollBar:SetPoint("TOPRIGHT", complaintMessageBox, "TOPRIGHT", 0, -18)
	scrollBar:SetPoint("BOTTOMRIGHT", complaintMessageBox, "BOTTOMRIGHT", 0, 18)
	local scrollUp = _G["GMGenie_Complaints_ScrollBarScrollUpButton"]
	local scrollDown = _G["GMGenie_Complaints_ScrollBarScrollDownButton"]
	if scrollUp then
		scrollUp:ClearAllPoints()
		scrollUp:SetPoint("BOTTOM", scrollBar, "TOP", 0, 0)
	end
	if scrollDown then
		scrollDown:ClearAllPoints()
		scrollDown:SetPoint("TOP", scrollBar, "BOTTOM", 0, 0)
	end

	cEditBox:ClearAllPoints()
	cEditBox:SetPoint("BOTTOMLEFT", complaintDetailPane, "BOTTOMLEFT", 0, 33)
	cEditBox:SetWidth(detailWidth - 72)
	cEditBox:SetHeight(25)

	cCommentBtn:ClearAllPoints()
	cCommentBtn:SetPoint("LEFT", cEditBox, "RIGHT", 4, 0)
	cCommentBtn:SetWidth(68)
	cCommentBtn:SetHeight(25)

	cCloseBtn:ClearAllPoints()
	cCloseBtn:SetPoint("BOTTOMLEFT", complaintDetailPane, "BOTTOMLEFT", 0, 0)

	cAssignBtn:ClearAllPoints()
	cAssignBtn:SetPoint("LEFT", cCloseBtn, "RIGHT", 0, 0)

	cUnassignBtn:ClearAllPoints()
	cUnassignBtn:SetPoint("LEFT", cAssignBtn, "RIGHT", 0, 0)

	cGPSBtn:ClearAllPoints()
	cGPSBtn:SetPoint("LEFT", cUnassignBtn, "RIGHT", 0, 0)
end

cApplyComplaintLayout()
cUpdateComplaintHeader(nil)


