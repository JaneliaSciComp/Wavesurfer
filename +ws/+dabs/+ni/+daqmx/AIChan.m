classdef AIChan < ws.dabs.ni.daqmx.private.AnalogChan
    %AICHAN A DAQmx Analog Input Channel
    
    properties (Constant)
        type = 'AnalogInput';
    end
    
    properties (Constant, Hidden)
        typeCode = 'AI';
    end
    
    %% CONSTRUCTOR/DESTRUCTOR
    methods
        function obj = AIChan(varargin)
            %Constructor required, as this is a concrete subclass of abstract lineage
            obj = obj@ws.dabs.ni.daqmx.private.AnalogChan(varargin{:});
            
        end
    end
    
    %% METHODS
    
    methods (Hidden)
        
        function postCreationListener(obj)
            %Handle input data type
            errorCond = false;
            for i=1:length(obj)
                rawSampSize = obj(i).getQuiet('rawSampSize');
                switch rawSampSize
                    case 8
                        rawSampClass = 'int8';
                    case 16
                        rawSampClass = 'int16';
                    case 32
                        rawSampClass = 'int32';
                    otherwise
                        errMessage = ['Unsupported sample size (' num2str(rawSampSize) '). Task deleted.'];
                        errorCond = true;
                        break;
                end
                if isempty(obj(i).task.rawDataArrayAI)
                    obj(1).task.rawDataArrayAI = feval(rawSampClass,0); %Creates a scalar array of rawSampClass
                elseif ~strcmpi(class(obj(i).task.rawDataArrayAI), rawSampClass);
                    errMessage = ['All ' obj(i).type ' channels in a given Task must have the same raw data type. Task deleted.'];
                    errorCond = true;
                    break;
                end
            end
            
            if errorCond
                delete(obj(1).task); %All created objects presumed (known) to belong to same class
                error(errMessage);
            end
        end
        
        
    end
    
    
end



