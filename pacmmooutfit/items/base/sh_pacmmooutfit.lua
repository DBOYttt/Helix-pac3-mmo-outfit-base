--[[ 
    File: gamemodes/darkrp/plugins/pacmmooutfit/items/base/sh_pacmmooutfit.lua
    This is the PAC Outfit Base.
    Child items using this base should set:
       Base = "base_pacmmooutfit"
    and may define an attribRanges table to allow randomized attribute generation.
    
    Example attribRanges for a child item:
       ITEM.attribRanges = {
           str = {min = 1,  max = 50},
           arm = {min = 1,  max = 50},
           end = {min = 1,  max = 50},
           stm = {min = 1,  max = 50}
       }
    
    In this scheme, the probability for each successive number is roughly halved compared to the previous one.
--]]

-- Do not override ITEM.uniqueID! Helix will automatically set it based on the filename.
ITEM.hooks = ITEM.hooks or {}
ITEM.postHooks = ITEM.postHooks or {}
ITEM.functions = ITEM.functions or {}

ITEM.name = "PAC Outfit Base"
ITEM.description = [[
A fully featured PAC outfit base that supports:
- Stats or Look-Only equip modes
- Hiding a stats item if a look-only item is placed in the same slot
- Persistent data across restarts
- Custom dropped model (box01a)
]]
ITEM.category = "Outfit"
ITEM.model = "models/Gibs/HGIBS.mdl"
ITEM.dropModel = "models/props_junk/cardboard_box001a.mdl"
ITEM.width = 1
ITEM.height = 1

-- Which "slot" or category this outfit occupies in Helix's system:
ITEM.outfitCategory = "hat"

-- Example PAC data. (Items sharing the same UniqueID here may conflict in PAC3.)
ITEM.pacData = {
    [1] = {
        ["self"] = {
            ["ClassName"] = "group",
            ["UniqueID"]   = "example_pac_group"
        },
    },
}

-- Example attribute boosts for Stats mode (optional).
ITEM.attribBoosts = nil

--------------------------------------------------------------------------------
-- RANDOM ATTRIBUTE GENERATION (Discrete Geometric Distribution)
--------------------------------------------------------------------------------
-- Child items may define an attribRanges table (with min and max values for each attribute).
-- In this version, the chance for each number is half of the previous one.
function ITEM:GenerateRandomAttributes()
    local attributes = {}
    if self.attribRanges then
        local function GeometricRandom(min, max)
            local n = max - min + 1
            local total = 0
            for i = 0, n - 1 do
                total = total + (0.5)^i
            end
            local r = math.random() * total  -- math.random() returns a float in [0,1)
            local cum = 0
            for i = 0, n - 1 do
                cum = cum + (0.5)^i
                if r <= cum then
                    return min + i
                end
            end
            return max
        end
        for attr, range in pairs(self.attribRanges) do
            attributes[attr] = GeometricRandom(range.min, range.max)
        end
    end
    return attributes
end

-- OnInstanced is called when a new item instance is created.
function ITEM:OnInstanced(invID, x, y, item)
    if self.attribRanges and not self:GetData("attributes") then
        local randomAttributes = self:GenerateRandomAttributes()
        self:SetData("attributes", randomAttributes)
        print("[ITEM TEMPLATE] Generated attributes for item", self.uniqueID, randomAttributes)
    end
end

--------------------------------------------------------------------------------
-- CLIENT: Draw a green square if equipped in any mode.
--------------------------------------------------------------------------------
if CLIENT then
    function ITEM:PaintOver(item, w, h)
        if item:GetData("equip") or item:GetData("equipLook") then
            surface.SetDrawColor(110, 255, 110, 100)
            surface.DrawRect(w - 14, h - 14, 8, 8)
        end
    end
end

--------------------------------------------------------------------------------
-- HELPER: Hide/Show PAC Visuals (not stats)
--------------------------------------------------------------------------------
function ITEM:HidePAC(client)
    client:RemovePart(self.uniqueID)
    self:SetData("pacHidden", true)
end

function ITEM:ShowPAC(client)
    if self:GetData("pacHidden") then
        client:AddPart(self.uniqueID, self)
        self:SetData("pacHidden", false)
    end
end

--------------------------------------------------------------------------------
-- RemovePart: Fully un-equip stats + PAC.
--------------------------------------------------------------------------------
function ITEM:RemovePart(client)
    local char = client:GetCharacter()
    if not char then return end

    self:SetData("equip", false)
    self:SetData("equipLook", false)
    self:SetData("pacHidden", nil)

    client:RemovePart(self.uniqueID)

    -- Revert any attribute boosts.
    local oldAttributes = self:GetData("oldAttributes", {})
    if next(oldAttributes) ~= nil then
        for attrName, oldVal in pairs(oldAttributes) do
            char:SetAttrib(attrName, oldVal)
        end
    end
    self:SetData("oldAttributes", nil)

    self:OnUnequipped()
end

ITEM:Hook("drop", function(item)
    if item:GetData("equip") or item:GetData("equipLook") then
        item:RemovePart(item:GetOwner())
    end
end)

--------------------------------------------------------------------------------
-- MODE 1: EQUIP (STATS + APPEARANCE)
--------------------------------------------------------------------------------
ITEM.functions.Equip = {
    name = "Equip (Stats)",
    tip = "equipTip",
    icon = "icon16/tick.png",
    OnRun = function(item)
        local client = item.player
        local char = client:GetCharacter()
        if not char then return false end

        item:SetData("equip", true)
        item:SetData("equipLook", false)
        item:SetData("pacHidden", false)

        local oldAttributes = {}
        if item.attribBoosts then
            for attrName, boostVal in pairs(item.attribBoosts) do
                local currentVal = char:GetAttribute(attrName, 0)
                oldAttributes[attrName] = currentVal
                char:SetAttrib(attrName, currentVal + boostVal)
            end
        elseif item.attribRanges then
            local randomAttributes = item:GetData("attributes")
            if randomAttributes then
                for attr, value in pairs(randomAttributes) do
                    local currentVal = char:GetAttribute(attr, 0)
                    oldAttributes[attr] = currentVal
                    char:SetAttrib(attr, currentVal + value)
                end
            end
        end
        item:SetData("oldAttributes", oldAttributes)

        client:AddPart(item.uniqueID, item)
        item:OnEquipped()
        return false
    end,
    OnCanRun = function(item)
        local client = item.player
        if not IsValid(client) then return false end
        local char = client:GetCharacter()
        if not char then return false end

        for _, v in pairs(char:GetInventory():GetItems()) do
            if v.id ~= item.id and v.outfitCategory == item.outfitCategory then
                if v:GetData("equip") == true then return false end
            end
        end

        if item:GetData("equip") or item:GetData("equipLook") then return false end
        return not IsValid(item.entity)
    end
}

ITEM.functions.EquipUn = {
    name = "Unequip (Stats)",
    tip = "unequipTip",
    icon = "icon16/cross.png",
    OnRun = function(item)
        item:RemovePart(item.player)
        return false
    end,
    OnCanRun = function(item)
        return item:GetData("equip") == true
            and not IsValid(item.entity)
            and IsValid(item.player)
    end
}

--------------------------------------------------------------------------------
-- MODE 2: EQUIP (LOOK ONLY)
--------------------------------------------------------------------------------
ITEM.functions.EquipLook = {
    name = "Equip (Look Only)",
    tip = "equipTip",
    icon = "icon16/tick.png",
    OnRun = function(item)
        local client = item.player
        local char = client:GetCharacter()
        if not char then return false end

        item:SetData("equipLook", true)
        item:SetData("equip", false)
        item:SetData("pacHidden", false)

        client:AddPart(item.uniqueID, item)

        for _, v in pairs(char:GetInventory():GetItems()) do
            if v.id ~= item.id and v.outfitCategory == item.outfitCategory then
                if v:GetData("equip") == true and not v:GetData("pacHidden") then
                    v:HidePAC(client)
                    item:SetData("hiddenStatsItemID", v.id)
                    break
                end
            end
        end

        item:OnEquipped()
        return false
    end,
    OnCanRun = function(item)
        local client = item.player
        if not IsValid(client) then return false end
        local char = client:GetCharacter()
        if not char then return false end

        for _, v in pairs(char:GetInventory():GetItems()) do
            if v.id ~= item.id and v.outfitCategory == item.outfitCategory then
                if v:GetData("equipLook") == true then return false end
            end
        end

        return (not item:GetData("equipLook"))
            and (not item:GetData("equip"))
            and (not IsValid(item.entity))
    end
}

ITEM.functions.EquipLookUn = {
    name = "Unequip (Look Only)",
    tip = "unequipTip",
    icon = "icon16/cross.png",
    OnRun = function(item)
        local client = item.player

        item:SetData("equipLook", false)
        client:RemovePart(item.uniqueID)

        local hiddenID = item:GetData("hiddenStatsItemID")
        if hiddenID then
            local hiddenItem = ix.item.instances[hiddenID]
            if hiddenItem and hiddenItem:GetOwner() == client and hiddenItem:GetData("equip") == true then
                hiddenItem:ShowPAC(client)
            end
            item:SetData("hiddenStatsItemID", nil)
        end

        item:OnUnequipped()
        return false
    end,
    OnCanRun = function(item)
        return item:GetData("equipLook") == true
            and not IsValid(item.entity)
            and IsValid(item.player)
    end
}

--------------------------------------------------------------------------------
-- BLOCK TRANSFER IF EQUIPPED
--------------------------------------------------------------------------------
function ITEM:CanTransfer(oldInventory, newInventory)
    if newInventory and (self:GetData("equip") or self:GetData("equipLook")) then
        return false
    end
    return true
end

--------------------------------------------------------------------------------
-- CLEANUP IF REMOVED FROM INVENTORY
--------------------------------------------------------------------------------
function ITEM:OnRemoved()
    local inventory = ix.item.inventories[self.invID]
    local owner = inventory and inventory.GetOwner and inventory:GetOwner()
    if IsValid(owner) and owner:IsPlayer() then
        if self:GetData("equip") or self:GetData("equipLook") then
            self:RemovePart(owner)
        end
    end
end

--------------------------------------------------------------------------------
-- DESCRIPTION (SHOW BOOSTS AND RANDOMIZED ATTRIBUTES)
--------------------------------------------------------------------------------
function ITEM:GetDescription()
    local desc = self.description or ""
    
    if self.attribBoosts or self.attribRanges then
        desc = desc .. "\n\n(Equipped in 'stats' mode, grants:)"
        if self.attribBoosts then
            for k, v in pairs(self.attribBoosts) do
                local att = ix.attributes.list[k]
                if att and att.name then
                    desc = desc .. string.format("\n%s: +%d", att.name, v)
                else
                    desc = desc .. string.format("\n%s: +%d", k, v)
                end
            end
        elseif self.attribRanges then
            local randAttributes = self:GetData("attributes")
            if randAttributes then
                for attr, value in pairs(randAttributes) do
                    local attData = ix.attributes.list[attr]
                    if attData and attData.name then
                        desc = desc .. string.format("\n%s: +%d", attData.name, value)
                    else
                        desc = desc .. string.format("\n%s: +%d", attr, value)
                    end
                end
            else
                desc = desc .. "\n(No attributes generated yet.)"
            end
        end
    else
        desc = desc .. "\n\n(Can be equipped for appearance only, no stat boosts.)"
    end

    return desc
end

--------------------------------------------------------------------------------
-- OPTIONAL HOOKS
--------------------------------------------------------------------------------
function ITEM:OnEquipped()
    -- Called after item is fully equipped in either mode.
end

function ITEM:OnUnequipped()
    -- Called after item is fully unequipped.
end

--------------------------------------------------------------------------------
-- OVERRIDE THE DROP-SPAWN MODEL
--------------------------------------------------------------------------------
function ITEM:Spawn(position, angles)
    if ix.item.instances[self.id] then
        local client
        local entity = ents.Create("ix_item")
        entity:SetAngles(angles or Angle(0, 0, 0))
        entity:SetItem(self.id)
        entity:Spawn()

        if type(position) == "Player" then
            client = position
            position = position:GetItemDropPos(entity)
        end

        entity:SetPos(position)

        if IsValid(client) then
            entity.ixSteamID = client:SteamID()
            entity.ixCharID  = client:GetCharacter():GetID()
            entity:SetNetVar("owner", entity.ixCharID)
        end

        entity:SetModel(self.dropModel or self.model)

        hook.Run("OnItemSpawned", entity)
        return entity
    end
end

--------------------------------------------------------------------------------
-- REAPPLY ON CHARACTER LOAD (SERVER-SIDE)
--------------------------------------------------------------------------------
if SERVER then
    local baseID = ITEM.uniqueID or "pacoutfit"
    hook.Add("PlayerLoadedCharacter", "ReApplyPACOutfits_" .. baseID, function(client, character, oldCharacter)
        timer.Simple(0, function()
            if not IsValid(client) then return end
            local inv = character:GetInventory()
            if not inv then return end

            for _, v in pairs(inv:GetItems()) do
                if v.Base == baseID then
                    local isStats = v:GetData("equip")
                    local isLook  = v:GetData("equipLook")
                    if isStats or isLook then
                        client:AddPart(v.uniqueID, v)
                        v:SetData("pacHidden", false)

                        if isLook then
                            local hiddenID = v:GetData("hiddenStatsItemID")
                            if hiddenID then
                                local hiddenItem = ix.item.instances[hiddenID]
                                if hiddenItem and hiddenItem:GetData("equip") and hiddenItem:GetOwner() == client then
                                    hiddenItem:HidePAC(client)
                                end
                            end
                        end
                    end
                end
            end
        end)
    end)
end

print("[PAC MMO Outfit Base] Registered base:", ITEM.uniqueID)
