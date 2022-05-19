lvg_ib_1 = class( nil )
lvg_ib_1.maxChildCount = -1
lvg_ib_1.maxParentCount = -1
lvg_ib_1.connectionInput = sm.interactable.connectionType.logic
lvg_ib_1.connectionOutput = sm.interactable.connectionType.logic -- none, logic, power, bearing, seated, piston, any
lvg_ib_1.colorNormal = sm.color.new(0xdf7000ff)
lvg_ib_1.colorHighlight = sm.color.new(0xef8010ff)
--lvg_ib_1.poseWeightCount = 1

local timeloaded = 0

--[[ client ]]
function lvg_ib_1.client_onCreate( self )

    sm.gui.chatMessage("#00FF00CLIENT SCRIPT LOADED")
    sm.gui.chatMessage("#000000------------------------")
    print ("loaded lvg_ib_1.client_onCreate script")
end
function lvg_ib_1.client_onRefresh( self ) 
 self:client_onCreate()
end

--gui--


--gui--
local debug = false
function lvg_ib_1.client_onUpdate( self, deltaTime )
   if debug == true then
    --debug--
    print("--------------------DEBUG INFO-----------------------")
    print(sm.localPlayer.getPlayer().character.worldPosition)
    print(" ")
    print("VER 1.5")
    print("-----------------------------------------------------")
    --debug--
   end
--does this every tick
end

local ti = 0
function lvg_ib_1.cl_guiInteract(self, button)
if button == "button1" then
        --
        if debug == true then sm.gui.chatMessage("#00FF00debug mode off | check console for info")
        else sm.gui.chatMessage("#00FF00debug mode on | check console for info") end
        print(sm.localPlayer.getPlayer().character.worldPosition)
       
        if debug == false then
            debug = true else debug = false
        end
        
       
        
        
        --
elseif button == "button2" then
        --
        print("#00FF00TEST2 button pressed")
        self.gui:close()
        self.gui:destroy()
        self.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/custom/test.layout")
        self.gui:open()
        self.gui:setButtonCallback( "button1", "cl_guiInteract" )
        self.gui:setButtonCallback( "button2", "cl_guiInteract" )
        self.gui:setButtonCallback( "button3", "cl_guiInteract" )
        self.gui:setButtonCallback( "button4", "cl_guiInteract" )
        --
    elseif button == "button3" then
        --
        print("#00FF00TEST3 button pressed")
        self.gui:close()
        self.gui:destroy()
        self.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/custom/test1.layout")
        self.gui:open()
        self.gui:setButtonCallback( "button1", "cl_guiInteract" )
        self.gui:setButtonCallback( "button2", "cl_guiInteract" )
        --
    elseif button == "button4" then
        --
        sm.gui.chatMessage("#00FF00comming soon..")
        sm.camera.setPosition( x[30], y[10], z[0.7] )
        --
      end
      end





function lvg_ib_1.client_onInteract(self)
    ti = ti + 1
    if ti == 1 then
        ----interact code from here----
        sm.gui.chatMessage("#00FF00interact script running")
        self.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/custom/test.layout")
        self.gui:open()
        self.gui:setButtonCallback( "button1", "cl_guiInteract" )
        self.gui:setButtonCallback( "button2", "cl_guiInteract" )
        self.gui:setButtonCallback( "button3", "cl_guiInteract" )
        self.gui:setButtonCallback( "button4", "cl_guiInteract" )
        
         ----to here----
    else if ti == 2 then ti = 0
    end
    end
end
--[[ server ]]
function lvg_ib_1.server_onCreate( self )
    sm.gui.chatMessage("#000000------------------------")
    sm.gui.chatMessage("#00FF00SERVER SCRIPT LOADED")
    print ("loaded lvg_ib_1.server_onCreate script")
end
function lvg_ib_1.server_onRefresh( self )
 self:server_onCreate()
end

function lvg_ib_1.server_onFixedUpdate( self, deltaTime )

end