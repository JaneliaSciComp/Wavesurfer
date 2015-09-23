classdef Acquisition < ws.system.AcquisitionSubsystem
    
    methods
        function self = Acquisition(parent)
            self@ws.system.AcquisitionSubsystem(parent);
        end
                
%         function settings = packageCoreSettings(self)
%             settings=struct() ;
%             for i=1:length(self.CoreFieldNames_)
%                 fieldName = self.CoreFieldNames_{i} ;
%                 settings.(fieldName) = self.(fieldName) ;
%             end
%         end        
    end  % methods block    
    
    methods (Access=protected)
        function value = getAnalogChannelScales_(self)
            wavesurferModel=self.Parent;
            if isempty(wavesurferModel) ,
                ephys=[];
            else
                ephys=wavesurferModel.Ephys;
            end
            if isempty(ephys) ,
                electrodeManager=[];
            else
                electrodeManager=ephys.ElectrodeManager;
            end
            if isempty(electrodeManager) ,
                value=self.AnalogChannelScales_;
            else
                analogChannelNames=self.AnalogChannelNames;
                [channelScalesFromElectrodes, ...
                 isChannelScaleEnslaved] = ...
                    electrodeManager.getMonitorScalingsByName(analogChannelNames);
                value=ws.utility.fif(isChannelScaleEnslaved,channelScalesFromElectrodes,self.AnalogChannelScales_);
            end
        end
    end  % methods block    
    
end  % classdef
