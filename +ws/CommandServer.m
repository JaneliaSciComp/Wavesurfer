classdef CommandServer < handle
%     properties (Access=protected, Constant = true, Transient=true)
%         CommunicationFolderName_ = fullfile(tempdir(),'si-ws-comm') ;
%         
%         WSCommandFileName_ = 'ws_command.txt'  % Commands *to* WS
%         WSResponseFileName_ = 'ws_response.txt'  % Responses *from* WS
%         
%         SICommandFileName_ = 'si_command.txt'  % Commands *to* SI
%         SIResponseFileName_ = 'si_response.txt'  % Responses *from* SI
%     end
    
    properties (Access=protected, Transient=true)
        IncomingCommandFilePath_
        OutgoingResponseFilePath_
        %OutgoingCommandFilePath_
        %IncomingResponseFilePath_
    end

    properties (Dependent=true)
        Parent
        IsEnabled
        IsProcessingIncomingCommand
    end

    properties (Access=protected)
        IsEnabled_
    end
    
    properties (Access=protected, Transient=true)
        Parent_  % the parent WS/SI model object
        IsParentWavesurferModel_
        CommandFileExistenceChecker_  
        IsProcessingIncomingCommand_
    end
    
    methods
        function self = CommandServer(parent)
            self.IsEnabled_ = false ;
            self.Parent_ = parent ;
            self.IsParentWavesurferModel_ = isa(parent, 'ws.WavesurferModel') ;         
            isServer = true ;
            [self.IncomingCommandFilePath_, self.OutgoingResponseFilePath_] = ws.commandFilePaths(self.IsParentWavesurferModel_, isServer) ;
%             if self.IsParentWavesurferModel_ ,
%                 self.IncomingCommandFilePath_ = fullfile(self.CommunicationFolderName_,self.WSCommandFileName_) ;
%                 self.OutgoingResponseFilePath_ = fullfile(self.CommunicationFolderName_,self.WSResponseFileName_) ;
%                 %self.OutgoingCommandFilePath_ = fullfile(self.CommunicationFolderName_,self.SICommandFileName_) ;
%                 %self.IncomingResponseFilePath_ = fullfile(self.CommunicationFolderName_,self.SIResponseFileName_) ;                
%             else
%                 self.IncomingCommandFilePath_ = fullfile(self.CommunicationFolderName_,self.SICommandFileName_) ;
%                 self.OutgoingResponseFilePath_ = fullfile(self.CommunicationFolderName_,self.SIResponseFileName_) ;
%                 %self.OutgoingCommandFilePath_ = fullfile(self.CommunicationFolderName_,self.WSCommandFileName_) ;
%                 %self.IncomingResponseFilePath_ = fullfile(self.CommunicationFolderName_,self.WSResponseFileName_) ;                                
%             end
            self.IsProcessingIncomingCommand_ = false ;
        end  % function
        
        function delete(self)            
            %fprintf('In ws.CommandServer::delete()\n') ;
            self.IsEnabled = false ;  % this will delete the CommandFileExistenceChecker_, if it is a valid object
        end  % function

        function result = get.Parent(self)
            result = self.Parent_ ;
        end  % function
        
        function result = get.IsEnabled(self)
            result = self.IsEnabled_ ;
        end  % function
        
        function set.IsEnabled(self, newValue)
            err = [] ;
            
            if islogical(newValue) && isscalar(newValue) ,
                areFilesGone=self.ensureYokingFilesAreGone_();
                
                % If the yoking is being turned on (from being off), and
                % deleting the command/response files fails, don't go into
                % yoked mode.
                if ~areFilesGone && newValue && ~self.IsEnabled_ ,
                    err = MException('CommandServer:UnableToDeleteExistingYokeFiles', ...
                                     'Unable to delete one or more yoking files') ;
                    newValue = false;
                end
                
                self.IsEnabled_ = newValue;
            end            
            
            % Start a thread to poll for the SI command file, or stop the
            % thread if we are diabled
            if self.IsEnabled_ ,
                %ws.deleteIfValidHandle(self.CommandFileExistenceChecker_) ;  % Have to manually delete, b/c referenced by singleton FileExistenceCheckerManager
                self.CommandFileExistenceChecker_ = [] ;  % clear the old one (this *should* cause it to be delete()'d, I think
                self.CommandFileExistenceChecker_ = ...
                    ws.FileExistenceChecker(self.IncomingCommandFilePath_, ...
                                            @()(self.didDetectIncomingCommandFileChange())) ;  % make a fresh one
                self.CommandFileExistenceChecker_.start();  % start it
            else
                %ws.deleteIfValidHandle(self.CommandFileExistenceChecker_) ;  % Have to manually delete, b/c referenced by singleton FileExistenceCheckerManager
                self.CommandFileExistenceChecker_ = [] ;  % don't want a dangling reference hanging around
            end
            
            if ~isempty(err) ,
                throw(err) ;
            end
        end  % function
        
        function didDetectIncomingCommandFileChange(self)
            if exist(self.IncomingCommandFilePath_, 'file') ,
                self.didReceiveIncomingCommandFile() ;
            end
        end
        
        function didReceiveIncomingCommandFile(self)
            % Reads an incomming command file created by our partner.
            % The command file is parsed and checked for completeness.
            % If complete, the commands are executed, and a response 
            % file is written.
            
            %fprintf('At top of didReceiveIncomingCommandFile\n') ;
            
            % If we're in the midst of executing a command already, the
            % next command will have to wait.
            if self.IsProcessingIncomingCommand_ ,
                %fprintf('About to exit didReceiveIncomingCommandFile b/c IsProcessingIncomingCommand is true\n') ;
                return
            end
            self.IsProcessingIncomingCommand_ = true ;
            
            if exist(self.IncomingCommandFilePath_,'file') ,
                try
                    commandFileText = ws.readFileContents(self.IncomingCommandFilePath_) ;
                    %commandFileText
                catch me ,
                    wrappingException = MException('CommandServer:UnableToOpenYokingFile', ...
                                                   'Unable to open ScanImage command file') ;
                    finalException = addCause(wrappingException, me) ;
                    self.IsProcessingIncomingCommand_ = false ;
                    throw(finalException) ;
                end
                %self.ensureYokingFilesAreGone_() ;  % Can't do yet, b/c
                                                     % the command file might be incomplete
                
                try
                    self.executeIncomingCommand_(commandFileText) ;
                catch exception
                    self.acknowledgeCommand_(exception) ;
                    %fprintf(2,'%s\n',exception.message);
                end
            else
                %fprintf('In didReceiveIncomingCommandFile(), the incoming command file does not exist\n') ;
            end
            
            self.IsProcessingIncomingCommand_ = false ;
        end  % function
        
%         function sendCommandFileAsString(self, commandFileAsString)
%             % sends command to ScanImage and waits for ScanImage response
%             % throws if communication fails
%             
%             if ~self.IsEnabled_ ,
%                 return
%             end
% 
%             % If we're already processing a received command, don't also
%             % send commands back to our partner during execution
%             if self.IsProcessingIncomingCommand_ ,
%                 return
%             end
%             
%             fprintf('About to send command:\n') ;
%             disp(commandFileAsString) ;
%             
%             [fid,fopenErrorMessage]=fopen(self.OutgoingCommandFilePath_,'wt');
%             if fid<0 ,
%                 error('CommandServer:UnableToOpenYokingFile', ...
%                       'Unable to open outgoing command file: %s',fopenErrorMessage);
%             end
%             
%             fprintf(fid,'%s',commandFileAsString);
%             fclose(fid);
%             
%             [isPartnerReady,errorMessage]=self.waitForResponse_();
%             if isPartnerReady ,
%                 fprintf('Got OK response.\n\n\n') ;
%             else
%                 %fprintf('There was no response, or an ERROR response, or some other problem.\n') ;
%                 self.ensureYokingFilesAreGone_();
%                 error('CommandServer:ProblemCommandingPartner','Error sending command to partner.\nCommmand:\n%s\n\nError:\n%s',...
%                       commandFileAsString,errorMessage);
%             end
%         end  % function
        
%         function [isPartnerReady, errorMessage] = waitForResponse_(self)
%             maximumWaitTime=30;  % sec
%             dtBetweenChecks=0.1;  % sec
%             nChecks=round(maximumWaitTime/dtBetweenChecks);
%             
%             for iCheck=1:nChecks ,
%                 % pause for dtBetweenChecks without relinquishing control
%                 % I assume this means we don't let UI callback run.  But
%                 % not clear why that's important here...
%                 timerVal=tic();
%                 while (toc(timerVal)<dtBetweenChecks)
%                     x=1+1; %#ok<NASGU>
%                 end
%                 
%                 % Check for the response file
%                 doesReponseFileExist=exist(self.IncomingResponseFilePath_,'file');
%                 if doesReponseFileExist ,
%                     try
%                         responseFileText = ws.readFileContents(self.IncomingResponseFilePath_) ;
%                     catch me
%                         isPartnerReady=false;
%                         errorMessage=sprintf('Unable to open incoming response file: %s (%s)', me.message, me.identifier);
%                         return                        
%                     end
%                     lines = ws.splitIntoCompleteLines(responseFileText) ;
%                     lineCount = length(lines) ;
%                     if lineCount>=1 ,
%                         response = lines{1} ;
%                         ws.deleteFileWithoutWarning(self.IncomingResponseFilePath_) ;  % We read it, so delete it now
%                         if isequal(response,'OK') ,
%                             isPartnerReady = true ;
%                             errorMessage = '' ;
%                         else
%                             isPartnerReady = false ;
%                             errorMessage = response ;
%                         end
%                         return
%                     else
%                         % looks like response is not yet complete
%                         % do nothing, hopefully will be done next time around
%                     end
%                 end
%             end
%             
%             % If get here, must have timed out
%             % Do we want to delete it here?  Why not just delete a pre-existing reponse file
%             % just before giving a command?
%             if exist(self.IncomingResponseFilePath_,'file') ,
%                 ws.deleteFileWithoutWarning(self.IncomingResponseFilePath_);  % If it exists, it's now a response to an old command
%             end
%             isPartnerReady=false;
%             errorMessage='Partner did not respond within the alloted time';
%         end  % function
        
        function result = get.IsProcessingIncomingCommand(self)
            result = self.IsProcessingIncomingCommand_ ;
        end
        
        function clearIsProcessingIncomingCommand_(self)
            % This shouldn't need to exist, but b/c the WS commands play()
            % and run() are blocking, they need to because to clear this
            % so that a stop() command can be received during a run.
            self.IsProcessingIncomingCommand_ = false ;
        end
    end  % public methods block
    
    methods (Access=protected)
        function executeIncomingCommand_(self, commandFileText)
            % Executes a received command received from partner
            
            % Each command file is generally a set of commands, 
            % They get executed in sequence, and then an
            % acknowledgement is sent.
            %self.IsProcessingIncomingCommand_ = true;
            [isCompleteCommandFile, commands] = ws.CommandServer.parseIncomingCommandFile(commandFileText) ;
            if isCompleteCommandFile ,
                self.ensureYokingFilesAreGone_() ;
                if self.IsParentWavesurferModel_ && isscalar(commands) ,
                    command = commands ;  % b/c scalar
                    isBlocking = ( isequal(command.name, 'record') || isequal(command.name, 'play') ) ;
                else
                    isBlocking = false ;
                end

                if isBlocking ,
                    % Have to acknowledge the command before executing, b/c
                    % command will block
                    %self.IsProcessingIncomingCommand_ = false ;
                    self.acknowledgeCommand_() ;

                    try
                        % awkward workaround because self.play() and self.record() is blocking call
                        % acknowledgeSICommand_ needs to be done before play and
                        % record
                        % flag self.IsProcessingIncomingCommand_ is reset in self.run
                        %self.IsProcessingIncomingCommand_ = true ;
                        self.Parent.executeIncomingCommand(command) ;  % we know commands is a scalar
                        %self.IsProcessingIncomingCommand_ = false ;
                    catch ME
                        %self.IsProcessingIncomingCommand_ = false ;
                        rethrow(ME) ;
                    end
                else
                    % no blocking commands
                    for idx = 1:length(commands) ,
                        command = commands(idx) ;
                        try
                            self.Parent.executeIncomingCommand(command) ;
                        catch ME
                            %self.IsProcessingIncomingCommand_ = false ;
                            rethrow(ME) ;
                        end
                    end
                    %self.IsProcessingIncomingCommand_ = false ;
                    self.acknowledgeCommand_() ;
                end                
            end
        end  % function
            
%         function executeIncomingCommandToSIFromWS_(self, lines)
%             % Each command from WS is a single command, basically, and SI
%             % doesn't block.
%             self.IsProcessingIncomingCommand_ = true ;
%             [command, parameters] = ws.CommandServer.parseIncomingCommandToSIFromWS(lines) ;
%             try
%                 self.Parent.executeIncomingCommand(command, parameters) ;
%             catch ME
%                 self.IsProcessingIncomingCommand_ = false ;
%                 rethrow(ME) ;
%             end
%             self.IsProcessingIncomingCommand_ = false ;
%             self.acknowledgeCommand_() ;             
%         end
            
        function acknowledgeCommand_(self, exception)
            % Sends acknowledgment of received command to ScanImage.  Also deletes the
            % just-received command file.
            if nargin<2 || isempty(exception) ,
                exception = [] ;
            end            
            self.ensureYokingFilesAreGone_();
            
            [fid,fopenErrorMessage]=fopen(self.OutgoingResponseFilePath_,'wt');
            if fid<0 ,
                error('CommandServer:UnableToOpenYokingFile', ...
                      'Unable to open outgoing response file: %s',fopenErrorMessage);
            end
            
            if isempty(exception) ,
                fprintf(fid,'OK\n');
            else
                fprintf(fid,'ERROR: %s (%s)\n', exception.message, exception.identifier);
            end
            
            fclose(fid);
        end  % function
        
        function [areFilesGone, errorMessage] = ensureYokingFilesAreGone_(self)
            % This deletes the command and response yoking files from the
            % temp dir, if they exist.  On exit, areFilesGone will be true
            % iff all files are gone.  If areFilesGone is false,
            % errorMessage will indicate what went wrong.            
            
            % A list of error messages we'll accumulate
            filePaths = {self.OutgoingResponseFilePath_ self.IncomingCommandFilePath_} ;
            errorMessages = cell(1,0) ;
            for i = 1:length(filePaths) ,
                filePath = filePaths{i} ;
                [isFileGone, errorMessage] = ws.ensureSingleFileIsGone(filePath) ;
                if ~isFileGone ,
                    errorMessages = horzcat(errorMessage, {errorMessage}) ;
                end
            end
            
            % Determine whether all files are gone
            areFilesGone = isempty(errorMessages) ;
            if isempty(errorMessages) ,
                errorMessage = '' ;
            elseif isscalar(errorMessages) ,
                errorMessage = errorMessages{1} ;
            else
                errorMessage = 'Multiple problems deleting preexisting WS-SI yoking files' ;
            end                
        end  % function        
    end  % protected methods block
    
    methods (Static)
%         function [command, parameters] = parseIncomingCommandToSIFromWS(lines)
%             if isempty(lines) ,
%                 command = '' ;
%                 parameters = cell(1,0) ;                
%             else
%                 command = strtrim(lines{1}) ;
%                 lineCount = length(lines) ;
%                 parameterCount = lineCount-1 ;
%                 parameters = cell(1,parameterCount) ;
%                 for i = 1:parameterCount ,
%                     parameterLine = lines{i+1} ;
%                     parsedParameterLine = strsplit(parameterLine,'|') ;
%                     if length(parsedParameterLine)>=2 ,
%                         parameterValue = strtrim(parsedParameterLine{2}) ;
%                     else
%                         parameterValue = '' ;
%                     end
%                     parameters{i} = parameterValue ;
%                 end
%             end
%         end
        
        function [isComplete, commands] = parseIncomingCommandFile(commandFileText)
            % Each command file from SI contains a set of mini-commands.
            % This thing will not throw if the command file text is merely incomplete, only
            % if it seems to be malformed.
            lines = ws.splitIntoCompleteLines(commandFileText) ;
            lineCount = length(lines) ;
            if lineCount == 0 ,
                % this is presumably an incomplete file
                isComplete = false ;
                commands = [] ;
            else
                firstLine = lines{1} ;  % should contain number of mini-commands
                commandCount = str2double(firstLine) ;
                if isfinite(commandCount) && commandCount>=0 && round(commandCount)==commandCount ,
                    if lineCount >= commandCount+1 ,
                        commands = struct('name', cell(commandCount,1), ...
                                          'parameters', cell(commandCount,1)) ;
                        for commandIndex = 1:commandCount ,
                            line = lines{commandIndex+1} ;
                            if isempty(line) ,
                                % This is odd, but we'll allow it, I guess...
                                name = '' ;
                                parameters = cell(1,0) ;                            
                            else
                                % Parse the line to get the minicommand and the parameters for it
                                split_line = strsplit(line,'\s*\|\s*','DelimiterType','RegularExpression');
                                name = lower(split_line{1}) ;
                                parameters = split_line(2:end) ;
                            end
                            command = struct('name', {name},  ...
                                             'parameters', {parameters}) ;  % a scalar struct
                            commands(commandIndex) = command ;
                        end        
                        isComplete = true ;
                    else
                        % There are fewer lines than there should be, so this file is presumably
                        % incomplete.
                        isComplete = false ;
                        commands = [] ;                        
                    end
                else
                    % the first line does not seem to contain a number of minicommands
                    error('ws:CommandServer:badCommandFile', ...
                          'The command file seems to be badly formed') ;
                end
            end    
        end  % function        
    end  % static methods
end  % classdef
