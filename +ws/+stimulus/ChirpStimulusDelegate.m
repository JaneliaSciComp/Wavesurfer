classdef ChirpStimulusDelegate < ws.stimulus.StimulusDelegate
    properties (Constant)
        TypeString='Chirp'
        AdditionalParameterNames={'InitialFrequency' 'FinalFrequency'}
        AdditionalParameterDisplayNames={'Initial Frequency' 'Final Frequency'}
        AdditionalParameterDisplayUnitses={'Hz' 'Hz'}
    end
    
    properties (Dependent=true)
        InitialFrequency
        FinalFrequency
    end
    
    properties (Access=protected)
        InitialFrequency_ = '10'  % Hz
        FinalFrequency_ = '100'  % Hz
    end
    
    methods
        function self = ChirpStimulusDelegate(parent,varargin)
            self=self@ws.stimulus.StimulusDelegate(parent);
            pvArgs = ws.most.util.filterPVArgs(varargin, {'InitialFrequency' 'FinalFrequency'}, {});
            propNames = pvArgs(1:2:end);
            propValues = pvArgs(2:2:end);               
            for i = 1:length(propValues)
                self.(propNames{i}) = propValues{i};
            end            
        end  % function
        
        function set.InitialFrequency(self, value)
            test = ws.stimulus.Stimulus.evaluateTrialExpression(value,1) ;
            if ~isempty(test) && isnumeric(test) && isscalar(test) && isfinite(test) && isreal(test) && test>0 ,
                % if we get here without error, safe to set
                self.InitialFrequency_ = value;
            end
            if ~isempty(self.Parent) ,
                self.Parent.childMayHaveChanged();
            end
        end  % function

        function out = get.InitialFrequency(self)
            out=self.InitialFrequency_;
        end
        
        function set.FinalFrequency(self, value)
            test = ws.stimulus.Stimulus.evaluateTrialExpression(value,1) ;
            if ~isempty(test) && isnumeric(test) && isscalar(test) && isfinite(test) && isreal(test) && test>0 ,
                % if we get here without error, safe to set
                self.FinalFrequency_ = value;
            end                    
            if ~isempty(self.Parent) ,
                self.Parent.childMayHaveChanged();
            end
        end  % function

        function out = get.FinalFrequency(self)
            out=self.FinalFrequency_;
        end  % function
    end
    
%     methods (Access=protected)
%         function value=isequalElement(self,other)
%             isEqualAsStimuli=isequalElement@ws.stimulus.Stimulus(self,other);
%             if ~isEqualAsStimuli ,
%                 value=false;
%                 return
%             end
%             additionalPropertyNamesToCompare={'InitialFrequency' 'FinalFrequency'};
%             value=isequalElementHelper(self,other,additionalPropertyNamesToCompare);
%        end
%     end
    
    methods
        function y = calculateCoreSignal(self, stimulus, t, trialIndexWithinSet)
            % Compute the duration from the expression for it
            duration = ws.stimulus.Stimulus.evaluateTrialExpression(stimulus.Duration,trialIndexWithinSet) ;
            if isempty(duration) || ~isnumeric(duration) || ~isscalar(duration) || ~isreal(duration) || ~isfinite(duration) || duration<0 ,
                y=zeros(size(t));
                return
            end   
            
            % Compute the duration from the expression for it
            f0 = ws.stimulus.Stimulus.evaluateTrialExpression(self.InitialFrequency,trialIndexWithinSet) ;
            if isempty(f0) || ~isnumeric(f0) || ~isscalar(f0) || ~isreal(f0) || ~isfinite(f0) || f0<0 ,
                y=zeros(size(t));
                return
            end   
            
            % Compute the duration from the expression for it
            ff = ws.stimulus.Stimulus.evaluateTrialExpression(self.FinalFrequency,trialIndexWithinSet) ;
            if isempty(ff) || ~isnumeric(ff) || ~isscalar(ff) || ~isreal(ff) || ~isfinite(ff) || ff<0 ,
                y=zeros(size(t));
                return
            end                          
            
            %
            % Actually do the computation
            %
            fSlope=(ff-f0)/duration;  % Hz/s == Hz^2
            % These next two lines are naive and incorrect
            % f=f0+fSlope*t;  % Hz
            % y=sin((2*pi)*(f.*t));
            
            % Expression for instantaneous frequency is f(t)=f0+fSlope*t
            % Have to integrate this to get the number of cycles completed
            % since t==0.  Doing that gives nCycles = f0*t +
            % (1/2)*fSlope*t^2.  We do that, then convert to radians and
            % put through sine function
            
            nCycles=t.*(f0+(fSlope/2)*t);  % nCycles completed since t==0 (can be fractional, negative)
            phi=2*pi*nCycles;  % radians completed since t==0
            y=sin(phi);            
        end
        
%         function defineDefaultPropertyAttributes(self)
%             defineDefaultPropertyAttributes@ws.stimulus.Stimulus(self);
%             self.setPropertyAttributeFeatures('InitialFrequency', 'Classes', 'numeric', 'Attributes', {'scalar', 'real', 'finite', 'positive'});
%             self.setPropertyAttributeFeatures('FinalFrequency', 'Classes', 'numeric', 'Attributes', {'scalar', 'real', 'finite', 'positive'});
%         end
    end

    methods (Access=protected)
        function defineDefaultPropertyTags(self)
            defineDefaultPropertyTags@ws.stimulus.StimulusDelegate(self);
            self.setPropertyTags('AdditionalParameterNames', 'ExcludeFromFileTypes', {'header'});
            self.setPropertyTags('AdditionalParameterDisplayNames', 'ExcludeFromFileTypes', {'header'});
            self.setPropertyTags('AdditionalParameterDisplayUnitses', 'ExcludeFromFileTypes', {'header'});
        end
    end
    
    %
    % Implementations of methods needed to be a ws.mixin.ValueComparable
    %
    methods
        function value=isequal(self,other)
            % Custom isequal.  Doesn't work for 3D, 4D, etc arrays.
            value=isequalHelper(self,other,'ws.stimulus.ChirpStimulusDelegate');
        end                            
    end
    
    methods (Access=protected)
       function value=isequalElement(self,other)
            propertyNamesToCompare={'InitialFrequency' 'FinalFrequency'};
            value=isequalElementHelper(self,other,propertyNamesToCompare);
       end
    end
    
end

