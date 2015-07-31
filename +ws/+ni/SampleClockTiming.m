classdef SampleClockTiming < int32
    enumeration
        FiniteSamples(1);
        ContinuousSamples(2);
        HardwareTimedSinglePoint(3);
    end
    
    methods
        function out = daqmxName(obj)
            %DAQMXNAME Return the DAQmx-appropriate string for this enumeration value.
            switch obj
                case 'DAQmx_Val_FiniteSamps'
                    out = 'DAQmx_Val_FiniteSamps';
                case 'DAQmx_Val_ContSamps'
                    out = 'DAQmx_Val_ContSamps';
                case ws.ni.SampleClockTiming.HardwareTimedSinglePoint
                    out = 'DAQmx_Val_HWTimedSinglePoint';
            end
        end
    end
end
