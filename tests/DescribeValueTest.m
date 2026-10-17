classdef DescribeValueTest < matlab.unittest.TestCase
    %DESCRIBEVALUETEST Unit tests for describeValue, one per branch.
    %
    % Each test checks class, size and value, with literal expected leaves,
    % so a branch that drops the shape or the type of a value fails as
    % surely as one that changes it.

    methods (TestClassSetup)

        function addPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            here = fileparts(mfilename('fullpath'));
            testCase.applyFixture(PathFixture(here));
            testCase.applyFixture(PathFixture(fullfile(here, '..', 'matlab')));
        end

    end

    methods (Test)

        function testDoubleMatrix(testCase)
            v = [1 2 3; 4 5 6];
            d = describeValue(v);
            testCase.verifyEqual(d.class, 'double');
            testCase.verifyEqual(d.size, [2 3]);
            testCase.verifyEqual(d.value, v);
        end

        function testLogical(testCase)
            d = describeValue([true false]);
            testCase.verifyEqual(d.class, 'logical');
            testCase.verifyEqual(d.size, [1 2]);
            testCase.verifyEqual(d.value, [true false]);
        end

        function testChar(testCase)
            d = describeValue('abc');
            testCase.verifyEqual(d.class, 'char');
            testCase.verifyEqual(d.size, [1 3]);
            testCase.verifyEqual(d.value, 'abc');
        end

        function testStringColumn(testCase)
            d = describeValue(["a"; "bc"]);
            testCase.verifyEqual(d.class, 'string');
            testCase.verifyEqual(d.size, [2 1]);
            testCase.verifyEqual(d.value, {'a'; 'bc'});
        end

        function testStructArrayKeepsFieldOrder(testCase)
            s = struct('b', {1, 'x'}, 'a', {true, [1 2]});
            d = describeValue(s);
            testCase.verifyEqual(d.class, 'struct');
            testCase.verifyEqual(d.size, [1 2]);
            testCase.verifyEqual(d.value.fields, {'b', 'a'});
            testCase.assertSize(d.value.elements, [1 2]);
            testCase.verifyEqual(fieldnames(d.value.elements{2}), {'b'; 'a'});
            first = d.value.elements{1};
            second = d.value.elements{2};
            testCase.verifyEqual(first.b.class, 'double');
            testCase.verifyEqual(first.b.value, 1);
            testCase.verifyEqual(first.a.class, 'logical');
            testCase.verifyEqual(first.a.value, true);
            testCase.verifyEqual(second.b.class, 'char');
            testCase.verifyEqual(second.b.value, 'x');
            testCase.verifyEqual(second.a.size, [1 2]);
            testCase.verifyEqual(second.a.value, [1 2]);
        end

        function testEmptyStructs(testCase)
            d = describeValue(struct([]));
            testCase.verifyEqual(d.class, 'struct');
            testCase.verifyEqual(d.size, [0 0]);
            testCase.verifyEqual(d.value.fields, cell(1, 0));
            testCase.verifyEqual(d.value.elements, cell(0, 0));

            d = describeValue(struct());
            testCase.verifyEqual(d.class, 'struct');
            testCase.verifyEqual(d.size, [1 1]);
            testCase.verifyEqual(d.value.fields, cell(1, 0));
            testCase.assertSize(d.value.elements, [1 1]);
            testCase.verifyTrue(isstruct(d.value.elements{1}));
            testCase.verifyEmpty(fieldnames(d.value.elements{1}));
        end

        function testStructHoldingStructAndCell(testCase)
            s = struct();
            s.inner = struct('x', 1);
            s.list = {2, 'a'};
            d = describeValue(s);
            testCase.verifyEqual(d.value.fields, {'inner', 'list'});
            inner = d.value.elements{1}.inner;
            testCase.verifyEqual(inner.class, 'struct');
            testCase.verifyEqual(inner.value.fields, {'x'});
            testCase.verifyEqual(inner.value.elements{1}.x.value, 1);
            list = d.value.elements{1}.list;
            testCase.verifyEqual(list.class, 'cell');
            testCase.verifyEqual(list.size, [1 2]);
            testCase.verifyEqual(list.value{1}.value, 2);
            testCase.verifyEqual(list.value{2}.class, 'char');
            testCase.verifyEqual(list.value{2}.value, 'a');
        end

        function testCell(testCase)
            d = describeValue({1, 'a'; "s", []});
            testCase.verifyEqual(d.class, 'cell');
            testCase.verifyEqual(d.size, [2 2]);
            testCase.assertSize(d.value, [2 2]);
            testCase.verifyEqual(d.value{1, 1}.value, 1);
            testCase.verifyEqual(d.value{1, 2}.value, 'a');
            testCase.verifyEqual(d.value{2, 1}.class, 'string');
            testCase.verifyEqual(d.value{2, 1}.size, [1 1]);
            testCase.verifyEqual(d.value{2, 1}.value, {'s'});
            testCase.verifyEqual(d.value{2, 2}.class, 'double');
            testCase.verifyEqual(d.value{2, 2}.size, [0 0]);
        end

        function testFunctionHandle(testCase)
            f = @(z) 1 + z;
            d = describeValue(f);
            testCase.verifyEqual(d.class, 'function_handle');
            testCase.verifyEqual(d.size, [1 1]);
            % func2str's own spacing is what the fixture records.
            testCase.verifyEqual(d.value, func2str(f));
            testCase.verifyClass(d.value, 'char');
        end

        function testEmpty(testCase)
            d = describeValue([]);
            testCase.verifyEqual(d.class, 'double');
            testCase.verifyEqual(d.size, [0 0]);
            testCase.verifyEqual(d.value, []);
        end

        function testNumericEnumerationGivesNames(testCase)
            % ExportFixture.Level derives from uint16, so it also counts as
            % numeric: the enumeration check must come first.
            d = describeValue(ExportFixture.Level.HIGH);
            testCase.verifyEqual(d.class, 'ExportFixture.Level');
            testCase.verifyEqual(d.size, [1 1]);
            testCase.verifyEqual(d.value, 'HIGH');
            d = describeValue([ExportFixture.Level.LOW ExportFixture.Level.HIGH]);
            testCase.verifyEqual(d.size, [1 2]);
            testCase.verifyEqual(d.value, {'LOW', 'HIGH'});
        end

        function testOtherObjectGoesToToPlain(testCase)
            node = ExportFixture.Node(3);
            d = describeValue(node);
            testCase.verifyEqual(d.class, 'ExportFixture.Node');
            testCase.verifyEqual(d.size, [1 1]);
            testCase.verifyEqual(d.value, '<skipped:ExportFixture.Node>');
            testCase.verifyEqual(d.value, toPlain(node));
        end

    end

end
