ESX = exports["es_extended"]:getSharedObject()

local config = require 'config.client'

local isScoreboardOpen = false
local onDutyAdmins = {}

local function shouldShowPlayerId(targetServerId)
    if config.idVisibility == 'all' then return true end
    if onDutyAdmins[GetPlayerServerId(PlayerId())] then return true end
    if config.idVisibility == 'admin_only' then return false end
    if config.idVisibility == 'admin_excluded' and onDutyAdmins[targetServerId] then return false end
    return true
end

local function openScoreboard()
    ESX.TriggerServerCallback('esx_scoreboard:getScoreboardData', function(data)
        if not data then return end

        local totalPlayers = data.totalPlayers
        local policeCount = data.policeCount
        onDutyAdmins = data.onDutyAdmins or {}

        local adminCount = 0
        for _ in pairs(onDutyAdmins) do
            adminCount += 1
        end

        local options = {}

        if config.showPlayers then
            local playersItem = {
                title       = ("Players: %s/%s"):format(totalPlayers, config.maxPlayers),
                description = ("Police Online: %s"):format(policeCount),
                icon        = "fas fa-users",
                iconColor   = "#60A5FA",
                readOnly    = true,
            }

            if config.enablePlayerList then
                playersItem.readOnly = false
                playersItem.arrow = true
                playersItem.onSelect = function()
                    ESX.TriggerServerCallback('esx_scoreboard:getOnlinePlayers', function(playerList)
                        if not playerList or #playerList == 0 then
                            lib.notify({ title = 'Scoreboard', description = 'No players found', type = 'inform' })
                            return
                        end

                        local playerOptions = {}

                        table.insert(playerOptions, {
                            title = ('Online Players (%s)'):format(#playerList),
                            description = 'Sorted by name',
                            icon = 'fas fa-list',
                            readOnly = true,
                            disabled = true,
                        })

                        for _, p in ipairs(playerList) do
                            table.insert(playerOptions, {
                                title       = p.name,
                                description = ('ID: %s • %s'):format(p.id, p.job),
                                icon        = 'fas fa-user',
                                iconColor   = '#A1A1AA',
                                readOnly    = true,
                            })
                        end

                        table.insert(playerOptions, {
                            title = 'Back to Scoreboard',
                            icon = 'fas fa-arrow-left',
                            iconColor = '#F87171',
                            onSelect = function()
                                openScoreboard()
                            end,
                        })

                        exports.lation_ui:registerMenu({
                            id = 'scoreboard_players_list',
                            title = 'Online Players',
                            position = 'top-right',
                            options = playerOptions
                        })

                        exports.lation_ui:showMenu('scoreboard_players_list')
                    end)
                end
            end

            table.insert(options, playersItem)
        end

        if config.showAdmins then
            table.insert(options, {
                title     = ("Admins On Duty: %s"):format(adminCount),
                icon      = "fas fa-shield-halved",
                iconColor = "#3B82F6",
                readOnly  = true
            })
        end

        local illegalGlobal = GlobalState.illegalActions or {}
        local illegalConfig = config.illegalActions or {}

        local available, busyList, locked = {}, {}, {}

        for key, cfg in pairs(illegalConfig) do
            local state = illegalGlobal[key] or {}
            local busy = state.busy or false
            local requiredPolice = cfg.minimumPolice or 0

            local statusText, icon, iconColor

            if busy then
                statusText = "In Progress"
                icon = "fas fa-hourglass-half"
                iconColor = "#F59E0B"
            elseif policeCount < requiredPolice then
                statusText = ("Requires %s Police"):format(requiredPolice)
                icon = "fas fa-lock"
                iconColor = "#EF4444"
            else
                statusText = "Available"
                icon = "fas fa-check-circle"
                iconColor = "#10B981"
            end

            local item = {
                title       = cfg.label or key,
                description = statusText,
                icon        = icon,
                iconColor   = iconColor,
                readOnly    = true,
            }

            if cfg.image then
                item.image = cfg.image
            end

            if busy then
                table.insert(busyList, item)
            elseif policeCount < requiredPolice then
                table.insert(locked, item)
            else
                table.insert(available, item)
            end
        end

        for _, item in ipairs(available) do table.insert(options, item) end
        for _, item in ipairs(busyList) do table.insert(options, item) end
        for _, item in ipairs(locked) do table.insert(options, item) end

        exports.lation_ui:registerMenu({
            id       = 'scoreboard_menu',
            title    = 'Scoreboard',
            position = 'top-right',
            options  = options,
            canClose = true,
            onExit   = function()
                isScoreboardOpen = false
            end
        })

        exports.lation_ui:showMenu('scoreboard_menu')
        isScoreboardOpen = true
    end)
end

RegisterNetEvent('esx_scoreboard:refresh', function()
    if isScoreboardOpen then
        openScoreboard()
    end
end)

local function closeScoreboard()
    exports.lation_ui:hideMenu('scoreboard_menu')
    isScoreboardOpen = false
end

RegisterCommand('scoreboard', function()
    if config.toggle then
        if isScoreboardOpen then
            closeScoreboard()
        else
            openScoreboard()
        end
    else
        openScoreboard()
    end
end)

RegisterKeyMapping('scoreboard', 'Open Scoreboard', 'keyboard', config.openKey)

CreateThread(function()
    while true do
        if isScoreboardOpen then
            local players = ESX.Game.GetPlayersInArea(GetEntityCoords(PlayerPedId()), config.visibilityDistance)

            for _, playerId in ipairs(players) do
                local ped = GetPlayerPed(playerId)
                local serverId = GetPlayerServerId(playerId)

                if DoesEntityExist(ped) and shouldShowPlayerId(serverId) then
                    local coords = GetEntityCoords(ped)

                    DrawText3D(coords.x, coords.y, coords.z + 1.0, '[' .. serverId .. ']')
                end
            end

            Wait(0)
        else
            Wait(500)
        end
    end
end)

function DrawText3D(x, y, z, text)
    SetDrawOrigin(x, y, z, 0)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextCentre(true)
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(0.0, 0.0)
    ClearDrawOrigin()
end
