classdef PythonExecutableTest < matlab.unittest.TestCase
    %PYTHONEXECUTABLETEST Unit tests for pythonExecutable.
    %
    % actions/setup-python keeps python3 in the bin folder of its location on
    % Linux and python.exe directly in the location on Windows. The unit tests
    % run on Linux, so the Windows form is checked by the names it must have,
    % not by the separator.

    methods (TestClassSetup)

        function addPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            here = fileparts(mfilename('fullpath'));
            testCase.applyFixture(PathFixture(fullfile(here, '..', 'matlab')));
        end

    end

    methods (Test)

        function testLinuxForm(testCase)
            location = '/opt/hostedtoolcache/Python/3.13.1/x64';
            out = pythonExecutable(location, false);
            testCase.verifyClass(out, 'char');
            testCase.verifyEqual(out, '/opt/hostedtoolcache/Python/3.13.1/x64/bin/python3');
        end

        function testWindowsForm(testCase)
            location = 'C:\hostedtoolcache\windows\Python\3.13.1\x64';
            out = pythonExecutable(location, true);
            testCase.verifyClass(out, 'char');
            testCase.verifyTrue(startsWith(out, location));
            testCase.verifyTrue(endsWith(out, 'python.exe'));
            testCase.verifyFalse(contains(out, 'python3'));
            testCase.verifyFalse(contains(out(numel(location)+1:end), 'bin'));
        end

        function testStringLocation(testCase)
            out = pythonExecutable("/x/y", false);
            testCase.verifyClass(out, 'char');
            testCase.verifyEqual(out, '/x/y/bin/python3');
        end

        function testDefaultFollowsThePlatform(testCase)
            % The default is the form of the system the tests run on.
            out = pythonExecutable('/x/y');
            if ispc()
                testCase.verifyTrue(endsWith(out, 'python.exe'));
            else
                testCase.verifyEqual(out, '/x/y/bin/python3');
            end
        end

        function testTheTwoFormsDiffer(testCase)
            % Negative control: a function returning one form for both
            % platforms fails the tests above.
            testCase.verifyNotEqual(pythonExecutable('/x/y', true), ...
                pythonExecutable('/x/y', false));
        end

    end

end
