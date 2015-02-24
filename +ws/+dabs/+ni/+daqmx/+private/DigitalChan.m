classdef DigitalChan < ws.dabs.ni.daqmx.Channel
    %DIGITALCHAN  An abstract DAQmx Digital Channel class    
   
    
    properties  (SetAccess=protected)
        channelType=''; %One of {'port','line'}, indicating if Channel is port-based or line-based.
    end
    
    properties (Constant, Hidden)
        physChanIDsArgValidator = @ischar; %PhysChanIDs arg must be a string (or a cell array of such, for multi-device case)
    end
        
   %% CONSTRUCTOR/DESTRUCTOR
    methods (Access=protected)       
        function obj = DigitalChan(varargin)
            % obj = DigitalChan(createFunc,task,deviceName,physChanIDs,chanNames,varargin)            
            obj = obj@ws.dabs.ni.daqmx.Channel(varargin{:});
        end
    end
    
   
    %% ABSTRACT METHOD IMPLEMENTATIONS (ws.dabs.ni.daqmx.Channel)
    methods (Hidden)
        %TMW: This function is a regular method, rather than being static (despite having no object-dependence). This allows caller in abstract superclass to invoke it  by the correct subclass version.
        %%% This would not need to be a regular method if there were a simpler way to invoke static methods, without resorting to completely qualified names.
        function [physChanNameArray,chanNameArray] = createChanIDArrays(obj, numChans, deviceName, physChanIDs,chanNames)
            %NOTE: For DOChan objects, physChanIDs 
            
            [physChanNameArray,chanNameArray] = deal(cell(1,numChans));
            
            if numChans == 1
                physChanIDs = {physChanIDs};
            end
            
            for i=1:numChans     
                portOrLineID = regexpi(physChanIDs{i},'\s*/?(.*)','tokens','once'); %Removes leading slash, if any  
                physChanNameArray{i} = [deviceName '/' portOrLineID{1}];           
                if isempty(chanNames)
                    chanNameArray{i} = ''; %Would prefer to give it the physical chan name, but DAQmx won't take any special characters in the given channel name (even as it proceeds to use them in supplying the default itself)
                elseif ischar(chanNames)
                    if numChans > 1
                        chanNameArray{i} = [chanNames num2str(i)];
                    else
                        chanNameArray{i} = chanNames;
                    end
                elseif iscellstr(chanNames) && length(chanNames)==numChans
                    chanNameArray{i} = chanNames{i};
                else
                    error(['Argument ''' inputname(5) ''' must be a string or cell array of strings of length equal to the number of channels.']);
                end
            end
        end
        
        function postCreationListener(obj)

            %Determine if channel(s) added are port- or line-based
            for i=1:length(obj)
               if ~isempty(strfind(obj.chanNamePhysical,'line'))
                   obj(i).channelType = 'line';
               else
                   obj(i).channelType = 'port';
               end
            end
            
            %Ensure that all channel(s) added, now and previously to this Task, are of same type
            taskChannelTypes = unique({obj(1).task.channels.channelType});
            
            if length(taskChannelTypes) > 1
                delete(obj(1).task);
                fprintf(2,['The Matlab DAQmx package does not, at this time, allow Digital I/O Tasks\n' ...
                    'to contain a mixture of port- and line-based Channels.\n' ...
                    'Task has been deleted!\n']);                
                return;
            end  
            
            %Store to Task whether Channel(s) of this Task are line-based 
            obj(1).task.isLineBasedDigital = strcmpi(taskChannelTypes,'line');
            
            
        end
    end
    
    
end

