dofile( "$SURVIVAL_DATA/Scripts/game/managers/UnitManager.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/managers/PesticideManager.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_harvestable.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_projectiles.lua" )

CreativeBaseWorld = class( nil )

function CreativeBaseWorld.server_onCreate( self )
	self.pesticideManager = PesticideManager()
	self.pesticideManager:sv_onCreate()
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