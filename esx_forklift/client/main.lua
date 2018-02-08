--******************************************
--    ESX_FORKLIFT, BASED ON MY ESX_BUS   **
--	  									  **
--    VERSION 0.0.0.0.0.0.0.0.0.0.0.0.1	  **
--	  									  **
--     Coded and tested in ~2 hours so:   **
--              - it's quite messy        **
--              - might contain glitches  **
--			    - no localization         **
--                                        **
--               ENJOY                    **
--******************************************
--========================================--
--===========KEY MAPPING==================--
local Keys = {
	["ESC"] = 322, ["F1"] = 288, ["F2"] = 289, ["F3"] = 170, ["F5"] = 166, ["F6"] = 167, ["F7"] = 168, ["F8"] = 169, ["F9"] = 56, ["F10"] = 57, 
	["~"] = 243, ["1"] = 157, ["2"] = 158, ["3"] = 160, ["4"] = 164, ["5"] = 165, ["6"] = 159, ["7"] = 161, ["8"] = 162, ["9"] = 163, ["-"] = 84, ["="] = 83, ["BACKSPACE"] = 177, 
	["TAB"] = 37, ["Q"] = 44, ["W"] = 32, ["E"] = 38, ["R"] = 45, ["T"] = 245, ["Y"] = 246, ["U"] = 303, ["P"] = 199, ["["] = 39, ["]"] = 40, ["ENTER"] = 18,
	["CAPS"] = 137, ["A"] = 34, ["S"] = 8, ["D"] = 9, ["F"] = 23, ["G"] = 47, ["H"] = 74, ["K"] = 311, ["L"] = 182,
	["LEFTSHIFT"] = 21, ["Z"] = 20, ["X"] = 73, ["C"] = 26, ["V"] = 0, ["B"] = 29, ["N"] = 249, ["M"] = 244, [","] = 82, ["."] = 81,
	["LEFTCTRL"] = 36, ["LEFTALT"] = 19, ["SPACE"] = 22, ["RIGHTCTRL"] = 70, 
	["HOME"] = 213, ["PAGEUP"] = 10, ["PAGEDOWN"] = 11, ["DELETE"] = 178,
	["LEFT"] = 174, ["RIGHT"] = 175, ["TOP"] = 27, ["DOWN"] = 173,
	["NENTER"] = 201, ["N4"] = 108, ["N5"] = 60, ["N6"] = 107, ["N+"] = 96, ["N-"] = 97, ["N7"] = 117, ["N8"] = 61, ["N9"] = 118
}
--========================================--
--=========GET SHARED OBJ=================--
ESX = nil				--esx defaults to nil
local playerData = {}	--player ""object""
Citizen.CreateThread(function()
    while ESX == nil do													--while esx is not available
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)--try to acquire it
        Citizen.Wait(0)
    end
end)
--========================================--
--==========JOB VARIABLES=================--
local onDuty = false	   --if player is on a 'mission'
local isInMarker = false   --if player is inside a marker
local menuIsOpen = false   --if menu is displayed
local taskPoints = {}	   --assigned task coordinates will be placed here
local forkBlips = {}       --esx_forklift blips will be placed here
local currentZone = 'none'
local Blips = {}		   --GPS blip array
local packetsDelivered = 0 --number of packets delivered
local currentJob = 'none'  --current task (deliver or pickup)
local currentBox = nil	   --store box

local lastDelivery = nil   --last delivery index
local lastPickup = nil	   --last pickup index

local zOffset = -0.65	--how much below player Z the marker should be drawn *CURRENTLY NOT IN USE*
local hintToDisplay = "no hint to display"				--default to no hint
local hintIsShowed = false								--default to hint hidden
--========================================--
--==========JOB GLOBALS=================--
local currentVehicle = nil												--store car spawned for player, idk if I am going to use this anyways
local currentPlate = ''												--store plate for current car

--========================================--
--===NON INTEGER INDEXED ARRAY FUNCTIONS==--
function sizeOfTable (tab)
  local count = 0
  for k, v in pairs(tab) do
    count = count + 1
  end
  return count
end

function elementAt(tab, indx)
 
  local count = 0
  local ret = nil
  for k, v in pairs(tab) do
    count = count + 1
	if count == indx then
	ret = v
	break
	end
  end
  return ret
end
--========================================--
--============NET EVENTS==================--
RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)	--on player load		
    playerData = xPlayer								--get player data from esx	
    refreshBlips()										--refresh blips 
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)	--when player changes jobs this will be triggered
  playerData.job = job						--update previously acquired player data
  onDuty = false							--set player as off-duty
  deleteBlips()								--delete existing blips
  refreshBlips()							--refresh blips
end)

--========================================--
--=============BLIP FUNCTIONS=============--
function drawBlip(coords, icon, text)

  local blip = AddBlipForCoord(coords.x, coords.y, coords.z)	--create blip on map
  
  SetBlipSprite (blip, icon)		--set sprite 'image'
  SetBlipDisplay(blip, 4)			--set blip display style
  SetBlipScale  (blip, 0.9)			--set blip scale
  SetBlipColour (blip, 3)			--set blip color
  SetBlipAsShortRange(blip, true)	--set visibility on mini-map to regular
	
  BeginTextCommandSetBlipName("STRING")	
  AddTextComponentString(text)		--set text argument as blip name in game
  EndTextCommandSetBlipName(blip)	--quit
  table.insert(forkBlips, blip)	    --insert to busBlips table where it can later be accessed and removed

end

function refreshBlips()
	if playerData.job.name ~= nil and playerData.job.name == 'fork' then 	--if player is a bus 
		drawBlip(Config.locker, 280, "Trukkikuskin pukukoppi")			 	--draw locker room on the map
		drawBlip(Config.carSpawner, 479, "Trukin lunastus")					--draw job starting point
		drawBlip(Config.carDelete, 490, "Trukin palautus")					--draw checkout point 
	end
end

function deleteBlips()
  if forkBlips[1] ~= nil then 	--if the first element exists
    for i = 1, #forkBlips, 1 do	--loop
      RemoveBlip(forkBlips[i])	--remove each blip
      forkBlips[i] = nil		--by assigning nil
    end
  end
end

--========================================--
--=============TOP LEFT HINT==============--
Citizen.CreateThread(function()
  while true do										--loop like there is no tomorrow
    Citizen.Wait(1)
    if hintIsShowed then							--if hint should be drawn
      SetTextComponentFormat("STRING")				--component format -> string
      AddTextComponentString(hintToDisplay)			--get text from global variable
      DisplayHelpTextFromStringLabel(0, 0, 1, -1)	--set it loose
    end
  end
end)
--========================================--
--==========DISPLAY MARKER================--
function displayMarker(coords) --draws a marker for given frame
	DrawMarker(0, coords.x, coords.y, coords.z + 0.75, 0.0, 0.0, 0.0, 0, 0.0, 0.0, 1.0, 1.0, 1.0, 15, 15, 255, 100, false, true, 2, false, false, false, false) --who puts this many arguments in one function? rofl
end
--========================================--
--==========WORK FUNCTIONS================--
function isMyCar()
	if currentPlate == GetVehicleNumberPlateText(GetVehiclePedIsIn(GetPlayerPed(-1), false)) then --compare current plate with the vehicle player is driving
		return true
	else
		return false
	end
end

function spawnFork()							--spawns forklift
	
	local vehicleModel = GetHashKey('forklift')	--get hash key of forklift
	RequestModel(vehicleModel)					--request model by hash
	
	while not HasModelLoaded(vehicleModel) do	--wait until the model has been loaded by ?client?
		Citizen.Wait(0)
	end
	
	currentCar = CreateVehicle(vehicleModel, Config.carSpawnPoint.x, Config.carSpawnPoint.y, Config.carSpawnPoint.z, Config.carSpawnPoint.h, true, false)	--create vehicle
	SetVehicleHasBeenOwnedByPlayer(currentCar,  true)														--set owned by player so he can use the locks
	SetEntityAsMissionEntity(currentCar,  true,  true)														--this step makes the vehicle persistent :)
	SetVehicleNumberPlateText(currentCar, "HOMO" .. math.random(1000, 9999))								--create 'random' plate
	local id = NetworkGetNetworkIdFromEntity(currentCar)													--get player's network id
	SetNetworkIdCanMigrate(id, true)																		--I have absolutely no idea what this does, but decided to included it since it's in every car spawn script																																	
	TaskWarpPedIntoVehicle(GetPlayerPed(-1), currentCar, -1)												--Warp player inside the freshly spawned vehicle
	local props = {																							--vehicle properties
		modEngine       = 1,
		modTransmission = 1,
		modSuspension   = 1,
		modTurbo        = true,																				--just to install turbo :D
	}
	ESX.Game.SetVehicleProperties(currentCar, props)
	Wait(1000)																								--Wait a second to avoid any glitches that might occur
	
	currentPlate = GetVehicleNumberPlateText(GetVehiclePedIsIn(GetPlayerPed(-1), false))
end

function trackBox()
	Citizen.CreateThread(function()
		while currentJob == 'pickup' do
			Citizen.Wait(5)
			if currentBox ~= nil and DoesEntityExist(currentBox) then
				local coords = GetEntityCoords(currentBox)
				setGPS(coords)
				
				if playerIsInside(coords, 4) then
					goDeliver()
				end
				if playerIsInside(coords, Config.pickupDistance) then 
					--[[ Do not enable, totally useless here since inmarker check thread overrides this anyways
					isInMarker = true
					hintIsShowed = true
					hintToDisplay = "Nosta trukkilava piikeille ja vie merkittyyn paikkaan."
					currentZone = 'none' ]]--
				end
				if playerIsInside(coords, 100) then
					local temp = {x = coords.x, y = coords.y, z = coords.z + Config.boxZ}
					displayMarker(temp)
				end
			end
		end
	end)
end

function spawnBox(coords)
	Citizen.CreateThread(function()
		repeat
			Citizen.Wait(500)
		until boxCanSpawn(taskPoints['deliver'])
		
		ESX.Game.SpawnObject('prop_boxpile_07d', {
			x = coords.x,
			y = coords.y,
			z = coords.z
		}, function(obj)
			SetEntityHeading(obj, coords.h)
			PlaceObjectOnGroundProperly(obj)
			currentBox = obj
		end)
		
		--trackBox()
	end)
end

function deleteBox()
	--local object = GetClosestObjectOfType(coords.x,  coords.y,  coords.z,  3.0,  GetHashKey('prop_boxpile_07d'), false, false, false)
	if currentBox ~= nil and DoesEntityExist(currentBox) then
		DeleteEntity(currentBox)
		return true
	end
	return false
end

function deleteCurrentBox()
	if currentBox ~= nil and DoesEntityExist(currentBox) then
		DeleteEntity(currentBox)
	end
end

function giveWork()
	
	if lastDelivery == nil then
		lastDelivery = 0
	end 
	if lastPickup == nil then
		lastPickup = 0
	end
	
	local indA = 0
	local indB = 0

	repeat 
		indA = math.random(1, #Config.objPoints)	
	until indA ~= lastPickup
	local temp = Config.objPoints[indA]
	taskPoints['pickup'] = { x = temp.x, y = temp.y, z = temp.z, h = temp.h}
	
	repeat
		indB = math.random(1, #Config.objPoints)
	until indB ~= indA and indB ~= lastDelivery and isFar(taskPoints['pickup'], Config.objPoints[indB], Config.minDistance)
	local temp2 = Config.objPoints[indB]
	
	taskPoints['deliver'] = { x = temp2.x, y = temp2.y, z = temp2.z, h = temp2.h}
	
	lastPickup = indA
	lastDelivery = indB
end

function boxIsInside(coords)
	--local object = GetClosestObjectOfType(coords.x,  coords.y,  coords.z,  3.0,  GetHashKey('prop_boxpile_07d'), false, false, false)
	if currentBox ~= nil and DoesEntityExist(currentBox) then
        local objCoords = GetEntityCoords(currentBox)
        local distance  = GetDistanceBetweenCoords(coords.x,  coords.y,  coords.z,  objCoords.x,  objCoords.y,  objCoords.z,  true)
		return distance < 1.25
	else
		return false
	end
end

function boxCanSpawn(coords)
	local object = GetClosestObjectOfType(coords.x,  coords.y,  coords.z,  3.0,  GetHashKey('prop_boxpile_07d'), false, false, false)
	if DoesEntityExist(object) then
        local objCoords = GetEntityCoords(object)
        local distance  = GetDistanceBetweenCoords(coords.x,  coords.y,  coords.z,  objCoords.x,  objCoords.y,  objCoords.z,  true)
		return distance > 5.0
	else
		return true
	end
end


function goDeliver()
	Citizen.CreateThread(function()
		ESX.ShowNotification('Toimita trukkilava merkittyyn paikkaan.')
		setGPS(taskPoints['deliver'])
		currentJob = 'deliver'
	end)
end

function goPickup()
	Citizen.CreateThread(function()
		ESX.ShowNotification('Hae trukkilava merkitystä paikasta.')
		setGPS(taskPoints['pickup'])
		currentJob = 'pickup'
		trackBox()
	end)
	spawnBox(taskPoints['pickup'])
end

function nextJob()
	--lastDelivery = taskPoints['delivery']
	--lastPickup = taskPoints['pickup']
	packetsDelivered = packetsDelivered + 1
	giveWork()
	goPickup()
end

function startWork()
	packetsDelivered = 0
	spawnFork()
	giveWork()
	goPickup()
end

function deleteCar()
	local entity = GetVehiclePedIsIn(GetPlayerPed(-1), false)	--get vehicle player is in
	ESX.Game.DeleteVehicle(entity)								--delete it
end

function getPaid()
	setGPS(0)													--rip gps
	local playerPed = GetPlayerPed(-1)
	if IsPedInAnyVehicle(playerPed) and isMyCar() then			--player successfully returned the bus
		deleteCar()												--delete players car
		TriggerServerEvent('esx_fork:getPaid', packetsDelivered * Config.pay) --pay accordingly
	else														--if player didn't return the forklift
		ESX.ShowNotification('~r~Missä trukki?')
		local amount = 400										--charge 100-400 EUR
		if packetsDelivered < 2 then							--if player delivered less than 2 packets
			amount = 1200										--charge 900-1200 EUR
		end
		ESX.ShowNotification('~w~Voittosumma: ~r~ -' .. amount .. ' ~w~euroa.')
	end
	currentJob = 'none'												--reset current mission
	currentPlate = ''												--reset current plate
	currentVehicle = nil											--remove current vehicle from variables
	packetsDelivered = 0											--reset packetsDelivered
	taskPoints = {}													--reset taskPoints
	deleteCurrentBox()												--delete last box spawned by player
end

--=========IF NEXT POINT IS FAR ENOUGH===--
function isFar(coords1, coords2, distance) 
	local vecDiffrence = GetDistanceBetweenCoords(coords1x, coords1.y, coords1.z, coords2.x, coords2.y, coords2.z, false)
	return vecDiffrence > distance			--returns true if next point is far enough. Kinda useless tho.
end

--========================================--
--==========SET GPS TO NEXT===============--
function setGPS(coords)
	if Blips['fork'] ~= nil then 	--if blips clean exists
		RemoveBlip(Blips['fork'])	--remove
		Blips['fork'] = nil			--remove from table 'assigning a nil value to a table variable will remove that variable in lua'
	end
	if coords ~= 0 then
		Blips['fork'] = AddBlipForCoord(coords.x, coords.y, coords.z)		--add new blip on the map
		SetBlipRoute(Blips['buzz'], true)									--set GPS to point this blip
	end
end
--========================================--
--======IF PLAYER IS INSIDE MARKER========--
function playerIsInside(coords, distance) 	--check whether player is inside a marker
	local playerCoords = GetEntityCoords(GetPlayerPed(-1))
	local vecDiffrence = GetDistanceBetweenCoords(playerCoords, coords.x, coords.y, coords.z, false)
	return vecDiffrence < distance			--returns true if player is within the given distance
end
--========================================--
--===========TASK TRIGGER 'SWITCH'========--
function taskTrigger(zone)					--WHY THE FUCK LUA DOESN'T HAVE SWITCHES ??? @ WUT
	if zone == 'locker' then				--player wants to change clothes
		openMenu()
	elseif zone == 'start' then				--player needs an assignment
		startWork()
	elseif zone == 'pay' then				--player is going to get paid
		getPaid()
	end
end
--========================================--
--==========BOX DELIVER THREAD============--
Citizen.CreateThread(function()
	while true do																		--loop 
		Citizen.Wait(50)
		if playerData.job ~= nil and playerData.job.name == "fork" and onDuty then
			if currentJob == 'deliver' and taskPoints['deliver'] ~= nil and playerIsInside(taskPoints['deliver'], 5.5) and boxIsInside(taskPoints['deliver']) then
				if deleteBox() then
					nextJob()
				end
			--[[  MOVED TO TRACKBOX
			elseif currentJob == 'pickup' and taskPoints['pickup'] ~= nil and playerIsInside(taskPoints['pickup'], 4.5) then
				goDeliver()
			end ]]--
			end
		end
	end
end)
--========================================--
--======INSIDE MARKER CHECK THREAD========--
Citizen.CreateThread(function()
	while true do																		--loop 
		Citizen.Wait(2)																	-- <0 ms is okay when nothing is drawn
		--=====check for inside marker=====-
		if menuIsOpen == false then 
			if playerData.job ~= nil and playerData.job.name == "fork" and playerIsInside(Config.locker, 2.5) then 				--if player is inside locker marker
				isInMarker = true
				hintIsShowed = true																	--set hint visible
				hintToDisplay = "Paina E vaihtaaksesi vaatteita"									--set hint string
				currentZone = 'locker'																--set current zone for action parsing
			elseif onDuty and taskPoints['deliver'] == nil and playerIsInside(Config.carSpawner, 2.5) then	--if player is inside the job assignment
				isInMarker = true
				hintIsShowed = true
				hintToDisplay = "Paina E aloittaaksesi työt"
				currentZone = 'start'
			elseif onDuty and currentJob == 'deliver' and taskPoints['deliver'] ~= nil and playerIsInside(taskPoints['deliver'], Config.pickupDistance) then --if player is on the next task location
				isInMarker = true
				hintIsShowed = true
				hintToDisplay = "Siirrä trukkilava merkittyyn paikkaan."
				currentZone = 'none' --[[ MOVED TO TRACKBOX AND FOUND TO BE USELESS THERE. LULZ
			elseif onDuty and currentJob == 'pickup' and taskPoints['pickup'] ~= nil and playerIsInside(taskPoints['pickup'], Config.pickupDistance) then --if player is on the next task location
				isInMarker = true
				hintIsShowed = true
				hintToDisplay = "Nosta trukkilava piikeille ja vie merkittyyn paikkaan."
				currentZone = 'none' ]]--
			elseif playerData.job ~= nil and playerData.job.name == "fork" and currentPlate ~= '' and playerIsInside(Config.carDelete, 1.5) then  				--if player is inside paycheck aka car delete marker
				isInMarker = true
				hintIsShowed = true
				hintToDisplay = "Paina E palauttaaksesi trukki"
				currentZone = 'pay'
			else																				--if player is nowhere near markers
				isInMarker = false
				hintIsShowed = false
				hintToDisplay = "No hint to display"
				currentZone = 'none'
			end
			--=====check for controls=====-
			if IsControlJustReleased(0, Keys["E"]) and isInMarker then
				taskTrigger(currentZone)														--blow kiss, fire a gun
			end
			
		end
	end
end)
--========================================--
--=========MARKER DRAW THREAD=============--
Citizen.CreateThread(function()
	while true do																			--loop 
		Citizen.Wait(1)																		--cant sleep too long since markers are drawn
		if playerData.job ~= nil and playerData.job.name == "fork" and playerIsInside(Config.locker, 100) then 	--if player is inside locker marker draw distance
			displayMarker(Config.locker)
		end
		if onDuty and currentJob == 'none' and playerIsInside(Config.carSpawner, 100) then			--if player is inside the job assignment and has no current assignments, draw within distance
			displayMarker(Config.carSpawner)
		end
		if onDuty and currentJob == 'deliver' and playerIsInside(taskPoints['deliver'], 100) then 			--if player is inside delivery point 
			displayMarker(taskPoints['deliver'])
		end
		--[[
		if onDuty and currentJob == 'pickup' and playerIsInside(taskPoints['pickup'], 100) then 			--if player is inside pickup point 
			displayMarker(taskPoints['pickup']) 
		end]]--
		if playerData.job ~= nil and playerData.job.name == "fork" and onDuty and currentPlate ~= '' and playerIsInside(Config.carDelete, 100) then  		--if player is inside paycheck marker draw distance
			displayMarker(Config.carDelete)
		end																				--if player is somewhere else, no markers bitch
	end
end)
--========================================--
--===============MENU=====================--
function openMenu()									--I have added comments and made some minor changes
  menuIsOpen = true
  ESX.UI.Menu.CloseAll()							--Close everything ESX.Menu related				

  ESX.UI.Menu.Open(
    'default', GetCurrentResourceName(), 'locker',			--locker room menu
    {
      title    = "Pukukoppi",								--set title
      elements = {
        {label = "Työvaatteet", value = 'fork_wear'},		--work clothes selection
        {label = "Arkivaatteet", value = 'everyday_wear'}	--everyday clothes selection
      }
    },
    function(data, menu)									--on data selection
      if data.current.value == 'everyday_wear' then			--if everyday clothes are selected
        onDuty = false										--GTFO duty
        ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin)	--call ESX_Skin to get desired skin
            TriggerEvent('skinchanger:loadSkin', skin)						--after receiving cb, load skin on player
        end)
      end
      if data.current.value == 'fork_wear' then
        onDuty = true
        ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin, jobSkin)
          if skin.sex == 0 then
              TriggerEvent('skinchanger:loadClothes', skin, jobSkin.skin_male)
          else
              TriggerEvent('skinchanger:loadClothes', skin, jobSkin.skin_female)
          end
        end)
      end
      menu.close()											--close menu after selection
	  menuIsOpen = false
    end,
    function(data, menu)
      menu.close()
	  menuIsOpen = false
    end
  )
end

