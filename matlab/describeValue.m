function d = describeValue(v)
%DESCRIBEVALUE Describe a value with its class and size, in plain MATLAB types.
%
%   D = DESCRIBEVALUE(V) returns a struct with fields:
%
%   - class: class(V) (char)
%   - size:  size(V) (double row)
%   - value: V in plain types, by these rules (first match wins):
%     - enumeration members: toPlain(V), their member names. Checked first:
%       members of numeric-based enumerations also count as numeric;
%     - numeric, logical and char: V unchanged;
%     - string: cellstr(V), reshaped to size(V);
%     - struct: a struct with fields "fields" (a cellstr row of the field
%       names, in order) and "elements" (a cell of size(V); each element
%       is a struct whose fields hold describeValue of that element's
%       field values);
%     - cell: describeValue of every element, same size;
%     - function handle: func2str(V);
%     - any other object: toPlain(V).
%
%   Unlike toPlain alone, the class and size of every level are kept, so a
%   reader can tell a string from a char, a 1x1 cell from its content, or a
%   row from a column.

d = struct();
d.class = class(v);
d.size = size(v);
if isEnumeration(v)
    d.value = toPlain(v);
elseif isnumeric(v) || islogical(v) || ischar(v)
    d.value = v;
elseif isstring(v)
    d.value = reshape(cellstr(v), size(v));
elseif isstruct(v)
    d.value = describeStruct(v);
elseif iscell(v)
    d.value = cellfun(@describeValue, v, 'UniformOutput', false);
elseif isa(v, 'function_handle')
    d.value = func2str(v);
else
    d.value = toPlain(v);
end

end

function out = describeStruct(s)
names = reshape(fieldnames(s), 1, []);
elements = cell(size(s));
for k = 1:numel(s)
    element = struct();
    for j = 1:numel(names)
        element.(names{j}) = describeValue(s(k).(names{j}));
    end
    elements{k} = element;
end
out = struct();
out.fields = names;
out.elements = elements;
end

function tf = isEnumeration(v)
tf = false;
if isobject(v)
    mc = metaclass(v);
    tf = mc.Enumeration;
end
end
