classdef CommandConnector < handle
    properties (Access=protected, Constant = true, Transient=true)
        CommunicationFolderName_ = tempdir()
        
        WSCommandFileName_ = 'ws_command.txt'  % Commands *to* WS
        WSResponseFileName_ = 'ws_response.txt'  % Responses *from* WS
        
        SICommandFileName_ = 'si_command.txt'  % Commands *to* SI
        SIResponseFileName_ = 'si_response.txt'  % Responses *from* SI
    end
    
    properties (Access=protected)
        IncomingCommandFilePath_
        OutgoingResponseFilePath_
        OutgoingCommandFilePath_
        IncomingResponseFilePath_
    end

    properties (Dependent=true)
        Parent
        IsEnabled
    end
    
    properties (Access=protected)
        Parent_  % the parent WS/SI model object
        IsParentWavesurferModel_
        IsEnabled_
        CommandFileExistenceChecker_  
        ExecutingIncomingCommandNow_
    end
    
    methods
        function self = CommandConnector(parent)
            self.Parent_ = parent ;
            self.IsParentWavesurferModel_ = isa(parent, 'ws.WavesurferModel') ;         
            if self.IsParentWavesurferModel_ ,
                self.IncomingCommandFilePath_ = fullfile(self.CommunicationFolderName_,self.WSCommandFileName_) ;
                self.OutgoingResponseFilePath_ = fullfile(self.CommunicationFolderName_,self.WSResponseFileName_) ;
                self.OutgoingCommandFilePath_ = fullfile(self.CommunicationFolderName_,self.SICommandFileName_) ;
                self.IncomingResponseFilePath_ = fullfile(self.CommunicationFolderName_,self.SIResponseFileName_) ;                
            else
                self.IncomingCommandFilePath_ = fullfile(self.CommunicationFolderName_,self.SICommandFileName_) ;
                self.OutgoingResponseFilePath_ = fullfile(self.CommunicationFolderName_,self.SIResponseFileName_) ;
                self.OutgoingCommandFilePath_ = fullfile(self.CommunicationFolderName_,self.WSCommandFileName_) ;
                self.IncomingResponseFilePath_ = fullfile(self.CommunicationFolderName_,self.WSResponseFileName_) ;                                
            end
            self.IsEnabled_ = false ;
            self.ExecutingIncomingCommandNow_ = false ;
        end
        
        function delete(self)            
            fprintf('In ws.CommandConnector::delete()\n') ;
            self.IsEnabled = false ;  % this will delete the CommandFileExistenceChecker_, if it is a valid object
        end

        function result = get.Parent(self)
            result = self.Parent_ ;
        end
        
        function result = get.IsEnabled(self)
            result = self.IsEnabled_ ;
        end
        
        function set.IsEnabled(self, newValue)
            err = [] ;
            
            if islogical(newValue) && isscalar(newValue) ,
                areFilesGone=self.ensureYokingFilesAreGone_();
                
                % If the yoking is being turned on (from being off), and
                % deleting the command/response files fails, don't go into
                % yoked mode.
                if ~areFilesGone && newValue && ~self.IsEnabled_ ,
                    err = MException('CommandConnector:UnableToDeleteExistingYokeFiles', ...
                                     'Unable to delete one or more yoking files') ;
                    newValue = false;
                end
                
                self.IsEnabled_ = newValue;
            end            
            
            % Start a thread to poll for the SI command file, or stop the
            % thread if we are diabled
            if self.IsEnabled_ ,
                self.CommandFileExistenceChecker_ = [] ;  % clear the old one
                self.CommandFileExistenceChecker_ = ...
                    ws.FileExistenceChecker(self.IncomingCommandFilePath_, ...
                                            @()(self.didReceiveIncomingCommands())) ;  % make a fresh one
                self.CommandFileExistenceChecker_.start();  % start it
            else
                self.CommandFileExistenceChecker_ = [] ;  % this will stop and delete it, if it exists
            end
            
            if ~isempty(err) ,
                throw(err) ;
            end
        end                
        
        function didReceiveIncomingCommands(self)
            % Checks for a command file created by ScanImage
            % If a command file is found, the command is parsed,
            % executed, and a response file is written
            
            if exist(self.IncomingCommandFilePath_,'file') ,
                try
                    lines = ws.readAllLines(self.IncomingCommandFilePath_);
                catch me ,
                    wrappingException = MException('CommandConnector:UnableToOpenYokingFile', ...
                                                   'Unable to open ScanImage command file');
                    finalException = addCause(wrappingException, me) ;
                    throw(finalException) ;
                end
                self.ensureYokingFilesAreGone_();
                
                try
                    self.executeIncomingCommands_(lines);
                catch ME
                    self.acknowledgeCommand_(false);
                    fprintf(2,'%s\n',ME.message);
                end
            end
        end
        
        function sendCommandAsString(self, commandAsString)
            % sends command to ScanImage and waits for ScanImage response
            % throws if communication fails
            
            if ~self.IsEnabled_ ,
                return
            end
            
            if self.ExecutingIncomingCommandNow_ ,
                return
            end
            
            [fid,fopenErrorMessage]=fopen(self.OutgoingCommandFilePath_,'wt');
            if fid<0 ,
                error('CommandConnector:UnableToOpenYokingFile', ...
                      'Unable to open outgoing command file: %s',fopenErrorMessage);
            end
            
            fprintf(fid,'%s',commandAsString);
            fclose(fid);
            
            [isPartnerReady,errorMessage]=self.waitForResponse_();
            if ~isPartnerReady ,
                self.ensureYokingFilesAreGone_();
                error('CommandConnector:ProblemCommandingPartner','Error sending command to partner.\nCmd:\n%s\n\nError:\n%s',...
                      commandAsString,errorMessage);
            end
        end % function
        
        function [isPartnerReady, errorMessage] = waitForResponse_(self)
            maximumWaitTime=30;  % sec
            dtBetweenChecks=0.1;  % sec
            nChecks=round(maximumWaitTime/dtBetweenChecks);
            
            for iCheck=1:nChecks ,
                % pause for dtBetweenChecks without relinquishing control
                % I assume this means we don't let UI callback run.  But
                % not clear why that's important here...
                timerVal=tic();
                while (toc(timerVal)<dtBetweenChecks)
                    x=1+1; %#ok<NASGU>
                end
                
                % Check for the response file
                doesReponseFileExist=exist(self.IncomingResponseFilePath_,'file');
                if doesReponseFileExist ,
                    [fid,fopenErrorMessage]=fopen(self.IncomingResponseFilePath_,'rt');
                    if fid>=0 ,                        
                        response=fscanf(fid,'%s',1);
                        fclose(fid);
                        if isequal(response,'OK') ,
                            ws.deleteFileWithoutWarning(self.IncomingResponseFilePath_);  % We read it, so delete it now
                            isPartnerReady=true;
                            errorMessage='';
                            return
                        end
                    else
                        isPartnerReady=false;
                        errorMessage=sprintf('Unable to open incoming response file: %s',fopenErrorMessage);
                        return
                    end
                end
            end
            
            % If get here, must have failed
            if exist(self.IncomingResponseFilePath_,'file') ,
                ws.deleteFileWithoutWarning(self.IncomingResponseFilePath_);  % If it exists, it's now a response to an old command
            end
            isPartnerReady=false;
            errorMessage='Partner did not respond within the alloted time';
        end  % function
        
        function clearExecutingIncomingCommandNow_(self)
            % This shouldn't need to exist, but b/c the WS commands play()
            % and run() are blocking, they need to because to clear this
            % so that a stop() command can be received during a run.
            self.ExecutingIncomingCommandNow_ = false ;
        end
    end  % public methods block
    
    methods (Access=protected)
        function executeIncomingCommands_(self, command_lines)
            % Executes a received command received from partner
            self.ExecutingIncomingCommandNow_ = true;
            
            % If our parent is WS, check to see if the command is a
            % blocking call, which must be the one and only command.
            if self.IsParentWavesurferModel_ && isscalar(command_lines) ,
                command_line = command_lines{1};
                if isempty(command_line) ,
                    is_blocking = false ;
                else
                    parsed_command_line = strsplit(command_line,'\s*\|\s*','DelimiterType','RegularExpression');
                    command = parsed_command_line{1};
                    parameters = parsed_command_line(2:end);                    
                    lower_command = lower(command) ;                    
                    if isequal(lower_command, 'record') || isequal(lower_command, 'play') ,
                        is_blocking = true ;
                    else
                        is_blocking = false ;
                    end
                end
            else
                is_blocking = false ;
            end
                        
            if is_blocking ,
                % Have to acknowledge the command before executing, b/c
                % command will block
                self.ExecutingIncomingCommandNow_ = false;
                self.acknowledgeCommand_();

                try
                    % awkward workaround because self.play() and self.record() is blocking call
                    % acknowledgeSICommand_ needs to be done before play and
                    % record
                    % flag self.ExecutingIncomingCommandNow_ is reset in self.run
                    self.ExecutingIncomingCommandNow_ = true;
                    self.Parent.executeIncomingCommand(command, parameters) ;
                    self.ExecutingIncomingCommandNow_ = false;
                catch ME
                    self.ExecutingIncomingCommandNow_ = false;
                    rethrow(ME);
                end
            else
                % no blocking commands
                for idx = 1:length(command_lines)
                    command_line = command_lines{idx};
                    if isempty(command_line)
                        continue
                    end
                    parsed_command_line = strsplit(command_line,'\s*\|\s*','DelimiterType','RegularExpression');
                    command = parsed_command_line{1};
                    parameters = parsed_command_line(2:end);

                    try
                        self.Parent.executeIncomingCommand(command, parameters) ;
                    catch ME
                        self.ExecutingIncomingCommandNow_ = false;
                        rethrow(ME);
                    end
                end
                self.ExecutingIncomingCommandNow_ = false;
                self.acknowledgeCommand_();
            end
        end  % function        
        
        function acknowledgeCommand_(self,success)
            % Sends acknowledgment of received command to ScanImage
            if nargin<2 || isempty(success)
                success = true;
            end            
            self.ensureYokingFilesAreGone_();
            
            [fid,fopenErrorMessage]=fopen(self.OutgoingResponseFilePath_,'wt');
            if fid<0 ,
                error('CommandConnector:UnableToOpenYokingFile', ...
                      'Unable to open outgoing response file: %s',fopenErrorMessage);
            end
            
            if success
                fprintf(fid,'OK');
            else
                fprintf(fid,'ERROR');
            end
            
            fclose(fid);
        end % function
        
        function [areFilesGone, errorMessage] = ensureYokingFilesAreGone_(self)
            % This deletes the command and response yoking files from the
            % temp dir, if they exist.  On exit, areFilesGone will be true
            % iff all files are gone.  If areFilesGone is false,
            % errorMessage will indicate what went wrong.            
            
            % A list of error messages we'll accumulate
            filePaths = {self.OutgoingCommandFilePath_ self.IncomingResponseFilePath_ self.OutgoingResponseFilePath_ self.IncomingCommandFilePath_} ;
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
    end
end
