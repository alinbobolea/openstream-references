classdef WiringTest < matlab.unittest.TestCase
    %WIRINGTEST Tests of machineProcessorModel and of the two places that must
    % call a helper: environmentRecord and setupOpenstream.
    %
    % machineProcessorModel is executed here, both of its branches (the file
    % is there; the file is not there, as on Windows). environmentRecord and
    % setupOpenstream cannot be executed by the unit tests (they need Python
    % with CoolProp, or change the Python of the MATLAB session), so that the
    % first calls the helper with the right arguments and the second uses
    % pythonExecutable is checked on the text of the code (comments left out).
    % This is a source-text check and is labelled as such. Each check is a
    % function of the source, run in the tests below on the real file and on
    % deliberately broken variants, so that the check is seen to fail.

    methods (TestClassSetup)

        function addPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            here = fileparts(mfilename('fullpath'));
            testCase.applyFixture(PathFixture(fullfile(here, '..', 'matlab')));
        end

    end

    methods (Static)

        function text = source(name)
            here = fileparts(mfilename('fullpath'));
            text = fileread(fullfile(here, '..', 'matlab', name));
        end

        function code = codeOf(text)
            % TEXT without the lines whose first non-blank character is %.
            lines = splitlines(string(text));
            keep = ~startsWith(strtrim(lines), "%");
            code = string(strjoin(reshape(lines(keep), 1, []), newline));
        end

        function problems = environmentRecordProblems(text)
            % What is wrong with the source TEXT of environmentRecord, as a
            % string row (empty when nothing): cpuModel must be set by one
            % call of machineProcessorModel with the file /proc/cpuinfo and
            % the value of PROCESSOR_IDENTIFIER, in that order, in code and
            % not in a comment, and not by cpuModelName alone.
            code = WiringTest.codeOf(text);
            problems = strings(1, 0);
            call = ['env\.cpuModel\s*=\s*machineProcessorModel\(\s*' ...
                '''/proc/cpuinfo''\s*,\s*getenv\(''PROCESSOR_IDENTIFIER''\)\s*\)'];
            if isempty(regexp(char(code), call, 'once'))
                problems(end+1) = "cpuModel is not set by machineProcessorModel('/proc/cpuinfo', getenv('PROCESSOR_IDENTIFIER'))";
            end
            if ~isempty(regexp(char(code), 'env\.cpuModel\s*=\s*cpuModelName', 'once'))
                problems(end+1) = "cpuModel is also set from the file alone";
            end
        end

        function problems = setupOpenstreamProblems(text)
            % What is wrong with the source TEXT of setupOpenstream: the
            % program given to pyenv must come from pythonExecutable, and
            % the Linux-only path must not be built there.
            code = WiringTest.codeOf(text);
            problems = strings(1, 0);
            if isempty(regexp(char(code), ...
                    'pyenv\(\s*Version\s*=\s*pythonExecutable\(\s*pythonLocation\s*\)\s*\)', 'once'))
                problems(end+1) = "pyenv is not given pythonExecutable(pythonLocation)";
            end
            if contains(code, "'python3'") || contains(code, '"python3"')
                problems(end+1) = "the path of python3 is built in setupOpenstream";
            end
        end

        function text = cpuinfo(model)
            tab = char(9);
            text = ['processor' tab ': 0' newline 'model name' tab ': ' model newline];
        end

    end

    methods (Test)

        function testFileThereGivesItsModelName(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            folder = testCase.applyFixture(TemporaryFolderFixture).Folder;
            file = fullfile(folder, 'cpuinfo');
            WiringTest.write(file, WiringTest.cpuinfo('Some CPU'));
            testCase.verifyEqual(machineProcessorModel(file, ''), 'Some CPU');
            % The variable is not used where the file exists.
            testCase.verifyEqual(machineProcessorModel(file, 'Other Identifier'), ...
                'Some CPU');
        end

        function testFileThereWithoutModelNameDoesNotFallBack(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            folder = testCase.applyFixture(TemporaryFolderFixture).Folder;
            file = fullfile(folder, 'cpuinfo');
            WiringTest.write(file, ['processor' char(9) ': 0' newline]);
            testCase.verifyEqual(machineProcessorModel(file, 'Some Identifier'), '');
            WiringTest.write(file, '');
            testCase.verifyEqual(machineProcessorModel(file, 'Some Identifier'), '');
        end

        function testFileNotThereGivesTheIdentifier(testCase)
            % The Windows branch: the file does not exist.
            import matlab.unittest.fixtures.TemporaryFolderFixture
            folder = testCase.applyFixture(TemporaryFolderFixture).Folder;
            missingFile = fullfile(folder, 'no-such-cpuinfo');
            testCase.assertFalse(isfile(missingFile));
            identifier = 'Intel64 Family 6 Model 85 Stepping 7, GenuineIntel';
            testCase.verifyEqual(machineProcessorModel(missingFile, identifier), identifier);
            testCase.verifyEqual(machineProcessorModel(missingFile, [' ' identifier newline]), ...
                identifier);
            testCase.verifyEqual(machineProcessorModel(missingFile, ''), '');
        end

        function testRealCpuinfoPathOnThisSystem(testCase)
            % With the path environmentRecord passes: where the file exists
            % (Linux) the answer is the model name of the file, whatever the
            % variable says; where it does not, the variable.
            out = machineProcessorModel('/proc/cpuinfo', 'Identifier Of A Test');
            if isfile('/proc/cpuinfo')
                testCase.verifyEqual(out, cpuModelName(fileread('/proc/cpuinfo')));
            else
                testCase.verifyEqual(out, 'Identifier Of A Test');
            end
        end

        function testEnvironmentRecordCallsTheHelper(testCase)
            problems = WiringTest.environmentRecordProblems( ...
                WiringTest.source('environmentRecord.m'));
            testCase.verifyEmpty(problems, strjoin(problems, '; '));
        end

        function testEnvironmentRecordCheckFailsOnBrokenVariants(testCase)
            % Negative controls: the check, run on variants of the real
            % source, reports a problem for each.
            real = WiringTest.source('environmentRecord.m');
            call = "env.cpuModel = machineProcessorModel('/proc/cpuinfo', getenv('PROCESSOR_IDENTIFIER'));";
            testCase.assertTrue(contains(real, call), ...
                'the real source has the call in this form (the variants replace it)');
            variants = { ...
                "env.cpuModel = cpuModelName(fileread('/proc/cpuinfo'));", ...
                "env.cpuModel = machineProcessorModel(getenv('PROCESSOR_IDENTIFIER'), '/proc/cpuinfo');", ...
                "% " + call, ...
                "env.cpuModel = machineProcessorModel('/proc/cpuinfo', getenv('PROCESSOR_ARCHITECTURE'));", ...
                "other = machineProcessorModel('/proc/cpuinfo', getenv('PROCESSOR_IDENTIFIER'));", ...
                call + newline + "env.cpuModel = cpuModelName(fileread('/proc/cpuinfo'));"};
            for k = 1:numel(variants)
                broken = replace(real, call, variants{k});
                testCase.assertNotEqual(broken, string(real), sprintf('variant %d changed the source', k));
                testCase.verifyNotEmpty(WiringTest.environmentRecordProblems(broken), ...
                    sprintf('variant %d is reported', k));
            end
        end

        function testSetupOpenstreamUsesPythonExecutable(testCase)
            % A check of the text of setupOpenstream (see the class comment).
            problems = WiringTest.setupOpenstreamProblems( ...
                WiringTest.source('setupOpenstream.m'));
            testCase.verifyEmpty(problems, strjoin(problems, '; '));
        end

        function testSetupOpenstreamCheckFailsOnBrokenVariants(testCase)
            real = WiringTest.source('setupOpenstream.m');
            line = "pyenv(Version = pythonExecutable(pythonLocation));";
            testCase.assertTrue(contains(real, line));
            variants = { ...
                "pyenv(Version = fullfile(pythonLocation, 'bin', 'python3'));", ...
                "% " + line + newline + "        pyenv(Version = pythonLocation);", ...
                "pyenv(Version = pythonExecutable(pythonLocation, false));", ...
                line + newline + "        other = fullfile(pythonLocation, 'bin', 'python3');"};
            for k = 1:numel(variants)
                broken = replace(real, line, variants{k});
                testCase.assertNotEqual(broken, string(real));
                testCase.verifyNotEmpty(WiringTest.setupOpenstreamProblems(broken), ...
                    sprintf('variant %d is reported', k));
            end
        end

        function testCodeOfDropsCommentLines(testCase)
            code = WiringTest.codeOf(sprintf('a = 1;\n  %% b = 2;\n%% c\nd = 3;'));
            testCase.verifyEqual(code, string(sprintf('a = 1;\nd = 3;')));
        end

    end

    methods (Static, Access = private)

        function write(file, text)
            fid = fopen(file, 'w');
            fprintf(fid, '%s', text);
            fclose(fid);
        end

    end

end
