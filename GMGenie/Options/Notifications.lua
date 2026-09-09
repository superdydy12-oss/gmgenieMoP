-- Notification options for tickets and complaints.

local function notificationPanel()
    return getglobal("GMGenie_Notifications_OptionsWindow");
end

local function selectedSound(kind)
    local panel = notificationPanel();
    if kind == "ticket" then
        return panel.ticketSoundSelection or GMGenie_SavedVars.ticketNotificationSound;
    end
    return panel.complaintSoundSelection or GMGenie_SavedVars.complaintNotificationSound;
end

function GMGenie.Notifications.loadSoundDropdown(kind)
    local selected = selectedSound(kind);
    for _, sound in ipairs(GMGenie.Notifications.sounds) do
        local soundKey = sound.key;
        local info = UIDropDownMenu_CreateInfo();
        info.text = sound.label;
        info.value = soundKey;
        info.checked = (selected == soundKey);
        info.func = function()
            local panel = notificationPanel();
            if kind == "ticket" then
                panel.ticketSoundSelection = soundKey;
                UIDropDownMenu_SetSelectedValue(GMGenie_Notifications_OptionsWindow_TicketSound, soundKey);
                UIDropDownMenu_SetText(GMGenie_Notifications_OptionsWindow_TicketSound, GMGenie.Notifications.getSoundLabel(soundKey));
            else
                panel.complaintSoundSelection = soundKey;
                UIDropDownMenu_SetSelectedValue(GMGenie_Notifications_OptionsWindow_ComplaintSound, soundKey);
                UIDropDownMenu_SetText(GMGenie_Notifications_OptionsWindow_ComplaintSound, GMGenie.Notifications.getSoundLabel(soundKey));
            end
            CloseDropDownMenus();
            GMGenie.Notifications.playSound(soundKey);
        end;
        UIDropDownMenu_AddButton(info);
    end
end

function GMGenie.Notifications.preview(kind)
    GMGenie.Notifications.playSound(selectedSound(kind));
end

function GMGenie.Notifications.optionsOkay()
    local panel = notificationPanel();
    GMGenie_SavedVars.ticketNotificationSound = panel.ticketSoundSelection or GMGenie.defaultSettings.ticketNotificationSound;
    GMGenie_SavedVars.complaintNotificationSound = panel.complaintSoundSelection or GMGenie.defaultSettings.complaintNotificationSound;
    GMGenie_SavedVars.ticketNotificationFlash = GMGenie_Notifications_OptionsWindow_TicketFlash:GetChecked() and true or false;
    GMGenie_SavedVars.complaintNotificationFlash = GMGenie_Notifications_OptionsWindow_ComplaintFlash:GetChecked() and true or false;
    GMGenie.Notifications.applyFlashSettings();
end

function GMGenie.Notifications.optionsDefault()
    GMGenie.setDefault({ "ticketNotificationSound", "complaintNotificationSound", "ticketNotificationFlash", "complaintNotificationFlash" });
    GMGenie.Notifications.optionsUpdate();
    GMGenie.Notifications.applyFlashSettings();
end

function GMGenie.Notifications.optionsOnLoad()
    local panel = notificationPanel();
    panel.name = "Notifications";
    panel.parent = "GM Genie";
    panel.okay = GMGenie.Notifications.optionsOkay;
    panel.cancel = GMGenie.Notifications.optionsUpdate;
    panel.default = GMGenie.Notifications.optionsDefault;
    InterfaceOptions_AddCategory(panel);

    GMGenie_Notifications_OptionsWindow_Title:SetText("Notifications");
    GMGenie_Notifications_OptionsWindow_SubText:SetText("Choose separate alerts for new tickets and complaints. Selecting a sound previews it immediately.");

    UIDropDownMenu_SetWidth(GMGenie_Notifications_OptionsWindow_TicketSound, 170);
    UIDropDownMenu_SetWidth(GMGenie_Notifications_OptionsWindow_ComplaintSound, 170);
    UIDropDownMenu_Initialize(GMGenie_Notifications_OptionsWindow_TicketSound, function() GMGenie.Notifications.loadSoundDropdown("ticket"); end);
    UIDropDownMenu_Initialize(GMGenie_Notifications_OptionsWindow_ComplaintSound, function() GMGenie.Notifications.loadSoundDropdown("complaint"); end);
    GMGenie.Notifications.optionsUpdate();
end

function GMGenie.Notifications.optionsUpdate()
    local panel = notificationPanel();
    panel.ticketSoundSelection = GMGenie_SavedVars.ticketNotificationSound;
    panel.complaintSoundSelection = GMGenie_SavedVars.complaintNotificationSound;

    UIDropDownMenu_SetSelectedValue(GMGenie_Notifications_OptionsWindow_TicketSound, panel.ticketSoundSelection);
    UIDropDownMenu_SetText(GMGenie_Notifications_OptionsWindow_TicketSound, GMGenie.Notifications.getSoundLabel(panel.ticketSoundSelection));
    UIDropDownMenu_SetSelectedValue(GMGenie_Notifications_OptionsWindow_ComplaintSound, panel.complaintSoundSelection);
    UIDropDownMenu_SetText(GMGenie_Notifications_OptionsWindow_ComplaintSound, GMGenie.Notifications.getSoundLabel(panel.complaintSoundSelection));

    GMGenie_Notifications_OptionsWindow_TicketFlash:SetChecked(GMGenie_SavedVars.ticketNotificationFlash);
    GMGenie_Notifications_OptionsWindow_ComplaintFlash:SetChecked(GMGenie_SavedVars.complaintNotificationFlash);
end
