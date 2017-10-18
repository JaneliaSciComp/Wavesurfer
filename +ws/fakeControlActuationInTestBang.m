function [didWarningsOccur, warningsException] = fakeControlActuationInTestBang(target, controlName, varargin)            
    % This is like controlActuated(), but used when you want to
    % fake the actuation of a control, often in a testing script.
    % So, for instance, if only ws:warnings occur, if prints them,
    % rather than showing a dialog box.  Also, this lets
    % non-warning errors (including ws:invalidPropertyValue)
    % percolate upward, unlike controlActuated().  Also, this
    % always calls [controlName 'Actuated'], rather than using
    % source.Type to determine the method name.  That's becuase
    % there's generally no real source for fake actuations.
    didWarningsOccur = false ;
    warningsException = [] ;  % fallback
    try
        methodName = [controlName 'Actuated'] ;
        if ismethod(target, methodName) ,
            if ws.contains(controlName, 'Checkbox') ||  ws.contains(controlName, 'Edit') ,
                if nargin>=1 ,
                    source = ws.Valuable(varargin{1}) ; 
                    varargin = varargin(2:end) ;
                else
                    source = [] ;
                end
            else
                source = [] ;
            end
            event = [] ;
            target.(methodName)(source, event, varargin{:}) ;
        else
            error('ws:noSuchMethod' , ...
                  'There is no method named %s', methodName) ;                    
        end
    catch exception
        indicesOfWarningPhrase = strfind(exception.identifier,'ws:warningsOccurred') ;
        isWarning = (~isempty(indicesOfWarningPhrase) && indicesOfWarningPhrase(1)==1) ;
        if isWarning ,
            fprintf('A warning-level exception was thrown.  Here is the report for it:\n') ;
            disp(exception.getReport()) ;
            fprintf('(End of report for warning-level exception.)\n\n') ;
            didWarningsOccur = true ;
            warningsException = exception ;
        else
            rethrow(exception) ;
        end
    end
end  % function
