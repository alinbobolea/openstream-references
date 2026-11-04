classdef WarningRecorderTest < matlab.unittest.TestCase
    %WARNINGRECORDERTEST Unit tests for WarningRecorder, which records every
    % warning issued through the function warning while it exists.
    %
    % The recorder puts a function file named warning.m (in the folder
    % support/warningRecorder, never on the path of the source folder) in
    % front of the built-in on the search path and removes it when it is
    % released. The shadow records the formatted message and the identifier
    % of each call that leaves a message in lastwarn (a warning that is
    % switched off may or may not do so: MATLAB decides) and passes every
    % call on to the built-in unchanged. Warnings are displayed as usual,
    % so the log of a test run shows some of them.

    properties
        helperFolder
    end

    methods (TestClassSetup)

        function addPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            here = fileparts(mfilename('fullpath'));
            testCase.applyFixture(PathFixture(fullfile(here, '..', 'matlab')));
        end

    end

    methods (TestMethodSetup)

        function makeHelperPackage(testCase)
            % A package function that issues a warning with the arguments it
            % is given, in a folder of this test.
            import matlab.unittest.fixtures.TemporaryFolderFixture
            import matlab.unittest.fixtures.PathFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture);
            testCase.helperFolder = fixture.Folder;
            mkdir(fullfile(fixture.Folder, '+recorderhelper'));
            fid = fopen(fullfile(fixture.Folder, '+recorderhelper', 'issue.m'), 'w');
            fprintf(fid, '%s\n', 'function issue(varargin)', 'warning(varargin{:});', 'end');
            fclose(fid);
            testCase.applyFixture(PathFixture(fixture.Folder));
            % Never leave a recorder behind, whatever a test does.
            testCase.addTeardown(@WarningRecorderTest.releaseAll);
        end

    end

    methods (Static)

        function releaseAll()
            WarningRecorder.releaseAll();
        end

    end

    methods (Test)

        function testFormattedWarningIsRecordedAndStillSetsLastwarn(testCase)
            rec = WarningRecorder();
            lastwarn('', '');
            warning('Recorder:formatted', 'value %d of %s', 3, 'x');
            w = rec.recorded();
            testCase.assertNumElements(w, 1);
            testCase.verifyEqual(w(1).identifier, 'Recorder:formatted');
            testCase.verifyEqual(w(1).message, 'value 3 of x');
            [message, id] = lastwarn;
            testCase.verifyEqual(message, 'value 3 of x');
            testCase.verifyEqual(id, 'Recorder:formatted');
        end

        function testWarningWithoutIdentifierHasAnEmptyIdentifier(testCase)
            rec = WarningRecorder();
            warning('plain %d here', 5);
            w = rec.recorded();
            testCase.assertNumElements(w, 1);
            testCase.verifyEmpty(w(1).identifier);
            testCase.verifyClass(w(1).identifier, 'char');
            testCase.verifyEqual(w(1).message, 'plain 5 here');
        end

        function testTwoWarningsInARowAreBothRecordedInOrder(testCase)
            rec = WarningRecorder();
            warning('Recorder:first', 'one');
            warning('Recorder:second', 'two %s', 'x');
            w = rec.recorded();
            testCase.assertNumElements(w, 2);
            testCase.verifyEqual({w.identifier}, {'Recorder:first', 'Recorder:second'});
            testCase.verifyEqual({w.message}, {'one', 'two x'});
        end

        function testTheSameWarningTwiceIsRecordedTwice(testCase)
            rec = WarningRecorder();
            warning('Recorder:again', 'same');
            warning('Recorder:again', 'same');
            testCase.verifyNumElements(rec.recorded(), 2);
        end

        function testDisabledWarningCallDoesNotThrowAndStateCallsWork(testCase)
            % Whether MATLAB sets lastwarn for a warning that is switched
            % off is not known here (the recorder records whatever the
            % built-in leaves in lastwarn), so this test claims nothing about
            % the record of a disabled warning: the state calls change the
            % state, the call of the disabled warning does not throw, and
            % once the warning is on again one call adds exactly one record.
            state = warning('off', 'Recorder:quiet');
            testCase.addTeardown(@() warning(state));
            rec = WarningRecorder();
            testCase.verifyEqual(warning('query', 'Recorder:quiet').state, 'off');
            warning('Recorder:quiet', 'quiet');
            warning('on', 'Recorder:quiet');
            testCase.verifyEqual(warning('query', 'Recorder:quiet').state, 'on');
            before = numel(rec.recorded());
            warning('Recorder:quiet', 'shown');
            w = rec.recorded();
            testCase.assertNumElements(w, before + 1);
            testCase.verifyEqual(w(end).message, 'shown');
        end

        function testCallWithAnEmptyMessageRecordsNothingAndKeepsLastwarn(testCase)
            % A call that issues no warning (an empty message) leaves the
            % record alone and lastwarn as it was: the shadow restores what
            % it saved.
            rec = WarningRecorder();
            lastwarn('earlier text', 'Recorder:earlier');
            warning('');
            testCase.verifyEmpty(rec.recorded());
            [message, id] = lastwarn;
            testCase.verifyEqual(message, 'earlier text');
            testCase.verifyEqual(id, 'Recorder:earlier');
        end

        function testStateCallFormsAreRecognised(testCase)
            % The forms the shadow passes through without recording; every
            % other form is a message.
            is = @WarningRecorder.isStateCall;
            testCase.verifyTrue(is({}));
            testCase.verifyTrue(is({'on'}));
            testCase.verifyTrue(is({'off', 'Recorder:x'}));
            testCase.verifyTrue(is({'query', 'all'}));
            testCase.verifyTrue(is({'error', 'Recorder:x'}));
            testCase.verifyTrue(is({"off", "Recorder:x"}));
            testCase.verifyTrue(is({struct('identifier', 'Recorder:x', 'state', 'on')}));
            testCase.verifyFalse(is({'Recorder:x', 'text'}));
            testCase.verifyFalse(is({'plain text %d', 3}));
            testCase.verifyFalse(is({"Recorder:x", "text"}));
            testCase.verifyFalse(is({'one'}));
            testCase.verifyFalse(is({'onwards', 'x'}));
            testCase.verifyFalse(is({5}));
        end

        function testCompleteAddsTheLastWarningOnlyWhenTheRecorderMissedIt(testCase)
            % complete(recorded, message, id): the recorded warnings, plus the
            % last warning of lastwarn when it is not the last recorded one
            % (a direct call of the built-in is not seen by the shadow).
            none = struct('identifier', {}, 'message', {});
            one = struct('identifier', {''}, 'message', {'x was removed.'});
            w = WarningRecorder.complete(one, 'x was removed.', '');
            testCase.verifyEqual(w, one);
            w = WarningRecorder.complete(one, 'other', 'Other:id');
            testCase.assertNumElements(w, 2);
            testCase.verifyEqual(w(1), one);
            testCase.verifyEqual(w(2).identifier, 'Other:id');
            testCase.verifyEqual(w(2).message, 'other');
            w = WarningRecorder.complete(none, 'only', 'Only:id');
            testCase.assertNumElements(w, 1);
            testCase.verifyEqual(w(1).message, 'only');
            w = WarningRecorder.complete(none, '', '');
            testCase.verifyEmpty(w);
            testCase.verifyEqual(sort(fieldnames(w)), {'identifier'; 'message'});
            % Same message, other identifier: a different warning.
            w = WarningRecorder.complete(one, 'x was removed.', 'Some:id');
            testCase.verifyNumElements(w, 2);
        end

        function testCompleteDropsTheNoticeOfTheShadowedName(testCase)
            % MATLAB's notice that a function has the name of a built-in
            % (identifier MATLAB:dispatcher:nameConflict) is not a warning of
            % the case: it is dropped from the recorded warnings and from the
            % last warning.
            notice = 'MATLAB:dispatcher:nameConflict';
            recorded = struct('identifier', {notice, 'Real:one', notice}, ...
                'message', {'Function warning has the same name', 'real', 'again'});
            w = WarningRecorder.complete(recorded, 'again', notice);
            testCase.assertNumElements(w, 1);
            testCase.verifyEqual(w(1).identifier, 'Real:one');
            w = WarningRecorder.complete(recorded(1), 'notice text', notice);
            testCase.verifyEmpty(w);
        end

        function testTheNoticeOfTheShadowedNameStaysOffWhileRecordingOnly(testCase)
            % The notice is switched off from the start of a recorder to its
            % release, and its state is what it was before afterwards.
            id = 'MATLAB:dispatcher:nameConflict';
            original = warning('query', id).state;
            rec = WarningRecorder();
            testCase.verifyEqual(warning('query', id).state, 'off');
            warning('Recorder:duringNotice', 'x');
            delete(rec);
            testCase.verifyEqual(warning('query', id).state, original);
        end

        function testRecorderWithoutItsShadowFileRefusesToStart(testCase)
            % A folder that does not exist, or has no warning.m, is an error
            % with the identifier References:WarningRecorderUnavailable and
            % leaves nothing behind: no recorder, no path entry, no appdata,
            % the notice state unchanged. (A recorder that "succeeded" would
            % record nothing.)
            id = 'MATLAB:dispatcher:nameConflict';
            original = warning('query', id).state;
            pathBefore = path;
            for folder = {fullfile(testCase.helperFolder, 'no_such_folder'), ...
                    testCase.helperFolder}
                testCase.verifyError(@() WarningRecorder(folder{1}), ...
                    'References:WarningRecorderUnavailable');
                testCase.verifyFalse(WarningRecorder.active());
                testCase.verifyFalse(isappdata(0, WarningRecorder.key()));
                testCase.verifyEqual(path, pathBefore);
                testCase.verifyEqual(warning('query', id).state, original);
            end
        end

        function testRecorderWithAnotherFolderUsesItsShadow(testCase)
            % The folder argument is the seam: a copy of the shadow in a
            % folder of the test records, and the folder is taken off the path
            % at the release.
            copyFolder = fullfile(testCase.helperFolder, 'copyOfShadow');
            mkdir(copyFolder);
            copyfile(fullfile(WarningRecorder.folder(), 'warning.m'), copyFolder);
            rec = WarningRecorder(copyFolder);
            testCase.verifyTrue(contains(path, copyFolder));
            warning('Recorder:copy', 'from a copy');
            testCase.verifyEqual({rec.recorded().identifier}, {'Recorder:copy'});
            delete(rec);
            testCase.verifyFalse(contains(path, copyFolder));
            testCase.verifyFalse(WarningRecorder.active());
        end

        function testControlFormsWorkAndAreNotRecorded(testCase)
            original = warning('query', 'Recorder:control');
            testCase.addTeardown(@() warning(original));
            rec = WarningRecorder();
            warning('off', 'Recorder:control');
            testCase.verifyEqual(warning('query', 'Recorder:control').state, 'off');
            warning('on', 'Recorder:control');
            testCase.verifyEqual(warning('query', 'Recorder:control').state, 'on');
            testCase.verifyEmpty(rec.recorded());
        end

        function testCallsWithOutputsReturnWhatTheBuiltinReturns(testCase)
            rec = WarningRecorder();
            s = warning('query', 'Recorder:output');
            testCase.verifyTrue(isstruct(s));
            testCase.verifyEqual(sort(fieldnames(s)), {'identifier'; 'state'});
            testCase.verifyEqual(s.identifier, 'Recorder:output');
            previous = warning('off', 'Recorder:output');
            testCase.addTeardown(@() warning(previous));
            testCase.verifyEqual(previous.identifier, 'Recorder:output');
            states = warning;
            testCase.verifyTrue(isstruct(states) && ~isempty(states));
            testCase.verifyEmpty(rec.recorded());
        end

        function testWarningFromAPackageFunctionIsRecorded(testCase)
            rec = WarningRecorder();
            recorderhelper.issue('Recorder:fromPackage', 'in a package %d', 7);
            w = rec.recorded();
            testCase.assertNumElements(w, 1);
            testCase.verifyEqual(w(1).identifier, 'Recorder:fromPackage');
            testCase.verifyEqual(w(1).message, 'in a package 7');
        end

        function testRecorderPutsTheShadowOnThePathAndReleaseTakesItOff(testCase)
            % While a recorder exists the file warning.m of its folder is
            % the warning function; after the release it is the built-in
            % again, no warning is recorded and nothing is left in the
            % root appdata or on the path.
            folder = WarningRecorder.folder();
            testCase.assertFalse(WarningRecorder.active());
            testCase.assertFalse(contains(path, folder));
            testCase.assertFalse(contains(which('warning'), folder));

            rec = WarningRecorder();
            testCase.verifyTrue(WarningRecorder.active());
            testCase.verifyTrue(contains(path, folder));
            testCase.verifyTrue(contains(which('warning'), folder));
            warning('Recorder:during', 'during');
            testCase.verifyNumElements(rec.recorded(), 1);

            delete(rec);
            testCase.verifyFalse(WarningRecorder.active());
            testCase.verifyFalse(contains(path, folder));
            testCase.verifyFalse(contains(which('warning'), folder));
            testCase.verifyFalse(isappdata(0, WarningRecorder.key()));
            % A warning after the release goes to no recorder: a recorder
            % made next starts empty.
            warning('Recorder:after', 'after');
            second = WarningRecorder();
            testCase.verifyEmpty(second.recorded());
            warning('Recorder:next', 'next');
            testCase.verifyEqual({second.recorded().identifier}, {'Recorder:next'});
        end

        function testClearingTheHandleReleasesTheRecorder(testCase)
            rec = WarningRecorder();
            testCase.assertTrue(WarningRecorder.active());
            clear rec
            testCase.verifyFalse(WarningRecorder.active());
            testCase.verifyFalse(contains(which('warning'), WarningRecorder.folder()));
            testCase.verifyFalse(isappdata(0, WarningRecorder.key()));
        end

        function testDeletingADeletedHandleIsSilent(testCase)
            % A probe of MATLAB: delete of a handle that is already deleted
            % does not error (the runner guards it with isvalid anyway).
            rec = WarningRecorder();
            delete(rec);
            testCase.verifyFalse(isvalid(rec));
            delete(rec);
            testCase.verifyFalse(WarningRecorder.active());
        end

        function testReleasingTwiceIsHarmless(testCase)
            rec = WarningRecorder();
            delete(rec);
            if isvalid(rec)
                delete(rec);
            end
            testCase.verifyFalse(WarningRecorder.active());
            testCase.verifyFalse(contains(path, WarningRecorder.folder()));
            % Stopping everything first, then clearing the handle.
            rec = WarningRecorder();
            WarningRecorder.releaseAll();
            testCase.verifyFalse(WarningRecorder.active());
            clear rec
            testCase.verifyFalse(contains(path, WarningRecorder.folder()));
            testCase.verifyFalse(isappdata(0, WarningRecorder.key()));
        end

        function testNestedRecordersRecordInTheInnermost(testCase)
            % A second recorder takes over the recording until it is
            % released; the first one then records again, and the path is
            % restored only when the last one is released.
            folder = WarningRecorder.folder();
            outer = WarningRecorder();
            warning('Recorder:outer1', 'a');
            inner = WarningRecorder();
            warning('Recorder:inner', 'b');
            delete(inner);
            testCase.verifyTrue(contains(path, folder));
            warning('Recorder:outer2', 'c');
            testCase.verifyEqual({outer.recorded().identifier}, ...
                {'Recorder:outer1', 'Recorder:outer2'});
            delete(outer);
            testCase.verifyFalse(contains(path, folder));
            testCase.verifyFalse(WarningRecorder.active());
        end

        function testTheShadowFolderIsOutsideTheSourceFolder(testCase)
            % genpath of the source folder, as the test job does, must never
            % pick the shadow up.
            here = fileparts(mfilename('fullpath'));
            source = fullfile(here, '..', 'matlab');
            testCase.verifyFalse(contains(genpath(source), 'warningRecorder'));
            testCase.verifyTrue(isfile(fullfile(WarningRecorder.folder(), 'warning.m')));
        end

    end

end
