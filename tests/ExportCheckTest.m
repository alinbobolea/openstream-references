classdef ExportCheckTest < matlab.unittest.TestCase
    %EXPORTCHECKTEST Unit tests for checkInputFixtureCases.
    %
    % The accepted list holds a passing case and a case that failed with an
    % upstream error; the rejected list differs only by one case that failed
    % because of the manifest.

    methods (TestClassSetup)

        function addPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            here = fileparts(mfilename('fullpath'));
            testCase.applyFixture(PathFixture(fullfile(here, '..', 'matlab')));
        end

    end

    methods (Static)

        function c = recorded(name, errorId)
            c = struct('name', name, 'errorId', errorId);
        end

    end

    methods (Test)

        function testIntendedFailuresAreAccepted(testCase)
            cases = {ExportCheckTest.recorded('a', ''), ...
                ExportCheckTest.recorded('b', 'OpenSTREAM:INPUT:fileTypeError')};
            testCase.verifyWarningFree(@() checkInputFixtureCases(cases));
        end

        function testEmptyListIsAccepted(testCase)
            testCase.verifyWarningFree(@() checkInputFixtureCases({}));
        end

        function testManifestFailureIsRejected(testCase)
            cases = {ExportCheckTest.recorded('a', ''), ...
                ExportCheckTest.recorded('b', 'OpenSTREAM:INPUT:fileTypeError'), ...
                ExportCheckTest.recorded('typo_case', 'References:InvalidInputFixture')};
            testCase.verifyError(@() checkInputFixtureCases(cases), ...
                'References:InvalidInputFixture');
            try
                checkInputFixtureCases(cases);
            catch err
                testCase.verifySubstring(err.message, 'typo_case');
            end
        end

    end

end
