ESX = nil

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end) --acquire ESX

RegisterServerEvent('esx_fork:getPaid')
AddEventHandler('esx_fork:getPaid', function(amount)
	local xPlayer = ESX.GetPlayerFromId(source)		--get xPlayer
	xPlayer.addMoney(math.floor(amount))	
end)

RegisterServerEvent('esx_fork:getPunished')
AddEventHandler('esx_fork:getPunished', function(amount)
	local xPlayer = ESX.GetPlayerFromId(source)		       --get xPlayer
	xPlayer.removeMoney(math.random(amount - 300, amount)) --remove money from player
end)


