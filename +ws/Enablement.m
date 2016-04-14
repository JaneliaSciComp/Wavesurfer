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
    
    properties (Dependent=true, SetAccess=immutable)  
        IsEnabled   % logical scalar, read-only
    end

%     properties (Access=protected, Transient=true)
%         Parent_ 
%     end
    
    methods
        function self=Enablement()
            %self.Parent_ = parent ;
        end
       
%         function delete(self) %#ok<INUSD>
%             %self.Parent_ = [] ;
%         end
        
        function enableMaybe(self)
            %fprintf('ws.Enablement::enableMaybe()\n');
            %dbstack            
%             className = class(self.Parent_) ;
%             if isequal(className,'ws.UserCodeManager') ,
%                 fprintf('About to increment (maybe) UserCodeManager degree of enablement.\n');
%             end
            newDegreeOfEnablementRaw = self.DegreeOfEnablement_ + 1 ;
            self.DegreeOfEnablement_ = min(1,newDegreeOfEnablementRaw) ;
        end
        
        function disable(self)
            %fprintf('ws.Enablement::disable()\n');
            %dbstack
%             className = class(self.Parent_) ;
%             if isequal(className,'ws.UserCodeManager') ,
%                 fprintf('About to decrement UserCodeManager degree of enablement.\n');
%             end
            self.DegreeOfEnablement_ = self.DegreeOfEnablement_ - 1 ;
        end
        
        function value=get.IsEnabled(self)
            value = (self.DegreeOfEnablement_>0);
        end
        
        function value = peekAtDegreeOfEnablement(self)
            % This is meant to be used only for debugging, not for routine access            
            value = self.DegreeOfEnablement_ ;
        end
    end
    
end  % classdef
