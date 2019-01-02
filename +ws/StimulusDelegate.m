classdef (Abstract) StimulusDelegate < ws.Model & ws.ValueComparable
    % Superclass class for a stimulus delegate, which implements a
    % particular kind of stimulus (pulse, since, chirp, etc) for a Stimulus object 
    
    methods
        function self = StimulusDelegate()
        end

        y = calculateCoreSignal(self, stimulus, t, sweepIndexWithinSet)  % abstract        
    end
    
    %
    % Implementations of methods needed to be a ws.ValueComparable
    %
    methods
        function value=isequal(self,other)
            % Custom isequal.  Doesn't work for 3D, 4D, etc arrays.
            value=isequalHelper(self,other,'ws.StimulusDelegate');
        end                            
    end
        
    methods (Access=protected)
        function value=isequalElement(self,other) %#ok<INUSD>
           value=true;
       end
    end
    
    methods 
        function out = getPropertyValue_(self, name)
            out = self.(name);
        end  % function
        
        % Allows access to protected and protected variables from ws.Encodable.
        function setPropertyValue_(self, name, value)
            self.(name) = value;
        end  % function
    end
    
end
