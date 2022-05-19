dofile( "$SURVIVAL_DATA/Scripts/game/managers/UnitManager.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/managers/PesticideManager.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_harvestable.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_projectiles.lua" )

CreativeBaseWorld = class( nil )
--portal
dofile( "$CONTENT_DATA/Scripts/portal_projectiles.lua" )
local portalSize = sm.vec3.new(0.75, 0.1, 1.0)

function CreativeBaseWorld.server_onCreate( self )
	self.pesticideManager = PesticideManager()
	self.pesticideManager:sv_onCreate()

	--portal
	self.portals = {portal1 = nil, portal2 = nil}
	self.portalData = {directions = {portal1 = nil, portal2 = nil}, ticks = { portal1 = 0, portal2 = 0}}
	self.ignoreObjects = {}
	self.yeet = {}
end

function CreativeBaseWorld.client_onCreate( self )
	if self.pesticideManager == nil then
		assert( not sm.isHost )
		self.pesticideManager = PesticideManager()
	end
	self.pesticideManager:cl_onCreate()
end

function CreativeBaseWorld.sv_e_spawnNewCharacter( self, params )
	local spawnRayBegin = sm.vec3.new( params.x, params.y, 1024 )
	local spawnRayEnd = sm.vec3.new( params.x, params.y, -1024 )
	local valid, result = sm.physics.spherecast( spawnRayBegin, spawnRayEnd, 0.3 )
	local pos
	if valid then
		pos = result.pointWorld + sm.vec3.new( 0, 0, 0.4 )
	else
		pos = sm.vec3.new( params.x, params.y, 100 )
	end

	local character = sm.character.createCharacter( params.player, self.world, pos )
	params.player:setCharacter( character )
end


function CreativeBaseWorld.server_onFixedUpdate( self )
	self.pesticideManager:sv_onWorldFixedUpdate( self )

	--portal
	for k, v in pairs(self.yeet) do
		if v.tick < sm.game.getCurrentTick() then
			local char = v.player:getCharacter()
			if char then
				sm.physics.applyImpulse(char, v.dir * v.velocity * 100)
			end
			self.yeet[k] = nil
		end
	end
end

function CreativeBaseWorld.cl_n_pesticideMsg( self, msg )
	self.pesticideManager[msg.fn]( self.pesticideManager, msg )
end

function CreativeBaseWorld.server_onProjectileFire( self, firePos, fireVelocity, _, attacker, projectileUuid )
	if isAnyOf( projectileUuid, g_potatoProjectiles ) then
		local units = sm.unit.getAllUnits()
		for i, unit in ipairs( units ) do
			if InSameWorld( self.world, unit ) then
				sm.event.sendToUnit( unit, "sv_e_worldEvent", { eventName = "projectileFire", firePos = firePos, fireVelocity = fireVelocity, projectileUuid = projectileUuid, attacker = attacker })
			end
		end
	end
end

function CreativeBaseWorld.server_onInteractableCreated( self, interactable )
	g_unitManager:sv_onInteractableCreated( interactable )
end

function CreativeBaseWorld.server_onInteractableDestroyed( self, interactable )
	g_unitManager:sv_onInteractableDestroyed( interactable )
end

function CreativeBaseWorld.server_onProjectile( self, hitPos, hitTime, hitVelocity, _, attacker, damage, userData, hitNormal, target, projectileUuid )
	-- Notify units about projectile hit
	if isAnyOf( projectileUuid, g_potatoProjectiles ) then
		local units = sm.unit.getAllUnits()
		for i, unit in ipairs( units ) do
			if InSameWorld( self.world, unit ) then
				sm.event.sendToUnit( unit, "sv_e_worldEvent", { eventName = "projectileHit", hitPos = hitPos, hitTime = hitTime, hitVelocity = hitVelocity, attacker = attacker, damage = damage })
			end
		end
	end

	if projectileUuid == projectile_pesticide then
		local forward = sm.vec3.new( 0, 1, 0 )
		local randomDir = forward:rotateZ( math.random( 0, 359 ) )
		local effectPos = hitPos
		local success, result = sm.physics.raycast( hitPos + sm.vec3.new( 0, 0, 0.1 ), hitPos - sm.vec3.new( 0, 0, PESTICIDE_SIZE.z * 0.5 ), nil, sm.physics.filter.static + sm.physics.filter.dynamicBody )
		if success then
			effectPos = result.pointWorld + sm.vec3.new( 0, 0, PESTICIDE_SIZE.z * 0.5 )
		end
		self.pesticideManager:sv_addPesticide( self, effectPos, sm.vec3.getRotation( forward, randomDir ) )
	end

	if projectileUuid == projectile_glowstick then
		sm.harvestable.createHarvestable( hvs_remains_glowstick, hitPos, sm.vec3.getRotation( sm.vec3.new( 0, 1, 0 ), hitVelocity:normalize() ) )
	end

	if projectileUuid == projectile_explosivetape then
		sm.physics.explode( hitPos, 7, 2.0, 6.0, 25.0, "RedTapeBot - ExplosivesHit" )
	end

	--portal
	if projectileUuid == projectile_portal1 or projectileUuid == projectile_portal2 then
		local portal = projectileUuid == projectile_portal1 and "portal1" or "portal2"


		local rot = sm.vec3.getRotation(sm.vec3.new(0,1,0), hitVelocity:normalize())
		self.portalData.directions[portal] = hitVelocity:normalize()
		--try to get better rotation from collision buddy
		local success, result = sm.physics.raycast(hitPos - hitVelocity:normalize(), hitPos + hitVelocity:normalize())
		if success and result.valid and result.normalLocal then
			rot = sm.vec3.getRotation(sm.vec3.new(0,1,0), result.normalLocal)
			self.portalData.directions[portal] = result.normalLocal
		end
		self.network:sendToClients("cl_setEffect", {uuid = tostring(projectileUuid), pos = hitPos, rot = rot})


		if self.portals[portal] then
			sm.areaTrigger.destroy(self.portals[portal])
		end
		self.portals[portal] = sm.areaTrigger.createBox(portalSize, hitPos, rot)
		self.portals[portal]:bindOnEnter("sv_onEnterPortal", self )
		self.portals[portal]:bindOnExit("sv_onExitPortal", self )
		self.portals[portal]:bindOnProjectile("trigger_onProjectile", self )
	end
end

function CreativeBaseWorld.server_onCollision( self, objectA, objectB, collisionPosition, objectAPointVelocity, objectBPointVelocity, collisionNormal )
	g_unitManager:sv_onWorldCollision( self, objectA, objectB, collisionPosition, objectAPointVelocity, objectBPointVelocity, collisionNormal )
end

function CreativeBaseWorld.sv_e_clear( self )
	for _, body in ipairs( sm.body.getAllBodies() ) do
		for _, shape in ipairs( body:getShapes() ) do
			shape:destroyShape()
		end
	end
end

local function selectHarvestableToPlace( keyword )
	if keyword == "stone" then
		local stones = {
			hvs_stone_small01, hvs_stone_small02, hvs_stone_small03
			--hvs_stone_medium01, hvs_stone_medium02, hvs_stone_medium03,
			--hvs_stone_large01, hvs_stone_large02, hvs_stone_large03
		}
		return stones[math.random( 1, #stones )]
	elseif keyword == "tree" then
		local trees = {
			hvs_tree_birch01, hvs_tree_birch02, hvs_tree_birch03,
			hvs_tree_leafy01, hvs_tree_leafy02, hvs_tree_leafy03,
			hvs_tree_spruce01, hvs_tree_spruce02, hvs_tree_spruce03,
			hvs_tree_pine01, hvs_tree_pine02, hvs_tree_pine03
		}
		return trees[math.random( 1, #trees )]
	elseif keyword == "birch" then
		local trees = { hvs_tree_birch01, hvs_tree_birch02, hvs_tree_birch03 }
		return trees[math.random( 1, #trees )]
	elseif keyword == "leafy" then
		local trees = { hvs_tree_leafy01, hvs_tree_leafy02, hvs_tree_leafy03 }
		return trees[math.random( 1, #trees )]
	elseif keyword == "spruce" then
		local trees = {	hvs_tree_spruce01, hvs_tree_spruce02, hvs_tree_spruce03 }
		return trees[math.random( 1, #trees )]
	elseif keyword == "pine" then
		local trees = { hvs_tree_pine01, hvs_tree_pine02, hvs_tree_pine03 }
		return trees[math.random( 1, #trees )]
	end
	return nil
end

function CreativeBaseWorld.sv_e_onChatCommand( self, params )
	if params[1] == "/aggroall" then
		local units = sm.unit.getAllUnits()
		for _, unit in ipairs( units ) do
			sm.event.sendToUnit( unit, "sv_e_receiveTarget", { targetCharacter = params.player.character } )
		end
		sm.gui.chatMessage( "Hostiles received " .. params.player:getName() .. "'s position." )
	elseif params[1] == "/killall" then
		local units = sm.unit.getAllUnits()
		for _, unit in ipairs( units ) do
			unit:destroy()
		end
	elseif params[1] == "/place" then
		local harvestableUuid = selectHarvestableToPlace( params[2] )
		if harvestableUuid and params.aimPosition then
			local from = params.aimPosition + sm.vec3.new( 0, 0, 16.0 )
			local to = params.aimPosition - sm.vec3.new( 0, 0, 16.0 )
			local success, result = sm.physics.raycast( from, to, nil, sm.physics.filter.default )
			if success and result.type == "terrainSurface" then
				local harvestableYZRotation = sm.vec3.getRotation( sm.vec3.new( 0, 1, 0 ), sm.vec3.new( 0, 0, 1 ) )
				local harvestableRotation = sm.quat.fromEuler( sm.vec3.new( 0, math.random( 0, 359 ), 0 ) )
				local placePosition = result.pointWorld
				if params[2] == "stone" then
					placePosition = placePosition + sm.vec3.new( 0, 0, 2.0 )
				end
				sm.harvestable.createHarvestable( harvestableUuid, placePosition, harvestableYZRotation * harvestableRotation )
			end
		end
	end
end



--portal
function CreativeBaseWorld.sv_ignoreTeleport(self, args)
	local object = args.object
	local trigger = args.trigger
	local tick = args.tick
	table.insert(self.ignoreObjects, {object = object, trigger = trigger, tick = args.tick})
end

function CreativeBaseWorld.sv_onEnterPortal(self, trigger, results)
	if not (self.portals["portal1"] and self.portals["portal2"]) then
		return
	end

	local otherPortal = "portal1"
	local thisPortal = "portal2"
	if trigger == self.portals[otherPortal] then
		otherPortal = "portal2"
		thisPortal = "portal1"
	end

	if self.portalData.ticks[thisPortal] > sm.game.getCurrentTick() then
		return
	end

	for _,result in ipairs( results ) do
		if sm.exists( result ) then
			if type( result ) == "Character" then
				local player = result:getPlayer()
				if player then
					local dir = self.portalData.directions[otherPortal]
					local yaw = math.atan2( dir.y, dir.x ) - math.pi/2
					local pitch = math.asin( dir.z )
					local newCharacter = sm.character.createCharacter( player, self.world, self.portals[otherPortal]:getWorldPosition() + self.portalData.directions[otherPortal], yaw, pitch )
					local vel = result:getVelocity():length()
					player:setCharacter(newCharacter)
					self.yeet[#self.yeet] = {player = player, dir = self.portalData.directions[otherPortal], velocity = vel, tick = sm.game.getCurrentTick()}
					self.portalData.ticks[otherPortal] = sm.game.getCurrentTick() + 3
					return
				end


				local id = result.id
				for k, v in pairs(self.ignoreObjects) do
					if v.object == id then
						return
					end
				end

				local unit = result:getUnit()
				if unit then
					local uuid = result:getCharacterType()	
					local newUnit = sm.unit.createUnit(uuid, self.portals[otherPortal]:getWorldPosition())
					self.portalData.ticks[otherPortal] = sm.game.getCurrentTick() + 3
					self:sv_ignoreTeleport({object = id + 1, trigger = trigger})
					unit:destroy()
				end
			


			elseif type( result ) == "Body" and not result:isStatic() then
				local blueprint = sm.creation.exportToString(result, false, true)
				for _, shape in pairs(result:getCreationShapes()) do
					sm.shape.destroyShape(shape)
				end
				sm.creation.importFromString(self.world, blueprint, self.portals[otherPortal]:getWorldPosition(), sm.vec3.getRotation(sm.vec3.new(0,1,0), self.portalData.directions[otherPortal]))
				self.portalData.ticks[otherPortal] = sm.game.getCurrentTick() + 3
			end
		end
	end
end

function CreativeBaseWorld.sv_onExitPortal(self, trigger, results)
	for _,result in ipairs( results ) do
		if sm.exists( result ) then
			if type( result ) == "Character" then
				local id = result.id
				local newIgnore = {}
				for k, v in pairs(self.ignoreObjects) do
					if not v.object == id then
						table.insert(newIgnore, v)
					end
				end
				self.ignoreObjects = newIgnore
			end
		end
	end
end

function CreativeBaseWorld.trigger_onProjectile( self, trigger, hitPos, hitTime, hitVelocity, _, attacker, damage, userData, hitNormal, projectileUuid )
	local otherPortal = "portal1"
	local thisPortal = "portal2"
	if trigger == self.portals[otherPortal] then
		otherPortal = "portal2"
		thisPortal = "portal1"
	end
	sm.projectile.projectileAttack(projectileUuid, 69, self.portals[otherPortal]:getWorldPosition(), self.portalData.directions[otherPortal]*hitVelocity:length(), sm.player.getAllPlayers()[1])
	return true
end


function CreativeBaseWorld.client_onCreate(self)
	local effect1 = sm.effect.createEffect("ShapeRenderable")
    effect1:setParameter("uuid", sm.uuid.new("628b2d61-5ceb-43e9-8334-a4135566df7a"))
	effect1:setParameter("color", sm.color.new(0,0.5,1))
	effect1:setScale(portalSize)

	local effect2 = sm.effect.createEffect("ShapeRenderable")
    effect2:setParameter("uuid", sm.uuid.new("628b2d61-5ceb-43e9-8334-a4135566df7a"))
	effect2:setParameter("color", sm.color.new(1,0.5,0))
	effect2:setScale(portalSize)

	self.portalEffects = {}
	self.portalEffects[tostring(projectile_portal1)] = effect1
	self.portalEffects[tostring(projectile_portal2)] = effect2
end

function CreativeBaseWorld.cl_setEffect(self, args)
	local uuid = args.uuid
	local pos = args.pos
	local rot = args.rot

	self.portalEffects[uuid]:setPosition(pos)
	self.portalEffects[uuid]:setRotation(rot)
	self.portalEffects[uuid]:start()
end