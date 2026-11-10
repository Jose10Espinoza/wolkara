-- Explicit host UI gestures -> ordinary addon bindings; no game memory or injected Lua.
-- These transient overrides do not overwrite the user's saved bindings.
local _,ns=...
local Bridge=ns.Register("Host controls",{})
function Bridge:Init()
    local bridge=CreateFrame("Frame","WolkaraMobileBridge",UIParent,"SecureHandlerBaseTemplate")
    ns.bridge=bridge
    function bridge:Command(command)
        if command=="on" then ns.SetEnabled(true)
        elseif command=="off" then ns.SetEnabled(false)
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
        SetOverrideBindingClick(bridge,false,"CTRL-ALT-SHIFT-F"..(4+index),b:GetName())
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
end
