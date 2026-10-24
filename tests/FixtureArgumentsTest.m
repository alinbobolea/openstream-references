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
        end

    end

    methods (Static)

        function spec = matrixSpec(rows, texts)
            spec = struct('matrix', struct('rows', rows, 'double', {texts}));
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

    end

end
