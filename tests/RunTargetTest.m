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
            if isappdata(0, 'RunTargetTestFailing')
                rmappdata(0, 'RunTargetTestFailing');
            end
        end

        function failing(names)
            % The stubs named in NAMES (a string row) record their call and
            % then error with RunTargetTest:stubFailure.
            setappdata(0, 'RunTargetTestFailing', cellstr(names));
        end

        function writeStub(folder, name)
            % A function NAME that appends {NAME, its arguments} to the
            % list kept in the root appdata RunTargetTestCalls and then, when
            % NAME is in the list RunTargetTestFailing, errors.
            lines = [ ...
                "function NAME(varargin)"
                "calls = getappdata(0, 'RunTargetTestCalls');"
                "if isempty(calls)"
                "    calls = {};"
                "end"
                "calls{end+1} = {'NAME', varargin};"
                "setappdata(0, 'RunTargetTestCalls', calls);"
                "failing = getappdata(0, 'RunTargetTestFailing');"
                "if ~isempty(failing) && any(strcmp(failing, 'NAME'))"
                "    error('RunTargetTest:stubFailure', 'NAME failed on purpose');"
                "end"
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
                case "input-fixture-windows"
                    calls = {'exportInputFixture', ...
                        ["cases/input-fixture-windows.json" "upstream/openstream" ...
                        "results/input-fixture-windows"]};
                case "extension"
                    % Both fixtures in one session, the semantics one first.
                    calls = { ...
                        'exportSemanticsFixture', ["cases/semantics-fixture.json" ...
                            "upstream/openstream" "results/semantics-fixture"]; ...
                        'exportInputFixture', ["cases/input-fixture.json" ...
                            "upstream/openstream" "results/input-fixture"]};
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

        function text = workflowText()
            here = fileparts(mfilename('fullpath'));
            text = fileread(fullfile(here, '..', '.github', 'workflows', 'references.yml'));
        end

        function block = jobBlock(text, job)
            % The lines of the job JOB of workflow TEXT: from its key (two
            % spaces of indent) up to the next key of that indent, as one
            % string. Empty when there is no such job.
            lines = splitlines(string(text));
            start = find(lines == "  " + job + ":", 1);
            block = "";
            if isempty(start)
                return
            end
            stop = numel(lines);
            for k = start+1:numel(lines)
                if ~isempty(regexp(char(lines(k)), '^  [A-Za-z][\w-]*:\s*$', 'once'))
                    stop = k - 1;
                    break
                end
            end
            block = string(strjoin(reshape(lines(start:stop), 1, []), newline));
        end

        function value = firstMatch(text, pattern)
            % The first capture of PATTERN in TEXT, or "" when it does not match.
            tokens = regexp(char(text), pattern, 'tokens', 'once');
            value = "";
            if ~isempty(tokens)
                value = string(tokens{1});
            end
        end

        function entries = manifestEntries(file)
            % The entries of cases/FILE as a 1xN cell of structs, as jsondecode
            % gives them (a struct array when all have the same fields).
            here = fileparts(mfilename('fullpath'));
            entries = jsondecode(fileread(fullfile(here, '..', 'cases', file)));
            if isstruct(entries)
                entries = num2cell(entries);
            end
            entries = reshape(entries, 1, []);
        end

        function e = entryNamed(entries, name)
            % The one entry of the cell ENTRIES named NAME ([] when none).
            e = [];
            for k = 1:numel(entries)
                if strcmp(entries{k}.name, name)
                    e = entries{k};
                    return
                end
            end
        end

        function [bad, withRun] = stepsWithoutBash(block)
            % The steps of the job text BLOCK (a step starts at a line of six
            % spaces and "- ") that have a run key but no "shell: bash":
            % BAD is the list of their numbers, WITHRUN the number of steps
            % that have a run key. The key may be on the dash line
            % ("      - run:") or on a line of its own ("        run:").
            lines = splitlines(string(block));
            starts = find(startsWith(lines, "      - "));
            bad = [];
            withRun = 0;
            for k = 1:numel(starts)
                stop = numel(lines);
                if k < numel(starts)
                    stop = starts(k+1) - 1;
                end
                step = lines(starts(k):stop);
                hasRun = any(startsWith(step, ["      - run:" "        run:"]));
                hasShell = any(startsWith(step, ...
                    ["      - shell: bash" "        shell: bash"]));
                withRun = withRun + hasRun;
                if hasRun && ~hasShell
                    bad(end+1) = k; %#ok<AGROW>
                end
            end
        end

        function names = windowsSourceNames()
            % The entries of the Linux manifest whose paths the Windows
            % manifest repeats: ext_session_01 to 12 and 29 to 33.
            numbers = [1:12 29:33];
            names = strings(1, numel(numbers));
            for k = 1:numel(numbers)
                names(k) = sprintf('ext_session_%02d', numbers(k));
            end
        end

        function [ok, why] = windowsMatchesLinux(windowsEntries, linuxEntries)
            % True when WINDOWSENTRIES (a 1xN cell) are exactly the 17 entries
            % win_legalpath_01 to 17, each of kind legalpath with the fields
            % name, kind and path only, and each path equal to the path of the
            % Linux entry it repeats (see windowsSourceNames).
            ok = false;
            sources = RunTargetTest.windowsSourceNames();
            if numel(windowsEntries) ~= numel(sources)
                why = sprintf('%d entries, expected %d', numel(windowsEntries), numel(sources));
                return
            end
            for k = 1:numel(sources)
                e = windowsEntries{k};
                expectedName = sprintf('win_legalpath_%02d', k);
                if ~isequal(sort(fieldnames(e)), {'kind'; 'name'; 'path'})
                    why = sprintf('entry %d has other fields than name, kind and path', k);
                    return
                end
                if ~strcmp(e.name, expectedName)
                    why = sprintf('entry %d is named %s, expected %s', k, e.name, expectedName);
                    return
                end
                if ~strcmp(e.kind, 'legalpath')
                    why = sprintf('%s has kind %s', e.name, e.kind);
                    return
                end
                source = RunTargetTest.entryNamed(linuxEntries, char(sources(k)));
                if isempty(source)
                    why = sprintf('no entry %s in the Linux manifest', sources(k));
                    return
                end
                if ~strcmp(source.kind, 'legalpath') || ~strcmp(e.path, source.path)
                    why = sprintf('%s does not repeat the path of %s', e.name, sources(k));
                    return
                end
            end
            ok = true;
            why = '';
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
                    "semantics-fixture" "extension" "input-fixture-windows"]
                testCase.verifyTrue(ismember(name, names), char(name));
            end
        end

        function testExtensionAndWindowsTargetsAreKnown(testCase)
            names = knownTargets();
            testCase.verifyTrue(ismember("extension", names));
            testCase.verifyTrue(ismember("input-fixture-windows", names));
            testCase.verifyEqual(numel(names), 6);
        end

        function testExtensionTargetCallsBothExportersInOrder(testCase)
            testCase.stubTheExporters();
            runTarget("extension");
            calls = testCase.recorded();
            testCase.assertNumElements(calls, 2);
            testCase.verifyEqual(calls{1}{1}, 'exportSemanticsFixture');
            testCase.verifyEqual(calls{2}{1}, 'exportInputFixture');
        end

        function testWindowsTargetCallsOnlyTheInputExporterOnItsManifest(testCase)
            testCase.stubTheExporters();
            runTarget("input-fixture-windows");
            calls = testCase.recorded();
            testCase.assertNumElements(calls, 1);
            testCase.verifyEqual(calls{1}{1}, 'exportInputFixture');
            args = string(cellfun(@char, calls{1}{2}, 'UniformOutput', false));
            testCase.verifyEqual(args(1), "cases/input-fixture-windows.json");
            testCase.verifyEqual(args(3), "results/input-fixture-windows");
        end

        function testExtensionRunsTheSecondFixtureWhenTheFirstFails(testCase)
            % The failure of one fixture does not hide the other: both are
            % run, and the target then errors naming the one that failed.
            testCase.stubTheExporters();
            RunTargetTest.failing("exportSemanticsFixture");
            testCase.verifyError(@() runTarget("extension"), ...
                'References:ExtensionFailed');
            calls = testCase.recorded();
            testCase.assertNumElements(calls, 2);
            testCase.verifyEqual(calls{2}{1}, 'exportInputFixture');
            try
                runTarget("extension");
            catch err
                testCase.verifySubstring(err.message, 'semantics-fixture');
                testCase.verifySubstring(err.message, 'exportSemanticsFixture failed on purpose');
                testCase.verifyFalse(contains(err.message, 'input-fixture failed'));
            end
        end

        function testExtensionErrorsWhenTheSecondFixtureFails(testCase)
            testCase.stubTheExporters();
            RunTargetTest.failing("exportInputFixture");
            testCase.verifyError(@() runTarget("extension"), ...
                'References:ExtensionFailed');
            calls = testCase.recorded();
            testCase.assertNumElements(calls, 2);
            try
                runTarget("extension");
            catch err
                testCase.verifySubstring(err.message, 'input-fixture');
                testCase.verifyFalse(contains(err.message, 'semantics-fixture failed'));
            end
        end

        function testExtensionErrorNamesBothWhenBothFail(testCase)
            testCase.stubTheExporters();
            RunTargetTest.failing(["exportSemanticsFixture" "exportInputFixture"]);
            try
                runTarget("extension");
                testCase.verifyFail('runTarget did not error');
            catch err
                testCase.verifyEqual(err.identifier, 'References:ExtensionFailed');
                testCase.verifySubstring(err.message, 'exportSemanticsFixture failed on purpose');
                testCase.verifySubstring(err.message, 'exportInputFixture failed on purpose');
            end
            testCase.verifyNumElements(testCase.recorded(), 2);
        end

        function testExtensionDoesNotErrorWhenBothSucceed(testCase)
            testCase.stubTheExporters();
            testCase.verifyWarningFree(@() runTarget("extension"));
        end

        function testSingleTargetsStillPropagateTheirErrors(testCase)
            % The tolerance is only for the combined target: a single target's
            % error reaches the caller unchanged.
            testCase.stubTheExporters();
            RunTargetTest.failing("exportInputFixture");
            testCase.verifyError(@() runTarget("input-fixture"), ...
                'RunTargetTest:stubFailure');
            testCase.verifyError(@() runTarget("input-fixture-windows"), ...
                'RunTargetTest:stubFailure');
        end

        function testWindowsManifestHoldsThePathsOfTheLinuxEntries(testCase)
            windows = RunTargetTest.manifestEntries('input-fixture-windows.json');
            linux = RunTargetTest.manifestEntries('input-fixture.json');
            [ok, why] = RunTargetTest.windowsMatchesLinux(windows, linux);
            testCase.verifyTrue(ok, why);
            testCase.verifyNumElements(windows, 17);
            % The Linux entries it repeats are legalpath entries too.
            for name = RunTargetTest.windowsSourceNames()
                source = RunTargetTest.entryNamed(linux, char(name));
                testCase.assertNotEmpty(source, char(name));
                testCase.verifyEqual(source.kind, 'legalpath', char(name));
            end
        end

        function testWindowsManifestValidates(testCase)
            entries = jsondecode(fileread(fullfile(fileparts(mfilename('fullpath')), ...
                '..', 'cases', 'input-fixture-windows.json')));
            testCase.verifyWarningFree(@() validateInputFixtureList(entries, true));
            % Every entry is a legalpath case; none names a file.
            e = RunTargetTest.manifestEntries('input-fixture-windows.json');
            for k = 1:numel(e)
                testCase.verifyEqual(e{k}.kind, 'legalpath');
            end
        end

        function testWindowsManifestCheckRejectsAChangedEntry(testCase)
            % Negative controls for the two checks above, on copies.
            windows = RunTargetTest.manifestEntries('input-fixture-windows.json');
            linux = RunTargetTest.manifestEntries('input-fixture.json');
            testCase.assertTrue(RunTargetTest.windowsMatchesLinux(windows, linux), ...
                'the unchanged manifest matches (otherwise the controls prove nothing)');
            for k = 1:numel(windows)
                changed = windows;
                changed{k}.path = [changed{k}.path 'x'];
                testCase.verifyFalse(RunTargetTest.windowsMatchesLinux(changed, linux), ...
                    sprintf('path of entry %d changed', k));
            end
            changed = windows;
            changed{3}.name = 'win_legalpath_99';
            testCase.verifyFalse(RunTargetTest.windowsMatchesLinux(changed, linux));
            changed = windows;
            changed{3}.kind = 'read';
            testCase.verifyFalse(RunTargetTest.windowsMatchesLinux(changed, linux));
            changed = windows;
            changed{3}.extra = 1;
            testCase.verifyFalse(RunTargetTest.windowsMatchesLinux(changed, linux));
            testCase.verifyFalse(RunTargetTest.windowsMatchesLinux(windows(1:16), linux));
            testCase.verifyFalse(RunTargetTest.windowsMatchesLinux( ...
                windows([2 1 3:17]), linux));
            % Against a Linux manifest in which one repeated path differs.
            changedLinux = linux;
            for k = 1:numel(changedLinux)
                if strcmp(changedLinux{k}.name, 'ext_session_33')
                    changedLinux{k}.path = 'other';
                end
            end
            testCase.verifyFalse(RunTargetTest.windowsMatchesLinux(windows, changedLinux));
        end

        function testValidatorRejectsABrokenWindowsEntry(testCase)
            % Negative controls for the validator run on the manifest: an
            % entry that lost its path, or that has an unknown field.
            windows = RunTargetTest.manifestEntries('input-fixture-windows.json');
            broken = windows;
            broken{5} = rmfield(broken{5}, 'path');
            testCase.verifyError(@() validateInputFixtureList(broken, true), ...
                'References:InvalidInputFixture');
            broken = windows;
            broken{5}.file = 'cases/input-fixture-windows.json';
            testCase.verifyError(@() validateInputFixtureList(broken, true), ...
                'References:InvalidInputFixture');
            broken = windows;
            broken{5}.name = windows{4}.name;
            testCase.verifyError(@() validateInputFixtureList(broken, true), ...
                'References:InvalidInputFixture');
        end

        function testUnknownTargetsStillErrorWithTheNewOnesKnown(testCase)
            % The names of the new targets do not make nearby names known.
            for bad = ["extension " "Extension" "input-fixture-windows " "windows" ...
                    "input-fixture-win"]
                testCase.verifyError(@() runTarget(bad), ...
                    'References:UnknownTarget', sprintf('"%s"', bad));
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
            % accepts, except the one only the Windows job runs: a target
            % added to one and not the other fails here.
            offered = RunTargetTest.workflowTargets();
            testCase.assertNotEmpty(offered, 'the workflow lists its targets');
            testCase.verifyEqual(sort(offered), ...
                sort(setdiff(knownTargets(), "input-fixture-windows")));
            testCase.verifyTrue(ismember("extension", offered));
            testCase.verifyFalse(ismember("input-fixture-windows", offered));
        end

        function testWindowsJobRunsTheWindowsTarget(testCase)
            text = RunTargetTest.workflowText();
            block = RunTargetTest.jobBlock(text, "windows");
            testCase.assertNotEqual(block, "", 'the workflow has a windows job');
            testCase.verifySubstring(block, 'runTarget("input-fixture-windows")');
            testCase.verifySubstring(block, 'runs-on: windows-2025');
            testCase.verifySubstring(block, 'continue-on-error: true');
            testCase.verifySubstring(block, 'needs: tests');
            testCase.verifySubstring(block, ...
                "if: github.event_name == 'workflow_dispatch' && inputs.target == 'extension'");
            testCase.verifySubstring(block, 'path: results/input-fixture-windows/**');
            testCase.verifySubstring(block, 'name: windows-results-${{ github.run_id }}');
            testCase.verifySubstring(block, 'if: always()');
        end

        function testEveryRunStepOfTheWindowsJobUsesBash(testCase)
            block = RunTargetTest.jobBlock(RunTargetTest.workflowText(), "windows");
            testCase.assertNotEqual(block, "");
            [bad, withRun] = RunTargetTest.stepsWithoutBash(block);
            testCase.verifyGreaterThan(withRun, 0, 'the job has run steps');
            testCase.verifyEmpty(bad, 'steps with a run key and no shell: bash');
        end

        function testStepReaderSeesBothFormsOfARunKey(testCase)
            % Negative controls for the reader above, on small job texts.
            head = "  job:" + newline + "    steps:" + newline;
            ok = head + join(["      - name: a" "        shell: bash" "        run: x"], newline);
            [bad, n] = RunTargetTest.stepsWithoutBash(ok);
            testCase.verifyEmpty(bad);
            testCase.verifyEqual(n, 1);
            okDash = head + join(["      - run: x" "        shell: bash"], newline);
            [bad, n] = RunTargetTest.stepsWithoutBash(okDash);
            testCase.verifyEmpty(bad);
            testCase.verifyEqual(n, 1);
            noShell = head + join(["      - name: a" "        run: x"], newline);
            [bad, n] = RunTargetTest.stepsWithoutBash(noShell);
            testCase.verifyEqual(bad, 1);
            testCase.verifyEqual(n, 1);
            noShellDash = head + join(["      - uses: u" "      - run: x" "        env:" "          run: y"], newline);
            [bad, n] = RunTargetTest.stepsWithoutBash(noShellDash);
            testCase.verifyEqual(bad, 2, 'the dash form without a shell is seen');
            testCase.verifyEqual(n, 1, 'a run key nested deeper is not a run step');
            mixed = head + join(["      - run: x" "        shell: bash" ...
                "      - name: b" "        run: y"], newline);
            [bad, n] = RunTargetTest.stepsWithoutBash(mixed);
            testCase.verifyEqual(bad, 2);
            testCase.verifyEqual(n, 2);
        end

        function testWindowsJobUsesTheSamePinsAsTheLinuxJob(testCase)
            % The upstream commit, the repository, the Python version, the
            % MATLAB release and the action versions of the two jobs agree.
            text = RunTargetTest.workflowText();
            windows = RunTargetTest.jobBlock(text, "windows");
            linux = RunTargetTest.jobBlock(text, "references");
            patterns = {'ref: ([0-9a-f]{40})', 'repository: (\S+/openstream)\s', ...
                'python-version: ("[^"]*")', 'release: (R\d{4}[ab])', ...
                'actions/setup-python@(v\d+)', 'actions/checkout@(v\d+)', ...
                'matlab-actions/setup-matlab@(v\d+)', 'matlab-actions/run-command@(v\d+)', ...
                'actions/upload-artifact@(v\d+)'};
            for k = 1:numel(patterns)
                inWindows = RunTargetTest.firstMatch(windows, patterns{k});
                inLinux = RunTargetTest.firstMatch(linux, patterns{k});
                testCase.assertNotEqual(inWindows, "", patterns{k});
                testCase.verifyEqual(inWindows, inLinux, patterns{k});
            end
            testCase.verifySubstring(windows, 'submodules: true');
            testCase.verifySubstring(linux, 'submodules: true');
        end

        function testPinReaderSeesADifferentValue(testCase)
            % Negative control for the pins: the same reader on a job text
            % with one character of the commit changed gives another value.
            text = RunTargetTest.workflowText();
            windows = RunTargetTest.jobBlock(text, "windows");
            changed = replace(windows, "a614c717", "b614c717");
            testCase.assertNotEqual(changed, windows);
            testCase.verifyNotEqual( ...
                RunTargetTest.firstMatch(changed, 'ref: ([0-9a-f]{40})'), ...
                RunTargetTest.firstMatch(RunTargetTest.jobBlock(text, "references"), ...
                'ref: ([0-9a-f]{40})'));
        end

        function testReferencesJobRunsWheneverTheWindowsJobEnds(testCase)
            block = RunTargetTest.jobBlock(RunTargetTest.workflowText(), "references");
            testCase.assertNotEqual(block, "");
            testCase.verifySubstring(block, 'needs: [tests, windows]');
            testCase.verifySubstring(block, ...
                "if: ${{ !cancelled() && github.event_name == 'workflow_dispatch' && needs.tests.result == 'success' }}");
            testCase.verifyFalse(contains(block, 'needs: tests'));
        end

        function testWindowsArtifactIsDownloadedWhereItWasUploaded(testCase)
            % Upload and download use the same name, the download is
            % optional and only for the combined target, and it lands in the
            % folder the upload's paths start in (the artifact does not keep
            % the folders before the wildcard).
            text = RunTargetTest.workflowText();
            up = RunTargetTest.firstMatch(RunTargetTest.jobBlock(text, "windows"), ...
                'name: (windows-results-[^\n]*)');
            down = RunTargetTest.firstMatch(RunTargetTest.jobBlock(text, "references"), ...
                'download-artifact@v7\s+(?:if:[^\n]*\n\s+)?(?:continue-on-error:[^\n]*\n\s+)?with:\s+name: (windows-results-[^\n]*)');
            testCase.assertNotEqual(up, "");
            testCase.verifyEqual(down, up);
            block = RunTargetTest.jobBlock(text, "references");
            testCase.verifySubstring(block, 'actions/download-artifact@v7');
            testCase.verifySubstring(block, "inputs.target == 'extension'");
            testCase.verifySubstring(block, 'path: results/input-fixture-windows');
            step = extractAfter(block, 'actions/download-artifact@v7');
            step = extractBefore(step + "- ", "- ");
            testCase.verifySubstring(step, 'continue-on-error: true');
            % The download comes before the step that opens the pull request.
            testCase.verifyLessThan(strfind(block, 'download-artifact@v7'), ...
                strfind(block, 'Open results pull request'));
        end

        function testDiagnosticsStepWritesBeforeMatlabStarts(testCase)
            text = RunTargetTest.workflowText();
            block = RunTargetTest.jobBlock(text, "references");
            testCase.assertNotEqual(block, "");
            testCase.verifySubstring(block, 'support/runnerDiagnostics.py');
            testCase.verifySubstring(block, 'results/${{ inputs.target }}/runner-diagnostics.txt');
            testCase.verifyLessThan(strfind(block, 'support/runnerDiagnostics.py'), ...
                strfind(block, 'matlab-actions/setup-matlab'));
            testCase.verifyGreaterThan(strfind(block, 'support/runnerDiagnostics.py'), ...
                strfind(block, 'pip freeze'));
            here = fileparts(mfilename('fullpath'));
            testCase.verifyTrue(isfile(fullfile(here, '..', 'support', 'runnerDiagnostics.py')));
        end

        function testPullRequestBodyDoesNotPromiseOneEnvironmentFile(testCase)
            block = RunTargetTest.jobBlock(RunTargetTest.workflowText(), "references");
            testCase.verifySubstring(block, 'Environment: see environment.json in each results folder');
            testCase.verifyFalse(contains(block, 'results/${{ inputs.target }}/environment.json'));
        end

        function testJobBlockReaderFindsTheJobs(testCase)
            % Negative controls for the reader used above, on a small text.
            text = join(["jobs:" "  one:" "    runs-on: x" "  two-parts:" ...
                "    needs: one" "    steps:" "      - run: y"], newline);
            testCase.verifyEqual(RunTargetTest.jobBlock(text, "one"), ...
                join(["  one:" "    runs-on: x"], newline));
            testCase.verifySubstring(RunTargetTest.jobBlock(text, "two-parts"), 'needs: one');
            testCase.verifyFalse(contains(RunTargetTest.jobBlock(text, "two-parts"), 'runs-on'));
            testCase.verifyEqual(RunTargetTest.jobBlock(text, "three"), "");
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
