classdef ProfilerCalibrationTest < matlab.unittest.TestCase
    %PROFILERCALIBRATIONTEST Unit tests for calibrateProfiler.
    %
    % The sample class Calibration.ProfilerSample is run under the real
    % profiler. What the tests assert is what must hold whatever the profiler
    % does with signature, case, else, catch and end lines (those are only
    % recorded, by the entries tagged "label"): a statement that ran is
    % reported, a statement that did not run is not, and the record is
    % complete and consistent with the source file. The first two are the
    % assumption that a required-line rule can be built on; if the profiler
    % does not report the lines of classdef methods, the first test fails and
    % that is the finding.

    methods (TestClassSetup)

        function addPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            here = fileparts(mfilename('fullpath'));
            testCase.applyFixture(PathFixture(fullfile(here, '..', 'matlab')));
        end

    end

    methods (Static)

        function expected = tagsInSource()
            % The tagged lines of the sample, read here again from the file
            % (a second reading, independent of calibrateProfiler's): a struct
            % array with line, expected and kind.
            file = which('Calibration.ProfilerSample');
            lines = readlines(file);
            expected = struct('line', {}, 'expected', {}, 'kind', {});
            for k = 1:numel(lines)
                text = char(lines(k));
                if startsWith(strtrim(text), '%')
                    continue
                end
                tokens = regexp(text, '\[(ran|never|label):([A-Za-z0-9-]+)\]', ...
                    'tokens');
                for j = 1:numel(tokens)
                    expected(end+1) = struct('line', k, ... %#ok<AGROW>
                        'expected', tokens{j}{1}, 'kind', tokens{j}{2});
                end
            end
        end

    end

    methods (Test)

        function testStatementsThatRanAreReported(testCase)
            calibration = calibrateProfiler();
            ran = calibration.entries(strcmp({calibration.entries.expected}, 'ran'));
            testCase.assertNotEmpty(ran);
            notReported = ran(~[ran.reported]);
            testCase.verifyEmpty(notReported, sprintf( ...
                'executed statements the profiler did not report: lines %s', ...
                num2str([notReported.line])));
        end

        function testStatementsThatDidNotRunAreNotReported(testCase)
            calibration = calibrateProfiler();
            never = calibration.entries(strcmp({calibration.entries.expected}, 'never'));
            testCase.assertNotEmpty(never);
            reported = never([never.reported]);
            testCase.verifyEmpty(reported, sprintf( ...
                'statements that did not run but were reported: lines %s', ...
                num2str([reported.line])));
        end

        function testEveryTaggedLineIsInTheRecord(testCase)
            calibration = calibrateProfiler();
            expected = ProfilerCalibrationTest.tagsInSource();
            testCase.assertNotEmpty(expected);
            testCase.verifyEqual([calibration.entries.line], [expected.line]);
            testCase.verifyEqual({calibration.entries.expected}, {expected.expected});
            testCase.verifyEqual({calibration.entries.kind}, {expected.kind});
        end

        function testRecordHoldsEveryKindOfTag(testCase)
            % The sample has statements that run, statements that do not,
            % and lines to be recorded; a sample that lost one of the kinds
            % would make the two tests above empty.
            expected = ProfilerCalibrationTest.tagsInSource();
            kinds = unique({expected.expected});
            testCase.verifyEqual(sort(kinds), {'label', 'never', 'ran'});
        end

        function testReportedLinesAreLinesOfTheFile(testCase)
            calibration = calibrateProfiler();
            lines = calibration.reportedLines;
            testCase.verifyNotEmpty(lines);
            testCase.verifyTrue(all(lines >= 1 & lines <= calibration.sourceLines));
            testCase.verifyEqual(lines, unique(lines));
        end

        function testRecordNamesTheFileTheFunctionsAndTheVersion(testCase)
            calibration = calibrateProfiler();
            testCase.verifyEqual(calibration.sourceFile, '+Calibration/ProfilerSample.m');
            testCase.verifyEqual(calibration.matlabVersion, version);
            testCase.verifyNotEmpty(calibration.functions);
            testCase.verifyEqual(calibration.sourceLines, ...
                numel(readlines(which('Calibration.ProfilerSample'))));
        end

        function testReportedFlagOfAnEntryAgreesWithTheReportedLines(testCase)
            calibration = calibrateProfiler();
            for entry = calibration.entries
                testCase.verifyEqual(entry.reported, ...
                    ismember(entry.line, calibration.reportedLines), ...
                    sprintf('line %d', entry.line));
            end
        end

    end

end
