classdef (Abstract) TriggeringSubsystem < ws.system.Subsystem
    
    properties (Dependent = true)
        Sources  % this is a cell array with all elements of type ws.TriggerSource
        Destinations  % this is a cell array with all elements of type ws.TriggerDestination
        Schemes  % This is [Sources Destinatations], a cell array
        StimulationUsesAcquisitionTriggerScheme
            % This is bound to the checkbox "Uses Acquisition Trigger" in the Stimulation section of the Triggers window
        AcquisitionTriggerScheme
        StimulationTriggerScheme
        AcquisitionTriggerSchemeIndex
        StimulationTriggerSchemeIndex
    end
    
    properties (Access=protected, Constant=true)
        MasterTriggerPhysicalChannelName_ = 'pfi8'
        MasterTriggerPFIID_ = 8
        MasterTriggerEdge_ = 'DAQmx_Val_Rising'
    end
    
    properties (Access = protected)
        Sources_  % this is a cell array with all elements of type ws.TriggerSource
        Destinations_  % this is a cell array with all elements of type ws.TriggerDestination
        StimulationUsesAcquisitionTriggerScheme_
        AcquisitionTriggerSchemeIndex_
        StimulationTriggerSchemeIndex_
    end

    properties (Access=protected, Constant=true)
        CoreFieldNames_ = { 'Sources_' , 'Destinations_', 'StimulationUsesAcquisitionTriggerScheme_', 'AcquisitionTriggerSchemeIndex_', ...
                            'StimulationTriggerSchemeIndex_' } ;
            % The "core" settings are the ones that get transferred to
            % other processes for running a sweep.
    end
    
    methods
        function self = TriggeringSubsystem(parent)
            self@ws.system.Subsystem(parent) ;            
            self.IsEnabled = true ;
            self.Sources_ = cell(0,1) ;
            self.Destinations_ = cell(0,1) ;       
            self.StimulationUsesAcquisitionTriggerScheme_ = true ;
            self.AcquisitionTriggerSchemeIndex_ = [] ;
            self.StimulationTriggerSchemeIndex_ = [] ;
        end  % function
                        
        function out = get.Destinations(self)
            out = self.Destinations_;
        end  % function
        
        function out = get.Sources(self)
            out = self.Sources_;
        end  % function
        
        function out = get.Schemes(self)
            out = [ self.Sources_ self.Destinations ] ;
        end  % function
        
        function out = get.AcquisitionTriggerScheme(self)
            index = self.AcquisitionTriggerSchemeIndex_ ;
            out = self.Schemes{index} ;
        end  % function
        
        function out = get.AcquisitionTriggerSchemeIndex(self)
            out = self.AcquisitionTriggerSchemeIndex_ ;
        end  % function

        function set.AcquisitionTriggerSchemeIndex(self, newValue)
            if ws.utility.isASettableValue(newValue) ,
                nSchemes = length(self.Sources_) + length(self.Destinations_) ;
                if isscalar(newValue) && isnumeric(newValue) && newValue==round(newValue) && 1<=newValue && newValue<=nSchemes ,
                    self.releaseCurrentTriggerSources_() ;
                    self.AcquisitionTriggerSchemeIndex_ = double(newValue) ;
                    self.syncTriggerSourcesFromTriggeringState_() ;
                else
                    error('most:Model:invalidPropVal', ...
                          'AcquisitionTriggerSchemeIndex must be a (scalar) index between 1 and the number of triggering schemes');
                end
            end
            self.broadcast('Update');                        
        end
        
        function out = get.StimulationTriggerSchemeIndex(self)
            out = self.StimulationTriggerSchemeIndex_ ;
        end  % function

        function set.StimulationTriggerSchemeIndex(self, newValue)
            if ws.utility.isASettableValue(newValue) ,
                nSchemes = length(self.Sources_) + length(self.Destinations_) ;
                if isscalar(newValue) && isnumeric(newValue) && newValue==round(newValue) && 1<=newValue && newValue<=nSchemes ,
                    self.StimulationTriggerSchemeIndex_ = double(newValue) ;
                else
                    error('most:Model:invalidPropVal', ...
                          'StimulationTriggerSchemeIndex must be a (scalar) index between 1 and the number of triggering schemes');
                end
            end
            self.broadcast('Update');                        
        end
        
        function out = get.StimulationTriggerScheme(self)
            if self.StimulationUsesAcquisitionTriggerScheme ,
                out = self.AcquisitionTriggerScheme ;
            else                
                out = self.Schemes{self.StimulationTriggerSchemeIndex_} ;
            end
        end  % function
        
        function debug(self) %#ok<MANU>
            % This is to make it easy to examine the internals of the
            % object
            keyboard
        end  % function
    end  % methods block
    
    methods
        function source = addNewTriggerSource(self)
            source = ws.TriggerSource(self);
            self.Sources_{end + 1} = source;
        end  % function
                
        function destination = addNewTriggerDestination(self)
            destination = ws.TriggerDestination(self);
            self.Destinations_{end + 1} = destination;
        end  % function
                        
        function set.StimulationUsesAcquisitionTriggerScheme(self,newValue)
            if ws.utility.isASettableValue(newValue) ,
                if self.Parent.AreSweepsFiniteDuration ,
                    % overridden by AreSweepsFiniteDuration, do nothing
                else                    
                    if isscalar(newValue) && (islogical(newValue) || (isnumeric(newValue) && (newValue==1 || newValue==0))) ,
                        self.StimulationUsesAcquisitionTriggerScheme_ = logical(newValue) ;
                        self.stimulusMapDurationPrecursorMayHaveChanged_();  % why are we calling this, again?
                    else
                        error('most:Model:invalidPropVal', ...
                              'StimulationUsesAcquisitionTriggerScheme must be a scalar, and must be logical, 0, or 1');
                    end
                end
            end
            self.broadcast('Update');            
        end  % function
        
        function value=get.StimulationUsesAcquisitionTriggerScheme(self)
            parent = self.Parent ;
            if ~isempty(parent) && isvalid(parent) && parent.AreSweepsFiniteDuration ,
                value = true ;
            else
                value = self.StimulationUsesAcquisitionTriggerScheme_ ;
            end
        end  % function
    end  % methods block
    
    methods (Access = protected)
        % Allows access to protected and protected variables from ws.mixin.Coding.
        function out = getPropertyValue(self, name)
            out = self.(name);
        end  % function
        
        % Allows access to protected and protected variables from ws.mixin.Coding.
        function setPropertyValue(self, name, value)
            self.(name) = value;
        end  % function
    end  % protected methods block
    
    methods
        function willSetNSweepsPerRun(self)
            % Have to release the relvant parts of the trigger scheme
            self.releaseCurrentTriggerSources_();
        end  % function

        function didSetNSweepsPerRun(self)
            self.syncTriggerSourcesFromTriggeringState_();            
        end  % function        
        
        function willSetAcquisitionDuration(self)
            % Have to release the relvant parts of the trigger scheme
            self.releaseCurrentTriggerSources_();
        end  % function

        function didSetAcquisitionDuration(self)
            self.syncTriggerSourcesFromTriggeringState_();            
        end  % function        
        
        function willSetAreSweepsFiniteDuration(self)
            % Have to release the relvant parts of the trigger scheme
            self.releaseCurrentTriggerSources_();
        end  % function
        
        function didSetAreSweepsFiniteDuration(self)
            %fprintf('Triggering::didSetAreSweepsFiniteDuration()\n');
            self.syncTriggerSourcesFromTriggeringState_();
            self.stimulusMapDurationPrecursorMayHaveChanged_();  
                % Have to do b/c changing this can change
                % StimulationUsesAcquisitionTriggerScheme.  (But why does
                % that matter?  That can't change the stim map duration
                % any more, I don't think...)
        end  % function         
    end
    
    methods (Access=protected)
        function stimulusMapDurationPrecursorMayHaveChanged_(self)
            parent=self.Parent;
            if ~isempty(parent) ,
                parent.stimulusMapDurationPrecursorMayHaveChanged();
            end
        end  % function        

        function releaseCurrentTriggerSources_(self)
            if self.AcquisitionTriggerScheme.IsInternal ,
                self.AcquisitionTriggerScheme.releaseInterval();
                self.AcquisitionTriggerScheme.releaseRepeatCount();
            end
        end  % function
        
        function syncTriggerSourcesFromTriggeringState_(self)
            if self.AcquisitionTriggerScheme.IsInternal ,
                self.AcquisitionTriggerScheme.overrideInterval(0.01);
                self.AcquisitionTriggerScheme.overrideRepeatCount(1);
            end
        end  % function        
    end  % protected methods block

    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = struct();
        mdlHeaderExcludeProps = {};
    end  % function    
    
end
