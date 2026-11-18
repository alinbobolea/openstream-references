function calibration = calibrateProfiler()
%CALIBRATEPROFILER Record which source lines MATLAB's profiler reports.
%
%   CALIBRATION = CALIBRATEPROFILER() runs the class Calibration.ProfilerSample
%   under the profiler (runProfiled), with calls that are known to execute some
%   of its lines and not others, and returns a struct with the fields
%
%   - sourceFile:    the path of the class file, relative to the folder matlab;
%   - matlabVersion: the output of version;
%   - sourceLines:   the number of lines of the file;
%   - reportedLines: the line numbers the profiler reported for the file (a
%                    column; empty when the file is not in the profile);
%   - functions:     the names of the profile entries of the file;
%   - entries:       one element for every line of the file that has a tag in
%                    a trailing comment (see Calibration.ProfilerSample):
%                    line, text, expected ('ran', 'never' or 'label'), kind,
%                    and reported (true when the profiler reported the line).
%
%   The result states what the profiler reports for classdef methods, for the
%   statement lines of an if, a switch, a for loop and a try, for the lines of
%   a statement continued with "...", and for signature, else, case, otherwise,
%   catch and end lines, so that the lines an upstream file requires of a case
%   are decided from MATLAB's own output.

sourceFile = which('Calibration.ProfilerSample');
if isempty(sourceFile)
    error('References:CalibrationSampleMissing', ...
        'Calibration.ProfilerSample is not on the path');
end
matlabFolder = fileparts(fileparts(sourceFile));

[~, coverage] = runProfiled(@runSample, matlabFolder);

relative = "+Calibration/ProfilerSample.m";
index = find(strcmp({coverage.file}, char(relative)), 1);
reported = zeros(0, 1);
functions = cell(0, 1);
if ~isempty(index)
    reported = coverage(index).lines;
    functions = coverage(index).functions;
end

lines = readlines(sourceFile);
entries = taggedLines(lines, reported);

calibration = struct();
calibration.sourceFile = char(relative);
calibration.matlabVersion = version;
calibration.sourceLines = numel(lines);
calibration.reportedLines = reported;
calibration.functions = functions;
calibration.entries = entries;

end

function runSample()
% The calls whose executed lines are known: see the tags in the class.
sample = Calibration.ProfilerSample(5);
sample.branches(1);
sample.branches(3);
sample.twoWay(true);
sample.continued();
sample.looped();
sample.guarded();
sample.withLocalCall();
end

function entries = taggedLines(lines, reported)
% One element for each line that has a tag in a trailing comment. A line
% whose first non-blank character is % is documentation, not a tagged line.
entries = struct('line', {}, 'text', {}, 'expected', {}, 'kind', {}, 'reported', {});
for k = 1:numel(lines)
    text = char(lines(k));
    if startsWith(strtrim(text), '%')
        continue
    end
    tokens = regexp(text, '\[(ran|never|label):([A-Za-z0-9-]+)\]', 'tokens', 'once');
    if isempty(tokens)
        continue
    end
    entries(end+1) = struct('line', k, 'text', strtrim(text), ... %#ok<AGROW>
        'expected', tokens{1}, 'kind', tokens{2}, ...
        'reported', any(reported == k));
end
end
