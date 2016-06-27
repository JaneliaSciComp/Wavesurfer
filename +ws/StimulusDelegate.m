classdef (Abstract) StimulusDelegate < ws.Model & ws.ValueComparable
    % Superclass class for a stimulus delegate, which implements a
    % particular kind of stimulus (pulse, since, chirp, etc) for a Stimulus object 
%     properties (Dependent=true)
%         Parent  % Invariant: cannot be empty.  (Except sometimes during object loading.  Arg.)
%     end
%     
%     properties (Access=protected)
%         Parent_  % Invariant: cannot be empty.  (Except sometimes during object loading.  Arg.)
%     end
    
    methods
        function self=StimulusDelegate(parent)
            self@ws.Model(parent);
        end

%         function parent=get.Parent(self)
%             parent=self.Parent_;
%         end
%         
%         function set.Parent(self,newValue)
%             if isa(newValue,'ws.Stimulus') && isscalar(newValue) ,
%                 self.Parent_ = newValue;
%             end
%         end
        
        y = calculateCoreSignal(self, stimulus, t, sweepIndexWithinSet)  % abstract        
    end
    
    methods         
        function propNames = listPropertiesForHeader(self)
            propNamesRaw = listPropertiesForHeader@ws.Model(self) ;            
            % delete some property names that are defined in subclasses
            % that don't need to go into the header file
            propNames=setdiff(propNamesRaw, ...
                              {'AdditionalParameterNames', 'AdditionalParameterDisplayNames', 'AdditionalParameterDisplayUnitses'}) ;
        end  % function        
        
    end  % public methods block        

    %
    % Implementations of methods needed to be a ws.ValueComparable
    %
    methods
        function value=isequal(self,other)
            % Custom isequal.  Doesn't work for 3D, 4D, etc arrays.
            value=isequalHelper(self,other,'ws.StimulusDelegate');
        end                            
    end
    
    methods
    end
    
    methods (Access=protected)
       function value=isequalElement(self,other) %#ok<INUSD>
           value=true;
       end
    end
    
    methods (Access=protected)
        function out = getPropertyValue_(self, name)
            out = self.(name);
        end  % function
        
        % Allows access to protected and protected variables from ws.Coding.
        function setPropertyValue_(self, name, value)
            self.(name) = value;
        end  % function
    end
    
end
