classdef RunTargetTest < matlab.unittest.TestCase
    %RUNTARGETTEST Unit test for the target guard of runTarget.

    methods (TestClassSetup)

        function addPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            here = fileparts(mfilename('fullpath'));
            testCase.applyFixture(PathFixture(fullfile(here, '..', 'matlab')));
        end

    end

    methods (Test)

        function testUnknownTargetIsRejected(testCase)
            testCase.verifyError(@() runTarget('nope'), ...
                'References:UnknownTarget');
        end

    end

end
