classdef StickShiftBiasUserClass < ws.UserClass

    properties (Constant=true)
        serverIPAddressAsString = '127.0.0.1';                % bias listens on this ip
        serverFirstCameraPort = 5010 ;
        serverPortStride = 10 ;  % We assume bias listens at port serverFirstCameraPort for the 1st camera, serverFirstCameraPort+serverPortStride for 2nd, etc
    end  % constant properties
            
    properties (Dependent=true)
        cameraCount
    end
    
    properties (Access=protected, Transient=true)
        areCameraInterfacesInitialized_ = false
        cameraCount_
        biasCameraInterfaces_    % cell array of handles to bias camera interface object(s)
        isIInFrontend_ 
    end
    
    methods
        function self = StickShiftBiasUserClass(userCodeManager)
            self.isIInFrontend_ = ( isa(userCodeManager.Parent,'ws.WavesurferModel') && userCodeManager.Parent.IsITheOneTrueWavesurferModel ) ;
        end
        
        function delete(self)
            if self.areCameraInterfacesInitialized_ ,
                self.finalizeBiasCameraInterfaces_() ;
            end
        end
        
        function startingRun(self,~,~)
            fprintf('Starting a run.\n');
            if self.isIInFrontend_ ,
                if ~self.areCameraInterfacesInitialized_ ,
                    self.initializeBiasCameraInterfaces_() ;
                end
            end
        end
        
        function startingSweep(self ,~, ~)
            % Called just before each trial
            fprintf('Starting a sweep.\n');
            if self.isIInFrontend_ ,
                self.configureForSweep_();
                self.start_();
            end
        end
        
        function completingSweep(self, ~, ~)
            %dbstack;
            fprintf('Completing a sweep.\n');
            if self.isIInFrontend_ ,
                self.stop_();
            end
        end
        
        function abortingSweep(self,~,~)
            %dbstack;
            fprintf('Oh noes!  A sweep aborted.\n');
            if self.isIInFrontend_ ,
                self.stop_();
            end
        end
        
        function stoppingSweep(self,~,~)
            %dbstack;
            fprintf('A sweep was stopped.\n');
            if self.isIInFrontend_ ,
                self.stop_();
            end
        end
        
        function completingRun(self,~,~) %#ok<INUSD>
            % Called just after each set of trials (a.k.a. each
            % "experiment")
            fprintf('Completing a run.\n');
        end
        
        function abortingRun(self,~,~) %#ok<INUSD>
            % Called if a trial set goes wrong, after the call to
            % trialDidAbort()
            fprintf('Oh noes!  A run aborted.\n');
        end
        
        function stoppingRun(self,~,~) %#ok<INUSD>
            fprintf('A run was stopped.\n');
        end
        
        function dataAvailable(~,~,~)
            %dbstack;
        end

        function startingEpisode(~,~,~)
            % Called just before each trial
            fprintf('About to start a sweep.\n');
        end
        
        function completingEpisode(~,~,~)
            %dbstack;
        end
        
        function abortingEpisode(~,~,~)
            %dbstack;
        end
        
        function stoppingEpisode(~,~,~)
            %dbstack;
        end
        
        % These methods are called in the looper process
        function samplesAcquired(self,looper,eventName,analogData,digitalData)  %#ok<INUSD>
            % Called each time a "chunk" of data (typically a few ms worth) 
            % is read from the DAQ board.
            %nScans = size(analogData,1);
            %fprintf('%s  Just acquired %d scans of data.\n',self.Greeting,nScans);                                    
        end
        
        function result = get.cameraCount(self)
            result = self.cameraCount_ ;
        end
    end  % methods


    methods (Access=private)
        function initializeBiasCameraInterfaces_(self)
            disp('Calling BIAS init.');
            cameraCount = 0 ;  %#ok<PROP>
            for iCamera = 1:16 ,  % no one will have more cameras than this
                portNumber = self.serverFirstCameraPort + (iCamera-1)*self.serverPortStride ;
                cameraInterface = ws.examples.bias.SimpleBiasCameraInterface(self.serverIPAddressAsString, portNumber) ;
                try
                    cameraInterface.connectAndGetConfiguration() ;
                catch me
                    if isequal(me.identifier, 'SimpleBiasCameraInterface:unableToConnectToBIASServer') ,
                        break ;
                    else
                        me.rethrow() ;
                    end
                end
                % if get here, must have successfully connected to camera i
                cameraCount = iCamera ;  %#ok<PROP>
                self.biasCameraInterfaces_{1,iCamera} = cameraInterface ;
            end
            self.cameraCount_ = cameraCount ;  %#ok<PROP>
            fprintf('Number of cameras found: %d\n', cameraCount) ;  %#ok<PROP>
%             % Get status from each camera, to make sure BIAS is really
%             % ready to go
%             for iCamera = 1:cameraCount ,
%                 self.biasCameraInterfaces_{iCamera}.getStatus() ;
%             end
            % Finally, set the semaphore
            self.areCameraInterfacesInitialized_ = true ;
        end

        function configureForSweep_(self)
            disp('Calling BIAS config.');
            % Get status from each camera, to make sure BIAS is really
            % ready to go
            for i=1:self.cameraCount_ ,
                self.biasCameraInterfaces_{i}.getStatus() ; 
            end
        end
        
        function start_(self)
            disp('Calling BIAS start.');
            for i=1:self.cameraCount_ ,
                self.biasCameraInterfaces_{i}.startCapture() ;
            end

            % wait for bias to be ready
            checkInterval = 0.1 ;  % s
            maxNumberOfChecks = 1000 ;
            for i=1:maxNumberOfChecks ,
                areAllCamerasCapturing = true ;
                for j=1:self.cameraCount_ ,
                    response = self.biasCameraInterfaces_{j}.getStatus() ;   % call this just to make sure BIAS is capturing
                    if ~response.value.capturing ,
                        areAllCamerasCapturing = false ;
                        break ;
                    end
                end
                if areAllCamerasCapturing ,
                    break ;
                else
                    pause(checkInterval) ;    % have to wait a bit for both cams to be capturing
                end
            end
        end  % method        
                
        function stop_(self)
            % wait for bias to be done
            checkInterval = 0.1 ;  % s
            maxNumberOfChecks = 10 ;
            for i=1:maxNumberOfChecks ,
                isACameraCapturing = false ;
                for j=1:self.cameraCount_
                    response = self.biasCameraInterfaces_{j}.getStatus() ;   % call this just to make sure BIAS is done
                    if response.value.capturing ,
                        isACameraCapturing = true ;
                        break ;
                    end
                end
                if isACameraCapturing ,
                    pause(checkInterval) ;    % have to wait a bit for all cams to be done
                else
                    break ;
                end
            end
            disp('Calling BIAS stop.');
            for i=1:self.cameraCount_ ,
                self.biasCameraInterfaces_{i}.stopCapture() ;
            end
        end
                
        function finalizeBiasCameraInterfaces_(self)
            disp('Calling BIAS finalize.');
            for i=1:self.cameraCount_ ,
                try
                    self.biasCameraInterfaces_{i}.disconnect();
                catch me  %#ok<NASGU>
                    % ignore
                end
                delete(self.biasCameraInterfaces_{i});
                self.biasCameraInterfaces_{i} = [] ;  % set the cell to empty, but don't change length of cell array
            end
            self.biasCameraInterfaces_ = cell(1,0) ;  % set to zero-length cell array
            self.areCameraInterfacesInitialized_ = false ;
        end
    end  % private methods block
    
end  % classdef

