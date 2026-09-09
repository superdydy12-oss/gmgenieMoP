-- Server-backed ticket / complaint archive browser for GM Genie (MoP 5.4.8)
-- The server remains authoritative, but successfully read records are cached
-- in SavedVariables so a relog does not require scanning the whole archive again.

GMGenie.Archive = GMGenie.Archive or {};
local Archive = GMGenie.Archive;

Archive.kind = "ticket";
Archive.results = { ticket = {}, complaint = {} };
Archive.resultById = { ticket = {}, complaint = {} };
Archive.currentPage = { ticket = 1, complaint = 1 };
Archive.perPage = 20;
Archive.selected = nil;
Archive.activeRequest = nil;
Archive.scan = nil;
Archive.scanDelay = 0.12;
Archive.requestTimeout = 1.0;
Archive.quietDelay = 0.18;
Archive.frame = nil;
Archive.rows = {};
Archive.autoStarted = { ticket = false, complaint = false };
Archive.resumeNextId = { ticket = nil, complaint = nil };
Archive.highestProbeInProgress = { ticket = false, complaint = false };
Archive.cacheVersion = 2;
Archive.cacheLoaded = false;
Archive.cache = nil;
Archive.pendingResumeAfterIncremental = { ticket = nil, complaint = nil };

-- Private Archive timer queue.  This deliberately does not use
-- Chronos.scheduleByName: Chronos 2.x can throw "invalid key to next" when a
-- named timer is cancelled/rescheduled from inside another named callback.
Archive.timers = {};
Archive.timerSerial = 0;
Archive.timerFrame = CreateFrame("Frame");
Archive.timerFrame:Hide();

function Archive.schedule(name, delay, callback)
    if not name or not callback then return; end
    Archive.timerSerial = Archive.timerSerial + 1;
    Archive.timers[name] = {
        due = GetTime() + (tonumber(delay) or 0),
        callback = callback,
        serial = Archive.timerSerial,
    };
    Archive.timerFrame:Show();
end

function Archive.cancel(name)
    if name then Archive.timers[name] = nil; end
    if not next(Archive.timers) then Archive.timerFrame:Hide(); end
end

Archive.timerFrame:SetScript("OnUpdate", function(self)
    local now = GetTime();
    local due = {};
    for name, timer in pairs(Archive.timers) do
        if timer.due <= now then
            table.insert(due, { name = name, serial = timer.serial, callback = timer.callback });
        end
    end
    for _, item in ipairs(due) do
        local current = Archive.timers[item.name];
        if current and current.serial == item.serial then
            Archive.timers[item.name] = nil;
            item.callback();
        end
    end
    if not next(Archive.timers) then self:Hide(); end
end);

local function trim(s)
    if not s then return ""; end
    s = string.gsub(s, "^%s+", "");
    s = string.gsub(s, "%s+$", "");
    return s;
end

local function stripFormatting(text)
    if not text then return ""; end
    text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "");
    text = string.gsub(text, "|r", "");
    text = string.gsub(text, "|H.-|h(.-)|h", "%1");
    return trim(text);
end

local function escapeForDisplay(text)
    return text or "";
end

local function toNumber(editBox)
    if not editBox then return nil; end
    local value = trim(editBox:GetText() or "");
    if value == "" then return nil; end
    return tonumber(value);
end

local function getAgeSeconds(record)
    if record and record.created and GMGenie.timeStrToSeconds then
        return GMGenie.timeStrToSeconds(record.created);
    end
    return nil;
end

local function lower(text)
    return string.lower(tostring(text or ""));
end

local function copyRecordForCache(record)
    if not record then return nil; end
    local out = {
        kind = record.kind,
        id = tonumber(record.id) or record.id,
        name = record.name,
        subject = record.subject,
        type = record.type,
        createdBy = record.createdBy,
        created = record.created,
        modified = record.modified,
        assigned = record.assigned,
        message = record.message,
        comment = record.comment,
        reportedText = record.reportedText,
        chatLines = {},
    };
    for _, line in ipairs(record.chatLines or {}) do
        table.insert(out.chatLines, line);
    end
    return out;
end

local function cacheId(id)
    local n = tonumber(id);
    return n and tostring(math.floor(n)) or tostring(id or "");
end

function Archive.ensureCache()
    if not GMGenie_SavedVars then return nil; end

    local root = GMGenie_SavedVars.archiveCache;
    if type(root) ~= "table" or tonumber(root.version) ~= Archive.cacheVersion then
        root = { version = Archive.cacheVersion, realms = {} };
        GMGenie_SavedVars.archiveCache = root;
    end
    root.realms = type(root.realms) == "table" and root.realms or {};

    local realmKey = (GetRealmName and GetRealmName()) or "UnknownRealm";
    if not realmKey or realmKey == "" then realmKey = "UnknownRealm"; end
    local cache = root.realms[realmKey];
    if type(cache) ~= "table" then
        cache = {
            ticket = {}, complaint = {},
            missing = { ticket = {}, complaint = {} },
            meta = {
                ticket = { highestId = 0, nextId = nil, complete = false },
                complaint = { highestId = 0, nextId = nil, complete = false },
            },
        };
        root.realms[realmKey] = cache;
    end

    cache.ticket = type(cache.ticket) == "table" and cache.ticket or {};
    cache.complaint = type(cache.complaint) == "table" and cache.complaint or {};
    cache.missing = type(cache.missing) == "table" and cache.missing or {};
    cache.missing.ticket = type(cache.missing.ticket) == "table" and cache.missing.ticket or {};
    cache.missing.complaint = type(cache.missing.complaint) == "table" and cache.missing.complaint or {};
    cache.meta = type(cache.meta) == "table" and cache.meta or {};
    cache.meta.ticket = type(cache.meta.ticket) == "table" and cache.meta.ticket or { highestId = 0, complete = false };
    cache.meta.complaint = type(cache.meta.complaint) == "table" and cache.meta.complaint or { highestId = 0, complete = false };
    cache.realm = realmKey;
    Archive.cache = cache;

    if not Archive.cacheLoaded or Archive.cacheRealm ~= realmKey then
        Archive.results = { ticket = {}, complaint = {} };
        Archive.resultById = { ticket = {}, complaint = {} };
        for _, kind in ipairs({ "ticket", "complaint" }) do
            local highest = tonumber(cache.meta[kind].highestId) or 0;
            for idString, savedRecord in pairs(cache[kind]) do
                if type(savedRecord) == "table" then
                    savedRecord.kind = kind;
                    savedRecord.id = tonumber(savedRecord.id) or tonumber(idString) or savedRecord.id;
                    savedRecord.chatLines = type(savedRecord.chatLines) == "table" and savedRecord.chatLines or {};
                    local id = tonumber(savedRecord.id);
                    if id then
                        Archive.resultById[kind][id] = savedRecord;
                        table.insert(Archive.results[kind], savedRecord);
                        if id > highest then highest = id; end
                    end
                end
            end
            table.sort(Archive.results[kind], function(a, b) return tonumber(a.id) > tonumber(b.id); end);
            cache.meta[kind].highestId = highest;
            Archive.resumeNextId[kind] = tonumber(cache.meta[kind].nextId);
        end
        Archive.cacheRealm = realmKey;
        Archive.cacheLoaded = true;
    end
    return cache;
end

function Archive.persistRecord(record)
    if not record or not record.kind or not record.id then return; end
    local cache = Archive.ensureCache();
    if not cache then return; end
    local kind = record.kind;
    local id = tonumber(record.id);
    if not id or not cache[kind] then return; end
    local key = cacheId(id);
    cache[kind][key] = copyRecordForCache(record);
    cache.missing[kind][key] = nil;
    local meta = cache.meta[kind];
    if id > (tonumber(meta.highestId) or 0) then meta.highestId = id; end
end

function Archive.markMissing(kind, id)
    local cache = Archive.ensureCache();
    id = tonumber(id);
    if not cache or not id or not cache.missing[kind] then return; end
    local key = cacheId(id);
    if not cache[kind][key] then cache.missing[kind][key] = true; end
end

function Archive.getCachedRecord(kind, id)
    local cache = Archive.ensureCache();
    if not cache then return nil, false; end
    local key = cacheId(id);
    return cache[kind][key], cache.missing[kind][key] == true;
end

function Archive.cacheCount(kind)
    Archive.ensureCache();
    return #(Archive.results[kind] or {});
end

function Archive.observeId(kind, id)
    id = tonumber(id);
    if not id or id < 1 or (kind ~= "ticket" and kind ~= "complaint") then return; end
    local cache = Archive.ensureCache();
    if not cache then return; end
    local meta = cache.meta[kind];
    local old = tonumber(meta.highestKnown) or 0;
    if id > old then meta.highestKnown = id; end
end

function Archive.getHighestKnownId(kind)
    local highest = 0;
    local cache = Archive.ensureCache();
    if cache and cache.meta[kind] then
        highest = tonumber(cache.meta[kind].highestKnown) or 0;
    end

    if kind == "ticket" and GMGenie.Tickets then
        for _, ticket in ipairs(GMGenie.Tickets.list or {}) do
            local id = tonumber(ticket.ticketId);
            if id and id > highest then highest = id; end
        end
        local current = GMGenie.Tickets.currentTicket and tonumber(GMGenie.Tickets.currentTicket.ticketId);
        if current and current > highest then highest = current; end
    elseif kind == "complaint" and cmplSys then
        for _, complaint in ipairs(cmplSys.complaints or {}) do
            local id = tonumber(complaint.id);
            if id and id > highest then highest = id; end
        end
        local current = cmplSys.cSelected and tonumber(cmplSys.cSelected.id);
        if current and current > highest then highest = current; end
    end

    if GMGenie.Notifications and GMGenie.Notifications.pending and GMGenie.Notifications.pending[kind] then
        for idString in pairs(GMGenie.Notifications.pending[kind]) do
            local id = tonumber(idString);
            if id and id > highest then highest = id; end
        end
    end

    for _, record in ipairs(Archive.results[kind] or {}) do
        local id = tonumber(record.id);
        if id and id > highest then highest = id; end
    end

    if highest > 0 then Archive.observeId(kind, highest); end
    return highest > 0 and highest or nil;
end

function Archive.recordText(record)
    if not record then return ""; end
    local parts = {
        record.id, record.name, record.subject, record.type, record.createdBy,
        record.created, record.modified, record.assigned, record.message,
        record.comment, record.reportedText
    };
    if record.chatLines then
        for _, line in ipairs(record.chatLines) do
            table.insert(parts, stripFormatting(line));
        end
    end
    local out = {};
    for _, value in ipairs(parts) do
        if value ~= nil then table.insert(out, tostring(value)); end
    end
    return lower(table.concat(out, "\n"));
end

function Archive.matchesFilters(record, filters)
    if not filters then return true; end

    local age = getAgeSeconds(record);
    if filters.minAgeDays and age and age < (filters.minAgeDays * 86400) then
        return false;
    end
    if filters.maxAgeDays and age and age > (filters.maxAgeDays * 86400) then
        return false;
    end

    local needle = lower(trim(filters.text or ""));
    if needle ~= "" and not string.find(Archive.recordText(record), needle, 1, true) then
        return false;
    end
    return true;
end

function Archive.setStatus(text)
    if Archive.statusText then
        Archive.statusText:SetText(text or "");
    end
end

function Archive.savePosition()
    if not Archive.frame or not GMGenie_SavedVars then return; end
    local point, _, relativePoint, x, y = Archive.frame:GetPoint(1);
    if not point then return; end
    GMGenie_SavedVars.archiveWindowPosition = {
        point = point,
        relativePoint = relativePoint or point,
        x = x or 0,
        y = y or 0,
    };
end

function Archive.restorePosition()
    if not Archive.frame then return; end
    local position = GMGenie_SavedVars and GMGenie_SavedVars.archiveWindowPosition;
    Archive.frame:ClearAllPoints();
    if position and position.point then
        Archive.frame:SetPoint(position.point, UIParent, position.relativePoint or position.point, position.x or 0, position.y or 0);
    else
        Archive.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0);
    end
    if ValidateFramePosition then ValidateFramePosition(Archive.frame); end
end

local function createLabel(parent, text, x, y, width)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GenieFontNormalSmall");
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y);
    if width then fs:SetWidth(width); end
    fs:SetJustifyH("LEFT");
    fs:SetText(text or "");
    return fs;
end

local function createInput(parent, x, y, width)
    local edit = CreateFrame("EditBox", nil, parent, "GMGenie_Input_Text");
    edit:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y);
    edit:SetWidth(width);
    edit:SetHeight(20);
    edit:SetAutoFocus(false);
    return edit;
end

local function createButton(parent, text, x, y, width, onClick)
    local button = CreateFrame("Button", nil, parent, "GMGenie_Button");
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y);
    button:SetWidth(width);
    button:SetHeight(22);
    button:SetText(text);
    button:SetScript("OnClick", onClick);
    return button;
end

local function setTabVisual(button, active)
    if not button then return; end
    local fontString = button:GetFontString();
    if active then
        button:SetBackdropBorderColor(1.00, 0.82, 0.10, 1);
        if fontString then fontString:SetTextColor(1.00, 0.82, 0.10, 1); end
    else
        button:SetBackdropBorderColor(0.12, 0.48, 0.58, 1);
        if fontString then fontString:SetTextColor(0.30, 0.90, 1.00, 1); end
    end
end

function Archive.createUI()
    if Archive.frame then return; end

    local frame = CreateFrame("Button", "GMGenie_Archive_Main", UIParent, "GMGenie_Window");
    frame:SetWidth(1040);
    frame:SetHeight(560);
    GMGenie.loadWindow(frame, "Archive", false, nil);
    Archive.frame = frame;

    frame:SetScript("OnMouseDown", function(self) self:StartMoving(); end);
    frame:SetScript("OnMouseUp", function(self)
        self:StopMovingOrSizing();
        Archive.savePosition();
    end);
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing();
        Archive.savePosition();
    end);
    frame:SetScript("OnHide", function() Archive.stopScan(false); end);

    Archive.restorePosition();

    Archive.ticketTab = createButton(frame, "Tickets", 14, -27, 95, function() Archive.setKind("ticket"); end);
    Archive.complaintTab = createButton(frame, "Complaints", 112, -27, 95, function() Archive.setKind("complaint"); end);

    createLabel(frame, "ID:", 225, -31, 22);
    Archive.idInput = createInput(frame, 248, -27, 82);
    Archive.openIdButton = createButton(frame, "Open ID", 334, -27, 76, function() Archive.openExactId(); end);

    createLabel(frame, "Range:", 426, -31, 38);
    Archive.fromInput = createInput(frame, 466, -27, 72);
    createLabel(frame, "to", 543, -31, 16);
    Archive.toInput = createInput(frame, 560, -27, 72);

    createLabel(frame, "Created days ago:", 14, -61, 96);
    Archive.minAgeInput = createInput(frame, 112, -57, 48);
    createLabel(frame, "to", 164, -61, 16);
    Archive.maxAgeInput = createInput(frame, 181, -57, 48);

    createLabel(frame, "Full text:", 245, -61, 50);
    Archive.textInput = createInput(frame, 299, -57, 265);
    Archive.scanButton = createButton(frame, "Scan", 570, -57, 62, function() Archive.startScan(); end);
    Archive.stopButton = createButton(frame, "Stop", 636, -57, 62, function() Archive.stopScan(true); end);
    Archive.clearButton = createButton(frame, "Clear Cache", 702, -57, 78, function() Archive.clearResults(); end);

    Archive.statusText = frame:CreateFontString(nil, "OVERLAY", "GenieFontNormalSmall");
    Archive.statusText:SetPoint("TOPLEFT", frame, "TOPLEFT", 796, -31);
    Archive.statusText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -18, -31);
    Archive.statusText:SetHeight(45);
    Archive.statusText:SetJustifyH("LEFT");
    Archive.statusText:SetJustifyV("TOP");
    Archive.statusText:SetText("Server-backed archive with persistent local cache. First scan reads the server; later logins load cached records immediately and scan only unfinished/new IDs.");

    -- Result table headers.
    Archive.headers = {};
    local headerX = { 14, 68, 168, 253, 421 };
    local headerW = { 51, 97, 82, 165, 90 };
    for i = 1, 5 do
        local b = CreateFrame("Button", nil, frame, "GMGenie_LeftButton");
        b:SetPoint("TOPLEFT", frame, "TOPLEFT", headerX[i], -91);
        b:SetWidth(headerW[i]);
        b:SetHeight(18);
        Archive.headers[i] = b;
    end

    -- Twenty rows, ticket-style hover and selection.
    for rowIndex = 1, Archive.perPage do
        local row = CreateFrame("Button", "GMGenie_Archive_Row" .. rowIndex, frame);
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -110 - ((rowIndex - 1) * 18));
        row:SetWidth(485);
        row:SetHeight(18);
        row:RegisterForClicks("LeftButtonUp");
        row:SetHighlightTexture("Interface\\FriendsFrame\\UI-FriendsFrame-HighlightBar", "ADD");
        row.cols = {};
        local widths = { 51, 97, 82, 165, 90 };
        local x = 3;
        for col = 1, 5 do
            local fs = row:CreateFontString(nil, "OVERLAY", "GenieFontNormalSmall");
            fs:SetPoint("LEFT", row, "LEFT", x, 0);
            fs:SetWidth(widths[col] - 5);
            fs:SetJustifyH("LEFT");
            row.cols[col] = fs;
            x = x + widths[col];
        end
        row:SetScript("OnClick", function(self)
            if self.record then Archive.selectRecord(self.record); end
        end);
        Archive.rows[rowIndex] = row;
    end

    Archive.prevButton = CreateFrame("Button", nil, frame, "GMGenie_PreviousButton");
    Archive.prevButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 7);
    Archive.prevButton:SetScript("OnClick", function() Archive.previousPage(); end);
    Archive.nextButton = CreateFrame("Button", nil, frame, "GMGenie_NextButton");
    Archive.nextButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 460, 7);
    Archive.nextButton:SetScript("OnClick", function() Archive.nextPage(); end);
    Archive.pageText = frame:CreateFontString(nil, "OVERLAY", "GenieFontNormalSmall");
    Archive.pageText:SetPoint("BOTTOM", frame, "BOTTOMLEFT", 260, 14);
    Archive.pageText:SetWidth(320);
    Archive.pageText:SetJustifyH("CENTER");

    -- Right-hand detail panel.
    Archive.detailPane = CreateFrame("Frame", nil, frame);
    Archive.detailPane:SetPoint("TOPLEFT", frame, "TOPLEFT", 506, -88);
    Archive.detailPane:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12);
    Archive.detailPane:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 12, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    });
    Archive.detailPane:SetBackdropColor(0.012, 0.028, 0.045, 0.94);
    Archive.detailPane:SetBackdropBorderColor(0.08, 0.38, 0.46, 1);

    Archive.detailTitle = Archive.detailPane:CreateFontString(nil, "OVERLAY", "GenieFontHighlightSmall");
    Archive.detailTitle:SetPoint("TOPLEFT", Archive.detailPane, "TOPLEFT", 8, -7);
    Archive.detailTitle:SetPoint("TOPRIGHT", Archive.detailPane, "TOPRIGHT", -8, -7);
    Archive.detailTitle:SetHeight(18);
    Archive.detailTitle:SetJustifyH("CENTER");
    Archive.detailTitle:SetText("Select an archived record");

    Archive.detailMeta = Archive.detailPane:CreateFontString(nil, "OVERLAY", "GenieFontNormalSmall");
    Archive.detailMeta:SetPoint("TOPLEFT", Archive.detailPane, "TOPLEFT", 10, -29);
    Archive.detailMeta:SetPoint("TOPRIGHT", Archive.detailPane, "TOPRIGHT", -10, -29);
    Archive.detailMeta:SetHeight(36);
    Archive.detailMeta:SetJustifyH("LEFT");
    Archive.detailMeta:SetJustifyV("TOP");

    Archive.detailBox = CreateFrame("Frame", nil, Archive.detailPane);
    Archive.detailBox:SetPoint("TOPLEFT", Archive.detailPane, "TOPLEFT", 7, -68);
    Archive.detailBox:SetPoint("BOTTOMRIGHT", Archive.detailPane, "BOTTOMRIGHT", -7, 7);
    Archive.detailBox:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 12, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    });
    Archive.detailBox:SetBackdropColor(0.012, 0.028, 0.045, 0.98);
    Archive.detailBox:SetBackdropBorderColor(0.08, 0.38, 0.46, 1);

    Archive.detailMessage = CreateFrame("ScrollingMessageFrame", nil, Archive.detailBox);
    Archive.detailMessage:SetPoint("TOPLEFT", Archive.detailBox, "TOPLEFT", 7, -7);
    Archive.detailMessage:SetPoint("BOTTOMRIGHT", Archive.detailBox, "BOTTOMRIGHT", -28, 7);
    Archive.detailMessage:SetFontObject(ChatFontNormal);
    Archive.detailMessage:SetTextColor(1, 1, 1, 1);
    Archive.detailMessage:SetJustifyH("LEFT");
    Archive.detailMessage:SetHyperlinksEnabled(true);
    Archive.detailMessage:SetFading(false);
    Archive.detailMessage:SetMaxLines(1000);
    Archive.detailMessage:EnableMouseWheel(true);

    Archive.detailScroll = CreateFrame("Slider", "GMGenie_Archive_DetailScroll", Archive.detailBox, "UIPanelScrollBarTemplate");
    Archive.detailScroll:SetPoint("TOPRIGHT", Archive.detailBox, "TOPRIGHT", 0, -18);
    Archive.detailScroll:SetPoint("BOTTOMRIGHT", Archive.detailBox, "BOTTOMRIGHT", 0, 18);
    Archive.detailScroll:SetMinMaxValues(0, 0);
    Archive.detailScroll:SetValueStep(1);
    Archive.detailScroll.scrollStep = 1;
    Archive.detailScroll:SetScript("OnValueChanged", function(self, value)
        Archive.detailMessage:SetScrollOffset(value);
    end);
    Archive.detailMessage:SetScript("OnMouseWheel", function(self, delta)
        local maxScroll = math.max(0, self:GetNumMessages() - self:GetNumLinesDisplayed());
        local current = Archive.detailScroll:GetValue();
        if delta < 0 then
            current = math.min(maxScroll, current + 1);
        else
            current = math.max(0, current - 1);
        end
        Archive.detailScroll:SetMinMaxValues(0, maxScroll);
        Archive.detailScroll:SetValue(current);
    end);

    Archive.ensureCache();
    Archive.setKind("ticket");
    Archive.updateRows();
end

function Archive.toggle()
    Archive.ensureCache();
    Archive.createUI();
    if Archive.frame:IsShown() then
        Archive.frame:Hide();
    else
        Archive.restorePosition();
        Archive.frame:Show();
        Archive.updateRows();
        Archive.setStatus("Loaded " .. Archive.cacheCount(Archive.kind) .. " cached " .. Archive.kind .. " record(s). Checking for new or unfinished IDs...");
        Archive.schedule("GMGenieArchiveAutoStart", 0.05, function()
            if Archive.frame and Archive.frame:IsShown() then Archive.startAutoScan(Archive.kind); end
        end);
    end
end

local function ArchiveApplyTableLayout(kind)
    local headerX, headerW
    if kind == "complaint" then
        headerX = { 14, 68, 168, 253 }
        headerW = { 51, 97, 82, 250 }
    else
        headerX = { 14, 68, 168, 253, 421 }
        headerW = { 51, 97, 82, 165, 90 }
    end

    for i = 1, 5 do
        local header = Archive.headers and Archive.headers[i]
        if header then
            if headerX[i] then
                header:ClearAllPoints()
                header:SetPoint("TOPLEFT", Archive.frame, "TOPLEFT", headerX[i], -91)
                header:SetWidth(headerW[i])
                header:Show()
            else
                header:Hide()
            end
        end
    end

    for rowIndex = 1, Archive.perPage do
        local row = Archive.rows and Archive.rows[rowIndex]
        if row and row.cols then
            local x = 3
            for col = 1, 5 do
                local fs = row.cols[col]
                if headerW[col] then
                    fs:ClearAllPoints()
                    fs:SetPoint("LEFT", row, "LEFT", x, 0)
                    fs:SetWidth(headerW[col] - 5)
                    fs:Show()
                    x = x + headerW[col]
                else
                    fs:SetText("")
                    fs:Hide()
                end
            end
        end
    end
end

function Archive.setKind(kind)
    if kind ~= "ticket" and kind ~= "complaint" then return; end
    if Archive.scan and Archive.scan.running and Archive.scan.kind ~= kind then
        Archive.stopScan(false);
        Archive.setStatus("Scan stopped because the archive tab changed.");
    end
    Archive.kind = kind;
    Archive.selected = nil;
    ArchiveApplyTableLayout(kind);
    setTabVisual(Archive.ticketTab, kind == "ticket");
    setTabVisual(Archive.complaintTab, kind == "complaint");
    if Archive.headers then
        if kind == "ticket" then
            Archive.headers[1]:SetText("#");
            Archive.headers[2]:SetText("Name");
            Archive.headers[3]:SetText("Created");
            Archive.headers[4]:SetText("Modified");
            Archive.headers[5]:SetText("Assigned To");
        else
            Archive.headers[1]:SetText("#");
            Archive.headers[2]:SetText("Name");
            Archive.headers[3]:SetText("Type");
            Archive.headers[4]:SetText("Created");
        end
    end
    Archive.detailTitle:SetText("Select an archived " .. kind);
    Archive.detailMeta:SetText("");
    Archive.detailMessage:Clear();
    Archive.updateRows();
    if Archive.frame and Archive.frame:IsShown() then
        Archive.schedule("GMGenieArchiveAutoStart", 0.05, function()
            if Archive.frame and Archive.frame:IsShown() and Archive.kind == kind then Archive.startAutoScan(kind); end
        end);
    end
end

function Archive.addResult(record, skipPersist)
    if not record or not record.id or not record.kind then return; end
    Archive.ensureCache();
    local id = tonumber(record.id) or record.id;
    Archive.observeId(record.kind, id);
    record.id = id;
    if not skipPersist then Archive.persistRecord(record); end
    local existing = Archive.resultById[record.kind][id];
    if existing then
        for key, value in pairs(record) do existing[key] = value; end
    else
        Archive.resultById[record.kind][id] = record;
        table.insert(Archive.results[record.kind], record);
        table.sort(Archive.results[record.kind], function(a, b)
            return tonumber(a.id) > tonumber(b.id);
        end);
    end
    Archive.updateRows();
end

function Archive.clearResults()
    local kind = Archive.kind;
    local cache = Archive.ensureCache();
    if cache then
        cache[kind] = {};
        cache.missing[kind] = {};
        cache.meta[kind] = { highestId = 0, nextId = nil, complete = false };
    end
    Archive.results[kind] = {};
    Archive.resultById[kind] = {};
    Archive.currentPage[kind] = 1;
    Archive.resumeNextId[kind] = nil;
    Archive.autoStarted[kind] = false;
    Archive.selected = nil;
    Archive.detailTitle:SetText("Select an archived " .. kind);
    Archive.detailMeta:SetText("");
    Archive.detailMessage:Clear();
    Archive.setStatus("Local " .. kind .. " cache cleared. Server data was not changed; reopening this tab will rebuild it.");
    Archive.updateRows();
end

function Archive.updateRows()
    if not Archive.frame then return; end
    local list = Archive.results[Archive.kind];
    local pages = math.max(1, math.ceil(#list / Archive.perPage));
    local page = Archive.currentPage[Archive.kind] or 1;
    if page > pages then page = pages; Archive.currentPage[Archive.kind] = page; end
    if page < 1 then page = 1; Archive.currentPage[Archive.kind] = 1; end

    local startIndex = ((page - 1) * Archive.perPage) + 1;
    for i = 1, Archive.perPage do
        local row = Archive.rows[i];
        local record = list[startIndex + i - 1];
        row:UnlockHighlight();
        if record then
            row.record = record;
            local values;
            if Archive.kind == "ticket" then
                values = { record.id, record.name, record.created, record.modified, record.assigned };
            else
                local created = tostring(record.created or "");
                if record.createdBy and record.createdBy ~= "" then created = created .. " - " .. record.createdBy; end
                values = { record.id, record.subject, record.type, created };
            end
            for c = 1, 5 do row.cols[c]:SetText(tostring(values[c] or "")); end
            row:Show();
            if Archive.selected == record then row:LockHighlight(); end
        else
            row.record = nil;
            for c = 1, 5 do row.cols[c]:SetText(""); end
            row:Hide();
        end
    end

    Archive.pageText:SetText(#list .. " result" .. (#list == 1 and "" or "s") .. "   Page " .. page .. " of " .. pages);
    if page <= 1 then Archive.prevButton:Disable(); else Archive.prevButton:Enable(); end
    if page >= pages then Archive.nextButton:Disable(); else Archive.nextButton:Enable(); end
end

function Archive.previousPage()
    if Archive.currentPage[Archive.kind] > 1 then
        Archive.currentPage[Archive.kind] = Archive.currentPage[Archive.kind] - 1;
        Archive.updateRows();
    end
end

function Archive.nextPage()
    local pages = math.max(1, math.ceil(#Archive.results[Archive.kind] / Archive.perPage));
    if Archive.currentPage[Archive.kind] < pages then
        Archive.currentPage[Archive.kind] = Archive.currentPage[Archive.kind] + 1;
        Archive.updateRows();
    end
end

function Archive.selectRecord(record)
    Archive.selected = record;
    Archive.updateRows();
    Archive.detailMessage:Clear();
    Archive.detailScroll:SetValue(0);

    if record.kind == "ticket" then
        Archive.detailTitle:SetText((record.name or "Unknown") .. "'s Ticket #" .. tostring(record.id));
        local meta = "Created: " .. tostring(record.created or "?") .. " ago";
        if record.modified and record.modified ~= "" then meta = meta .. "   Modified: " .. record.modified .. " ago"; end
        if record.assigned and record.assigned ~= "" then meta = meta .. "   Assigned to: " .. record.assigned; end
        Archive.detailMeta:SetText(meta);
        if record.message and record.message ~= "" then Archive.detailMessage:AddMessage(record.message); end
        if record.comment and record.comment ~= "" then
            Archive.detailMessage:AddMessage(" ");
            Archive.detailMessage:AddMessage("|cffffd200GM Comment:|r " .. record.comment);
        end
    else
        Archive.detailTitle:SetText((record.subject or "Unknown") .. "'s Complaint #" .. tostring(record.id));
        local meta = "Type: " .. tostring(record.type or "?") .. "   Created: " .. tostring(record.created or "?") .. " ago";
        if record.createdBy and record.createdBy ~= "" then meta = meta .. "   Created by: " .. record.createdBy; end
        Archive.detailMeta:SetText(meta);
        if record.reportedText and record.reportedText ~= "" then
            Archive.detailMessage:AddMessage("|cffffd200Reported message:|r " .. record.reportedText);
        end
        for _, line in ipairs(record.chatLines or {}) do Archive.detailMessage:AddMessage(line); end
        if record.comment and record.comment ~= "" then
            Archive.detailMessage:AddMessage(" ");
            Archive.detailMessage:AddMessage("|cffffd200GM Comment:|r " .. record.comment);
        end
    end

    local maxScroll = math.max(0, Archive.detailMessage:GetNumMessages() - Archive.detailMessage:GetNumLinesDisplayed());
    Archive.detailScroll:SetMinMaxValues(0, maxScroll);
end

function Archive.getFilters()
    local minAge = toNumber(Archive.minAgeInput);
    local maxAge = toNumber(Archive.maxAgeInput);
    if minAge and maxAge and minAge > maxAge then minAge, maxAge = maxAge, minAge; end
    return {
        minAgeDays = minAge,
        maxAgeDays = maxAge,
        text = Archive.textInput and Archive.textInput:GetText() or "",
    };
end

function Archive.openExactId()
    local id = toNumber(Archive.idInput);
    if not id then
        Archive.setStatus("Enter a numeric ID first.");
        return;
    end
    local kind = Archive.kind;
    Archive.stopScan(false);

    local cached, knownMissing = Archive.getCachedRecord(kind, id);
    if cached then
        Archive.addResult(cached, true);
        if Archive.kind == kind then Archive.selectRecord(cached); end
        Archive.setStatus("Loaded " .. kind .. " #" .. id .. " from local archive cache.");
        return;
    elseif knownMissing then
        Archive.setStatus((kind == "ticket" and "Ticket" or "Complaint") .. " #" .. id .. " is known as not found in the local cache.");
        return;
    end

    Archive.setStatus("Loading " .. kind .. " #" .. id .. " from server...");
    Archive.request(kind, id, true, function(record, found, reason)
        if found and record then
            Archive.addResult(record);
            if Archive.kind == kind then Archive.selectRecord(record); end
            Archive.setStatus("Loaded " .. kind .. " #" .. id .. " from server and saved it to the local cache.");
        elseif reason == "notfound" then
            Archive.setStatus((kind == "ticket" and "Ticket" or "Complaint") .. " #" .. id .. " not found.");
        else
            Archive.setStatus("No usable server reply for " .. kind .. " #" .. id .. ".");
        end
    end);
end

function Archive.startScan(fromOverride, toOverride, isAuto, autoMode)
    local fromId = tonumber(fromOverride) or toNumber(Archive.fromInput);
    local toId = tonumber(toOverride) or toNumber(Archive.toInput);

    if not fromId then fromId = Archive.getHighestKnownId(Archive.kind); end
    if not toId then toId = 1; end

    if not fromId then
        Archive.setStatus("No current " .. Archive.kind .. " ID is known yet. Open/refresh the live list or enter a From ID manually.");
        return;
    end

    if fromId < 1 then fromId = 1; end
    if toId < 1 then toId = 1; end
    Archive.observeId(Archive.kind, fromId);

    if Archive.fromInput then Archive.fromInput:SetText(tostring(fromId)); end
    if Archive.toInput then Archive.toInput:SetText(tostring(toId)); end

    Archive.stopScan(false);
    if not isAuto then
        Archive.results[Archive.kind] = {};
        Archive.resultById[Archive.kind] = {};
        Archive.currentPage[Archive.kind] = 1;
    end
    Archive.selected = nil;
    Archive.detailMessage:Clear();
    Archive.detailMeta:SetText("");
    Archive.detailTitle:SetText("Scanning server archive...");

    local step = fromId <= toId and 1 or -1;
    Archive.scan = {
        running = true,
        kind = Archive.kind,
        nextId = fromId,
        toId = toId,
        step = step,
        checked = 0,
        found = 0,
        matched = 0,
        filters = Archive.getFilters(),
        auto = isAuto == true,
        autoMode = autoMode,
        fromId = fromId,
    };
    Archive.resumeNextId[Archive.kind] = fromId;
    if isAuto then
        local cache = Archive.ensureCache();
        if cache then
            cache.meta[Archive.kind].nextId = fromId;
            if autoMode == "full" then
                cache.meta[Archive.kind].highestId = math.max(tonumber(cache.meta[Archive.kind].highestId) or 0, fromId);
            end
        end
    end
    Archive.autoStarted[Archive.kind] = Archive.autoStarted[Archive.kind] or (isAuto == true);
    Archive.setStatus((isAuto and "Auto-scanning " or "Scanning ") .. Archive.kind .. " IDs from #" .. fromId .. " to #" .. toId .. ". Results appear progressively.");
    Archive.scanNext();
end

function Archive.startAutoScan(kind)
    kind = kind or Archive.kind;
    if kind ~= Archive.kind then return; end
    if Archive.scan and Archive.scan.running then return; end
    local cache = Archive.ensureCache();
    if not cache then return; end

    local highest = Archive.getHighestKnownId(kind);
    if not highest then
        if not Archive.highestProbeInProgress[kind] then
            Archive.highestProbeInProgress[kind] = true;
            Archive.setStatus("Loaded " .. Archive.cacheCount(kind) .. " cached record(s). Finding the newest known " .. kind .. " ID from the live list...");
            if kind == "ticket" and GMGenie.Tickets and GMGenie.Tickets.refresh then
                GMGenie.Tickets.refresh();
            elseif kind == "complaint" and getComplaintList then
                getComplaintList();
            end
            Archive.schedule("GMGenieArchiveHighestRetry", 1.5, function()
                Archive.highestProbeInProgress[kind] = false;
                if Archive.frame and Archive.frame:IsShown() and Archive.kind == kind then Archive.startAutoScan(kind); end
            end);
        end
        return;
    end
    Archive.highestProbeInProgress[kind] = false;

    local meta = cache.meta[kind];
    local cachedHighest = tonumber(meta.highestId) or 0;
    local resume = tonumber(meta.nextId) or Archive.resumeNextId[kind];

    if not meta.complete and resume and highest > cachedHighest then
        Archive.pendingResumeAfterIncremental[kind] = resume;
        Archive.startScan(highest, cachedHighest + 1, true, "incremental");
        return;
    end

    if not meta.complete then
        local startId = resume or highest;
        if startId < 1 then return; end
        Archive.startScan(startId, 1, true, resume and "resume" or "full");
        return;
    end

    if highest > cachedHighest then
        Archive.startScan(highest, cachedHighest + 1, true, "incremental");
    else
        Archive.resumeNextId[kind] = nil;
        Archive.setStatus("Archive cache is up to date: " .. Archive.cacheCount(kind) .. " " .. kind .. " record(s) loaded locally.");
    end
end

function Archive.scanNext()
    local scan = Archive.scan;
    if not scan or not scan.running then return; end
    local id = scan.nextId;
    if (scan.step > 0 and id > scan.toId) or (scan.step < 0 and id < scan.toId) then
        scan.running = false;
        Archive.resumeNextId[scan.kind] = nil;
        local cache = Archive.ensureCache();
        if scan.auto and cache then
            local meta = cache.meta[scan.kind];
            meta.nextId = nil;
            if scan.autoMode == "full" or scan.autoMode == "resume" then
                if scan.toId == 1 then meta.complete = true; end
                meta.highestId = math.max(tonumber(meta.highestId) or 0, tonumber(scan.fromId) or 0);
            elseif scan.autoMode == "incremental" then
                meta.highestId = math.max(tonumber(meta.highestId) or 0, tonumber(scan.fromId) or 0);
            end
        end
        Archive.setStatus("Scan complete: " .. scan.checked .. " IDs checked, " .. scan.found .. " existing, " .. scan.matched .. " matched. Cache contains " .. Archive.cacheCount(scan.kind) .. " record(s).");

        local resume = Archive.pendingResumeAfterIncremental[scan.kind];
        if scan.autoMode == "incremental" and resume and resume >= 1 then
            Archive.pendingResumeAfterIncremental[scan.kind] = nil;
            Archive.schedule("GMGenieArchiveResume", 0.05, function()
                if Archive.frame and Archive.frame:IsShown() and Archive.kind == scan.kind then
                    Archive.startScan(resume, 1, true, "resume");
                end
            end);
        end
        return;
    end

    if scan.checked == 0 or (scan.checked % 5) == 0 then
        Archive.setStatus("Scanning " .. scan.kind .. " #" .. id .. " ...   Checked: " .. scan.checked .. "   Found: " .. scan.matched);
    end

    local function process(record, found, reason)
        if not Archive.scan or not Archive.scan.running then return; end
        local s = Archive.scan;
        s.checked = s.checked + 1;
        if found and record then
            s.found = s.found + 1;
            Archive.persistRecord(record);
            if Archive.matchesFilters(record, s.filters) then
                s.matched = s.matched + 1;
                Archive.addResult(record, true);
            end
        elseif reason == "notfound" then
            Archive.markMissing(s.kind, id);
        end
        s.nextId = id + s.step;
        Archive.resumeNextId[s.kind] = s.nextId;
        if s.auto then
            local cache = Archive.ensureCache();
            if cache then cache.meta[s.kind].nextId = s.nextId; end
        end
        if found then
            Archive.setStatus("Scanning " .. s.kind .. " #" .. id .. " ...   Checked: " .. s.checked .. "   Found: " .. s.matched);
        end
        Archive.schedule("GMGenieArchiveNext", Archive.scanDelay, Archive.scanNext);
    end

    local cached, knownMissing = Archive.getCachedRecord(scan.kind, id);
    if cached then
        process(cached, true, "cache");
    elseif knownMissing then
        process(nil, false, "notfound");
    else
        Archive.request(scan.kind, id, false, process);
    end
end

function Archive.stopScan(showStatus)
    Archive.cancel("GMGenieArchiveNext");
    Archive.cancel("GMGenieArchiveTimeout");
    Archive.cancel("GMGenieArchiveQuiet");
    Archive.cancel("GMGenieArchiveAutoStart");
    Archive.cancel("GMGenieArchiveHighestRetry");
    Archive.cancel("GMGenieArchiveResume");
    if Archive.scan then
        Archive.resumeNextId[Archive.scan.kind] = Archive.scan.nextId;
        if Archive.scan.auto then
            local cache = Archive.ensureCache();
            if cache then cache.meta[Archive.scan.kind].nextId = Archive.scan.nextId; end
        end
        Archive.scan.running = false;
    end
    Archive.scan = nil;
    Archive.activeRequest = nil;
    if showStatus then Archive.setStatus("Scan stopped. Progress is saved locally; reopening the tab will continue from the last checked ID."); end
end

function Archive.request(kind, id, exact, callback)
    if Archive.activeRequest then
        Archive.finishRequest(false, "superseded");
    end
    local req = {
        kind = kind,
        id = tonumber(id),
        exact = exact,
        callback = callback,
        found = false,
        rawSeen = {},
        chatSeen = {},
        record = { kind = kind, id = tonumber(id), chatLines = {} },
        ticketMessageOpen = false,
        expectPlayerSubject = false,
    };
    Archive.activeRequest = req;

    if kind == "ticket" then
        SendChatMessage(".ticket viewid " .. id, "GUILD");
    else
        SendChatMessage(".complaint view " .. id, "GUILD");
    end
    Archive.schedule("GMGenieArchiveTimeout", Archive.requestTimeout, function()
        if Archive.activeRequest == req then Archive.finishRequest(req.found, req.found and "timeout_after_data" or "timeout"); end
    end);
end

function Archive.touchRequest()
    Archive.cancel("GMGenieArchiveQuiet");
    Archive.schedule("GMGenieArchiveQuiet", Archive.quietDelay, function()
        if Archive.activeRequest and Archive.activeRequest.found then
            Archive.finishRequest(true, "complete");
        end
    end);
end

function Archive.finishRequest(found, reason)
    local req = Archive.activeRequest;
    if not req then return; end
    Archive.activeRequest = nil;
    Archive.cancel("GMGenieArchiveTimeout");
    Archive.cancel("GMGenieArchiveQuiet");
    if found and req.record then Archive.persistRecord(req.record); end
    if req.callback then req.callback(found and req.record or nil, found, reason); end
end

local function parseTicketHeader(req, msg)
    local ticketId, name, createStr, lastModifiedStr, rest = string.match(msg,
        "^%|cffaaffaaTicket%|r:%|cffaaccff%s([0-9]+).%|r%s%|cff00ff00Created%sby%|r:%|cff00ccff%s(.+)%|r%s%|cff00ff00Created%|r:%|cff00ccff%s([a-zA-Z0-9%s]+)%sago%|r%s%|cff00ff00Last%schange%|r:%|cff00ccff%s([a-zA-Z0-9%s]+)%sago%|r%s(.*)$");
    if not ticketId or tonumber(ticketId) ~= req.id then return false; end

    req.found = true;
    req.record.name = name;
    req.record.created = trim(createStr);
    req.record.modified = trim(lastModifiedStr);
    req.record.assigned = string.match(rest or "", "%|cff00ff00Assigned%sto%|r:%|cff00ccff%s([a-zA-Z]+)%|r") or "";

    local message = string.match(rest or "", "%|cff00ff00Ticket%sMessage%|r:%s%[(.-)%]%|r");
    if message then
        req.record.message = message;
        req.ticketMessageOpen = false;
    else
        message = string.match(rest or "", "%|cff00ff00Ticket%sMessage%|r:%s%[(.*)");
        if message then
            req.record.message = message;
            req.ticketMessageOpen = true;
        end
    end
    local comment = string.match(rest or "", "%|cff00ff00GM%sComment%|r:%s%[(.*)%]%|r");
    if comment then req.record.comment = comment; end
    return true;
end

local complaintListPattern = "|cffaaffaaComplaint|r:|cffaaccff (%d+).|r |cff00ff00Type|r:|cffffaa00 (.+)|r |cff00ff00Subject|r:|cffff4444(.+)|r |cff00ff00Created by|r:|cff00ccff(.+)|r |cff00ff00Created|r:|cff00ccff (%d*%a*%d*%a*%d*%a*%d*%a*) ago|r";
local complaintChatPattern = "|(.+)%((%a*)%) %- %[(.+) (.+)%] |r(.-)%[(.-)%].+%((%d+)%) (%a*)%-?[%a()]*%]: (.+)";

local function parseComplaintHeader(req, msg)
    local _, _, id, complaintType, subject, createdBy, created = msg:find(complaintListPattern);
    if not id or tonumber(id) ~= req.id then return false; end
    req.found = true;
    req.record.type = trim(complaintType);
    req.record.subject = trim(subject);
    req.record.createdBy = trim(createdBy);
    req.record.created = trim(created);
    req.record.comment = string.match(msg, "|cff00ff00GM Comment|r:|cffff66cc .(.+).|r ") or "";
    req.record.assigned = string.match(msg, "|cff00ff00Assigned To|r:|cff00ccff (%a+)|r") or "";
    return true;
end

function Archive.capture(msg)
    local req = Archive.activeRequest;
    if not req or not msg then return false; end

    -- The handler may be called for multiple chat frames. Process a given raw
    -- server line only once, but still hide duplicate copies from chat.
    if req.rawSeen[msg] then return true; end

    local plain = lower(stripFormatting(msg));
    if req.kind == "ticket" and string.find(plain, "ticket not found", 1, true) then
        req.rawSeen[msg] = true;
        Archive.markMissing(req.kind, req.id);
        Archive.finishRequest(false, "notfound");
        return true;
    elseif req.kind == "complaint" and
        ((string.find(plain, "complaint not found", 1, true)) or
         (string.find(plain, "complaint", 1, true) and string.find(plain, "not found", 1, true))) then
        req.rawSeen[msg] = true;
        Archive.markMissing(req.kind, req.id);
        Archive.finishRequest(false, "notfound");
        return true;
    end

    if req.kind == "ticket" then
        if parseTicketHeader(req, msg) then
            req.rawSeen[msg] = true;
            Archive.touchRequest();
            return true;
        end
        if req.ticketMessageOpen then
            req.rawSeen[msg] = true;
            local messagePart, rest = string.match(msg, "(.-)%]%|r(.*)");
            if messagePart then
                req.record.message = (req.record.message or "") .. "\n" .. messagePart;
                req.ticketMessageOpen = false;
                local comment = string.match(rest or "", "%|cff00ff00GM%sComment%|r:%s%[(.*)%]%|r");
                if comment then req.record.comment = comment; end
            else
                req.record.message = (req.record.message or "") .. "\n" .. msg;
            end
            Archive.touchRequest();
            return true;
        end
        return false;
    end

    -- Complaint archive parsing.
    if parseComplaintHeader(req, msg) then
        req.rawSeen[msg] = true;
        Archive.touchRequest();
        return true;
    end

    if string.find(msg, "Player subject", 1, true) then
        req.rawSeen[msg] = true;
        req.found = true;
        local clean = stripFormatting(msg);
        local reported = string.match(clean, "Player subject%s*:%s*(.+)") or string.match(clean, "Player subject%s*%-?%s*(.+)");
        if reported and trim(reported) ~= "" then
            req.record.reportedText = trim(reported);
            req.expectPlayerSubject = false;
        else
            req.expectPlayerSubject = true;
        end
        Archive.touchRequest();
        return true;
    end

    local _, _, color, reporter, dateStr, timeStr, channelColor, channel, guid, playerName, message = msg:find(complaintChatPattern);
    if color then
        req.rawSeen[msg] = true;
        req.found = true;
        local key = table.concat({dateStr or "", timeStr or "", channel or "", guid or "", playerName or "", message or ""}, "\031");
        if not req.chatSeen[key] then
            req.chatSeen[key] = true;
            if color == "cff555500" then color = "cffffffff"; end
            local formatted = "|" .. color .. timeStr .. channelColor .. " [" .. channel .. "]: " .. getPlayerLink(playerName) .. " " .. message;
            if req.expectPlayerSubject then
                req.record.reportedText = stripFormatting(formatted);
                req.expectPlayerSubject = false;
            else
                table.insert(req.record.chatLines, formatted);
            end
        end
        Archive.touchRequest();
        return true;
    end

    if req.expectPlayerSubject then
        if string.find(msg, "Chat history", 1, true) then
            req.expectPlayerSubject = false;
            req.rawSeen[msg] = true;
            Archive.touchRequest();
            return true;
        elseif not string.find(msg, "Complaint", 1, true) then
            req.record.reportedText = stripFormatting(msg);
            req.expectPlayerSubject = false;
            req.rawSeen[msg] = true;
            Archive.touchRequest();
            return true;
        end
    end

    if string.find(msg, "Chat history", 1, true) then
        req.rawSeen[msg] = true;
        Archive.touchRequest();
        return true;
    end

    return false;
end
