function res = test(varargin)
    %testWavesurfer  Run wavesurfer automated tests.
    %
    %   testWavesurfer() runs all wavesurfer automated tests.
    %
    %   testWavesurfer('nohow') runs only those test that do not require
    %   any hardware connection.
    %
    %   res = testWavesurfer() returns test results in the result
    %   structure, res, rather than displaying the results at the command
    %   line.

    % By default include the tests that don't require hardware.
    suite = matlab.unittest.TestSuite.fromPackage('ws.test.nohw');

    % Add the hardware tests if appropriate based on the input arguments.
    if nargin == 0 || ~strcmpi(varargin{1}, 'nohw')
        ts = matlab.unittest.TestSuite.fromPackage('ws.test.hw');
        if ~isempty(ts)
            suite = [ts, suite];
        end
    end

    % unittest execution manager.
    res = suite.run();
end
