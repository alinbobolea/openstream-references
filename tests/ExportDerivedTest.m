classdef ExportDerivedTest < matlab.unittest.TestCase
    %EXPORTDERIVEDTEST Unit tests for exportDerived.
    %
    % The classes in tests/+TestData (FakeSolver, FakeMixture, FakeLiquid)
    % stand for the mixture solver and its states with the kinds of methods
    % that exportDerived has to handle: a node index that is left out, two
    % outputs, a wall temperature, values of the previous state, a call that
    % only works for one node, a call that always fails, inputs that no one can
    % give, and the methods that must not be listed (private, protected,
    % static, constructor, accessors, the excluded base class). The solver has
    % three states in mixtureInit (offsets 10, 20, 30) and one in mixture
    % (offset 0); the values below are the formulas of the fake methods.

    properties
        derived
    end

    methods (TestClassSetup)

        function addPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            here = fileparts(mfilename('fullpath'));
            testCase.applyFixture(PathFixture(here));
            testCase.applyFixture(PathFixture(fullfile(here, '..', 'matlab')));
        end

    end

    methods (TestMethodSetup)

        function runExport(testCase)
            solver = TestData.FakeSolver(3);
            testCase.derived = ExportDerivedTest.exportFake(solver);
        end

    end

    methods (Static)

        function derived = exportFake(solver)
            % Output of the summary is not part of what is tested.
            derived = [];
            evalc('derived = exportDerived(solver, includePrefixes = "TestData.", excludedClasses = "TestData.FakeBase", objectClasses = "TestData.FakeBase");');
        end

        function names = methodNames(derived, className)
            list = derived.methods;
            names = sort(string({list(strcmp({list.class}, className)).name}));
        end

    end

    methods (Test)

        function testRootsAreTheObjectArrayPropertiesOnly(testCase)
            names = sort(string(fieldnames(testCase.derived)))';
            testCase.verifyEqual(names, ["methods" "mixture" "mixtureInit"]);
            testCase.verifySize(testCase.derived.mixtureInit, [1 3]);
            testCase.verifySize(testCase.derived.mixture, [1 1]);
        end

        function testDefaultsFindNothingInClassesOutsideTheSolverPackage(testCase)
            % With the defaults (classes of the package Solvers), the fake
            % classes are not roots: the defaults are not the test's options.
            solver = TestData.FakeSolver(2);
            derived = [];
            evalc('derived = exportDerived(solver);');
            testCase.verifyEqual(fieldnames(derived), {'methods'});
            testCase.verifyEmpty(derived.methods);
        end

        function testMethodListHoldsEveryPublicMethodWithAValue(testCase)
            expected = sort(["VALUE" "PAIR" "TWALL" "NEEDSTWALL" "UP" "MCT" ...
                "WITHOLD" "STRUCTVALUE" "SCALARONLY" "SCALARTEXT" "ALWAYSFAILS" ...
                "TRAILING" "NEEDSOTHER" "NOOUTPUT" "WARNS" "NOINDEX" "HIDDENVALUE"]);
            testCase.verifyEqual(ExportDerivedTest.methodNames( ...
                testCase.derived, 'TestData.FakeMixture'), expected);
            testCase.verifyEqual(ExportDerivedTest.methodNames( ...
                testCase.derived, 'TestData.FakeLiquid'), ...
                sort(["TEMPERATURE" "NU" "SEESPARENT"]));
        end

        function testMethodsThatMustNotBeListedAreNotListed(testCase)
            all = string({testCase.derived.methods.name});
            for name = ["PRIVATEVALUE" "PROTECTEDVALUE" "STATICVALUE" "BASEMETHOD" ...
                    "FakeMixture" "FakeLiquid" "set.OFFSET" "get.dependentProperty" ...
                    "delete" "addlistener"]
                testCase.verifyFalse(ismember(name, all), char(name));
            end
        end

        function testEachClassIsListedOnceHoweverManyStates(testCase)
            classes = string({testCase.derived.methods.class});
            testCase.verifyEqual(numel(classes), 17 + 3);
            testCase.verifyEqual(numel(unique(string({testCase.derived.methods.name}) ...
                + "@" + classes)), 20);
        end

        function testMethodsThatCannotBeCalledAreListedWithTheirReason(testCase)
            list = testCase.derived.methods;
            byName = containers.Map({list.name}, num2cell(1:numel(list)));
            other = list(byName('NEEDSOTHER'));
            testCase.verifyFalse(other.exported);
            testCase.verifySubstring(other.reason, 'param1, param2');
            noOutput = list(byName('NOOUTPUT'));
            testCase.verifyFalse(noOutput.exported);
            testCase.verifySubstring(noOutput.reason, 'no output');
            value = list(byName('VALUE'));
            testCase.verifyTrue(value.exported);
            testCase.verifyEqual(value.reason, '');
            testCase.verifyEqual(value.inputNames, {'zIdx'});
            testCase.verifyEqual(value.outputNames, {'v'});
            pair = list(byName('PAIR'));
            testCase.verifyEqual(pair.outputNames, {'a', 'b'});
        end

        function testNotExportedMethodsHaveNoValue(testCase)
            values = testCase.derived.mixtureInit(1).values;
            testCase.verifyFalse(isfield(values, 'NEEDSOTHER'));
            testCase.verifyFalse(isfield(values, 'NOOUTPUT'));
            testCase.verifyFalse(isfield(values, 'BASEMETHOD'));
        end

        function testValuesAreThoseOfTheCallsWithoutANodeIndex(testCase)
            for k = 1:3
                v = testCase.derived.mixtureInit(k).values;
                offset = 10 * k;
                testCase.verifyEqual(v.VALUE, offset + (1:3).');
                testCase.verifyEqual(v.HIDDENVALUE, 50 + offset + (1:3).');
                testCase.verifyEqual(v.NOINDEX, 40 + offset);
                testCase.verifyEqual(v.TRAILING, offset + (1:3).');
                testCase.verifyEqual(v.WARNS, 1);
            end
            testCase.verifyEqual(testCase.derived.mixture.values.VALUE, (1:3).');
        end

        function testMethodWithTwoOutputsGivesAStructOfThem(testCase)
            v = testCase.derived.mixtureInit(2).values;
            testCase.verifyEqual(fieldnames(v.PAIR), {'a'; 'b'});
            testCase.verifyEqual(v.PAIR.a, 20 + (1:3).');
            testCase.verifyEqual(v.PAIR.b, 10 * (1:3).');
            testCase.verifyEqual(fieldnames(v.TWALL), {'twall'; 'tbulk'});
            testCase.verifyEqual(v.TWALL.twall, [120 + (1:3).', 220 + (1:3).']);
            testCase.verifyEqual(v.TWALL.tbulk, 300 + (1:3).');
        end

        function testStructValueOfAMethodIsKept(testCase)
            v = testCase.derived.mixtureInit(3).values.STRUCTVALUE;
            testCase.verifyEqual(v.FIRST, (1:3).');
            testCase.verifyEqual(v.SECOND, 30 * ones(3, 1));
        end

        function testWallTemperatureIsTheFirstOutputOfTheStatesOwnTWALL(testCase)
            for k = 1:3
                offset = 10 * k;
                testCase.verifyEqual( ...
                    testCase.derived.mixtureInit(k).values.NEEDSTWALL, ...
                    100 + offset + 2 * (1:3).');
            end
        end

        function testFirstStateHasNoPreviousState(testCase)
            first = testCase.derived.mixtureInit(1);
            testCase.verifyEqual(first.values.WITHOLD, []);
            testCase.verifyEqual(first.errorId.WITHOLD, 'References:NoPreviousState');
            testCase.verifyNotEmpty(first.errorMessage.WITHOLD);
            only = testCase.derived.mixture;
            testCase.verifyEqual(only.errorId.WITHOLD, 'References:NoPreviousState');
        end

        function testLaterStatesUseTheValuesOfThePreviousState(testCase)
            % UP and MCT change by 10 each between the states, per node.
            for k = 2:3
                state = testCase.derived.mixtureInit(k);
                testCase.verifyEqual(state.errorId.WITHOLD, '');
                testCase.verifyEqual(state.values.WITHOLD, 20 * ones(3, 1));
            end
        end

        function testMethodThatNeedsOneNodeIsCalledPerNode(testCase)
            for k = 1:3
                state = testCase.derived.mixtureInit(k);
                offset = 10 * k;
                testCase.verifyEqual(state.values.SCALARONLY, offset + 7 * (1:3).');
                testCase.verifyTrue(state.nodeByNode.SCALARONLY);
                testCase.verifyEqual(state.errorId.SCALARONLY, '');
                testCase.verifyEqual(state.errorMessage.SCALARONLY, '');
                testCase.verifyFalse(state.nodeByNode.VALUE);
            end
        end

        function testNodeByNodeOutputThatIsNotNumericKeepsTheFirstError(testCase)
            state = testCase.derived.mixtureInit(1);
            testCase.verifyEqual(state.values.SCALARTEXT, []);
            testCase.verifyEqual(state.errorId.SCALARTEXT, 'Fake:vector');
            testCase.verifyEqual(state.errorMessage.SCALARTEXT, 'one node at a time');
            testCase.verifyFalse(state.nodeByNode.SCALARTEXT);
        end

        function testMethodThatAlwaysFailsIsRecordedAndDoesNotStopTheExport(testCase)
            for k = 1:3
                state = testCase.derived.mixtureInit(k);
                testCase.verifyEqual(state.values.ALWAYSFAILS, []);
                testCase.verifyEqual(state.errorId.ALWAYSFAILS, 'Fake:always');
                testCase.verifyEqual(state.errorMessage.ALWAYSFAILS, ...
                    'this method always fails');
                testCase.verifyFalse(state.nodeByNode.ALWAYSFAILS);
                % The methods after it were called.
                testCase.verifyEqual(state.errorId.VALUE, '');
            end
        end

        function testChildrenAreCalledWithTheWallTemperatureOfTheirParent(testCase)
            for k = 1:3
                offset = 10 * k;
                liquid = testCase.derived.mixtureInit(k).children.liquid;
                % NU only works for one node: rows of twall, one per node.
                testCase.verifyEqual(liquid.values.NU, 100 + offset + 1.5 * (1:3).');
                testCase.verifyTrue(liquid.nodeByNode.NU);
                testCase.verifyEqual(liquid.errorId.NU, '');
                testCase.verifyEqual(liquid.values.TEMPERATURE, offset + 1000 + (1:3).');
                testCase.verifyEqual(liquid.values.SEESPARENT, offset);
            end
        end

        function testEveryChildPropertyIsFollowed(testCase)
            children = testCase.derived.mixtureInit(1).children;
            testCase.verifyEqual(sort(string(fieldnames(children)))', ["liquid" "vapor"]);
            testCase.verifyEqual(children.vapor.values.SEESPARENT, 10);
        end

        function testStatesOfARootHaveTheSameFields(testCase)
            % The three states form one struct array: same fields, in order.
            state = testCase.derived.mixtureInit;
            testCase.verifyEqual(fieldnames(state), ...
                {'values'; 'errorId'; 'errorMessage'; 'nodeByNode'; 'children'});
            testCase.verifyEqual(fieldnames(state(1).values), fieldnames(state(3).values));
        end

        function testWarningsAreSilencedAndRestored(testCase)
            before = warning('query', 'Fake:warns');
            solver = TestData.FakeSolver(1);
            testCase.verifyWarningFree(@() ExportDerivedTest.exportFake(solver));
            after = warning('query', 'Fake:warns');
            testCase.verifyEqual(after.state, before.state);
        end

        function testResultCanBeSavedAfterToPlain(testCase)
            % runCases saves toPlain(derived) with save -v7.
            import matlab.unittest.fixtures.TemporaryFolderFixture
            folder = testCase.applyFixture(TemporaryFolderFixture).Folder;
            plain = toPlain(testCase.derived);
            file = fullfile(folder, 'derived.mat');
            save(file, 'plain', '-v7');
            loaded = load(file);
            testCase.verifyEqual(loaded.plain.mixtureInit(2).values.VALUE, 20 + (1:3).');
            testCase.verifyEqual(loaded.plain.methods(1).class, 'TestData.FakeMixture');
        end

    end

end
