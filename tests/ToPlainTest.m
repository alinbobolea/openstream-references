classdef ToPlainTest < matlab.unittest.TestCase
    %TOPLAINTEST Unit tests for toPlain, the conversion of OpenSTREAM
    % objects to plain MATLAB types.
    %
    % Each exclusion check is paired with an inclusion check, so a
    % conversion that drops everything fails as surely as one that keeps
    % too much.

    methods (TestClassSetup)

        function addPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            here = fileparts(mfilename('fullpath'));
            testCase.applyFixture(PathFixture(here));
            testCase.applyFixture(PathFixture(fullfile(here, '..', 'matlab')));
        end

    end

    methods (Test)

        function testNumericPassThrough(testCase)
            values = {reshape(1:24, 2, 3, 4), uint8(255), [true false], 'abc'};
            for k = 1:numel(values)
                out = toPlain(values{k});
                testCase.verifyEqual(out, values{k});
                testCase.verifyClass(out, class(values{k}));
            end
        end

        function testStringBecomesChar(testCase)
            out = toPlain("MRM");
            testCase.verifyEqual(out, 'MRM');
            testCase.verifyClass(out, 'char');
            testCase.verifyEqual(toPlain(["a" "b"]), {'a', 'b'});
        end

        function testEnumBecomesName(testCase)
            testCase.verifyEqual(toPlain(ExportFixture.Color.RED), 'RED');
            testCase.verifyEqual(toPlain(ExportFixture.Level.HIGH), 'HIGH');
        end

        function testFunctionHandleBecomesText(testCase)
            f = @(z) 1;
            testCase.verifyEqual(toPlain(f), func2str(f));
        end

        function testStoredPropertiesIncludedDerivedExcluded(testCase)
            s = toPlain(ExportFixture.Node(3), includePrefixes = "ExportFixture.");
            testCase.assertTrue(isstruct(s));
            testCase.verifyTrue(isfield(s, 'value'));
            testCase.verifyEqual(s.value, 3);
            testCase.verifyTrue(isfield(s, 'hiddenValue'));
            testCase.verifyEqual(s.hiddenValue, 42);
            testCase.verifyFalse(isfield(s, 'doubled'));
            testCase.verifyFalse(isfield(s, 'scratch'));
            testCase.verifyFalse(isfield(s, 'LIMIT'));
        end

        function testOverloadedStructIsBypassed(testCase)
            s = toPlain(ExportFixture.Overloaded(), includePrefixes = "ExportFixture.");
            testCase.assertTrue(isstruct(s));
            testCase.verifyEqual(s.shown, 1);
            testCase.verifyTrue(isfield(s, 'hidden'));
            testCase.verifyEqual(s.hidden, 2);
        end

        function testIndependentPropertiesKeepSharedObjects(testCase)
            % Upstream solvers share handles between properties (shallow
            % copies); each top-level property must still hold its own data.
            shared = ExportFixture.Node(5);
            root = ExportFixture.Node(0);
            root.value = shared;
            root.next = shared;
            shared.next = root;
            s = toPlain(root, includePrefixes = "ExportFixture.", ...
                independentProperties = true);
            testCase.assertTrue(isstruct(s) && isstruct(s.value) && isstruct(s.next));
            testCase.verifyEqual(s.value.value, 5);
            testCase.verifyEqual(s.next.value, 5);
            % A reference back to the top object still ends in a marker.
            testCase.verifyEqual(s.value.next, '<cycle:ExportFixture.Node>');
            % Without the option, one of the two references is a marker.
            d = toPlain(root, includePrefixes = "ExportFixture.");
            testCase.verifyTrue(xor(ischar(d.value), ischar(d.next)));
        end

        function testCycleIsMarked(testCase)
            a = ExportFixture.Node(1);
            b = ExportFixture.Node(2);
            a.next = b;
            b.next = a;
            s = toPlain(a, includePrefixes = "ExportFixture.");
            testCase.assertTrue(isstruct(s) && isstruct(s.next));
            testCase.verifyEqual(s.next.value, 2);
            testCase.verifyEqual(s.next.next, '<cycle:ExportFixture.Node>');
        end

        function testObjectArrayKeepsSize(testCase)
            nodes = [ExportFixture.Node(1) ExportFixture.Node(2) ExportFixture.Node(3)];
            s = toPlain(nodes, includePrefixes = "ExportFixture.");
            testCase.assertTrue(isstruct(s));
            testCase.verifySize(s, [1 3]);
            testCase.verifyEqual([s.value], [1 2 3]);
        end

        function testLastWarningIsKept(testCase)
            % builtin struct() on an object sets lastwarn even with its
            % warning off; toPlain must leave the caller's last warning.
            lastwarn('m', 'a:b');
            s = toPlain(ExportFixture.Node(1), includePrefixes = "ExportFixture.");
            [message, id] = lastwarn;
            testCase.assertTrue(isstruct(s));
            testCase.verifyEqual(message, 'm');
            testCase.verifyEqual(id, 'a:b');
        end

        function testUnincludedObjectIsSkipped(testCase)
            testCase.verifyEqual(toPlain(containers.Map()), '<skipped:containers.Map>');
            testCase.verifyEqual(toPlain(ExportFixture.Node(1)), '<skipped:ExportFixture.Node>');
        end

        function testStructAndCellRecurse(testCase)
            s = toPlain(struct('a', {"x", ExportFixture.Color.RED}));
            testCase.assertTrue(isstruct(s));
            testCase.verifySize(s, [1 2]);
            testCase.verifyEqual(s(1).a, 'x');
            testCase.verifyEqual(s(2).a, 'RED');
            testCase.verifyEqual(toPlain({"y", @sin}), {'y', 'sin'});
        end

    end

end
