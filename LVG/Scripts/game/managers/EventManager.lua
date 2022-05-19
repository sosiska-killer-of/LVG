dofile "$SURVIVAL_DATA/Scripts/game/survival_constants.lua"
dofile "$SURVIVAL_DATA/Scripts/game/util/Timer.lua"

EventManager = class( nil )

local SaveTickInterval = 10

function EventManager.sv_onCreate( self )
	self.sv = {}
	self.sv.tileStorageKeys = {}
	self.sv.tileStorage = {}
	self.sv.tileStorageDirtyList = {}

	self.sv.saveTimer = Timer()
	self.sv.saveTimer:start( SaveTickInterval )
	self.sv.saveTimer.count = SaveTickInterval
end

--------------------------------------------------------------------------------

function EventManager.sv_getTileStorageKey( self, worldId, x, y )
	local cellTileStorageKeys = self.sv.tileStorageKeys[worldId]

	if cellTileStorageKeys == nil then
		self.sv.tileStorageKeys[worldId] = sm.storage.load( "tsk_"..worldId )
		cellTileStorageKeys = self.sv.tileStorageKeys[worldId]
	end

	if cellTileStorageKeys == nil then
		return nil
	end
	if cellTileStorageKeys.indoor then
		return cellTileStorageKeys.worldKey
	end
	if cellTileStorageKeys.cellKeys[y] == nil then
		return nil
	end
	return cellTileStorageKeys.cellKeys[y][x]
end

--------------------------------------------------------------------------------

function EventManager.sv_getTileStorageKeyFromObject( self, userdataObject )
	if userdataObject and isAnyOf( type( userdataObject ), { "Character", "Harvestable", "Interactable" } ) then
		local worldId, worldPosition
		if type( userdataObject ) == "Character" then
			worldId = userdataObject:getWorld().id
			worldPosition = userdataObject.worldPosition
		elseif type( userdataObject ) == "Harvestable" then
			worldId = userdataObject:getWorld().id
			if userdataObject:isKinematic() then
				worldPosition = userdataObject.initialPosition
			else
				worldPosition = userdataObject.worldPosition
			end
		elseif type( userdataObject ) == "Interactable" then
			if userdataObject.body then
				worldId = userdataObject.body:getWorld().id
			end
			if userdataObject.shape then
				worldPosition = userdataObject.shape.worldPosition
			end
		end
		if worldId and worldPosition then
			local cellX = math.floor( worldPosition.x / 64 )
			local cellY = math.floor( worldPosition.y / 64 )
			return self:sv_getTileStorageKey( worldId, cellX, cellY )
		end
		return nil
	end
	sm.log.warning( "Tried to get tile storage key for an unsupported type: "..type( userdataObject ) )
	return nil
end

--------------------------------------------------------------------------------

function EventManager.sv_getTileStorage( self, tileStorageKey )
	if self.sv.tileStorage[tileStorageKey] == nil then
		self.sv.tileStorage[tileStorageKey] = sm.storage.load( tileStorageKey ) or {}
	end
	return self.sv.tileStorage[tileStorageKey]
end

--------------------------------------------------------------------------------

function EventManager.sv_setValue( self, tileStorageKey, name, value )
	if self.sv.tileStorage[tileStorageKey] == nil then
		self.sv.tileStorage[tileStorageKey] = sm.storage.load( tileStorageKey ) or {}
	end
	self.sv.tileStorage[tileStorageKey][name] = value
	self.sv.tileStorageDirtyList[tileStorageKey] = true
end

function EventManager.sv_getValue( self, tileStorageKey, name )
	if self.sv.tileStorage[tileStorageKey] == nil then
		self.sv.tileStorage[tileStorageKey] = sm.storage.load( tileStorageKey ) or {}
	end
	return self.sv.tileStorage[tileStorageKey][name]
end

--------------------------------------------------------------------------------

function EventManager.sv_onFixedUpdate( self )

	if not self.sv.saveTimer:done() then
		self.sv.saveTimer:tick()
	end

	--if self.sv.saveTimer:done() and #self.sv.tileStorageDirtyList ~= {} then
	if #self.sv.tileStorageDirtyList ~= {} then
		for tileStorageKey, _ in pairs( self.sv.tileStorageDirtyList ) do
			sm.storage.saveAndSync( tileStorageKey, self.sv.tileStorage[tileStorageKey] )
		end
		self.sv.saveTimer:reset()
		self.sv.tileStorageDirtyList = {}
	end
end

--------------------------------------------------------------------------------

function EventManager.sv_triggerEvent( self, tileStorageKey, eventName )
	if self.sv.tileStorage[tileStorageKey] == nil then
		self.sv.tileStorage[tileStorageKey] = sm.storage.load( tileStorageKey ) or {}
	end
	local event = self.sv.tileStorage[tileStorageKey][eventName]
	-- TODO setup events that can be triggered
	print( "EVENT:", eventName, event )
	if event then
		--if event.effectTags then
		--	for _, effectTag in ipairs( event.effectTags ) do
		--		local effectData = self:sv_getValue( self.sv.tileStorageKey, effectTag )
		--		sm.effect.playEffect( effectData.name, effectData.worldPosition, nil, effectData.worldRotation )
		--	end
		--end

		if event.activationTags then
			for _, activationTag in ipairs( event.activationTags ) do
				local activation = self:sv_getValue( self.sv.tileStorageKey, activationTag )
				if activation and activation.registered then
					for _, kinematic in ipairs( activation.registered ) do
						if sm.exists( kinematic ) then
							sm.event.sendToHarvestable( kinematic, "sv_e_activate" )
						end
					end
				end
			end
		end

	end

end