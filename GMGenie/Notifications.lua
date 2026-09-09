-- GM Genie notification helper for tickets and complaints.
-- Uses stock WoW UI sounds compatible with the MoP 5.4.8 client.

GMGenie.Notifications = {};

GMGenie.Notifications.sounds = {
    { key = "none",         label = "None",              path = nil },
    { key = "readycheck",   label = "Ready Check",       path = "Sound\\Interface\\ReadyCheck.ogg" },
    { key = "raidwarning",  label = "Raid Warning",      path = "Sound\\Interface\\RaidWarning.ogg" },
    { key = "raidboss",     label = "Raid Boss Warning", path = "Sound\\Interface\\RaidBossWarning.ogg" },
    { key = "dungeonready", label = "Dungeon Ready",     path = "Sound\\Interface\\levelup2.ogg" },
    { key = "tell",         label = "Whisper",           path = "Sound\\Interface\\iTellMessage.ogg" },
    { key = "map",          label = "Map Ping",          path = "Sound\\Interface\\MapPing.ogg" },
    { key = "levelup",      label = "Level Up",          path = "Sound\\Interface\\LevelUp.ogg" },
    { key = "friend",       label = "Friend Online",     path = "Sound\\Interface\\FriendJoin.ogg" },
    { key = "invite",       label = "Player Invite",     path = "Sound\\Interface\\iPlayerInviteA.ogg" },
};

GMGenie.Notifications.soundByKey = {};
for _, sound in ipairs(GMGenie.Notifications.sounds) do
    GMGenie.Notifications.soundByKey[sound.key] = sound;
end

GMGenie.Notifications.pending = { ticket = {}, complaint = {} };
GMGenie.Notifications.flashing = { ticket = false, complaint = false };
GMGenie.Notifications.flashState = false;
GMGenie.Notifications.flashElapsed = 0;

local function getButton(kind)
    if kind == "ticket" then
        return GMGenie_Hud_Tickets;
    elseif kind == "complaint" then
        return GMGenie_Hud_Complaints;
    end
end

local function flashEnabled(kind)
    if not GMGenie_SavedVars then return true; end
    if kind == "ticket" then
        return GMGenie_SavedVars.ticketNotificationFlash ~= false;
    elseif kind == "complaint" then
        return GMGenie_SavedVars.complaintNotificationFlash ~= false;
    end
    return false;
end

GMGenie.Notifications.flashFrame = CreateFrame("Frame");
GMGenie.Notifications.flashFrame:Hide();
GMGenie.Notifications.flashFrame:SetScript("OnUpdate", function(self, elapsed)
    GMGenie.Notifications.flashElapsed = GMGenie.Notifications.flashElapsed + elapsed;
    if GMGenie.Notifications.flashElapsed < 0.45 then return; end
    GMGenie.Notifications.flashElapsed = 0;
    GMGenie.Notifications.flashState = not GMGenie.Notifications.flashState;

    local anyActive = false;
    for _, kind in ipairs({ "ticket", "complaint" }) do
        if GMGenie.Notifications.flashing[kind] and flashEnabled(kind) then
            anyActive = true;
            local button = getButton(kind);
            if button then
                if GMGenie.Notifications.flashState then
                    button:LockHighlight();
                else
                    button:UnlockHighlight();
                end
            end
        end
    end

    if not anyActive then self:Hide(); end
end);

function GMGenie.Notifications.getSound(key)
    return GMGenie.Notifications.soundByKey[key] or GMGenie.Notifications.soundByKey["none"];
end

function GMGenie.Notifications.getSoundLabel(key)
    local sound = GMGenie.Notifications.getSound(key);
    return sound and sound.label or "None";
end

function GMGenie.Notifications.playSound(key)
    local sound = GMGenie.Notifications.getSound(key);
    if not sound or not sound.path then return; end

    -- Prefer the Master channel. If an older client build rejects the channel
    -- argument, fall back to the original PlaySoundFile signature.
    local ok = pcall(PlaySoundFile, sound.path, "Master");
    if not ok then pcall(PlaySoundFile, sound.path); end
end

function GMGenie.Notifications.startFlash(kind)
    if not flashEnabled(kind) then return; end
    GMGenie.Notifications.flashing[kind] = true;
    GMGenie.Notifications.flashFrame:Show();
end

function GMGenie.Notifications.stopFlash(kind)
    GMGenie.Notifications.flashing[kind] = false;
    local button = getButton(kind);
    if button then button:UnlockHighlight(); end
    if not GMGenie.Notifications.flashing.ticket and not GMGenie.Notifications.flashing.complaint then
        GMGenie.Notifications.flashFrame:Hide();
    end
end

function GMGenie.Notifications.hasPending(kind)
    local pending = GMGenie.Notifications.pending[kind];
    return pending and next(pending) ~= nil;
end

function GMGenie.Notifications.notify(kind, id, playerName)
    if kind ~= "ticket" and kind ~= "complaint" then return; end

    if GMGenie.Archive and GMGenie.Archive.observeId then
        GMGenie.Archive.observeId(kind, id);
    end

    local key = tostring(id or "unknown");
    if GMGenie.Notifications.pending[kind][key] then return; end
    GMGenie.Notifications.pending[kind][key] = true;

    if kind == "ticket" then
        GMGenie.Notifications.playSound(GMGenie_SavedVars.ticketNotificationSound);
    else
        GMGenie.Notifications.playSound(GMGenie_SavedVars.complaintNotificationSound);
    end
    GMGenie.Notifications.startFlash(kind);
end

function GMGenie.Notifications.newTicket(ticketId, playerName)
    GMGenie.Notifications.notify("ticket", ticketId, playerName);
end

function GMGenie.Notifications.newComplaint(complaintId, playerName)
    GMGenie.Notifications.notify("complaint", complaintId, playerName);
end

function GMGenie.Notifications.markSeen(kind, id)
    local pending = GMGenie.Notifications.pending[kind];
    if not pending then return; end
    if id ~= nil then pending[tostring(id)] = nil; end
    pending["unknown"] = nil;
    if not GMGenie.Notifications.hasPending(kind) then
        GMGenie.Notifications.stopFlash(kind);
    end
end

function GMGenie.Notifications.applyFlashSettings()
    for _, kind in ipairs({ "ticket", "complaint" }) do
        if flashEnabled(kind) and GMGenie.Notifications.hasPending(kind) then
            GMGenie.Notifications.startFlash(kind);
        elseif not flashEnabled(kind) then
            GMGenie.Notifications.stopFlash(kind);
        end
    end
end
