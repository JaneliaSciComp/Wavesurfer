classdef BuiltinTrigger < ws.Model %& ws.HasPFIIDAndEdge  % & matlab.mixin.Heterogeneous  (was second in list)
    % A class that represents the built-in trigger, a trigger on
    % PFI8, that we "manually" throw at the start of each leg of the run.  This
    % trigger can trigger AI/AO/DI/DO tasks directly, and can also trigger
    % counter trigger tasks, which can then trigger AO/DO tasks.  Note that
    % this trigger gets fired at the start of each leg of the run, whether
    % or not it's actually used to trigger either the acquisition or the
    % stimulation.
    
    properties (Dependent=true)
        Name
        DeviceName  % the NI device ID string, e.g. 'Dev1'
        PFIID  % The PFI ID of the line to output on
        Edge
            % Whether rising edges or falling edges constitute a trigger
            % event.
    end
    
    properties (Access=protected)
        Name_
        DeviceName_
        PFIID_
        Edge_
    end
    
    methods
        function self=BuiltinTrigger(parent)  %#ok<INUSD>            
            self@ws.Model([]) ;  % have to accept parent arg, but ignore it
            %fprintf('ws.BuiltinTrigger constructor called\n') ;
            %dbstack
            self.Name_ = 'Built-in Trigger (PFI8)' ;
            self.DeviceName_ = '' ;
            self.PFIID_ = 8 ;
            self.Edge_ = 'rising' ;
        end
        
        function value=get.Name(self)
            value = self.Name_ ;
        end

        function value = get.DeviceName(self)
            value = self.DeviceName_ ;
        end
        
        function set.DeviceName(self, deviceName)  % should only be called by triggering subsystem
            self.DeviceName_ = deviceName ;
        end        
        
%         function value=get.DeviceName(self)
%             value = self.Parent.Parent.DeviceName ;
%             %value = self.DeviceName_ ;
%             
% %             % Look high and low throughout the system for a device name
% %             triggeringSubsystem = self.Parent ;
% %             counterTriggers = triggeringSubsystem.CounterTriggers ;
% %             if isempty(counterTriggers) ,
% %                 externalTriggers = triggeringSubsystem.ExternalTriggers ;
% %                 if isempty(externalTriggers) ,
% %                     rootModel = triggeringSubsystem.Parent ;
% %                     if isprop(rootModel,'Acquisition') ,
% %                         acquisitionSubsystem = rootModel.Acquisition ;
% %                         acquisitionDeviceNames = acquisitionSubsystem.DeviceNames ;
% %                         if isempty(acquisitionDeviceNames) ,
% %                             didGetDeviceNameFromAcquisitionSubsystem = false ;
% %                             valueFromAcquisitionSubsystem = [] ;                            
% %                         else
% %                             didGetDeviceNameFromAcquisitionSubsystem = true ;
% %                             valueFromAcquisitionSubsystem = acquisitionDeviceNames{1} ;                            
% %                         end
% %                     else
% %                         didGetDeviceNameFromAcquisitionSubsystem = false ;
% %                         valueFromAcquisitionSubsystem = [] ;
% %                     end                    
% %                     if didGetDeviceNameFromAcquisitionSubsystem ,
% %                         value = valueFromAcquisitionSubsystem ;
% %                     else
% %                         % Probe the stimulation subsystem
% %                         if isprop(rootModel,'Stimulation') ,
% %                             stimulationSubsystem = rootModel.Stimulation ;
% %                             stimulationDeviceNames = stimulationSubsystem.DeviceNames ;
% %                             if isempty(stimulationDeviceNames) ,
% %                                 didGetDeviceNameFromStimulationSubsystem = false ;
% %                                 valueFromStimulationSubsystem = [] ;                            
% %                             else
% %                                 didGetDeviceNameFromStimulationSubsystem = true ;
% %                                 valueFromStimulationSubsystem = stimulationDeviceNames{1} ;                            
% %                             end
% %                         else
% %                             didGetDeviceNameFromStimulationSubsystem = false ;
% %                             valueFromStimulationSubsystem = [] ;
% %                         end                    
% %                         if didGetDeviceNameFromStimulationSubsystem ,
% %                             value = valueFromStimulationSubsystem ;
% %                         else
% %                             % Harrumph: there doesn't seem to be any
% %                             % anywhere to get the device name from                       
% %                             value = '' ;
% %                         end                        
% %                     end
% %                 else
% %                     firstExternalTrigger = counterTriggers{1} ;
% %                     value = firstExternalTrigger.DeviceName ;                    
% %                 end
% %             else
% %                 firstCounterTrigger = counterTriggers{1} ;
% %                 value = firstCounterTrigger.DeviceName ;
% %             end            
%         end
                
        function value=get.PFIID(self)
            value=self.PFIID_;
        end
        
        function value=get.Edge(self)
            value=self.Edge_;
        end
        
%         function set.DeviceName(self, value)
%             if ws.isASettableValue(value) ,
%                 if ws.isString(value) ,
%                     self.DeviceName_ = value ;
%                 else
%                     self.broadcast('Update');
%                     error('ws:invalidPropertyValue', ...
%                           'Name must be a string');                  
%                 end                    
%             end
%             self.broadcast('Update');            
%         end
        
%         function set.Name(self, value)
%             if ws.isASettableValue(value) ,
%                 if ws.isString(value) && ~isempty(value) ,
%                     self.Name_ = value ;
%                 else
%                     self.broadcast('Update');
%                     error('ws:invalidPropertyValue', ...
%                           'Name must be a nonempty string');                  
%                 end                    
%             end
%             self.broadcast('Update');            
%         end
        
%         function set.DeviceName(self, value)
%             if ws.isASettableValue(value) ,
%                 if ws.isString(value) ,
%                     self.DeviceName_ = value ;
%                 else
%                     self.broadcast('Update');
%                     error('ws:invalidPropertyValue', ...
%                           'DeviceName must be a string');                  
%                 end                    
%             end
%             self.broadcast('Update');            
%         end
        
%         function set.PFIID(self, value)
%             if ws.isASettableValue(value) ,
%                 if isnumeric(value) && isscalar(value) && isreal(value) && value==round(value) && value>=0 ,
%                     value = double(value) ;
%                     self.PFIID_ = value ;
%                 else
%                     self.broadcast('Update');
%                     error('ws:invalidPropertyValue', ...
%                           'PFIID must be a (scalar) nonnegative integer');                  
%                 end                    
%             end
%             self.broadcast('Update');            
%         end
%         
%         function set.Edge(self, value)
%             if ws.isASettableValue(value) ,
%                 if ws.isAnEdgeType(value) ,
%                     self.Edge_ = value;
%                 else
%                     self.broadcast('Update');
%                     error('ws:invalidPropertyValue', ...
%                           'Edge must be ''rising'' or ''falling''');                  
%                 end                                        
%             end
%             self.broadcast('Update');            
%         end  % function 
    end  % methods
    
    methods (Access=protected)        
        function out = getPropertyValue_(self, name)
            out = self.(name);
        end  % function
        
        % Allows access to protected and protected variables from ws.Coding.
        function setPropertyValue_(self, name, value)
            self.(name) = value;
        end  % function
    end
    
%     properties (Hidden, SetAccess=protected)
%         mdlPropAttributes = struct();        
%         mdlHeaderExcludeProps = {};
%     end
    
%     methods (Static)
%         function s = propertyAttributes()
%             s = struct();
% 
%             s.Name=struct('Classes', 'char', ...
%                           'Attributes', {{'vector'}}, ...
%                           'AllowEmpty', false);
%             s.DeviceName=struct('Classes', 'char', ...
%                             'Attributes', {{'vector'}}, ...
%                             'AllowEmpty', true);
%             s.PFIID=struct('Classes', 'numeric', ...
%                            'Attributes', {{'scalar', 'integer'}}, ...
%                            'AllowEmpty', false);
%         end  % function
%     end  % class methods block
    
end  % classdef
