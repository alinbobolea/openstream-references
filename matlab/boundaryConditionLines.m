function lines = boundaryConditionLines(entries)
%BOUNDARYCONDITIONLINES The text lines of a boundary-condition input file.
%
%   LINES = BOUNDARYCONDITIONLINES(ENTRIES) returns a string column with one
%   block of "KEY ! > value" lines, a line END and an empty line for every
%   element of ENTRIES, in this order. ENTRIES is a struct array or a cell
%   array of structs, as jsondecode returns the list of a case; each field is
%   one key (the field name in upper case) and its value is written by
%   formatInputValue. The keys of an entry are written in the order of its
%   fields.
%
%   Every entry must have the fields TIME, PRESSURE, HIN and MFLOW (the four
%   that upstream's own file writer takes for every entry); no other key is
%   required here.
%
%   Errors (References:InvalidOverride): no entries, an element that is not a
%   struct, a missing required field, a key given twice (fields that differ
%   only by case), or a value that formatInputValue refuses.

if isstruct(entries)
    entries = num2cell(reshape(entries, 1, []));
elseif iscell(entries)
    entries = reshape(entries, 1, []);
else
    error('References:InvalidOverride', ...
        'The boundary conditions must be a struct array or a cell array of structs');
end
if isempty(entries)
    error('References:InvalidOverride', 'The boundary conditions list no entry');
end

required = ["TIME" "PRESSURE" "HIN" "MFLOW"];
lines = strings(0, 1);
for k = 1:numel(entries)
    entry = entries{k};
    if ~isstruct(entry) || ~isscalar(entry)
        error('References:InvalidOverride', ...
            'Boundary-condition entry %d is not a struct', k);
    end
    fields = reshape(string(fieldnames(entry)), 1, []);
    keys = upper(fields);
    if numel(unique(keys)) < numel(keys)
        error('References:InvalidOverride', ...
            'Boundary-condition entry %d gives a key twice', k);
    end
    missing = required(~ismember(required, keys));
    if ~isempty(missing)
        error('References:InvalidOverride', ...
            'Boundary-condition entry %d has no %s', k, strjoin(missing, ', '));
    end
    for j = 1:numel(keys)
        lines(end+1, 1) = sprintf('%-13s! > %s', keys(j), ... %#ok<AGROW>
            formatInputValue(entry.(fields(j))));
    end
    lines(end+1, 1) = "END"; %#ok<AGROW>
    lines(end+1, 1) = ""; %#ok<AGROW>
end

end
