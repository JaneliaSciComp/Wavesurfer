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
            x = int16( 0.9*2^14*sin(bsxfun(@plus, 2*pi*10*t, 2*pi*iChannel)) ) ;
            channelScale = 1./[1 2 3 4 5 6] ;  % V/whatevers, scale for converting from V to whatever or vice-versa
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
            channelScale = zeros(1,0) ;  % V/whatevers, scale for converting from V to whatever or vice-versa
            adcCoefficients = repmat([1 2 3 4]',[1 nChannels]) ;
            %tic() ;
            y = ws.scaledDoubleAnalogDataFromRaw(x, channelScale, adcCoefficients) ;
            %timeForMFile = toc() 
            %tic() ;
            yMex = ws.scaledDoubleAnalogDataFromRawMex(x, channelScale, adcCoefficients) ;
            %timeForMexFile = toc() 
            %fprintf('mex file version of scaledDoubleAnalogDataFromRaw is %gx faster\n',timeForMFile/timeForMexFile) ;
            self.verifyEqual(y, yMex) ;
        end
        
        function testArbitraryOnMatrixZeroCoeffs(self)
            fs = 20000 ;  % Hz
            dt = 1/fs ;  % s
            T = 0.2 ;  % s
            nScans = round(T/dt) ;
            nChannels = 6 ;
            iChannel = (0:(nChannels-1)) ;
            t = dt*(0:(nScans-1))' ;
            x = int16( 0.9*2^14*sin(bsxfun(@plus, 2*pi*10*t, 2*pi*iChannel)) ) ;
            channelScale = 1./[1 2 3 4 5 6] ;  % V/whatevers, scale for converting from V to whatever or vice-versa
            adcCoefficients = zeros(0,nChannels) ;
            y = ws.scaledDoubleAnalogDataFromRaw(x, channelScale, adcCoefficients) ;
            yMex = ws.scaledDoubleAnalogDataFromRawMex(x, channelScale, adcCoefficients) ;
            self.verifyEqual(y, yMex) ;
        end
        
        function testArbitraryOnMatrixOneCoeff(self)
            fs = 20000 ;  % Hz
            dt = 1/fs ;  % s
            T = 0.2 ;  % s
            nScans = round(T/dt) ;
            nChannels = 6 ;
            iChannel = (0:(nChannels-1)) ;
            t = dt*(0:(nScans-1))' ;
            x = int16( 0.9*2^14*sin(bsxfun(@plus, 2*pi*10*t, 2*pi*iChannel)) ) ;
            channelScale = 1./[1 2 3 4 5 6] ;  % V/whatevers, scale for converting from V to whatever or vice-versa
            adcCoefficients = repmat(0.001,[1 nChannels]) ;
            y = ws.scaledDoubleAnalogDataFromRaw(x, channelScale, adcCoefficients) ;
            yMex = ws.scaledDoubleAnalogDataFromRawMex(x, channelScale, adcCoefficients) ;
            self.verifyEqual(y, yMex) ;
        end
        
        function testArbitraryOnMatrixTwoCoeffs(self)
            fs = 20000 ;  % Hz
            dt = 1/fs ;  % s
            T = 0.2 ;  % s
            nScans = round(T/dt) ;
            nChannels = 6 ;
            iChannel = (0:(nChannels-1)) ;
            t = dt*(0:(nScans-1))' ;
            x = int16( 0.9*2^14*sin(bsxfun(@plus, 2*pi*10*t, 2*pi*iChannel)) ) ;
            channelScale = 1./[1 2 3 4 5 6] ;  % V/whatevers, scale for converting from V to whatever or vice-versa
            adcCoefficients = [0.001 0.002 -0.001 -0.002 -0.003 +0.1 ; ...
                               1.234 0.967 0.3    100    0.5    -9.8 ] ;   
            y = ws.scaledDoubleAnalogDataFromRaw(x, channelScale, adcCoefficients) ;
            yMex = ws.scaledDoubleAnalogDataFromRawMex(x, channelScale, adcCoefficients) ;
            absoluteError = abs(y-yMex) ;
            relativeError = abs(y-yMex)./abs(y) ;
            self.verifyTrue( all( (relativeError(:)<1e-6) | absoluteError(:)<1e-6 ) ) ;
        end
        
        function testArbitraryOnMatrixThreeCoeffs(self)
            fs = 20000 ;  % Hz
            dt = 1/fs ;  % s
            T = 0.2 ;  % s
            nScans = round(T/dt) ;
            nChannels = 6 ;
            iChannel = (0:(nChannels-1)) ;
            t = dt*(0:(nScans-1))' ;
            x = int16( 0.9*2^14*sin(bsxfun(@plus, 2*pi*10*t, 2*pi*iChannel)) ) ;
            channelScale = 1./[1 2 3 4 5 6] ;  % V/whatevers, scale for converting from V to whatever or vice-versa
            adcCoefficients = [0.001  0.002  -0.001  -0.002  -0.003 +0.1 ; ...
                               1.234  0.967   0.3    +100     0.5    -9.8 ; ...
                               3e-10  2e-12  -2e-11   4e-8   -5e-15  1.3  ] ;   
            y = ws.scaledDoubleAnalogDataFromRaw(x, channelScale, adcCoefficients) ;
            yMex = ws.scaledDoubleAnalogDataFromRawMex(x, channelScale, adcCoefficients) ;
            absoluteError = abs(y-yMex) ;
            relativeError = abs(y-yMex)./abs(y) ;
            self.verifyTrue( all( (relativeError(:)<1e-6) | absoluteError(:)<1e-6 ) ) ;
        end
        
        function testArbitraryOnMatrixFourCoeffs(self)
            fs = 20000 ;  % Hz
            dt = 1/fs ;  % s
            T = 0.2 ;  % s
            nScans = round(T/dt) ;
            nChannels = 6 ;
            iChannel = (0:(nChannels-1)) ;
            t = dt*(0:(nScans-1))' ;
            x = int16( 0.9*2^14*sin(bsxfun(@plus, 2*pi*10*t, 2*pi*iChannel)) ) ;
            channelScale = 1./[1 2 3 4 5 6] ;  % V/whatevers, scale for converting from V to whatever or vice-versa
            adcCoefficients = [0.001  0.002  -0.001  -0.002  -0.003 +0.1 ; ...
                               1.234  0.967   0.3    +100     0.5    -9.8 ; ...
                               3e-10  2e-12  -2e-11   4e-8   -5e-15  1.3  ; ...
                               3.1e-11 2.4e-5  -5e-11   +2e-7  +3e-15  4e-20  ] ;   
            y = ws.scaledDoubleAnalogDataFromRaw(x, channelScale, adcCoefficients) ;
            yMex = ws.scaledDoubleAnalogDataFromRawMex(x, channelScale, adcCoefficients) ;
            absoluteError = abs(y-yMex) ;
            relativeError = abs(y-yMex)./abs(y) ;
            self.verifyTrue( all( (relativeError(:)<1e-6) | absoluteError(:)<1e-6 ) ) ;
        end
        
        function testArbitraryOnMatrixFiveCoeffs(self)
            fs = 20000 ;  % Hz
            dt = 1/fs ;  % s
            T = 0.2 ;  % s
            nScans = round(T/dt) ;
            nChannels = 6 ;
            iChannel = (0:(nChannels-1)) ;
            t = dt*(0:(nScans-1))' ;
            x = int16( 0.9*2^14*sin(bsxfun(@plus, 2*pi*10*t, 2*pi*iChannel)) ) ;
            channelScale = 1./[1 2 3 4 5 6] ;  % V/whatevers, scale for converting from V to whatever or vice-versa
            adcCoefficients = [0.001  0.002  -0.001  -0.002  -0.003 +0.1 ; ...
                               1.234  0.967   0.3    +100     0.5    -9.8 ; ...
                               3e-10  2e-12  -2e-11   4e-8   -5e-15  1.3  ; ...
                               3.1e-11 2.4e-5  -5e-11   +2e-7  +3e-15  4e-20  ; ...
                               3e-10  2e-12  -2e-11   4e-8   -5e-15  1.3 ] ;   
            y = ws.scaledDoubleAnalogDataFromRaw(x, channelScale, adcCoefficients) ;
            yMex = ws.scaledDoubleAnalogDataFromRawMex(x, channelScale, adcCoefficients) ;
            absoluteError = abs(y-yMex) ;
            relativeError = abs(y-yMex)./abs(y) ;
            self.verifyTrue( all( (relativeError(:)<1e-6) | absoluteError(:)<1e-6 ) ) ;
        end
    end  % test methods

 end  % classdef
