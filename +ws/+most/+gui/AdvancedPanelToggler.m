classdef AdvancedPanelToggler 
% Stateless class that knows how to resize GUIs for advanced-panel-ness,
% update UIControl toggle-buttons, etc. All necessary state is stored in
% figure UserData. This state is conceptually opaque, ie this class should
% handle all toggle-related actions.
    
    methods (Static)
        
        function tf = isFigToggleable(hFig)
            tf = ws.most.gui.AdvancedPanelToggler.isFigToggleInitted(hFig);
        end
        
        % initialize size toggability for a gui figure.
        % hFig: handle to GUI figure
        % hToggleCtrl: handle to uicontrol togglebutton
        % deltaPos: change in figure size
        function init(hFig,hToggleCtrl,deltaPos)
            assert(ishandle(hFig) && isscalar(hFig));
            assert(ishandle(hToggleCtrl) && isscalar(hToggleCtrl) && ...
                strcmp(get(hToggleCtrl,'Type'),'uicontrol') && ...
                strcmp(get(hToggleCtrl,'Style'),'togglebutton'));
            validateattributes(deltaPos,{'numeric'},{'scalar' 'real'});

            orientation = ws.most.gui.AdvancedPanelToggler.getToggleOrientation(hToggleCtrl);

            % write toggle state to hFig userData
            currentUserData = get(hFig,'UserData');            
            assert(isempty(currentUserData) || ...
                isstruct(currentUserData) && ~isfield(currentUserData,'toggle'), ...
                'Unexpected figure userdata.');
            
            currentUserData.toggle.toggleCtrlTag = get(hToggleCtrl,'Tag');
            currentUserData.toggle.orientation = orientation;
            currentUserData.toggle.deltaPos = deltaPos;
            set(hFig,'UserData',currentUserData);
        end
        
        % Toggle advanced-panel situation for hFig.
        % The toggle-button should already be "clicked" (to the new,
        % desired value) before making this call.
        function toggle(hFig)
            % For now use toggleAdvancedPanel; at some point
            % toggleAdvancedPanel may become obsolete and then we can
            % cut+paste that code here.

            assert(ws.most.gui.AdvancedPanelToggler.isFigToggleInitted(hFig), ...
                'Figure has not been toggle-initted.');
            ud = get(hFig,'UserData');
            
            hToggleCtrl = findobj(hFig,'Tag',ud.toggle.toggleCtrlTag);                       
            offset = ud.toggle.deltaPos;
            orientation = ud.toggle.orientation;            
            ws.most.gui.toggleAdvancedPanel(hToggleCtrl,offset,orientation);
        end  
        
        % This first "pushes" the toggle uicontrol button, then calls
        % toggle(). This method is the programmatic equivalent of
        % actually pushing the button.
        function pushToggleButtonAndToggle(hFig)            
            assert(ws.most.gui.AdvancedPanelToggler.isFigToggleInitted(hFig), ...
                'Figure has not been toggle-initted.');
            ud = get(hFig,'UserData');
            
            hToggleCtrl = findobj(hFig,'Tag',ud.toggle.toggleCtrlTag);
            
            % "push" togglebutton
            val = get(hToggleCtrl,'Value');
            val = mod(val+1,2);
            set(hToggleCtrl,'Value',val);
            
            ws.most.gui.AdvancedPanelToggler.toggle(hFig);
        end
        
        % return a struct to be used with loadToggleState.
        function s = saveToggleState(hFig)
            assert(ws.most.gui.AdvancedPanelToggler.isFigToggleInitted(hFig), ...
                'Figure has not been toggle-initted.');
            ud = get(hFig,'UserData');

            s = ud.toggle;
            
            % figure out current state of toggle button
            hToggleCtrl = findobj(hFig,'Tag',ud.toggle.toggleCtrlTag);
            s.toggleCtrlVal = get(hToggleCtrl,'Value');
        end
        
        % restore advanced-panel-toggleness to state saved in s.
        function loadToggleState(hFig,s)
            assert(ws.most.gui.AdvancedPanelToggler.isFigToggleInitted(hFig), ...
                'Figure has not been toggle-initted.');            
            ud = get(hFig,'UserData');
            
            assert(isequal(rmfield(s,'toggleCtrlVal'),ud.toggle));
            hToggleCtrl = findobj(hFig,'Tag',ud.toggle.toggleCtrlTag);
            val = get(hToggleCtrl,'value');
            if val~=s.toggleCtrlVal
                ws.most.gui.AdvancedPanelToggler.pushToggleButtonAndToggle(hFig);
            end
        end        
        
    end
    
    methods (Static,Access=private)
        
        function tf = isFigToggleInitted(hFig)
            ud = get(hFig,'UserData');
            tf = isstruct(ud) && isfield(ud,'toggle');
        end
        
        function orientation = getToggleOrientation(hCtrl)
            lbl = get(hCtrl,'String');
            switch lbl
                case {'/\' '\/'}
                    orientation = 'y';
                case {'<<' '>>'}
                    orientation = 'x';
                otherwise
                    assert(false);
            end
        end
        
    end
    
end
