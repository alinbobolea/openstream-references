classdef InputOverridesTest < matlab.unittest.TestCase
    %INPUTOVERRIDESTEST Unit tests for the functions that write input files
    % with overrides: formatInputValue, overrideInputEntry,
    % boundaryConditionLines, writeBoundaryConditions, prepareCaseInputs and
    % requireOverridesUsed.
    %
    % The files they write are read back here with the line rule of upstream's
    % .inp reader (the regular expression of Inputs.Input.readInputFile,
    % copied in parseLines), so that "the solver would read the value that was
    % meant" is a test, not a belief.

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
            testCase.folder = testCase.applyFixture(TemporaryFolderFixture).Folder;
        end

    end

    methods (Static)

        function entries = parseLines(lines)
            % The entries of an .inp file as upstream's reader reads the lines:
            % a cell array of structs, the values numeric (textscan %f) or text.
            expression = '(?<PARAMETER>(end|END))|(?<PARAMETER>(#|\/\/|%)).*|(?<PARAMETER>[\w]+)?\s*\!\s*(?<DESC>.*?)>\s*"*(?<VALUE>[@><=&|()\/\*\[\],\w\s\+\-\.]*)?"*';
            found = regexpi(cellstr(lines), expression, 'names');
            entries = {};
            current = struct();
            for k = 1:numel(found)
                row = found{k};
                if isempty(row)
                    continue
                end
                if strcmpi(row.PARAMETER, 'END')
                    entries{end+1} = current; %#ok<AGROW>
                    current = struct();
                    continue
                end
                value = row.VALUE;
                numbers = textscan(value, '%f');
                numbers = numbers{1};
                if ~isempty(numbers)
                    current.(row.PARAMETER) = numbers;
                else
                    current.(row.PARAMETER) = value;
                end
            end
        end

        function lines = trimmed(lines)
            % LINES without the empty lines at the end (whether readlines
            % returns one for the last line break does not matter here).
            last = find(lines ~= "", 1, 'last');
            lines = lines(1:last);
        end

        function writeBase(file)
            % Two entries, as upstream's models.inp has them.
            lines = [ ...
                "ID            ! Model ID                                                   > FIRST"
                "NNODES        ! Number of axial nodes                                      > 100"
                "VOID          ! Void fraction model                                        > SLIP"
                "RELAXX        ! Relaxation time Xeq [-]                                    > -0.5 1.0"
                "END"
                ""
                "ID            ! Model ID                                                   > SECOND"
                "NNODES        ! Number of axial nodes                                      > 50"
                "END"
                ""];
            writelines(lines, file);
        end

    end

    methods (Test)

        % ---- formatInputValue ----

        function testNumbersKeepAllDigits(testCase)
            for value = [0.1, 1/3, 1e-13, 123456789.123456789, -2.5e10, 100, 0]
                text = formatInputValue(value);
                testCase.verifyEqual(str2double(text), value, ...
                    sprintf('%.17g', value));
            end
        end

        function testNumericArrayIsWrittenInColumnOrderWithSpaces(testCase)
            testCase.verifyEqual(formatInputValue([1 2; 3 4]), "1 3 2 4");
            testCase.verifyEqual(formatInputValue([-0.5; 1]), "-0.5 1");
        end

        function testNonNumbersAreRefused(testCase)
            for bad = {[], NaN, Inf, -Inf, 1+2i, {1}, struct(), @sin}
                value = bad{1};
                testCase.verifyError(@() formatInputValue(value), ...
                    'References:InvalidOverride');
            end
        end

        function testLogicalAndTextValues(testCase)
            testCase.verifyEqual(formatInputValue([true false]), "TRUE FALSE");
            testCase.verifyEqual(formatInputValue('  BESTION '), "BESTION");
            testCase.verifyEqual(formatInputValue("ELEVATION"), "ELEVATION");
            % A function text keeps its characters while the reader keeps them: its
            % character class has no ^ (so x.^2 is refused, below).
            testCase.verifyEqual(formatInputValue('@(x) x.*2 + 1'), "@(x) x.*2 + 1");
        end

        function testTextThatTheReaderWouldDropIsRefused(testCase)
            for bad = {'', '   ', 'a;b', 'a"b', 'a!b', '@(x) x.^2', ['ab'; 'cd'], ["a" "b"]}
                testCase.verifyError(@() formatInputValue(bad{1}), ...
                    'References:InvalidOverride');
            end
        end

        % ---- overrideInputEntry ----

        function testChangedKeyAndNewIDAreRead_OthersAreUnchanged(testCase)
            base = fullfile(testCase.folder, 'models.inp');
            InputOverridesTest.writeBase(base);
            out = fullfile(testCase.folder, 'out.inp');

            overrideInputEntry(base, "FIRST", struct('NNODES', 37), out, "NEWCASE");

            entries = InputOverridesTest.parseLines(readlines(out));
            testCase.assertSize(entries, [1 1], 'one entry is written');
            e = entries{1};
            testCase.verifyEqual(strtrim(e.ID), 'NEWCASE');
            testCase.verifyEqual(e.NNODES, 37);
            testCase.verifyEqual(strtrim(e.VOID), 'SLIP');
            testCase.verifyEqual(e.RELAXX, [-0.5; 1]);
            testCase.verifyEqual(sort(fieldnames(e))', sort({'ID', 'NNODES', 'VOID', 'RELAXX'}));
        end

        function testTextAfterTheArrowIsTheOnlyChange(testCase)
            base = fullfile(testCase.folder, 'models.inp');
            InputOverridesTest.writeBase(base);
            out = fullfile(testCase.folder, 'out.inp');
            overrideInputEntry(base, "FIRST", struct('VOID', "BESTION"), out, "X");
            written = InputOverridesTest.trimmed(readlines(out));
            original = readlines(base);
            % Same lines except the ID line and the VOID line, which keep
            % their key and description.
            testCase.verifyEqual(numel(written), 5);
            testCase.verifyEqual(written(2), original(2));
            testCase.verifyEqual(written(4), original(4));
            testCase.verifyEqual(extractBefore(written(1), '>'), extractBefore(original(1), '>'));
            testCase.verifyEqual(extractBefore(written(3), '>'), extractBefore(original(3), '>'));
            testCase.verifyEqual(strtrim(extractAfter(written(3), '>')), "BESTION");
            testCase.verifyEqual(written(5), "END");
        end

        function testKeyThatIsNotInTheEntryIsAdded(testCase)
            base = fullfile(testCase.folder, 'models.inp');
            InputOverridesTest.writeBase(base);
            out = fullfile(testCase.folder, 'out.inp');
            overrideInputEntry(base, "FIRST", struct('NEWKEY', [1.5 2.5]), out, "X");
            e = InputOverridesTest.parseLines(readlines(out));
            testCase.verifyEqual(e{1}.NEWKEY, [1.5; 2.5]);
            testCase.verifyEqual(e{1}.NNODES, 100);
            lines = InputOverridesTest.trimmed(readlines(out));
            testCase.verifyEqual(lines(end), "END");
            testCase.verifySubstring(lines(end-1), 'NEWKEY', ...
                'the new line is inside the entry, just before END');
        end

        function testKeyCaseDoesNotMatter(testCase)
            base = fullfile(testCase.folder, 'models.inp');
            InputOverridesTest.writeBase(base);
            out = fullfile(testCase.folder, 'out.inp');
            overrideInputEntry(base, "first", struct('nnodes', 12), out, "X");
            e = InputOverridesTest.parseLines(readlines(out));
            testCase.verifyEqual(e{1}.NNODES, 12);
            testCase.verifyFalse(isfield(e{1}, 'nnodes'));
        end

        function testSecondEntryOfTheFileIsFoundAndTheFirstIsNotCopied(testCase)
            base = fullfile(testCase.folder, 'models.inp');
            InputOverridesTest.writeBase(base);
            out = fullfile(testCase.folder, 'out.inp');
            overrideInputEntry(base, "SECOND", struct(), out, "X");
            e = InputOverridesTest.parseLines(readlines(out));
            testCase.assertSize(e, [1 1]);
            testCase.verifyEqual(e{1}.NNODES, 50);
            testCase.verifyFalse(isfield(e{1}, 'VOID'));
        end

        function testBaseFileIsNotChanged(testCase)
            base = fullfile(testCase.folder, 'models.inp');
            InputOverridesTest.writeBase(base);
            before = fileread(base);
            overrideInputEntry(base, "FIRST", struct('NNODES', 1), ...
                fullfile(testCase.folder, 'out.inp'), "X");
            testCase.verifyEqual(fileread(base), before);
        end

        function testOverrideProblemsAreRejected(testCase)
            base = fullfile(testCase.folder, 'models.inp');
            InputOverridesTest.writeBase(base);
            out = fullfile(testCase.folder, 'out.inp');
            id = 'References:InvalidOverride';
            testCase.verifyError(@() overrideInputEntry(base, "NOSUCH", struct(), out, "X"), id);
            testCase.verifyError(@() overrideInputEntry(base, "FIRST", struct('ID', 'Y'), out, "X"), id);
            testCase.verifyError(@() overrideInputEntry(base, "FIRST", ...
                struct('a', 1, 'A', 2), out, "X"), id);
            testCase.verifyError(@() overrideInputEntry(base, "FIRST", ...
                struct('NNODES', NaN), out, "X"), id);
            testCase.verifyError(@() overrideInputEntry(base, "FIRST", struct(), out, "BAD;ID"), id);
            other = fullfile(testCase.folder, 'models.json');
            writelines("[]", other);
            testCase.verifyError(@() overrideInputEntry(other, "FIRST", struct(), out, "X"), id);
        end

        function testEntryWithoutEndIsRejected(testCase)
            base = fullfile(testCase.folder, 'models.inp');
            writelines(["ID    ! Model ID    > LAST"; "NNODES    ! n    > 3"], base);
            testCase.verifyError(@() overrideInputEntry(base, "LAST", struct(), ...
                fullfile(testCase.folder, 'out.inp'), "X"), 'References:InvalidOverride');
        end

        % ---- boundary conditions ----

        function testBoundaryConditionEntriesAreWrittenInOrderAndRead(testCase)
            entries = [ ...
                struct('TIME', 0, 'PRESSURE', 6e6, 'HIN', 1.1394e6, 'MFLOW', 0.07, ...
                    'POWER', 87500, 'WMESH', [3.5 2.0], 'WPOWER', [1.0 0.0]), ...
                struct('TIME', 10, 'PRESSURE', 6.1e6, 'HIN', 1.2e6, 'MFLOW', 0.08, ...
                    'POWER', 90000, 'WMESH', [3.5 2.0], 'WPOWER', [0.5 0.5])];
            file = fullfile(testCase.folder, 'bc.inp');
            writeBoundaryConditions(entries, file);
            read = InputOverridesTest.parseLines(readlines(file));
            testCase.assertSize(read, [1 2]);
            testCase.verifyEqual(read{1}.TIME, 0);
            testCase.verifyEqual(read{2}.TIME, 10);
            testCase.verifyEqual(read{1}.PRESSURE, 6e6);
            testCase.verifyEqual(read{2}.WPOWER, [0.5; 0.5]);
            testCase.verifyEqual(read{1}.WMESH, [3.5; 2]);
            testCase.verifyEqual(fieldnames(read{1})', ...
                {'TIME', 'PRESSURE', 'HIN', 'MFLOW', 'POWER', 'WMESH', 'WPOWER'});
        end

        function testCellArrayOfEntriesIsAccepted(testCase)
            a = struct('TIME', 0, 'PRESSURE', 6e6, 'HIN', 1e6, 'MFLOW', 1);
            b = struct('TIME', 1, 'PRESSURE', 6e6, 'HIN', 1e6, 'MFLOW', 1, 'POWER', 5);
            lines = boundaryConditionLines({a, b});
            read = InputOverridesTest.parseLines(lines);
            testCase.verifySize(read, [1 2]);
            testCase.verifyEqual(read{2}.POWER, 5);
            testCase.verifyFalse(isfield(read{1}, 'POWER'));
        end

        function testBoundaryConditionProblemsAreRejected(testCase)
            id = 'References:InvalidOverride';
            ok = struct('TIME', 0, 'PRESSURE', 6e6, 'HIN', 1e6, 'MFLOW', 1);
            testCase.verifyError(@() boundaryConditionLines(struct([])), id);
            testCase.verifyError(@() boundaryConditionLines({}), id);
            testCase.verifyError(@() boundaryConditionLines(5), id);
            testCase.verifyError(@() boundaryConditionLines({5}), id);
            testCase.verifyError(@() boundaryConditionLines(rmfield(ok, 'MFLOW')), id);
            twice = ok;
            twice.time = 1;
            testCase.verifyError(@() boundaryConditionLines(twice), id);
            bad = ok;
            bad.POWER = Inf;
            testCase.verifyError(@() boundaryConditionLines(bad), id);
        end

        % ---- prepareCaseInputs ----

        function testCaseWithoutOverridesUsesTheUpstreamFiles(testCase)
            c = InputOverridesTest.caseWith(struct());
            prepared = prepareCaseInputs(c, string(testCase.folder), ...
                string(fullfile(testCase.folder, 'case')));
            testCase.verifyEqual(prepared.modelFilePath, fullfile(testCase.folder, 'models.inp'));
            testCase.verifyEqual(prepared.modelID, 'FIRST');
            testCase.verifyEqual(prepared.optionsFilePath, fullfile(testCase.folder, 'options.inp'));
            testCase.verifyEqual(prepared.geometryFilePath, fullfile(testCase.folder, 'geom.inp'));
            testCase.verifyEqual(prepared.bcFilePath, fullfile(testCase.folder, 'bc.inp'));
            testCase.verifyEqual(fieldnames(prepared.overrides), cell(0, 1));
            testCase.verifyFalse(isfolder(fullfile(testCase.folder, 'case')), ...
                'nothing is written when there is nothing to override');
        end

        function testCaseWithOverridesGetsFilesWrittenForIt(testCase)
            InputOverridesTest.writeBase(fullfile(testCase.folder, 'models.inp'));
            c = InputOverridesTest.caseWith(struct( ...
                'model', struct('NNODES', 21), ...
                'boundaryConditions', struct('TIME', 0, 'PRESSURE', 6e6, ...
                    'HIN', 1e6, 'MFLOW', 1)));
            caseFolder = fullfile(testCase.folder, 'case');
            prepared = prepareCaseInputs(c, string(testCase.folder), string(caseFolder));

            testCase.verifyEqual(prepared.modelFilePath, fullfile(caseFolder, 'models.inp'));
            testCase.verifyEqual(prepared.modelID, 'MYCASE');
            e = InputOverridesTest.parseLines(readlines(prepared.modelFilePath));
            testCase.verifyEqual(e{1}.NNODES, 21);
            testCase.verifyEqual(strtrim(e{1}.ID), 'MYCASE');
            % Kinds without an override keep the upstream file and ID.
            testCase.verifyEqual(prepared.optionsFilePath, fullfile(testCase.folder, 'options.inp'));
            testCase.verifyEqual(prepared.optionsID, 'OPT');
            testCase.verifyEqual(prepared.geometryID, 'GEO');
            testCase.verifyEqual(prepared.bcFilePath, fullfile(caseFolder, 'bc.inp'));
            testCase.verifyTrue(isfile(prepared.bcFilePath));
            testCase.verifyEqual(fieldnames(prepared.overrides), {'model'});
            testCase.verifyEqual(prepared.overrides.model.NNODES, 21);
        end

        function testEmptyOverrideStructChangesNothing(testCase)
            c = InputOverridesTest.caseWith(struct('model', struct()));
            prepared = prepareCaseInputs(c, string(testCase.folder), ...
                string(fullfile(testCase.folder, 'case')));
            testCase.verifyEqual(prepared.modelFilePath, fullfile(testCase.folder, 'models.inp'));
            testCase.verifyEqual(fieldnames(prepared.overrides), cell(0, 1));
        end

        % ---- requireOverridesUsed ----

        function testOverrideThatUpstreamIgnoredIsReported(testCase)
            inputSet = struct( ...
                'model', struct('extra', struct('TYPOKEY', 3)), ...
                'options', struct('extra', struct.empty()), ...
                'geometry', struct('extra', struct.empty()));
            overrides = struct('model', struct('typokey', 1, 'NNODES', 5));
            testCase.verifyError(@() requireOverridesUsed(inputSet, overrides), ...
                'References:OverrideIgnored');
            try
                requireOverridesUsed(inputSet, overrides);
            catch err
                testCase.verifySubstring(err.message, 'TYPOKEY');
                testCase.verifySubstring(err.message, 'model');
            end
        end

        function testExtrasThatTheCaseDidNotOverrideAreIgnored(testCase)
            % The base entry may have unused keys of its own.
            inputSet = struct( ...
                'model', struct('extra', struct('OLDKEY', 3)), ...
                'options', struct('extra', struct.empty()), ...
                'geometry', struct('extra', struct.empty()));
            overrides = struct('model', struct('NNODES', 5));
            testCase.verifyWarningFree(@() requireOverridesUsed(inputSet, overrides));
            testCase.verifyWarningFree(@() requireOverridesUsed(inputSet, struct()));
        end

        function testEveryKindIsChecked(testCase)
            for kind = ["model" "options" "geometry"]
                inputSet = struct( ...
                    'model', struct('extra', struct.empty()), ...
                    'options', struct('extra', struct.empty()), ...
                    'geometry', struct('extra', struct.empty()));
                inputSet.(kind).extra = struct('BADKEY', 1);
                overrides = struct();
                overrides.(kind) = struct('BADKEY', 2);
                testCase.verifyError(@() requireOverridesUsed(inputSet, overrides), ...
                    'References:OverrideIgnored', char(kind));
            end
        end

    end

    methods (Static, Access = private)

        function c = caseWith(extra)
            % A case entry whose files are in the test folder.
            c = struct('name', 'MyCase', 'solver', 'S', ...
                'modelFile', 'models.inp', 'modelID', 'FIRST', ...
                'optionsFile', 'options.inp', 'optionsID', 'OPT', ...
                'geometryFile', 'geom.inp', 'geometryID', 'GEO', ...
                'bcFile', 'bc.inp');
            for name = reshape(string(fieldnames(extra)), 1, [])
                c.(name) = extra.(name);
            end
        end

    end

end
