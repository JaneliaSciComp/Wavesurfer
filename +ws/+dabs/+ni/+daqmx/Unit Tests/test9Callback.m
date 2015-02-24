function test9Callback()

global callbackStruct9

disp('howdy');

if callbackStruct9.stopInCallback
    hTask = callbackStruct9.task;
    hTask.stop();
end
