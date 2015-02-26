classdef DIChan < ws.dabs.ni.daqmx.private.DigitalChan
    %DICHAN  A DAQmx Digital Input Channel
    %   Detailed explanation goes here
    
    properties (Constant)
        type = 'DigitalInput';
    end
    
    properties (Constant, Hidden)
        typeCode = 'DI';
    end
    
    %%TMW: Should we really have to create a constructor when a simple pass-through to superclass would do?
    methods
        function obj = DIChan(varargin)
            obj = obj@ws.dabs.ni.daqmx.private.DigitalChan(varargin{:});
        end
    end
    
end

