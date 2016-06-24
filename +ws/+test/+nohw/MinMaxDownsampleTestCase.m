classdef MinMaxDownsampleTestCase < matlab.unittest.TestCase
    methods (Test)
        
        function testVector(self)
            fs = 20000 ;  % Hz
            dt = 1/fs ;  % s
            T = 0.2 ;  % s
            nScans = round(T/dt) ;
            t = dt*(0:(nScans-1))' ;
            y = sin(2*pi*10*t) ;
            r = 87 ;  % Why not?
            [tSubDub,ySubDub] = ws.minMaxDownsample(t,y,r) ;
            [tSubDubMex,ySubDubMex] = ws.minMaxDownsampleMex(t,y,r) ;
            self.verifyEqual(tSubDub,tSubDubMex) ;            
            self.verifyEqual(ySubDub,ySubDubMex) ;
        end
        
        function testRandomArray(self)
            fs = 20000 ;  % Hz
            dt = 1/fs ;  % s
            T = 0.2 ;  % s
            nScans = round(T/dt) ;
            t = dt*(0:(nScans-1))' ;
            nChannels = 8 ;
            channelIndex = (0:(nChannels-1)) ;
            y = sin(bsxfun(@plus,2*pi*10*t,2*pi*channelIndex/nChannels)) ;
            r = 87 ;  % Why not?
            [tSubDub,ySubDub] = ws.minMaxDownsample(t,y,r) ;
            [tSubDubMex,ySubDubMex] = ws.minMaxDownsampleMex(t,y,r) ;
            self.verifyEqual(tSubDub,tSubDubMex) ;            
            self.verifyEqual(ySubDub,ySubDubMex) ;
        end
        
        function testLargeRandomArray(self)
            fs = 20000 ;  % Hz
            dt = 1/fs ;  % s
            T = 300 ;  % s
            nScans = round(T/dt) ;
            t = dt*(0:(nScans-1))' ;
            nChannels = 8 ;
            channelIndex = (0:(nChannels-1)) ;
            y = sin(bsxfun(@plus,2*pi*10*t,2*pi*channelIndex/nChannels)) ;
            r = 20001 ;  % Why not?
            tic
            [tSubDub,ySubDub] = ws.minMaxDownsample(t,y,r) ;
            toc
            tic
            [tSubDubMex,ySubDubMex] = ws.minMaxDownsampleMex(t,y,r) ;
            toc
            self.verifyEqual(tSubDub,tSubDubMex) ;            
            self.verifyEqual(ySubDub,ySubDubMex) ;
        end
        
        function testRIsEmpty(self)
            fs = 20000 ;  % Hz
            dt = 1/fs ;  % s
            T = 0.2 ;  % s
            nScans = round(T/dt) ;
            t = dt*(0:(nScans-1))' ;
            nChannels = 8 ;
            channelIndex = (0:(nChannels-1)) ;
            y = sin(bsxfun(@plus,2*pi*10*t,2*pi*channelIndex/nChannels)) ;
            r = [] ;  % input should equal output
            [tSubDub,ySubDub] = ws.minMaxDownsample(t,y,r) ;
            [tSubDubMex,ySubDubMex] = ws.minMaxDownsampleMex(t,y,r) ;
            self.verifyEqual(tSubDub,tSubDubMex) ;            
            self.verifyEqual(ySubDub,ySubDubMex) ;
        end
        
        function testZeroChannels(self)
            fs = 20000 ;  % Hz
            dt = 1/fs ;  % s
            T = 0.2 ;  % s
            nScans = round(T/dt) ;
            t = dt*(0:(nScans-1))' ;
            nChannels = 0 ;
            channelIndex = (0:(nChannels-1)) ;
            y = sin(bsxfun(@plus,2*pi*10*t,2*pi*channelIndex/nChannels)) ;
            r = 87 ;  % input should equal output
            [tSubDub,ySubDub] = ws.minMaxDownsample(t,y,r) ;
            [tSubDubMex,ySubDubMex] = ws.minMaxDownsampleMex(t,y,r) ;
            self.verifyEqual(tSubDub,tSubDubMex) ;            
            self.verifyEqual(ySubDub,ySubDubMex) ;
        end
        
        function testZeroScans(self)
            fs = 20000 ;  % Hz
            dt = 1/fs ;  % s
            T = 0 ;  % s
            nScans = round(T/dt) ;
            t = dt*(0:(nScans-1))' ;
            nChannels = 8 ;
            channelIndex = (0:(nChannels-1)) ;
            y = sin(bsxfun(@plus,2*pi*10*t,2*pi*channelIndex/nChannels)) ;
            r = 87 ;  % input should equal output
            [tSubDub,ySubDub] = ws.minMaxDownsample(t,y,r) ;
            [tSubDubMex,ySubDubMex] = ws.minMaxDownsampleMex(t,y,r) ;
            self.verifyEqual(tSubDub,tSubDubMex) ;            
            self.verifyEqual(ySubDub,ySubDubMex) ;
        end
        
        function testZeroChannelsZeroScans(self)
            fs = 20000 ;  % Hz
            dt = 1/fs ;  % s
            T = 0 ;  % s
            nScans = round(T/dt) ;
            t = dt*(0:(nScans-1))' ;
            nChannels = 0 ;
            channelIndex = (0:(nChannels-1)) ;
            y = sin(bsxfun(@plus,2*pi*10*t,2*pi*channelIndex/nChannels)) ;
            r = 87 ;  % input should equal output
            [tSubDub,ySubDub] = ws.minMaxDownsample(t,y,r) ;
            [tSubDubMex,ySubDubMex] = ws.minMaxDownsampleMex(t,y,r) ;
            self.verifyEqual(tSubDub,tSubDubMex) ;            
            self.verifyEqual(ySubDub,ySubDubMex) ;
        end
        
        function testZeroChannelsZeroScansAndRIsEmpty(self)
            fs = 20000 ;  % Hz
            dt = 1/fs ;  % s
            T = 0 ;  % s
            nScans = round(T/dt) ;
            t = dt*(0:(nScans-1))' ;
            nChannels = 0 ;
            channelIndex = (0:(nChannels-1)) ;
            y = sin(bsxfun(@plus,2*pi*10*t,2*pi*channelIndex/nChannels)) ;
            r = [] ;  % input should equal output
            [tSubDub,ySubDub] = ws.minMaxDownsample(t,y,r) ;
            [tSubDubMex,ySubDubMex] = ws.minMaxDownsampleMex(t,y,r) ;
            self.verifyEqual(tSubDub,tSubDubMex) ;            
            self.verifyEqual(ySubDub,ySubDubMex) ;
        end
        
    end  % test methods

 end  % classdef
