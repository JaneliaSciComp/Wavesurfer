classdef (Abstract) StimulusDelegate < ws.Model & ws.ValueComparable
    % Superclass class for a stimulus delegate, which implements a
    % particular kind of stimulus (pulse, since, chirp, etc) for a Stimulus object 
    
    methods (Abstract=true)
        data = calculateSignal(self, t, sweepIndexWithinSet)  
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
end
