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
        CoreFieldNames_ = { 'Sources_' , 'Destinations_', 'StimulationUsesAcquisitionTriggerScheme_', 'AcquisitionTriggerSchemeIndex_', ...
                            'StimulationTriggerSchemeIndex_' } ;
            % The "core" settings are the ones that get transferred to
            % other processes for running a sweep.
    end

    properties (Access = protected)
        Sources_  % this is a cell array with all elements of type ws.TriggerSource
        Destinations_  % this is a cell array with all elements of type ws.TriggerDestination
        StimulationUsesAcquisitionTriggerScheme_
        AcquisitionTriggerSchemeIndex_
        StimulationTriggerSchemeIndex_
    end
    
    methods
        function self = TriggeringSubsystem(parent)
            self.CanEnable = true ;
            self.Enabled = true ;
            self.Parent = parent ;
            self.Sources_ = cell(0,1) ;
            self.Destinations_ = cell(0,1) ;       
            self.StimulationUsesAcquisitionTriggerScheme_ = true ;
            self.AcquisitionTriggerSchemeIndex_ = [] ;
            self.StimulationTriggerSchemeIndex_ = [] ;
        end  % function
                        
        function delete(self)
            self.Parent = [] ;
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
            self.setAcquisitionTriggerSchemeIndex_(newValue) ;  % subclasses override this, sometimes
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
            source = ws.TriggerSource();
            self.Sources_{end + 1} = source;
        end  % function
                
        function destination = addNewTriggerDestination(self)
            destination = ws.TriggerDestination();
            self.Destinations_{end + 1} = destination;
        end  % function
                        
        function set.StimulationUsesAcquisitionTriggerScheme(self,newValue)
            self.setStimulationUsesAcquisitionTriggerScheme_(newValue) ;
        end  % function
        
        function value=get.StimulationUsesAcquisitionTriggerScheme(self)
            value = self.getStimulationUsesAcquisitionTriggerScheme_() ;
        end  % function
        
        function settings = packageCoreSettings(self)
            settings=struct() ;
            for i=1:length(self.CoreFieldNames_)
                fieldName = self.CoreFieldNames_{i} ;
                settings.(fieldName) = self.(fieldName) ;
            end
        end
        
        function setCoreSettingsToMatchPackagedOnes(self,settings)
            for i=1:length(self.CoreFieldNames_)
                fieldName = self.CoreFieldNames_{i} ;
                self.(fieldName) = settings.(fieldName) ;
            end
        end
    end  % methods block
    
    methods (Access = protected)
        function setStimulationUsesAcquisitionTriggerScheme_(self,newValue)   % this is overridable by subclasses, whereas a setter is not
            if ws.utility.isASettableValue(newValue) ,
                if isscalar(newValue) && (islogical(newValue) || (isnumeric(newValue) && (newValue==1 || newValue==0))) ,
                    self.StimulationUsesAcquisitionTriggerScheme_ = logical(newValue) ;
                else
                    error('most:Model:invalidPropVal', ...
                          'StimulationUsesAcquisitionTriggerScheme must be a scalar, and must be logical, 0, or 1');
                end
            end
            self.broadcast('Update');            
        end  % function
        
        function value=getStimulationUsesAcquisitionTriggerScheme_(self)  % this is overridable by subclasses, whereas a getter is not
            value = self.StimulationUsesAcquisitionTriggerScheme_ ;
        end  % function                
        
        % Allows access to protected and protected variables from ws.mixin.Coding.
        function out = getPropertyValue(self, name)
            out = self.(name);
        end  % function
        
        % Allows access to protected and protected variables from ws.mixin.Coding.
        function setPropertyValue(self, name, value)
            self.(name) = value;
        end  % function
    end  % protected methods block
    
    methods (Access=protected)
        function setAcquisitionTriggerSchemeIndex_(self, newValue)  % this is overridable by subclasses, whereas a setter is not
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
