classdef ProcessorModelNameTest < matlab.unittest.TestCase
    %PROCESSORMODELNAMETEST Unit tests for processorModelName.
    %
    % The file-reading function machineProcessorModel and the use of it by
    % environmentRecord are tested in WiringTest.
    %
    % The Windows case (no /proc/cpuinfo, the model named by the environment
    % variable PROCESSOR_IDENTIFIER) is tested on any system through the
    % arguments of the function, because it takes the text of the file (or a
    % missing string where the file does not exist) and the variable's value.

    methods (TestClassSetup)

        function addPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            here = fileparts(mfilename('fullpath'));
            testCase.applyFixture(PathFixture(fullfile(here, '..', 'matlab')));
        end

    end

    methods (Static)

        function text = cpuinfo(model)
            % The text of a /proc/cpuinfo with one processor named MODEL.
            tab = char(9);
            text = ['processor' tab ': 0' newline 'model name' tab ': ' model newline];
        end

    end

    methods (Test)

        function testLinuxUsesTheModelNameOfCpuinfo(testCase)
            testCase.verifyEqual(processorModelName( ...
                ProcessorModelNameTest.cpuinfo('AMD EPYC 7763 64-Core Processor'), ''), ...
                'AMD EPYC 7763 64-Core Processor');
        end

        function testLinuxIgnoresTheEnvironmentVariable(testCase)
            % Where the file exists nothing changes, whatever the variable says.
            text = ProcessorModelNameTest.cpuinfo('Some CPU');
            testCase.verifyEqual(processorModelName(text, ...
                'Intel64 Family 6 Model 85 Stepping 7, GenuineIntel'), 'Some CPU');
        end

        function testExistingFileWithoutModelNameDoesNotFallBack(testCase)
            % A file that exists but names no model (some other architectures)
            % gives '' as before; the variable is not consulted.
            text = ['processor' char(9) ': 0' newline];
            testCase.verifyEqual(processorModelName(text, 'Some Identifier'), '');
            testCase.verifyEqual(processorModelName('', 'Some Identifier'), '');
        end

        function testWithoutTheFileTheIdentifierIsUsed(testCase)
            identifier = 'Intel64 Family 6 Model 85 Stepping 7, GenuineIntel';
            testCase.verifyEqual(processorModelName(string(missing), identifier), ...
                identifier);
        end

        function testIdentifierIsTrimmed(testCase)
            testCase.verifyEqual(processorModelName(string(missing), ...
                ['  AMD64 Family 25 Model 1 ' newline]), 'AMD64 Family 25 Model 1');
        end

        function testWithoutTheFileAndWithoutTheVariable(testCase)
            testCase.verifyEqual(processorModelName(string(missing), ''), '');
            testCase.verifyEqual(processorModelName(string(missing), '   '), '');
            testCase.verifyEqual(processorModelName(string(missing), string.empty), '');
        end

        function testEveryKindOfEmptyIdentifierGivesEmptyChar(testCase)
            % Added after a CI run: char of an empty string array has more
            % than two dimensions, so no empty value may reach char.
            empties = {'', "", string.empty, [], {}, string(missing), '   ', " "};
            for k = 1:numel(empties)
                out = processorModelName(string(missing), empties{k});
                testCase.verifyEqual(out, '', sprintf('identifier %d', k));
                testCase.verifyClass(out, 'char');
            end
        end

        function testEmptyFileTextOfAnyKindGivesEmptyChar(testCase)
            % The same for the text of the file: it exists but names no model.
            for text = {'', "", string.empty, []}
                out = processorModelName(text{1}, 'Some Identifier');
                testCase.verifyEqual(out, '');
                testCase.verifyClass(out, 'char');
            end
        end

        function testResultIsChar(testCase)
            out = processorModelName(string(missing), "Some Identifier");
            testCase.verifyClass(out, 'char');
            testCase.verifyEqual(out, 'Some Identifier');
            out = processorModelName(string(ProcessorModelNameTest.cpuinfo('S')), "x");
            testCase.verifyClass(out, 'char');
            testCase.verifyEqual(out, 'S');
        end

    end

end
