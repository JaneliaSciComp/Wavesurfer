classdef StickShiftBiasUserClass < ws.UserClass

    properties (Constant=true)
        cameraCount = 2;                       % number of cameras controlled through bias
        serverIPAddressAsString = '127.0.0.1';                % bias listens on this ip
        serverPortPerCamera = 5010:10:5040;             % bias listens at this port; for camera i, port  = 5000 + 10*i;
    end  % constant properties
            
    properties (Access=protected, Transient=true)
        areCameraInterfacesInitialized_ = false
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
        
        function startingSweep(~,~,~)
            % Called just before each trial
            fprintf('Starting a sweep.\n');
            if self.isIInFrontend_ ,
                self.configureForSweep_();
                self.start_();
            end
        end
        
        function completingSweep(~,~,~)
            %dbstack;
            fprintf('Completing a sweep.\n');
            if self.isIInFrontend_ ,
                self.stop_();
            end
        end
        
        function abortingSweep(~,~,~)
            %dbstack;
            fprintf('Oh noes!  A sweep aborted.\n');
            if self.isIInFrontend_ ,
                self.stop_();
            end
        end
        
        function stoppingSweep(~,~,~)
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
    end  % methods


    methods (Access=private)
        function initializeBiasCameraInterfaces_(self)
            disp('Calling BIAS init.');
            fprintf('Number of cameras found: %d\n', self.cameraCount) ;
            for i=1:self.cameraCount ,
                self.biasCameraInterfaces_{i} = ws.examples.bias.SimpleBiasCameraInterface(self.serverIPAddressAsString, self.serverPortPerCamera(i));
                self.biasCameraInterfaces_{i}.connectAndGetConfiguration() ;
            end
            for i=1:self.cameraCount ,
                self.biasCameraInterfaces_{i}.getStatus() ;  % call this just to make sure (hopefully) that BIAS is done
            end
            self.areCameraInterfacesInitialized_ = true ;
        end

        function configureForSweep_(self)
            disp('Calling BIAS config.');            
            for i=1:self.cameraCount ,
                self.biasCameraInterfaces_{i}.getStatus() ;  % call this just to make sure (hopefully) that BIAS is ready
            end
        end
        
        function start_(self)
            disp('Calling BIAS start.');
            for i=1:self.cameraCount ,
                self.biasCameraInterfaces_{i}.startCapture() ;
            end

            % wait for bias to be ready
            checkInterval = 0.1 ;  % s
            maxNumberOfChecks = 1000 ;
            for i=1:maxNumberOfChecks ,
                areAllCamerasCapturing = true ;
                for j=1:self.cameraCount ,
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
                for j=1:self.cameraCount
                    response = self.biasCameraInterfaces_{j}.getStatus() ;   % call this just to make sure BIAS is done
                    if response.value.capturing ,
                        isACameraCapturing = true ;
                        break ;
                    end
                end
                if isACameraCapturing ,
                    pause(checkInterval) ;    % have to wait a bit for both cams to be done
                else
                    break ;
                end
            end
            disp('Calling BIAS stop.');
            for i=1:self.cameraCount ,
                self.biasCameraInterfaces_{i}.stopCapture() ;
            end
        end
                
        function finalizeBiasCameraInterfaces_(self)
            disp('Calling BIAS finalize.');
            for i=1:self.cameraCount ,
                try
                    self.biasCameraInterfaces_{i}.disconnect();
                catch me  %#ok<NASGU>
                    % ignore
                end
                delete(self.biasCameraInterfaces_{i});
                self.biasCameraInterfaces_{i} = [] ;
            end
            self.biasCameraInterfaces_ = [] ;  
            self.areCameraInterfacesInitialized_ = false ;
        end
    end  % private methods block
    
end  % classdef

