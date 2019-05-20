classdef LabelledEdit < handle
    properties (Dependent)
        Parent
        LabelString
        EditString
        UnitsString
        Position  % This is the position of the edit box
        Callback
        HorizontalAlignment
        Tag
        Enable
    end        
    
    properties (Access=private)
        LabelText_
        Edit_
        UnitsText_
    end
    
    methods
        function self = LabelledEdit(varargin)
            propertyValuePairsAsCellArray = varargin ;
            propertyValueStruct = ws.structFromPropertyValuePairs(propertyValuePairsAsCellArray) ;
            propertyNames = fieldnames(propertyValueStruct) ;
            
            % Figure out the parent
            if ismember('Parent', propertyNames) ,
                parent = propertyValueStruct.Parent ;
            else
                parent = gcf() ;
            end
            
            % Create the widgets
            self.LabelText_ = ws.uicontrol('Parent', parent, 'Style', 'text') ;
            self.Edit_ = ws.uicontrol('Parent', parent, 'Style', 'edit') ;            
            self.UnitsText_ = ws.uicontrol('Parent', parent, 'Style', 'text') ;            
            
            % Set the remaining properties, using the usual setters
            propertyNamesWithoutParent = setdiff(propertyNames, {'Parent'}) ;            
            for i = 1:length(propertyNamesWithoutParent) ,
                propertyName = propertyNamesWithoutParent{i} ;
                self.(propertyName) = propertyValueStruct.(propertyName) ;
            end            
        end
        
        function delete(self)  %#ok<INUSD>
        end
        
        function result = get.Tag(self)
            result = self.Edit_.Tag ;
        end
        
        function result = get.Position(self)
            result = self.Edit_.Position ;
        end
        
        function set.Position(self, newValue)
            position = newValue ;
            self.Edit_.Position = position ;
            editOffset = position(1:2) ;
            editSize = position(3:4) ;
            ws.positionEditLabelAndUnitsBang(self.LabelText_, self.Edit_, self.UnitsText_, ...
                                             editOffset(1), editOffset(2), editSize(1)) ;            
        end
        
        function set.Callback(self, newValue)
            self.Edit_.Callback = newValue ;
        end
        
        function set.Tag(self, newValue)
            self.Edit_.Tag = newValue ;
        end
        
        function set.LabelString(self, newValue)
            self.LabelText_.String = newValue ;
        end
        
        function set.EditString(self, newValue)
            self.Edit_.String = newValue ;
        end
        
        function set.UnitsString(self, newValue)
            self.UnitsText_.String = newValue ;
        end
        
        function result = get.HorizontalAlignment(self)
            result = self.Edit_.HorizontalAlignment ;
        end
        
        function set.HorizontalAlignment(self, newValue)
            self.Edit_.HorizontalAlignment = newValue ;
        end
        
        function result = get.Enable(self)
            result = self.Edit_.Enable ;
        end
        
        function set.Enable(self, newValue)
            self.Edit_.Enable = newValue ;
        end
    end  % public methods block    
end
