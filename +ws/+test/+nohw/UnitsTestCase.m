classdef UnitsTestCase < matlab.unittest.TestCase
    methods (Test)
        function theTest(self)
            [gainOrResistanceUnits,gainOrResistance] = ws.convertScalarDimensionalQuantityToEngineering('GOhm',0.01) ;            
            self.verifyEqual(gainOrResistanceUnits,'MOhm');
            self.verifyEqual(gainOrResistance,10);
        end  % function
    end  % test methods    
end
