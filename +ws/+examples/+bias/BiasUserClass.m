classdef BiasUserClass < ws.UserClass

    properties
        enabled = 1;                          % Enable/Disable Camera
        
        %% PointGrey/Flea3 properties
        bias_nCams = 2;                       % number of cameras controlled through bias
        bias_ip = '127.0.0.1';                % bias listens on this ip
        bias_port = 5010:10:5040;             % bias listens at this port; for camera i, port  = 5000 + 10*i;
        bias_cfgFiles = {'Camera0_config_Jay20160726.json' 'Camera1_config_Jay20160726.json'};  % specify json cfg file for bias to use
        cameraOn = 1;
        hardTrig = 1;
        frameRate = 500;
        camTrigCOChan = 2;
        boardID = 'Dev1';
        hCamTrig;                             % Handle to counter out channel
        cameraStartEvent = 'Start';           % One of 'TTL' or 'Start'. Starts camera acq when either TTL button is pressed or Start btn is pressed
        ttlPulseChan = 3;                     % TTL output channel; Should be same as TTL pulse chan in ReachTask.m
        
        %% BIAS Properties (frameRate, movieFormat, ROI, triggerMode)
        %Camera 1
        bias_cam1_frameRate = 500;
        bias_cam1_movieFormat = 'avi';
        bias_cam1_ROI = [504,418,384,260];
        bias_cam1_triggerMode = 'External';
        bias_cam1_shutterValue = 157;
        
        %Camera 2
        bias_cam2_frameRate = 500;
        bias_cam2_movieFormat = 'avi';
        bias_cam2_ROI = [312,318,384,260];
        bias_cam2_triggerMode = 'External';
        bias_cam2_shutterValue = 157;
        
        % Bookkeeping
        %HasRunStart = false
    end  % properties
            
    properties (Access=protected, Transient=true)
        bias                                 % handle to bias object(s)
        IsIInFrontend        
    end
    
    methods
        %% User functions    
        function self = BiasUserClass(userCodeManager)
            if isa(userCodeManager.Parent,'ws.WavesurferModel') && userCodeManager.Parent.IsITheOneTrueWavesurferModel ,
                self.IsIInFrontend = true ;
                self.initialize();
            else
                self.IsIInFrontend = false ;
            end
        end
        
        function delete(self)
            if self.IsIInFrontend ,
                % self.close();  % doesn't seem to work right...
            end
        end
        
        function startingRun(self,~,~)
            fprintf('Starting a run.\n');
            self.configure();
            self.start();
        end
        
        function startingSweep(~,~,~)
            % Called just before each trial
            fprintf('Starting a sweep.\n');
        end
        
        function completingSweep(~,~,~)
            %dbstack;
            fprintf('Completing a sweep.\n');
        end
        
        function abortingSweep(~,~,~)
            %dbstack;
        end
        
        function stoppingSweep(~,~,~)
            %dbstack;
        end
        
        function completingRun(self,~,~)
            % Called just after each set of trials (a.k.a. each
            % "experiment")
            fprintf('Completing a run.\n');
            self.stop();
        end
        
        function abortingRun(self,~,~)
            % Called if a trial set goes wrong, after the call to
            % trialDidAbort()
            fprintf('Oh noes!  A run aborted.\n');
            self.stop();
        end
        
        function stoppingRun(self,~,~)
            fprintf('A run was stopped.\n');
            self.stop();
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


    methods(Access=private)
        %% Bias Operations
        function initialize(obj)
            disp('Calling BIAS init.');
            fprintf('Number of cameras found: %d\n', obj.bias_nCams) ;
            for i=1:obj.bias_nCams
                obj.bias{i} = ws.examples.bias.BiasInterface(obj.bias_ip,obj.bias_port(i));
                obj.bias{i}.initializeCamera(...
                    obj.(sprintf('bias_cam%d_frameRate',i)),...
                    obj.(sprintf('bias_cam%d_movieFormat',i)),...
                    obj.(sprintf('bias_cam%d_ROI',i)),...
                    obj.(sprintf('bias_cam%d_triggerMode',i)),...
                    obj.(sprintf('bias_cam%d_shutterValue',i))...
                );
            end
            for i=1:obj.bias_nCams
                obj.bias{i}.getStatus() ;  % call this just to make sure (hopefully) that BIAS is done
            end
        end

        function configure(obj)
            disp('Calling BIAS config.');            
            for i=1:obj.bias_nCams
                if exist(obj.bias_cfgFiles{i},'file');
                    obj.bias{i}.loadConfiguration(obj.bias_cfgFiles{i});
                end
            end
            for i=1:obj.bias_nCams
                obj.bias{i}.getStatus() ;  % call this just to make sure (hopefully) that BIAS is done
            end
        end
        
        function start(obj)
            disp('Calling BIAS start.');
            for i=1:obj.bias_nCams
                obj.bias{i}.startCapture;
%                 if obj.HasRunStart ,
%                      % do nothing
%                 else
%                     pauseDuration = 0.2 
%                     pause(pauseDuration) ;  % wait a bit on first start
%                 end
            end
%             if ~obj.HasRunStart ,
%                 obj.HasRunStart = true ;
%             end
        end
                
        function stop(obj)
            % wait for bias to be done
            checkInterval = 0.1 ;  % s
            maxNumberOfChecks = 10 ;
            for i=1:maxNumberOfChecks ,
                isACameraCapturing = false ;
                for j=1:obj.bias_nCams
                    response = obj.bias{j}.getStatus() ;   % call this just to make sure BIAS is done
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
            for i=1:obj.bias_nCams
                obj.bias{i}.stopCapture;
            end
        end
                
        function close(obj)
            % (ngc) when should I call this?
            disp('Calling BIAS close.');
            for i=1:obj.bias_nCams
                try
                    obj.bias{i}.disconnect();
                    obj.bias{i}.closeWindow;
                    delete(obj.bias{i});
                catch
                    disp('ERROR: on disconnect...Kill BIAS')
                    obj.bias{end}.kill;
                end
            end
        end
    end
    
end  % classdef

