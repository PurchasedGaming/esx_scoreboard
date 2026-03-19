local config = require 'config.server'
GlobalState = GlobalState or {}
GlobalState.illegalActions = config.illegalActions or {}

ESX = exports["es_extended"]:getSharedObject()

ESX.RegisterServerCallback('esx_scoreboard:getScoreboardData', function(source, cb)
    local xPlayers = ESX.GetExtendedPlayers()
    local totalPlayers = 0
    local policeCount = 0
    local onDutyAdmins = {}

    for _, xPlayer in pairs(xPlayers) do
        totalPlayers = totalPlayers + 1

        if xPlayer.job.name == 'police' then
            policeCount = policeCount + 1
        end

        if IsPlayerAceAllowed(xPlayer.source, 'admin') and xPlayer.get('metadata').optin then
            onDutyAdmins[xPlayer.source] = true
        end
    end

    cb({
        totalPlayers = totalPlayers,
        policeCount = policeCount,
        onDutyAdmins = onDutyAdmins
    })
end)

ESX.RegisterServerCallback('esx_scoreboard:getOnlinePlayers', function(source, cb)
    local xPlayers = ESX.GetExtendedPlayers()
    local players = {}

    for _, xPlayer in pairs(xPlayers) do
        local fullName = 'Unknown'

        local charInfo = xPlayer.get('charinfo')
        if charInfo and charInfo.firstname then
            fullName = charInfo.firstname .. ' ' .. charInfo.lastname
        elseif xPlayer.get('firstName') then
            fullName = xPlayer.get('firstName') .. ' ' .. (xPlayer.get('lastName') or '')
        elseif xPlayer.getName() then
            fullName = xPlayer.getName()
        end

        local id = xPlayer.source
        local jobLabel = xPlayer.job.label or xPlayer.job.name or 'Civilian'
        local onDuty = xPlayer.job.onduty and ' (On Duty)' or ''

        table.insert(players, {
            name = fullName,
            id   = id,
            job  = jobLabel .. onDuty,
        })
    end

    table.sort(players, function(a, b)
        return a.name < b.name
    end)

    cb(players)
end)

RegisterNetEvent('esx:setJob', function(job)
    TriggerClientEvent('esx_scoreboard:refresh', -1)
end)

local function setActivityBusy(name, bool)
    local illegalActions = GlobalState.illegalActions
    if illegalActions[name] then
        illegalActions[name].busy = bool
        GlobalState.illegalActions = illegalActions
    end
end

RegisterNetEvent('esx_scoreboard:SetActivityBusy', setActivityBusy)
exports('SetActivityBusy', setActivityBusy)
