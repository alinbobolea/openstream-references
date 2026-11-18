function coverage = profilerCoverage(info, root)
%PROFILERCOVERAGE Executed lines per file, from the output of profile('info').
%
%   COVERAGE = PROFILERCOVERAGE(INFO, ROOT) reads INFO.FunctionTable (the
%   struct returned by profile('info')) and returns a struct array with one
%   element for every file under the folder ROOT that the profiler recorded,
%   sorted by file, with the fields
%
%   - file:      the path of the file relative to ROOT, with "/" as the
%                separator;
%   - lines:     the line numbers the profiler reported as executed (a
%                sorted column, each number once), taken over every entry of
%                the function table that belongs to the file;
%   - counts:    how many times each of those lines ran, summed over the
%                entries (a column of the same size);
%   - functions: the names of the function table entries of the file (a
%                cellstr column, each name once).
%
%   Entries whose file is not under ROOT (MATLAB's own files, other code) are
%   left out. The path comparison is made on the text, after the separators
%   are turned into "/"; ROOT must therefore be written as the profiler
%   writes file names (an absolute path). With no file under ROOT the result
%   is an empty struct array.
%
%   Errors: References:InvalidProfile when INFO has no FunctionTable, or when
%   an entry's ExecutedLines is neither empty nor an array with at least
%   two columns (line number, count).

arguments
    info (1,1) struct
    root (1,1) string
end

if ~isfield(info, 'FunctionTable')
    error('References:InvalidProfile', 'The profile has no FunctionTable field');
end

prefix = replace(root, "\", "/");
if ~endsWith(prefix, "/")
    prefix = prefix + "/";
end

table = info.FunctionTable;
files = strings(0, 1);
lineLists = cell(0, 1);
countLists = cell(0, 1);
functionLists = cell(0, 1);

for k = 1:numel(table)
    fileName = replace(string(table(k).FileName), "\", "/");
    if ~startsWith(fileName, prefix)
        continue
    end
    relative = extractAfter(fileName, strlength(prefix));
    executed = table(k).ExecutedLines;
    if isempty(executed)
        executed = zeros(0, 2);
    elseif size(executed, 2) < 2
        error('References:InvalidProfile', ...
            'ExecutedLines of %s has %d column(s), at least 2 are needed', ...
            fileName, size(executed, 2));
    end

    index = find(files == relative, 1);
    if isempty(index)
        files(end+1, 1) = relative; %#ok<AGROW>
        lineLists{end+1, 1} = zeros(0, 1); %#ok<AGROW>
        countLists{end+1, 1} = zeros(0, 1); %#ok<AGROW>
        functionLists{end+1, 1} = strings(0, 1); %#ok<AGROW>
        index = numel(files);
    end
    lineLists{index} = [lineLists{index}; executed(:, 1)];
    countLists{index} = [countLists{index}; executed(:, 2)];
    functionLists{index} = [functionLists{index}; string(table(k).FunctionName)];
end

[files, order] = sort(files);
coverage = struct('file', {}, 'lines', {}, 'counts', {}, 'functions', {});
for k = 1:numel(files)
    j = order(k);
    if isempty(lineLists{j})
        lines = zeros(0, 1);
        counts = zeros(0, 1);
    else
        [lines, ~, group] = unique(lineLists{j});
        counts = accumarray(group, countLists{j}, [numel(lines) 1]);
    end
    coverage(k).file = char(files(k));
    coverage(k).lines = lines(:);
    coverage(k).counts = counts(:);
    coverage(k).functions = cellstr(unique(functionLists{j}));
end

end
