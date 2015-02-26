classdef SIUnitTestCase < matlab.unittest.TestCase
    
    methods (Test)
        function testPrefixStemMatrix(self)
            import ws.utility.*
            stems={'kg' 'm' 's' 'C' 'K' 'mol' 'cd' 'A' 'V' 'N' 'Hz' 'Ohm' 'S' 'W' 'Pa' 'J'}';
            prefixes={'y' 'z' 'a' 'f' 'p' 'n' 'u' 'm' 'c' 'd' '' 'da' 'h' 'k' 'M' 'G' 'T' 'P' 'E' 'Z' 'Y'}';
            for i=1:length(stems) ,
                for j=1:length(prefixes) ,
                    thisUnitString=[prefixes{j} stems{i}];
                    thisUnitStringCheck=string(SIUnit(thisUnitString));
                    self.verifyEqual(thisUnitStringCheck, ...
                                     thisUnitString, ...
                                     sprintf('string(SIUnit(''%s'')) => ''%s'', should be ''%s''', ...
                                             thisUnitString, ...
                                             thisUnitStringCheck, ...
                                             thisUnitString));
                end
            end
        end  % method
        
        function testGOhm(self)
            expression='SIUnit(''mV'')./SIUnit(''pA'')';
            expected='GOhm';
            self.testSIUnitExpression(expression,expected);
        end  % method
        
        function testMOhm(self)
            expression='SIUnit(''mV'')./SIUnit(''nA'')';
            expected='MOhm';
            self.testSIUnitExpression(expression,expected);
        end  % method
        
        function testNS(self)
            expression='SIUnit(''pA'')./SIUnit(''mV'')';
            expected='nS';
            self.testSIUnitExpression(expression,expected);
        end  % method

        function testUS(self)
            expression='SIUnit(''nA'')./SIUnit(''mV'')';
            expected='uS';
            self.testSIUnitExpression(expression,expected);
        end  % method

        function testHz(self)
            expression='invert(SIUnit(''s''))';
            expected='Hz';
            self.testSIUnitExpression(expression,expected);
        end  % method

        function testJ(self)
            expression='SIUnit(''kg'').*(SIUnit(''m'')./SIUnit(''s'')).*(SIUnit(''m'')./SIUnit(''s''))';
            expected='J';
            self.testSIUnitExpression(expression,expected);
        end  % method

        function testPure(self)
            expression='SIUnit(0,[0 0 0 0 0 0 0])';
            expected='';
            self.testSIUnitExpression(expression,expected);
        end  % method

        function testPercent(self)
            expression='SIUnit(-2,[0 0 0 0 0 0 0])';
            expected='*10^-2';
            self.testSIUnitExpression(expression,expected);
        end  % method

        function testNonidiomaticStem(self)
            expression='SIUnit(''kg'').*SIUnit(''m'').*(SIUnit(''m'')./SIUnit(''s'')).*10.^-3';
            expected='10^-3*kg*m^2*s^-1';
            self.testSIUnitExpression(expression,expected);
        end  % method

        function testPower(self)
            expression='SIUnit(''W'').^2./SIUnit(''Hz'')';
            expected='kg^2*m^4*s^-5';
            self.testSIUnitExpression(expression,expected);
        end  % method

        function testFractionalPower(self)
            expression='SIUnit(''W'')./SIUnit(''Hz'').^0.5';
            expected='kg*m^2*s^-2.5';
            self.testSIUnitExpression(expression,expected);
        end  % method

        function testVC(self)
            expression='SIUnit(''V'').*SIUnit(''C'')';
            expected='J';
            self.testSIUnitExpression(expression,expected);
        end  % method

        function testN(self)
            expression='SIUnit(''kg'').*SIUnit(''m'')./SIUnit(''s'').^2';
            expected='N';
            self.testSIUnitExpression(expression,expected);
        end  % method
    end  % methods (Test)

    methods
        function testSIUnitExpression(self,expression,expected)
            % general method for verifying whether a SIUnit expression evals to 
            % what we think it should.  expression should be a string that
            % evals to an SIUnit.  expected should be a string.
            import ws.utility.*
            actual=eval(sprintf('string(%s)',expression));
            self.verifyEqual(actual, ...
                             expected, ...
                             sprintf('%s => ''%s'', should be ''%s''', ...
                                     expression, actual, expected));
        end
    end
    

end
