classdef DOChan < ws.dabs.ni.daqmx.private.DigitalChan
    %DOCHAN  A DAQmx Digital Output Channel
    %   Detailed explanation goes here
    
    properties (Constant)
        type = 'DigitalOutput';
    end
    
    properties (Constant, Hidden)
        typeCode = 'DO';
    end
    
    %%TMW: Should we really have to create a constructor when a simple pass-through to superclass would do?
    methods 
        function obj = DOChan(varargin)
            obj = obj@ws.dabs.ni.daqmx.private.DigitalChan(varargin{:});            
        end        
    end
    
end

