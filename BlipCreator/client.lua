local ESX, QBCore = nil, nil
local blips = {}
local previewBlip = nil
local menuOpen = false

Citizen.CreateThread(function()
    if GetResourceState('es_extended') == 'started' then
        ESX = exports['es_extended']:getSharedObject()
    elseif GetResourceState('qb-core') == 'started' then
        QBCore = exports['qb-core']:GetCoreObject()
    end
end)

-- ============================================================================
-- BLIP CREATION / LOADING
-- ============================================================================

function CreateBlipFromData(data)
    local blip = AddBlipForCoord(data.coords.x, data.coords.y, data.coords.z)
    SetBlipSprite(blip, data.sprite)
    SetBlipColour(blip, data.color)
    SetBlipScale(blip, data.scale)
    SetBlipAsShortRange(blip, data.shortRange)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(data.name)
    EndTextCommandSetBlipName(blip)
    data.handle = blip
    return blip
end

RegisterNetEvent('blipcreator:client:loadBlips', function(data)
    for _, blip in pairs(blips) do
        if blip.handle then RemoveBlip(blip.handle) end
    end
    blips = data or {}
    for _, blip in pairs(blips) do
        CreateBlipFromData(blip)
    end
end)

RegisterNetEvent('blipcreator:client:refreshBlips', function(data)
    for _, blip in pairs(blips) do
        if blip.handle then RemoveBlip(blip.handle) end
    end
    blips = {}
    for _, blip in pairs(data) do
        CreateBlipFromData(blip)
    end
end)

-- ============================================================================
-- COMMAND / OPEN
-- ============================================================================

RegisterCommand(Config.Command, function()
    TriggerServerEvent('blipcreator:server:requestOpen')
end, false)

RegisterNetEvent('blipcreator:client:openMenu', function()
    OpenMainMenu()
end)

-- ============================================================================
-- MENUS
-- ============================================================================

function CountBlips()
    local count = 0
    for _ in pairs(blips) do count = count + 1 end
    return count
end

function CloseMenu()
    menuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeMenu' })
    if previewBlip then
        RemoveBlip(previewBlip)
        previewBlip = nil
    end
end

function OpenMainMenu()
    if menuOpen then return end
    menuOpen = true

    local coords = GetEntityCoords(PlayerPedId())
    local elements = {
        { label = '?? Create Blip Here', value = 'create' },
        { label = '?? Manage Blips (' .. CountBlips() .. ')', value = 'manage' },
        { label = '? Close', value = 'close' },
    }

    SendNUIMessage({
        action   = 'openMenu',
        title    = 'Blip Creator',
        subtitle = string.format('Position: %.2f, %.2f, %.2f', coords.x, coords.y, coords.z),
        elements = elements
    })
    SetNuiFocus(true, true)
end

function OpenManageMenu()
    if previewBlip then
        RemoveBlip(previewBlip)
        previewBlip = nil
    end

    -- Build a sorted array so ordering is stable between refreshes
    local list = {}
    for id, blip in pairs(blips) do
        table.insert(list, { id = id, blip = blip })
    end
    table.sort(list, function(a, b) return tostring(a.id) < tostring(b.id) end)

    local elements = {}
    for _, entry in ipairs(list) do
        table.insert(elements, {
            label = string.format('%s (ID: %s)', entry.blip.name, entry.id),
            value = 'blip_' .. entry.id,
            id    = entry.id
        })
    end
    table.insert(elements, { label = '?? Back', value = 'back' })

    SendNUIMessage({
        action   = 'openManage',
        title    = 'Manage Blips',
        elements = elements
    })
    SetNuiFocus(true, true)
end

-- ============================================================================
-- CREATION
-- ============================================================================

function StartCreation()
    local coords = GetEntityCoords(PlayerPedId())

    if previewBlip then
        RemoveBlip(previewBlip)
        previewBlip = nil
    end

    previewBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(previewBlip, Config.Defaults.sprite)
    SetBlipColour(previewBlip, Config.Defaults.color)
    SetBlipScale(previewBlip, Config.Defaults.scale)
    SetBlipAsShortRange(previewBlip, Config.Defaults.shortRange)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(Config.Defaults.name)
    EndTextCommandSetBlipName(previewBlip)

    SendNUIMessage({
        action   = 'openEditor',
        title    = 'Create Blip',
        isEdit   = false,
        blipData = {
            name       = Config.Defaults.name,
            sprite     = Config.Defaults.sprite,
            color      = Config.Defaults.color,
            scale      = Config.Defaults.scale,
            shortRange = Config.Defaults.shortRange,
            coords     = { x = coords.x, y = coords.y, z = coords.z }
        },
        sprites = Config.CommonSprites,
        colors  = Config.Colors
    })
    SetNuiFocus(true, true)
end

function UpdatePreview(data)
    if not previewBlip then return end
    SetBlipSprite(previewBlip, data.sprite)
    SetBlipColour(previewBlip, data.color)
    SetBlipScale(previewBlip, data.scale)
    SetBlipAsShortRange(previewBlip, data.shortRange)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(data.name)
    EndTextCommandSetBlipName(previewBlip)
end

function SaveNewBlip(data)
    if previewBlip then
        RemoveBlip(previewBlip)
        previewBlip = nil
    end
    TriggerServerEvent('blipcreator:server:addBlip', data)
    CloseMenu()
    TriggerEvent('chat:addMessage', { args = { '[Blip Creator]', 'Blip created successfully!' } })
end

function CancelCreation()
    if previewBlip then
        RemoveBlip(previewBlip)
        previewBlip = nil
    end
    OpenMainMenu()
end

-- ============================================================================
-- EDIT / DELETE
-- ============================================================================

function EditBlip(id)
    id = tonumber(id)
    local blip = blips[id]
    if not blip then
        print(('[BlipCreator][client] EditBlip: no blip with id %s'):format(tostring(id)))
        return
    end

    if previewBlip then
        RemoveBlip(previewBlip)
        previewBlip = nil
    end

    SendNUIMessage({
        action   = 'openEditor',
        title    = 'Edit Blip',
        isEdit   = true,
        editId   = id,
        blipData = {
            name       = blip.name,
            sprite     = blip.sprite,
            color      = blip.color,
            scale      = blip.scale,
            shortRange = blip.shortRange,
            coords     = blip.coords
        },
        sprites = Config.CommonSprites,
        colors  = Config.Colors
    })
    SetNuiFocus(true, true)
end

function DeleteBlip(id)
    id = tonumber(id)
    if not id then return end

    if blips[id] then
        if blips[id].handle then RemoveBlip(blips[id].handle) end
        blips[id] = nil
    end
    TriggerServerEvent('blipcreator:server:deleteBlip', id)
end

-- ============================================================================
-- NUI CALLBACKS
-- ============================================================================

RegisterNUICallback('menuSelect', function(data, cb)
    local value = data.value
    print(('[BlipCreator][client] menuSelect value=%s id=%s'):format(tostring(value), tostring(data.id)))

    if value == 'create' then
        StartCreation()
    elseif value == 'manage' then
        OpenManageMenu()
    elseif value == 'close' then
        CloseMenu()
    elseif value == 'back' then
        OpenMainMenu()
    elseif value == 'save' then
        SaveNewBlip(data.blipData)
    elseif value == 'cancel' then
        CancelCreation()
    elseif value == 'delete' then
        DeleteBlip(data.id)
        OpenManageMenu()
    elseif value == 'edit' then
        EditBlip(data.id)
    elseif value == 'updatePreview' then
        UpdatePreview(data.blipData)
    end
    cb('ok')
end)

RegisterNUICallback('updateBlip', function(data, cb)
    TriggerServerEvent('blipcreator:server:updateBlip', data.editId, data.blipData)
    CloseMenu()
    cb('ok')
end)

-- ============================================================================
-- ESC TO CLOSE
-- ============================================================================

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if menuOpen and IsControlJustPressed(0, 322) then -- ESC
            CloseMenu()
        end
    end
end)