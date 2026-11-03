classdef RunTargetTest < matlab.unittest.TestCase
    %RUNTARGETTEST Unit tests for the target guard and the dispatch of
    % runTarget.
    %
    % The real targets are not run. For the dispatch tests the functions
    % runTarget calls are shadowed by stubs in a temporary folder placed
    % first on the path; each stub records its name and arguments, so the
    % tests see which function each target calls, with what, and in which
    % order.

    properties
        stubFolder
    end

    methods (TestClassSetup)

        function addPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            here = fileparts(mfilename('fullpath'));
            testCase.applyFixture(PathFixture(fullfile(here, '..', 'matlab')));
        end

    end

    methods (Static)

        function clearCalls()
            if isappdata(0, 'RunTargetTestCalls')
                rmappdata(0, 'RunTargetTestCalls');
            end
        end

        function writeStub(folder, name)
            % A function NAME that appends {NAME, its arguments} to the
            % list kept in the root appdata RunTargetTestCalls.
            lines = [ ...
                "function NAME(varargin)"
                "calls = getappdata(0, 'RunTargetTestCalls');"
                "if isempty(calls)"
                "    calls = {};"
                "end"
                "calls{end+1} = {'NAME', varargin};"
                "setappdata(0, 'RunTargetTestCalls', calls);"
                "end"];
            text = replace(strjoin(reshape(lines, 1, []), newline), "NAME", name);
            fid = fopen(fullfile(folder, name + ".m"), 'w');
            fprintf(fid, '%s\n', text);
            fclose(fid);
        end

        function calls = expectedCalls(target)
            % The calls runTarget(TARGET) makes, in order: {function,
            % argument texts}.
            switch target
                case "tutorial1"
                    calls = { ...
                        'runCases', ["cases/tutorial1.json" "upstream/openstream" ...
                            "results/tutorial1"]; ...
                        'exportReferences', ["cases/tutorial1.json" ...
                            "upstream/openstream" "results/tutorial1-upstream"]; ...
                        'writeFormatFixture', "fixtures/format_fixture.mat"};
                case "nuthos15-bartolomey"
                    calls = {'runDatasetCases', ["cases/nuthos15-bartolomey.json" ...
                        "upstream/openstream" "upstream/openstream-database" ...
                        "results/nuthos15-bartolomey"]};
                case "input-fixture"
                    calls = {'exportInputFixture', ["cases/input-fixture.json" ...
                        "upstream/openstream" "results/input-fixture"]};
                case "semantics-fixture"
                    calls = {'exportSemanticsFixture', ["cases/semantics-fixture.json" ...
                        "upstream/openstream" "results/semantics-fixture"]};
                otherwise
                    error('RunTargetTest:noExpectation', 'No expectation for %s', target);
            end
        end

        function names = workflowTargets()
            % The target choices of the workflow file.
            here = fileparts(mfilename('fullpath'));
            names = RunTargetTest.targetsInWorkflowText(fileread( ...
                fullfile(here, '..', '.github', 'workflows', 'references.yml')));
        end

        function names = targetsInWorkflowText(text)
            % The list items under the first "options:" line of TEXT, up to
            % the first line that is not an item (a string row).
            lines = splitlines(string(text));
            start = find(strtrim(lines) == "options:", 1);
            names = strings(1, 0);
            if isempty(start)
                return
            end
            for k = start+1:numel(lines)
                item = strtrim(lines(k));
                if ~startsWith(item, "- ")
                    break
                end
                names(end+1) = strtrim(extractAfter(item, "- ")); %#ok<AGROW>
            end
        end

    end

    methods

        function stubTheExporters(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            import matlab.unittest.fixtures.PathFixture
            import matlab.unittest.fixtures.CurrentFolderFixture
            here = fileparts(mfilename('fullpath'));
            % The repository root as current folder: the stubs are found by
            % the path alone, whatever folder the tests were started in.
            testCase.applyFixture(CurrentFolderFixture(fullfile(here, '..')));
            fixture = testCase.applyFixture(TemporaryFolderFixture);
            testCase.stubFolder = fixture.Folder;
            for name = ["runCases" "exportReferences" "writeFormatFixture" ...
                    "runDatasetCases" "exportInputFixture" "exportSemanticsFixture"]
                RunTargetTest.writeStub(testCase.stubFolder, name);
            end
            testCase.applyFixture(PathFixture(testCase.stubFolder));
            RunTargetTest.clearCalls();
            testCase.addTeardown(@RunTargetTest.clearCalls);
        end

        function calls = recorded(~)
            calls = getappdata(0, 'RunTargetTestCalls');
            if isempty(calls)
                calls = {};
            end
        end

    end

    methods (Test)

        function testUnknownTargetIsRejected(testCase)
            testCase.verifyError(@() runTarget('nope'), ...
                'References:UnknownTarget');
        end

        function testOtherUnknownTargetsAreRejected(testCase)
            % Also the empty text and the right name in the wrong case.
            known = knownTargets();
            for bad = ["nonsense" "" "Semantics-Fixture" "semantics-fixture " "tutorial"]
                testCase.assertFalse(ismember(bad, known), ...
                    'the name is not a known target');
                testCase.verifyError(@() runTarget(bad), ...
                    'References:UnknownTarget', sprintf('"%s"', bad));
            end
        end

        function testUnknownTargetMessageListsTheKnownTargets(testCase)
            % The message names the target asked for and every known one.
            try
                runTarget("nonsense");
                testCase.verifyFail('runTarget accepted an unknown target');
            catch err
                testCase.verifyEqual(err.identifier, 'References:UnknownTarget');
                testCase.verifySubstring(err.message, 'nonsense');
                for name = knownTargets()
                    testCase.verifySubstring(err.message, char(name));
                end
            end
        end

        function testKnownTargetsListsTheTargets(testCase)
            names = knownTargets();
            testCase.verifyClass(names, 'string');
            testCase.verifyTrue(isrow(names));
            testCase.verifyEqual(numel(unique(names)), numel(names));
            for name = ["tutorial1" "nuthos15-bartolomey" "input-fixture" ...
                    "semantics-fixture"]
                testCase.verifyTrue(ismember(name, names), char(name));
            end
        end

        function testNothingRunsForAnUnknownTarget(testCase)
            % With every exporter stubbed, a rejected target calls none.
            testCase.stubTheExporters();
            testCase.verifyError(@() runTarget("nonsense"), ...
                'References:UnknownTarget');
            testCase.verifyEmpty(testCase.recorded());
        end

        function testEachTargetCallsItsExporter(testCase)
            % Every known target, each with its own calls and arguments; a
            % target that called another one's exporter, or none (no case in
            % runTarget), or the right one with other paths, fails; so does a
            % target added to knownTargets that has no expectation here.
            testCase.stubTheExporters();
            targets = knownTargets();
            for target = targets
                RunTargetTest.clearCalls();
                runTarget(target);
                calls = testCase.recorded();
                expected = RunTargetTest.expectedCalls(target);
                testCase.assertNumElements(calls, size(expected, 1), char(target));
                for k = 1:numel(calls)
                    testCase.verifyEqual(calls{k}{1}, expected{k, 1}, char(target));
                    testCase.verifyEqual( ...
                        string(cellfun(@char, calls{k}{2}, 'UniformOutput', false)), ...
                        expected{k, 2}, sprintf('%s: %s', char(target), expected{k, 1}));
                end
            end
        end

        function testSemanticsTargetCallsOnlyItsExporter(testCase)
            testCase.stubTheExporters();
            runTarget("semantics-fixture");
            calls = testCase.recorded();
            testCase.assertNumElements(calls, 1);
            testCase.verifyEqual(calls{1}{1}, 'exportSemanticsFixture');
            testCase.verifyNumElements(calls{1}{2}, 3);
        end

        function testWorkflowOffersTheKnownTargets(testCase)
            % The choices of the workflow input are the targets runTarget
            % accepts: a target added to one and not the other fails here.
            offered = RunTargetTest.workflowTargets();
            testCase.assertNotEmpty(offered, 'the workflow lists its targets');
            testCase.verifyEqual(sort(offered), sort(knownTargets()));
        end

        function testWorkflowReaderFindsTheOptionItems(testCase)
            % Negative controls for the reader used above, on small texts:
            % it takes the items of the options list, stops at the next
            % key, and finds nothing where there is no list.
            text = join(["    inputs:" "      target:" "        options:" ...
                "          - one" "          - two-parts" "        default: one" ...
                "          - not-an-option"], newline);
            testCase.verifyEqual(RunTargetTest.targetsInWorkflowText(text), ...
                ["one" "two-parts"]);
            testCase.verifyEqual(RunTargetTest.targetsInWorkflowText("a: b"), ...
                strings(1, 0));
            text = join(["options:" "  - one" "  - two"], newline);
            testCase.verifyEqual(RunTargetTest.targetsInWorkflowText(text), ...
                ["one" "two"]);
        end

    end

end
