local settings = require("resources/database/settings")

-- playerData is nested in events because my mental model
-- is unlike data that comes from Settings - this is data
-- that may initialize from Settings but is kept up-to-date
-- via events and called "eventsData". I renamed it "events"
-- because "eventsData.playerData" felt too redundant.

local events = {
    playerData = {
        inCombat = false,
        activeAspect = nil,
        combatStyle = nil,
        
        ranged = {
            activeAmmo = {
                icon = 0,
                name = '',
                configName = '',
            },
            quiverAmmo = {
                icon = 0,
                name = '',
                configName = '',
            },
            arrows = {
                bikArrows = {
                    stacks = 0,
                    remainingDuration = 0,
                },
                wenArrows = {
                    stacks = 0,
                    remainingDuration = 0,
                },
                deathsporeArrows = {
                    stacks = 0,
                    remainingDuration = 0,
                },
                splinteringArrows = {
                    stacks = 0,
                    remainingDuration = 0,
                }
            }
        }
    }
}



local function swapGaugeToCombatStyle(style)
    if settings.Get('generalSettings.automaticSwapping') == 'dynamic' then
        events.playerData.combatStyle = style
    end

    -- Only update if the combat style has changed
    if settings.Get('playerState.combatStyle') ~= style then
        settings.Set('playerState.combatStyle', style)
    end
end

local MAINHAND_SLOT = 4
local weaponCombatStyles = {
    [7] = "barehanded",
    [8] = "ranged",
    [9] = "ranged",
    [10] = "ranged",
}
local function checkEquippedMainhand()
    if settings.Get('generalSettings.automaticSwapping') ~= 'mainhand' then return end

    local worn = Inventory.Find(config.Inv.WORN)
    local wornObj = worn:GetSlot(MAINHAND_SLOT)

    if wornObj and wornObj.obj then
        local wornObjStyle = var.VarPlayer["COMBATV2_MAINHAND_STYLE"].value
        if wornObjStyle == nil then return end

        local combatStyle = weaponCombatStyles[wornObjStyle]

        if combatStyle then
            events.playerData.combatStyle = combatStyle
            settings.Set("playerState.combatStyle", combatStyle)
        end
    end
end

-- To match various Augmented & Dyed and alternate names like Trimmed
-- or Custom-Fitted a string match against the item's name will be used.
-- Such that it will match all variants of the item.
--
-- This was done because I didn't realize I could get data about the
-- last ability used to easily determine which special attack was used.
-- Instead, I'm checking what weapon they specced with.
local function returnEquippedMainhand()
    local worn = Inventory.Find(config.Inv.WORN)
    local wornObj = worn:GetSlot(4)

    if wornObj and wornObj.obj then
        return wornObj.obj.configName
    end
    return nil
end

-- This gets copy/pasted an awful lot with the times (counted in ServerLogic events)
-- mostly being hard-coded rather than derived. This is because many have an _END
-- without a _START and I didn't think to cache a _START value and increment it
-- myself with ServerLogic events to track _START irregardless if a varp is set.
-- As this could otherwise always be derived by `END - cachedServerLogic_START`




-- Treats the player as 'Out of Combat' if they bank, so the gauge doesn't block the bank UI
local function handleBank()
    events.playerData.inCombat = false
end

-- Dispatchers - the handler functions tell you what the varp being mapped for dispatch helps keep updated.
local VAR_TRANSMIT_HANDLERS = {
    BANK_TEMP = handleBank,
}




-- If the player has a targeted enemy, they are considered to be in, or starting, combat.
local function updateInCombatState()
    events.playerData.inCombat = 
        var.VarPlayer["COMBATV2_PLAYER_IS_IN_COMBAT"].value > 0
end




local checkOnce = false

local function updatePlayerData()
    -- Data that needs to be updated with each server tick to keep up-to-date
    -- with the player's known state.
    updateInCombatState()
   

    -- Data that only needs to be checked once after signing in
    if (not checkOnce) then
        swapGaugeToCombatStyle(settings.Get('playerState.combatStyle'))
        checkOnce = true
    end

end



-- I'm not sure if this is too often, but if this is
-- on ServerLogic instead the entire UI is always a tick
-- behind. Not sure if % 2'ing and running this half
-- as often matters at all or what the performance looks
-- like since most of the code is reads & simple boolean
-- or value check branches; no complex algorithms.
Event.Logic.Subscribe("updatePlayerData", function() 
    updatePlayerData()
end)

-- Check mainhand weapon each game tick for a swap
Event.ServerLogic.Subscribe("wornMainhand", function() 
    checkEquippedMainhand()
end)

return events
