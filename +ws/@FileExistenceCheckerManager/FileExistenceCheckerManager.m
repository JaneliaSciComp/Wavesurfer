classdef FileExistenceCheckerManager < handle
%     properties (Constant, Access=private)
%         Store_ = ws.Store()
%     end
    
    properties (Dependent)
        Count
        UIDs
        IsRunning
    end
    
    properties (Access=private)
        %IsDLLLoaded_
        FileExistenceCheckersStruct_
        UIDs_
        NextUID_
        RunningCount_
        HookHandle_
    end
    
    methods (Access=private)
        function self = FileExistenceCheckerManager()
            self.FileExistenceCheckersStruct_ = ...
                struct('FilePath', cell(1,0), ...
                       'Callback', cell(1,0), ...
                       'IsRunning', cell(1,0), ...
                       'ThreadHandle', cell(1,0), ...
                       'ThreadId', cell(1,0), ...
                       'EndChildThreadEventHandle', cell(1,0)) ;  % a 1x0 struct with these fields
            self.UIDs_ = zeros(1,0) ;
            self.NextUID_ = uint64(1) ;
            self.RunningCount_ = 0 ;  % the number of file existence checkers that are currently running
            self.HookHandle_ = [] ;
            %self.HookHandle_ = ws.FileExistenceCheckerManager.callMexProcedure_('initialize') ;
        end  % function
    end

    methods 
        function delete(self)
            % Stop all the threads (can't use remove all b/c want to be as
            % robust as possible)
            n = length(self.FileExistenceCheckersStruct_) ;
            for i = n:-1:1 ,
                try
                    self.removeByIndex(i) ;
                catch me
                    fprintf('Error while attempting to remove file existence checker %d: %s', i, me.message) ;
                end
            end
            % Unregister the hook procedure
            %self.callMexProcedure_('finalize', self.HookHandle_) ;
        end  % function
        
        function removeAll(self)
            n = length(self.FileExistenceCheckersStruct_) ;
            for i = n:-1:1 ,
                self.removeByIndex(i) ;
            end
        end
        
        function result = get.Count(self) 
            result = length(self.FileExistenceCheckersStruct_) ;
        end
        
        function uid = add(self, filePath, callback)
            fec = struct('FilePath', filePath, ...
                         'Callback', callback, ...
                         'IsRunning', false, ...
                         'ThreadHandle', [], ...
                         'ThreadId', [], ...
                         'EndChildThreadEventHandle', []) ;  % a 1x0 struct with these fields
            fecs = self.FileExistenceCheckersStruct_ ;
            self.FileExistenceCheckersStruct_ = horzcat(fecs, fec) ;
            thisUID = self.NextUID_ ;
            self.NextUID_ = thisUID + 1 ;
            self.UIDs_ = horzcat(self.UIDs_, thisUID) ;            
            uid = self.UIDs_(end) ;
            %fprintf('Just added an FEC with UID %d\n', thisUID) ;
            %dbstack
        end  % function
        
        function remove(self, uid)
            uid = uint64(uid) ;
            i = self.indexFromUID_(uid) ;
            self.removeByIndex(i) ;
        end  % function

        function removeByIndex(self, index)
            if ~isempty(index) ,                
                self.stopByIndex(index) ;
                fec = self.FileExistenceCheckersStruct_(index) ;  % there can be only one
                if fec.IsRunning ,
                    error('FileExistenceCheckerManager:unableToRemoveBecauseUnableToStop', ...
                          'Unable to remove, because unable to stop.')
                else
                    self.FileExistenceCheckersStruct_(index) = [] ;
                    self.UIDs_(index) = [] ;
                end
            end
        end  % function
        
        function callCallback(self, uid, varargin)
            i = self.indexFromUID_(uid) ;
            if ~isempty(i) ,                
                fec = self.FileExistenceCheckersStruct_(i) ;
                feval(fec.Callback, varargin{:}) ;                
            end
        end  % function
        
        function result = get.UIDs(self)
            result = self.UIDs_ ;
        end  % function
        
        function result = get.IsRunning(self)
            result = [ self.FileExistenceCheckersStruct_.IsRunning ] ;
        end  % function
        
        function start(self, uid) 
            uid = uint64(uid) ;
            i = self.indexFromUID_(uid) ;
            self.startByIndex(i) ;
        end  % function

        function startByIndex(self, i) 
            if ~isempty(i) ,
                uid = self.UIDs_(i) ;
                fec = self.FileExistenceCheckersStruct_(i) ;  % there can be only one
                if ~fec.IsRunning ,
                    if self.RunningCount_==0 ,
                        self.HookHandle_ = ws.FileExistenceCheckerManager.callMexProcedure_('initialize') ;
                    end
                    [isRunning, threadHandle, threadId, endChildThreadEventHandle] = ...
                        ws.FileExistenceCheckerManager.callMexProcedure_('start', uid, fec.FilePath) ;
                    self.FileExistenceCheckersStruct_(i).IsRunning = isRunning ;
                    if isRunning ,
                        self.RunningCount_ = self.RunningCount_ + 1 ;
                        self.FileExistenceCheckersStruct_(i).ThreadHandle = threadHandle ;
                        self.FileExistenceCheckersStruct_(i).ThreadId = threadId ;
                        self.FileExistenceCheckersStruct_(i).EndChildThreadEventHandle = endChildThreadEventHandle ;
                    end
                end
            end
        end  % function
        
        function stop(self, uid) 
            uid = uint64(uid) ;
            i = self.indexFromUID_(uid) ;
            self.stopByIndex(i) ;
        end  % function

        function stopByIndex(self, i) 
            if ~isempty(i) ,                
                uid = self.UIDs_(i) ;
                fec = self.FileExistenceCheckersStruct_(i) ;  % there can be only one
                if fec.IsRunning ,
                    isRunning = ...
                        ws.FileExistenceCheckerManager.callMexProcedure_('stop', uid, fec.ThreadHandle, fec.ThreadId, fec.EndChildThreadEventHandle) ;
                    self.FileExistenceCheckersStruct_(i).IsRunning = isRunning ;
                    if ~isRunning, 
                        self.FileExistenceCheckersStruct_(i).ThreadHandle = [] ;
                        self.FileExistenceCheckersStruct_(i).ThreadId = [] ;
                        self.FileExistenceCheckersStruct_(i).EndChildThreadEventHandle = [] ;
                        self.RunningCount_ = self.RunningCount_ - 1 ;
                        if self.RunningCount_==0 ,
                            ws.FileExistenceCheckerManager.callMexProcedure_('finalize', self.HookHandle_) ;
                            self.HookHandle_ = [] ;
                        end
                    end
                end
            end
        end  % function
    end  % methods
        
    methods (Access=private)
        function result = indexFromUID_(self, uid)
            uid = uint64(uid) ;
            result = find(uid==self.UIDs_) ;  % there can be only one (at most)
        end
        
        function result = getByUID_(self, uid)
            uid = uint64(uid) ;
            isMatch = (uid==self.UIDs_) ;
            if any(isMatch) ,
                fec = self.FileExistenceCheckersStruct_(isMatch) ;  % there can be only one
                result = {fec} ;
            else
                result = cell(1,0) ;
            end
        end
    end  % private methods block
        
    methods (Static)
        function result = getShared(varargin)
            persistent singleton
            if nargin>0 && isequal(varargin{1},'doesSingletonExist') ,
                % Intended to be used mainly for debugging
                result = ~isempty(singleton) ;
            else
                if isempty(singleton) 
                    singleton = ws.FileExistenceCheckerManager() ;
                end
                result = singleton ;
            end
        end
    end  % static methods block
    
    methods (Static, Access=private)
        varargout = callMexProcedure_(methodName, varargin)
    end    
end  % classdef
