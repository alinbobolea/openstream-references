classdef DatasetCaseListTest < matlab.unittest.TestCase
    %DATASETCASELISTTEST Unit tests for validateDatasetCaseList.
    %
    % Each test builds a temporary database-like root with a package folder
    % +FakeSet. The valid case is the inclusion half of every rejection test.

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
            mkdir(fullfile(testCase.root, '+FakeSet'));
        end

    end

    methods

        function c = validCase(~)
            c = struct( ...
                'name', 'c1', ...
                'dataset', 'FakeSet', ...
                'testID', 1, ...
                'solver', 'Mixture', ...
                'model', struct(), ...
                'options', struct());
        end

    end

    methods (Test)

        function testValidCaseIsAccepted(testCase)
            testCase.verifyWarningFree( ...
                @() validateDatasetCaseList(testCase.validCase(), testCase.root));
        end

        function testMissingFieldIsRejected(testCase)
            c = rmfield(testCase.validCase(), 'solver');
            testCase.verifyError( ...
                @() validateDatasetCaseList(c, testCase.root), ...
                'References:InvalidCase');
        end

        function testDuplicateNameIsRejected(testCase)
            c = [testCase.validCase(), testCase.validCase()];
            testCase.verifyError( ...
                @() validateDatasetCaseList(c, testCase.root), ...
                'References:InvalidCase');
        end

        function testMissingDatasetIsRejected(testCase)
            c = testCase.validCase();
            c.dataset = 'Nope';
            testCase.verifyError( ...
                @() validateDatasetCaseList(c, testCase.root), ...
                'References:MissingInput');
        end

        function testUnknownSolverIsRejected(testCase)
            c = testCase.validCase();
            c.solver = 'Nope';
            testCase.verifyError( ...
                @() validateDatasetCaseList(c, testCase.root), ...
                'References:UnknownSolver');
        end

        function testGeometryAndBoundaryConditionOverridesAreAccepted(testCase)
            c = testCase.validCase();
            c.geometry = struct('NWALL', 2, 'HDIAM', 0.01);
            c.boundaryConditions = struct('POWER', 90000, 'WPOWER', [0.5; 0.5]);
            testCase.verifyWarningFree( ...
                @() validateDatasetCaseList(c, testCase.root));
        end

        function testOverrideThatIsNotAStructIsRejected(testCase)
            for kind = ["geometry" "boundaryConditions"]
                c = testCase.validCase();
                c.(kind) = 5;
                testCase.verifyError( ...
                    @() validateDatasetCaseList(c, testCase.root), ...
                    'References:InvalidCase', char(kind));
                c.(kind) = [struct('A', 1), struct('A', 2)];
                testCase.verifyError( ...
                    @() validateDatasetCaseList(c, testCase.root), ...
                    'References:InvalidCase', char(kind));
            end
        end

        function testOverrideOfTheIDIsRejected(testCase)
            for kind = ["geometry" "boundaryConditions"]
                c = testCase.validCase();
                c.(kind) = struct('ID', 'OTHER');
                testCase.verifyError( ...
                    @() validateDatasetCaseList(c, testCase.root), ...
                    'References:InvalidCase', char(kind));
            end
        end

        function testOverrideValueThatCannotBeWrittenIsRejected(testCase)
            for bad = {NaN, [], 'a;b'}
                c = testCase.validCase();
                c.geometry = struct('KEY', bad{1});
                testCase.verifyError( ...
                    @() validateDatasetCaseList(c, testCase.root), ...
                    'References:InvalidCase');
            end
        end

    end

end
