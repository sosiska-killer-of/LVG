dofile( "$SURVIVAL_DATA/Scripts/game/managers/UnitManager.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_projectiles.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_meleeattacks.lua" )

MenuGame = class( nil )
MenuGame.enableLimitedInventory = false
MenuGame.enableRestrictions = false
MenuGame.enableFuelConsumption = false
MenuGame.enableAmmoConsumption = false
MenuGame.enableUpgrade = true

g_godMode = true

-- Game Server side --

function MenuGame.server_onCreate( self )
	local worldScriptFilename = "$GAME_DATA/Scripts/game/worlds/MenuWorld.lua"
	local worldScriptClass = "MenuWorld"
	self.menuWorld = sm.world.createWorld( worldScriptFilename, worldScriptClass )
	sm.game.bindChatCommand( "/save", {}, "sv_onChatCommand", "Save the menu creation" )

	g_unitManager = UnitManager()
	g_unitManager:sv_onCreate( nil )
end

function MenuGame.server_onFixedUpdate( self, timeStep )
	g_unitManager:sv_onFixedUpdate()
 end

function MenuGame.server_onPlayerJoined( self, player, newPlayer )
	print( player.name, "joined the game" )
	g_unitManager:sv_onPlayerJoined( player )
	if not sm.exists( self.menuWorld ) then
		sm.world.loadWorld( self.menuWorld )
	end
	self.menuWorld:loadCell( 2, 0, player, "sv_cellLoaded" )
end

function MenuGame.server_onSaveLevel( self )
	sm.event.sendToWorld( self.menuWorld, "sv_e_export" )
end

function MenuGame.sv_onChatCommand( self, params )
	if params[1] == "/save" then
		sm.event.sendToWorld( self.menuWorld, "sv_e_export" )
	end
end

function MenuGame.sv_cellLoaded( self, world, x, y, player )
	local params = { player = player, x = x, y = y }
	sm.event.sendToWorld( world, "sv_e_spawnNewCharacter", params )
	if player.id == 1 then
		sm.event.sendToWorld( self.menuWorld, "sv_e_loadMenuCreations" )
	end
end

-- Game Client side --

function MenuGame.client_onCreate( self )
	sm.game.setTimeOfDay( 0.5 )
	sm.render.setOutdoorLighting( 0.5 )

	if g_unitManager == nil then
		assert( not sm.isHost )
		g_unitManager = UnitManager()
	end
	g_unitManager:cl_onCreate()

	self.cl = {}
	if sm.isHost then
		sm.game.bindChatCommand( "/clear", {}, "cl_onChatCommand", "Clear creations from the menu" )
		self.cl.confirmClearGui = sm.gui.createGuiFromLayout( "$GAME_DATA/Gui/Layouts/PopUp/PopUp_YN.layout" )
		self.cl.confirmClearGui:setButtonCallback( "Yes", "cl_onButtonClick" )
		self.cl.confirmClearGui:setButtonCallback( "No", "cl_onButtonClick" )
		self.cl.confirmClearGui:setText( "Title", "#{MENU_YN_TITLE_ARE_YOU_SURE}" )
		self.cl.confirmClearGui:setText( "Message", "#{MENU_YN_MESSAGE_CLEAR_MENU}" )
	end
end

function MenuGame.cl_onChatCommand( self, params )
	if params[1] == "/clear" then
		self.cl.confirmClearGui:open()
	end
end

function MenuGame.cl_onButtonClick( self, name )
	if name == "Yes" then
		self.cl.confirmClearGui:close()
		self.network:sendToServer( "sv_clear" )
	elseif name == "No" then
		self.cl.confirmClearGui:close()
	end
end

function MenuGame.sv_clear( self )
	sm.event.sendToWorld( self.menuWorld, "sv_e_clear" )
end