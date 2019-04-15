function raiseDialogOnException(exception)
    indicesOfWarningPhrase = strfind(exception.identifier,'ws:warningsOccurred') ;
    isWarning = (~isempty(indicesOfWarningPhrase) && indicesOfWarningPhrase(1)==1) ;
    if isWarning ,
        dialogContentString = exception.message ;
        dialogTitleString = ws.fif(length(exception.cause)<=1, 'Warning', 'Warnings') ;
    else
        if isempty(exception.cause)
            dialogContentString = exception.message ;
            dialogTitleString = 'Error' ;
        else
            primaryCause = exception.cause{1} ;
            if isempty(primaryCause.cause) ,
                dialogContentString = sprintf('%s:\n%s',exception.message,primaryCause.message) ;
                dialogTitleString = 'Error' ;
            else
                secondaryCause = primaryCause.cause{1} ;
                dialogContentString = sprintf('%s:\n%s\n%s', exception.message, primaryCause.message, secondaryCause.message) ;
                dialogTitleString = 'Error' ;
            end
        end            
    end
    ws.errordlg(dialogContentString, dialogTitleString, 'modal') ;                
end  % method
