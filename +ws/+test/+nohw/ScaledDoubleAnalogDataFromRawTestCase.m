classdef ScaledDoubleAnalogDataFromRawTestCase < matlab.unittest.TestCase
    methods (Test)
        
        function testIdentityFunctionOnVector(self)
            fs = 20000 ;  % Hz
            dt = 1/fs ;  % s
            T = 0.2 ;  % s
            nScans = round(T/dt) ;
            t = dt*(0:(nScans-1))' ;
            x = int16(0.9*2^14*sin(2*pi*10*t)) ;
            channelScale = 1 ;  % V/whatevers, scale for converting from V to whatever or vice-versa
            adcCoefficients = [0 1 0 0]' ;  % identity function
            yTheoretical = double(x) ;
            y = ws.scaledDoubleAnalogDataFromRaw(x, channelScale, adcCoefficients) ;
            yMex = ws.scaledDoubleAnalogDataFromRawMex(x, channelScale, adcCoefficients) ;
            self.verifyEqual(yTheoretical, y) ;            
            self.verifyEqual(y, yMex) ;
        end
        
        function testArbitraryOnVector(self)
            fs = 20000 ;  % Hz
            dt = 1/fs ;  % s
            T = 0.2 ;  % s
            nScans = round(T/dt) ;
            t = dt*(0:(nScans-1))' ;
            x = int16(0.9*2^14*sin(2*pi*10*t)) ;
            channelScale = 1 ;  % V/whatevers, scale for converting from V to whatever or vice-versa
            adcCoefficients = [1 2 3 4]' ;
            y = ws.scaledDoubleAnalogDataFromRaw(x, channelScale, adcCoefficients) ;
            yMex = ws.scaledDoubleAnalogDataFromRawMex(x, channelScale, adcCoefficients) ;
            self.verifyEqual(y, yMex) ;
        end

        function testArbitraryOnEmpty(self)
            fs = 20000 ;  % Hz
            dt = 1/fs ;  % s
            T = 0 ;  % s
            nScans = round(T/dt) ;
            t = dt*(0:(nScans-1))' ;
            x = int16(0.9*2^14*sin(2*pi*10*t)) ;
            channelScale = 1 ;  % V/whatevers, scale for converting from V to whatever or vice-versa
            adcCoefficients = [1 2 3 4]' ;
            y = ws.scaledDoubleAnalogDataFromRaw(x, channelScale, adcCoefficients) ;
            yMex = ws.scaledDoubleAnalogDataFromRawMex(x, channelScale, adcCoefficients) ;
            self.verifyEqual(y, yMex) ;
        end
        
        function testArbitraryOnMatrix(self)
            fs = 20000 ;  % Hz
            dt = 1/fs ;  % s
            T = 0.2 ;  % s
            nScans = round(T/dt) ;
            nChannels = 6 ;
            iChannel = (0:(nChannels-1)) ;
            t = dt*(0:(nScans-1))' ;
            x = int16(0.9*2^14*sin(bsxfun(@plus,2*pi*10*t,2*pi*iChannel))) ;
            channelScale = [1 2 3 4 5 6] ;  % V/whatevers, scale for converting from V to whatever or vice-versa
            adcCoefficients = repmat([1 2 3 4]',[1 nChannels]) ;
            y = ws.scaledDoubleAnalogDataFromRaw(x, channelScale, adcCoefficients) ;
            yMex = ws.scaledDoubleAnalogDataFromRawMex(x, channelScale, adcCoefficients) ;
            self.verifyEqual(y, yMex) ;
        end
        
        function testArbitraryOnZeroChannels(self)
            fs = 20000 ;  % Hz
            dt = 1/fs ;  % s
            T = 0.2 ;  % s
            nScans = round(T/dt) ;
            nChannels = 0 ;
            iChannel = (0:(nChannels-1)) ;
            t = dt*(0:(nScans-1))' ;
            x = int16(0.9*2^14*sin(bsxfun(@plus,2*pi*10*t,2*pi*iChannel))) ;
            channelScale = [1 2 3 4 5 6] ;  % V/whatevers, scale for converting from V to whatever or vice-versa
            adcCoefficients = repmat([1 2 3 4]',[1 nChannels]) ;
            tic() ;
            y = ws.scaledDoubleAnalogDataFromRaw(x, channelScale, adcCoefficients) ;
            timeForMFile = toc() 
            tic() ;
            yMex = ws.scaledDoubleAnalogDataFromRawMex(x, channelScale, adcCoefficients) ;
            timeForMexFile = toc() 
            fprintf('mex file version of scaledDoubleAnalogDataFromRaw is %gx faster\n',timeForMFile/timeForMexFile) ;
            self.verifyEqual(y, yMex) ;
        end
        
    end  % test methods

 end  % classdef
