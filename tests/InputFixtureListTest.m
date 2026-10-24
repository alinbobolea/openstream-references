classdef InputFixtureListTest < matlab.unittest.TestCase
    %INPUTFIXTURELISTTEST Unit tests for validateInputFixtureList.
    %
    % The valid lists are the inclusion half of every rejection test: each
    % rejection changes one thing in them. Files are created in a temporary
    % folder, named by absolute paths unless a test says otherwise.

    properties
        folder
    end

    methods (Static)

        function call = writeCall(className)
            % One write call with the keys of CLASSNAME, as jsondecode
            % returns it.
            values = {{'POWER'; struct('double', {{'1'}})}};
            if strcmp(className, 'BoundaryConditions')
                d = struct('double', {{'0'}});
                call = struct('time', d, 'pressure', d, 'hin', d, 'mflow', d, ...
                    'values', {values});
            else
                call = struct('id', 'W', 'values', {values});
            end
        end

        function tf = namesUpstreamFile(e)
            % True when entry E names a file under upstream/ (the fields
            % validateInputFixtureList checks).
            paths = {};
            for field = {'file', 'geometryFile'}
                if isfield(e, field{1})
                    paths{end+1} = char(e.(field{1})); %#ok<AGROW>
                end
            end
            if strcmp(char(e.kind), 'inputset')
                for field = {'model', 'options', 'geometry'}
                    if isfield(e, field{1})
                        pair = e.(field{1});
                        paths{end+1} = char(pair{1}); %#ok<AGROW>
                    end
                end
                if isfield(e, 'bc')
                    paths{end+1} = char(e.bc);
                end
            end
            tf = any(startsWith(paths, 'upstream/'));
        end

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

        function entries = validCallList(~)
            % One entry per optional field and argument key of the upper,
            % sprintf, num2str and strcat kinds, as jsondecode returns
            % them (a JSON list of texts is a column cell of char).
            matrix = struct('rows', 2, 'double', {{'1'; '3'; '2'; '4'}});
            entries = { ...
                struct('name', 'sc_a', 'kind', 'strcat', 'args', ...
                    [struct('text', 'a '); struct('text', 'b')]), ...
                struct('name', 'sc_none', 'kind', 'strcat', 'args', []), ...
                struct('name', 'spf_u8', 'kind', 'sprintf', 'format', '%d', ...
                    'args', {{struct('uint8', {{'1'}}); struct('double', {{'2'}})}}), ...
                struct('name', 'spf_matrix', 'kind', 'sprintf', 'format', '%d,', ...
                    'args', struct('matrix', matrix)), ...
                struct('name', 'spf_string', 'kind', 'sprintf', 'format', 'x%s', ...
                    'args', struct('text', 'a'), 'formatClass', 'string'), ...
                struct('name', 'up_double', 'kind', 'upper', 'text', '', ...
                    'as', 'double', 'values', struct('double', {{'1'; '2'}})), ...
                struct('name', 'up_u8', 'kind', 'upper', 'text', '', ...
                    'as', 'uint8', 'values', struct('uint8', {{'1'}})), ...
                struct('name', 'up_scan', 'kind', 'upper', 'text', 'Infinity', ...
                    'as', 'textscan'), ...
                struct('name', 'n2s_plain', 'kind', 'num2str', ...
                    'values', struct('double', {{'1'}}), 'format', ''), ...
                struct('name', 'n2s_column', 'kind', 'num2str', ...
                    'values', struct('double', {{'1'; '2'}}), 'format', '%.11f ', ...
                    'shape', 'column'), ...
                struct('name', 'n2s_u8', 'kind', 'num2str', ...
                    'values', struct('double', {{'100'}}), 'format', '%.11f ', ...
                    'valuesClass', 'uint8'), ...
                struct('name', 'n2s_fmt', 'kind', 'num2str', ...
                    'values', struct('double', {{'1'}}), 'format', '%.11f ', ...
                    'formatClass', 'string'), ...
                struct('name', 'n2s_text', 'kind', 'num2str', ...
                    'values', struct('text', 'a b'), 'format', ''), ...
                struct('name', 'n2s_string', 'kind', 'num2str', ...
                    'values', struct('text', 'X'), 'format', '', ...
                    'valuesClass', 'string'), ...
                struct('name', 'n2s_row', 'kind', 'num2str', ...
                    'values', struct('double', {{'1'; '2'}}), 'format', '%.11f ', ...
                    'shape', 'row'), ...
                struct('name', 'spf_empty', 'kind', 'sprintf', 'format', '%d', ...
                    'args', {{struct('uint8', []); struct('double', [])}}), ...
                struct('name', 'handle_a', 'kind', 'handle', 'text', '@(z) z', ...
                    'z', struct('double', {{'1'}})), ...
                struct('name', 'tol_a', 'kind', 'ismembertol', ...
                    'a', struct('double', {{'1'}}), 'b', struct('double', {{'1'}}), ...
                    'tol', 0.001), ...
                struct('name', 'u8_a', 'kind', 'uint8', 'values', struct('double', {{'1'}})), ...
                struct('name', 'sum_a', 'kind', 'sum', 'values', struct('double', []))};
        end

        function entries = realManifest(~)
            here = fileparts(mfilename('fullpath'));
            manifest = fullfile(here, '..', 'cases', 'input-fixture.json');
            entries = jsondecode(fileread(manifest));
        end

        function verifyCallEntryRejected(testCase, index, field, value, expectedText)
            % validCallList with one field of one entry changed (or removed
            % when VALUE is the text '<remove>') is rejected.
            entries = testCase.validCallList();
            if ischar(value) && strcmp(value, '<remove>')
                entries{index} = rmfield(entries{index}, field);
            else
                entries{index}.(field) = value;
            end
            testCase.verifyRejected(entries, false, expectedText);
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
            entries = testCase.realManifest();
            testCase.verifyNumElements(entries, 732);
            testCase.verifyAccepted(entries, false);
        end

        function testRealManifestFilesExist(testCase)
            % The file check from the repository root. Entries naming files
            % under upstream/ are left out: that checkout exists only in the
            % references job, whose own validation checks them before any
            % case runs.
            import matlab.unittest.fixtures.CurrentFolderFixture
            here = fileparts(mfilename('fullpath'));
            testCase.applyFixture(CurrentFolderFixture(fullfile(here, '..')));
            entries = reshape(testCase.realManifest(), 1, []);
            upstream = cellfun(@InputFixtureListTest.namesUpstreamFile, entries);
            testCase.verifyEqual(nnz(upstream), 69);
            local = entries(~upstream);
            testCase.verifyAccepted(local, true);
            % Negative control: one local file renamed to a missing one.
            k = find(cellfun(@(e) isfield(e, 'file') ...
                && ~strcmp(e.name, 'read_missing'), local), 1);
            local{k}.file = 'cases/input-fixture/absent.inp';
            testCase.verifyRejected(local, true, 'absent.inp');
        end

        function testExporterChangeFieldIsAccepted(testCase)
            % exporterChange is allowed on every kind; a misspelling of it
            % is an unknown field like any other.
            entries = testCase.validCallList();
            entries{1}.exporterChange = 'x';
            testCase.verifyAccepted(entries, true);
            entries = testCase.validList();
            entries{1}.exporterChange = 'x';
            testCase.verifyAccepted(entries, true);
            entries{1} = rmfield(entries{1}, 'exporterChange');
            entries{1}.exporterchange = 'x';
            testCase.verifyRejected(entries, true, 'unknown field(s): exporterchange');
        end

        function testDoubleArgumentNeedsTexts(testCase)
            testCase.verifyCallEntryRejected(3, 'args', ...
                {struct('double', [1 2])}, 'double must be a list of texts');
            testCase.verifyCallEntryRejected(3, 'args', ...
                {struct('double', '1')}, 'double must be a list of texts');
        end

        function testNumberFieldsNeedTextLists(testCase)
            testCase.verifyCallEntryRejected(17, 'z', ...
                struct('double', [0 1]), 'z must be');
            testCase.verifyCallEntryRejected(18, 'a', ...
                struct('double', 1), 'a must be');
            testCase.verifyCallEntryRejected(18, 'b', ...
                struct('double', {{'1'}}, 'text', 'a'), 'b must be');
            testCase.verifyCallEntryRejected(19, 'values', ...
                struct('text', 'a'), 'values must be');
            testCase.verifyCallEntryRejected(20, 'values', ...
                struct('double', {{1}}), 'values must be');
        end

        function testFormatClassOnStrcatIsRejected(testCase)
            testCase.verifyCallEntryRejected(1, 'formatClass', 'string', ...
                'unknown field(s): formatClass');
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

        function testValidCallListIsAccepted(testCase)
            testCase.verifyAccepted(testCase.validCallList(), true);
        end

        function testStrcatNeedsArgs(testCase)
            testCase.verifyCallEntryRejected(1, 'args', '<remove>', 'args');
        end

        function testArgsMustBeAList(testCase)
            testCase.verifyCallEntryRejected(1, 'args', 'abc', 'args must be a list');
            testCase.verifyCallEntryRejected(3, 'args', 5, 'args must be a list');
        end

        function testArgumentNeedsExactlyOneKey(testCase)
            testCase.verifyCallEntryRejected(3, 'args', ...
                {struct('double', {{'1'}}, 'text', 'a')}, 'exactly one key');
            testCase.verifyCallEntryRejected(1, 'args', {5}, 'exactly one key');
        end

        function testUnknownArgumentKeyIsRejected(testCase)
            testCase.verifyCallEntryRejected(3, 'args', ...
                {struct('int8', {{'1'}})}, 'unknown key int8');
            testCase.verifyCallEntryRejected(1, 'args', ...
                struct('number', 1), 'unknown key number');
        end

        function testUint8ArgumentNeedsTexts(testCase)
            for bad = {[1 2], '1', {1}}
                testCase.verifyCallEntryRejected(3, 'args', ...
                    {struct('uint8', bad)}, 'uint8 must be a list of texts');
            end
        end

        function testMatrixRowsCheckAlone(testCase)
            % Rows that pass the divisibility check (the number of texts is
            % a multiple of them, or there are none), so only the rows
            % check (positive, integer, finite, numeric) rejects them.
            texts = {'1'; '3'; '2'; '4'};
            bad = {struct('rows', 0.5, 'double', {texts}), ...
                struct('rows', -2, 'double', {texts}), ...
                struct('rows', 0, 'double', {[]}), ...
                struct('rows', Inf, 'double', {[]}), ...
                struct('rows', true, 'double', {texts}), ...
                struct('rows', char(2), 'double', {texts})};
            for k = 1:numel(bad)
                testCase.verifyCallEntryRejected(4, 'args', ...
                    struct('matrix', bad(k)), 'matrix must be');
            end
            % The accepted neighbours: an empty matrix with 2 rows, and
            % the same texts with 1 row.
            for good = {struct('rows', 2, 'double', {[]}), struct('rows', 1, 'double', {texts})}
                entries = testCase.validCallList();
                entries{4}.args = struct('matrix', good);
                testCase.verifyAccepted(entries, false);
            end
        end

        function testMatrixArgumentIsChecked(testCase)
            texts = {'1'; '3'; '2'; '4'};
            bad = {struct('rows', 3, 'double', {texts}), ...
                struct('rows', 0, 'double', {texts}), ...
                struct('rows', 1.5, 'double', {texts}), ...
                struct('rows', Inf, 'double', {texts}), ...
                struct('rows', '2', 'double', {texts}), ...
                struct('rows', [2 2], 'double', {texts}), ...
                struct('double', {texts}), ...
                struct('rows', 2, 'double', {texts}, 'cols', 2), ...
                struct('rows', 2, 'double', [1 3 2 4]), ...
                {texts}};
            for k = 1:numel(bad)
                testCase.verifyCallEntryRejected(4, 'args', ...
                    struct('matrix', bad(k)), 'matrix must be');
            end
        end

        function testUpperAsIsChecked(testCase)
            testCase.verifyCallEntryRejected(6, 'as', 'number', 'as must be');
            testCase.verifyCallEntryRejected(6, 'as', 5, 'as must be');
        end

        function testUpperValuesAreChecked(testCase)
            testCase.verifyCallEntryRejected(6, 'values', '<remove>', 'values must be');
            testCase.verifyCallEntryRejected(6, 'values', ...
                struct('uint8', {{'1'}}), 'values must be');
            testCase.verifyCallEntryRejected(6, 'values', ...
                struct('double', [1 2]), 'values must be');
            testCase.verifyCallEntryRejected(7, 'values', ...
                struct('double', {{'1'}}), 'values must be');
            testCase.verifyCallEntryRejected(8, 'values', ...
                struct('double', {{'1'}}), 'values applies only');
        end

        function testNum2strFormatMustBeText(testCase)
            testCase.verifyCallEntryRejected(9, 'format', 5, 'format must be text');
        end

        function testNum2strValuesAreChecked(testCase)
            testCase.verifyCallEntryRejected(9, 'values', ...
                struct('logical', true), 'values must be');
            testCase.verifyCallEntryRejected(9, 'values', ...
                struct('double', 1), 'values must be');
            testCase.verifyCallEntryRejected(9, 'values', ...
                struct('double', {{'1'}}, 'text', 'a'), 'values must be');
            testCase.verifyCallEntryRejected(13, 'values', ...
                struct('text', {{'a'}}), 'values must be');
        end

        function testNum2strTextNeedsEmptyFormat(testCase)
            testCase.verifyCallEntryRejected(13, 'format', '%d', 'empty format');
        end

        function testNum2strValuesClassIsChecked(testCase)
            testCase.verifyCallEntryRejected(11, 'valuesClass', 'string', ...
                'valuesClass must be uint8');
            testCase.verifyCallEntryRejected(11, 'valuesClass', 'int8', ...
                'valuesClass must be uint8');
            testCase.verifyCallEntryRejected(14, 'valuesClass', 'uint8', ...
                'valuesClass must be string');
        end

        function testNum2strShapeIsChecked(testCase)
            testCase.verifyCallEntryRejected(10, 'shape', 'diagonal', 'shape must be');
            testCase.verifyCallEntryRejected(13, 'shape', 'column', ...
                'shape applies to double values only');
        end

        function testNum2strFormatClassNeedsFormat(testCase)
            testCase.verifyCallEntryRejected(12, 'format', '', 'formatClass needs a format');
        end

        function testFormatClassMustBeString(testCase)
            testCase.verifyCallEntryRejected(5, 'formatClass', 'char', ...
                'formatClass must be string');
            testCase.verifyCallEntryRejected(12, 'formatClass', 'char', ...
                'formatClass must be string');
        end

        function testCallFieldsOnOtherKindsAreRejected(testCase)
            % The fields num2str or sprintf use are unknown on other kinds.
            testCase.verifyCallEntryRejected(5, 'shape', 'column', ...
                'unknown field(s): shape');
            testCase.verifyCallEntryRejected(6, 'valuesClass', 'uint8', ...
                'unknown field(s): valuesClass');
            testCase.verifyCallEntryRejected(6, 'formatClass', 'string', ...
                'unknown field(s): formatClass');
            entries = testCase.validList();
            entries{1}.formatClass = 'string';
            testCase.verifyRejected(entries, false, 'unknown field(s): formatClass');
        end

        function testUnknownFieldsAreRejected(testCase)
            % Misspelled optional fields; validCallList itself (each entry
            % with its correct spelling) is accepted by
            % testValidCallListIsAccepted.
            testCase.verifyCallEntryRejected(10, 'shap', 'column', ...
                'unknown field(s): shap');
            testCase.verifyCallEntryRejected(5, 'formatclass', 'string', ...
                'unknown field(s): formatclass');
            testCase.verifyCallEntryRejected(14, 'valueClass', 'string', ...
                'unknown field(s): valueClass');
            testCase.verifyCallEntryRejected(1, 'arg', [], 'unknown field(s): arg');
            entries = testCase.validList();
            entries{2}.geometryID = 'G';
            testCase.verifyRejected(entries, false, 'unknown field(s): geometryID');
            e = testCase.validInputSet();
            e.bcFile = testCase.filePath('bc.inp');
            testCase.verifyRejected({e}, false, 'unknown field(s): bcFile');
        end

        function testEveryKindAcceptsItsFields(testCase)
            % Every optional field of the table, on its kind, together.
            e = testCase.validInputSet();
            testCase.verifyAccepted({e}, true);
            entries = testCase.validCallList();
            entries{10}.valuesClass = 'uint8';
            entries{10}.formatClass = 'string';
            entries{10}.exporterChange = 'x';
            testCase.verifyAccepted(entries, false);
        end

        function testClassIsChecked(testCase)
            classes = {'Model', 'Options', 'Geometry', 'BoundaryConditions'};
            for kind = {'default', 'listprops', 'write'}
                for className = classes
                    e = struct('name', 'c', 'kind', kind{1}, 'class', className{1});
                    if strcmp(kind{1}, 'write')
                        e.calls = InputFixtureListTest.writeCall(className{1});
                    end
                    testCase.verifyAccepted({e}, false);
                end
                for bad = {'Mod', 'model', 5, ''}
                    e.class = bad{1};
                    testCase.verifyRejected({e}, false, 'class must be');
                end
            end
        end

        function testWriteCallKeysAreChecked(testCase)
            % Accepted: one call with the keys of its class, two calls (a
            % struct array, as jsondecode gives calls with the same keys),
            % and calls as a cell. Rejected: a missing, a misspelled or an
            % extra key, and calls that are not a non-empty list of objects.
            model = struct('name', 'w', 'kind', 'write', 'class', 'Model', ...
                'calls', InputFixtureListTest.writeCall('Model'));
            bc = model;
            bc.name = 'w_bc';
            bc.class = 'BoundaryConditions';
            bc.calls = InputFixtureListTest.writeCall('BoundaryConditions');
            testCase.verifyAccepted({model, bc}, false);
            e = bc;
            e.calls = [bc.calls; bc.calls];
            testCase.verifyAccepted({e}, false);
            e.calls = {bc.calls; bc.calls};
            testCase.verifyAccepted({e}, false);

            e = model;
            e.calls = rmfield(model.calls, 'id');
            testCase.verifyRejected({e}, false, 'call 1 is missing key(s): id');
            e.calls.ID = 'W';
            testCase.verifyRejected({e}, false, 'call 1 is missing key(s): id');
            e = model;
            e.calls.time = struct('double', {{'0'}});
            testCase.verifyRejected({e}, false, 'call 1 has unknown key(s): time');
            e = bc;
            e.calls = rmfield(bc.calls, 'hin');
            testCase.verifyRejected({e}, false, 'call 1 is missing key(s): hin');
            e = bc;
            e.calls.id = 'W';
            testCase.verifyRejected({e}, false, 'call 1 has unknown key(s): id');
            e = bc;
            e.calls = {bc.calls; 5};
            testCase.verifyRejected({e}, false, 'call 2 is not an object');
            for badCalls = {[], {}, 'abc', 5}
                e = model;
                e.calls = badCalls{1};
                testCase.verifyRejected({e}, false, 'calls must be');
            end
        end

        function testIsmembertolTolIsChecked(testCase)
            testCase.verifyCallEntryRejected(18, 'tol', '0.001', 'tol must be a number');
            testCase.verifyCallEntryRejected(18, 'tol', [0.001 0.002], 'tol must be a number');
            testCase.verifyCallEntryRejected(18, 'tol', true, 'tol must be a number');
            testCase.verifyCallEntryRejected(18, 'tol', 1i, 'tol must be a number');
            testCase.verifyCallEntryRejected(18, 'tol', {0.001}, 'tol must be a number');
            entries = testCase.validCallList();
            entries{18}.tol = 0;
            testCase.verifyAccepted(entries, false);
        end

        function testSumsweepLengthsAreChecked(testCase)
            e = struct('name', 'sw', 'kind', 'sumsweep', 'lengths', [1; 2; 300]);
            testCase.verifyAccepted({e}, false);
            e.lengths = 5;
            testCase.verifyAccepted({e}, false);
            for bad = {[], zeros(1, 0), zeros(0, 1), [0; 1], [1; 1.5], [1; Inf], ...
                    [1; NaN], '3', {1}, true, [1 2; 3 4], [-1; 2]}
                e.lengths = bad{1};
                testCase.verifyRejected({e}, false, 'lengths must be');
            end
        end

    end

end
