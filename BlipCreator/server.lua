local blips = {}
local blipFile = 'blips.json'

-- ============================================================================
-- PERMISSIONS
-- ============================================================================

local function getPlayerIdentifierSet(src)
    local set = {}
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        set[id] = true
    end
    return set
end

local function getCitizenId(src)
    if GetResourceState('es_extended') == 'started' then
        local ESX = exports['es_extended']:getSharedObject()
        local xPlayer = ESX.GetPlayerFromId(src)
        return xPlayer and xPlayer.identifier or nil
    elseif GetResourceState('qb-core') == 'started' then
        local QBCore = exports['qb-core']:GetCoreObject()
        local Player = QBCore.Functions.GetPlayer(src)
        return Player and Player.PlayerData.citizenid or nil
    end
    return nil
end

local function hasPermission(src)
    if src == 0 then return false end

    local ids = getPlayerIdentifierSet(src)

    for id in pairs(Config.AllowedIdentifiers) do
        if ids[id] then
            if Config.DebugPermissions then
                print(('[BlipCreator] ALLOW %s (matched %s)'):format(src, id))
            end
            return true
        end
    end

    if next(Config.AllowedCitizenIds) ~= nil then
        local cid = getCitizenId(src)
        if cid and Config.AllowedCitizenIds[cid] then
            if Config.DebugPermissions then
                print(('[BlipCreator] ALLOW %s (matched citizenid %s)'):format(src, cid))
            end
            return true
        end
    end

    if Config.DebugPermissions then
        print(('[BlipCreator] DENY  %s'):format(src))
        for _, id in ipairs(GetPlayerIdentifiers(src)) do
            print(('  - %s'):format(id))
        end
    end
    return false
end

-- ============================================================================
-- PERSISTENCE
-- ============================================================================

local function loadBlips()
    local file = LoadResourceFile(GetCurrentResourceName(), blipFile)
    if file and file ~= '' then
        local ok, decoded = pcall(json.decode, file)
        blips = (ok and decoded) or {}
    else
        blips = {}
    end
    print(('[BlipCreator] Loaded %d blips'):format(#blips))
end

local function saveBlips()
    SaveResourceFile(GetCurrentResourceName(), blipFile, json.encode(blips, { indent = true }), -1)
end

-- ============================================================================
-- COMMANDS
-- ============================================================================

RegisterCommand('myids', function(src)
    if src == 0 then return end
    print(('[BlipCreator] Identifiers for %s (%s):'):format(GetPlayerName(src), src))
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        print(('  - %s'):format(id))
    end
    TriggerClientEvent('chat:addMessage', src, {
        args = { '[Blip Creator]', 'Your identifiers were printed to the server console.' }
    })
end, false)

-- ============================================================================
-- NETWORK EVENTS
-- ============================================================================

RegisterNetEvent('blipcreator:server:requestOpen', function()
    local src = source
    if hasPermission(src) then
        TriggerClientEvent('blipcreator:client:openMenu', src)
    else
        TriggerClientEvent('chat:addMessage', src, {
            args = { '[Blip Creator]', 'You are not whitelisted for this command.' }
        })
    end
end)

AddEventHandler('playerJoining', function()
    local src = source
    Citizen.SetTimeout(2000, function()
        TriggerClientEvent('blipcreator:client:loadBlips', src, blips)
    end)
end)

RegisterNetEvent('blipcreator:server:addBlip', function(data)
    local src = source
    if not hasPermission(src) then return end
    if type(data) ~= 'table' or type(data.coords) ~= 'table' then return end

    table.insert(blips, {
        name       = tostring(data.name or 'Blip'),
        sprite     = math.floor(tonumber(data.sprite) or 1),
        color      = math.floor(tonumber(data.color) or 0),
        scale      = tonumber(data.scale) or 1.0,
        shortRange = data.shortRange and true or false,
        coords     = { x = data.coords.x, y = data.coords.y, z = data.coords.z }
    })
    saveBlips()
    TriggerClientEvent('blipcreator:client:refreshBlips', -1, blips)
end)

RegisterNetEvent('blipcreator:server:updateBlip', function(id, data)
    local src = source
    if not hasPermission(src) then return end

    id = tonumber(id)
    if not id or not blips[id] then return end
    if type(data) ~= 'table' then return end

    blips[id].name       = tostring(data.name or blips[id].name)
    blips[id].sprite     = math.floor(tonumber(data.sprite) or blips[id].sprite)
    blips[id].color      = math.floor(tonumber(data.color) or blips[id].color)
    blips[id].scale      = tonumber(data.scale) or blips[id].scale
    blips[id].shortRange = data.shortRange and true or false
    if data.coords and data.coords.x then
        blips[id].coords = { x = data.coords.x, y = data.coords.y, z = data.coords.z }
    end
    saveBlips()
    TriggerClientEvent('blipcreator:client:refreshBlips', -1, blips)
end)

RegisterNetEvent('blipcreator:server:deleteBlip', function(id)
    local src = source
    if not hasPermission(src) then return end

    id = tonumber(id)
    if not id or not blips[id] then return end

    table.remove(blips, id)
    saveBlips()
    TriggerClientEvent('blipcreator:client:refreshBlips', -1, blips)
end)

-- ============================================================================
-- INIT
-- ============================================================================

loadBlips()