ESX.Trace = function(str)
	if Config.EnableDebug then
		print('ESX> ' .. str)
	end
end

ESX.SetTimeout = function(msec, cb)
	local id = ESX.TimeoutCount + 1

	SetTimeout(msec, function()
		if ESX.CancelledTimeouts[id] then
			ESX.CancelledTimeouts[id] = nil
		else
			cb()
		end
	end)

	ESX.TimeoutCount = id

	return id
end

ESX.ClearTimeout = function(id)
	ESX.CancelledTimeouts[id] = true
end

ESX.RegisterServerCallback = function(name, cb)
	ESX.ServerCallbacks[name] = cb
end

ESX.TriggerServerCallback = function(name, requestId, source, cb, ...)
	if ESX.ServerCallbacks[name] ~= nil then
		ESX.ServerCallbacks[name](source, cb, ...)
	else
		print('[CBR Framework] [ALERTA]: SERVER CALLBACK => [' .. name .. '] NÃO EXISTE')
	end
end

ESX.SavePlayer = function(xPlayer, cb)
	local asyncTasks = {}
	xPlayer.setLastPosition(xPlayer.getCoords())

	-- User accounts
	for i=1, #xPlayer.accounts, 1 do
		if ESX.LastPlayerData[xPlayer.source].accounts[xPlayer.accounts[i].name] ~= xPlayer.accounts[i].money then
			table.insert(asyncTasks, function(cb)
				exports.DatabaseAPI:updateOne({ collection="user_accounts", query = { identifier = xPlayer.identifier,  name = xPlayer.accounts[i].name }, update = { ["$set"] = {money = xPlayer.accounts[i].money} } }, function (success, users)
					if not success then
						print("[MongoDB] [ESBridge] ERRO AO SALVAR DATA DE CONTAS DO USUARIO: "..tostring(users))
						return
					end	
					cb()		
				end)
			end)
			ESX.LastPlayerData[xPlayer.source].accounts[xPlayer.accounts[i].name] = xPlayer.accounts[i].money
		end
	end

	-- Inventory items
	for i=1, #xPlayer.inventory, 1 do
		if ESX.LastPlayerData[xPlayer.source].items[xPlayer.inventory[i].name] ~= xPlayer.inventory[i].count then
			table.insert(asyncTasks, function(cb)
				exports.DatabaseAPI:updateOne({ collection="user_inventory", query = { identifier = xPlayer.identifier,  item = xPlayer.inventory[i].name}, update = { ["$set"] = {count = xPlayer.inventory[i].count} } }, function (success, users)
					if not success then
						print("[MongoDB] [ESBridge] ERRO AO SALVAR ITENS DO INVENTARIO DO USUARIO: "..tostring(users))
						return
					end	
					cb()		
				end)				
			end)

			ESX.LastPlayerData[xPlayer.source].items[xPlayer.inventory[i].name] = xPlayer.inventory[i].count
		end
	end

	-- Job, loadout and position
	table.insert(asyncTasks, function(cb)
		exports.DatabaseAPI:updateOne({ collection="users", query = { identifier = xPlayer.identifier}, update = { ["$set"] = {job = xPlayer.job.name, job_grade = xPlayer.job.grade, loadout = json.encode(xPlayer.getLoadout()), position = json.encode(xPlayer.getLastPosition())} } }, function (success, users)
			if not success then
				print("[MongoDB] [ESBridge] ERRO AO SALVAR LOADOUT E POSIÇÃO DO USUARIO: "..tostring(users))
				return
			end	
			cb()		
		end)		
	end)

	Async.parallel(asyncTasks, function(results)
		RconPrint('[USUARIO SALVO] ' .. xPlayer.name .. "^7\n")

		if cb ~= nil then
			cb()
		end
	end)
end

ESX.SavePlayers = function(cb)
	local asyncTasks = {}
	local xPlayers   = ESX.GetPlayers()

	for i=1, #xPlayers, 1 do
		table.insert(asyncTasks, function(cb)
			local xPlayer = ESX.GetPlayerFromId(xPlayers[i])
			ESX.SavePlayer(xPlayer, cb)
		end)
	end

	Async.parallelLimit(asyncTasks, 8, function(results)
		RconPrint('[SALVO] Todos os Jogadores' .. "\n")

		if cb ~= nil then
			cb()
		end
	end)
end

ESX.StartDBSync = function()
	function saveData()
		ESX.SavePlayers()
		SetTimeout(10 * 60 * 1000, saveData)
	end

	SetTimeout(10 * 60 * 1000, saveData)
end

ESX.GetPlayers = function()
	local sources = {}

	for k,v in pairs(ESX.Players) do
		table.insert(sources, k)
	end

	return sources
end


ESX.GetPlayerFromId = function(source)
	return ESX.Players[tonumber(source)]
end

ESX.GetPlayerFromIdentifier = function(identifier)
	for k,v in pairs(ESX.Players) do
		if v.identifier == identifier then
			return v
		end
	end
end

ESX.RegisterUsableItem = function(item, cb)
	ESX.UsableItemsCallbacks[item] = cb
end

ESX.UseItem = function(source, item)
	ESX.UsableItemsCallbacks[item](source)
end

ESX.GetItemLabel = function(item)
	if ESX.Items[item] ~= nil then
		return ESX.Items[item].label
	end
end

ESX.CreatePickup = function(type, name, count, label, playerId)
	local pickupId = (ESX.PickupId == 65635 and 0 or ESX.PickupId + 1)
	local xPlayer = ESX.GetPlayerFromId(playerId)

	ESX.Pickups[pickupId] = {
		type  = type,
		name  = name,
		count = count,
		label = label,
		coords = xPlayer.getCoords()
	}

	TriggerClientEvent('esx:pickup', -1, pickupId, label, playerId)
	ESX.PickupId = pickupId
end

ESX.DoesJobExist = function(job, grade)
	grade = tostring(grade)

	if job and grade then
		if ESX.Jobs[job] and ESX.Jobs[job].grades[grade] then
			return true
		end
	end

	return false
end