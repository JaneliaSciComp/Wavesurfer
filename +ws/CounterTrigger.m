classdef CounterTrigger < ws.Model
    % This class represents a trigger source, i.e. an internally-generated
    % trigger output.  A trigger source has a device (e.g. 'Dev1'), a
    % counter (the index of the NI DAQmx counter), an inter-trigger
    % interval, a PFIID (the NI zero-based index of the PFI line used for
    % output), and an Edge (the edge polarity used).
    
    properties (Dependent=true)
        Name
        RepeatCount
        DeviceName  % the NI device ID string, e.g. 'Dev1'
        CounterID  % the index of the DAQmx Counter device (zero-based)
        Interval  % the inter-trigger interval, in seconds
        PFIID
        Edge
        IsMarkedForDeletion
    end
    
    properties (Access=protected)
        Name_
        IsInternalRepeatCountOverridden_
        InternalRepeatCount_  % our internal RepeatCount value, which can be overridden
        ExternalRepeatCount_  % the overriding RepeatCount value
        Interval_
        CounterID_
        Edge_
        DeviceName_
        IsMarkedForDeletion_
    end

    methods
        function self = CounterTrigger(parent)  %#ok<INUSD>
            self = self@ws.Model([]) ;  % ignore parent arg
            self.Name_ = 'Counter Trigger' ;
            self.IsInternalRepeatCountOverridden_ = false ;
            self.InternalRepeatCount_ = 1 ;
            self.ExternalRepeatCount_ = [] ;            
            self.CounterID_ = 0 ;
            self.Interval_ = 1 ;  % s
            self.Edge_ = 'rising' ;
            self.IsMarkedForDeletion_ = false ;
        end
        
        function value=get.Name(self)
            value=self.Name_;
        end
        
        function value=get.DeviceName(self)
            value=self.DeviceName_;
        end

        function set.DeviceName(self, deviceName)  % should only be called by triggering subsystem
            self.DeviceName_ = deviceName ;
        end        
        
        function didSetDeviceName(self, deviceName)  % should only be called by triggering subsystem
            self.DeviceName_ = deviceName ;
        end        
        
        function value = get.RepeatCount(self)
            % In some circumstances, the internal value is overridden by
            % the NSweepsPerRun property of the root model.  Otherwise,
            % just return self.RepeatCount_.
            if self.IsInternalRepeatCountOverridden_ ,
                value = self.ExternalRepeatCount_ ;
            else
                value = self.InternalRepeatCount_ ; 
            end                
        end  % function
        
        function set.RepeatCount(self, newValue)
            if self.IsInternalRepeatCountOverridden_ ,
                %self.Parent.update();
                error('ws:invalidPropertyValue', ...
                      'Can''t set RepeatCount when it is overridden');
            else
                if ws.CounterTrigger.isValidRepeatCount(newValue) ,
                    self.InternalRepeatCount_ = double(newValue) ;
                    %self.Parent.update();
                else
                    %self.Parent.update();
                    error('ws:invalidPropertyValue', ...
                          'RepeatCount must be a (scalar) positive integer, or inf');
                end                
            end
        end
        
        function overrideRepeatCount(self, newValue)
            if ws.CounterTrigger.isValidRepeatCount(newValue) ,
                self.IsInternalRepeatCountOverridden_ = true ;
                self.ExternalRepeatCount_ = double(newValue) ;
            else
                error('ws:invalidPropertyValue', ...
                      'RepeatCount must be a (scalar) positive integer, or inf');
            end
        end
        
        function releaseRepeatCount(self)
            self.IsInternalRepeatCountOverridden_ = false ;
            self.ExternalRepeatCount_ = [] ;  % for tidiness
%             self.Parent.update();
        end        
        
        function value=get.Interval(self)
            value=self.Interval_;
        end
        
        function set.Interval(self, value)
            if ws.isASettableValue(value) ,
                if isnumeric(value) && isscalar(value) && isreal(value) && value>0 ,
                    self.Interval_ = value ;
                else
                    %self.Parent.update() ;
                    error('ws:invalidPropertyValue', ...
                          'Interval must be a (scalar) positive integer') ;       
                end
            end
            %self.Parent.update();                
        end
        
        function value=get.CounterID(self)
            value=self.CounterID_;
        end
        
        function value=get.PFIID(self)
            value = self.CounterID_ + 12 ;  
              % This rule works for X series boards, and doesn't rely on
              % w.g. self.Parent.Parent.NPFITerminals being correct, which
              % it generally isn't for the refiller
            %rootModel = self.Parent.Parent ;
            %numberOfPFILines = rootModel.NPFITerminals ;
            %nCounters = rootModel.NCounters ;
            %value = numberOfPFILines - nCounters + self.CounterID_ ;  % the default counter outputs are at the end of the PFI lines
        end
        
        function value=get.Edge(self)
            value=self.Edge_;
        end
        
        function value = get.IsMarkedForDeletion(self)
            value = self.IsMarkedForDeletion_ ;
        end

        function set.IsMarkedForDeletion(self, value)
            if ws.isASettableValue(value) ,
                if (islogical(value) || isnumeric(value)) && isscalar(value) ,
                    self.IsMarkedForDeletion_ = logical(value) ;
                else
                    %self.Parent.update();
                    error('ws:invalidPropertyValue', ...
                          'IsMarkedForDeletion must be a truthy scalar');                  
                end                    
            end
            %self.Parent.update();            
        end
        
        function set.Name(self, value)
            if ws.isASettableValue(value) ,
                if ws.isString(value) && ~isempty(value) ,
                    self.Name_ = value ;
                else
                    %self.Parent.update();
                    error('ws:invalidPropertyValue', ...
                          'Name must be a nonempty string');                  
                end                    
            end
            %self.Parent.update();            
        end
        
        function set.Edge(self, value)
            if ws.isASettableValue(value) ,
                if ws.isAnEdgeType(value) ,
                    self.Edge_ = value;
                else
                    %self.Parent.update();
                    error('ws:invalidPropertyValue', ...
                          'Edge must be ''rising'' or ''falling''');                  
                end                                        
            end
            %self.Parent.update();            
        end  % function 
        
        function set.CounterID(self, value)
            if ws.isASettableValue(value) ,
                if isnumeric(value) && isscalar(value) && isreal(value) && value==round(value) && value>=0 ,
                    value = double(value) ;
                    self.CounterID_ = value ;
                    %self.syncPFIIDToCounterID_() ;
                else
                    %self.Parent.update();
                    error('ws:invalidPropertyValue', ...
                          'CounterID must be a (scalar) nonnegative integer');                  
                end                    
            end
            %self.Parent.update();            
        end  % function        
    end  % public methods
    
    methods (Access=protected)        
        function out = getPropertyValue_(self, name)
            out = self.(name);
        end  % function
        
        % Allows access to protected and protected variables from ws.Coding.
        function setPropertyValue_(self, name, value)
            self.(name) = value;
        end  % function
    end  % protected methods block
    
    methods (Static)
        function result = isValidRepeatCount(value)
            result = ( isscalar(value) && isnumeric(value) && isreal(value) && value>0 && (round(value)==value || isinf(value)) ) ;
        end  % function
    end  % static methods block
end  % classdef
