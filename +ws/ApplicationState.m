classdef ApplicationState < int32
    % Enumerated values for the possible Wavesurfer operation modes or states.
    
    enumeration
        Uninitialized(0);  % Not yet loaded and configured.
        NoMDF(1);  % No Machine Data File specified yet
        % If in any othe modes below, implies that the MDF has been
        % specified
        Idle(2);  % Not doing much of anything
        AcquiringTrialBased(3);     % Running a standard acq set with one or more acqs
        AcquiringContinuously(4);        % Continuously acquire until the user interrupts
        TestPulsing(5);  % Running a test pulse
    end
    
    methods
        function out = toTitleString(self)
            switch self
                case ws.ApplicationState.Uninitialized
                    out = '(Uninitialized)';
                case ws.ApplicationState.NoMDF
                    out = 'No MDF';
                case ws.ApplicationState.Idle
                    out = 'Idle';
                case ws.ApplicationState.AcquiringTrialBased
                    out = 'Acquiring (trial-based)';
                case ws.ApplicationState.AcquiringContinuously
                    out = 'Acquiring (continuous)';
                case ws.ApplicationState.TestPulsing
                    out = 'Test Pulsing';
                otherwise
                    out = '';
            end
        end

        function out = toCodeString(self)
            switch self
                case ws.ApplicationState.Uninitialized
                    out = 'Uninitialized';
                case ws.ApplicationState.NoMDF
                    out = 'NoMDF';
                case ws.ApplicationState.Idle
                    out = 'Idle';
                case ws.ApplicationState.AcquiringTrialBased
                    out = 'AcquiringTrialBased)';
                case ws.ApplicationState.AcquiringContinuously
                    out = 'AcquiringContinuously';
                case ws.ApplicationState.TestPulsing
                    out = 'TestPulsing';
                otherwise
                    out = '';
            end
        end
        
        function out = num2str(self)  % deprecated
            out = toTitleString(self);
        end
    end  % methods
    
    methods (Static=true)
        function out = fromCodeString(string)
            out=ws.fastprotocol.StartType.(string);
        end
    end  % static methods
    
end
