function [CommandFilePath_, ResponseFilePath_] = commandFilePaths(IsParentWavesurferModel_, isServer)
    %CommunicationFolderName_ = fullfile(tempdir(),'si-ws-comm') ;
    CommunicationFolderName_ = tempdir() ;

    WSCommandFileName_  = 'ws_command.txt'  ;  % Commands *to* WS
    WSResponseFileName_ = 'ws_response.txt' ;  % Responses *from* WS

    SICommandFileName_  = 'si_command.txt'  ;  % Commands *to* SI
    SIResponseFileName_ = 'si_response.txt' ;  % Responses *from* SI    
    
    if IsParentWavesurferModel_ ,
        if isServer ,  
            CommandFilePath_ = fullfile(CommunicationFolderName_, WSCommandFileName_) ;
            ResponseFilePath_ = fullfile(CommunicationFolderName_, WSResponseFileName_) ;
        else
            CommandFilePath_ = fullfile(CommunicationFolderName_, SICommandFileName_) ;
            ResponseFilePath_ = fullfile(CommunicationFolderName_, SIResponseFileName_) ;
        end
    else
        if isServer ,
            CommandFilePath_ = fullfile(CommunicationFolderName_, SICommandFileName_) ;
            ResponseFilePath_ = fullfile(CommunicationFolderName_, SIResponseFileName_) ;
        else
            CommandFilePath_ = fullfile(CommunicationFolderName_, WSCommandFileName_) ;
            ResponseFilePath_ = fullfile(CommunicationFolderName_, WSResponseFileName_) ;
        end
    end
    
end
