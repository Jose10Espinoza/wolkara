-- Freely placed actions. Reuses WolkaraRoue's action/selection primitives (MIT).
local _, ns=...
local Abilities=ns.Register("Abilities",{})
local buttons, panel, selected, all, summary = {}, nil, nil, false, nil
local function Item(i) return ns.db.buttons[i] end
local function Place(b,i)
    local s=Item(i)
    if not s then b:Hide(); return end
    local W,H=UIParent:GetWidth(),UIParent:GetHeight()
    s.size=ns.Clamp(tonumber(s.size) or 52,28,120)
    s.x=ns.Clamp(tonumber(s.x) or .5,s.size/2/W,1-s.size/2/W)
    s.y=ns.Clamp(tonumber(s.y) or .36,s.size/2/H,1-s.size/2/H)
    b:SetSize(s.size,s.size); b:ClearAllPoints()
    b:SetPoint("CENTER",UIParent,"BOTTOMLEFT",s.x*W,s.y*H)
    b:SetShown(ns.enabled); ns.ApplyButton(b); ns.RefreshButton(b)
end
local function Status()
    if summary then summary:SetText((all and "Whole layout" or (selected and "Button "..selected or "Tap a button")).." · "..#ns.db.buttons.."/"..ns.MAX_BUTTONS) end
end
function ns.SelectButton(b) selected=b.index; Status() end
local function Add()
    if InCombatLockdown() or #ns.db.buttons>=ns.MAX_BUTTONS then return end
    local i=#ns.db.buttons+1
    ns.db.buttons[i]={x=.32+((i-1)%6)*.07,y=.4+math.floor(((i-1)%18)/6)*.09,size=52}
    selected=i; ns.MarkChanged(); ns.Layout()
end
local function Resize(delta)
    if InCombatLockdown() then return end
    local pivot=selected and Item(selected)
    local factor=pivot and ns.Clamp((pivot.size or 52)+delta,28,120)/(pivot.size or 52) or 1
    for i,s in ipairs(ns.db.buttons) do
        if all or i==selected then
            if all and pivot then s.x=pivot.x+(s.x-pivot.x)*factor; s.y=pivot.y+(s.y-pivot.y)*factor end
            s.size=ns.Clamp((s.size or 52)+delta,28,120)
        end
    end
    ns.MarkChanged(); ns.Layout()
end
local function DragEnd(b)
    if not b.moving then return end
    b:StopMovingOrSizing(); b.moving=nil; b.swiped=true
    if InCombatLockdown() then ns.pendingLayout=true; return end
    local s=Item(b.index); if not s then return end
    local W,H=UIParent:GetWidth(),UIParent:GetHeight()
    local x,y=b:GetCenter(); local dx,dy=x/W-s.x,y/H-s.y
    if all then
        for _,v in ipairs(ns.db.buttons) do
            dx=ns.Clamp(dx,v.size/2/W-v.x,1-v.size/2/W-v.x)
            dy=ns.Clamp(dy,v.size/2/H-v.y,1-v.size/2/H-v.y)
        end
        for _,v in ipairs(ns.db.buttons) do v.x=v.x+dx; v.y=v.y+dy end
    else s.x=x/W; s.y=y/H end
    ns.MarkChanged(); ns.Layout()
end
function Abilities:Init()
    -- Bound and sanitize persisted layouts before creating secure buttons.
    for i=#ns.db.buttons,ns.MAX_BUTTONS+1,-1 do ns.db.buttons[i]=nil end
    for i,s in ipairs(ns.db.buttons) do if type(s)~="table" then ns.db.buttons[i]={} end end
    for i=1,ns.MAX_BUTTONS do
        local b=ns.CreateActionButton("WolkaraMobileAbility"..i,UIParent,52,
            function() return Item(i) and Item(i).entry end,
            function(e) if Item(i) then Item(i).entry=e end end)
        b.index=i; b:SetFrameStrata("LOW"); b:SetMovable(true); b:SetClampedToScreen(true)
        b:RegisterForDrag("LeftButton")
        b:SetScript("OnDragStart",function(self)
            if ns.editing and not InCombatLockdown() then
                selected=i; self.moving=true; self:StartMoving(); Status()
            end
        end)
        b:SetScript("OnDragStop",DragEnd); b:Hide(); buttons[i]=b
    end
    panel=CreateFrame("Frame","WolkaraMobileEditor",UIParent,"UIPanelDialogTemplate")
    panel:SetSize(620,112); panel:SetPoint("TOP",0,-130); panel:SetFrameStrata("DIALOG"); panel:EnableMouse(true); panel:Hide()
    summary=ns.Label(panel,"GameFontNormal",""); summary:SetPoint("TOP",0,-14)
    local defs={
        {"Add",Add},
        {"Choose",function() if selected then ns.Picker:Open(buttons[selected]) end end},
        {"Smaller",function() Resize(-4) end},
        {"Larger",function() Resize(4) end},
        {"Move/size all",function() all=not all; Status() end},
        {"Remove",function()
            if selected and not InCombatLockdown() then table.remove(ns.db.buttons,selected); selected=nil; ns.MarkChanged(); ns.Layout() end
        end},
    }
    for i,d in ipairs(defs) do
        local b=ns.UIButton(panel,d[1],94,36,d[2]); b:SetPoint("TOPLEFT",15+(i-1)*98,-42)
    end
    local help=ns.Label(panel,"GameFontHighlightSmall","Drag buttons to move. Done & save reloads the interface."); help:SetPoint("BOTTOM",0,12)
    local tick=CreateFrame("Frame"); local elapsed=0
    tick:SetScript("OnUpdate",function(_,dt)
        if not ns.enabled then return end
        elapsed=elapsed+dt; if elapsed<.25 then return end; elapsed=0
        for i=1,#ns.db.buttons do ns.UpdateState(buttons[i]) end
    end)
end
function Abilities:Layout()
    for i,b in ipairs(buttons) do Place(b,i) end
    panel:SetShown(ns.editing); if ns.editing then ns.FitPanel(panel) end; Status()
end
function Abilities:Refresh()
    for i=1,#ns.db.buttons do ns.RefreshButton(buttons[i]) end
end
function Abilities:SetEditing() self:Layout() end
function Abilities:Disable()
    panel:Hide(); ns.Picker:Close()
    for _,b in ipairs(buttons) do b:Hide(); ns.ApplyButton(b) end
end
function Abilities:CombatStarts() panel:Hide() end
function Abilities:AfterCombat() ns.Layout() end
ns.On("SPELL_UPDATE_COOLDOWN",function()
    if ns.enabled then for i=1,#ns.db.buttons do ns.UpdateCooldown(buttons[i]) end end
end)
ns.On("BAG_UPDATE",function() ns.Refresh() end)
ns.On("SPELLS_CHANGED",function() ns.Layout(); ns.Refresh() end)
