classdef RunSessionCaseTest < matlab.unittest.TestCase
    %RUNSESSIONCASETEST Unit tests for runSessionCase, the call a logcalls,
    % sessionfs, inputsetcall or inputsetwarnings case makes.
    %
    % The cases run for real against the OpenSTREAM checkout in
    % upstream/openstream, in scratch folders. tempname is shadowed by a stub
    % that returns unique names under a folder of the test, so a test knows
    % where the scratch folders are, can see that none is left behind and can
    % look for the scratch path in what is recorded. Entries are the ones of
    % the manifest, decoded with jsondecode as the exporter decodes them;
    % entries made here are named in the comments.
    %
    % Expected values come from the upstream source (a file mode makes the
    % session folder and an empty log file, a closed log file is not written,
    % a hidden warning goes to the log file, and so on): each test says which
    % statement of that source decides it. What MATLAB does that the source
    % does not decide (the text of its own errors) is not asserted.
    %
    % The record of a case has these fields, all rows of a struct array
    % being sorted by name where they have one:
    %
    % - error:    struct(identifier, message), both '' when there is none;
    % - warnings: struct array (identifier, message), each warning issued;
    % - console:  char, the text printed;
    % - files:    struct array (name, isFolder, text, hex): every file and
    %             folder of the scratch folder, name relative to it with /
    %             as separator, text and hex (lower case, two digits per
    %             byte) of the bytes of a file, '' for a folder;
    % - calls:    logcalls only; struct array (op, error, warnings), one per
    %             call, error and warnings as above.
    %
    % sessionfs also records sandboxFiles, the same listing of the sandbox
    % (the folder that holds the scratch folder as its subfolder scratch),
    % names relative to the sandbox; the scratch folder is a child of a
    % sandbox so that the names . and .. of a session folder stay inside it.
    %
    % sessionfs records error, warnings, console and files; logcalls those
    % and calls (its error is that of setting the log up); inputsetcall
    % error, warnings and files; inputsetwarnings console only, or files
    % only, as its capture says.

    properties
        scratchBase
    end

    methods (TestClassSetup)

        function addPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            import matlab.unittest.fixtures.CurrentFolderFixture
            here = fileparts(mfilename('fullpath'));
            root = fullfile(here, '..');
            testCase.applyFixture(PathFixture(fullfile(root, 'matlab')));
            % The folder of the tests, for the package TestData.
            testCase.applyFixture(PathFixture(here));
            % The cases name files relative to the repository root.
            testCase.applyFixture(CurrentFolderFixture(root));
            upstream = fullfile(root, 'upstream', 'openstream');
            testCase.assertTrue(isfolder(fullfile(upstream, '+Session')), ...
                'upstream/openstream is not checked out');
            testCase.applyFixture(PathFixture(upstream));
        end

    end

    methods (TestMethodSetup)

        function shadowTempname(testCase)
            % tempname returns scratch1, scratch2 ... under a folder of this
            % test; the count is kept in the root appdata.
            import matlab.unittest.fixtures.TemporaryFolderFixture
            import matlab.unittest.fixtures.PathFixture
            % One folder for the test: the sandboxes of the cases go in its
            % subfolder scratches, the stub in its subfolder stub.
            fixture = testCase.applyFixture(TemporaryFolderFixture);
            testCase.scratchBase = fullfile(fixture.Folder, 'scratches');
            mkdir(testCase.scratchBase);
            stubFolder = fullfile(fixture.Folder, 'stub');
            mkdir(stubFolder);
            setappdata(0, 'RunSessionCaseTestBase', testCase.scratchBase);
            setappdata(0, 'RunSessionCaseTestCount', 0);
            testCase.addTeardown(@RunSessionCaseTest.clearState);
            lines = [ ...
                "function name = tempname(varargin)"
                "base = getappdata(0, 'RunSessionCaseTestBase');"
                "count = getappdata(0, 'RunSessionCaseTestCount') + 1;"
                "setappdata(0, 'RunSessionCaseTestCount', count);"
                "name = fullfile(base, sprintf('scratch%d', count));"
                "end"];
            fid = fopen(fullfile(stubFolder, 'tempname.m'), 'w');
            fprintf(fid, '%s\n', strjoin(reshape(lines, 1, []), newline));
            fclose(fid);
            testCase.applyFixture(PathFixture(stubFolder));
        end

    end

    methods (Static)

        function clearState()
            for name = {'RunSessionCaseTestBase', 'RunSessionCaseTestCount'}
                if isappdata(0, name{1})
                    rmappdata(0, name{1});
                end
            end
        end

        function names = fileNames(files)
            % The names of the struct array FILES, as a string column.
            names = strings(0, 1);
            for k = 1:numel(files)
                names(end+1, 1) = string(files(k).name); %#ok<AGROW>
            end
        end

        function left = leftovers(base)
            % The names under BASE (none expected after a case).
            listing = dir(base);
            left = setdiff({listing.name}, {'.', '..'});
        end

        function e = sessionfs(logmode, dirName, overwrite, before, parent)
            % A sessionfs entry; OVERWRITE is the JSON text true or false.
            e = jsondecode(sprintf(['{"name":"sf","kind":"sessionfs",' ...
                '"logmode":"%s","dirName":"%s","overwrite":%s,' ...
                '"before":"%s","parent":"%s"}'], ...
                logmode, dirName, overwrite, before, parent));
        end

        function e = logcalls(logmode, sessionName, calls)
            % A logcalls entry; SESSIONNAME is the JSON text of the name
            % (quotes included, or null), CALLS the JSON text of the list.
            e = jsondecode(['{"name":"lc","kind":"logcalls",' ...
                '"logmode":"' logmode '","sessionName":' sessionName ...
                ',"calls":' calls '}']);
        end

        function tf = hexMatchesText(file)
            % True when the hex of FILE is the lower case hex of its text
            % (texts here are ASCII).
            if isempty(file.text)
                tf = isempty(file.hex);
            else
                bytes = dec2hex(double(file.text), 2);
                tf = strcmp(file.hex, lower(reshape(bytes.', 1, [])));
            end
        end

    end

    methods

        function verifyNoError(testCase, err)
            testCase.verifyEqual(sort(fieldnames(err)), {'identifier'; 'message'});
            testCase.verifyEmpty(err.identifier);
            testCase.verifyEmpty(err.message);
        end

        function verifyFilesLayout(testCase, files)
            % FILES is a struct array with the four fields, sorted by name,
            % whose texts and hex agree.
            testCase.verifyClass(files, 'struct');
            testCase.verifyEqual(sort(fieldnames(files)), ...
                {'hex'; 'isFolder'; 'name'; 'text'});
            names = RunSessionCaseTest.fileNames(files);
            testCase.verifyEqual(names, sort(names));
            for k = 1:numel(files)
                testCase.verifyTrue(RunSessionCaseTest.hexMatchesText(files(k)), ...
                    names(k));
                if files(k).isFolder
                    testCase.verifyEmpty(files(k).text, names(k));
                    testCase.verifyEmpty(files(k).hex, names(k));
                end
            end
        end

        function verifyWarningsLayout(testCase, warnings)
            testCase.verifyClass(warnings, 'struct');
            testCase.verifyEqual(sort(fieldnames(warnings)), ...
                {'identifier'; 'message'});
        end

        function sentinel = makeSentinel(testCase)
            % A file next to the sandboxes of the cases (in the base folder).
            sentinel = fullfile(testCase.scratchBase, 'sentinel.txt');
            fid = fopen(sentinel, 'w');
            fprintf(fid, 'keep');
            fclose(fid);
        end

        function verifySentinelAlone(testCase, sentinel)
            % The sentinel is intact and is all that is left in the base.
            testCase.verifyTrue(isfile(sentinel));
            testCase.verifyEqual(fileread(sentinel), 'keep');
            testCase.verifyEqual(RunSessionCaseTest.leftovers(testCase.scratchBase), ...
                {'sentinel.txt'});
        end

        function verifyNothingLeftBehind(testCase)
            testCase.verifyEmpty(RunSessionCaseTest.leftovers(testCase.scratchBase));
        end

        function verifyNoScratchPath(testCase, result)
            % The absolute scratch path is in no recorded text, whether
            % jsonencode writes a / as it is or escaped.
            encoded = jsonencode(result);
            testCase.verifyFalse(contains(encoded, testCase.scratchBase));
            testCase.verifyFalse(contains(encoded, ...
                strrep(testCase.scratchBase, '/', '\/')));
        end

    end

    methods (Test)

        % ----- the guard on the kind, and the scratch folder itself -----

        function testOtherKindIsRejected(testCase)
            % A kind that is not one of the four errors with the fixture
            % identifier; the neighbour, a session kind of the same shape
            % of entry, runs.
            other = jsondecode('{"name":"x","kind":"read","file":"a.inp"}');
            testCase.verifyError(@() runSessionCase(other), ...
                'References:InvalidInputFixture');
            e = RunSessionCaseTest.sessionfs('NONE', 'run', 'false', 'absent', 'exists');
            testCase.verifyClass(runSessionCase(e), 'struct');
        end

        function testTheStubReplacesTempname(testCase)
            % Control for the tests that look under the scratch base: the
            % stub is the tempname in use, counts its calls, and the
            % leftover reader sees what is left in the base.
            before = getappdata(0, 'RunSessionCaseTestCount');
            first = tempname;
            testCase.verifyEqual(first, fullfile(testCase.scratchBase, ...
                sprintf('scratch%d', before + 1)));
            testCase.verifyEqual(getappdata(0, 'RunSessionCaseTestCount'), before + 1);
            mkdir(fullfile(testCase.scratchBase, 'left'));
            testCase.verifyEqual(RunSessionCaseTest.leftovers(testCase.scratchBase), ...
                {'left'});
        end

        function testScratchFoldersAreRemoved(testCase)
            % One case of each kind, one that records an error: each made
            % a scratch folder (the stub counts the calls of tempname) and
            % no folder is left under the base.
            sessionfs = TestData.CaseEntries.entry('sessionfs', 'ext_session_14');
            logcalls = TestData.CaseEntries.entry('logcalls', 'ext_log_02');
            inputsetcall = TestData.CaseEntries.entry('inputsetcall', 'ext_inputset_08');
            warnings = TestData.CaseEntries.entry('inputsetwarnings', 'ext_inputset_25');
            entries = {sessionfs, logcalls, inputsetcall, warnings};
            for k = 1:numel(entries)
                before = getappdata(0, 'RunSessionCaseTestCount');
                runSessionCase(entries{k});
                testCase.verifyGreaterThan( ...
                    getappdata(0, 'RunSessionCaseTestCount'), before, entries{k}.name);
                testCase.verifyNothingLeftBehind();
            end
        end

        % ----- sessionfs -----

        function testNoneModeWithNothingBeforeRecordsNothing(testCase)
            % NONE builds the log without touching the file system (the
            % log constructor does nothing for NONE and console-only), so
            % the record has no error, no warning, no text and no file.
            e = RunSessionCaseTest.sessionfs('NONE', 'run', 'false', 'absent', 'exists');
            result = runSessionCase(e);
            testCase.verifyEqual(sort(fieldnames(result)), ...
                {'console'; 'error'; 'files'; 'sandboxFiles'; 'warnings'});
            testCase.verifyNoError(result.error);
            testCase.verifyWarningsLayout(result.warnings);
            testCase.verifyEmpty(result.warnings);
            testCase.verifyClass(result.console, 'char');
            testCase.verifyEmpty(result.console);
            testCase.verifyFilesLayout(result.files);
            testCase.verifyEmpty(result.files);
            testCase.verifyNothingLeftBehind();
        end

        function testFileModeMakesTheFolderAndTheLogFile(testCase)
            % Control for the test above, the same entry in a file mode:
            % the log constructor makes the session folder and an empty log
            % file in it, and the record lists both, so the empty listing
            % above is not a recorder that lists nothing.
            e = RunSessionCaseTest.sessionfs('BOTH', 'run', 'false', 'absent', 'exists');
            result = runSessionCase(e);
            testCase.verifyNoError(result.error);
            testCase.verifyEmpty(result.warnings);
            testCase.verifyFilesLayout(result.files);
            testCase.assertNumElements(result.files, 2);
            testCase.verifyEqual(result.files(1).name, 'run');
            testCase.verifyTrue(result.files(1).isFolder);
            testCase.verifyTrue(startsWith(result.files(2).name, 'run/'));
            testCase.verifyTrue(endsWith(result.files(2).name, '.log'));
            testCase.verifyFalse(result.files(2).isFolder);
            testCase.verifyEmpty(result.files(2).text);
            testCase.verifyNoScratchPath(result);
        end

        function testExistingFolderErrorIsRecordedNotThrown(testCase)
            % The session folder exists and may not be overwritten:
            % makeSessionDirectory throws ExistingSessionDirectoryError with
            % the message 'Session directory <dir> already exists.', dir
            % being the scratch folder and the name. The record holds the
            % error with the scratch path written <scratch>, and the folder
            % that was there before.
            e = TestData.CaseEntries.entry('sessionfs', 'ext_session_14');
            result = runSessionCase(e);
            testCase.verifyEqual(result.error.identifier, ...
                'OpenSTREAM:Session:ExistingSessionDirectoryError');
            testCase.verifyEqual(result.error.message, ...
                'Session directory <scratch>/run already exists.');
            testCase.verifyEmpty(result.warnings);
            testCase.verifyFilesLayout(result.files);
            testCase.verifyEqual(RunSessionCaseTest.fileNames(result.files), "run");
            testCase.verifyTrue(result.files(1).isFolder);
            testCase.verifyNoScratchPath(result);
        end

        function testOverwriteRemovesTheFolderWithItsFile(testCase)
            % With overwriting, the folder holding old.txt is removed and
            % made again (rmdir 's', then mkdir, then the log file); the one
            % warning issued is '<dir> was removed.' with no identifier. The
            % record has the new folder and log file and no old.txt.
            e = TestData.CaseEntries.entry('sessionfs', 'ext_session_15');
            result = runSessionCase(e);
            testCase.verifyNoError(result.error);
            testCase.verifyWarningsLayout(result.warnings);
            testCase.assertNumElements(result.warnings, 1);
            testCase.verifyEmpty(result.warnings(1).identifier);
            testCase.verifyEqual(result.warnings(1).message, ...
                '<scratch>/run was removed.');
            testCase.verifyFilesLayout(result.files);
            names = RunSessionCaseTest.fileNames(result.files);
            testCase.verifyFalse(any(names == "run/old.txt"));
            testCase.assertNumElements(names, 2);
            testCase.verifyEqual(names(1), "run");
            testCase.verifyTrue(startsWith(names(2), "run/"));
            testCase.verifyNoScratchPath(result);
        end

        function testFolderWithFileBeforeIsListedWhenNothingTouchesIt(testCase)
            % Control for the test above: in NONE mode the folder is not
            % touched, and the listing shows the folder and old.txt, so the
            % absence of old.txt above is the removal, not the recorder.
            e = RunSessionCaseTest.sessionfs('NONE', 'run', 'true', ...
                'folderWithFile', 'exists');
            result = runSessionCase(e);
            testCase.verifyNoError(result.error);
            testCase.verifyEmpty(result.warnings);
            testCase.verifyFilesLayout(result.files);
            testCase.verifyEqual(RunSessionCaseTest.fileNames(result.files), ...
                ["run"; "run/old.txt"]);
            testCase.verifyEqual([result.files.isFolder], [true false]);
        end

        function testOwnLogOpenWarnsOfTheClosedFileThenTheRemoval(testCase)
            % The first session's log file is open in the folder: the
            % second session closes it with the warning 'File closed: <file>'
            % and then removes the folder with '<dir> was removed.'. Both
            % warnings are recorded, in this order (a recorder that keeps
            % only the last warning of the call fails here).
            e = TestData.CaseEntries.entry('sessionfs', 'ext_session_21');
            result = runSessionCase(e);
            testCase.verifyNoError(result.error);
            testCase.verifyWarningsLayout(result.warnings);
            testCase.assertNumElements(result.warnings, 2);
            testCase.verifyTrue(startsWith(result.warnings(1).message, ...
                'File closed: <scratch>/run/'));
            testCase.verifyEqual(result.warnings(2).message, ...
                '<scratch>/run was removed.');
            testCase.verifyNoScratchPath(result);
        end

        function testEmptyFolderNameIsHarmlessWithoutAFileMode(testCase)
            % Console-only mode never touches the file system, whatever the
            % name: no error, nothing recorded.
            e = TestData.CaseEntries.entry('sessionfs', 'ext_session_22');
            result = runSessionCase(e);
            testCase.verifyNoError(result.error);
            testCase.verifyEmpty(result.warnings);
            testCase.verifyEmpty(result.console);
            testCase.verifyEmpty(result.files);
        end

        function testMissingAndFileParentsAreRecordedAsErrors(testCase)
            % The parent folder is checked by isfolder when the session is
            % built, which fails for a folder that does not exist, for a
            % file and for the empty text. Each failure is recorded (the
            % text of MATLAB's own message is not asserted) and the session
            % makes no folder.
            for name = {'ext_session_19', 'ext_session_20', 'ext_session_28'}
                e = TestData.CaseEntries.entry('sessionfs', name{1});
                result = runSessionCase(e);
                testCase.verifyNotEmpty(result.error.message, name{1});
                testCase.verifyFalse(any([result.files.isFolder]), name{1});
                testCase.verifyNoScratchPath(result);
            end
            % The neighbour with a parent that exists has no error.
            e = RunSessionCaseTest.sessionfs('NONE', 'run', 'false', 'absent', 'exists');
            testCase.verifyNoError(runSessionCase(e).error);
        end

        % ----- logcalls -----

        function testKeepOpenWritesAreRecordedExactly(testCase)
            % The calls of the entry decide the log file: a closed file is
            % not written (the first and the sixth log calls and the last
            % one are lost), openLogKeep keeps it open for two writes,
            % closeLog closes it, and openLog opens it for one write (it
            % closes after the first). The file ends 'a', 'b', 'd', one per
            % line; nothing is printed in a file-only mode; no call fails.
            e = TestData.CaseEntries.entry('logcalls', 'ext_log_02');
            result = runSessionCase(e);
            testCase.verifyEqual(sort(fieldnames(result)), ...
                {'calls'; 'console'; 'error'; 'files'; 'warnings'});
            testCase.verifyNoError(result.error);
            testCase.verifyEmpty(result.console);
            testCase.verifyFilesLayout(result.files);
            testCase.verifyEqual(RunSessionCaseTest.fileNames(result.files), ...
                ["run"; "run/s.log"]);
            testCase.verifyEqual(result.files(2).text, sprintf('a\nb\nd\n'));
            testCase.verifyEqual(result.files(2).hex, '610a620a640a');
            testCase.assertNumElements(result.calls, 9);
            testCase.verifyEqual({result.calls.op}, {'log', 'openLogKeep', 'log', ...
                'log', 'closeLog', 'log', 'openLog', 'log', 'log'});
            for k = 1:numel(result.calls)
                testCase.verifyNoError(result.calls(k).error);
                testCase.verifyEmpty(result.calls(k).warnings);
            end
        end

        function testConsoleTextAndEmptyLogFileAreRecorded(testCase)
            % Both mode with the log closed: the console gets the text
            % (the number is a double 3, so %d prints 3) and the closed
            % file gets nothing.
            e = TestData.CaseEntries.entry('logcalls', 'ext_log_01');
            result = runSessionCase(e);
            testCase.verifyNoError(result.error);
            testCase.verifyEqual(result.console, sprintf('v=3\n'));
            testCase.verifyEqual(RunSessionCaseTest.fileNames(result.files), ...
                ["run"; "run/s.log"]);
            testCase.verifyEmpty(result.files(2).text);
            testCase.verifyEmpty(result.files(2).hex);
        end

        function testShownWarningIsRecordedForItsCall(testCase)
            % Both mode shows the warning (builtin warning with the
            % identifier and the text), so lastwarn after the call holds
            % them; the log file stays empty.
            e = TestData.CaseEntries.entry('logcalls', 'ext_log_03');
            result = runSessionCase(e);
            testCase.verifyNoError(result.error);
            testCase.assertNumElements(result.calls, 1);
            testCase.verifyEqual(result.calls(1).op, 'warning');
            testCase.verifyWarningsLayout(result.calls(1).warnings);
            testCase.assertNumElements(result.calls(1).warnings, 1);
            testCase.verifyEqual(result.calls(1).warnings(1).identifier, 'Some:id');
            testCase.verifyEqual(result.calls(1).warnings(1).message, 'some message');
            testCase.verifySubstring(result.console, 'some message');
            testCase.verifyEmpty(result.files(2).text);
        end

        function testHiddenWarningGoesToTheFileAndNotToTheRecordOfWarnings(testCase)
            % File-only mode hides the warning and writes it to the log:
            % the line Warning: then the identifier and the text, one per
            % line. No warning is issued, so none is recorded for the call,
            % and nothing is printed. (Pair of the test above: the same
            % call, the other place for the warning.)
            e = TestData.CaseEntries.entry('logcalls', 'ext_log_04');
            result = runSessionCase(e);
            testCase.verifyNoError(result.error);
            testCase.verifyEmpty(result.console);
            testCase.assertNumElements(result.calls, 1);
            testCase.verifyEmpty(result.calls(1).warnings);
            testCase.verifyEqual(RunSessionCaseTest.fileNames(result.files), ...
                ["run"; "run/s.log"]);
            testCase.verifyEqual(result.files(2).text, ...
                sprintf('Warning:\nSome:id\nsome message\n'));
            testCase.verifyEqual(result.files(2).hex, ...
                '5761726e696e673a0a536f6d653a69640a736f6d65206d6573736167650a');
        end

        function testNoneModeWritesAndShowsNothing(testCase)
            % NONE: log returns at once and the warning is neither shown
            % nor written, and no folder is made.
            e = TestData.CaseEntries.entry('logcalls', 'ext_log_12');
            result = runSessionCase(e);
            testCase.verifyNoError(result.error);
            testCase.verifyEmpty(result.console);
            testCase.verifyEmpty(result.files);
            testCase.assertNumElements(result.calls, 2);
            testCase.verifyEqual({result.calls.op}, {'log', 'warning'});
            for k = 1:2
                testCase.verifyNoError(result.calls(k).error);
                testCase.verifyEmpty(result.calls(k).warnings);
            end
        end

        function testWarningsAreRecordedPerCall(testCase)
            % A warning of the first call is not recorded again for the
            % second: lastwarn is reset before each call. The first call
            % warns, the second only prints.
            calls = ['[{"op":"warning","args":["Some:id","first"]},' ...
                '{"op":"log","args":["x\n"]}]'];
            e = RunSessionCaseTest.logcalls('LOGTOCONSOLEONLY', '"s"', calls);
            result = runSessionCase(e);
            testCase.assertNumElements(result.calls, 2);
            testCase.verifyNumElements(result.calls(1).warnings, 1);
            testCase.verifyEqual(result.calls(1).warnings(1).message, 'first');
            testCase.verifyEmpty(result.calls(2).warnings);
            testCase.verifySubstring(result.console, sprintf('x\n'));
        end

        function testErrorOfACallIsRecordedAndTheNextCallsRun(testCase)
            % No session at all (the session name is null): the log is
            % built directly. In NONE mode log returns at once, but the
            % file path of a log without a session needs the session, which
            % does not exist, so that call fails. The error is recorded for
            % that call only, and the calls after it still run.
            calls = ['[{"op":"log","args":["x\n"]},{"op":"readLogFilePath","args":[]},' ...
                '{"op":"log","args":["y\n"]}]'];
            e = RunSessionCaseTest.logcalls('NONE', 'null', calls);
            result = runSessionCase(e);
            testCase.verifyNoError(result.error);
            testCase.assertNumElements(result.calls, 3);
            testCase.verifyEqual({result.calls.op}, ...
                {'log', 'readLogFilePath', 'log'});
            testCase.verifyNoError(result.calls(1).error);
            testCase.verifyNotEmpty(result.calls(2).error.message);
            testCase.verifyNoError(result.calls(3).error);
        end

        function testOpenLogWithoutASessionFails(testCase)
            % A log with no session cannot open its file.
            e = TestData.CaseEntries.entry('logcalls', 'ext_log_11');
            result = runSessionCase(e);
            testCase.verifyNoError(result.error);
            testCase.assertNumElements(result.calls, 1);
            testCase.verifyNotEmpty(result.calls(1).error.message);
            testCase.verifyEmpty(result.files);
        end

        function testRemovedSessionFolderLeavesNothingToRecord(testCase)
            % removeFolder deletes the session folder (and the log file in
            % it); openLog then cannot open a file in a missing folder, and
            % log has no open file to write to. The listing is empty, where
            % the same mode keeps the folder and the file when the folder is
            % not removed (see the keep-open test).
            e = TestData.CaseEntries.entry('logcalls', 'ext_log_17');
            result = runSessionCase(e);
            testCase.verifyNoError(result.error);
            testCase.verifyEmpty(result.files);
            testCase.assertNumElements(result.calls, 3);
            testCase.verifyEqual({result.calls.op}, {'removeFolder', 'openLog', 'log'});
        end

        % ----- inputsetcall -----

        function testMissingModelFileIsRecordedAndNothingIsMade(testCase)
            % The model file is checked by the argument validation before
            % anything is made. The record holds an error, no warning and no
            % session folder (a file named afile may stand in the scratch
            % folder; nothing else does).
            e = TestData.CaseEntries.entry('inputsetcall', 'ext_inputset_08');
            result = runSessionCase(e);
            testCase.verifyEqual(sort(fieldnames(result)), ...
                {'error'; 'files'; 'warnings'});
            testCase.verifyNotEmpty(result.error.message);
            testCase.verifyEmpty(result.warnings);
            testCase.verifyFilesLayout(result.files);
            testCase.verifyEmpty(setdiff( ...
                RunSessionCaseTest.fileNames(result.files), "afile"));
            testCase.verifyNoScratchPath(result);
        end

        function testFolderAsBoundaryConditionFileIsRecordedAsAnError(testCase)
            % <scratch> alone names the scratch folder, which is not a file.
            e = TestData.CaseEntries.entry('inputsetcall', 'ext_inputset_09');
            result = runSessionCase(e);
            testCase.verifyNotEmpty(result.error.message);
            testCase.verifyEmpty(setdiff( ...
                RunSessionCaseTest.fileNames(result.files), "afile"));
            testCase.verifyNoScratchPath(result);
        end

        function testFileAsSessionParentIsRecordedAndTheFileIsListed(testCase)
            % The session parent is a file, which isfolder refuses: an
            % error. The file stays and is listed as a file.
            e = TestData.CaseEntries.entry('inputsetcall', 'ext_inputset_12');
            result = runSessionCase(e);
            testCase.verifyNotEmpty(result.error.message);
            names = RunSessionCaseTest.fileNames(result.files);
            testCase.assertTrue(any(names == "afile"));
            testCase.verifyFalse(result.files(names == "afile").isFolder);
            testCase.verifyNoScratchPath(result);
        end

        function testScratchMarkerIsReplacedBeforeTheCall(testCase)
            % The boundary-condition file is <scratch>/afile, a file that
            % exists once the marker is replaced by the scratch path: the
            % argument validation then passes and the session is made (its
            % folder is named from the identifiers, here none, so --, and
            % the log file from the session name), whatever happens to the
            % file after that. Without the replacement the validation
            % fails before anything is made and only afile is listed.
            e = jsondecode(['{"name":"ic","kind":"inputsetcall","logmode":"BOTH",' ...
                '"args":[["bcFilePath","<scratch>/afile"],["sessionName","probe"]]}']);
            result = runSessionCase(e);
            testCase.verifyFilesLayout(result.files);
            names = RunSessionCaseTest.fileNames(result.files);
            testCase.verifyTrue(any(names == "--"));
            testCase.verifyTrue(any(names == "--/probe.log"));
            testCase.verifyTrue(any(names == "afile"));
            testCase.verifyNoScratchPath(result);
        end

        function testDefaultsBuildTheSessionInTheScratchFolder(testCase)
            % With no file at all the input set builds from defaults. The
            % parent folder defaults to the scratch folder (the session
            % folder -- is listed there, with the log file named by the
            % session name given), whatever the user path is.
            e = jsondecode(['{"name":"ic","kind":"inputsetcall","logmode":"BOTH",' ...
                '"args":[["sessionName","probe"]]}']);
            result = runSessionCase(e);
            names = RunSessionCaseTest.fileNames(result.files);
            testCase.verifyTrue(any(names == "--"));
            testCase.verifyTrue(any(names == "--/probe.log"));
            testCase.verifyNothingLeftBehind();
        end

        % ----- inputsetwarnings -----

        function testConsoleCaptureRecordsTheWarningOnceAndNoFiles(testCase)
            % NONE: the unused-key warning of the boundary conditions is a
            % direct warning call whose text starts with the upper case
            % class name, shown once. Capture console records the text and
            % not the files. The BOTH case of the same capture is left to
            % the recorded run: it turns the diary of the session log on
            % inside evalc, and what MATLAB does then is not known.
            for name = {'ext_inputset_23'}
                e = TestData.CaseEntries.entry('inputsetwarnings', name{1});
                result = runSessionCase(e);
                testCase.verifyEqual(fieldnames(result), {'console'}, name{1});
                testCase.verifyClass(result.console, 'char');
                testCase.verifyEqual(count(result.console, ...
                    'BOUNDARYCONDITIONS: These entries were not used'), 1, name{1});
            end
        end

        function testFilesCaptureRecordsTheSessionFilesAndNoConsole(testCase)
            % LOGTOFILEONLY: the session folder is named from the identifiers
            % (geometry, model, options) and holds the log file named by the
            % boundary-condition file. Capture files records them and not
            % the console (pair of the test above).
            e = TestData.CaseEntries.entry('inputsetwarnings', 'ext_inputset_25');
            result = runSessionCase(e);
            testCase.verifyEqual(fieldnames(result), {'files'});
            testCase.verifyFilesLayout(result.files);
            names = RunSessionCaseTest.fileNames(result.files);
            testCase.verifyTrue(any(names == "TUTORIAL1-TUTORIAL1-DEFAULT"));
            testCase.verifyTrue(any(names == "TUTORIAL1-TUTORIAL1-DEFAULT/bc_unused.log"));
            testCase.verifyNoScratchPath(result);
        end

        % ----- the sandbox -----

        function testSandboxFilesAreRelativeToTheSandbox(testCase)
            % The scratch folder is the folder scratch of a sandbox of the
            % case. files is relative to the scratch folder, sandboxFiles
            % (sessionfs only) to the sandbox: the same entries behind the
            % prefix scratch, and the folder scratch itself.
            e = RunSessionCaseTest.sessionfs('BOTH', 'run', 'false', 'absent', 'exists');
            result = runSessionCase(e);
            testCase.verifyFilesLayout(result.sandboxFiles);
            testCase.verifyEqual(RunSessionCaseTest.fileNames(result.files), ...
                ["run"; "run/.log"]);
            testCase.verifyEqual(RunSessionCaseTest.fileNames(result.sandboxFiles), ...
                ["scratch"; "scratch/run"; "scratch/run/.log"]);
            testCase.verifyEqual([result.sandboxFiles.isFolder], [true true false]);
            testCase.verifyNoScratchPath(result);
        end

        function testDotDotNameWithoutASessionTouchesOnlyTheSandbox(testCase)
            % NONE touches no folder, so the file old.txt that the case
            % puts at the name ".." (the parent of the scratch folder, that
            % is the sandbox) is still there, next to the scratch folder;
            % nothing outside the sandbox is made.
            sentinel = testCase.makeSentinel();
            e = RunSessionCaseTest.sessionfs('NONE', '..', 'true', ...
                'folderWithFile', 'exists');
            result = runSessionCase(e);
            testCase.verifyEqual(RunSessionCaseTest.fileNames(result.sandboxFiles), ...
                ["old.txt"; "scratch"]);
            testCase.verifyEqual([result.sandboxFiles.isFolder], [false true]);
            testCase.verifySentinelAlone(sentinel);
        end

        function testDotAndDotDotNamesStayInsideTheSandbox(testCase)
            % ext_session_23 and 24 (names "." and "..", overwriting, BOTH)
            % remove and make folders by name arithmetic on the scratch
            % folder. A file next to the sandbox must be untouched and
            % nothing but it left in the base folder afterwards. What the
            % removal of "scratch/.." itself does is not asserted, except
            % that old.txt, which stood in the folder removed, is gone
            % unless the removal failed (an error is then recorded).
            sentinel = testCase.makeSentinel();
            for name = {'ext_session_23', 'ext_session_24'}
                e = TestData.CaseEntries.entry('sessionfs', name{1});
                result = runSessionCase(e);
                testCase.verifyFilesLayout(result.files);
                testCase.verifyFilesLayout(result.sandboxFiles);
                testCase.verifySentinelAlone(sentinel);
                testCase.verifyNoScratchPath(result);
            end
            e = TestData.CaseEntries.entry('sessionfs', 'ext_session_24');
            result = runSessionCase(e);
            names = RunSessionCaseTest.fileNames(result.sandboxFiles);
            testCase.verifyTrue(~isempty(result.error.message) || ~any(names == "old.txt"));
        end

        % ----- names, marker, kept-open log, errors, one pair -----

        function testScratchMarkerInALogSessionNameIsReplaced(testCase)
            % The name <scratch> becomes the absolute path of the scratch
            % folder, so the log file path is the folder run plus that
            % path plus .log, in folders that do not exist: fopen fails
            % without an error and no log file is made. Without the
            % replacement the name would be the text <scratch> and the file
            % run/<scratch>.log would be made. Control: the name x makes
            % run/x.log.
            e = RunSessionCaseTest.logcalls('LOGTOFILEONLY', '"<scratch>"', '[]');
            result = runSessionCase(e);
            testCase.verifyNoError(result.error);
            testCase.verifyEqual(RunSessionCaseTest.fileNames(result.files), "run");
            e = RunSessionCaseTest.logcalls('LOGTOFILEONLY', '"x"', '[]');
            result = runSessionCase(e);
            testCase.verifyEqual(RunSessionCaseTest.fileNames(result.files), ...
                ["run"; "run/x.log"]);
        end

        function testLogKeptOpenAtTheEndIsRecordedComplete(testCase)
            % ext_log_13 keeps the log file open and ends with it open: a
            % hidden warning of two lines, then a log call. The runner
            % closes the log before reading the file, so the text is
            % complete: Warning:, the identifier, the message (its own final
            % newline and the one the writer adds), then the log text.
            e = TestData.CaseEntries.entry('logcalls', 'ext_log_13');
            result = runSessionCase(e);
            testCase.verifyNoError(result.error);
            testCase.verifyEqual(RunSessionCaseTest.fileNames(result.files), ...
                ["run"; "run/s.log"]);
            testCase.verifyEqual(result.files(2).text, ...
                [sprintf('Warning:\nA:b\nline1\nline2\n\n') sprintf('after\n')]);
            testCase.verifyTrue(RunSessionCaseTest.hexMatchesText(result.files(2)));
        end

        function testInputSetErrorOfAWarningsCasePropagatesWithoutTheScratchPath(testCase)
            % A failing build is not recorded for inputsetwarnings: the
            % error reaches the caller (the exporter records it). Its message
            % holds no scratch path, and the scratch folder is gone. (The
            % replacement of a path inside a message is not derivable from
            % a case of the manifest.)
            e = jsondecode(['{"name":"iw","kind":"inputsetwarnings",' ...
                '"logmode":"NONE","capture":"console",' ...
                '"model":["cases/input-fixture/absent_model.inp","M"]}']);
            try
                runSessionCase(e);
                testCase.verifyFail('the build of a missing model file did not error');
            catch err
                testCase.verifyNotEmpty(err.message);
                testCase.verifyFalse(contains(err.message, testCase.scratchBase));
            end
            testCase.verifyNothingLeftBehind();
        end

        function testASingleUnwrappedPairIsAPair(testCase)
            % args decoded as the cell {name; value} (one pair without the
            % list around it) is read as one pair, like the list of one
            % pair.
            wrapped = jsondecode(['{"name":"ic","kind":"inputsetcall",' ...
                '"logmode":"BOTH","args":[["sessionName","probe"]]}']);
            bare = wrapped;
            bare.args = {'sessionName'; 'probe'};
            a = runSessionCase(wrapped);
            b = runSessionCase(bare);
            testCase.verifyEqual(RunSessionCaseTest.fileNames(b.files), ...
                RunSessionCaseTest.fileNames(a.files));
            testCase.verifyTrue(any(RunSessionCaseTest.fileNames(b.files) == "--/probe.log"));
        end

    end

end
