ESX = {}
ESX.Players = {}
ESX.UsableItemsCallbacks = {}
ESX.Items = {}
ESX.ServerCallbacks = {}
ESX.TimeoutCount = -1
ESX.CancelledTimeouts = {}
ESX.LastPlayerData = {}
ESX.Pickups = {}
ESX.PickupId = 0
ESX.Jobs = {}
DebugQuerys = false
AddEventHandler('esx:getSharedObject', function(cb)
	cb(ESX)
end)

function getSharedObject()
	return ESX
end

function LetsFKGO()
	print('\27[42m[MongoDB][Core Framework] CONECTADO AO DB. Carregando Infos do Server\27[0m\n')
		exports.DatabaseAPI:find({collection = "items", query = {}}, function (success, result)
			if not success then
				print("[MongoDB] [ESBridge] ERRO AO OBTER A LISTA DE ITENS: ")
				return
			end
			-- DEBUG
			if DebugQuerys then
				print("\n** LISTA DE ITENS OBTIDA")
				for k, v in pairs(result[1]) do
					print("* "..tostring(k).." = \""..tostring(v).."\"")
				end			
			end

			for k,v in ipairs(result) do
				ESX.Items[v.name] = {
					label = v.label,
					weight = v.weight,
					rare = v.rare,
					canRemove = v.can_remove
				}
			end
		end)
		exports.DatabaseAPI:find({collection = "jobs", query = {}}, function (success, result)
			if not success then
				print("[MongoDB] [ESBridge] ERRO AO OBTER A LISTA DE EMPREGOS: ")
				return
			end
			-- DEBUG
			if DebugQuerys then
				print("\n** LISTA DE EMPREGOS OBTIDA")
				for k, v in pairs(result[1]) do
					print("* "..tostring(k).." = \""..tostring(v).."\"")
				end			
			end
			for i=1, #result do
				ESX.Jobs[result[i].name] = result[i]
				ESX.Jobs[result[i].name].grades = {}
			end
		end)

	exports.DatabaseAPI:find({collection = "job_grades", query = {}}, function (success, result)
		if not success then
			print("[MongoDB] [ESBridge] ERRO AO OBTER A LISTA DE CARGOS DOS EMPREGOS: ")
			return
		end
		-- DEBUG
		if DebugQuerys then
			print("\n** LISTA CARGOS DE ITENS OBTIDA")
			for k, v in pairs(result[1]) do
				print("* "..tostring(k).." = \""..tostring(v).."\"")
			end			
		end
		for i=1, #result do
			if ESX.Jobs[result[i].job_name] then
				ESX.Jobs[result[i].job_name].grades[tostring(result[i].grade)] = result[i]
			else
				print(('es_extended: invalid job "%s" from table job_grades ignored!'):format(result[i].job_name))
			end
		end
	
		for k,v in pairs(ESX.Jobs) do
			if next(v.grades) == nil then
				ESX.Jobs[v.name] = nil
				print(('es_extended: ignoring job "%s" due to missing job grades!'):format(v.name))
			end
		end
	end)
end
AddEventHandler("onDatabaseConnect", function (databaseName)
	LetsFKGO()
	loaded = true
end)	
if exports["DatabaseAPI"]:isConnected() == true and not loaded then
	LetsFKGO()
	loaded = true
end


AddEventHandler('esx:playerLoaded', function(source)
	local xPlayer         = ESX.GetPlayerFromId(source)
	local accounts        = {}
	local items           = {}
	local xPlayerAccounts = xPlayer.getAccounts()
	local xPlayerItems    = xPlayer.getInventory()

	for i=1, #xPlayerAccounts, 1 do
		accounts[xPlayerAccounts[i].name] = xPlayerAccounts[i].money
	end

	for i=1, #xPlayerItems, 1 do
		items[xPlayerItems[i].name] = xPlayerItems[i].count
	end

	ESX.LastPlayerData[source] = {
		accounts = accounts,
		items    = items
	}
end)

RegisterServerEvent('esx:clientLog')
AddEventHandler('esx:clientLog', function(msg)
	RconPrint(msg .. "\n")
end)

RegisterServerEvent('esx:triggerServerCallback')
AddEventHandler('esx:triggerServerCallback', function(name, requestId, ...)
	local _source = source

	ESX.TriggerServerCallback(name, requestID, _source, function(...)
		TriggerClientEvent('esx:serverCallback', _source, requestId, ...)
	end, ...)
end)
