classdef MicroManagerUserClass < ws.UserClass

    properties (Access=private, Transient=true)
        doesInterfaceExist_
        interface_
        isIInFrontend_ 
    end
    
    methods
        function self = MicroManagerUserClass(wsModel)
            fprintf('Creating the Micro-Manager user object\n') ;
            self.isIInFrontend_ = ( isa(wsModel,'ws.WavesurferModel') && wsModel.IsITheOneTrueWavesurferModel ) ;
            self.doesInterfaceExist_ = false ;
        end
        
        function delete(self)  %#ok<INUSD>
            fprintf('Deleting the Micro-Manager user object\n') ;
%             if self.areCameraInterfacesInitialized_ ,
%                 for i=1:self.cameraCount_ ,
%                     try
%                         %self.biasCameraInterfaces_{i}.disconnect();
%                     catch me  %#ok<NASGU>
%                         % ignore
%                     end
%                     delete(self.biasCameraInterfaces_{i});
%                     self.biasCameraInterfaces_{i} = [] ;  % set the cell to empty, but don't change length of cell array
%                 end
%                 self.biasCameraInterfaces_ = cell(1,0) ;  % set to zero-length cell array
%                 self.areCameraInterfacesInitialized_ = false ;
%             end
        end
        
        function startingRun(self,~,~)
            fprintf('Starting a run.\n');
            if self.isIInFrontend_ ,
                if ~self.doesInterfaceExist_ ,
                    self.interface_ = ws.examples.mm.MicroManagerInterface() ;
                    self.doesInterfaceExist_ = true ;
                    
                    % Make sure the server is there
                    fprintf('About to check if the server is alive...\n') ;
                    self.interface_.isBusy() ;
                    % We ignore the response, and only check that we get a response at all.
                end
            end
        end
        
        function startingSweep(self ,~, ~)
            % Called just before each sweep
            fprintf('Starting a sweep.\n');
            if self.isIInFrontend_ ,
                self.interface_.runWithoutBlocking() ;   % Tell MM to start acquiring (should be setup to wait for TTL trigger)
%                 % Wait for MM to be ready
%                 checkInterval = 0.1 ;  % s
%                 maxNumberOfChecks = 50 ;
%                 for i=1:maxNumberOfChecks ,
%                     isMMBusy = self.interface_.is()
%                     areAllCamerasCapturing = true ;
%                     
%                     for j=1:self.cameraCount_ ,
%                         response = self.biasCameraInterfaces_{j}.getStatus() ;   % call this just to make sure BIAS is capturing
%                         if ~response.value.capturing ,
%                             areAllCamerasCapturing = false ;
%                             break ;
%                         end
%                     end
%                     if areAllCamerasCapturing ,
%                         break ;
%                     else
%                         pause(checkInterval) ;    % have to wait a bit for both cams to be capturing
%                     end
%                 end                
            end
        end
        
        function completingSweep(self, ~, ~)
            fprintf('Completing a sweep.\n');
            self.completingOrAbortingOrStoppingASweep_();
        end
        
        function abortingSweep(self,~,~)
            fprintf('Oh noes!  A sweep aborted.\n');
            self.completingOrAbortingOrStoppingASweep_();
        end
        
        function stoppingSweep(self,~,~)
            fprintf('A sweep was stopped.\n');
            self.completingOrAbortingOrStoppingASweep_();
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
        end

        function startingEpisode(~,~,~)
        end
        
        function completingEpisode(~,~,~)
        end
        
        function abortingEpisode(~,~,~)
        end
        
        function stoppingEpisode(~,~,~)
        end
        
        % These methods are called in the looper process
        function samplesAcquired(self,looper,eventName,analogData,digitalData)  %#ok<INUSD>
            % Called each time a "chunk" of data (typically a few ms worth) 
            % is read from the DAQ board.
            %nScans = size(analogData,1);
            %fprintf('%s  Just acquired %d scans of data.\n',self.Greeting,nScans);                                    
        end        
    end  % public methods


    methods (Access=private)
        function completingOrAbortingOrStoppingASweep_(self)  %#ok<MANU>
            % wait for bias to be done
%             if self.isIInFrontend_ ,
%                 % Have to wait for a bit for all cameras to be done, we
%                 % discovered through a great deal of painful trial and
%                 % error.
%                 pause(0.1) ;
%                 
%                 % Tell bias to stop capturing
%                 for i=1:self.cameraCount_ ,
%                     self.biasCameraInterfaces_{i}.stopCapture() ;
%                 end
% 
%                 % Wait for it to stop capturing
%                 checkInterval = 0.1 ;  % s
%                 maxNumberOfChecks = 50 ;
%                 for i=1:maxNumberOfChecks ,
%                     isACameraCapturing = false ;
%                     for j=1:self.cameraCount_
%                         response = self.biasCameraInterfaces_{j}.getStatus() ;   % call this just to make sure BIAS is done
%                         if numel(response)==1 && isfield(response,'value') && isfield(response.value,'capturing') ,
%                             isThisCameraCapturing = response.value.capturing ;
%                             if numel(isThisCameraCapturing)==1 ,
%                                 if isThisCameraCapturing ,
%                                     % A camera is still capturing, so we
%                                     % can exit the for
%                                     % j=1:self.cameraCount_ loop
%                                     isACameraCapturing = true ;
%                                     break ;
%                                 else
%                                     % Communication is fine, and camera is
%                                     % not capturing, so go on to check the
%                                     % next camera.
%                                 end
%                             else
%                                 fprintf('Problem communicating with camera %d at end of a sweep: We''ll assume it is done capturing.\n', j-1) ;                                    
%                             end
%                         else
%                             fprintf('Problem communicating with camera %d at end of a sweep: We''ll assume it is done capturing.\n', j-1) ;                            
%                         end
%                     end
%                     if isACameraCapturing ,
%                         pause(checkInterval) ;    % have to wait a bit for all cams to be done
%                     else
%                         break ;
%                     end
%                 end     
%                 
%                 if isACameraCapturing ,
%                     fprintf('Warning: Gave up waiting for all cameras to not be capturing\n') ;
%                 else
%                     fprintf('For sweep end, all cameras say they''re not capturing\n') ;
%                 end 
%             end
        end  % function
    end  % private methods block
    
end  % classdef

