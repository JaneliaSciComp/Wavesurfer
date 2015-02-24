classdef (Abstract) StimulusDelegate < ws.Model & ws.mixin.ValueComparable
    % Superclass class for a stimulus delegate, which implements a
    % particular kind of stimulus (pulse, since, chirp, etc) for a Stimulus object 
    properties (Dependent=true)
        Parent  % Invariant: cannot be empty.  (Except sometimes during object loading.  Arg.)
    end
    
    properties (Access=protected)
        Parent_  % Invariant: cannot be empty.  (Except sometimes during object loading.  Arg.)
    end
    
    methods
        function self=StimulusDelegate(parent)
            if isa(parent,'ws.stimulus.Stimulus') && isscalar(parent) ,
                self.Parent_=parent;
            else
                error('wavesurfer:stimulusDelegate must have a parent');
            end
        end

        function parent=get.Parent(self)
            parent=self.Parent_;
        end
        
        function set.Parent(self,newValue)
            if isa(newValue,'ws.stimulus.Stimulus') && isscalar(newValue) ,
                self.Parent_ = newValue;
            end
        end
        
        y = calculateCoreSignal(self, stimulus, t, trialIndexWithinSet)  % abstract        
    end
       
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = struct();    
        mdlHeaderExcludeProps = {};
    end
    
    methods (Access=protected)
        function defineDefaultPropertyTags(self)
            defineDefaultPropertyTags@ws.Model(self);
            self.setPropertyTags('Parent', 'ExcludeFromFileTypes', {'header'});
        end
    end

    %
    % Implementations of methods needed to be a ws.mixin.ValueComparable
    %
    methods
        function value=isequal(self,other)
            % Custom isequal.  Doesn't work for 3D, 4D, etc arrays.
            value=isequalHelper(self,other,'ws.stimulus.StimulusDelegate');
        end                            
    end
    
    methods (Access=protected)
       function value=isequalElement(self,other) %#ok<INUSD>
           value=true;
       end
    end
    
end
