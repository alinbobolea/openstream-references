classdef InputFixtureListTest < matlab.unittest.TestCase
    %INPUTFIXTURELISTTEST Unit tests for validateInputFixtureList.
    %
    % The valid lists are the inclusion half of every rejection test: each
    % rejection changes one thing in them. Files are created in a temporary
    % folder, named by absolute paths unless a test says otherwise.

    properties
        folder
    end

    methods (TestClassSetup)

        function addPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            here = fileparts(mfilename('fullpath'));
            testCase.applyFixture(PathFixture(fullfile(here, '..', 'matlab')));
        end

    end

    methods (TestMethodSetup)

        function makeFolder(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture);
            testCase.folder = fixture.Folder;
            for name = ["a.inp" "geom.inp" "models.inp" "options.inp" "bc.inp"]
                fid = fopen(fullfile(testCase.folder, name), 'w');
                fclose(fid);
            end
        end

    end

    methods

        function entries = validList(testCase)
            entries = { ...
                struct('name', 'read_a', 'kind', 'read', ...
                    'file', testCase.filePath('a.inp')), ...
                struct('name', 'bc_a', 'kind', 'bc', ...
                    'file', testCase.filePath('a.inp'), ...
                    'geometryFile', testCase.filePath('geom.inp'), ...
                    'geometryId', 'G')};
        end

        function e = validInputSet(testCase)
            e = struct('name', 'set_a', 'kind', 'inputset', ...
                'model', {{testCase.filePath('models.inp'); 'M'}}, ...
                'options', {{testCase.filePath('options.inp'); 'O'}}, ...
                'geometry', {{testCase.filePath('geom.inp'); 'G'}}, ...
                'bc', testCase.filePath('bc.inp'), ...
                'logmode', 'NONE');
        end

        function p = filePath(testCase, name)
            p = fullfile(testCase.folder, name);
        end

        function verifyRejected(testCase, entries, checkFiles, expectedText)
            % Rejected with the fixture identifier; with EXPECTEDTEXT, the
            % message must also contain it.
            testCase.verifyError( ...
                @() validateInputFixtureList(entries, checkFiles), ...
                'References:InvalidInputFixture');
            if nargin > 3
                try
                    validateInputFixtureList(entries, checkFiles);
                catch err
                    testCase.verifySubstring(err.message, expectedText);
                end
            end
        end

        function verifyAccepted(testCase, entries, checkFiles)
            testCase.verifyWarningFree( ...
                @() validateInputFixtureList(entries, checkFiles));
        end

    end

    methods (Test)

        function testValidListIsAccepted(testCase)
            testCase.verifyAccepted(testCase.validList(), true);
        end

        function testRealManifestIsAccepted(testCase)
            here = fileparts(mfilename('fullpath'));
            manifest = fullfile(here, '..', 'cases', 'input-fixture.json');
            entries = jsondecode(fileread(manifest));
            testCase.verifyNumElements(entries, 330);
            testCase.verifyAccepted(entries, false);
        end

        function testStructArrayIsAccepted(testCase)
            entries = [struct('name', 'up_a', 'kind', 'upper', 'text', 'a', 'as', 'char'), ...
                struct('name', 'up_b', 'kind', 'upper', 'text', 'b', 'as', 'char')];
            testCase.verifyAccepted(entries, true);
        end

        function testNonListIsRejected(testCase)
            testCase.verifyRejected([], false);
            testCase.verifyRejected(42, false);
            testCase.verifyRejected({}, false);
        end

        function testNonStructEntryIsRejected(testCase)
            entries = testCase.validList();
            entries{2} = 5;
            testCase.verifyRejected(entries, false, 'entry 2');
            entries = testCase.validList();
            entries{2} = [entries{2}, entries{2}];
            testCase.verifyRejected(entries, false, 'entry 2');
        end

        function testMissingNameIsRejected(testCase)
            entries = testCase.validList();
            entries{2} = rmfield(entries{2}, 'name');
            testCase.verifyRejected(entries, true, 'has no name');
        end

        function testRepeatedNameIsRejected(testCase)
            entries = testCase.validList();
            entries{2}.name = 'read_a';
            testCase.verifyRejected(entries, true, 'duplicate name(s): read_a');
        end

        function testInvalidNamesAreRejected(testCase)
            bad = {'1read', '_read', 'read-a', 'read a', '', ['r' char(233) 'ad'], ...
                ['read_a' newline], 5, {'read_a'}};
            for k = 1:numel(bad)
                entries = testCase.validList();
                entries{1}.name = bad{k};
                testCase.verifyRejected(entries, true, 'invalid name');
            end
        end

        function testUnknownKindIsRejected(testCase)
            entries = testCase.validList();
            entries{1}.kind = 'nope';
            testCase.verifyRejected(entries, true, 'read_a');
            entries{1}.kind = 3;
            testCase.verifyRejected(entries, true, 'read_a');
        end

        function testMissingKindIsRejected(testCase)
            entries = testCase.validList();
            entries{1} = rmfield(entries{1}, 'kind');
            testCase.verifyRejected(entries, true, 'read_a');
        end

        function testMissingRequiredFieldIsRejected(testCase)
            entries = testCase.validList();
            entries{2} = rmfield(entries{2}, 'geometryId');
            testCase.verifyRejected(entries, true, 'geometryId');
        end

        function testMissingFileIsRejected(testCase)
            entries = testCase.validList();
            entries{2}.geometryFile = testCase.filePath('absent.inp');
            testCase.verifyRejected(entries, true, 'absent.inp');
        end

        function testRelativePathIsResolvedFromCurrentFolder(testCase)
            import matlab.unittest.fixtures.CurrentFolderFixture
            testCase.applyFixture(CurrentFolderFixture(testCase.folder));
            entries = {struct('name', 'read_a', 'kind', 'read', 'file', 'a.inp')};
            testCase.verifyAccepted(entries, true);
            entries{1}.file = 'absent.inp';
            testCase.verifyRejected(entries, true, 'absent.inp');
        end

        function testValidInputSetIsAccepted(testCase)
            entries = [testCase.validList(), {testCase.validInputSet()}];
            testCase.verifyAccepted(entries, true);
            minimal = struct('name', 'set_b', 'kind', 'inputset', 'logmode', 'NONE');
            testCase.verifyAccepted([entries, {minimal}], true);
        end

        function testInputSetBareModelIsRejected(testCase)
            % The pair shape is checked even without the file check.
            e = testCase.validInputSet();
            e.model = testCase.filePath('models.inp');
            testCase.verifyRejected({e}, false, 'model');
            e = testCase.validInputSet();
            e.bc = {testCase.filePath('bc.inp')};
            testCase.verifyRejected({e}, false, 'bc');
        end

        function testInputSetMissingFilesAreRejected(testCase)
            for field = {'model', 'options', 'geometry'}
                e = testCase.validInputSet();
                pair = e.(field{1});
                pair{1} = testCase.filePath('absent.inp');
                e.(field{1}) = pair;
                testCase.verifyRejected({e}, true, 'absent.inp');
            end
            e = testCase.validInputSet();
            e.bc = testCase.filePath('absent.inp');
            testCase.verifyRejected({e}, true, 'absent.inp');
        end

        function testReadMissingIsExempt(testCase)
            entries = testCase.validList();
            entries{1}.file = testCase.filePath('absent.inp');
            testCase.verifyRejected(entries, true, 'absent.inp');
            entries{1}.name = 'read_missing';
            testCase.verifyAccepted(entries, true);
        end

        function testMissingFileAcceptedWithoutFileCheck(testCase)
            entries = testCase.validList();
            entries{2}.geometryFile = testCase.filePath('absent.inp');
            testCase.verifyAccepted(entries, false);
        end

    end

end
