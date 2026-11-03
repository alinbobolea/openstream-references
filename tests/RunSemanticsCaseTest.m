classdef RunSemanticsCaseTest < matlab.unittest.TestCase
    %RUNSEMANTICSCASETEST Unit tests for runSemanticsCase, the call a
    % function-behaviour case makes (kinds mcall and sumsweep2; the fluid
    % kinds need OpenSTREAM and are not run here).
    %
    % Entries are made with jsondecode from JSON text, as the exporter gets
    % them. Each expected value is either the direct call written in the test
    % (described the way the exporter stores it) or a fact of the language
    % stated beside it, so a runner that makes another call, passes another
    % argument, or records the wrong output fails. Pairs of calls that differ
    % in one thing (max and min, one and two outputs, columns and rows)
    % check that the result follows the entry.

    methods (TestClassSetup)

        function addPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            here = fileparts(mfilename('fullpath'));
            testCase.applyFixture(PathFixture(fullfile(here, '..', 'matlab')));
        end

    end

    methods (Static)

        function e = call(name, args, outputs)
            % An mcall entry: NAME, ARGS (JSON text of the list) and the
            % number of outputs.
            e = jsondecode(sprintf(['{"name":"sem_shape_01","kind":"mcall",' ...
                '"callee":"%s","args":%s,"nargout":%d}'], name, args, outputs));
        end

        function e = sweep(along, lengths, other)
            e = jsondecode(sprintf(['{"name":"sem_sums_01","kind":"sumsweep2",' ...
                '"along":"%s","lengths":%s,"other":%d}'], along, lengths, other));
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

        function expected = sweepSums(lengths, other, along)
            % The sums the case describes, written out from its definition:
            % for each length n, v(k) = 0.1*k with every fifth value from
            % k = 1 replaced by 1e16 and from k = 2 by -1e16; the matrix has
            % column j equal to v*j for j = 1..other (n-by-other, summed
            % with sum(a, 1), a row of OTHER sums) for "columns", and its
            % transpose (other-by-n, summed with sum(a, 2), a column of OTHER
            % sums) for "rows".
            expected = cell(1, numel(lengths));
            for k = 1:numel(lengths)
                n = lengths(k);
                i = 1:n;
                v = 0.1 * i;
                v(mod(i, 5) == 1) = 1e16;
                v(mod(i, 5) == 2) = -1e16;
                a = v(:) * (1:other);
                if strcmp(along, 'columns')
                    expected{k} = describeValue(sum(a, 1));
                else
                    expected{k} = describeValue(sum(a.', 2));
                end
            end
        end

    end

    methods (Test)

        function testMaxIgnoresNaN(testCase)
            % Language fact: max([1 NaN 3]) is 3 (NaN is skipped).
            e = RunSemanticsCaseTest.call('max', '[{"double":["1","NaN","3"]}]', 1);
            result = runSemanticsCase(e);
            testCase.verifyEqual(result, struct('outputs', {{describeValue(max([1 NaN 3]))}}));
            testCase.verifyEqual(result.outputs{1}.value, 3);
            testCase.verifyEqual(result.outputs{1}.class, 'double');
            testCase.verifyEqual(result.outputs{1}.size, [1 1]);
        end

        function testMinFollowsTheFunction(testCase)
            % The same argument with min: language fact, min([1 NaN 3]) is 1.
            e = RunSemanticsCaseTest.call('min', '[{"double":["1","NaN","3"]}]', 1);
            result = runSemanticsCase(e);
            testCase.verifyEqual(result.outputs{1}.value, 1);
            testCase.verifyEqual(result, struct('outputs', {{describeValue(min([1 NaN 3]))}}));
        end

        function testMaxOfOnlyNaNIsNaN(testCase)
            e = RunSemanticsCaseTest.call('max', '[{"double":["NaN","NaN"]}]', 1);
            result = runSemanticsCase(e);
            testCase.verifyTrue(isnan(result.outputs{1}.value));
            testCase.verifyEqual(result.outputs{1}.size, [1 1]);
        end

        function testSecondOutputIsRecorded(testCase)
            % Language facts: [m, i] = max([1 NaN 3]) is 3 and 3; for a tie
            % the index is that of the first extreme: max([2 5 5 1]) is 5 at 2.
            e = RunSemanticsCaseTest.call('max', '[{"double":["1","NaN","3"]}]', 2);
            result = runSemanticsCase(e);
            testCase.verifySize(result.outputs, [1 2]);
            testCase.verifyEqual(result.outputs{1}.value, 3);
            testCase.verifyEqual(result.outputs{2}.value, 3);
            [m, i] = max([1 NaN 3]);
            testCase.verifyEqual(result, ...
                struct('outputs', {{describeValue(m), describeValue(i)}}));
            e = RunSemanticsCaseTest.call('max', '[{"double":["2","5","5","1"]}]', 2);
            result = runSemanticsCase(e);
            testCase.verifyEqual(result.outputs{1}.value, 5);
            testCase.verifyEqual(result.outputs{2}.value, 2);
        end

        function testOneOutputRecordsOneOutput(testCase)
            % The pair of testSecondOutputIsRecorded: the same call with
            % nargout 1 records one output, not two.
            e = RunSemanticsCaseTest.call('max', '[{"double":["2","5","5","1"]}]', 1);
            result = runSemanticsCase(e);
            testCase.verifySize(result.outputs, [1 1]);
            testCase.verifyEqual(result.outputs{1}.value, 5);
        end

        function testThreeOutputsOfSize(testCase)
            % Language fact: [a, b, c] = size of a 1x2x3 array is 1, 2, 3.
            args = ['[{"array":{"dims":[1,2,3],"double":' ...
                '["1","2","3","4","5","6"]}}]'];
            result = runSemanticsCase(RunSemanticsCaseTest.call('size', args, 3));
            testCase.verifySize(result.outputs, [1 3]);
            testCase.verifyEqual([result.outputs{1}.value, result.outputs{2}.value, ...
                result.outputs{3}.value], [1 2 3]);
            result = runSemanticsCase(RunSemanticsCaseTest.call('size', args, 1));
            testCase.verifySize(result.outputs, [1 1]);
            testCase.verifyEqual(result.outputs{1}.value, [1 2 3]);
        end

        function testFminbndWithTwoOutputs(testCase)
            % Language fact: the minimum of (x-1).^2 on [-3, 4] is at x = 1,
            % where the value is 0 (to the tolerance of fminbnd).
            args = ['[{"handle":"@(x) (x-1).^2"},{"double":["-3"]},' ...
                '{"double":["4"]}]'];
            result = runSemanticsCase(RunSemanticsCaseTest.call('fminbnd', args, 2));
            [x, fval] = fminbnd(@(x) (x-1).^2, -3, 4);
            testCase.verifyEqual(result, struct('outputs', {{describeValue(x), describeValue(fval)}}));
            testCase.verifySize(result.outputs, [1 2]);
            testCase.verifyLessThan(abs(result.outputs{1}.value - 1), 1e-3);
            testCase.verifyLessThan(result.outputs{2}.value, 1e-6);
        end

        function testReshapeWithAnEmptyPlaceholder(testCase)
            % Language fact: reshape(1:6, [], 2) is [1 4; 2 5; 3 6]. The []
            % is the empty argument {"empty": [0, 0]}.
            args = ['[{"double":["1","2","3","4","5","6"]},{"empty":[0,0]},' ...
                '{"double":["2"]}]'];
            result = runSemanticsCase(RunSemanticsCaseTest.call('reshape', args, 1));
            testCase.verifyEqual(result, struct('outputs', {{describeValue(reshape(1:6, [], 2))}}));
            testCase.verifyEqual(result.outputs{1}.value, [1 4; 2 5; 3 6]);
            testCase.verifyEqual(result.outputs{1}.size, [3 2]);
            % Neighbour: three columns instead of two.
            args = ['[{"double":["1","2","3","4","5","6"]},{"empty":[0,0]},' ...
                '{"double":["3"]}]'];
            result = runSemanticsCase(RunSemanticsCaseTest.call('reshape', args, 1));
            testCase.verifyEqual(result.outputs{1}.value, [1 3 5; 2 4 6]);
        end

        function testColonAndPowerAreCalledByName(testCase)
            % Language facts: colon(1, 2, 7) is 1:2:7 = [1 3 5 7]; power is
            % the operator .^.
            args = '[{"double":["1"]},{"double":["2"]},{"double":["7"]}]';
            result = runSemanticsCase(RunSemanticsCaseTest.call('colon', args, 1));
            testCase.verifyEqual(result.outputs{1}.value, [1 3 5 7]);
            testCase.verifyEqual(result.outputs{1}.size, [1 4]);
            args = '[{"double":["1","2","3"]},{"double":["2"]}]';
            result = runSemanticsCase(RunSemanticsCaseTest.call('power', args, 1));
            testCase.verifyEqual(result.outputs{1}.value, [1 4 9]);
        end

        function testEveryArgumentKeyReachesTheCall(testCase)
            % One call per key, each with a result that depends on how the
            % key was converted (language facts beside each).
            % empty: size(zeros(0, 3)) is [0 3].
            r = runSemanticsCase(RunSemanticsCaseTest.call('size', '[{"empty":[0,3]}]', 1));
            testCase.verifyEqual(r.outputs{1}.value, [0 3]);
            % array: a 2x3x2 array filled column-major with 1..12 (double of
            % a double is the array itself).
            args = ['[{"array":{"dims":[2,3,2],"double":' ...
                '["1","2","3","4","5","6","7","8","9","10","11","12"]}}]'];
            r = runSemanticsCase(RunSemanticsCaseTest.call('double', args, 1));
            testCase.verifyEqual(r.outputs{1}.size, [2 3 2]);
            testCase.verifyEqual(r.outputs{1}.value, reshape(1:12, [2 3 2]));
            testCase.verifyEqual(r.outputs{1}.value(2, 1, 1), 2);
            testCase.verifyEqual(r.outputs{1}.value(1, 2, 1), 3);
            testCase.verifyEqual(r.outputs{1}.value(1, 1, 2), 7);
            % matrix: rows 2 over six values in column order is the 2x3
            % matrix [1 2 3; 4 5 6].
            args = '[{"matrix":{"rows":2,"double":["1","4","2","5","3","6"]}}]';
            r = runSemanticsCase(RunSemanticsCaseTest.call('double', args, 1));
            testCase.verifyEqual(r.outputs{1}.size, [2 3]);
            testCase.verifyEqual(r.outputs{1}.value, [1 2 3; 4 5 6]);
            % uint8: 300 saturates to 255, so double(uint8(300)) is 255.
            r = runSemanticsCase(RunSemanticsCaseTest.call('double', ...
                '[{"uint8":["300","1"]}]', 1));
            testCase.verifyEqual(r.outputs{1}.value, [255 1]);
            testCase.verifyEqual(r.outputs{1}.class, 'double');
            % text: double('A') is 65.
            r = runSemanticsCase(RunSemanticsCaseTest.call('double', '[{"text":"A"}]', 1));
            testCase.verifyEqual(r.outputs{1}.value, 65);
            % logical: double(true) is 1.
            r = runSemanticsCase(RunSemanticsCaseTest.call('double', '[{"logical":true}]', 1));
            testCase.verifyEqual(r.outputs{1}.value, 1);
            testCase.verifyEqual(r.outputs{1}.class, 'double');
            % strings: a string row of two items has size [1 2].
            r = runSemanticsCase(RunSemanticsCaseTest.call('size', ...
                '[{"strings":["a","b"]}]', 1));
            testCase.verifyEqual(r.outputs{1}.value, [1 2]);
            % double: the plain row.
            r = runSemanticsCase(RunSemanticsCaseTest.call('size', ...
                '[{"double":["1","2","3"]}]', 1));
            testCase.verifyEqual(r.outputs{1}.value, [1 3]);
        end

        function testCellstrIsACellOfText(testCase)
            % Language fact: ismember('b', {'a', 'b'}) is true and
            % ismember('c', {'a', 'b'}) is false.
            args = '[{"text":"b"},{"cellstr":["a","b"]}]';
            r = runSemanticsCase(RunSemanticsCaseTest.call('ismember', args, 1));
            testCase.verifyEqual(r.outputs{1}.value, true);
            testCase.verifyEqual(r.outputs{1}.class, 'logical');
            args = '[{"text":"c"},{"cellstr":["a","b"]}]';
            r = runSemanticsCase(RunSemanticsCaseTest.call('ismember', args, 1));
            testCase.verifyEqual(r.outputs{1}.value, false);
        end

        function testCallWithoutArguments(testCase)
            % Language fact: nan() is a scalar NaN.
            r = runSemanticsCase(RunSemanticsCaseTest.call('nan', '[]', 1));
            testCase.verifyTrue(isnan(r.outputs{1}.value));
            testCase.verifyEqual(r.outputs{1}.size, [1 1]);
        end

        function testErrorOfTheCallIsNotCaught(testCase)
            % An error of the call itself reaches the exporter, which
            % records it as data: the outcome is that of the direct call, and
            % is not the fixture's own error.
            e = RunSemanticsCaseTest.call('max', ...
                '[{"double":["1","2"]},{"double":["1","2","3"]}]', 1);
            direct = RunSemanticsCaseTest.outcome(@() max([1 2], [1 2 3]));
            testCase.assertFalse(direct{1}, 'the direct call errors');
            testCase.assertNotEmpty(direct{2});
            testCase.verifyNotEqual(direct{2}, 'References:InvalidSemanticsFixture');
            testCase.verifyEqual(RunSemanticsCaseTest.outcome(@() runSemanticsCase(e)), direct);
            % The neighbour that does not error.
            e = RunSemanticsCaseTest.call('max', ...
                '[{"double":["1","2","3"]},{"double":["1","2","3"]}]', 1);
            outcome = RunSemanticsCaseTest.outcome(@() runSemanticsCase(e));
            testCase.verifyTrue(outcome{1});
        end

        function testSumsweepColumns(testCase)
            % Language facts, with three columns and sum(A, 1): for a length
            % of 1 the matrix is the row 1e16*[1 2 3] and its sum down the
            % columns is the row itself; for a length of 2 the values 1e16
            % and -1e16 cancel in every column, giving the row [0 0 0].
            lengths = [1 2 6 7];
            e = RunSemanticsCaseTest.sweep('columns', '[1,2,6,7]', 3);
            result = runSemanticsCase(e);
            testCase.verifyEqual(result.lengths, [1 2 6 7]);
            testCase.verifyNumElements(result.sums, 4);
            testCase.verifyEqual(result.sums{1}.value, [1e16 2e16 3e16]);
            testCase.verifyEqual(result.sums{2}.value, [0 0 0]);
            for k = 1:4
                testCase.verifyEqual(result.sums{k}.size, [1 3], sprintf('length %d', lengths(k)));
                testCase.verifyEqual(result.sums{k}.class, 'double');
            end
            expected = RunSemanticsCaseTest.sweepSums(lengths, 3, 'columns');
            for k = 1:4
                testCase.verifyEqual(result.sums{k}, expected{k}, sprintf('length %d', lengths(k)));
            end
        end

        function testSumsweepRows(testCase)
            % The same sweep along rows: each sum is a column of one value
            % per row of the transposed matrix.
            lengths = [1 2 6 7];
            e = RunSemanticsCaseTest.sweep('rows', '[1,2,6,7]', 3);
            result = runSemanticsCase(e);
            testCase.verifyEqual(result.lengths, [1 2 6 7]);
            testCase.verifyNumElements(result.sums, 4);
            testCase.verifyEqual(result.sums{1}.value, [1e16; 2e16; 3e16]);
            testCase.verifyEqual(result.sums{2}.value, [0; 0; 0]);
            for k = 1:4
                testCase.verifyEqual(result.sums{k}.size, [3 1], ...
                    sprintf('length %d', lengths(k)));
            end
            expected = RunSemanticsCaseTest.sweepSums(lengths, 3, 'rows');
            for k = 1:4
                testCase.verifyEqual(result.sums{k}, expected{k}, sprintf('length %d', lengths(k)));
            end
        end

        function testSumsweepOtherAndLengths(testCase)
            % other = 1 gives one column (a scalar sum); one length in the
            % list; a longer list keeps its order and values.
            result = runSemanticsCase(RunSemanticsCaseTest.sweep('columns', '[5]', 1));
            testCase.verifyEqual(result.lengths, 5);
            testCase.verifyNumElements(result.sums, 1);
            testCase.verifyEqual(result.sums{1}.size, [1 1]);
            expected = RunSemanticsCaseTest.sweepSums(5, 1, 'columns');
            testCase.verifyEqual(result.sums{1}, expected{1});
            lengths = [3 1 12];
            result = runSemanticsCase(RunSemanticsCaseTest.sweep('rows', '[3,1,12]', 2));
            testCase.verifyEqual(result.lengths, [3 1 12]);
            expected = RunSemanticsCaseTest.sweepSums(lengths, 2, 'rows');
            for k = 1:3
                testCase.verifyEqual(result.sums{k}, expected{k}, sprintf('length %d', lengths(k)));
            end
        end

        function testUnknownKindIsAFixtureError(testCase)
            e = struct('name', 'sem_shape_01', 'kind', 'nope');
            testCase.verifyError(@() runSemanticsCase(e), ...
                'References:InvalidSemanticsFixture');
            % The neighbour: the same entry with a kind it runs.
            e = RunSemanticsCaseTest.call('nan', '[]', 1);
            testCase.verifyWarningFree(@() runSemanticsCase(e));
        end

        function testEntryWithoutAKindIsAFixtureError(testCase)
            % Not an entry at all: a number, a text, a struct array, a struct
            % with no kind field.
            bad = {5, 'text', [struct('kind', 'mcall'), struct('kind', 'mcall')], ...
                struct('name', 'sem_shape_01')};
            for k = 1:numel(bad)
                testCase.verifyError(@() runSemanticsCase(bad{k}), ...
                    'References:InvalidSemanticsFixture', sprintf('case %d', k));
            end
        end

        function testUnknownDirectionIsAFixtureError(testCase)
            % along is columns or rows; the neighbours run.
            e = RunSemanticsCaseTest.sweep('diag', '[1,2]', 1);
            testCase.verifyError(@() runSemanticsCase(e), ...
                'References:InvalidSemanticsFixture');
            for along = {'columns', 'rows'}
                e = RunSemanticsCaseTest.sweep(along{1}, '[1,2]', 1);
                testCase.verifyWarningFree(@() runSemanticsCase(e), along{1});
            end
        end

    end

end
