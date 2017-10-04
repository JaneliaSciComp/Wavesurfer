import unittest
import os
import math
import numpy
import ws

class LoadDataFileTestCase(unittest.TestCase) :
    def testLoadingFile(self) :
        thisFilePath = os.path.realpath(__file__)
        thisDirName = os.path.dirname(thisFilePath)
        fileName = os.path.join(thisDirName, 'test2.h5') 
        d = ws.loadDataFile(fileName)   # conversion to scaled data would fail for these files
        acqSamplingRate = float(d['header']['AcquisitionSampleRate'])
        self.assertEqual(acqSamplingRate, 20e3)                 
        nAIChannels = int(d['header']['NAIChannels'])
        self.assertEqual(nAIChannels, 3)         
        nActiveAIChannels = int(d['header']['IsAIChannelActive'].sum())
        self.assertEqual(nActiveAIChannels, 2) 
        stimSamplingRate = d['header']['StimulationSampleRate'] 
        self.assertEqual(stimSamplingRate, 20e3)                 
        x = d['sweep_0001']['analogScans']
        self.assertTrue(numpy.absolute(numpy.max(x[0])-5)<0.01)
        self.assertTrue(numpy.absolute(numpy.min(x[0])-0)<0.01)
    
    def testLoadingOlderFileWithFunnySamplingRate(self) :
        thisFilePath = os.path.realpath(__file__)
        thisDirName = os.path.dirname(thisFilePath)
        fileName = os.path.join(thisDirName, '30_kHz_sampling_rate_0p912_0001.h5') 
        dataFileAsStruct = ws.loadDataFile(fileName, 'raw')   # conversion to scaled data would fail for these files
        # The nominal sampling rate was 30000, but the returned
        # sampling rate should be ~30003 Hz, to make (100 Mhz)/fs an
        # integer.
        returnedAcqSamplingRate = dataFileAsStruct['header']['Acquisition']['SampleRate'] 
        nTimebaseTicksPerAcqSample = 100e6/returnedAcqSamplingRate   # should be exactly 3333
        self.assertEqual(nTimebaseTicksPerAcqSample, 3333) 
        returnedStimSamplingRate = dataFileAsStruct['header']['Stimulation']['SampleRate'] 
        nTimebaseTicksPerStimSample = 100e6/returnedStimSamplingRate   # should be exactly 3333
        self.assertEqual(nTimebaseTicksPerStimSample, 3333) 
    
    def testLoadingNewerFileWithFunnySamplingRate(self) :
        thisFilePath = os.path.realpath(__file__)
        thisDirName = os.path.dirname(thisFilePath)
        fileName = os.path.join(thisDirName, '30_kHz_sampling_rate_0p913_0001.h5') 
        dataFileAsStruct = ws.loadDataFile(fileName, 'raw') 
        # The requested sampling rate was 30000, but this version of WS
        # coerces that in the UI to an acheivable rate, which should be
        # ~30003 Hz, to make (100 Mhz)/fs an integer.
        returnedAcqSamplingRate = dataFileAsStruct['header']['Acquisition']['SampleRate'] 
        nTimebaseTicksPerAcqSample = 100e6/returnedAcqSamplingRate   # should be exactly 3333
        self.assertEqual(nTimebaseTicksPerAcqSample,3333) 
        returnedStimSamplingRate = dataFileAsStruct['header']['Stimulation']['SampleRate'] 
        nTimebaseTicksPerStimSample = 100e6/returnedStimSamplingRate   # should be exactly 3333
        self.assertEqual(nTimebaseTicksPerStimSample,3333) 
    
    def testLoadingOlderFileWithFunnierSamplingRate(self) :
        thisFilePath = os.path.realpath(__file__)
        thisDirName = os.path.dirname(thisFilePath)
        fileName = os.path.join(thisDirName, '29997_Hz_sampling_rate_0p912_0001.h5') 
        dataFileAsStruct = ws.loadDataFile(fileName, 'raw') 
        # The nominal sampling rate was 29997, but the returned
        # sampling rate should be 100e6/3333 for acq, and 100e6/3334
        # for stim.
        returnedAcqSamplingRate = dataFileAsStruct['header']['Acquisition']['SampleRate'] 
        nTimebaseTicksPerAcqSample = 100e6/returnedAcqSamplingRate   # should be exactly 3333
        self.assertEqual(nTimebaseTicksPerAcqSample,3333) 
        returnedStimSamplingRate = dataFileAsStruct['header']['Stimulation']['SampleRate'] 
        nTimebaseTicksPerStimSample = 100e6/returnedStimSamplingRate   # should be exactly 3333
        self.assertEqual(nTimebaseTicksPerStimSample,3334) 
    
    def testLoadingNewerFileWithFunnierSamplingRate(self) :
        thisFilePath = os.path.realpath(__file__)
        thisDirName = os.path.dirname(thisFilePath)
        fileName = os.path.join(thisDirName, '29997_Hz_sampling_rate_0p913_0001.h5') 
        dataFileAsStruct = ws.loadDataFile(fileName, 'raw') 
        # The nominal sampling rate was 29997, but the returned
        # sampling rate should be 100e6/3333 for both acq and stim.
        returnedAcqSamplingRate = dataFileAsStruct['header']['Acquisition']['SampleRate'] 
        nTimebaseTicksPerAcqSample = 100e6/returnedAcqSamplingRate   # should be exactly 3333
        self.assertEqual(nTimebaseTicksPerAcqSample,3333) 
        returnedStimSamplingRate = dataFileAsStruct['header']['Stimulation']['SampleRate'] 
        nTimebaseTicksPerStimSample = 100e6/returnedStimSamplingRate   # should be exactly 3333
        self.assertEqual(nTimebaseTicksPerStimSample,3333) 

    def testIdentityFunctionOnVector(self) :
        fs = 20000.0   # Hz
        dt = 1/fs   # s
        T = 0.2   # s
        nScans = round(T/dt) 
        t = dt*numpy.arange(nScans) 
        x = (0.9 * pow(2,14) * numpy.sin(2*math.pi*10*t)).astype('int16').reshape(1, nScans)
        channelScale = (numpy.array(1, ndmin=1)).astype('float64')   # V/whatevers, scale for converting from V to whatever or vice-versa
        adcCoefficients = (numpy.array([0, 1, 0, 0])).astype('float64').reshape(1, 4)   # identity function
        yTheoretical = x.astype('float64')
        y = ws.scaledDoubleAnalogDataFromRaw(x, channelScale, adcCoefficients) 
        #yMex = ws.scaledDoubleAnalogDataFromRawMex(x, channelScale, adcCoefficients) 
        self.assertTrue((yTheoretical==y).all())             
        #self.assertEqual(y, yMex) 
    
    def testArbitraryOnVector(self) :
        fs = 20000.0   # Hz
        dt = 1/fs   # s
        T = 0.2   # s
        nScans = round(T/dt) 
        t = dt*numpy.arange(nScans) 
        x = (0.9 * pow(2,14) * numpy.sin(2*math.pi*10*t)).astype('int16').reshape(1, nScans)
        channelScale = (numpy.array(1, ndmin=1)).astype('float64')   # V/whatevers, scale for converting from V to whatever or vice-versa
        adcCoefficients = (numpy.array([1, 2, 3, 4])).astype('float64').reshape(1, 4)   # identity function
        xf = x.astype('float64')
        yTheoretical = (1.0 + 2.0*xf + 3.0*xf*xf +4.0*xf*xf*xf)
        y = ws.scaledDoubleAnalogDataFromRaw(x, channelScale, adcCoefficients) 
        #yMex = ws.scaledDoubleAnalogDataFromRawMex(x, channelScale, adcCoefficients) 
        self.assertTrue((yTheoretical==y).all())             
        #self.assertEqual(y, yMex) 

    def testArbitraryOnEmpty(self) :
        fs = 20000.0   # Hz
        dt = 1/fs   # s
        T = 0.0   # s
        nScans = round(T/dt) 
        t = dt*numpy.arange(nScans) 
        x = (0.9 * pow(2,14) * numpy.sin(2*math.pi*10*t)).astype('int16').reshape(1, nScans)
        channelScale = (numpy.array(1, ndmin=1)).astype('float64')   # V/whatevers, scale for converting from V to whatever or vice-versa
        adcCoefficients = (numpy.array([1, 2, 3, 4])).astype('float64').reshape(1, 4)   # identity function
        xf = x.astype('float64')
        yTheoretical = 1.0 + 2.0*xf + 3.0*xf*xf +4.0*xf*xf*xf
        y = ws.scaledDoubleAnalogDataFromRaw(x, channelScale, adcCoefficients) 
        self.assertTrue((yTheoretical==y).all())             

    def testArbitraryOnMatrix(self) :
        fs = 20000.0   # Hz
        dt = 1/fs   # s
        T = 0.2   # s
        nScans = round(T/dt) 
        nChannels = 6
        iChannel = numpy.arange(nChannels).reshape(nChannels, 1)
        t = (dt*numpy.arange(nScans)).reshape(1, nScans)
        x = (0.9 * pow(2,14) * numpy.sin(2*math.pi*10*t + 2*math.pi*(iChannel/nChannels))).astype('int16')
        channelScale = 1 / (iChannel+1) 
        adcCoefficients = numpy.tile((numpy.array([1, 2, 3, 4])).astype('float64').reshape(1, 4), (nChannels,1))   # identity function
        xf = x.astype('float64')
        yTheoretical = (1.0 + 2.0*xf + 3.0*xf*xf +4.0*xf*xf*xf) / channelScale
        y = ws.scaledDoubleAnalogDataFromRaw(x, channelScale, adcCoefficients) 
        self.assertTrue((yTheoretical==y).all())             
        #absoluteError = numpy.absolute(y-yTheoretical) 
        #relativeError = numpy.absolute(y-yTheoretical)/numpy.absolute(yTheoretical) 
        #self.assertTrue( (numpy.logical_or(relativeError<1e-6 , absoluteError<1e-6 ) ).all() ) 

    def testArbitraryOnZeroChannels(self) :
        fs = 20000.0   # Hz
        dt = 1/fs   # s
        T = 0.2   # s
        nScans = round(T/dt) 
        nChannels = 0
        iChannel = numpy.arange(nChannels).reshape(nChannels, 1)
        t = (dt*numpy.arange(nScans)).reshape(1, nScans)
        x = (0.9 * pow(2,14) * numpy.sin(2*math.pi*10*t + 2*math.pi*(iChannel/nChannels))).astype('int16')
        channelScale = 1 / (iChannel+1) 
        adcCoefficients = numpy.tile((numpy.array([1, 2, 3, 4])).astype('float64').reshape(1, 4), (nChannels,1))   # identity function
        xf = x.astype('float64')
        yTheoretical = (1.0 + 2.0*xf + 3.0*xf*xf +4.0*xf*xf*xf) / channelScale
        y = ws.scaledDoubleAnalogDataFromRaw(x, channelScale, adcCoefficients) 
        self.assertTrue((yTheoretical==y).all())                 

    def testArbitraryOnMatrixZeroCoeffs(self) :
        fs = 20000.0   # Hz
        dt = 1/fs   # s
        T = 0.2   # s
        nScans = round(T/dt) 
        nChannels = 0
        iChannel = numpy.arange(nChannels).reshape(nChannels, 1)
        t = (dt*numpy.arange(nScans)).reshape(1, nScans)
        x = (0.9 * pow(2,14) * numpy.sin(2*math.pi*10*t + 2*math.pi*(iChannel/nChannels))).astype('int16')
        channelScale = 1 / (iChannel+1) 
        adcCoefficients = numpy.zeros((nChannels, 0))         
        yTheoretical = numpy.zeros(x.shape) 
        y = ws.scaledDoubleAnalogDataFromRaw(x, channelScale, adcCoefficients) 
        self.assertTrue((yTheoretical==y).all())                 
    
    def testArbitraryOnMatrixOneCoeff(self) :
        fs = 20000.0   # Hz
        dt = 1/fs   # s
        T = 0.2   # s
        nScans = round(T/dt) 
        nChannels = 6
        iChannel = numpy.arange(nChannels).reshape(nChannels, 1)
        t = (dt*numpy.arange(nScans)).reshape(1, nScans)
        x = (0.9 * pow(2,14) * numpy.sin(2*math.pi*10*t + 2*math.pi*(iChannel/nChannels))).astype('int16')
        channelScale = 1 / (iChannel+1) 
        #adcCoefficients = numpy.tile((numpy.array([1, 2, 3, 4])).astype('float64').reshape(1, 4), (nChannels,1))   # identity function
        adcCoefficients = numpy.tile(0.001, (nChannels, 1))
        #xf = x.astype('float64')
        yTheoretical = numpy.tile(0.001, (nChannels, nScans)) / channelScale
        y = ws.scaledDoubleAnalogDataFromRaw(x, channelScale, adcCoefficients) 
        self.assertTrue((yTheoretical==y).all())                 
    
    def testArbitraryOnMatrixTwoCoeffs(self) :
        fs = 20000.0   # Hz
        dt = 1/fs   # s
        T = 0.2   # s
        nScans = round(T/dt) 
        nChannels = 3
        iChannel = numpy.arange(nChannels).reshape(nChannels, 1)
        t = (dt*numpy.arange(nScans)).reshape(1, nScans)
        x = (0.9 * pow(2,14) * numpy.sin(2*math.pi*10*t + 2*math.pi*(iChannel/nChannels))).astype('int16')
        channelScale = 1 / (iChannel+1) 
        #adcCoefficients = numpy.tile((numpy.array([1, 2, 3, 4])).astype('float64').reshape(1, 4), (nChannels,1))   # identity function
        #adcCoefficients = numpy.tile(0.001, (nChannels, 1))
        adcCoefficients = numpy.array([ [0.0, 1.0], 
                                        [0.0, 1.0], 
                                        [0.0, 1.0] ]) ;
        yTheoretical = x / channelScale
        y = ws.scaledDoubleAnalogDataFromRaw(x, channelScale, adcCoefficients) 
        self.assertTrue((yTheoretical==y).all())                 

if __name__ == '__main__':
    unittest.main()
    
        