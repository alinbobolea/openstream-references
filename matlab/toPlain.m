function out = toPlain(value, opts)
%TOPLAIN Convert a value, including OpenSTREAM objects, to plain MATLAB types.
%
%   OUT = TOPLAIN(VALUE) returns VALUE with every object converted to
%   numeric, logical, char, cell or struct data, so that any MAT-file reader
%   can open the result.
%
%   OUT = TOPLAIN(VALUE, includePrefixes=PREFIXES) converts objects whose
%   class name starts with one of PREFIXES. Default: "Solvers.", "Inputs.",
%   "Session.".
%
%   Rules, first match wins:
%
%   - Enumeration members become their member names (char, or a cellstr of
%     the same size). Checked first: members of uint16-based enumerations
%     such as Solvers.SolverState also count as numeric.
%   - Numeric, logical and char values are returned unchanged.
%   - Strings become char (scalar) or a cellstr of the same size.
%   - Structs and cells keep their size; every field or element is converted.
%   - Function handles become their text (func2str).
%   - Objects of an included class become structs with one field per stored
%     property: the properties MATLAB itself saves (not Dependent, Transient
%     or Constant), including private ones. Arrays keep their size. A handle
%     already converted becomes '<cycle:CLASS>'; an object whose properties
%     cannot be read becomes '<unreadable:CLASS:ERRORID>'.
%   - Anything else becomes '<skipped:CLASS>'.

arguments
    value
    opts.includePrefixes (1,:) string = ["Solvers." "Inputs." "Session."]
end

visited = {};
out = convert(value);

    function out = convert(v)
        if isEnumeration(v)
            out = enumerationNames(v);
        elseif isnumeric(v) || islogical(v) || ischar(v)
            out = v;
        elseif isstring(v)
            if isscalar(v)
                out = char(v);
            else
                out = cellstr(v);
            end
        elseif isstruct(v)
            out = convertStruct(v);
        elseif iscell(v)
            out = cellfun(@convert, v, 'UniformOutput', false);
        elseif isa(v, 'function_handle')
            out = func2str(v);
        elseif isobject(v) && startsWith(class(v), opts.includePrefixes)
            out = convertObjects(v);
        else
            out = sprintf('<skipped:%s>', class(v));
        end
    end

    function out = convertStruct(s)
        out = s;
        names = fieldnames(s);
        for k = 1:numel(s)
            for j = 1:numel(names)
                out(k).(names{j}) = convert(s(k).(names{j}));
            end
        end
    end

    function out = convertObjects(objs)
        if isempty(objs)
            out = struct([]);
            return
        end
        if isscalar(objs)
            % A single object gives its struct or its marker text directly.
            out = convertObject(objs);
            return
        end
        parts = cell(size(objs));
        for k = 1:numel(objs)
            parts{k} = convertObject(objs(k));
        end
        % One struct array when every element converted to a struct with the
        % same fields; otherwise (a cycle marker, or mixed classes) a cell
        % array of the same size.
        if all(cellfun(@isstruct, parts(:))) && sameFields(parts)
            out = reshape([parts{:}], size(objs));
        else
            out = parts;
        end
    end

    function out = convertObject(obj)
        if isa(obj, 'handle')
            for k = 1:numel(visited)
                if strcmp(class(visited{k}), class(obj)) && visited{k} == obj
                    out = sprintf('<cycle:%s>', class(obj));
                    return
                end
            end
            visited{end+1} = obj;
        end
        mc = metaclass(obj);
        props = mc.PropertyList;
        stored = props(~[props.Dependent] & ~[props.Transient] & ~[props.Constant]);
        % struct() is the only way to read private properties from outside a
        % class; its warning about that is expected here.
        warningState = warning('off', 'MATLAB:structOnObject');
        try
            raw = struct(obj);
        catch err
            warning(warningState);
            out = sprintf('<unreadable:%s:%s>', class(obj), err.identifier);
            return
        end
        warning(warningState);
        out = struct();
        for j = 1:numel(stored)
            out.(stored(j).Name) = convert(raw.(stored(j).Name));
        end
    end

end

function tf = isEnumeration(v)
% True for enumeration members, including those derived from numeric types.
tf = false;
if isobject(v)
    mc = metaclass(v);
    tf = mc.Enumeration;
end
end

function out = enumerationNames(v)
% Member names, looked up from the class so that members of numeric-based
% enumerations give their names, not their values.
[members, names] = enumeration(v);
out = cell(size(v));
for k = 1:numel(v)
    out{k} = names{find(members == v(k), 1)};
end
if isscalar(out)
    out = out{1};
end
end

function tf = sameFields(parts)
first = fieldnames(parts{1});
tf = all(cellfun(@(p) isequal(fieldnames(p), first), parts(:)));
end
