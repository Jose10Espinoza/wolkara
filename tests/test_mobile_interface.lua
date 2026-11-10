-- Synthetic addon API fixture: no client files, account, gameplay or network.
-- Exercises our actual modules and restricted snippets. Physical WoW validation
-- remains required for FrameXML version differences and combat security/taint.
unpack=unpack or table.unpack
local compile=loadstring or load
local combat,now,reloads=false,100,0
local secure=false
local frames,bindings,messages={},{},{}
function InCombatLockdown() return combat end
function GetTime() return now end
function UnitExists() return false end
function GetCursorInfo() return nil end
function GetSpellInfo(id) return "Spell "..id end
function GetSpellTexture() return "fixture-icon" end
function GetSpellCooldown() return 0,0,1 end
function IsUsableSpell() return true,false end
function GetNumSpellTabs() return 0 end
function GetMacroInfo() return "Macro","icon" end
function GetNumMacros() return 0,0 end
function ReloadUI() reloads=reloads+1 end
function RegisterStateDriver(f,state,body) f.drivers=f.drivers or {}; f.drivers[state]=body end
function SetOverrideBindingClick(_,_,key,button) bindings[key]=button end
function hooksecurefunc(name,fn) local original=_G[name]; _G[name]=function(...) local r=original(...); fn(...); return r end end
function ShowUIPanel(f) f:Show() end
function HideUIPanel(f) f:Hide() end
function UpdateContainerFrameAnchors() end
C_Timer={After=function(_,fn) fn() end}
DEFAULT_CHAT_FRAME={AddMessage=function(_,s) messages[#messages+1]=s end}
local Frame={}
local function Noop() end
for _,name in ipairs({"SetAllPoints","SetColorTexture","SetTextColor","SetTexture","SetTexCoord","SetDesaturated","SetVertexColor","SetBlendMode","SetNormalTexture","SetShadowOffset","SetFrameStrata","SetMovable","EnableMouse","RegisterForClicks","RegisterForDrag","RegisterEvent","SetUseCircularEdge","SetSwipeColor","SetHideCountdownNumbers","SetJustifyV","SetMaxLines","SetCooldown","Clear"}) do Frame[name]=Noop end
function Frame:SetScript(name,fn) self.scripts[name]=fn end
function Frame:GetScript(name) return self.scripts[name] end
function Frame:HookScript(name,fn) local old=self.scripts[name]; self.scripts[name]=function(...) if old then old(...) end; fn(...) end end
function Frame:GetName() return self.name end
function Frame:GetObjectType() return self.kind end
function Frame:GetChildren() return unpack(self.children) end
function Frame:GetParent() return self.parent end
function Frame:SetSize(w,h) self.w,self.h=w,h end
function Frame:SetWidth(w) self.w=w end
function Frame:SetHeight(h) self.h=h end
function Frame:GetWidth() return self.w end
function Frame:GetHeight() return self.h end
function Frame:SetPoint(...) self.points={ {...} } end
function Frame:GetPoint(i) return unpack(self.points[i]) end
function Frame:GetNumPoints() return #self.points end
function Frame:ClearAllPoints() self.points={} end
function Frame:GetCenter() local p=self.points[1]; return p and p[4] or 500,p and p[5] or 300 end
function Frame:GetRight() return self.w end
function Frame:GetTop() return self.h end
function Frame:SetScale(n) assert(not(combat and self.protected)); self.scale=n end
function Frame:GetScale() return self.scale end
function Frame:GetEffectiveScale() return self.scale*(self.parent and self.parent:GetEffectiveScale() or 1) end
function Frame:SetClampedToScreen(on) self.clamped=on end
function Frame:IsClampedToScreen() return self.clamped end
function Frame:SetClampRectInsets(...) self.insets={...} end
function Frame:GetClampRectInsets() return unpack(self.insets) end
function Frame:IsProtected() return self.protected end
function Frame:SetAttribute(key,value) assert(secure or not(combat and self.protected),"insecure protected attribute in combat"); self.attrs[key]=value end
function Frame:GetAttribute(key) return self.attrs[key] end
function Frame:SetFrameRef(key,value) self.refs[key]=value end
function Frame:GetFrameRef(key) return self.refs[key] end
function Frame:CallMethod(key,...) return self[key](self,...) end
function Frame:GetID() return self.id or 0 end
function Frame:SetID(id) self.id=id end
function Frame:SetFrameLevel(n) self.level=n end
function Frame:GetFrameLevel() return self.level end
function Frame:SetText(t) self.label=t; if self.font then self.font.label=t end end
function Frame:GetFontString() self.font=self.font or self:CreateFontString(); self.font.label=self.label; return self.font end
function Frame:Show() self.shown=true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
function Frame:Hide() assert(not(combat and self.protected),"insecure hide in combat"); self.shown=false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
function Frame:SetShown(on) if on then self:Show() else self:Hide() end end
function Frame:IsShown() return self.shown end
function Frame:StartMoving() self.moving=true end
function Frame:StopMovingOrSizing() self.moving=false end
function Frame:Click(button,down)
    button=button or "LeftButton"; down=down or false
    if self.scripts.PreClick then self.scripts.PreClick(self,button,down) end
    if self.scripts.OnClick then self.scripts.OnClick(self,button,down) end
    if self.scripts.PostClick then self.scripts.PostClick(self,button,down) end
end
function CreateFrame(kind,name,parent,template)
    local f=setmetatable({kind=kind,name=name,parent=parent,children={},scripts={},attrs={},refs={},points={},insets={0,0,0,0},shown=true,scale=1,w=100,h=100,level=1,clamped=false,protected=template and template:find("Secure")~=nil},{__index=Frame})
    if parent then parent.children[#parent.children+1]=f end
    if name then _G[name]=f end; frames[#frames+1]=f
    if template and template:find("SecureActionButtonTemplate") then
        f.scripts.OnClick=function(self,button,down) if not down and self.attrs.type then self.casts=(self.casts or 0)+1 end end
    end
    return f
end
function Frame:CreateTexture() return CreateFrame("Texture",nil,nil) end
function Frame:CreateFontString() return CreateFrame("FontString",nil,nil) end
function SecureHandlerWrapScript(f,script,control,body)
    local snippet=assert(compile("return function(self,control,button,down) "..body.." end"))()
    local original=f:GetScript(script)
    f:SetScript(script,function(self,button,down)
        secure=true
        local override=snippet(self,control,button,down)
        secure=false
        if override==false then return end
        if original then original(self,override or button,down) end
    end)
end
UIParent=CreateFrame("Frame","UIParent"); UIParent:SetSize(1000,700)
local original=CreateFrame("Frame","QuestFrame",UIParent)
original:SetSize(600,1200); original:SetScale(.8); original:SetPoint("TOPLEFT",UIParent,"TOPLEFT",12,-25)
original:SetClampRectInsets(1,2,3,4)
local bag=CreateFrame("Frame","ContainerFrame1",UIParent); bag:SetID(0)
local slot=CreateFrame("ItemButton","ContainerFrame1Item1",bag); slot:SetID(1); slot.icon=slot:CreateTexture()
local clicks={}; slot:SetScript("OnClick",function(_,button,down) if not down then clicks[#clicks+1]=button end end)
local ns={}
for line in io.lines("addons/WolkaraMobile/WolkaraMobile.toc") do
    if line:match("%.lua$") then assert(loadfile("addons/WolkaraMobile/"..line))("WolkaraMobile",ns) end
end
local function Event(name,...) ns.events:GetScript("OnEvent")(ns.events,name,...) end
local function Clean() for _,s in ipairs(messages) do assert(not s:match("attempt") and not s:match("insecure"),s) end end
local function Button(parent,text)
    for _,f in ipairs(parent.children) do if f.kind=="Button" and (f.label==text or f.font and f.font.label==text) then return f end end
    error("missing button "..text)
end
ns.hostSession="fixture-session"
Event("ADDON_LOADED","WolkaraMobile"); Clean()
Event("PLAYER_LOGIN"); assert(not ns.enabled and original:GetScale()==.8)
assert(bindings["CTRL-ALT-SHIFT-F5"]=="WolkaraMobileCommand1")
assert(bindings["CTRL-ALT-SHIFT-F12"]=="WolkaraMobileCommand8")
local function Mark(gesture) ns.bridge.attrs.gesture=gesture end
slot:Click(); assert(clicks[#clicks]=="LeftButton") -- Disabled mode never converts.
ns.SetEnabled(true); assert(ns.enabled and original:GetScale()<.8)
local menu=Button(UIParent,"Menu"); assert(menu:IsShown())
slot:Click(); assert(clicks[#clicks]=="LeftButton") -- Untagged physical pointer unchanged.
Mark("tap"); slot:Click(); assert(clicks[#clicks]=="RightButton")
assert(ns.bridge:GetAttribute("gesture")==nil)
slot:Click(); assert(clicks[#clicks]=="LeftButton")
local count=#clicks
Mark("drag"); slot:Click(); assert(#clicks==count)
Mark("hold"); slot:Click(); assert(#clicks==count and WolkaraMobileBagOptions:IsShown())
Mark(nil); Button(WolkaraMobileBagOptions,"Cancel"):Click(); assert(not WolkaraMobileBagOptions:IsShown())
-- Build a layout via its public editor, assign a spell, resize and move it.
ns.SetEditing(true); Button(WolkaraMobileEditor,"Add"):Click()
local ability=WolkaraMobileAbility1
assert(#ns.db.buttons==1 and ability:IsShown())
ns.AssignEntry(ability,{kind="spell",id=123}); ns.SelectButton(ability)
Button(WolkaraMobileEditor,"Larger"):Click(); assert(ns.db.buttons[1].size==56)
ability:GetScript("OnDragStart")(ability)
ability:SetPoint("CENTER",UIParent,"BOTTOMLEFT",720,420)
ability:GetScript("OnDragStop")(ability)
assert(math.abs(ns.db.buttons[1].x-.72)<.001 and math.abs(ns.db.buttons[1].y-.6)<.001)
ns.SetEditing(false); ability.swiped=nil
Mark("tap"); ability:Click("LeftButton",true); ability:Click(); assert(ability.casts==1)
Mark("drag"); ability:Click(); assert(ability.casts==1)
Mark("hold"); ability:Click(); assert(ability.casts==1)
-- Combat: no protected attributes/layout changes, drag never casts, off queues.
combat=true; Event("PLAYER_REGEN_DISABLED")
Mark("tap"); ability:Click(); assert(ability.casts==2)
Mark("drag"); ability:Click(); Mark("drag"); slot:Click(); assert(ability.casts==2 and #clicks==count)
ns.SetEnabled(false); assert(ns.enabled)
combat=false; Event("PLAYER_REGEN_ENABLED"); assert(not ns.enabled and not ability:IsShown())
assert(original:GetScale()==.8 and original:IsClampedToScreen()==false)
local a,b,c,d=original:GetClampRectInsets(); assert(a==1 and b==2 and c==3 and d==4)
local _,_,_,x,y=original:GetPoint(1); assert(x==12 and y==-25)
assert(ns.db.buttons[1].entry.id==123) -- Toggle never discards layout.
-- Explicit save only; rendering, resize, enable/disable never reload the UI.
assert(reloads==0); ns.SetEnabled(true); ns.FinishEditing(); assert(reloads==1)
ns.SetEnabled(false); Event("PLAYER_LOGIN"); assert(not ns.enabled) -- Same-session reload keeps toggle.
ns.hostSession="next-launch"; ns.hostEnabled=true; Event("PLAYER_LOGIN"); assert(ns.enabled)
ns.SetEditing(true)
for i=2,70 do Button(WolkaraMobileEditor,"Add"):Click() end
assert(#ns.db.buttons==64)
ns.SetEnabled(false); Clean()
print("MOBILE_ADDON_PASS: enable/restore, secure tap/hold/drag, editable actions, combat queue, persistence and limits")
