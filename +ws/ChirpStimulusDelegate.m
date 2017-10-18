classdef ChirpStimulusDelegate < ws.StimulusDelegate
    properties (Constant)
        TypeString='Chirp'
        AdditionalParameterNames={'Delay' 'Duration' 'Amplitude' 'DCOffset' 'InitialFrequency' 'FinalFrequency'}
        AdditionalParameterDisplayNames={'Delay' 'Duration' 'Amplitude' 'DC Offset' 'Initial Frequency' 'Final Frequency'}
        AdditionalParameterDisplayUnitses={'s' 's' '' '' 'Hz' 'Hz'}
    end
    
    properties (Dependent=true)
        Delay  % this and all below are string sweep expressions, in seconds
        Duration % s
            % this is the duration of the "support" of the stimulus.  I.e.
            % the stim is zero for the delay period, generally nonzero for
            % the Duration, then zero for some time after, with the total
            % duration being specified elsewhere.
        Amplitude
        DCOffset
        InitialFrequency
        FinalFrequency
    end
    
    properties (Access=protected)
        Delay_ = '0.25'  % sec
        Duration_ = '0.5'  % sec
        Amplitude_ = '5'
        DCOffset_ = '0'
        InitialFrequency_ = '10'  % Hz
        FinalFrequency_ = '100'  % Hz
    end
    
    properties (Dependent = true, Transient=true)
        EndTime  % Delay + Duration
    end
    
    methods
        function set.Delay(self, value)
            test = ws.Stimulus.evaluateSweepExpression(value,1) ;
            if ~isempty(test) && isnumeric(test) && isscalar(test) && isfinite(test) && isreal(test) && test>=0 ,
                % if we get here without error, safe to set
                self.Delay_ = value ;
            end                    
        end  % function
        
        function set.Duration(self, value)
            test = ws.Stimulus.evaluateSweepExpression(value,1) ;
            if ~isempty(test) && isnumeric(test) && isscalar(test) && isreal(test) && isfinite(test) && test>=0 ,
                % if we get here without error, safe to set
                self.Duration_ = value;
            end                    
        end  % function
        
        function set.Amplitude(self, value)
            test = ws.Stimulus.evaluateSweepExpression(value,1) ;
            if ~isempty(test) && (isnumeric(test) || islogical(test)) && isscalar(test) && isfinite(test) && isreal(test) ,
                % if we get here without error, safe to set
                self.Amplitude_ = value;
            end                
        end
        
        function set.DCOffset(self, value)
            test = ws.Stimulus.evaluateSweepExpression(value,1) ;
            if ~isempty(test) && isnumeric(test) && isscalar(test) && isfinite(test) && isreal(test) ,
                % if we get here without error, safe to set
                self.DCOffset_ = value;
            end                
        end

        function out = get.Delay(self)
            out = self.Delay_;
        end   % function

        function out = get.Duration(self)
            out = self.Duration_;
        end   % function

        function out = get.Amplitude(self)
            out = self.Amplitude_;
        end   % function

        function out = get.DCOffset(self)
            out = self.DCOffset_;
        end   % function        
        
        function val = get.EndTime(self)
            val = ws.Stimulus.evaluateSweepExpression(self.Delay,1) + ws.Stimulus.evaluateSweepExpression(self.Duration,1) ;
        end
    end    
    
    methods
        function self = ChirpStimulusDelegate()
            self = self@ws.StimulusDelegate() ;
        end  % function
        
        function set.InitialFrequency(self, value)
            test = ws.Stimulus.evaluateSweepExpression(value,1) ;
            if ~isempty(test) && isnumeric(test) && isscalar(test) && isfinite(test) && isreal(test) && test>0 ,
                % if we get here without error, safe to set
                self.InitialFrequency_ = value;
            end
        end  % function

        function out = get.InitialFrequency(self)
            out=self.InitialFrequency_;
        end
        
        function set.FinalFrequency(self, value)
            test = ws.Stimulus.evaluateSweepExpression(value,1) ;
            if ~isempty(test) && isnumeric(test) && isscalar(test) && isfinite(test) && isreal(test) && test>0 ,
                % if we get here without error, safe to set
                self.FinalFrequency_ = value;
            end                    
        end  % function

        function out = get.FinalFrequency(self)
            out=self.FinalFrequency_;
        end  % function
    end
    
    methods
        function data = calculateSignal(self, t, sweepIndexWithinSet)
            % Process args
            if ~exist('sweepIndexWithinSet','var') || isempty(sweepIndexWithinSet) ,
                sweepIndexWithinSet=1;
            end
                        
            % Compute the delay from the expression for it
            delay = ws.Stimulus.evaluateSweepExpression(self.Delay,sweepIndexWithinSet) ;
            % Screen for illegal values
            if isempty(delay) || ~(isnumeric(delay)||islogical(delay)) || ~isscalar(delay) || ~isreal(delay) || ~isfinite(delay) || delay<0 ,
                data=zeros(size(t));
                return
            end
            
            % Shift the timeline to account for the delay
            tShiftedByDelay=t-delay;
            
            % Call a method to generate the raw output data
            %delegate=self.Delegate_;
            data = self.calculateCoreSignal(tShiftedByDelay,sweepIndexWithinSet);
                % data should be same size as t at this point
            
            % Compute the amplitude from the expression for it
            amplitude = ws.Stimulus.evaluateSweepExpression(self.Amplitude,sweepIndexWithinSet) ;
            % Screen for illegal values
            if isempty(amplitude) || ~(isnumeric(amplitude)||islogical(amplitude)) || ~isscalar(amplitude) || ~isreal(amplitude) || ~isfinite(amplitude) ,
                data=zeros(size(t));
                return
            end

            % Compute the delay from the expression for it
            dcOffset = ws.Stimulus.evaluateSweepExpression(self.DCOffset,sweepIndexWithinSet) ;
            % Screen for illegal values
            if isempty(dcOffset) || ~(isnumeric(dcOffset)||islogical(dcOffset)) || ~isscalar(dcOffset) || ~isreal(dcOffset) || ~isfinite(dcOffset) ,
                data=zeros(size(t));
                return
            end
            
            % Scale by the amplitude, and add the DC offset
            data = amplitude*data + dcOffset;

            % Compute the duration from the expression for it
            duration = ws.Stimulus.evaluateSweepExpression(self.Duration,sweepIndexWithinSet) ;
            % Screen for illegal values
            if isempty(duration) || ~(isnumeric(duration)||islogical(duration)) || ~isscalar(duration) || ~isreal(duration) || ~isfinite(duration) || duration<0 ,
                data=zeros(size(t));
                return
            end
            
            % Zero the data outside the support
            % Yes, this is supposed to "override" the DC offset outside the
            % support.
            isOnSupport=(0<=tShiftedByDelay)&(tShiftedByDelay<duration);
            data(~isOnSupport,:)=0;
            
            if size(data,1)>0 ,
                data(end,:)=0;  % don't want to leave the DACs on when we're done
            end
        end        
        
        function y = calculateCoreSignal(self, t, sweepIndexWithinSet)
            % Compute the duration from the expression for it
            duration = ws.Stimulus.evaluateSweepExpression(self.Duration, sweepIndexWithinSet) ;
            if isempty(duration) || ~isnumeric(duration) || ~isscalar(duration) || ~isreal(duration) || ~isfinite(duration) || duration<0 ,
                y=zeros(size(t));
                return
            end   
            
            % Compute the duration from the expression for it
            f0 = ws.Stimulus.evaluateSweepExpression(self.InitialFrequency,sweepIndexWithinSet) ;
            if isempty(f0) || ~isnumeric(f0) || ~isscalar(f0) || ~isreal(f0) || ~isfinite(f0) || f0<0 ,
                y=zeros(size(t));
                return
            end   
            
            % Compute the duration from the expression for it
            ff = ws.Stimulus.evaluateSweepExpression(self.FinalFrequency,sweepIndexWithinSet) ;
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
    end

    %
    % Implementations of methods needed to be a ws.ValueComparable
    %
    methods
        function value=isequal(self,other)
            % Custom isequal.  Doesn't work for 3D, 4D, etc arrays.
            value=isequalHelper(self,other,'ws.ChirpStimulusDelegate');
        end                            
    end
    
    methods (Access=protected)
       function value=isequalElement(self,other)
            propertyNamesToCompare={'Delay' 'Duration' 'Amplitude' 'DCOffset' 'InitialFrequency' 'FinalFrequency'};
            value=isequalElementHelper(self,other,propertyNamesToCompare);
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

