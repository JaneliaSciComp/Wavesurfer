classdef Robot
    %ROBOT A thin wrapper around the 'java.awt.Robot' class.
    %   Detailed explanation goes here
    
    
    %% CLASS PROPERTIES
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    properties (Hidden, Access=private)
        
        hRobot; % The java.awt.Robot object.
    
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    
    
    %% CONSTRUCTOR/DESTRUCTOR
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    methods
        function obj = Robot()
            obj.hRobot = java.awt.Robot;
        end
        
        function delete(obj)
            delete(obj.hRobot);
        end
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    
    
    methods (Access=public)
        
        function moveAbsolute(obj,pos)
            scrSize = get(0,'ScreenSize');
            obj.hRobot.mouseMove(pos(1),scrSize(4)-pos(2));
        end
        
        function moveRelative(obj,pos)
            currentPos = get(0,'PointerLocation');
            obj.moveAbsolute([currentPos(1) + pos(1) currentPos(2) + pos(2)]);
        end
        
        function moveToUiComponent(obj,uiComponent,doFocus,offset)
			if nargin < 4 || isempty(offset)
				offset = [0 0];
			end
			
            if nargin < 3 || isempty(doFocus)
               doFocus = false; 
            end
            
            parentFig = ancestor(uiComponent,'figure');
            parentPos = getpixelposition(parentFig);
            uiPos = getpixelposition(uiComponent);
            obj.moveAbsolute([parentPos(1) + uiPos(1) + uiPos(3)/2.0 + offset(1), parentPos(2) + uiPos(2) + uiPos(4)/2.0 + offset(2)]);
            
            if doFocus
                figure(parentFig);
                drawnow;
            end
        end
        
        function leftClick(obj)
            obj.click(java.awt.event.InputEvent.BUTTON1_MASK);
        end
        
        function middleClick(obj)
            obj.click(java.awt.event.InputEvent.BUTTON2_MASK);
        end
        
        function rightClick(obj)
            obj.click(java.awt.event.InputEvent.BUTTON3_MASK);
        end
        
        function click(obj,button)
            obj.hRobot.mousePress(button);
            obj.hRobot.mouseRelease(button);
		end
    
		function leftRelease(obj)
			obj.release(java.awt.event.InputEvent.BUTTON1_MASK);
		end
		
		function release(obj,button)
			obj.hRobot.mouseRelease(button);
		end
		
        function doubleClick(obj)
            obj.click(java.awt.event.InputEvent.BUTTON1_MASK);
            obj.click(java.awt.event.InputEvent.BUTTON1_MASK);
		end
		
		function keyPress(obj,key)
			switch key
				case 'shift'
					obj.keyAction('Press',java.awt.event.KeyEvent.VK_SHIFT);
				case 'ctrl'
					obj.keyAction('Press',java.awt.event.KeyEvent.VK_CONTROL);
				otherwise
					% assume the user has provided a valid keycode
					obj.keyAction('Press',key);
			end
		end

		function keyRelease(obj,key)
			switch key
				case 'shift'
					obj.keyAction('Release',java.awt.event.KeyEvent.VK_SHIFT);
				case 'ctrl'
					obj.keyAction('Release',java.awt.event.KeyEvent.VK_CONTROL);
				otherwise
					% assume the user has provided a valid keycode
					obj.keyAction('Release',key);
			end
		end
		
		function keyAction(obj,action,keyCode)
			eval(['obj.hRobot.key' action '(keyCode);'])
		end
    end
    
end

