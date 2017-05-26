function process = launchSIMockInOtherProcessAndSendMessagesBack()
    % Returns a dotnet System.Diagnostics.Process object
    pathToWavesurferRoot = ws.WavesurferModel.pathNamesThatNeedToBeOnSearchPath() ;
    process = System.Diagnostics.Process() ;
    process.StartInfo.FileName = 'matlab.exe' ;
    argumentsString = sprintf('-nojvm -nosplash -r "addpath(''%s''); sim = ws.SIMock(); sim.sendLotsOfMessages(); pause(10); quit();', pathToWavesurferRoot) ;
    process.StartInfo.Arguments = argumentsString ;
    %process.StartInfo.WindowStyle = ProcessWindowStyle.Maximized;
    process.Start();
end
