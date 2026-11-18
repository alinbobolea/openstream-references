function overrideInputEntry(baseFile, entryID, overrides, outFile, newID)
%OVERRIDEINPUTENTRY Write one entry of an input file with some values changed.
%
%   OVERRIDEINPUTENTRY(BASEFILE, ENTRYID, OVERRIDES, OUTFILE, NEWID) reads the
%   upstream .inp file BASEFILE, takes the entry whose ID is ENTRYID (the
%   lines from its "ID" line to the next "END" line), and writes to OUTFILE a
%   file holding only that entry, with
%
%   - its ID changed to NEWID;
%   - for every field of the struct OVERRIDES, the value of the line of that
%     key replaced by formatInputValue of the field (the key is the field name
%     in upper case; the text up to the ">" of the line stays), or, when the
%     entry has no line for the key, a new line "KEY ! > value" before END.
%
%   Everything else of the entry is copied unchanged, so that only the named
%   keys differ from the base entry. The ID cannot be an override. A line is
%   read by the rule of the upstream reader: a key, "!", a description, ">",
%   and the value; the first ">" after the "!" ends the description.
%
%   Errors (References:InvalidOverride): BASEFILE is not an .inp file, the
%   entry is not in the file, OVERRIDES has the field ID, a value cannot be
%   written, or a key is given twice (fields that differ only by case).

arguments
    baseFile (1,1) string
    entryID (1,1) string
    overrides (1,1) struct
    outFile (1,1) string
    newID (1,1) string
end

if ~endsWith(lower(baseFile), ".inp")
    error('References:InvalidOverride', ...
        'Overrides are written for .inp files only: %s', baseFile);
end

fields = reshape(string(fieldnames(overrides)), 1, []);
keys = upper(fields);
if any(keys == "ID")
    error('References:InvalidOverride', 'ID cannot be overridden');
end
if numel(unique(keys)) < numel(keys)
    error('References:InvalidOverride', ...
        'A key is overridden twice (keys differing by case count as one)');
end
texts = strings(1, numel(keys));
for k = 1:numel(keys)
    texts(k) = formatInputValue(overrides.(fields(k)));
end
newIDText = formatInputValue(char(newID));

lines = readlines(baseFile);
[first, last] = findEntry(lines, entryID, baseFile);
block = lines(first:last);

% The ID line first, then each override.
block = setValue(block, "ID", newIDText);
for k = 1:numel(keys)
    block = setValue(block, keys(k), texts(k));
end

writelines(block, outFile);

end

function [first, last] = findEntry(lines, entryID, baseFile)
% The line numbers of the first and the last line (END) of the entry ENTRYID.
first = 1;
foundID = false;
for k = 1:numel(lines)
    text = char(lines(k));
    if ~isempty(regexp(text, '^\s*END\s*$', 'once', 'ignorecase'))
        if foundID
            last = k;
            return
        end
        first = k + 1;
        continue
    end
    [key, value] = splitLine(text);
    if strcmpi(key, "ID") && strcmpi(value, entryID)
        foundID = true;
    end
end
error('References:InvalidOverride', ...
    'The entry %s was not found in %s (or has no END line)', entryID, baseFile);
end

function [key, value] = splitLine(text)
% The key and the trimmed value of a "KEY ! description > value" line; both
% are "" when the line is not of that form.
key = "";
value = "";
tokens = regexp(text, '^\s*(\w+)\s*!.*?>\s*"*(.*?)"*\s*$', 'tokens', 'once');
if ~isempty(tokens)
    key = string(tokens{1});
    value = string(tokens{2});
end
end

function block = setValue(block, key, valueText)
% Replace the value of the line of KEY in BLOCK, or add a line before END.
lastLine = numel(block);
for k = 1:lastLine-1
    text = char(block(k));
    [lineKey, ~] = splitLine(text);
    if strcmpi(lineKey, key)
        prefix = regexp(text, '^(\s*\w+\s*!.*?>)', 'tokens', 'once');
        block(k) = string(prefix{1}) + " " + valueText;
        return
    end
end
newLine = sprintf('%-13s! > %s', key, valueText);
block = [block(1:lastLine-1); string(newLine); block(lastLine)];
end
