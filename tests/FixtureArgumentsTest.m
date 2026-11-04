classdef FixtureArgumentsTest < matlab.unittest.TestCase
    %FIXTUREARGUMENTSTEST Unit tests for FixtureArguments, the conversion
    % of manifest arguments to MATLAB values.
    %
    % Arguments are built as jsondecode returns them: a JSON list of texts
    % is a column cell of char, [] an empty double. Each malformed argument
    % is paired with a well-formed one that is accepted, so a check that
    % rejects everything fails as surely as one that accepts too much.

    methods (TestClassSetup)

        function addPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            here = fileparts(mfilename('fullpath'));
            testCase.applyFixture(PathFixture(fullfile(here, '..', 'matlab')));
            % The folder of the tests, for the package TestData.
            testCase.applyFixture(PathFixture(here));
        end

    end

    methods (Static)

        function spec = matrixSpec(rows, texts)
            spec = struct('matrix', struct('rows', rows, 'double', {texts}));
        end

        function spec = decode(json)
            % A manifest argument as jsondecode returns it.
            spec = jsondecode(json);
        end

        function out = errorOf(spec)
            % {identifier, true when the message is the rows message} of
            % the error FixtureArguments.value(SPEC) raises; {'', false}
            % when it raises none.
            out = {'', false};
            try
                FixtureArguments.value(spec);
            catch err
                out = {err.identifier, contains(err.message, 'positive integer')};
            end
        end

    end

    methods (Test)

        function testDoubleGivesRow(testCase)
            v = FixtureArguments.value(struct('double', {{'1'; '2.5'}}));
            testCase.verifyClass(v, 'double');
            testCase.verifyEqual(v, [1 2.5]);
            v = FixtureArguments.value(struct('double', []));
            testCase.verifyEqual(v, zeros(1, 0));
        end

        function testTextLogicalStringsHandle(testCase)
            v = FixtureArguments.value(struct('text', 'ab'));
            testCase.verifyClass(v, 'char');
            testCase.verifyEqual(v, 'ab');
            v = FixtureArguments.value(struct('logical', true));
            testCase.verifyClass(v, 'logical');
            testCase.verifyEqual(v, true);
            v = FixtureArguments.value(struct('strings', {{'a'; 'b'}}));
            testCase.verifyClass(v, 'string');
            testCase.verifyEqual(v, ["a" "b"]);
            v = FixtureArguments.value(struct('handle', '@(z) z'));
            testCase.verifyClass(v, 'function_handle');
        end

        function testUint8GivesUint8Row(testCase)
            v = FixtureArguments.value(struct('uint8', {{'1'; '2'}}));
            testCase.verifyClass(v, 'uint8');
            testCase.verifyEqual(v, uint8([1 2]));
            v = FixtureArguments.value(struct('uint8', {{'65'}}));
            testCase.verifyClass(v, 'uint8');
            testCase.verifyEqual(v, uint8(65));
            v = FixtureArguments.value(struct('uint8', []));
            testCase.verifyClass(v, 'uint8');
            testCase.verifySize(v, [1 0]);
        end

        function testMatrixIsColumnMajor(testCase)
            v = FixtureArguments.value( ...
                FixtureArgumentsTest.matrixSpec(2, {'1'; '3'; '2'; '4'}));
            testCase.verifyClass(v, 'double');
            testCase.verifyEqual(v, [1 2; 3 4]);
        end

        function testMatrixRowsSetTheShape(testCase)
            texts = {'1'; '2'; '3'; '4'};
            v = FixtureArguments.value(FixtureArgumentsTest.matrixSpec(1, texts));
            testCase.verifyEqual(v, [1 2 3 4]);
            v = FixtureArguments.value(FixtureArgumentsTest.matrixSpec(4, texts));
            testCase.verifyEqual(v, [1; 2; 3; 4]);
            v = FixtureArguments.value(FixtureArgumentsTest.matrixSpec(2, []));
            testCase.verifySize(v, [2 0]);
        end

        function testMalformedMatrixIsRejected(testCase)
            texts = {'1'; '2'; '3'; '4'};
            bad = {FixtureArgumentsTest.matrixSpec(3, texts), ...
                FixtureArgumentsTest.matrixSpec(0, texts), ...
                FixtureArgumentsTest.matrixSpec(1.5, texts), ...
                FixtureArgumentsTest.matrixSpec(-2, texts), ...
                FixtureArgumentsTest.matrixSpec(Inf, texts), ...
                FixtureArgumentsTest.matrixSpec('2', texts), ...
                FixtureArgumentsTest.matrixSpec([2 2], texts), ...
                struct('matrix', struct('double', {texts})), ...
                struct('matrix', struct('rows', 2)), ...
                struct('matrix', struct('rows', 2, 'double', {texts}, 'cols', 2)), ...
                struct('matrix', {{'1'; '2'}})};
            for k = 1:numel(bad)
                testCase.verifyError(@() FixtureArguments.value(bad{k}), ...
                    'References:InvalidInputFixture', sprintf('case %d', k));
            end
        end

        function testMatrixRowsGuardAlone(testCase)
            % Rows the divisibility check would let through (the number of
            % texts is a multiple of them, or there are none): only the
            % rows check can reject them, and its message says so.
            texts = {'1'; '2'; '3'; '4'};
            bad = {FixtureArgumentsTest.matrixSpec(0.5, texts), ...
                FixtureArgumentsTest.matrixSpec(-2, texts), ...
                FixtureArgumentsTest.matrixSpec(0, []), ...
                FixtureArgumentsTest.matrixSpec(Inf, []), ...
                FixtureArgumentsTest.matrixSpec(true, texts), ...
                FixtureArgumentsTest.matrixSpec(char(2), texts)};
            for k = 1:numel(bad)
                testCase.verifyEqual(FixtureArgumentsTest.errorOf(bad{k}), ...
                    {'References:InvalidInputFixture', true}, sprintf('case %d', k));
            end
            % The divisibility check has its own message.
            testCase.verifyEqual(FixtureArgumentsTest.errorOf( ...
                FixtureArgumentsTest.matrixSpec(3, texts)), ...
                {'References:InvalidInputFixture', false});
        end

        function testEmptyGivesZeros(testCase)
            % {"empty": [rows, cols]} is zeros(rows, cols), whatever the
            % sizes, including the empty ones.
            sizes = {[0 0], [0 3], [3 0], [1 0], [0 1], [2 3]};
            for k = 1:numel(sizes)
                json = sprintf('{"empty":[%d,%d]}', sizes{k}(1), sizes{k}(2));
                v = FixtureArguments.value(FixtureArgumentsTest.decode(json));
                testCase.verifyClass(v, 'double', json);
                testCase.verifySize(v, sizes{k}, json);
                testCase.verifyEqual(v, zeros(sizes{k}), json);
            end
        end

        function testMalformedEmptyIsRejected(testCase)
            % Each bad value differs from the accepted [0,3] by one thing.
            testCase.verifyEqual(FixtureArguments.value( ...
                FixtureArgumentsTest.decode('{"empty":[0,3]}')), zeros(0, 3));
            bad = {'{"empty":[0]}', '{"empty":[0,3,1]}', '{"empty":[-1,3]}', ...
                '{"empty":[1.5,3]}', '{"empty":[0,-3]}', '{"empty":["0","3"]}', ...
                '{"empty":[0,"3"]}', '{"empty":5}', '{"empty":[]}', ...
                '{"empty":"03"}', '{"empty":[true,false]}'};
            for k = 1:numel(bad)
                spec = FixtureArgumentsTest.decode(bad{k});
                testCase.verifyError(@() FixtureArguments.value(spec), ...
                    'References:InvalidInputFixture', bad{k});
            end
        end

        function testCellstrGivesACellRowOfChar(testCase)
            v = FixtureArguments.value(FixtureArgumentsTest.decode('{"cellstr":["a","b"]}'));
            testCase.verifyClass(v, 'cell');
            testCase.verifySize(v, [1 2]);
            testCase.verifyEqual(v, {'a', 'b'});
            testCase.verifyClass(v{1}, 'char');
            v = FixtureArguments.value(FixtureArgumentsTest.decode('{"cellstr":["abc"]}'));
            testCase.verifyClass(v, 'cell');
            testCase.verifySize(v, [1 1]);
            testCase.verifyEqual(v, {'abc'});
            testCase.verifyClass(v{1}, 'char');
            v = FixtureArguments.value(FixtureArgumentsTest.decode('{"cellstr":["a","bc","def"]}'));
            testCase.verifyEqual(v, {'a', 'bc', 'def'});
        end

        function testEmptyCellstrIsAnEmptyCellRow(testCase)
            v = FixtureArguments.value(FixtureArgumentsTest.decode('{"cellstr":[]}'));
            testCase.verifyClass(v, 'cell');
            testCase.verifySize(v, [1 0]);
        end

        function testMalformedCellstrIsRejected(testCase)
            bad = {'{"cellstr":[1,2]}', '{"cellstr":["a",1]}', '{"cellstr":5}', ...
                '{"cellstr":[true]}'};
            for k = 1:numel(bad)
                spec = FixtureArgumentsTest.decode(bad{k});
                testCase.verifyError(@() FixtureArguments.value(spec), ...
                    'References:InvalidInputFixture', bad{k});
            end
        end

        function testArrayIsColumnMajor(testCase)
            % The list fills the first dimension fastest.
            v = FixtureArguments.value(FixtureArgumentsTest.decode( ...
                ['{"array":{"dims":[2,2,2],"double":' ...
                '["1","2","3","4","5","6","7","8"]}}']));
            testCase.verifyClass(v, 'double');
            testCase.verifySize(v, [2 2 2]);
            testCase.verifyEqual(v, reshape(1:8, [2 2 2]));
            testCase.verifyEqual(v(2, 1, 1), 2);
            testCase.verifyEqual(v(1, 2, 1), 3);
            testCase.verifyEqual(v(1, 1, 2), 5);
            v = FixtureArguments.value(FixtureArgumentsTest.decode( ...
                '{"array":{"dims":[2,2],"double":["1","2","3","4"]}}'));
            testCase.verifyEqual(v, [1 3; 2 4]);
            v = FixtureArguments.value(FixtureArgumentsTest.decode( ...
                '{"array":{"dims":[1,2,3],"double":["1","2","3","4","5","6"]}}'));
            testCase.verifySize(v, [1 2 3]);
            testCase.verifyEqual(v(1, 2, 3), 6);
            testCase.verifyEqual(v(1, 1, 2), 3);
        end

        function testArrayWithAZeroDimension(testCase)
            v = FixtureArguments.value(FixtureArgumentsTest.decode( ...
                '{"array":{"dims":[3,0,2],"double":[]}}'));
            testCase.verifyClass(v, 'double');
            testCase.verifySize(v, [3 0 2]);
        end

        function testMalformedArrayIsRejected(testCase)
            % Each bad value differs from the accepted one by one thing; the
            % dims of the fourth and fifth have a product equal to the
            % count, so only the check of the dims themselves rejects them.
            good = '{"array":{"dims":[2,2],"double":["1","2","3","4"]}}';
            testCase.verifyEqual(FixtureArguments.value( ...
                FixtureArgumentsTest.decode(good)), [1 3; 2 4]);
            bad = { ...
                '{"array":{"dims":[2,2],"double":["1","2","3"]}}', ...
                '{"array":{"dims":[2,2],"double":["1","2","3","4","5"]}}', ...
                '{"array":{"dims":[4],"double":["1","2","3","4"]}}', ...
                '{"array":{"dims":[1.5,2],"double":["1","2","3"]}}', ...
                '{"array":{"dims":[-2,-2],"double":["1","2","3","4"]}}', ...
                '{"array":{"dims":["2","2"],"double":["1","2","3","4"]}}', ...
                '{"array":{"dims":[],"double":[]}}', ...
                '{"array":{"dims":[2,2]}}', ...
                '{"array":{"double":["1","2","3","4"]}}', ...
                '{"array":{"dims":[2,2],"double":["1","2","3","4"],"rows":2}}', ...
                '{"array":{"dims":[2,2],"double":[1,2,3,4]}}', ...
                '{"array":{"dims":[0,3],"double":["1"]}}', ...
                '{"array":5}'};
            for k = 1:numel(bad)
                spec = FixtureArgumentsTest.decode(bad{k});
                testCase.verifyError(@() FixtureArguments.value(spec), ...
                    'References:InvalidInputFixture', bad{k});
            end
        end

        function testArrayAndEmptyAreKnownKeys(testCase)
            % An unknown key is still rejected, and the new keys are not.
            testCase.verifyError(@() FixtureArguments.value(struct('arrays', 1)), ...
                'References:InvalidInputFixture');
            testCase.verifyError(@() FixtureArguments.value(struct('cell', 1)), ...
                'References:InvalidInputFixture');
            for json = {'{"empty":[0,0]}', '{"cellstr":[]}', ...
                    '{"array":{"dims":[1,1],"double":["1"]}}'}
                testCase.verifyWarningFree(@() FixtureArguments.value( ...
                    FixtureArgumentsTest.decode(json{1})));
            end
        end

        function testNonTextNumberListsAreRejected(testCase)
            % Numbers must come as a JSON list of texts (a cell of char);
            % anything else is a manifest error, as in the validator.
            bad = {struct('double', [1 2]), struct('uint8', 1), ...
                struct('double', '1'), struct('double', "1"), ...
                struct('double', {{1}}), struct('double', true), ...
                FixtureArgumentsTest.matrixSpec(2, [1 2 3 4])};
            for k = 1:numel(bad)
                testCase.verifyError(@() FixtureArguments.value(bad{k}), ...
                    'References:InvalidInputFixture', sprintf('case %d', k));
            end
            testCase.verifyError(@() FixtureArguments.doubles( ...
                struct('double', [1 2]), 'row'), 'References:InvalidInputFixture');
            % The accepted forms of the same values.
            testCase.verifyEqual(FixtureArguments.value( ...
                struct('double', {{'1'; '2'}})), [1 2]);
            testCase.verifyEqual(FixtureArguments.value(struct('double', {{}})), ...
                zeros(1, 0));
        end

        function testPairs(testCase)
            % The three shapes jsondecode gives a list of [key, arg] pairs.
            first = {'A'; struct('double', {{'1'}})};
            second = {'B'; struct('text', 'x')};
            expected = {'A', 1, 'B', 'x'};
            testCase.verifyEqual(FixtureArguments.pairs({first; second}), expected);
            testCase.verifyEqual(FixtureArguments.pairs(first), {'A', 1});
            testCase.verifyEqual(FixtureArguments.pairs( ...
                [first'; second']), expected);
            bad = {{'A'; 5}, {5; struct('text', 'x')}, 'A', {first; {'B'}}};
            for k = 1:numel(bad)
                testCase.verifyError(@() FixtureArguments.pairs(bad{k}), ...
                    'References:InvalidInputFixture', sprintf('case %d', k));
            end
        end

        function testWriteArguments(testCase)
            % The id form for Model, Options and Geometry, the four leading
            % values for BoundaryConditions, and an unknown class rejected.
            pairs = {{'NNODES'; struct('double', {{'100'}})}};
            call = struct('id', 'W1', 'values', {pairs});
            for className = {'Model', 'Options', 'Geometry'}
                testCase.verifyEqual(FixtureArguments.writeArguments( ...
                    className{1}, call), {'W1', 'NNODES', 100});
            end
            d = @(text) struct('double', {{text}});
            call = struct('time', d('0'), 'pressure', d('6e6'), 'hin', d('1'), ...
                'mflow', d('0.07'), 'values', {pairs});
            testCase.verifyEqual(FixtureArguments.writeArguments( ...
                'BoundaryConditions', call), {0, 6e6, 1, 0.07, 'NNODES', 100});
            testCase.verifyError(@() FixtureArguments.writeArguments('Mod', call), ...
                'References:InvalidInputFixture');
            call.time = struct('number', 1);
            testCase.verifyError(@() FixtureArguments.writeArguments( ...
                'BoundaryConditions', call), 'References:InvalidInputFixture');
        end

        function testMalformedArgumentIsRejected(testCase)
            bad = {struct('number', 1), struct('double', {{'1'}}, 'text', 'a'), ...
                struct(), 5, [struct('text', 'a'), struct('text', 'b')]};
            for k = 1:numel(bad)
                testCase.verifyError(@() FixtureArguments.value(bad{k}), ...
                    'References:InvalidInputFixture', sprintf('case %d', k));
            end
        end

        function testDoublesShape(testCase)
            spec = struct('double', {{'1'; '2'}});
            testCase.verifyEqual(FixtureArguments.doubles(spec, 'row'), [1 2]);
            testCase.verifyEqual(FixtureArguments.doubles(spec, 'column'), [1; 2]);
            testCase.verifyError(@() FixtureArguments.doubles( ...
                struct('text', 'a'), 'row'), 'References:InvalidInputFixture');
        end

        function testListShapes(testCase)
            testCase.verifyEqual(FixtureArguments.list({1; 2}), {1, 2});
            s = [struct('a', 1); struct('a', 2)];
            out = FixtureArguments.list(s);
            testCase.verifySize(out, [1 2]);
            testCase.verifyEqual(out{2}, struct('a', 2));
            testCase.verifyEqual(FixtureArguments.list([]), {});
            testCase.verifyEqual(FixtureArguments.list('x'), {'x'});
        end

        function testWriteArgumentsLeaveOutTheFileMode(testCase)
            % A write call may carry the fopen mode of the file as its
            % field mode; it is not an argument after the file name, so the
            % arguments are those of the same call without it, for every
            % class. (The mode reaches the file call by another route.)
            pairs = {{'NNODES'; struct('double', {{'100'}})}};
            d = @(text) struct('double', {{text}});
            for className = {'Model', 'Options', 'Geometry'}
                plain = struct('id', 'W1', 'values', {pairs});
                withMode = struct('id', 'W1', 'mode', 'w', 'values', {pairs});
                testCase.verifyEqual(FixtureArguments.writeArguments( ...
                    className{1}, withMode), {'W1', 'NNODES', 100});
                testCase.verifyEqual(FixtureArguments.writeArguments( ...
                    className{1}, withMode), ...
                    FixtureArguments.writeArguments(className{1}, plain));
            end
            plain = struct('time', d('0'), 'pressure', d('6e6'), 'hin', d('1'), ...
                'mflow', d('0.07'), 'values', {pairs});
            withMode = struct('time', d('0'), 'pressure', d('6e6'), 'hin', d('1'), ...
                'mflow', d('0.07'), 'mode', 'r+', 'values', {pairs});
            testCase.verifyEqual(FixtureArguments.writeArguments( ...
                'BoundaryConditions', withMode), {0, 6e6, 1, 0.07, 'NNODES', 100});
            testCase.verifyEqual(FixtureArguments.writeArguments( ...
                'BoundaryConditions', withMode), ...
                FixtureArguments.writeArguments('BoundaryConditions', plain));
        end

        function testWriteArgumentsConvertMatrixArrayAndEmptyTextValues(testCase)
            % The three value forms of the writer's pairs, from entries as
            % jsondecode gives them: a matrix with rows (filled column by
            % column, so rows 2 over 1 3 2 4 is [1 2; 3 4]), an array with
            % dims (1x2x2 over 1..4 puts 1 2 in the first page and 3 4 in
            % the second), and an empty text, which stays an empty char of
            % size 0x0 (not a string, not 1x0).
            matrix = TestData.CaseEntries.entry('write', 'ext_write_01');
            calls = FixtureArguments.list(matrix.calls);
            args = FixtureArguments.writeArguments(matrix.class, calls{1});
            testCase.verifyEqual(args, {'G', 'PERIM', [1 2; 3 4]});

            array = TestData.CaseEntries.entry('write', 'ext_write_06');
            calls = FixtureArguments.list(array.calls);
            args = FixtureArguments.writeArguments(array.class, calls{1});
            testCase.verifyEqual(args{1}, 'G');
            testCase.verifyEqual(args{2}, 'PERIM');
            testCase.verifyEqual(args{3}, cat(3, [1 2], [3 4]));
            testCase.verifySize(args{3}, [1 2 2]);

            empty = TestData.CaseEntries.entry('write', 'ext_write_05');
            calls = FixtureArguments.list(empty.calls);
            args = FixtureArguments.writeArguments(empty.class, calls{1});
            testCase.verifyClass(args{3}, 'char');
            testCase.verifySize(args{3}, [0 0]);
        end

        function testEveryWriteEntryConvertsWithoutAnError(testCase)
            % Every write entry of the manifest extension converts its
            % calls: no entry raises the fixture's error. The control: the
            % same entry with a value key that does not exist does.
            lines = TestData.CaseEntries.write();
            entries = TestData.CaseEntries.decode(lines);
            for k = 1:numel(entries)
                e = entries{k};
                calls = FixtureArguments.list(e.calls);
                for j = 1:numel(calls)
                    FixtureArguments.writeArguments(e.class, calls{j});
                end
            end
            e = entries{1};
            calls = FixtureArguments.list(e.calls);
            call = calls{1};
            call.values = {{'PERIM'; struct('number', 1)}};
            testCase.verifyError(@() FixtureArguments.writeArguments( ...
                e.class, call), 'References:InvalidInputFixture');
        end

        function testCallsWithDifferentKeysConvertAlike(testCase)
            % A write entry whose calls do not all have a mode decodes its
            % calls as a cell, not a struct array; list gives the same row of
            % calls either way and each converts.
            text = ['{"name":"w","kind":"write","class":"Geometry","calls":[' ...
                '{"id":"G","mode":"w","values":[["LENGTH",{"double":["5.5"]}]]},' ...
                '{"id":"G","values":[["LENGTH",{"double":["6"]}]]}]}'];
            e = jsondecode(text);
            testCase.assertClass(e.calls, 'cell');
            calls = FixtureArguments.list(e.calls);
            testCase.assertNumElements(calls, 2);
            testCase.verifyEqual(FixtureArguments.writeArguments('Geometry', calls{1}), ...
                {'G', 'LENGTH', 5.5});
            testCase.verifyEqual(FixtureArguments.writeArguments('Geometry', calls{2}), ...
                {'G', 'LENGTH', 6});
        end

    end

end
