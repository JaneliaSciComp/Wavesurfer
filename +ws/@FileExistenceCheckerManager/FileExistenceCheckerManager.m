classdef FileExistenceCheckerManager < handle
    properties (Constant, Access=private)
        Store_ = ws.Store()
    end
    
    properties (Dependent)
        UIDs
    end
    
    properties (Access=private)
        IsDLLLoaded_
        FileExistenceCheckers_
        UIDs_
        NextUID_
        RunningCount_
        HookHandle_
    end
    
    methods (Access=private)
        function self = FileExistenceCheckerManager()
            self.FileExistenceCheckers_ = ...
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
            % Stop all the threads
            n = length(self.FileExistenceCheckers_) ;
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
        
        function result = getCount(self) 
            result = length(self.FileExistenceCheckers_) ;
        end
        
        function uid = add(self, filePath, callback)
            fec = struct('FilePath', filePath, ...
                         'Callback', callback, ...
                         'IsRunning', false, ...
                         'ThreadHandle', [], ...
                         'ThreadId', [], ...
                         'EndChildThreadEventHandle', []) ;  % a 1x0 struct with these fields
            fecs = self.FileExistenceCheckers_ ;
            self.FileExistenceCheckers_ = horzcat(fecs, fec) ;
            self.UIDs_ = horzcat(self.UIDs_, self.NextUID_) ;            
            self.NextUID_ = self.NextUID_ + 1 ;
            uid = self.UIDs_(end) ;
        end  % function
        
        function remove(self, uid)
            uid = uint64(uid) ;
            i = self.indexFromUID_(uid) ;
            self.removeByIndex(i) ;
        end  % function

        function removeByIndex(self, index)
            if ~isempty(index) ,                
                self.stopByIndex(index) ;
                fec = self.FileExistenceCheckers_(index) ;  % there can be only one
                if fec.IsRunning ,
                    error('FileExistenceCheckerManager:unableToRemoveBecauseUnableToStop', ...
                          'Unable to remove, because unable to stop.')
                else
                    self.FileExistenceCheckers_(index) = [] ;
                    self.UIDs_(index) = [] ;
                end
            end
        end  % function
        
        function callCallback(self, uid, varargin)
            i = self.indexFromUID_(uid) ;
            if ~isempty(i) ,                
                fec = self.FileExistenceCheckers_(i) ;
                feval(fec.Callback, varargin{:}) ;                
            end
        end  % function
        
        function result = get.UIDs(self)
            result = self.UIDs_ ;
        end  % function
        
        function start(self, uid) 
            uid = uint64(uid) ;
            i = self.indexFromUID_(uid) ;
            self.startByIndex(i) ;
        end  % function

        function startByIndex(self, i) 
            if ~isempty(i) ,
                uid = self.UIDs_(i) ;
                fec = self.FileExistenceCheckers_(i) ;  % there can be only one
                if ~fec.IsRunning ,
                    if self.RunningCount_==0 ,
                        self.HookHandle_ = ws.FileExistenceCheckerManager.callMexProcedure_('initialize') ;
                    end
                    [isRunning, threadHandle, threadId, endChildThreadEventHandle] = ...
                        ws.FileExistenceCheckerManager.callMexProcedure_('start', uid, fec.FilePath) ;
                    self.FileExistenceCheckers_(i).IsRunning = isRunning ;
                    if isRunning ,
                        self.RunningCount_ = self.RunningCount_ + 1 ;
                        self.FileExistenceCheckers_(i).ThreadHandle = threadHandle ;
                        self.FileExistenceCheckers_(i).ThreadId = threadId ;
                        self.FileExistenceCheckers_(i).EndChildThreadEventHandle = endChildThreadEventHandle ;
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
                fec = self.FileExistenceCheckers_(i) ;  % there can be only one
                if fec.IsRunning ,
                    isRunning = ...
                        ws.FileExistenceCheckerManager.callMexProcedure_('stop', uid, fec.ThreadHandle, fec.ThreadId, fec.EndChildThreadEventHandle) ;
                    self.FileExistenceCheckers_(i).IsRunning = isRunning ;
                    if ~isRunning, 
                        self.FileExistenceCheckers_(i).ThreadHandle = [] ;
                        self.FileExistenceCheckers_(i).ThreadId = [] ;
                        self.FileExistenceCheckers_(i).EndChildThreadEventHandle = [] ;
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
                fec = self.FileExistenceCheckers_(isMatch) ;  % there can be only one
                result = {fec} ;
            else
                result = cell(1,0) ;
            end
        end
    end  % private methods block
        
    methods (Static)
        function result = doesExist()
            store = ws.FileExistenceCheckerManager.Store_ ;
            result = ~isempty(store) && isvalid(store) && store.isValid() ;
        end
        
        function result = getShared()
            if ws.FileExistenceCheckerManager.doesExist() ,
                result = ws.FileExistenceCheckerManager.Store_.get() ;
            else
                fecm = ws.FileExistenceCheckerManager() ;
                ws.FileExistenceCheckerManager.Store_.set(fecm) ;
                result = fecm ;
            end
        end
        
        function deleteShared()
            if ws.FileExistenceCheckerManager.doesExist() ,
                fecm = ws.FileExistenceCheckerManager.getShared() ;
                fecm.delete() ;
                ws.FileExistenceCheckerManager.Store_.clear() ;  % just to be tidy
            end            
        end
    end  % static methods block
    
    methods (Static, Access=private)
        varargout = callMexProcedure_(methodName, varargin)
    end    
end  % classdef
