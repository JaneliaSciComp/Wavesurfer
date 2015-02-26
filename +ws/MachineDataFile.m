classdef MachineDataFile < ws.most.MachineDataFile
    
    properties (SetAccess = protected)
        MDFData
    end
    
    properties (Constant, Hidden)
        mdfClassName = mfilename('class');
        mdfHeading = 'Wavesurfer';
        mdfDependsOnClasses = {};
        mdfDirectProp = false;
        mdfPropPrefix = '';
    end
    
    methods
        function self = MachineDataFile(mdfFileName)
            if ~exist('mdfFileName','var') || isempty(mdfFileName) ,
                mdfFileName='';
            end
            % The prompt if a machine data file needs to me created.
            message = 'Wavesurfer requires a machine data file specifying your hardware configuration.  You can create one now or cancel loading Wavesurfer.';
            title = 'Wavesurfer Machine Data File';
            self@ws.most.MachineDataFile(message, title, mdfFileName);
        end
        
        function out = get.MDFData(self)
            out = self.mdfData;
            
            self.verifyProperty('inputDeviceIDs', {'Classes', {'cell'}}, []);
            self.verifyProperty('inputChanIDs', {'Classes', {'numeric'}, 'Attributes', {'vector', 'nonnegative', 'integer'}, 'AllowEmptyDouble', true}, []);
            self.verifyProperty('inputChanNames', {'Classes', {'cell'}}, []);
            
            self.verifyProperty('outputDeviceIDs', {'Classes', {'cell'}}, []);
            self.verifyProperty('outputAnalogChanIDs', {'Classes', {'numeric'}, 'Attributes', {'vector', 'nonnegative', 'integer'}, 'AllowEmptyDouble', true}, []);
            self.verifyProperty('outputAnalogChanNames', {'Classes', {'cell'}}, []);
            
            self.verifyProperty('outputDigitalChanIDs', {'Classes', {'numeric'}, 'Attributes', {'vector', 'nonnegative', 'integer'}, 'AllowEmptyDouble', true}, []);
            self.verifyProperty('outputDigitalChanNames', {'Classes', {'cell'}}, []);
            
            for idx = 1:1000
                triggerId = sprintf('trigger%d', idx);
                
                if ~isfield(self.mdfData, [triggerId 'Type']) || isempty(self.mdfData.([triggerId 'Type']))
                    break;
                end
                
                self.verifyProperty([triggerId 'Type'], {'Classes', {'char'}}, []);
                self.verifyProperty([triggerId 'DeviceID'], {'Classes', {'char'}}, []);
                self.verifyProperty([triggerId 'CounterID'], {'Classes', {'numeric'}, 'Attributes', {'scalar', 'nonnegative', 'integer'}, 'AllowEmptyDouble', true}, []);
                self.verifyProperty([triggerId 'Source'], {'Classes', {'numeric'}, 'Attributes', {'scalar', 'nonnegative', 'integer'}, 'AllowEmptyDouble', true}, []);
                self.verifyProperty([triggerId 'Edge'], {'Classes', {'char'}}, []);
            end  % for loop
        end  % function
    end  % methods
end  % classdef
