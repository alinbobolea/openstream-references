classdef FunctionCallTest < matlab.unittest.TestCase
    %FUNCTIONCALLTEST Unit tests for functionCall, the call an upper,
    % sprintf, num2str or strcat case makes.
    %
    % Each test checks the function, the class, size and value of every
    % argument, and the store function, so a call that passes a double for
    % a uint8, a char for a string, a row for a column or an extra format
    % fails without depending on what MATLAB returns for the call itself.
    % Entries are built as jsondecode returns them (a JSON list of texts
    % is a column cell of char, [] an empty double). Each rejected entry
    % differs by one field from an accepted one.

    methods (TestClassSetup)

        function addPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            here = fileparts(mfilename('fullpath'));
            testCase.applyFixture(PathFixture(fullfile(here, '..', 'matlab')));
        end

    end

    methods (Static)

        function e = upperEntry(as)
            e = struct('name', 'up', 'kind', 'upper', 'text', 'ab', 'as', as);
        end

        function e = num2strEntry(values, fmt)
            e = struct('name', 'n2s', 'kind', 'num2str', 'values', values, ...
                'format', fmt);
        end

        function spec = doubles(texts)
            spec = struct('double', {texts});
        end

        function e = sprintfEntry(fmt, args)
            e = struct('name', 'spf', 'kind', 'sprintf', 'format', fmt, ...
                'args', {args});
        end

        function entries = manifestEntries()
            % The entries of cases/input-fixture.json, as a 1xN cell.
            here = fileparts(mfilename('fullpath'));
            manifest = fullfile(here, '..', 'cases', 'input-fixture.json');
            entries = FixtureArguments.list(jsondecode(fileread(manifest)));
        end

        function e = entryNamed(entries, name)
            names = cellfun(@(x) char(x.name), entries, 'UniformOutput', false);
            index = find(strcmp(names, name));
            if numel(index) ~= 1
                error('FunctionCallTest:noEntry', 'No single entry named %s', name);
            end
            e = entries{index};
        end

        function id = argumentError(e)
            % The identifier of the error raised by the code exportInputFixture
            % runs for entry E ('' when none): runFunctionCase and
            % runNumberCase for their kinds, FixtureArguments.writeArguments
            % for each call of a write case (the writeInputFile calls
            % themselves need OpenSTREAM). Other kinds need OpenSTREAM or
            % convert nothing that can raise the fixture's error (the
            % inputset pairs only go through FixtureArguments.list; their
            % shape is checked by validateInputFixtureList) and are skipped.
            id = '';
            try
                switch char(e.kind)
                    case {'upper', 'sprintf', 'num2str', 'strcat'}
                        runFunctionCase(e);
                    case {'handle', 'ismembertol', 'uint8', 'sum'}
                        runNumberCase(e);
                    case 'write'
                        calls = FixtureArguments.list(e.calls);
                        for k = 1:numel(calls)
                            FixtureArguments.writeArguments(e.class, calls{k});
                        end
                end
            catch err
                id = err.identifier;
            end
        end

        function out = outcome(f)
            % {true, value} when F returns, {false, error identifier} when
            % it errors.
            try
                out = {true, f()};
            catch err
                out = {false, err.identifier};
            end
        end

        function stored = storedCases()
            % The cases of results/input-fixture/input_fixture.mat.
            here = fileparts(mfilename('fullpath'));
            matFile = fullfile(here, '..', 'results', 'input-fixture', 'input_fixture.mat');
            loaded = load(matFile, 'fixture');
            stored = loaded.fixture.cases;
        end

        function tf = reproduces(e, c)
            % True when entry E, run through the function the exporter runs
            % for its kind (runFunctionCase or runNumberCase), gives the
            % outcome of the stored case C: its result when C.ok, else its
            % error identifier. Values compare with isequaln (stored results
            % hold NaN, e.g. @(z) NaN*z; classes are kept by describeValue's
            % class fields, and the other results are char) and with the
            % sign of every zero (sameZeroSigns).
            if ismember(e.kind, {'upper', 'sprintf', 'num2str', 'strcat'})
                actual = FunctionCallTest.outcome(@() runFunctionCase(e));
            else
                actual = FunctionCallTest.outcome(@() runNumberCase(e));
            end
            if c.ok
                expected = {true, c.result};
            else
                expected = {false, c.errorId};
            end
            tf = isequaln(actual, expected) ...
                && FunctionCallTest.sameZeroSigns(actual, expected);
        end

        function tf = sameZeroSigns(a, b)
            % True when every zero of the floating-point values in A is a
            % zero of the same sign in B, walking structs and cells. NaN is
            % not compared (isequaln treats every NaN as equal); values of
            % other classes are left to isequaln.
            if isstruct(a) && isstruct(b)
                names = fieldnames(a);
                tf = isequal(size(a), size(b)) && isequal(sort(names), sort(fieldnames(b)));
                for k = 1:numel(a)
                    for j = 1:numel(names)
                        tf = tf && FunctionCallTest.sameZeroSigns( ...
                            a(k).(names{j}), b(k).(names{j}));
                    end
                end
            elseif iscell(a) && iscell(b)
                tf = isequal(size(a), size(b));
                for k = 1:numel(a)
                    tf = tf && FunctionCallTest.sameZeroSigns(a{k}, b{k});
                end
            elseif isfloat(a) && isfloat(b)
                tf = isequal(size(a), size(b)) ...
                    && FunctionCallTest.sameSigns(real(a), real(b)) ...
                    && FunctionCallTest.sameSigns(imag(a), imag(b));
            else
                tf = true;
            end
        end

        function tf = sameSigns(a, b)
            % A and B (real, same size) have zeros at the same places, with
            % the same signs (1/-0 is -Inf).
            za = a == 0;
            zb = b == 0;
            tf = isequal(za, zb) && isequal(1 ./ a(za) < 0, 1 ./ b(zb) < 0);
        end

    end

    methods

        function verifyCall(testCase, call, fnName, args, storeName)
            % The function, every argument (value and class) and the store.
            testCase.verifyEqual(func2str(call.fn), fnName);
            testCase.assertEqual(size(call.args), size(args));
            for k = 1:numel(args)
                testCase.verifyClass(call.args{k}, class(args{k}), ...
                    sprintf('argument %d', k));
                testCase.verifyEqual(call.args{k}, args{k}, ...
                    sprintf('argument %d', k));
            end
            testCase.verifyEqual(func2str(call.store), storeName);
        end

        function verifyRejected(testCase, e)
            testCase.verifyError(@() functionCall(e), ...
                'References:InvalidInputFixture');
        end

    end

    methods (Test)

        function testUpperCharAndString(testCase)
            testCase.verifyCall(functionCall(FunctionCallTest.upperEntry('char')), ...
                'upper', {'ab'}, 'describeValue');
            testCase.verifyCall(functionCall(FunctionCallTest.upperEntry('string')), ...
                'upper', {"ab"}, 'describeValue');
        end

        function testUpperDouble(testCase)
            e = FunctionCallTest.upperEntry('double');
            e.values = FunctionCallTest.doubles({'1'; '2'});
            testCase.verifyCall(functionCall(e), 'upper', {[1 2]}, 'describeValue');
        end

        function testUpperUint8(testCase)
            e = FunctionCallTest.upperEntry('uint8');
            e.values = struct('uint8', {{'1'}});
            testCase.verifyCall(functionCall(e), 'upper', {uint8(1)}, 'describeValue');
        end

        function testUpperTextscan(testCase)
            % The argument is what textscan itself returns for the text.
            e = FunctionCallTest.upperEntry('textscan');
            e.text = '1 2';
            scanned = textscan("1 2", '%f');
            testCase.verifyCall(functionCall(e), 'upper', scanned(1), 'describeValue');
        end

        function testUpperRejections(testCase)
            testCase.verifyRejected(FunctionCallTest.upperEntry('number'));
            e = FunctionCallTest.upperEntry('double');
            testCase.verifyRejected(e);
            e = FunctionCallTest.upperEntry('uint8');
            testCase.verifyRejected(e);
            e.values = FunctionCallTest.doubles({'1'});
            testCase.verifyRejected(e);
        end

        function testSprintfCharFormat(testCase)
            e = FunctionCallTest.sprintfEntry('%d %s', ...
                {struct('double', {{'1'}}); struct('text', 'a')});
            testCase.verifyCall(functionCall(e), 'sprintf', {'%d %s', 1, 'a'}, 'toPlain');
        end

        function testSprintfNoArguments(testCase)
            e = FunctionCallTest.sprintfEntry('%d', []);
            testCase.verifyCall(functionCall(e), 'sprintf', {'%d'}, 'toPlain');
        end

        function testSprintfStringFormat(testCase)
            e = FunctionCallTest.sprintfEntry('x%s', struct('text', 'a'));
            e.formatClass = 'string';
            testCase.verifyCall(functionCall(e), 'sprintf', {"x%s", 'a'}, 'describeValue');
        end

        function testSprintfUint8AndMatrixArguments(testCase)
            e = FunctionCallTest.sprintfEntry('%f %f', ...
                {struct('uint8', {{'100'}}); FunctionCallTest.doubles({'2.5'})});
            testCase.verifyCall(functionCall(e), 'sprintf', ...
                {'%f %f', uint8(100), 2.5}, 'toPlain');
            matrix = struct('matrix', struct('rows', 2, 'double', {{'1'; '3'; '2'; '4'}}));
            e = FunctionCallTest.sprintfEntry('%d,', matrix);
            testCase.verifyCall(functionCall(e), 'sprintf', {'%d,', [1 2; 3 4]}, 'toPlain');
        end

        function testSprintfRejections(testCase)
            e = FunctionCallTest.sprintfEntry('%d', []);
            e.formatClass = 'char';
            testCase.verifyRejected(e);
            e.formatClass = 5;
            testCase.verifyRejected(e);
            e = FunctionCallTest.sprintfEntry('%d', struct('number', 1));
            testCase.verifyRejected(e);
        end

        function testNum2strWithFormat(testCase)
            e = FunctionCallTest.num2strEntry( ...
                FunctionCallTest.doubles({'1'; '2'}), '%.11f ');
            testCase.verifyCall(functionCall(e), 'num2str', {[1 2], '%.11f '}, 'toPlain');
        end

        function testNum2strEmptyFormatPassesValueAlone(testCase)
            e = FunctionCallTest.num2strEntry( ...
                FunctionCallTest.doubles({'1'; '2'; '3'}), '');
            testCase.verifyCall(functionCall(e), 'num2str', {[1 2 3]}, 'toPlain');
        end

        function testNum2strColumn(testCase)
            e = FunctionCallTest.num2strEntry( ...
                FunctionCallTest.doubles({'1'; '2'}), '%.11f ');
            e.shape = 'column';
            testCase.verifyCall(functionCall(e), 'num2str', {[1; 2], '%.11f '}, 'toPlain');
            e.shape = 'row';
            testCase.verifyCall(functionCall(e), 'num2str', {[1 2], '%.11f '}, 'toPlain');
        end

        function testNum2strUint8(testCase)
            e = FunctionCallTest.num2strEntry( ...
                FunctionCallTest.doubles({'100'}), '%.11f ');
            e.valuesClass = 'uint8';
            testCase.verifyCall(functionCall(e), 'num2str', ...
                {uint8(100), '%.11f '}, 'toPlain');
        end

        function testNum2strText(testCase)
            e = FunctionCallTest.num2strEntry(struct('text', 'a b'), '');
            testCase.verifyCall(functionCall(e), 'num2str', {'a b'}, 'toPlain');
            e = FunctionCallTest.num2strEntry(struct('text', ''), '');
            testCase.verifyCall(functionCall(e), 'num2str', {''}, 'toPlain');
        end

        function testNum2strStringText(testCase)
            e = FunctionCallTest.num2strEntry(struct('text', 'X'), '');
            e.valuesClass = 'string';
            testCase.verifyCall(functionCall(e), 'num2str', {"X"}, 'describeValue');
        end

        function testNum2strStringFormat(testCase)
            e = FunctionCallTest.num2strEntry( ...
                FunctionCallTest.doubles({'1'}), '%.11f ');
            e.formatClass = 'string';
            testCase.verifyCall(functionCall(e), 'num2str', {1, "%.11f "}, 'describeValue');
        end

        function testNum2strRejections(testCase)
            values = FunctionCallTest.doubles({'1'});
            textValues = struct('text', 'a');
            bad = {FunctionCallTest.num2strEntry(textValues, '%d'), ...
                FunctionCallTest.num2strEntry(struct('logical', true), ''), ...
                FunctionCallTest.num2strEntry(struct('double', {{'1'}}, 'text', 'a'), '')};
            e = FunctionCallTest.num2strEntry(values, '%d');
            e.valuesClass = 'string';
            bad{end+1} = e;
            e = FunctionCallTest.num2strEntry(textValues, '');
            e.valuesClass = 'uint8';
            bad{end+1} = e;
            e = FunctionCallTest.num2strEntry(values, '%d');
            e.shape = 'diagonal';
            bad{end+1} = e;
            e = FunctionCallTest.num2strEntry(textValues, '');
            e.shape = 'column';
            bad{end+1} = e;
            e = FunctionCallTest.num2strEntry(values, '');
            e.formatClass = 'string';
            bad{end+1} = e;
            e = FunctionCallTest.num2strEntry(values, '%d');
            e.formatClass = 'char';
            bad{end+1} = e;
            for k = 1:numel(bad)
                testCase.verifyError(@() functionCall(bad{k}), ...
                    'References:InvalidInputFixture', sprintf('case %d', k));
            end
        end

        function testStrcat(testCase)
            e = struct('name', 'sc', 'kind', 'strcat', 'args', ...
                [struct('text', 'a '); struct('text', '-'); struct('text', 'b')]);
            testCase.verifyCall(functionCall(e), 'strcat', {'a ', '-', 'b'}, 'describeValue');
            e.args = {struct('strings', {{'a '}}); struct('text', 'b')};
            testCase.verifyCall(functionCall(e), 'strcat', {"a ", 'b'}, 'describeValue');
        end

        function testStrcatWithoutArguments(testCase)
            e = struct('name', 'sc', 'kind', 'strcat', 'args', []);
            call = functionCall(e);
            testCase.verifyEqual(func2str(call.fn), 'strcat');
            testCase.verifyEmpty(call.args);
            testCase.verifyClass(call.args, 'cell');
        end

        function testOtherKindIsRejected(testCase)
            testCase.verifyRejected(struct('name', 'r', 'kind', 'textscan', 'text', '1'));
        end

        function testRunFunctionCaseMakesTheCallAndStoresIt(testCase)
            % runFunctionCase is what exportInputFixture runs for these
            % kinds; its result must equal the direct call, stored.
            e = struct('name', 'sc', 'kind', 'strcat', 'args', ...
                [struct('text', 'a '); struct('text', 'b')]);
            testCase.verifyEqual(runFunctionCase(e), describeValue(strcat('a ', 'b')));
            e = FunctionCallTest.sprintfEntry('x%s', struct('text', 'a'));
            e.formatClass = 'string';
            testCase.verifyEqual(runFunctionCase(e), describeValue(sprintf("x%s", 'a')));
            e = FunctionCallTest.num2strEntry( ...
                FunctionCallTest.doubles({'1'; '2'}), '%.11f ');
            testCase.verifyEqual(runFunctionCase(e), toPlain(num2str([1 2], '%.11f ')));
        end

        function testRunFunctionCaseLetsTheCallErrorThrough(testCase)
            % An error of the call itself reaches the exporter, which
            % records it; the fixture identifier is not used for it.
            e = struct('name', 'sc', 'kind', 'strcat', 'args', []);
            direct = FunctionCallTest.outcome(@() strcat());
            % strcat() itself errors, so this compares two errors.
            testCase.verifyFalse(direct{1});
            testCase.verifyNotEqual(direct{2}, 'References:InvalidInputFixture');
            testCase.verifyEqual(FunctionCallTest.outcome(@() runFunctionCase(e)), direct);
        end

        function testRunNumberCase(testCase)
            % runNumberCase is what exportInputFixture runs for these kinds;
            % its result must equal the direct call, stored.
            d = @(texts) struct('double', {texts});
            e = struct('name', 'h', 'kind', 'handle', 'text', '@(z) 2*z', ...
                'z', d({'1'; '2'}));
            expected = struct('text', func2str(str2func('@(z) 2*z')), ...
                'value', describeValue(2*[1; 2]));
            testCase.verifyEqual(runNumberCase(e), expected);
            e = struct('name', 't', 'kind', 'ismembertol', 'a', d({'1'; '2'}), ...
                'b', d({'1'}), 'tol', 0.001);
            testCase.verifyEqual(runNumberCase(e), ...
                describeValue(ismembertol([1 2], 1, 0.001)));
            e = struct('name', 'u', 'kind', 'uint8', 'values', d({'1'; '300'}));
            testCase.verifyEqual(runNumberCase(e), describeValue(uint8([1 300])));
            e = struct('name', 's', 'kind', 'sum', 'values', d({'1'; '2'}));
            testCase.verifyEqual(runNumberCase(e), describeValue(sum([1 2])));
            testCase.verifyError(@() runNumberCase(struct('name', 'r', ...
                'kind', 'textscan', 'text', '1')), 'References:InvalidInputFixture');
        end

        function testExistingEntriesKeepTheirCall(testCase)
            % Two entries of the manifest, pinned: num2str_01 passes its
            % numbers as a double row and its format as char, stored with
            % toPlain; upper_02 passes a string, stored with describeValue.
            entries = FunctionCallTest.manifestEntries();
            e = FunctionCallTest.entryNamed(entries, 'num2str_01');
            testCase.verifyCall(functionCall(e), 'num2str', ...
                {[0.2 -0.2 0], '%.11f '}, 'toPlain');
            e = FunctionCallTest.entryNamed(entries, 'upper_02');
            testCase.verifyCall(functionCall(e), 'upper', {"next"}, 'describeValue');
        end

        function testStoredResultsAreReproduced(testCase)
            % Every upper, sprintf, num2str, strcat, handle, ismembertol,
            % uint8 and sum case in the saved results gives the same
            % outcome (stored result, or error identifier) through the
            % function the exporter runs for it (see reproduces).
            stored = FunctionCallTest.storedCases();
            entries = FunctionCallTest.manifestEntries();
            counts = struct('upper', 0, 'sprintf', 0, 'num2str', 0, 'strcat', 0, ...
                'handle', 0, 'ismembertol', 0, 'uint8', 0, 'sum', 0);
            for k = 1:numel(stored)
                c = stored{k};
                if ~isfield(counts, c.kind)
                    continue
                end
                e = FunctionCallTest.entryNamed(entries, c.name);
                testCase.verifyTrue(FunctionCallTest.reproduces(e, c), c.name);
                counts.(c.kind) = counts.(c.kind) + 1;
            end
            % The cases of each kind in the first recorded run; the saved
            % results may only gain cases. No strcat case is recorded yet.
            floors = struct('upper', 8, 'sprintf', 26, 'num2str', 11, ...
                'handle', 43, 'ismembertol', 6, 'uint8', 1, 'sum', 9);
            for kind = reshape(fieldnames(floors), 1, [])
                testCase.verifyGreaterThanOrEqual(counts.(kind{1}), ...
                    floors.(kind{1}), kind{1});
            end
        end

        function testReproducesDetectsAChange(testCase)
            % Negative controls for testStoredResultsAreReproduced, through
            % the same helper: a changed entry, an entry changed to error, a
            % stored error, and a stored -0 turned into +0 all fail.
            stored = FunctionCallTest.storedCases();
            names = cellfun(@(c) c.name, stored, 'UniformOutput', false);
            entries = FunctionCallTest.manifestEntries();

            c = stored{strcmp(names, 'sum_01')};
            e = FunctionCallTest.entryNamed(entries, 'sum_01');
            testCase.verifyTrue(FunctionCallTest.reproduces(e, c));
            changed = e;
            changed.values.double = [reshape(e.values.double, [], 1); {'1'}];
            testCase.verifyFalse(FunctionCallTest.reproduces(changed, c));
            failing = e;
            failing.values = struct('double', {{1}});
            testCase.verifyFalse(FunctionCallTest.reproduces(failing, c));
            storedError = c;
            storedError.ok = false;
            storedError.errorId = 'Some:error';
            testCase.verifyFalse(FunctionCallTest.reproduces(e, storedError));
            % A stored error against an actual error: the identifiers decide.
            storedError.errorId = 'References:InvalidInputFixture';
            testCase.verifyTrue(FunctionCallTest.reproduces(failing, storedError));
            storedError.errorId = 'Other:id';
            testCase.verifyFalse(FunctionCallTest.reproduces(failing, storedError));

            % handle_29 (@(z) -(z) at z = 0) holds a -0, which isequaln
            % alone does not tell from +0.
            c = stored{strcmp(names, 'handle_29')};
            e = FunctionCallTest.entryNamed(entries, 'handle_29');
            testCase.verifyTrue(FunctionCallTest.reproduces(e, c));
            positive = c;
            v = positive.result.value.value;
            testCase.assertTrue(any(v == 0 & 1 ./ v < 0));
            v(v == 0) = 0;
            positive.result.value.value = v;
            testCase.verifyTrue(isequaln(positive.result, c.result));
            testCase.verifyFalse(FunctionCallTest.reproduces(e, positive));
        end

        function testSameZeroSigns(testCase)
            % The sign-of-zero comparison, for each value form it walks.
            same = @FunctionCallTest.sameZeroSigns;
            testCase.verifyTrue(same([0 -0 1 NaN], [0 -0 1 NaN]));
            testCase.verifyFalse(same([0 -0], [0 0]));
            testCase.verifyTrue(same(NaN, -NaN));
            testCase.verifyFalse(same(struct('a', {-0}), struct('a', {0})));
            testCase.verifyFalse(same({1, -0}, {1, 0}));
            testCase.verifyTrue(same({'a', uint8(0)}, {'a', uint8(0)}));
            testCase.verifyTrue(same(single(-0), single(-0)));
            testCase.verifyFalse(same(single(-0), single(0)));
            % Last, since an assumption that fails skips the rest: only
            % when complex() keeps a -0 imaginary part.
            testCase.assumeTrue(1 / imag(complex(1, -0)) < 0);
            testCase.verifyFalse(same(complex(1, -0), complex(1, 0)));
        end

        function testRealManifestRaisesNoFixtureError(testCase)
            % The exporter code that needs no OpenSTREAM (see argumentError)
            % must not raise the fixture's error for any manifest entry: it
            % would fail the run after the cases.
            entries = FunctionCallTest.manifestEntries();
            flagged = strings(1, 0);
            for k = 1:numel(entries)
                if strcmp(FunctionCallTest.argumentError(entries{k}), ...
                        'References:InvalidInputFixture')
                    flagged(end+1) = string(entries{k}.name); %#ok<AGROW>
                end
            end
            testCase.verifyEmpty(flagged);
        end

        function testBrokenManifestEntryIsFlagged(testCase)
            % Negative control for testRealManifestRaisesNoFixtureError, one
            % per branch of argumentError: each real entry is not flagged,
            % then flagged once one of its fields is broken.
            entries = FunctionCallTest.manifestEntries();
            fixtureId = 'References:InvalidInputFixture';
            e = FunctionCallTest.entryNamed(entries, 'ext_sprintf_54');
            testCase.verifyNotEqual(FunctionCallTest.argumentError(e), fixtureId);
            e.args.matrix.rows = 3;
            testCase.verifyEqual(FunctionCallTest.argumentError(e), fixtureId);
            e = FunctionCallTest.entryNamed(entries, 'handle_01');
            testCase.verifyNotEqual(FunctionCallTest.argumentError(e), fixtureId);
            e.z = struct('double', [0 1]);
            testCase.verifyEqual(FunctionCallTest.argumentError(e), fixtureId);
            e = FunctionCallTest.entryNamed(entries, 'ismembertol_01');
            testCase.verifyNotEqual(FunctionCallTest.argumentError(e), fixtureId);
            e.b = struct('double', 1);
            testCase.verifyEqual(FunctionCallTest.argumentError(e), fixtureId);
            e = FunctionCallTest.entryNamed(entries, 'uint8_values');
            testCase.verifyNotEqual(FunctionCallTest.argumentError(e), fixtureId);
            e.values = struct('text', 'a');
            testCase.verifyEqual(FunctionCallTest.argumentError(e), fixtureId);
            e = FunctionCallTest.entryNamed(entries, 'sum_01');
            testCase.verifyNotEqual(FunctionCallTest.argumentError(e), fixtureId);
            e.values = struct('double', {{1}});
            testCase.verifyEqual(FunctionCallTest.argumentError(e), fixtureId);
            e = FunctionCallTest.entryNamed(entries, 'write_bc');
            testCase.verifyNotEqual(FunctionCallTest.argumentError(e), fixtureId);
            calls = FixtureArguments.list(e.calls);
            calls{1}.time = struct('number', 1);
            e.calls = calls;
            testCase.verifyEqual(FunctionCallTest.argumentError(e), fixtureId);
            e = FunctionCallTest.entryNamed(entries, 'write_model');
            testCase.verifyNotEqual(FunctionCallTest.argumentError(e), fixtureId);
            e.class = 'Mod';
            testCase.verifyEqual(FunctionCallTest.argumentError(e), fixtureId);
        end

        function testEmptyNumberListArguments(testCase)
            e = FunctionCallTest.sprintfEntry('%d', ...
                {struct('uint8', []); struct('double', [])});
            testCase.verifyCall(functionCall(e), 'sprintf', ...
                {'%d', uint8(zeros(1, 0)), zeros(1, 0)}, 'toPlain');
        end

        function testExporterChangeFieldIsIgnored(testCase)
            e = FunctionCallTest.num2strEntry(FunctionCallTest.doubles({'1'}), '');
            plain = functionCall(e);
            e.exporterChange = 'x';
            testCase.verifyCall(functionCall(e), 'num2str', plain.args, 'toPlain');
        end

        function testCallWithoutArgumentsRunsLikeTheDirectCall(testCase)
            % args{:} of an empty cell must call the function with no
            % arguments: the outcome (value or error identifier) must be
            % that of strcat() itself.
            call = functionCall(struct('name', 'sc', 'kind', 'strcat', 'args', []));
            viaCall = FunctionCallTest.outcome(@() call.fn(call.args{:}));
            direct = FunctionCallTest.outcome(@() strcat());
            testCase.verifyEqual(viaCall, direct);
        end

    end

end
