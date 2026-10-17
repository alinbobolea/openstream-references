classdef CpuModelNameTest < matlab.unittest.TestCase
    %CPUMODELNAMETEST Unit tests for cpuModelName.
    %
    % Each line form that must match has a nearby form that must not.

    methods (TestClassSetup)

        function addPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            here = fileparts(mfilename('fullpath'));
            testCase.applyFixture(PathFixture(fullfile(here, '..', 'matlab')));
        end

    end

    methods (Test)

        function testFirstModelNameOfTwoProcessors(testCase)
            nl = newline;
            tab = char(9);
            text = ['processor' tab ': 0' nl ...
                'vendor_id' tab ': AuthenticAMD' nl ...
                'model' tab tab ': 1' nl ...
                'model name' tab ': AMD EPYC 7763 64-Core Processor  ' nl ...
                nl ...
                'processor' tab ': 1' nl ...
                'model name' tab ': Other CPU' nl];
            testCase.verifyEqual(cpuModelName(text), ...
                'AMD EPYC 7763 64-Core Processor');
        end

        function testNoModelNameLine(testCase)
            text = ['processor' char(9) ': 0' newline 'model' char(9) ': 1' newline];
            testCase.verifyEqual(cpuModelName(text), '');
        end

        function testCrlfLineEnds(testCase)
            crlf = [char(13) newline];
            text = ['processor' char(9) ': 0' crlf ...
                'model name' char(9) ': Some CPU' crlf 'flags' char(9) ': x' crlf];
            testCase.verifyEqual(cpuModelName(text), 'Some CPU');
        end

        function testSpacingBeforeColon(testCase)
            testCase.verifyEqual(cpuModelName(['model name: A' newline]), 'A');
            testCase.verifyEqual(cpuModelName(['model name   : B' newline]), 'B');
            testCase.verifyEqual(cpuModelName('model name:C'), 'C');
        end

        function testLineMustStartWithModelName(testCase)
            testCase.verifyEqual(cpuModelName([' model name: x' newline]), '');
            text = ['flags' char(9) ': model name : y' newline ...
                'note: the model name : z' newline];
            testCase.verifyEqual(cpuModelName(text), '');
            % The first line that does start with it is still found.
            testCase.verifyEqual(cpuModelName([text 'model name : w' newline]), 'w');
        end

        function testEmptyValue(testCase)
            testCase.verifyEqual(cpuModelName(['model name' char(9) ':' newline]), '');
            testCase.verifyEqual(cpuModelName(['model name' char(9) ':   ' newline]), '');
        end

        function testStringArgument(testCase)
            out = cpuModelName("model name" + char(9) + ": S CPU" + newline);
            testCase.verifyEqual(out, 'S CPU');
            testCase.verifyClass(out, 'char');
        end

    end

end
