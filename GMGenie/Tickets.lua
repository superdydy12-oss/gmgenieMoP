--This file is part of Game Master Genie.
--Copyright 2011-2014 Chocochaos

--Game Master Genie is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 3 of the License.
--Game Master Genie is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
--You should have received a copy of the GNU General Public License along with Game Master Genie. If not, see <http://www.gnu.org/licenses/>.

GMGenie.Tickets = {};

-- config
GMGenie.Tickets.perPage = 10;

-- vars
GMGenie.Tickets.pages = 1;
GMGenie.Tickets.tickets = 0;
GMGenie.Tickets.onlineTickets = 0;
GMGenie.Tickets.currentPage = 1;
GMGenie.Tickets.currentTicket = { ["num"] = 0, ["ticketId"] = 0, ['name'] = "", ["message"] = "" };
GMGenie.Tickets.order = "ticketId";
GMGenie.Tickets.ascDesc = false;
GMGenie.Tickets.messageOpen = false;
GMGenie.Tickets.done = 0;
GMGenie.Tickets.syncList = {};
GMGenie.Tickets.loadingOnline = false;
--GMGenie.Tickets.Colours = { ["onlineUnread"] = "ffbfbfff", ["onlineRead"] = "ffffffff", ["offlineUnread"] = "ff5f5f80", ["offlineRead"] = "ff808080" };
GMGenie.Tickets.Colours = { ["current"] = "ffffffff", ["onlineUnread"] = "ffbfbfff", ["onlineRead"] = "ff5f5f7f", ["offlineUnread"] = "ffff0000", ["offlineRead"] = "ff7f0000" };

-- ticket list
GMGenie.Tickets.list = {};
GMGenie.Tickets.read = {};
GMGenie.Tickets.idToNum = {};
GMGenie.Tickets.unifiedLayout = true;

function GMGenie.Tickets.applyTicketTextPadding()
    local ticketText = _G["GMGenie_Tickets_View_Ticket_Frame_Text"];
    local ticketScrollFrame = _G["GMGenie_Tickets_View_Ticket_Frame"];
    if ticketText and ticketScrollFrame then
        -- Keep the user-tested -10 width adjustment, but reserve a small
        -- text inset for the scrollbar/arrow buttons. This keeps the wide
        -- text area without allowing glyphs to render underneath the arrows.
        local rightPadding = -10;
        local scrollbarTextInset = 28;
        ticketText:SetWidth(math.max(40, ticketScrollFrame:GetWidth() - rightPadding));
        ticketText:SetTextInsets(5, scrollbarTextInset, 5, 5);
    end
end
GMGenie.Tickets.windowWidth = 900;

function GMGenie.Tickets.saveWindowPosition(frame)
    if not frame or not GMGenie_SavedVars then
        return;
    end

    local point, _, relativePoint, x, y = frame:GetPoint(1);
    if not point then
        return;
    end

    GMGenie_SavedVars.ticketsWindowPosition = {
        point = point,
        relativePoint = relativePoint or point,
        x = x or 0,
        y = y or 0,
    };
end

function GMGenie.Tickets.restoreWindowPosition(frame)
    if not frame then
        return;
    end

    local position = GMGenie_SavedVars and GMGenie_SavedVars.ticketsWindowPosition;
    frame:ClearAllPoints();
    if position and position.point then
        frame:SetPoint(position.point, UIParent, position.relativePoint or position.point, position.x or 0, position.y or 0);
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0);
    end
    if ValidateFramePosition then
        ValidateFramePosition(frame);
    end
end

function GMGenie.Tickets.applyAssignedState(ticketId, assignedTo, skipRefresh)
    ticketId = tonumber(ticketId);
    assignedTo = assignedTo or "";

    if GMGenie.Tickets.tempList and GMGenie.Tickets.idToNum[ticketId] then
        GMGenie.Tickets.tempList[GMGenie.Tickets.idToNum[ticketId]]["assignedTo"] = assignedTo;
    elseif GMGenie.Tickets.idToNum[ticketId] then
        GMGenie.Tickets.list[GMGenie.Tickets.idToNum[ticketId]]["assignedTo"] = assignedTo;
    else
        return false;
    end

    if tonumber(GMGenie.Tickets.currentTicket["ticketId"]) == ticketId then
        GMGenie.Tickets.currentTicket["assignedTo"] = assignedTo;
    end

    if not skipRefresh and not GMGenie.Tickets.tempList then
        GMGenie.Tickets.updateView();
    end
    return true;
end

function GMGenie.Tickets.updateDetailTitle()
    local title = "Select a ticket"
    if GMGenie.Tickets.currentTicket and tonumber(GMGenie.Tickets.currentTicket["ticketId"]) and tonumber(GMGenie.Tickets.currentTicket["ticketId"]) > 0 then
        title = GMGenie.Tickets.currentTicket["name"] .. "'s Ticket"
    end

    if GMGenie_Tickets_View_Title_Text then
        GMGenie_Tickets_View_Title_Text:SetText(title);
    end
    if GMGenie_Tickets_View_InlineTitle then
        GMGenie_Tickets_View_InlineTitle:SetText(title);
    end
    if GMGenie_Tickets_InlineTitle then
        GMGenie_Tickets_InlineTitle:SetText(title);
    end
end

function GMGenie.Tickets.prepareDetailPane()
    if GMGenie_Tickets_View then
        GMGenie_Tickets_View:Show();
    end
    if GMGenie_Tickets_View_Sync then
        GMGenie_Tickets_View_Sync:Hide();
    end
    GMGenie.Tickets.applyUnifiedLayout();
    GMGenie.Tickets.updateDetailTitle();
    GMGenie.Tickets.showMessage();
end

function GMGenie.Tickets.applyUnifiedLayout()
    local main = GMGenie_Tickets_Main;
    local view = GMGenie_Tickets_View;
    if not main or not view then
        return;
    end

    main:SetWidth(GMGenie.Tickets.windowWidth);
    main:SetHeight(350);
    GMGenie.Tickets.restoreWindowPosition(main);
    main:SetMovable(true);
    main:EnableMouse(true);
    main:SetClampedToScreen(true);
    main:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            self:StartMoving();
        end
    end);
    main:SetScript("OnMouseUp", function(self)
        self:StopMovingOrSizing();
        GMGenie.Tickets.saveWindowPosition(self);
    end);
    main:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing();
        GMGenie.Tickets.saveWindowPosition(self);
    end);
    GMGenie.loadWindow(main, 'Tickets', true, function() GMGenie.Tickets.refresh(); end);
    local detailWidth = GMGenie.Tickets.windowWidth - 388;

    GMGenie_Tickets_Main_Previous:ClearAllPoints();
    GMGenie_Tickets_Main_Previous:SetPoint("BOTTOMLEFT", main, "BOTTOMLEFT", 2, 1);
    GMGenie_Tickets_Main_Next:ClearAllPoints();
    GMGenie_Tickets_Main_Next:SetPoint("BOTTOMLEFT", main, "BOTTOMLEFT", 329, 1);
    GMGenie_Tickets_Main_Info:ClearAllPoints();
    GMGenie_Tickets_Main_Info:SetPoint("BOTTOMLEFT", main, "BOTTOMLEFT", 60, 9);

    view:SetParent(main);
    view:Show();
    view:SetFrameStrata(main:GetFrameStrata());
    view:SetFrameLevel(main:GetFrameLevel() + 5);
    view:SetMovable(false);
    view:SetScript("OnMouseDown", nil);
    view:SetScript("OnMouseUp", nil);
    view:SetScript("OnDragStop", nil);

    local hiddenFrames = {
        GMGenie_Tickets_View_Title,
        GMGenie_Tickets_View_Close,
        GMGenie_Tickets_View_Refresh,
        GMGenie_Tickets_View_Main,
    };
    for _, subFrame in ipairs(hiddenFrames) do
        if subFrame then
            subFrame:Hide();
        end
    end

    if not GMGenie_Tickets_InlinePane then
        local panel = CreateFrame("Frame", "GMGenie_Tickets_InlinePane", main);
        panel:SetFrameLevel(main:GetFrameLevel() + 1);
        panel:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 12,
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        });
        panel:SetBackdropColor(0.012, 0.028, 0.045, 0.94);
        panel:SetBackdropBorderColor(0.08, 0.38, 0.46, 1);

        local title = panel:CreateFontString("GMGenie_Tickets_InlineTitle", "OVERLAY", "GenieFontHighlightSmall");
        title:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -5);
        title:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -5);
        title:SetJustifyH("CENTER");

        local divider = main:CreateTexture("GMGenie_Tickets_InlineDivider", "BORDER");
        divider:SetTexture(1, 1, 1, 0.08);
        divider:SetWidth(1);
        divider:SetPoint("TOPLEFT", panel, "TOPLEFT", -7, -1);
        divider:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", -7, 1);
    end

    GMGenie_Tickets_InlinePane:ClearAllPoints();
    GMGenie_Tickets_InlinePane:SetPoint("TOPLEFT", main, "TOPLEFT", 371, -19);
    GMGenie_Tickets_InlinePane:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -5, 5);

    view:ClearAllPoints();
    view:SetPoint("TOPLEFT", GMGenie_Tickets_InlinePane, "TOPLEFT", 6, -24);
    view:SetPoint("BOTTOMRIGHT", GMGenie_Tickets_InlinePane, "BOTTOMRIGHT", -6, 4);

    if not GMGenie_Tickets_View_InlineTitle then
        local title = view:CreateFontString("GMGenie_Tickets_View_InlineTitle", "OVERLAY", "GenieFontHighlightSmall");
        title:SetPoint("TOPLEFT", view, "TOPLEFT", 6, -2);
        title:SetPoint("TOPRIGHT", view, "TOPRIGHT", -6, -2);
        title:SetJustifyH("CENTER");
        title:Hide();
    end
    GMGenie_Tickets_View_InlineTitle:Hide();

    if GMGenie_Tickets_View_Ticket then
        GMGenie_Tickets_View_Ticket:ClearAllPoints();
        GMGenie_Tickets_View_Ticket:SetPoint("TOPLEFT", view, "TOPLEFT", 0, 0);
        GMGenie_Tickets_View_Ticket:SetWidth(detailWidth);
    end

    if GMGenie_Tickets_View_Sync then
        GMGenie_Tickets_View_Sync:ClearAllPoints();
        GMGenie_Tickets_View_Sync:SetPoint("TOP", GMGenie_Tickets_View_Ticket, "BOTTOM", 0, -4);
    end

    if GMGenie_Tickets_View_Comment then
        GMGenie_Tickets_View_Comment:ClearAllPoints();
        GMGenie_Tickets_View_Comment:SetPoint("BOTTOMLEFT", view, "BOTTOMLEFT", 0, 33);
        GMGenie_Tickets_View_Comment:SetWidth(detailWidth - 72);
        GMGenie_Tickets_View_Comment:SetHeight(50);
        GMGenie_Tickets_View_Comment:SetTextInsets(5, 5, 5, 5);
    end

    if GMGenie_Tickets_View_SetComment then
        GMGenie_Tickets_View_SetComment:ClearAllPoints();
        GMGenie_Tickets_View_SetComment:SetPoint("LEFT", GMGenie_Tickets_View_Comment, "RIGHT", 4, 0);
        GMGenie_Tickets_View_SetComment:SetWidth(68);
        GMGenie_Tickets_View_SetComment:SetHeight(25);
    end

    local actionButtons = {
        { GMGenie_Tickets_View_Delete,   56 },
        { GMGenie_Tickets_View_Assign,   56 },
        { GMGenie_Tickets_View_Unassign, 58 },
        { GMGenie_Tickets_View_Spy,      46 },
    };

    local previous;
    for index, data in ipairs(actionButtons) do
        local button, width = data[1], data[2];
        if button then
            button:ClearAllPoints();
            button:SetWidth(width);
            button:SetHeight(25);
            if index == 1 then
                button:SetPoint("BOTTOMLEFT", view, "BOTTOMLEFT", 0, 0);
            else
                button:SetPoint("LEFT", previous, "RIGHT", 0, 0);
            end
            previous = button;
        end
    end

    if GMGenie_Tickets_View_Response then
        GMGenie_Tickets_View_Response:ClearAllPoints();
        GMGenie_Tickets_View_Response:SetPoint("BOTTOMRIGHT", view, "BOTTOMRIGHT", 0, 0);
        GMGenie_Tickets_View_Response:SetWidth(64);
        GMGenie_Tickets_View_Response:SetHeight(25);
    end

    if GMGenie_Tickets_View_Ticket then
        GMGenie_Tickets_View_Ticket:SetHeight(184);
        GMGenie.loadEditBox(GMGenie_Tickets_View_Ticket);

        local ticketScrollBar = _G["GMGenie_Tickets_View_Ticket_FrameScrollBar"];
        local ticketScrollUp = _G["GMGenie_Tickets_View_Ticket_FrameScrollBarScrollUpButton"];
        local ticketScrollDown = _G["GMGenie_Tickets_View_Ticket_FrameScrollBarScrollDownButton"];
        if ticketScrollBar then
            ticketScrollBar:ClearAllPoints();
            ticketScrollBar:SetPoint("TOPRIGHT", GMGenie_Tickets_View_Ticket, "TOPRIGHT", 0, -18);
            ticketScrollBar:SetPoint("BOTTOMRIGHT", GMGenie_Tickets_View_Ticket, "BOTTOMRIGHT", 0, 18);
        end

        -- Keep the ticket text clear of the scrollbar and arrow buttons.
        GMGenie.Tickets.applyTicketTextPadding();
        if ticketScrollUp and ticketScrollBar then
            ticketScrollUp:ClearAllPoints();
            ticketScrollUp:SetPoint("BOTTOM", ticketScrollBar, "TOP", 0, 0);
        end
        if ticketScrollDown and ticketScrollBar then
            ticketScrollDown:ClearAllPoints();
            ticketScrollDown:SetPoint("TOP", ticketScrollBar, "BOTTOM", 0, 0);
        end
    end

    GMGenie.Tickets.updateDetailTitle();
end

function GMGenie.Tickets.onLoad()
    GMGenie.Tickets.applyUnifiedLayout();
    Chronos.scheduleRepeating('ticketrefresh', 120, GMGenie.Tickets.refresh);
    GMGenie.Tickets.refresh();
    GMGenie.Tickets.done = GMGenie_SavedVars.ticketsDone;
end

-- refresh ticket list & schedule next refresh
function GMGenie.Tickets.refresh()
    if not GMGenie.Tickets.tempList then
        -- create empty list
        GMGenie.Tickets.tempList = {};
        GMGenie.Tickets.idToNum = {};
        GMGenie.Tickets.tickets = 0;
		GMGenie.Tickets.onlineTickets = 0;
        GMGenie.Tickets.loadingOnline = false;
        -- get ticket list
        SendChatMessage(".ticket list", "GUILD");
        -- schedule next refresh
        Chronos.scheduleByName('ticketreupdate', 3, GMGenie.Tickets.update);
    elseif GMGenie.Tickets.loadingOnline then
        SendChatMessage(".ticket onlinelist", "GUILD");
        Chronos.scheduleByName('ticketreupdate', 3, GMGenie.Tickets.update);
    end
	if GMGenie.Tickets.onlineTickets < 0 then
	GMGenie.Tickets.onlineTickets = 0;
	end
end

-- add ticket from chat list to the addon list
function GMGenie.Tickets.listTicket(ticketId, name, createStr, createStamp, lastModifiedStr, lastModifiedStamp)
    if GMGenie.Archive and GMGenie.Archive.observeId then GMGenie.Archive.observeId("ticket", ticketId); end
    local ticketInfo = { ["ticketId"] = ticketId, ["name"] = name, ["createStr"] = createStr, ["createStamp"] = createStamp, ["lastModifiedStr"] = lastModifiedStr, ["lastModifiedStamp"] = lastModifiedStamp, ["assignedTo"] = "", ['online'] = GMGenie.Tickets.loadingOnline };
    if GMGenie.Tickets.tempList and not GMGenie.Tickets.idToNum[ticketId] and not GMGenie.Tickets.loadingOnline then
        -- add to temp list if page is being refreshed
        table.insert(GMGenie.Tickets.tempList, ticketInfo);
        GMGenie.Tickets.tickets = GMGenie.Tickets.tickets + 1;
        GMGenie.Tickets.idToNum[ticketId] = GMGenie.Tickets.tickets;
    elseif GMGenie.Tickets.tempList and GMGenie.Tickets.loadingOnline then
        GMGenie.Tickets.onlineTickets = GMGenie.Tickets.onlineTickets + 1;
        if GMGenie.Tickets.idToNum[ticketId] then
            GMGenie.Tickets.tempList[GMGenie.Tickets.idToNum[ticketId]] = ticketInfo;
        else
            table.insert(GMGenie.Tickets.tempList, ticketInfo)
            GMGenie.Tickets.tickets = GMGenie.Tickets.tickets + 1;
            GMGenie.Tickets.idToNum[ticketId] = GMGenie.Tickets.tickets;
        end
    end
    -- if no new tickets come in the chat for 1 second, update the list
    Chronos.scheduleByName('ticketreupdate', 0.25, GMGenie.Tickets.update);
end

-- set assignedTo for a ticket
function GMGenie.Tickets.setAssigned(ticketId, assignedTo)
    if not GMGenie.Tickets.applyAssignedState(ticketId, assignedTo) then
        Chronos.schedule(0.2, GMGenie.Tickets.setAssigned, ticketId, assignedTo);
    end
end

-- update ticket list
function GMGenie.Tickets.update()
    -- Check onlines too?
    if not GMGenie.Tickets.loadingOnline then
        GMGenie.Tickets.loadingOnline = true;
        GMGenie.Tickets.refresh();
    else
        GMGenie.Tickets.loadingOnline = false;

        -- move temp list to current list and empty temp list
        if GMGenie.Tickets.tempList then
            GMGenie.Tickets.list = GMGenie.Tickets.tempList;
            GMGenie.Tickets.tempList = nil;
        end
        -- calc number of pages
        if GMGenie_SavedVars.showOfflineTickets then
            GMGenie.Tickets.pages = math.ceil(GMGenie.Tickets.tickets / GMGenie.Tickets.perPage);
        else
            GMGenie.Tickets.pages = math.ceil(GMGenie.Tickets.onlineTickets / GMGenie.Tickets.perPage);
        end
        -- allways at least 1 page
        if GMGenie.Tickets.pages < 1 then
            GMGenie.Tickets.pages = 1;
        end
        -- does the page currently being viewed still exist?
        if GMGenie.Tickets.currentPage > GMGenie.Tickets.pages then
            GMGenie.Tickets.currentPage = GMGenie.Tickets.pages;
        end
        -- order ticket list
        GMGenie.Tickets.sort();
    end
end

-- change ordering for ticket list
function GMGenie.Tickets.changeOrder(order)
    if GMGenie.Tickets.order == order then
        if GMGenie.Tickets.ascDesc then
            GMGenie.Tickets.ascDesc = false;
        else
            GMGenie.Tickets.ascDesc = true;
        end
    else
        GMGenie.Tickets.order = order;
        GMGenie.Tickets.ascDesc = false;
    end
    GMGenie.Tickets.currentPage = 1;
    GMGenie.Tickets.sort();
end

-- order ticket list
function GMGenie.Tickets.sort()
    if GMGenie.Tickets.ascDesc then
        table.sort(GMGenie.Tickets.list, function(a, b) return a[GMGenie.Tickets.order] > b[GMGenie.Tickets.order] end);
    else
        table.sort(GMGenie.Tickets.list, function(a, b) return a[GMGenie.Tickets.order] < b[GMGenie.Tickets.order] end);
    end

    -- update idToNum table
    GMGenie.Tickets.idToNum = {};
    for ticketNum, ticketInfo in ipairs(GMGenie.Tickets.list) do
        GMGenie.Tickets.idToNum[ticketInfo["ticketId"]] = ticketNum;
    end

    -- update the ticket window
    GMGenie.Tickets.updateView();
end

-- update the ticket window
function GMGenie.Tickets.updateView()
    -- Page x of y (z tickets)
    local offlineCount = GMGenie.Tickets.tickets - GMGenie.Tickets.onlineTickets;
	if offlineCount < 0 then
	offlineCount = 0;
	end
    local plural = { ["total"] = "s", ["online"] = "s", ["offline"] = "s" };
    if GMGenie.Tickets.onlineTickets == 1 then
        plural["online"] = "0";
    end
    if offlineCount == 1 then
        plural["offline"] = "0";
    end
    if GMGenie.Tickets.tickets == 1 then
        plural["total"] = "0";
    end

	if GMGenie_Tickets_Main_Info_Text == nil then
		GMGenie_Tickets_Main_Info_Text = ".";
	end

	if (plural["offline"]) == nil then
		plural["offline"] = "0";
	end
	if (plural["total"]) == nil then
		plural["total"] = "0";
	end
	if (plural["online"]) == nil then
		plural["online"] = "0";
	end
	

    GMGenie_Tickets_Main_Info_Text:SetText(GMGenie.Tickets.tickets .. " ticket" .. plural["total"] .. " (|c" .. GMGenie.Tickets.Colours["onlineUnread"] .. GMGenie.Tickets.onlineTickets .. " online,|r |c" .. GMGenie.Tickets.Colours["offlineUnread"] .. offlineCount .. " offline|r), " .. GMGenie.Tickets.done .. " done");
    GMGenie_Tickets_Main_Info_Page:SetText("Page " .. GMGenie.Tickets.currentPage .. " of " .. GMGenie.Tickets.pages);

    GMGenie_Hud_Tickets:SetText("Tickets (|c" .. GMGenie.Tickets.Colours["onlineUnread"] .. GMGenie.Tickets.onlineTickets .. "|r / |c" .. GMGenie.Tickets.Colours["offlineUnread"] .. offlineCount .. "|r)");

    -- previous page
    if (GMGenie.Tickets.currentPage == 1) then
        GMGenie_Tickets_Main_Previous:Disable();
    else
        GMGenie_Tickets_Main_Previous:Enable();
    end

    -- next page
    if (GMGenie.Tickets.currentPage == GMGenie.Tickets.pages) then
        GMGenie_Tickets_Main_Next:Disable();
    else
        GMGenie_Tickets_Main_Next:Enable();
    end

    -- start and end of the list on the current page
    local minTicket = 1 + ((GMGenie.Tickets.currentPage - 1) * GMGenie.Tickets.perPage);
    local maxTicket = GMGenie.Tickets.currentPage * GMGenie.Tickets.perPage;
    local num = 1;
    local i = 0;

    -- reset num
    GMGenie.Tickets.currentTicket["num"] = 0;

    for listIndex = 1, GMGenie.Tickets.perPage do
        local button = getglobal("TicketStatusButton" .. listIndex);
        if button then
            button:UnlockHighlight();
        end
    end

    -- loop through tickets
    for ticketNum, ticketInfo in ipairs(GMGenie.Tickets.list) do
        -- Show ticket?
        if ticketInfo["online"] or GMGenie_SavedVars.showOfflineTickets then
            i = i + 1;
            if i >= minTicket and i <= maxTicket then
                -- colour in list
                local colour;
                if ticketInfo["ticketId"] == GMGenie.Tickets.currentTicket["ticketId"] then
                    colour = GMGenie.Tickets.Colours["current"];
                else
                    if GMGenie.Tickets.read[ticketInfo["ticketId"]] then
                        if ticketInfo["online"] then
                            colour = GMGenie.Tickets.Colours["onlineRead"];
                        else
                            colour = GMGenie.Tickets.Colours["offlineRead"];
                        end
                    else
                        if ticketInfo["online"] then
                            colour = GMGenie.Tickets.Colours["onlineUnread"];
							-- The original package did not include fakr.ogg.
                        else
                            colour = GMGenie.Tickets.Colours["offlineUnread"];
                        end
                    end
                end

                -- set ticket info
                getglobal("TicketStatusButton" .. num .. "_ticketId"):SetText("|c" .. colour .. ticketInfo["ticketId"] .. "|r");
                getglobal("TicketStatusButton" .. num .. "_name"):SetText("|c" .. colour .. ticketInfo["name"] .. "|r");
                getglobal("TicketStatusButton" .. num .. "_createStr"):SetText("|c" .. colour .. ticketInfo["createStr"] .. "|r");
                getglobal("TicketStatusButton" .. num .. "_lastModifiedStr"):SetText("|c" .. colour .. ticketInfo["lastModifiedStr"] .. "|r");
                getglobal("TicketStatusButton" .. num .. "_assignedTo"):SetText("|c" .. colour .. ticketInfo["assignedTo"] .. "|r");
                getglobal("TicketStatusButton" .. num):Show();
                if ticketInfo["ticketId"] == GMGenie.Tickets.currentTicket["ticketId"] then
                    getglobal("TicketStatusButton" .. num):LockHighlight();
                else
                    getglobal("TicketStatusButton" .. num):UnlockHighlight();
                end

                getglobal("TicketStatusButton" .. num).ticketId = ticketInfo["ticketId"];

                -- number on the ticket window
                num = num + 1;
            end
        end
    end
    if num <= GMGenie.Tickets.perPage then
        for num = num, GMGenie.Tickets.perPage do
            getglobal("TicketStatusButton" .. num):Hide();
        end
    end
end

-- next page
function GMGenie.Tickets.goToNext()
    if GMGenie.Tickets.currentPage < GMGenie.Tickets.pages then
        GMGenie.Tickets.currentPage = GMGenie.Tickets.currentPage + 1;
        GMGenie.Tickets.updateView();
    end
end

-- previous page
function GMGenie.Tickets.goToPrevious()
    if GMGenie.Tickets.currentPage > 1 then
        GMGenie.Tickets.currentPage = GMGenie.Tickets.currentPage - 1;
        GMGenie.Tickets.updateView();
    end
end

-- mark ticket as read
function GMGenie.Tickets.markAsRead(ticketId)
    GMGenie.Tickets.read[ticketId] = true;
    GMGenie.Tickets.updateView();
end

-- mark ticket as unread
function GMGenie.Tickets.markAsUnread(ticketId)
    GMGenie.Tickets.ReadTickets[ticketId] = false;
end

function GMGenie.Tickets.isOpen()
    local frame = GMGenie_Tickets_Main;
    if (frame) then
        return frame:IsVisible();
    end
end

-- hide or show ticket window
function GMGenie.Tickets.toggle(showOffline)
    if GMGenie.Tickets.isOpen() then
        -- hide window
        GMGenie_Tickets_Main:Hide();
    else
        if showOffline and not GMGenie_SavedVars.showOfflineTickets then
            GMGenie.Tickets.toggleOfflineTickets();
        end
        -- refresh ticket list and initiate auto-refresh
        GMGenie.Tickets.onLoad();
        -- show window
        GMGenie_Tickets_Main:Show();
        GMGenie.Tickets.prepareDetailPane();
    end
end

-- load ticket
function GMGenie.Tickets.loadTicket(ticketId, num)
    if GMGenie.Notifications then
        GMGenie.Notifications.markSeen("ticket", ticketId);
    end
    if (GMGenie.Tickets.currentTicket["ticketId"] and GMGenie.Tickets.currentTicket["ticketId"] == ticketId) then
        GMGenie.Tickets.markAsRead(ticketId);
        GMGenie.Tickets.updateView();
        return;
    else
        if GMGenie.Tickets.idToNum[ticketId] then
            if GMGenie.Tickets.list[GMGenie.Tickets.idToNum[ticketId]]["name"] then
                -- update current ticket
                GMGenie.Tickets.currentTicket = { ["num"] = num, ["ticketId"] = ticketId, ["name"] = GMGenie.Tickets.list[GMGenie.Tickets.idToNum[ticketId]]["name"], ["comment"] = "", ["message"] = "Loading..." };
                -- set title and loading text
                GMGenie.Tickets.updateDetailTitle();
                GMGenie.Tickets.showMessage();
                -- hide reading frame UNUSED ATM
                --GMGenie_Tickets_View_Ticket_Reading:Hide();
                -- get ticket
                SendChatMessage(".ticket viewid " .. ticketId, "GUILD");
                -- open spy
                if GMGenie_SavedVars.useSpy then
                    GMGenie.Spy.spy(GMGenie.Tickets.currentTicket["name"]);
                end
                -- mark as read
                GMGenie.Tickets.markAsRead(ticketId);
                -- keep the detail pane in the unified ticket window
                GMGenie_Tickets_View:Show();
                if GMGenie_SavedVars.swapTicketWindows and not GMGenie.Tickets.unifiedLayout then
                    GMGenie.Tickets.toggle();
                end
                -- chronos schedule and send message
                Chronos.scheduleRepeating('ticketSync', 30, GMGenie.Tickets.sync);
                GMGenie.Tickets.sync();
                GMGenie.Tickets.displaySync()
                return;
            end
        end
    end
    Chronos.schedule(0.2, GMGenie.Tickets.loadTicket, ticketId, num);
end

function GMGenie.Tickets.displaySync()
    local names = {};
    local num = 0;
    for name, ticketId in pairs(GMGenie.Tickets.syncList) do
        if tonumber(ticketId) == tonumber(GMGenie.Tickets.currentTicket["ticketId"]) then
            table.insert(names, name);
            num = num + 1;
        end
    end

    if num > 0 then
        local text = "";
        for index, name in ipairs(names) do
            text = text .. name;
            if index == (num - 1) then
                text = text .. " and ";
            elseif index < (num - 1) then
                text = text .. ", ";
            end
        end
        GMGenie_Tickets_View_Sync_Names:SetText(text);
        GMGenie_Tickets_View_Ticket:SetHeight(152);
        GMGenie.loadEditBox(GMGenie_Tickets_View_Ticket);
        GMGenie.Tickets.applyTicketTextPadding();
        GMGenie_Tickets_View_Sync:Show();
    else
        GMGenie_Tickets_View_Ticket:SetHeight(184);
        GMGenie.loadEditBox(GMGenie_Tickets_View_Ticket);
        GMGenie.Tickets.applyTicketTextPadding();
        GMGenie_Tickets_View_Sync:Hide();
    end
end

function GMGenie.Tickets.sync()
    SendAddonMessage("GMGenie_Sync", GMGenie.Tickets.currentTicket["ticketId"], "GUILD");
end

function GMGenie.Tickets.syncMessage(name, ticketId)
    -- CHAT_MSG_ADDON can occasionally arrive without a usable sender/message
    -- (and older code relied on the legacy global arg2/arg4 values). Never use
    -- a nil sender as a table key.
    if not name or name == "" or ticketId == nil then
        return;
    end

    -- Sender can be returned as Name-Realm. Ticket sync only needs the player
    -- name and this also keeps the keys stable between server responses.
    name = string.match(name, "^[^-]+") or name;

    local numericTicketId = tonumber(ticketId);
    if numericTicketId ~= nil then
        ticketId = numericTicketId;
    end

    if UnitName("player") ~= name then
        if not (GMGenie.Tickets.syncList[name] and GMGenie.Tickets.syncList[name] == ticketId) then
            GMGenie.Tickets.syncList[name] = ticketId;
            if ticketId == 0 then
                Chronos.unscheduleByName('ticketSync' .. name);
            else
                Chronos.scheduleByName('ticketSync' .. name, 35, GMGenie.Tickets.syncMessage, name, 0);
            end
            GMGenie.Tickets.displaySync();
        else
            Chronos.scheduleByName('ticketSync' .. name, 35, GMGenie.Tickets.syncMessage, name, 0);
        end
    end
end

function GMGenie.Tickets.loadComment(comment)
    GMGenie.Tickets.currentTicket["comment"] = comment;
		GMGenie_Tickets_StatusTemplate_Comment:SetPoint("TOPLEFT", "GMGenie_Tickets_StatusTemplate_Ticket", "BOTTOMLEFT", 0, 0);
		GMGenie_Tickets_StatusTemplate_Comment:SetPoint("BOTTOMRIGHT", "GMGenie_Tickets_StatusTemplate_Response", "TOPLEFT", 0, 0);
		GMGenie_Tickets_StatusTemplate_Comment:SetTextInsets(4,4,4,4);
		GMGenie_Tickets_StatusTemplate_Comment:SetMultiLine();
    GMGenie.Tickets.showMessage();
end

function GMGenie.Tickets.showMessage()
    GMGenie.Tickets.updateDetailTitle();
    GMGenie_Tickets_View_Ticket_Frame_Text:SetText(GMGenie.Tickets.currentTicket["message"] or "");
	GMGenie_Tickets_View_Comment:SetText(GMGenie.Tickets.currentTicket["comment"] or "");
end

function GMGenie.Tickets.close()
    if GMGenie.Spy.currentRequest["name"] == GMGenie.Tickets.currentTicket["name"] then
        GMGenie_Spy_InfoWindow:Hide();
    end
    SendAddonMessage("GMGenie_Sync", "0", "GUILD");
    Chronos.unscheduleRepeating('ticketSync');
    GMGenie.Tickets.currentTicket = { ["num"] = 0, ["ticketId"] = 0, ['name'] = "", ["message"] = "", ["comment"] = "" };
    if GMGenie_Tickets_View_Sync then
        GMGenie_Tickets_View_Sync:Hide();
    end
    if GMGenie_Tickets_Main and GMGenie_Tickets_Main:IsVisible() then
        GMGenie.Tickets.prepareDetailPane();
    end
    if GMGenie_SavedVars.swapTicketWindows and not GMGenie.Tickets.unifiedLayout then
        GMGenie.Tickets.toggle();
    end
    GMGenie.Tickets.updateView();
end

-- read ticket
function GMGenie.Tickets.readTicket(ticketId, message)
    if GMGenie.Tickets.currentTicket["ticketId"] == ticketId then
        GMGenie.Tickets.currentTicket["message"] = message;
        GMGenie.Tickets.showMessage();
        return true;
    end
    return false;
end

-- set comment
function GMGenie.Tickets.comment(ticketId, comment)
    if GMGenie.Tickets.currentTicket["ticketId"] == ticketId then
        GMGenie.Tickets.currentTicket["comment"] = comment;
        GMGenie.Tickets.showMessage();
        return true;
    end
    return false;
end

--add line to ticket
function GMGenie.Tickets.addLine(message)
    local currentTicket = GMGenie.Tickets.currentTicket
    if currentTicket["lastLine"] == message then
      currentTicket["lastLine"] = nil
      return
    end
    currentTicket["lastLine"] = message
    currentTicket["message"] = currentTicket["message"] .. "\n" .. message;
    GMGenie.Tickets.showMessage();
end

function GMGenie.Tickets.delete()
    SendChatMessage(".ticket close " .. GMGenie.Tickets.currentTicket["ticketId"], "GUILD");
    GMGenie.Tickets.done = GMGenie.Tickets.done + 1;
    GMGenie_SavedVars.ticketsDone = GMGenie.Tickets.done;
    local offlineCount = GMGenie.Tickets.tickets - GMGenie.Tickets.onlineTickets;
    GMGenie.Tickets.close();
    GMGenie.Tickets.refresh();
	-- SendChatMessage(".whispers off");
end

function GMGenie.Tickets.assignToSelf()
    local assignee = UnitName("player");
    SendChatMessage(".ticket assign " .. GMGenie.Tickets.currentTicket["ticketId"] .. " " .. assignee, "GUILD");
    GMGenie.Tickets.applyAssignedState(GMGenie.Tickets.currentTicket["ticketId"], assignee);
end

function GMGenie.Tickets.assign()
    GMGenie_Tickets_AssignPopup:Show();
    GMGenie_Tickets_AssignPopup_GMName:SetText("");
end

function GMGenie.Tickets.assignTo()
    GMGenie_Tickets_AssignPopup:Hide();
    local assignee = GMGenie_Tickets_AssignPopup_GMName:GetText();
    SendChatMessage(".ticket assign " .. GMGenie.Tickets.currentTicket["ticketId"] .. " " .. assignee, "GUILD");
    GMGenie.Tickets.applyAssignedState(GMGenie.Tickets.currentTicket["ticketId"], assignee);
end

function GMGenie.Tickets.unassign()
    SendChatMessage(".ticket unassign " .. GMGenie.Tickets.currentTicket["ticketId"], "GUILD");
    GMGenie.Tickets.applyAssignedState(GMGenie.Tickets.currentTicket["ticketId"], "");
end

function GMGenie.Tickets.setComment()
    SendChatMessage(".ticket comment " .. GMGenie.Tickets.currentTicket["ticketId"] .. " " .. GMGenie_Tickets_View_Comment:GetText(), "GUILD");
end

function GMGenie.Tickets.toggleSpy()
    if GMGenie_Spy_InfoWindow:IsVisible() and GMGenie.Tickets.currentTicket["name"] == GMGenie.Spy.currentRequest["name"] then
        GMGenie_Spy_InfoWindow:Hide();
    else
        GMGenie.Spy.spy(GMGenie.Tickets.currentTicket["name"]);
    end
end

function GMGenie.Tickets.respond()
    GMGenie_Tickets_ResponsePopup:Show();
    GMGenie_Tickets_ResponsePopup_Respond:SetText("");
end

function GMGenie.Tickets.responsesend()
	GMGenie.Tickets.appendln();
    SendChatMessage(".ticket response append " .. GMGenie.Tickets.currentTicket["ticketId"] .. " " .. GMGenie_Tickets_ResponsePopup_Respond:GetText(), "GUILD");
	SendChatMessage(".ticket complete " .. GMGenie.Tickets.currentTicket["ticketId"] , "GUILD");
	GMGenie_Tickets_ResponsePopup:Hide();
	GMGenie.Tickets.showMessage();
	SendChatMessage(".ticket comment " .. GMGenie.Tickets.currentTicket["ticketId"] .. " " .. "RESPONSE!");
end

function GMGenie.Tickets.appendln()
	SendChatMessage(".ticket response appendln " .. GMGenie.Tickets.currentTicket["ticketId"] .. " " .. GMGenie_Tickets_ResponsePopup_Respond:GetText(), "GUILD");
	GMGenie_Tickets_ResponsePopup_Respond:SetText("");
end

-- add slash command to open.close ticket widnow
SLASH_TICKETS1 = "/tickets";
SlashCmdList["TICKETS"] = GMGenie.Tickets.toggle;

local frame = CreateFrame("FRAME");
frame:RegisterEvent("CHAT_MSG_ADDON");

function frame:OnEvent(event, prefix, message, channel, sender)
    if event == "CHAT_MSG_ADDON" and (prefix == "GMGenie_TicketSync" or prefix == "GMGenie_Sync") then
        GMGenie.Tickets.syncMessage(sender, message);
    end
end

frame:SetScript("OnEvent", frame.OnEvent);
