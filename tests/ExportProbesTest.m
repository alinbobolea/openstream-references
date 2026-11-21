classdef ExportProbesTest < matlab.unittest.TestCase
    %EXPORTPROBESTEST Unit tests for exportProbes.
    %
    % TestData.FakeProbeSolver stands for a solved Mixture solver and
    % TestData.FakeProbeField for its states: five nodes, the values simple
    % functions of the offset of the state (mixtureInit: offsets 1, 2, 3;
    % mixture: offset 9), CHF = 100 + the node index, and a copyFlowProperties
    % that refuses a target whose mesh is not the source's.

    properties
        probes
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

        function runProbes(testCase)
            testCase.probes = exportProbes(TestData.FakeProbeSolver(), ...
                mixtureClass = "TestData.FakeProbeField");
        end

    end

    methods (Test)

        function testThereAreFourProbesAndEveryOneCompleted(testCase)
            names = sort(string(fieldnames(testCase.probes)))';
            testCase.verifyEqual(names, ["chf" "construct" "copyAll" "copyMismatch"]);
            for name = names
                probe = testCase.probes.(name);
                testCase.verifyTrue(probe.ok, char(name));
                testCase.verifyEqual(probe.errorId, '', char(name));
                testCase.verifyEqual(probe.errorMessage, '', char(name));
            end
        end

        function testConstructBuildsAnObjectOfTheClassWithTheTwoArguments(testCase)
            testCase.verifyEqual(testCase.probes.construct.class, ...
                'TestData.FakeProbeField');
        end

        function testChfIsAskedForSomeNodesAndForAll(testCase)
            probe = testCase.probes.chf;
            testCase.verifyEqual(probe.zIdx, [1; 3; 5]);
            testCase.verifyEqual(probe.values, [101; 103; 105]);
            testCase.verifyEqual(probe.full, (101:105).');
        end

        function testCopyAllCopiesEveryRowFromTheFirstStateIntoACopyOfTheSecond(testCase)
            probe = testCase.probes.copyAll;
            testCase.verifyEqual(probe.sourceW, (2:6).');
            testCase.verifyEqual(probe.sourceH, (11:15).');
            testCase.verifyEqual(probe.targetBeforeW, (3:7).');
            testCase.verifyEqual(probe.targetBeforeH, (21:25).');
            testCase.verifyEqual(probe.targetAfterW, probe.sourceW);
            testCase.verifyEqual(probe.targetAfterH, probe.sourceH);
        end

        function testCopyIntoAnObjectOffTheMeshIsRecordedAsTheAnswer(testCase)
            probe = testCase.probes.copyMismatch;
            testCase.verifyTrue(probe.threw);
            testCase.verifyEqual(probe.thrownId, 'Fake:mismatch');
            testCase.verifySubstring(probe.thrownMessage, 'mismatched');
        end

        function testTheProbesDoNotChangeTheSolver(testCase)
            solver = TestData.FakeProbeSolver();
            before = solver.mixtureInit(2).W;
            exportProbes(solver, mixtureClass = "TestData.FakeProbeField");
            testCase.verifyEqual(solver.mixtureInit(2).W, before);
        end

        function testAProbeThatErrorsIsRecordedAndTheOthersStillRun(testCase)
            probes = exportProbes(TestData.FakeProbeSolver(), ...
                mixtureClass = "TestData.NoSuchClass");
            testCase.verifyFalse(probes.construct.ok);
            testCase.verifyNotEmpty(probes.construct.errorId);
            testCase.verifyNotEmpty(probes.construct.errorMessage);
            testCase.verifyFalse(probes.copyMismatch.ok);
            testCase.verifyTrue(probes.chf.ok);
            testCase.verifyTrue(probes.copyAll.ok);
        end

        function testASolverThatIsNotAMixtureSolverGivesAnEmptyStruct(testCase)
            probes = exportProbes(struct('other', 1));
            testCase.verifyEmpty(fieldnames(probes));
        end

        function testTheWarningStateIsRestored(testCase)
            warning('on', 'MATLAB:ExportProbesTest:probe');
            exportProbes(TestData.FakeProbeSolver(), ...
                mixtureClass = "TestData.FakeProbeField");
            state = warning('query', 'MATLAB:ExportProbesTest:probe');
            testCase.verifyEqual(state.state, 'on');
        end

    end

end
