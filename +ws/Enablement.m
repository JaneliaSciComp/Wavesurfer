classdef Enablement < handle    
    % Class to keep track of the enablement state of a something...
    
    properties (Access=protected)
        DegreeOfEnablement_ = 1
            % We want to be able to disable things, and do it in such a way
            % that it can be called in nested loops, functions, etc and
            % behave in a reasonable way.  So this this an integer that can
            % take on negative values when it has been disabled multiple
            % times without being enabled.  But it is always <= 1.
    end
    
    properties (Dependent=true)  
        IsEnabled   % logical scalar, read-only
    end
        
    methods
        function self=Enablement()
        end
        
        function didChangeToEnabled=enableMaybe(self)
            wasEnabled=self.IsEnabled;
            newDegreeOfEnablementRaw=self.DegreeOfEnablement_+1;
            self.DegreeOfEnablement_ = ...
                    ws.utility.fif(newDegreeOfEnablementRaw<=1, ...
                                      newDegreeOfEnablementRaw, ...
                                      1);
            didChangeToEnabled=self.IsEnabled && ~wasEnabled;            
        end
        
        function disable(self)
            newDegreeOfEnablementRaw=self.DegreeOfEnablement_-1;
            self.DegreeOfEnablement_ = ...
                ws.utility.fif(newDegreeOfEnablementRaw<=1, ...
                                  newDegreeOfEnablementRaw, ...
                                  1);
        end
        
        function value=get.IsEnabled(self)
            value=(self.DegreeOfEnablement_>0);
        end
    end
    
end  % classdef
