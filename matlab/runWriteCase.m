function result = runWriteCase(e)
%RUNWRITECASE The result of a write case.
%
%   RESULT = RUNWRITECASE(E) makes the successive writeInputFile calls of
%   the manifest entry E (kind write; a scalar struct as jsondecode returns
%   it, valid by validateInputFixtureList) into one new temporary file and
%   returns the text of the file. The arguments of each call are converted
%   by FixtureArguments.writeArguments. The temporary files are removed.
%
%   - A call without a mode is made by the writer of the class
%     (Inputs.Model, Inputs.Options, Inputs.Geometry or
%     Inputs.BoundaryConditions .writeInputFile), which fixes the fopen mode
%     itself ("a+"; for BoundaryConditions "w+" at time 0 and "a+" later).
%   - A call with a mode (the field mode, the fopen mode as text) is made
%     with that mode by the function of the same name in the package
%     classWriters, which calls Inputs.Input.writeInputFile as the class
%     writers do. A mode that makes fopen fail (r+ on a file that does not
%     exist yet) makes the writer error; the error is not caught here.
%   - When some value of some call is an empty text, the case writes twice,
%     each time into a new file: once with the value as the empty char the
%     converter gives, once with it converted by string. RESULT is then
%     struct(char, string): the two texts, in that order. Every other entry
%     gives the text itself (a char row).
%
%   An unknown class or a malformed argument errors with
%   References:InvalidInputFixture. An error of a write is not caught here;
%   exportInputFixture records it as the case's error.

className = char(e.class);
calls = FixtureArguments.list(e.calls);
argsList = cell(1, numel(calls));
modes = cell(1, numel(calls));
for k = 1:numel(calls)
    argsList{k} = FixtureArguments.writeArguments(className, calls{k});
    modes{k} = callMode(calls{k});
end

if hasEmptyText(className, argsList)
    asString = cellfun(@(args) emptyTextsAsStrings(className, args), argsList, ...
        'UniformOutput', false);
    result = struct();
    result.char = writeAll(className, argsList, modes);
    result.string = writeAll(className, asString, modes);
else
    result = writeAll(className, argsList, modes);
end

end

function mode = callMode(call)
% The fopen mode of a call as char, '' when the call has none.
mode = '';
if isfield(call, 'mode')
    m = call.mode;
    if ~((ischar(m) && isrow(m)) || (isstring(m) && isscalar(m))) || strlength(m) == 0
        error('References:InvalidInputFixture', 'The mode of a call must be a text');
    end
    mode = char(m);
end
end

function first = firstValueIndex(className)
% The index in the arguments of a call of the first value: the arguments
% are {id, key1, value1, ...}, or {time, pressure, hin, mflow, key1, value1,
% ...} for BoundaryConditions.
if strcmp(className, 'BoundaryConditions')
    first = 6;
else
    first = 3;
end
end

function tf = hasEmptyText(className, argsList)
tf = false;
for k = 1:numel(argsList)
    args = argsList{k};
    for j = firstValueIndex(className):2:numel(args)
        if ischar(args{j}) && isempty(args{j})
            tf = true;
            return
        end
    end
end
end

function args = emptyTextsAsStrings(className, args)
for j = firstValueIndex(className):2:numel(args)
    if ischar(args{j}) && isempty(args{j})
        args{j} = string(args{j});
    end
end
end

function text = writeAll(className, argsList, modes)
% Successive writeInputFile calls into one new temporary file; its text.
file = [tempname '.inp'];
cleanup = onCleanup(@() deleteIfPresent(file));
for k = 1:numel(argsList)
    writeOne(className, file, argsList{k}, modes{k});
end
text = fileread(file);
clear cleanup
end

function writeOne(className, file, args, mode)
if isempty(mode)
    switch className
        case 'Model'
            Inputs.Model.writeInputFile(file, args{:});
        case 'Options'
            Inputs.Options.writeInputFile(file, args{:});
        case 'Geometry'
            Inputs.Geometry.writeInputFile(file, args{:});
        case 'BoundaryConditions'
            Inputs.BoundaryConditions.writeInputFile(file, args{:});
        otherwise
            % Guards a class that writeArguments accepts but this switch
            % does not, which would otherwise write nothing.
            error('References:InvalidInputFixture', 'Unknown class %s', className);
    end
else
    switch className
        case 'Model'
            classWriters.Model(file, mode, args{:});
        case 'Options'
            classWriters.Options(file, mode, args{:});
        case 'Geometry'
            classWriters.Geometry(file, mode, args{:});
        case 'BoundaryConditions'
            classWriters.BoundaryConditions(file, mode, args{:});
        otherwise
            error('References:InvalidInputFixture', 'Unknown class %s', className);
    end
end
end

function deleteIfPresent(file)
if isfile(file)
    delete(file);
end
end
