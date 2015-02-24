classdef MostPreferencesTestCase < matlab.unittest.TestCase
    
    methods (Test)
        function testZeroArgConstructor(self)
            prefs=ws.most.fileutil.Preferences();
            self.verifyEmpty(prefs.Location, 'The ''Location'' property should be empty.');
            self.verifyEmpty(prefs.Name, 'The ''Name'' property should be empty.');
            prefs.purge();
        end  % method
        
        function testOneArgConstructor(self)
            name='GorgonzolaTheApp.mat';
            prefs=ws.most.fileutil.Preferences(name);
            self.verifyEqual(prefs.Name,name);
            prefs.purge();
        end  % method

        function testTwoArgConstructor(self)
            name='GorgonzolaTheApp.mat';
            location='Janelia';
            prefs=ws.most.fileutil.Preferences(location,name);
            self.verifyEqual(prefs.Location,location);
            self.verifyEqual(prefs.Name,name);
            prefs.purge();
        end  % method

        function testSaveThenLoad(self)
            name='GorgonzolaTheApp.mat';
            location='Janelia';
            prefs=ws.most.fileutil.Preferences(location,name);
            mouseSpeed=10;
            prefs.savePref('mouseSpeed',mouseSpeed);
            mouseSpeedCheck=prefs.loadPref('mouseSpeed');
            self.verifyEqual(mouseSpeed,mouseSpeedCheck);
            prefs.purge();
        end  % method

        function testRegisterDefaults(self)
            name='GorgonzolaTheApp.mat';
            location='Janelia';
            prefs=ws.most.fileutil.Preferences(location,name);
            mouseSpeed=10;
            prefs.savePref('mouseSpeed',mouseSpeed);
            keyboardRepeatRate=20;
            otherMouseSpeed=30;
            prefs.registerDefaults('keyboardRepeatRate',keyboardRepeatRate, ...
                                   'mouseSpeed',otherMouseSpeed);
            mouseSpeedCheck=prefs.loadPref('mouseSpeed');  % this should be the originally-set value
            self.verifyEqual(mouseSpeed,mouseSpeedCheck);
            keyboardRepeatRateCheck=prefs.loadPref('keyboardRepeatRate');
            self.verifyEqual(keyboardRepeatRate,keyboardRepeatRateCheck);
            prefs.purge();
        end  % method

        function testFileCreationAndPurge(self)
            name='GorgonzolaTheApp.mat';
            location='Janelia';
            prefs=ws.most.fileutil.Preferences(location,name);
            mouseSpeed=10;
            prefs.savePref('mouseSpeed',mouseSpeed);
            % there should now be a prefs file in the filesystem
            absoluteFileName=fullfile(prefdir(),prefs.Location,prefs.Name);
            self.verifyTrue(logical(exist(absoluteFileName,'file')) && ~logical(exist(absoluteFileName,'dir')));
            prefs.purge();
            % the file should now be deleted
            self.verifyFalse(logical(exist(absoluteFileName,'file')));
        end  % method

    end  % methods (Test)
end
