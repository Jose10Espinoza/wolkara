-- Explicit host UI gestures -> ordinary addon bindings; no game memory or injected Lua.
-- These transient overrides do not overwrite the user's saved bindings.
local _,ns=...
local Bridge=ns.Register("Host controls",{})
-- WoW's canonical chord order is ALT, CTRL, SHIFT. Use F6/F7 so a lost
-- modifier cannot become one of the default F8-F12 bag shortcuts.
local keys={"ALT-CTRL-SHIFT-F6","ALT-CTRL-SHIFT-F7","ALT-CTRL-F6","ALT-CTRL-F7",
    "CTRL-SHIFT-F6","CTRL-SHIFT-F7","ALT-SHIFT-F6","ALT-SHIFT-F7"}
function Bridge:Init()
    local bridge=CreateFrame("Frame","WolkaraMobileBridge",UIParent,"SecureHandlerBaseTemplate")
    ns.bridge=bridge
    function bridge:Command(command)
        ns.hostCommands=(ns.hostCommands or 0)+1
        if command=="on" then
            ns.SetEnabled(true)
            if not InCombatLockdown() then ns.Print("Mobile interface enabled.") end
        elseif command=="off" then
            ns.SetEnabled(false)
            if not InCombatLockdown() then ns.Print("Mobile interface disabled.") end
        elseif command=="edit" then ns.SetEditing(true)
        elseif command=="done" then ns.FinishEditing() end
    end
    local values={"on","off","edit","done","tap","hold","clear","drag"}
    for index,value in ipairs(values) do
        local b=CreateFrame("Button","WolkaraMobileCommand"..index,UIParent,"SecureHandlerClickTemplate")
        b:RegisterForClicks("AnyUp"); b:SetFrameRef("bridge",bridge); b:SetAttribute("command",value)
        b:SetAttribute("_onclick",[=[
            local bridge=self:GetFrameRef("bridge")
            local command=self:GetAttribute("command")
            if command=="tap" or command=="hold" or command=="drag" then
                bridge:SetAttribute("gesture",command)
            elseif command=="clear" then bridge:SetAttribute("gesture",nil)
            else bridge:CallMethod("Command",command) end
        ]=])
        SetOverrideBindingClick(bridge,false,keys[index],b:GetName())
    end
    -- Suppress protected actions on drag release, including when already in combat.
    -- This is a secure wrapper, not a late insecure PreClick attribute change.
    for i=1,ns.MAX_BUTTONS do
        local action=_G["WolkaraMobileAbility"..i]
        if action then SecureHandlerWrapScript(action,"OnClick",bridge,[=[
            local gesture=control:GetAttribute("gesture")
            if not down then control:SetAttribute("gesture",nil) end
            if control:GetAttribute("enabled") and (gesture=="drag" or gesture=="hold") then return false end
        ]=]) end
    end
    if ns.Bags then ns.Bags:Watch() end
    SLASH_WOLKARAMOBILE1="/wolkaramobile"
    SlashCmdList.WOLKARAMOBILE=function()
        ns.Print("Mobile interface v1.0.1: "..(ns.enabled and "enabled" or "disabled")..
            "; host commands received: "..(ns.hostCommands or 0).."; module errors: "..(ns.errors or 0)..".")
    end
end
