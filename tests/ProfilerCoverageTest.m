classdef ProfilerCoverageTest < matlab.unittest.TestCase
    %PROFILERCOVERAGETEST Unit tests for profilerCoverage and runProfiled.
    %
    % profilerCoverage is tested on profile structs written here, so that the
    % merging, the filtering by folder and the path rules are seen on known
    % input. runProfiled is tested with the real profiler on a small function
    % written to a temporary folder: the statements that run are reported and
    % the statement that does not run is not.

    methods (TestClassSetup)

        function addPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            here = fileparts(mfilename('fullpath'));
            testCase.applyFixture(PathFixture(fullfile(here, '..', 'matlab')));
        end

    end

    methods (Static)

        function entry = entryFor(file, name, lines, counts)
            % One element of a FunctionTable.
            entry = struct('FileName', file, 'FunctionName', name, ...
                'ExecutedLines', [lines(:), counts(:), zeros(numel(lines), 1)]);
        end

        function info = infoOf(entries)
            info = struct('FunctionTable', {entries});
        end

        function out = boom()
            % An action that errors (with an output, as runProfiled calls it).
            error('Probe:boom', 'boom');
            out = 1; %#ok<UNRCH>
        end

    end

    methods (Test)

        function testOneFileGivesItsLinesAndCounts(testCase)
            entries = ProfilerCoverageTest.entryFor('/r/a/B.m', 'B', [3 5 9], [1 2 1]);
            coverage = profilerCoverage(ProfilerCoverageTest.infoOf(entries), "/r");
            testCase.verifySize(coverage, [1 1]);
            testCase.verifyEqual(coverage.file, 'a/B.m');
            testCase.verifyEqual(coverage.lines, [3; 5; 9]);
            testCase.verifyEqual(coverage.counts, [1; 2; 1]);
            testCase.verifyEqual(coverage.functions, {'B'});
        end

        function testEntriesOfOneFileAreMerged(testCase)
            % Two functions of one file; line 5 is reported by both.
            entries = [ ...
                ProfilerCoverageTest.entryFor('/r/B.m', 'B/one', [3 5], [1 2]), ...
                ProfilerCoverageTest.entryFor('/r/B.m', 'B/two', [5 8], [4 1]), ...
                ProfilerCoverageTest.entryFor('/r/B.m', 'B/one', [3], [7])];
            coverage = profilerCoverage(ProfilerCoverageTest.infoOf(entries), "/r");
            testCase.verifySize(coverage, [1 1]);
            testCase.verifyEqual(coverage.lines, [3; 5; 8]);
            testCase.verifyEqual(coverage.counts, [8; 6; 1]);
            testCase.verifyEqual(coverage.functions, {'B/one'; 'B/two'});
        end

        function testFilesOutsideTheRootAreLeftOut(testCase)
            entries = [ ...
                ProfilerCoverageTest.entryFor('/r/B.m', 'B', 1, 1), ...
                ProfilerCoverageTest.entryFor('/other/C.m', 'C', 1, 1), ...
                ProfilerCoverageTest.entryFor('/root2/D.m', 'D', 1, 1)];
            coverage = profilerCoverage(ProfilerCoverageTest.infoOf(entries), "/r");
            testCase.verifyEqual({coverage.file}, {'B.m'});
        end

        function testRootWithTrailingSeparatorGivesTheSameResult(testCase)
            entries = ProfilerCoverageTest.entryFor('/r/B.m', 'B', 1, 1);
            info = ProfilerCoverageTest.infoOf(entries);
            testCase.verifyEqual(profilerCoverage(info, "/r/"), profilerCoverage(info, "/r"));
        end

        function testWindowsSeparatorsAreTurnedIntoSlashes(testCase)
            entries = ProfilerCoverageTest.entryFor('C:\r\+P\B.m', 'B', 2, 1);
            coverage = profilerCoverage(ProfilerCoverageTest.infoOf(entries), "C:\r");
            testCase.verifyEqual(coverage.file, '+P/B.m');
        end

        function testFilesAreSortedByPath(testCase)
            entries = [ ...
                ProfilerCoverageTest.entryFor('/r/z/Z.m', 'Z', 1, 1), ...
                ProfilerCoverageTest.entryFor('/r/a/A.m', 'A', 1, 1), ...
                ProfilerCoverageTest.entryFor('/r/m/M.m', 'M', 1, 1)];
            coverage = profilerCoverage(ProfilerCoverageTest.infoOf(entries), "/r");
            testCase.verifyEqual({coverage.file}, {'a/A.m', 'm/M.m', 'z/Z.m'});
        end

        function testEntryWithoutExecutedLinesStillListsTheFile(testCase)
            entry = struct('FileName', '/r/B.m', 'FunctionName', 'B', ...
                'ExecutedLines', zeros(0, 3));
            coverage = profilerCoverage(ProfilerCoverageTest.infoOf(entry), "/r");
            testCase.verifyEqual(coverage.file, 'B.m');
            testCase.verifySize(coverage.lines, [0 1]);
            testCase.verifySize(coverage.counts, [0 1]);
            testCase.verifyEqual(coverage.functions, {'B'});
        end

        function testNoFileUnderTheRootGivesAnEmptyResult(testCase)
            entries = ProfilerCoverageTest.entryFor('/other/C.m', 'C', 1, 1);
            coverage = profilerCoverage(ProfilerCoverageTest.infoOf(entries), "/r");
            testCase.verifyEmpty(coverage);
            testCase.verifyTrue(isstruct(coverage));
            testCase.verifyEqual(fieldnames(coverage)', ...
                {'file', 'lines', 'counts', 'functions'});
        end

        function testProfileWithoutFunctionTableIsRejected(testCase)
            testCase.verifyError(@() profilerCoverage(struct('other', 1), "/r"), ...
                'References:InvalidProfile');
        end

        function testExecutedLinesWithOneColumnIsRejected(testCase)
            entry = struct('FileName', '/r/B.m', 'FunctionName', 'B', ...
                'ExecutedLines', [3; 4]);
            testCase.verifyError( ...
                @() profilerCoverage(ProfilerCoverageTest.infoOf(entry), "/r"), ...
                'References:InvalidProfile');
        end

        function testRealProfilerReportsRunStatementsAndNotTheOthers(testCase)
            % A function with one statement that runs and one that cannot.
            import matlab.unittest.fixtures.TemporaryFolderFixture
            import matlab.unittest.fixtures.PathFixture
            folder = testCase.applyFixture(TemporaryFolderFixture).Folder;
            testCase.applyFixture(PathFixture(folder));
            lines = [ ...
                "function y = coverageProbe(x)"       % 1
                "y = x + 1;"                          % 2 runs
                "if x < 0"                            % 3 runs
                "    y = -1;"                         % 4 does not run (x = 4)
                "end"                                 % 5
                "y = y * 2;"                          % 6 runs
                "end"];                               % 7
            writelines(lines, fullfile(folder, 'coverageProbe.m'));
            rehash;
            root = fileparts(which('coverageProbe'));

            [value, coverage] = runProfiled(@() coverageProbe(4), root);

            testCase.verifyEqual(value, 10);
            index = find(strcmp({coverage.file}, 'coverageProbe.m'));
            testCase.assertNotEmpty(index, 'the probe is in the profile');
            reported = coverage(index).lines;
            testCase.verifyTrue(all(ismember([2 3 6], reported)), ...
                'the statements that run are reported');
            testCase.verifyFalse(ismember(4, reported), ...
                'the statement that does not run is not reported');
        end

        function testProfilerIsOffAfterARunAndAfterAnError(testCase)
            root = fileparts(which('profilerCoverage'));
            runProfiled(@() 1, root);
            status = profile('status');
            testCase.verifyEqual(status.ProfilerStatus, 'off');
            testCase.verifyError(@() runProfiled(@ProfilerCoverageTest.boom, root), ...
                'Probe:boom');
            status = profile('status');
            testCase.verifyEqual(status.ProfilerStatus, 'off');
        end

    end

end
