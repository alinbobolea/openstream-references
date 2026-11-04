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

        function e = variant(kind, name, from, to)
            % The entry NAME of the entries of KIND, decoded after the text
            % FROM, which its JSON must hold exactly once, is replaced by TO.
            line = TestData.CaseEntries.row(kind, name);
            if count(line, from) ~= 1
                error('InputFixtureListTest:badVariant', ...
                    'Entry %s must hold the text %s exactly once', name, from);
            end
            e = jsondecode(strrep(line, from, to));
        end

        function entry = sweepEntry(calls)
            % An ismembertolsweep entry whose calls are the JSON text CALLS.
            entry = jsondecode(['{"name":"sweep_a","kind":"ismembertolsweep",' ...
                '"calls":' calls '}']);
        end

        function paths = namedFilePaths(line)
            % The files the JSON text LINE of an inputset, inputsetwarnings
            % or inputsetcall entry names, as a row cell of char: the first
            % item of the model, options and geometry pairs, bc, and the
            % value of a modelFilePath, optionsFilePath, geometryFilePath
            % or bcFilePath argument unless it is empty or holds the
            % scratch marker. Read from the text, so that it does not depend
            % on how jsondecode shapes the lists.
            paths = {};
            patterns = {'"(?:model|options|geometry)": \["([^"]*)"', ...
                '"bc": "([^"]*)"', ...
                '\["(?:model|options|geometry|bc)FilePath", "([^"]*)"\]'};
            for k = 1:numel(patterns)
                tokens = regexp(line, patterns{k}, 'tokens');
                for j = 1:numel(tokens)
                    path = tokens{j}{1};
                    if ~isempty(path) && ~contains(path, '<scratch>')
                        paths{end+1} = path; %#ok<AGROW>
                    end
                end
            end
        end

    end

    methods (TestClassSetup)

        function addPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            here = fileparts(mfilename('fullpath'));
            testCase.applyFixture(PathFixture(fullfile(here, '..', 'matlab')));
            % The folder of the tests, for the package TestData.
            testCase.applyFixture(PathFixture(here));
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

        function verifyVariants(testCase, kind, name, from, tos, accepted, field)
            % The entry NAME of KIND with the text FROM of its JSON replaced
            % by each text of the cell TOS in turn is accepted (ACCEPTED
            % true) or rejected, naming FIELD in its message (FIELD empty:
            % any message). The replacements are texts of JSON.
            for k = 1:numel(tos)
                e = InputFixtureListTest.variant(kind, name, from, tos{k});
                if accepted
                    testCase.verifyAccepted({e}, false);
                elseif isempty(field)
                    testCase.verifyRejected({e}, false);
                else
                    testCase.verifyRejected({e}, false, field);
                end
            end
        end

        function makeFiles(testCase, paths)
            % Empty files at PATHS (relative to the current folder, which
            % the test has set to a folder of its own), the folders made.
            for k = 1:numel(paths)
                folder = fileparts(paths{k});
                if ~isempty(folder) && ~isfolder(folder)
                    mkdir(folder);
                end
                fid = fopen(paths{k}, 'w');
                testCase.assertGreaterThanOrEqual(fid, 0, paths{k});
                fclose(fid);
            end
        end

        function useFolder(testCase)
            % The temporary folder of the test as the current folder.
            import matlab.unittest.fixtures.CurrentFolderFixture
            testCase.applyFixture(CurrentFolderFixture(testCase.folder));
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
            % under upstream/ are left out: this test does not depend on
            % that checkout, and the validation of the references job checks
            % those files before any case runs.
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

        % ----- the kinds of the session, log and input set cases -----

        function testSessionAndLogEntriesAreAccepted(testCase)
            % Every entry of these kinds, as a manifest holds it (decoded
            % with jsondecode), alone and with the others of its kind. The
            % inputset entries are of the existing kind, whose optional
            % fields they use in every combination.
            for kind = {'logcalls', 'sessionfs', 'inputsetcall', ...
                    'inputsetwarnings', 'inputset', 'write'}
                entries = TestData.CaseEntries.decode( ...
                    TestData.CaseEntries.group(kind{1}));
                testCase.assertNotEmpty(entries, kind{1});
                for k = 1:numel(entries)
                    testCase.verifyAccepted(entries(k), false);
                end
                testCase.verifyAccepted(entries, false);
            end
        end

        function testEntryWithANulCharacterIsDecodedAndAccepted(testCase)
            % The JSON escape for a NUL in a name must decode to a char
            % array with a NUL in it (a manifest holding it is read by
            % jsondecode first), and the entry is accepted like the others.
            entries = TestData.CaseEntries.decode(TestData.CaseEntries.withNul());
            testCase.assertNumElements(entries, 1);
            testCase.assertEqual(entries{1}.dirName, ['a' char(0) 'b']);
            testCase.verifyAccepted(entries, false);
            testCase.verifyAccepted(entries, true);
        end

        function testEveryNewEntryIsAcceptedWithTheFileCheck(testCase)
            % All the entries together with the file check: the files they
            % name (found in their JSON text) exist in a folder of the test;
            % nothing else is looked for. Then each such file removed in
            % turn is the one reported (negative control: the check is
            % applied to the entries of every kind that names files).
            testCase.useFolder();
            lines = {};
            for kind = {'logcalls', 'sessionfs', 'inputsetcall', ...
                    'inputsetwarnings', 'inputset', 'write'}
                lines = [lines; TestData.CaseEntries.group(kind{1})]; %#ok<AGROW>
            end
            paths = {};
            for k = 1:numel(lines)
                paths = [paths, InputFixtureListTest.namedFilePaths(lines{k})]; %#ok<AGROW>
            end
            paths = unique(paths);
            % The entries name 17 different files (a count that keeps the
            % search of their text from finding nothing and passing).
            testCase.assertNumElements(paths, 17);
            testCase.makeFiles(paths);
            entries = TestData.CaseEntries.decode(lines);
            testCase.verifyAccepted(entries, true);
            for k = 1:numel(paths)
                delete(paths{k});
                [~, base, ext] = fileparts(paths{k});
                testCase.verifyRejected(entries, true, [base ext]);
                fid = fopen(paths{k}, 'w');
                fclose(fid);
            end
            testCase.verifyAccepted(entries, true);
        end

        function testMissingFieldOfANewKindIsRejected(testCase)
            % Each required field of each new kind, removed from an entry
            % that is accepted as it is, is reported by name.
            required = { ...
                'logcalls', 'ext_log_03', {'logmode', 'sessionName', 'calls'}; ...
                'sessionfs', 'ext_session_14', ...
                    {'logmode', 'dirName', 'overwrite', 'before', 'parent'}; ...
                'inputsetcall', 'ext_inputset_08', {'logmode', 'args'}; ...
                'inputsetwarnings', 'ext_inputset_23', {'logmode', 'capture'}};
            for k = 1:size(required, 1)
                e = TestData.CaseEntries.entry(required{k, 1}, required{k, 2});
                testCase.verifyAccepted({e}, false);
                for field = required{k, 3}
                    testCase.verifyRejected({rmfield(e, field{1})}, false, field{1});
                end
            end
        end

        function testInputsetwarningsInputsAreAllOptional(testCase)
            % model, options, geometry and bc of an inputsetwarnings entry
            % are each optional, as for the inputset kind: removed one at a
            % time or all together the entry is accepted (the required
            % logmode and capture are refused when removed, in
            % testMissingFieldOfANewKindIsRejected).
            e = TestData.CaseEntries.entry('inputsetwarnings', 'ext_inputset_23');
            testCase.verifyAccepted({e}, false);
            fields = {'model', 'options', 'geometry', 'bc'};
            for k = 1:numel(fields)
                testCase.assertTrue(isfield(e, fields{k}));
                testCase.verifyAccepted({rmfield(e, fields{k})}, false);
            end
            testCase.verifyAccepted({rmfield(e, fields)}, false);
        end

        function testOptionalFieldsOfANewKindMayBeAbsent(testCase)
            % bc of an inputsetwarnings entry is optional; exporterChange is
            % optional on every new kind (and accepted when present).
            e = TestData.CaseEntries.entry('inputsetwarnings', 'ext_inputset_23');
            testCase.assertTrue(isfield(e, 'bc'));
            testCase.verifyAccepted({rmfield(e, 'bc')}, false);
            samples = {'logcalls', 'ext_log_03'; 'sessionfs', 'ext_session_14'; ...
                'inputsetcall', 'ext_inputset_08'; ...
                'inputsetwarnings', 'ext_inputset_23'; 'write', 'ext_write_02'};
            for k = 1:size(samples, 1)
                e = TestData.CaseEntries.entry(samples{k, :});
                testCase.assertTrue(isfield(e, 'exporterChange'));
                testCase.verifyAccepted({rmfield(e, 'exporterChange')}, false);
                e.exporterChange = 'x';
                testCase.verifyAccepted({e}, false);
                e = rmfield(e, 'exporterChange');
                e.exporterchange = 'x';
                testCase.verifyRejected({e}, false, 'unknown field(s): exporterchange');
            end
        end

        function testExtraFieldOfANewKindIsRejected(testCase)
            samples = {'logcalls', 'ext_log_03'; 'sessionfs', 'ext_session_14'; ...
                'inputsetcall', 'ext_inputset_08'; ...
                'inputsetwarnings', 'ext_inputset_23'; 'write', 'ext_write_02'};
            for k = 1:size(samples, 1)
                e = TestData.CaseEntries.entry(samples{k, :});
                testCase.verifyAccepted({e}, false);
                e.extra = 'x';
                testCase.verifyRejected({e}, false, 'unknown field(s): extra');
            end
            % A misspelling of the optional field of inputsetwarnings.
            e = TestData.CaseEntries.entry('inputsetwarnings', 'ext_inputset_23');
            e = rmfield(e, 'bc');
            e.bcFile = 'cases/input-fixture/bc_unused.inp';
            testCase.verifyRejected({e}, false, 'unknown field(s): bcFile');
        end

        function testFieldsOfOtherKindsAreRejected(testCase)
            % A field that another kind uses is unknown on this one: the
            % tables of allowed fields are not shared between kinds.
            cases = { ...
                'logcalls', 'ext_log_03', 'dirName', 'run'; ...
                'logcalls', 'ext_log_03', 'args', []; ...
                'logcalls', 'ext_log_03', 'capture', 'console'; ...
                'sessionfs', 'ext_session_14', 'calls', []; ...
                'sessionfs', 'ext_session_14', 'sessionName', 's'; ...
                'sessionfs', 'ext_session_14', 'args', []; ...
                'inputsetcall', 'ext_inputset_08', 'capture', 'console'; ...
                'inputsetcall', 'ext_inputset_08', 'bc', 'x.inp'; ...
                'inputsetcall', 'ext_inputset_08', 'calls', []; ...
                'inputsetwarnings', 'ext_inputset_23', 'args', []; ...
                'inputsetwarnings', 'ext_inputset_23', 'calls', []; ...
                'inputsetwarnings', 'ext_inputset_23', 'overwrite', true; ...
                'inputset', 'ext_inputset_03', 'capture', 'console'; ...
                'write', 'ext_write_02', 'mode', 'w'; ...
                'write', 'ext_write_02', 'values', []};
            for k = 1:size(cases, 1)
                e = TestData.CaseEntries.entry(cases{k, 1}, cases{k, 2});
                testCase.verifyAccepted({e}, false);
                e.(cases{k, 3}) = cases{k, 4};
                testCase.verifyRejected({e}, false, ...
                    ['unknown field(s): ' cases{k, 3}]);
            end
        end

        function testMisspelledNewKindIsRejected(testCase)
            e = TestData.CaseEntries.entry('logcalls', 'ext_log_03');
            testCase.verifyAccepted({e}, false);
            for bad = {'logcall', 'Logcalls', 'sessionFs', 'inputsetcalls', ...
                    'inputset_warnings', 'ismembertolsweeps', 'ismembertolSweep'}
                e.kind = bad{1};
                testCase.verifyRejected({e}, false, 'unknown kind');
            end
        end

        function testLogcallsLogmodeAndSessionNameAreChecked(testCase)
            base = 'ext_log_03';
            from = '"logmode": "BOTH"';
            modes = {'NONE', 'LOGTOFILEONLY', 'LOGTOCONSOLEONLY', 'BOTH'};
            for k = 1:numel(modes)
                testCase.verifyVariants('logcalls', base, from, ...
                    {['"logmode": "' modes{k} '"']}, true, '');
            end
            % null means the log is not set up (one entry has it).
            testCase.verifyVariants('logcalls', base, from, {'"logmode": null'}, ...
                true, '');
            testCase.verifyVariants('logcalls', base, from, ...
                {'"logmode": "both"', '"logmode": "ALL"', '"logmode": 5', ...
                '"logmode": ""', '"logmode": true', '"logmode": ["BOTH"]'}, ...
                false, 'logmode');
            from = '"sessionName": "s"';
            testCase.verifyVariants('logcalls', base, from, ...
                {'"sessionName": null', '"sessionName": ""', '"sessionName": "a/b"'}, ...
                true, '');
            testCase.verifyVariants('logcalls', base, from, ...
                {'"sessionName": 5', '"sessionName": ["s"]', '"sessionName": true'}, ...
                false, 'sessionName');
        end

        function testLogcallsCallsAreChecked(testCase)
            base = 'ext_log_03';
            from = '"calls": [{"op": "warning", "args": ["Some:id", "some message"]}]';
            call = @(c) ['"calls": [' c ']'];
            % Accepted: no calls, one call per op (with no arguments), calls
            % in a struct array (same keys) and every form of argument.
            ops = {'log', 'warning', 'openLog', 'openLogKeep', 'closeLog', ...
                'readLog', 'readLogFilePath', 'removeFolder'};
            good = {'"calls": []'};
            for k = 1:numel(ops)
                good{end+1} = call(['{"op": "' ops{k} '", "args": []}']); %#ok<AGROW>
            end
            good{end+1} = call(['{"op": "log", "args": ["a\n"]},' ...
                '{"op": "log", "args": ["v=%d\n", {"double": ["3"]}]}']);
            good{end+1} = call('{"op": "log", "args": [{"double": ["3"]}]}');
            good{end+1} = call('{"op": "warning", "args": ["a", "b", "c"]}');
            good{end+1} = call('{"op": "warning", "args": [{"text": "a"}, "b"]}');
            testCase.verifyVariants('logcalls', base, from, good, true, '');
            % Rejected: an op that is not one of the eight, arguments that
            % are not texts or one-key arguments (a number given as a JSON
            % number included), a call without op or args or with another
            % key, and calls that are not a list of objects.
            bad = {call('{"op": "Log", "args": []}'), ...
                call('{"op": "write", "args": []}'), ...
                call('{"op": "", "args": []}'), ...
                call('{"op": 5, "args": []}'), ...
                call('{"op": "log", "args": [5]}'), ...
                call('{"op": "log", "args": [true]}'), ...
                call('{"op": "log", "args": [{"double": [3]}]}'), ...
                call('{"op": "log", "args": [{"double": ["3"], "text": "a"}]}'), ...
                call('{"op": "log", "args": [{"nosuchkey": "a"}]}'), ...
                call('{"op": "log", "args": [["a"]]}'), ...
                call('{"op": "log", "args": "abc"}'), ...
                call('{"op": "log", "args": 5}'), ...
                call('{"op": "log"}'), ...
                call('{"args": []}'), ...
                call('{"op": "log", "args": [], "mode": "w"}'), ...
                call('{"op": "log", "args": []}, 5'), ...
                call('5'), '"calls": "abc"', '"calls": 5'};
            testCase.verifyVariants('logcalls', base, from, bad, false, '');
        end

        function testSessionfsFieldsAreChecked(testCase)
            base = 'ext_session_14';
            modes = {'NONE', 'LOGTOFILEONLY', 'LOGTOCONSOLEONLY', 'BOTH'};
            testCase.verifyVariants('sessionfs', base, '"logmode": "BOTH"', ...
                cellfun(@(m) ['"logmode": "' m '"'], modes, 'UniformOutput', false), ...
                true, '');
            testCase.verifyVariants('sessionfs', base, '"logmode": "BOTH"', ...
                {'"logmode": "both"', '"logmode": 5', '"logmode": ""'}, ...
                false, 'logmode');
            befores = {'absent', 'folder', 'folderWithFile', 'file', 'ownLogOpen'};
            testCase.verifyVariants('sessionfs', base, '"before": "folder"', ...
                cellfun(@(m) ['"before": "' m '"'], befores, 'UniformOutput', false), ...
                true, '');
            testCase.verifyVariants('sessionfs', base, '"before": "folder"', ...
                {'"before": "Folder"', '"before": "nothing"', '"before": ""', ...
                '"before": 5', '"before": ["folder"]'}, false, 'before');
            parents = {'exists', 'missing', 'file', 'empty'};
            testCase.verifyVariants('sessionfs', base, '"parent": "exists"', ...
                cellfun(@(m) ['"parent": "' m '"'], parents, 'UniformOutput', false), ...
                true, '');
            testCase.verifyVariants('sessionfs', base, '"parent": "exists"', ...
                {'"parent": "gone"', '"parent": ""', '"parent": 5', ...
                '"parent": ["exists"]'}, false, 'parent');
            testCase.verifyVariants('sessionfs', base, '"overwrite": false', ...
                {'"overwrite": true'}, true, '');
            testCase.verifyVariants('sessionfs', base, '"overwrite": false', ...
                {'"overwrite": "false"', '"overwrite": 0', '"overwrite": null', ...
                '"overwrite": [true, false]'}, false, 'overwrite');
            testCase.verifyVariants('sessionfs', base, '"dirName": "run"', ...
                {'"dirName": ""', '"dirName": "a/b"', '"dirName": "<scratch>/target"'}, ...
                true, '');
            testCase.verifyVariants('sessionfs', base, '"dirName": "run"', ...
                {'"dirName": 5', '"dirName": ["run"]', '"dirName": true'}, ...
                false, 'dirName');
        end

        function testInputsetcallFieldsAreChecked(testCase)
            base = 'ext_inputset_14';
            modes = {'NONE', 'LOGTOFILEONLY', 'LOGTOCONSOLEONLY', 'BOTH'};
            testCase.verifyVariants('inputsetcall', base, '"logmode": "BOTH"', ...
                cellfun(@(m) ['"logmode": "' m '"'], modes, 'UniformOutput', false), ...
                true, '');
            testCase.verifyVariants('inputsetcall', base, '"logmode": "BOTH"', ...
                {'"logmode": "both"', '"logmode": 5', '"logmode": null'}, ...
                false, 'logmode');
            from = '"args": [["sessionName", "s"], ["sessionDirName", "run1"]]';
            % Accepted: one pair, a text value, a one-key value whose
            % numbers are texts (the entry with a number value), several
            % pairs.
            testCase.verifyVariants('inputsetcall', base, from, ...
                {'"args": [["sessionName", "s"]]', ...
                '"args": [["overwriteSessionFiles", {"double": ["1"]}]]', ...
                '"args": [["sessionName", "s"], ["modelID", {"double": ["5"]}], ["sessionDirName", ""]]'}, ...
                true, '');
            % Rejected: a pair of one or three items, a name that is not
            % text, a value that is a number, a JSON number in a one-key
            % value, a value with two keys, an element that is not a pair,
            % and args that are not a list.
            testCase.verifyVariants('inputsetcall', base, from, ...
                {'"args": [["sessionName"]]', ...
                '"args": [["sessionName", "s", "x"]]', ...
                '"args": [[5, "s"]]', ...
                '"args": [["sessionName", 5]]', ...
                '"args": [["sessionName", {"double": [1]}]]', ...
                '"args": [["sessionName", {"double": ["1"], "text": "a"}]]', ...
                '"args": ["sessionName"]', ...
                '"args": "abc"', '"args": 5'}, false, '');
        end

        function testASingleUnwrappedPairIsAPairInArgs(testCase)
            % args decoded as the cell {name; value} (one pair without the
            % list around it) is read as one pair, as the converter of the
            % write values reads it; a pair whose value is neither a text nor
            % a one-key argument, or whose name is not a text, is refused.
            e = TestData.CaseEntries.entry('inputsetcall', 'ext_inputset_14');
            e.args = {'sessionName'; 's'};
            testCase.verifyAccepted({e}, false);
            e.args = {'overwriteSessionFiles'; struct('double', {{'1'}})};
            testCase.verifyAccepted({e}, false);
            e.args = {'sessionName'; 5};
            testCase.verifyRejected({e}, false);
            e.args = {5; 's'};
            testCase.verifyRejected({e}, false);
            % As a file argument it is looked for with the file check.
            testCase.useFolder();
            e.args = {'bcFilePath'; 'cases/input-fixture/absent.inp'};
            testCase.verifyAccepted({e}, false);
            testCase.verifyRejected({e}, true, 'absent.inp');
        end

        function testInputsetwarningsFieldsAreChecked(testCase)
            base = 'ext_inputset_23';
            testCase.verifyVariants('inputsetwarnings', base, '"capture": "console"', ...
                {'"capture": "files"'}, true, '');
            testCase.verifyVariants('inputsetwarnings', base, '"capture": "console"', ...
                {'"capture": "Console"', '"capture": "both"', '"capture": ""', ...
                '"capture": 5', '"capture": ["console"]'}, false, 'capture');
            modes = {'NONE', 'LOGTOFILEONLY', 'LOGTOCONSOLEONLY', 'BOTH'};
            testCase.verifyVariants('inputsetwarnings', base, '"logmode": "NONE"', ...
                cellfun(@(m) ['"logmode": "' m '"'], modes, 'UniformOutput', false), ...
                true, '');
            testCase.verifyVariants('inputsetwarnings', base, '"logmode": "NONE"', ...
                {'"logmode": "none"', '"logmode": 0', '"logmode": null'}, ...
                false, 'logmode');
            % The files are named as in an inputset entry: [file, id]
            % pairs for the three inputs, a text for bc.
            for field = {'model', 'options', 'geometry'}
                e = TestData.CaseEntries.entry('inputsetwarnings', base);
                e.(field{1}) = 'cases/input-fixture/a.inp';
                testCase.verifyRejected({e}, false, field{1});
                e.(field{1}) = {'cases/input-fixture/a.inp'; 'ID'; 'extra'};
                testCase.verifyRejected({e}, false, field{1});
                e.(field{1}) = {'cases/input-fixture/a.inp'; 5};
                testCase.verifyRejected({e}, false, field{1});
            end
            e = TestData.CaseEntries.entry('inputsetwarnings', base);
            e.bc = {'cases/input-fixture/bc_unused.inp'};
            testCase.verifyRejected({e}, false, 'bc');
            e.bc = 5;
            testCase.verifyRejected({e}, false, 'bc');
        end

        function testInputsetwarningsFilesAreChecked(testCase)
            % With the file check, each file an inputsetwarnings entry names
            % (the three inputs and bc) must exist; without it none is
            % looked for. An entry without bc names three files.
            testCase.useFolder();
            e = TestData.CaseEntries.entry('inputsetwarnings', 'ext_inputset_23');
            paths = {e.model{1}, e.options{1}, e.geometry{1}, e.bc};
            names = {'models.inp', 'options.inp', 'geom.inp', 'bc_unused.inp'};
            testCase.makeFiles(paths);
            testCase.verifyAccepted({e}, true);
            for k = 1:numel(paths)
                delete(paths{k});
                testCase.verifyRejected({e}, true, names{k});
                testCase.verifyAccepted({e}, false);
                testCase.makeFiles(paths(k));
            end
            testCase.verifyAccepted({e}, true);
            noBc = rmfield(e, 'bc');
            delete(paths{4});
            testCase.verifyAccepted({noBc}, true);
        end

        function testInputsetcallFilesAreChecked(testCase)
            % The file arguments of an inputsetcall entry are checked with
            % the file check: the four *FilePath names, when the value is a
            % text that is not empty and holds no scratch marker. No other
            % argument is looked at, whatever its value looks like.
            testCase.useFolder();
            e = TestData.CaseEntries.entry('inputsetcall', 'ext_inputset_13');
            testCase.assertTrue(contains( ...
                TestData.CaseEntries.row('inputsetcall', 'ext_inputset_13'), ...
                '"bcFilePath", "upstream/openstream/inputs/tutorial1.inp"'));
            testCase.verifyRejected({e}, true, 'tutorial1.inp');
            testCase.verifyAccepted({e}, false);
            testCase.makeFiles({'upstream/openstream/inputs/tutorial1.inp'});
            testCase.verifyAccepted({e}, true);

            % Two file arguments in one entry: each is reported.
            e = TestData.CaseEntries.entry('inputsetcall', 'ext_inputset_19');
            geometry = 'cases/input-fixture/ext_bc_geometry_one.inp';
            bc = 'cases/input-fixture/ext_inputset_mesh.inp';
            testCase.verifyRejected({e}, true, 'ext_bc_geometry_one.inp');
            testCase.makeFiles({geometry});
            testCase.verifyRejected({e}, true, 'ext_inputset_mesh.inp');
            testCase.makeFiles({bc});
            testCase.verifyAccepted({e}, true);
            delete(geometry);
            testCase.verifyRejected({e}, true, 'ext_bc_geometry_one.inp');

            % The model and options file arguments are file arguments too.
            for name = {'modelFilePath', 'optionsFilePath', 'geometryFilePath', ...
                    'bcFilePath'}
                e = InputFixtureListTest.variant('inputsetcall', 'ext_inputset_14', ...
                    '["sessionDirName", "run1"]', ...
                    ['["' name{1} '", "cases/input-fixture/absent.inp"]']);
                testCase.verifyRejected({e}, true, 'absent.inp');
                testCase.verifyAccepted({e}, false);
            end

            % Exempt: a value with the scratch marker, an empty value, and
            % any argument that is not a file argument (a session name that
            % looks like a missing file, a parent folder, an identifier).
            exempt = {'ext_inputset_08', 'ext_inputset_09', 'ext_inputset_10', ...
                'ext_inputset_11', 'ext_inputset_12', 'ext_inputset_14', ...
                'ext_inputset_15', 'ext_inputset_16', 'ext_inputset_17', ...
                'ext_inputset_18'};
            for k = 1:numel(exempt)
                e = TestData.CaseEntries.entry('inputsetcall', exempt{k});
                testCase.verifyAccepted({e}, true);
            end
            e = InputFixtureListTest.variant('inputsetcall', 'ext_inputset_14', ...
                '["sessionName", "s"]', '["sessionName", "absent.inp"]');
            testCase.verifyAccepted({e}, true);
            e = InputFixtureListTest.variant('inputsetcall', 'ext_inputset_14', ...
                '["sessionName", "s"]', '["sessionParentDir", "absent_folder"]');
            testCase.verifyAccepted({e}, true);
        end

        function testKindsThatNameNoFilesAreNotChecked(testCase)
            % A text that looks like a missing file in a field that names
            % none is not looked for: logcalls, sessionfs and write entries
            % are accepted with the file check from an empty folder.
            testCase.useFolder();
            e = InputFixtureListTest.variant('logcalls', 'ext_log_03', ...
                '"sessionName": "s"', '"sessionName": "absent.inp"');
            testCase.verifyAccepted({e}, true);
            e = InputFixtureListTest.variant('sessionfs', 'ext_session_14', ...
                '"dirName": "run"', '"dirName": "absent.inp"');
            testCase.verifyAccepted({e}, true);
            e = InputFixtureListTest.variant('logcalls', 'ext_log_03', ...
                '"args": ["Some:id", "some message"]', '"args": ["absent.inp"]');
            testCase.verifyAccepted({e}, true);
            for name = {'ext_write_01', 'ext_write_02', 'ext_write_05', 'ext_write_06'}
                testCase.verifyAccepted( ...
                    {TestData.CaseEntries.entry('write', name{1})}, true);
            end
            % Control: the same folder does not hide a real missing file
            % (the other files the entry names are made, so the missing bc
            % file is the one reported).
            testCase.makeFiles({'upstream/openstream/inputs/models.inp', ...
                'upstream/openstream/inputs/options.inp', ...
                'upstream/openstream/inputs/geom.inp'});
            e = InputFixtureListTest.variant('inputsetwarnings', 'ext_inputset_23', ...
                '"bc": "cases/input-fixture/bc_unused.inp"', ...
                '"bc": "cases/input-fixture/absent.inp"');
            testCase.verifyRejected({e}, true, 'absent.inp');
        end

        function testInputsetEntriesWithFewFieldsAreAccepted(testCase)
            % The unrecorded inputset entries name between none and four
            % files (ext_inputset_03 only a log mode, ext_inputset_07 a
            % geometry and a boundary-condition file); with the file check
            % each file they name must exist.
            testCase.useFolder();
            none = TestData.CaseEntries.entry('inputset', 'ext_inputset_03');
            testCase.verifyAccepted({none}, true);
            two = TestData.CaseEntries.entry('inputset', 'ext_inputset_07');
            testCase.verifyRejected({two}, true, 'ext_bc_geometry_one.inp');
            testCase.makeFiles({'cases/input-fixture/ext_bc_geometry_one.inp'});
            testCase.verifyRejected({two}, true, 'ext_inputset_mesh.inp');
            testCase.makeFiles({'cases/input-fixture/ext_inputset_mesh.inp'});
            testCase.verifyAccepted({two}, true);
        end

        % ----- ismembertolsweep -----

        function testSweepEntriesAreAccepted(testCase)
            % Calls of decimal texts: several calls (a struct array), one
            % call (a struct), lists of one number (a cell of one text),
            % every spelling a number may have, and the optional note.
            twoCalls = ['[{"a":["1","2.5","NaN"],"b":["1.0005","Inf"],"tol":"0.001"},' ...
                '{"a":["-0","1e-12"],"b":["0"],"tol":"0"}]'];
            e = InputFixtureListTest.sweepEntry(twoCalls);
            testCase.verifyAccepted({e}, false);
            testCase.verifyAccepted({e}, true);
            e.exporterChange = 'x';
            testCase.verifyAccepted({e}, true);
            e = InputFixtureListTest.sweepEntry('[{"a":["1"],"b":["2"],"tol":"1"}]');
            testCase.verifyAccepted({e}, true);
            for spelling = {'NaN', 'Inf', '-Inf', '-0', '0', '1e-12', '0.5', '-3.25e+2'}
                call = sprintf('[{"a":["%s"],"b":["%s"],"tol":"%s"}]', ...
                    spelling{1}, spelling{1}, spelling{1});
                testCase.verifyAccepted({InputFixtureListTest.sweepEntry(call)}, false);
            end
            % Together with an entry of another kind.
            other = TestData.CaseEntries.entry('write', 'ext_write_01');
            testCase.verifyAccepted({other, InputFixtureListTest.sweepEntry(twoCalls)}, false);
        end

        function testSweepFieldsAreChecked(testCase)
            good = InputFixtureListTest.sweepEntry('[{"a":["1"],"b":["2"],"tol":"1"}]');
            testCase.verifyAccepted({good}, false);
            testCase.verifyRejected({rmfield(good, 'calls')}, false, 'calls');
            extra = good;
            extra.extra = 'x';
            testCase.verifyRejected({extra}, false, 'unknown field(s): extra');
            for field = {'a', 'values', 'file', 'class', 'lengths', 'tol'}
                extra = good;
                extra.(field{1}) = 'x';
                testCase.verifyRejected({extra}, false, ...
                    ['unknown field(s): ' field{1}]);
            end
        end

        function testSweepCallsAreChecked(testCase)
            call = '{"a":["1"],"b":["2"],"tol":"1"}';
            % Rejected: no calls, calls that are not a list of objects, a
            % call without a key or with another key, and the lists and the
            % tolerance of a call that are not lists of texts and a text.
            bad = {'[]', '"abc"', '5', '[5]', ...
                ['[' call ',5]'], ...
                '[{"b":["2"],"tol":"1"}]', ...
                '[{"a":["1"],"tol":"1"}]', ...
                '[{"a":["1"],"b":["2"]}]', ...
                '[{"a":["1"],"b":["2"],"tol":"1","mode":"w"}]', ...
                '[{"a":[1],"b":["2"],"tol":"1"}]', ...
                '[{"a":["1"],"b":[2],"tol":"1"}]', ...
                '[{"a":"1","b":["2"],"tol":"1"}]', ...
                '[{"a":["1"],"b":"2","tol":"1"}]', ...
                '[{"a":{"double":["1"]},"b":["2"],"tol":"1"}]', ...
                '[{"a":["1"],"b":{"double":["2"]},"tol":"1"}]', ...
                '[{"a":["1"],"b":["2"],"tol":1}]', ...
                '[{"a":["1"],"b":["2"],"tol":["1"]}]', ...
                '[{"a":["1"],"b":["2"],"tol":0.001}]'};
            for k = 1:numel(bad)
                testCase.verifyRejected({InputFixtureListTest.sweepEntry(bad{k})}, false);
            end
            % The same single change in the accepted call is accepted
            % again with the text spelled right (the neighbour of each pair).
            testCase.verifyAccepted({InputFixtureListTest.sweepEntry(['[' call ']'])}, false);
        end

        function testSweepDecimalTextsAreChecked(testCase)
            % Every text of a, b and tol must read as a number: str2double
            % of "abc", "" and "1x" is NaN, which is not the spelling NaN.
            for place = {'a', 'b', 'tol'}
                for bad = {'abc', '', '1x', 'one', '--1', '1..2'}
                    a = '["1"]';
                    b = '["2"]';
                    tol = '"1"';
                    switch place{1}
                        case 'a'
                            a = ['["' bad{1} '"]'];
                        case 'b'
                            b = ['["' bad{1} '"]'];
                        case 'tol'
                            tol = ['"' bad{1} '"'];
                    end
                    text = ['[{"a":' a ',"b":' b ',"tol":' tol '}]'];
                    testCase.verifyRejected({InputFixtureListTest.sweepEntry(text)}, ...
                        false);
                end
            end
            % A later text of a list is checked as well as the first.
            e = InputFixtureListTest.sweepEntry('[{"a":["1","abc"],"b":["2"],"tol":"1"}]');
            testCase.verifyRejected({e}, false);
            e = InputFixtureListTest.sweepEntry('[{"a":["1","2"],"b":["2"],"tol":"1"}]');
            testCase.verifyAccepted({e}, false);
        end

        % ----- the mode of a write call -----

        function testWriteModeIsAccepted(testCase)
            % The entries with a mode (w, a and r+ occur) and the
            % default, a+, spelled out; for the id classes and for
            % BoundaryConditions.
            for mode = {'w', 'a', 'r+', 'a+'}
                e = InputFixtureListTest.variant('write', 'ext_write_02', ...
                    '"mode": "w"', ['"mode": "' mode{1} '"']);
                testCase.verifyAccepted({e}, false);
            end
            for className = {'Model', 'Options', 'Geometry'}
                call = InputFixtureListTest.writeCall(className{1});
                call.mode = 'a';
                e = struct('name', 'w', 'kind', 'write', 'class', className{1}, ...
                    'calls', call);
                testCase.verifyAccepted({e}, false);
            end
            call = InputFixtureListTest.writeCall('BoundaryConditions');
            call.mode = 'r+';
            e = struct('name', 'w_bc', 'kind', 'write', ...
                'class', 'BoundaryConditions', 'calls', call);
            testCase.verifyAccepted({e}, false);
        end

        function testWriteModeIsChecked(testCase)
            % A mode that is not one of the four is refused, whatever its
            % type; so is a misspelling of the key. Each differs from an
            % accepted entry by the mode alone.
            testCase.verifyVariants('write', 'ext_write_02', '"mode": "w"', ...
                {'"mode": "x"', '"mode": ""', '"mode": "W"', '"mode": "r"', ...
                '"mode": 5', '"mode": ["w"]', '"mode": true', '"mode": null'}, ...
                false, 'mode');
            e = InputFixtureListTest.variant('write', 'ext_write_02', ...
                '"mode": "w"', '"fmode": "w"');
            testCase.verifyRejected({e}, false, 'fmode');
            call = InputFixtureListTest.writeCall('BoundaryConditions');
            call.mode = 'x';
            e = struct('name', 'w_bc', 'kind', 'write', ...
                'class', 'BoundaryConditions', 'calls', call);
            testCase.verifyRejected({e}, false, 'mode');
            call.mode = 'w';
            e.calls = call;
            testCase.verifyAccepted({e}, false);
        end

        function testWriteCallsWithAndWithoutModeAreAccepted(testCase)
            % Calls that do not all have a mode have different keys, so
            % jsondecode gives them as a cell, not a struct array; the
            % entry is accepted, and refused when one call has a bad mode.
            text = ['{"name":"w","kind":"write","class":"Geometry","calls":[' ...
                '{"id":"G","mode":"w","values":[["LENGTH",{"double":["5.5"]}]]},' ...
                '{"id":"G","values":[["LENGTH",{"double":["6"]}]]}]}'];
            e = jsondecode(text);
            testCase.assertClass(e.calls, 'cell');
            testCase.verifyAccepted({e}, false);
            bad = jsondecode(strrep(text, '"mode":"w"', '"mode":"x"'));
            testCase.verifyRejected({bad}, false, 'mode');
        end

    end

end
