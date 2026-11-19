classdef RunGuardedTest < matlab.unittest.TestCase
    %RUNGUARDEDTEST Tests of failureRecord, writeFailures and runGuarded: the
    % record of a case that failed when a run goes on after a failure.
    %
    % runGuarded takes the work of a case as a function handle, so that the
    % tests give it work that fails and work that does not, without upstream's
    % code.

    methods (TestClassSetup)

        function addPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            here = fileparts(mfilename('fullpath'));
            testCase.applyFixture(PathFixture(fullfile(here, '..', 'matlab')));
        end

    end

    methods (Static)

        function err = caught(identifier, message)
            try
                error(identifier, '%s', message);
            catch err
            end
        end

        function write(file, text)
            fid = fopen(file, 'w');
            fprintf(fid, '%s', text);
            fclose(fid);
        end

    end

    methods (Test)

        function testFailureRecordHoldsTheNameTheIdentifierAndTheMessage(testCase)
            err = RunGuardedTest.caught('Some:identifier', 'It broke here');
            record = failureRecord("case_a", err);
            testCase.verifyEqual(record.name, "case_a");
            testCase.verifyEqual(record.identifier, "Some:identifier");
            testCase.verifyEqual(record.message, "It broke here");
            testCase.verifyClass(record.where, 'string');
        end

        function testFailureRecordNamesTheFunctionOfTheError(testCase)
            err = RunGuardedTest.caught('Some:identifier', 'It broke here');
            record = failureRecord("case_a", err);
            testCase.verifyTrue(contains(record.where, "RunGuardedTest.caught"), ...
                char(record.where));
        end

        function testFailureRecordOfAnErrorWithoutAStackHasAnEmptyWhere(testCase)
            err = MException('Some:identifier', 'No stack');
            record = failureRecord("case_a", err);
            testCase.verifyEqual(record.where, "");
        end

        function testWriteFailuresWritesAnEmptyListWhenNothingFailed(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            folder = testCase.applyFixture(TemporaryFolderFixture).Folder;
            writeFailures(folder, {});
            text = strtrim(fileread(fullfile(folder, 'failures.json')));
            testCase.verifyEqual(text, '[]');
            testCase.verifyEmpty(jsondecode(text));
        end

        function testWriteFailuresWritesEveryFailureInOrder(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            folder = testCase.applyFixture(TemporaryFolderFixture).Folder;
            first = failureRecord("first", RunGuardedTest.caught('A:one', 'm1'));
            second = failureRecord("second", RunGuardedTest.caught('B:two', 'm2 "quoted"'));
            writeFailures(folder, {first, second});
            list = jsondecode(fileread(fullfile(folder, 'failures.json')));
            testCase.assertNumElements(list, 2);
            testCase.verifyEqual(string(list(1).name), "first");
            testCase.verifyEqual(string(list(2).name), "second");
            testCase.verifyEqual(string(list(2).identifier), "B:two");
            testCase.verifyEqual(string(list(2).message), "m2 ""quoted""");
        end

        function testWriteFailuresWritesOneFailureAsAList(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            folder = testCase.applyFixture(TemporaryFolderFixture).Folder;
            only = failureRecord("only", RunGuardedTest.caught('A:one', 'm1'));
            writeFailures(folder, {only});
            text = strtrim(fileread(fullfile(folder, 'failures.json')));
            testCase.verifyEqual(text(1), '[');  % a list, not a bare object
            testCase.verifyNumElements(jsondecode(text), 1);
        end

        function testGuardedWorkThatSucceedsLeavesTheFailuresAsTheyWere(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            folder = testCase.applyFixture(TemporaryFolderFixture).Folder;
            marker = fullfile(folder, 'ran.txt');
            failures = runGuarded(@() RunGuardedTest.write(marker, 'ran'), ...
                "case_a", strings(1, 0), folder, true, {});
            testCase.verifyEmpty(failures);
            testCase.verifyTrue(isfile(marker));  % the work ran
            testCase.verifyFalse(isfolder(fullfile(folder, "case_a-inputs")));
        end

        function testGuardedWorkThatFailsIsRecordedWhenTheRunGoesOn(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            folder = testCase.applyFixture(TemporaryFolderFixture).Folder;
            failures = runGuarded( ...
                @() error('Some:identifier', 'It broke'), "case_a", ...
                strings(1, 0), folder, true, {});
            testCase.assertNumElements(failures, 1);
            testCase.verifyEqual(failures{1}.name, "case_a");
            testCase.verifyEqual(failures{1}.identifier, "Some:identifier");
        end

        function testGuardedFailuresAreAddedToTheEarlierOnes(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            folder = testCase.applyFixture(TemporaryFolderFixture).Folder;
            earlier = {failureRecord("earlier", RunGuardedTest.caught('A:one', 'm'))};
            failures = runGuarded(@() error('B:two', 'm'), "later", ...
                strings(1, 0), folder, true, earlier);
            testCase.assertNumElements(failures, 2);
            testCase.verifyEqual(failures{1}.name, "earlier");
            testCase.verifyEqual(failures{2}.name, "later");
        end

        function testGuardedWorkThatFailsStopsTheRunWhenItIsNotToGoOn(testCase)
            % The control of the test above: the same failure is rethrown.
            import matlab.unittest.fixtures.TemporaryFolderFixture
            folder = testCase.applyFixture(TemporaryFolderFixture).Folder;
            testCase.verifyError(@() runGuarded( ...
                @() error('Some:identifier', 'It broke'), "case_a", ...
                strings(1, 0), folder, false, {}), 'Some:identifier');
            testCase.verifyFalse(isfolder(fullfile(folder, "case_a-inputs")));
        end

        function testGuardedFailureCopiesTheInputFilesOfTheCase(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            folder = testCase.applyFixture(TemporaryFolderFixture).Folder;
            source = testCase.applyFixture(TemporaryFolderFixture).Folder;
            first = fullfile(source, 'model.inp');
            second = fullfile(source, 'bc.inp');
            RunGuardedTest.write(first, 'MODEL');
            RunGuardedTest.write(second, 'BC');
            runGuarded(@() error('Some:identifier', 'It broke'), "case_a", ...
                [string(first) string(second)], folder, true, {});
            testCase.verifyEqual(fileread(fullfile(folder, "case_a-inputs", "model.inp")), 'MODEL');
            testCase.verifyEqual(fileread(fullfile(folder, "case_a-inputs", "bc.inp")), 'BC');
        end

        function testGuardedFailureWithAMissingInputFileStillRecordsTheFailure(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            folder = testCase.applyFixture(TemporaryFolderFixture).Folder;
            failures = runGuarded(@() error('Some:identifier', 'It broke'), ...
                "case_a", string(fullfile(folder, 'not-there.inp')), folder, ...
                true, {});
            testCase.verifyNumElements(failures, 1);
        end

    end

end
