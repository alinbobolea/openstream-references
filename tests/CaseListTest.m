classdef CaseListTest < matlab.unittest.TestCase
    %CASELISTTEST Unit tests for validateCaseList.
    %
    % Each test builds a temporary OpenSTREAM-like root with an inputs/
    % folder. The valid case names files that exist there and uses the
    % fixture class ExportFixture.Node as its solver, so the accepted case
    % is the inclusion half of every rejection test.

    properties
        root
    end

    methods (TestClassSetup)

        function addPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            here = fileparts(mfilename('fullpath'));
            testCase.applyFixture(PathFixture(here));
            testCase.applyFixture(PathFixture(fullfile(here, '..', 'matlab')));
        end

    end

    methods (TestMethodSetup)

        function makeRoot(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            folder = testCase.applyFixture(TemporaryFolderFixture);
            testCase.root = folder.Folder;
            mkdir(fullfile(testCase.root, 'inputs'));
            for name = ["models.inp" "options.inp" "geom.inp" "bc.inp"]
                fid = fopen(fullfile(testCase.root, 'inputs', name), 'w');
                fclose(fid);
            end
        end

    end

    methods

        function c = validCase(~)
            c = struct( ...
                'name', 'case1', ...
                'solver', 'ExportFixture.Node', ...
                'modelFile', 'models.inp', 'modelID', 'M', ...
                'optionsFile', 'options.inp', 'optionsID', 'O', ...
                'geometryFile', 'geom.inp', 'geometryID', 'G', ...
                'bcFile', 'bc.inp');
        end

    end

    methods (Test)

        function testValidCaseIsAccepted(testCase)
            testCase.verifyWarningFree( ...
                @() validateCaseList(testCase.validCase(), testCase.root));
        end

        function testMissingFieldIsRejected(testCase)
            c = rmfield(testCase.validCase(), 'solver');
            testCase.verifyError(@() validateCaseList(c, testCase.root), ...
                'References:InvalidCase');
        end

        function testDuplicateNameIsRejected(testCase)
            c = [testCase.validCase(), testCase.validCase()];
            testCase.verifyError(@() validateCaseList(c, testCase.root), ...
                'References:InvalidCase');
        end

        function testMissingInputFileIsRejected(testCase)
            c = testCase.validCase();
            c.bcFile = 'absent.inp';
            testCase.verifyError(@() validateCaseList(c, testCase.root), ...
                'References:MissingInput');
        end

        function testUnknownSolverIsRejected(testCase)
            c = testCase.validCase();
            c.solver = 'Solvers.Nope';
            testCase.verifyError(@() validateCaseList(c, testCase.root), ...
                'References:UnknownSolver');
        end

    end

end
