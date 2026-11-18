function derived = exportDerived(solver, opts)
%EXPORTDERIVED Value of every public derived-output method, per stored state.
%
%   DERIVED = EXPORTDERIVED(SOLVER) calls, for every stored state of a solved
%   solver, every public method that returns a value, without a node index,
%   and returns the values as plain data.
%
%   Roots. Every public property of SOLVER that holds a non-empty array of
%   objects of one of the classes in opts.objectClasses is a root (for the
%   mixture solver: mixtureInit, the iteration states of the steady run, and
%   mixture, the physical time steps). Each element of a root is a stored
%   state. Within a state, every public property that holds an object of one
%   of those classes is a child (for a mixture: liquid and vapor); the child's
%   methods are called too. Children of children are not followed.
%
%   Methods. A method is called when it is public (hidden ones included), is
%   not static, is defined in a class whose name starts with one of
%   opts.includePrefixes and is not in opts.excludedClasses, is not a
%   constructor or a property accessor, and declares at least one output. It
%   is called with all its declared outputs. The inputs after the object are
%   given as follows, in the order the method declares them; trailing inputs
%   named zIdx or skipAdjustments are left out (the method then uses all
%   nodes); twall is the first output of the state's own TWALL (for a child,
%   its parent's); UPold and MCTold are the values of UP and MCT of the
%   previous stored state of the same root. A method with any other input
%   (for example AFDISTR: param1, param2) is not called and is listed.
%
%   Result.
%
%   - derived.methods: one element per class and method found: class, name,
%     inputNames (the names after the object), outputNames, exported
%     (logical) and reason (why not, or '').
%   - derived.<root>: a struct array, one element per stored state, with
%       values        a struct with one field per exported method: its value,
%                     or, for a method with several outputs, a struct with
%                     one field per declared output;
%       errorId       a struct with the same fields: '' when the call
%                     succeeded, else the MATLAB error identifier, or
%                     References:NoPreviousState (UPold or MCTold needed in the
%                     first state of a root) or References:NoWallTemperature;
%       errorMessage  the same, with the messages;
%       nodeByNode    the same, logical: true when the call for all nodes
%                     errored and the value is built from one call per node;
%       children      a struct with one field per child property, holding the
%                     same four structs (values, errorId, errorMessage,
%                     nodeByNode) for the child.
%     A value of a failed call is [].
%
%   A method whose call for all nodes errors is called once per node (the node
%   index and, for every numeric input with one row per node, that node's row
%   are given); its outputs are stacked, which needs numeric or logical
%   outputs. If that fails too, the failure of the call for all nodes is
%   recorded. No error of a method stops the export. Warnings are switched
%   off during the export and restored after it. The summary is printed.
%
%   Name-value options (for the tests of this function): includePrefixes
%   (default "Solvers."), excludedClasses (default "Solvers.AbstractField"),
%   objectClasses (default ["Solvers.AbstractField" "Solvers.AbstractPhase"]).

arguments
    solver (1,1)
    opts.includePrefixes (1,:) string = "Solvers."
    opts.excludedClasses (1,:) string = "Solvers.AbstractField"
    opts.objectClasses (1,:) string = ["Solvers.AbstractField" "Solvers.AbstractPhase"]
end

warningState = warning('off', 'all');
restoreWarnings = onCleanup(@() warning(warningState));

config = struct('includePrefixes', opts.includePrefixes, ...
    'excludedClasses', opts.excludedClasses, 'objectClasses', opts.objectClasses);

derived = struct();
derived.methods = struct('class', {}, 'name', {}, 'inputNames', {}, ...
    'outputNames', {}, 'exported', {}, 'reason', {});
seenClasses = strings(1, 0);

for rootName = rootNames(solver, config)
    objects = solver.(rootName);
    states = cell(1, numel(objects));
    previous = [];
    for k = 1:numel(objects)
        obj = objects(k);
        [state, methods, twall] = oneObject(obj, previous, [], config);
        [seenClasses, derived.methods] = addMethods(seenClasses, derived.methods, ...
            class(obj), methods);

        children = struct();
        for childName = childNames(obj, config)
            child = obj.(childName);
            previousChild = [];
            if ~isempty(previous) && isfield(previous.children, childName)
                previousChild = previous.children.(childName);
            end
            context = struct('twall', {twall}, 'nz', numberOfNodes(obj, NaN));
            [childState, childMethods] = oneObject(child, previousChild, context, config);
            [seenClasses, derived.methods] = addMethods(seenClasses, derived.methods, ...
                class(child), childMethods);
            children.(childName) = childState;
        end
        state.children = children;
        states{k} = state;
        previous = state;
    end
    derived.(rootName) = [states{:}];
end

printSummary(derived);

end

function names = rootNames(solver, config)
% Public properties of the solver that hold a non-empty array of objects of
% an object class.
names = strings(1, 0);
for p = reshape(string(properties(solver)), 1, [])
    value = readProperty(solver, p);
    if ~isempty(value) && isobject(value) && isOfClass(value, config.objectClasses)
        names(end+1) = p; %#ok<AGROW>
    end
end
end

function names = childNames(obj, config)
% Public, stored properties of a state that hold one object of an object class.
names = strings(1, 0);
mc = metaclass(obj);
for k = 1:numel(mc.PropertyList)
    property = mc.PropertyList(k);
    if property.Dependent || ~(ischar(property.GetAccess) && strcmp(property.GetAccess, 'public'))
        continue
    end
    value = readProperty(obj, property.Name);
    if isscalar(value) && isobject(value) && isOfClass(value, config.objectClasses)
        names(end+1) = string(property.Name); %#ok<AGROW>
    end
end
end

function value = readProperty(obj, name)
% A property value, or [] when it cannot be read.
try
    value = obj.(name);
catch
    value = [];
end
end

function tf = isOfClass(value, classNames)
tf = false;
for name = classNames
    if isa(value, char(name))
        tf = true;
        return
    end
end
end

function n = numberOfNodes(obj, fallback)
% The number of axial nodes of a state (NaN when it cannot be read).
n = fallback;
try
    n = double(obj.NZ);
catch
end
end

function [state, methods, twall] = oneObject(obj, previous, context, config)
% The four structs of one object, the list of its methods, and its TWALL.
% PREVIOUS is the state struct of the previous stored state, or [].
methods = describeMethods(obj, config);
if isempty(context)
    context = struct('twall', {[]}, 'nz', numberOfNodes(obj, NaN));
else
    context.nz = numberOfNodes(obj, context.nz);
end

values = struct();
errorId = struct();
errorMessage = struct();
nodeByNode = struct();

% TWALL first: other methods take its first output.
order = 1:numel(methods);
isTwall = strcmp({methods.name}, 'TWALL') & [methods.exported];
order = [order(isTwall) order(~isTwall)];

twall = context.twall;
for index = order
    method = methods(index);
    if ~method.exported
        continue
    end
    name = method.name;
    [value, id, message, byNode] = callMethod(obj, method, previous, twall, context.nz);
    values.(name) = value;
    errorId.(name) = id;
    errorMessage.(name) = message;
    nodeByNode.(name) = byNode;
    if strcmp(name, 'TWALL') && isempty(id)
        twall = firstOutput(value);
    end
end

state = struct('values', values, 'errorId', errorId, ...
    'errorMessage', errorMessage, 'nodeByNode', nodeByNode);
end

function value = firstOutput(value)
% The first output of a recorded multi-output value.
if isstruct(value)
    names = fieldnames(value);
    value = value.(names{1});
end
end

function list = describeMethods(obj, config)
% The methods of OBJ that the export considers, with the verdict on each.
mc = metaclass(obj);
shortName = regexprep(mc.Name, '^.*\.', '');
list = struct('class', {}, 'name', {}, 'inputNames', {}, 'outputNames', {}, ...
    'exported', {}, 'reason', {});
provided = ["twall" "UPold" "MCTold"];
omitted = ["zIdx" "skipAdjustments"];

for k = 1:numel(mc.MethodList)
    method = mc.MethodList(k);
    definingClass = method.DefiningClass.Name;
    if ~(ischar(method.Access) && strcmp(method.Access, 'public')) ...
            || method.Static || method.Abstract ...
            || strcmp(method.Name, shortName) || contains(method.Name, '.') ...
            || ~any(startsWith(definingClass, config.includePrefixes)) ...
            || any(strcmp(definingClass, config.excludedClasses))
        continue
    end
    inputNames = reshape(string(method.InputNames), 1, []);
    inputNames = inputNames(2:end);
    outputNames = reshape(string(method.OutputNames), 1, []);

    reason = '';
    if isempty(outputNames)
        reason = 'the method declares no output';
    else
        while ~isempty(inputNames) && any(inputNames(end) == omitted)
            inputNames(end) = [];
        end
        needed = setdiff(inputNames, provided, 'stable');
        if ~isempty(needed)
            reason = sprintf('the method needs the input %s', strjoin(needed, ', '));
        end
    end
    allInputs = reshape(string(method.InputNames), 1, []);
    list(end+1) = struct('class', mc.Name, 'name', method.Name, ... %#ok<AGROW>
        'inputNames', {cellstr(allInputs(2:end))}, ...
        'outputNames', {cellstr(outputNames)}, ...
        'exported', isempty(reason), 'reason', reason);
end
end

function [value, id, message, byNode] = callMethod(obj, method, previous, twall, nz)
% One method of one state: its value, error identifier, message, and whether
% it was built node by node.
value = [];
id = '';
message = '';
byNode = false;

[args, id, message] = givenInputs(method, previous, twall);
if ~isempty(id)
    return
end

outputCount = max(1, numel(method.outputNames));
try
    outputs = cell(1, outputCount);
    [outputs{1:outputCount}] = feval(method.name, obj, args{:});
    value = packOutputs(outputs, method.outputNames);
catch wholeError
    value = [];
    id = wholeError.identifier;
    message = wholeError.message;
    if ~hasInput(method, 'zIdx') || ~isfinite(nz)
        return
    end
    try
        outputs = nodeByNodeOutputs(obj, method, args, nz, outputCount);
        value = packOutputs(outputs, method.outputNames);
        id = '';
        message = '';
        byNode = true;
    catch
        value = [];
    end
end
end

function [args, id, message] = givenInputs(method, previous, twall)
% The inputs of a call, in declared order, without trailing zIdx and
% skipAdjustments; id and message say why they cannot be given.
args = {};
id = '';
message = '';
names = reshape(string(method.inputNames), 1, []);
while ~isempty(names) && any(names(end) == ["zIdx" "skipAdjustments"])
    names(end) = [];
end
for k = 1:numel(names)
    switch names(k)
        case "twall"
            if isempty(twall)
                id = 'References:NoWallTemperature';
                message = 'TWALL gave no value for this state';
                return
            end
            args{end+1} = twall; %#ok<AGROW>
        case {"UPold", "MCTold"}
            field = extractBefore(names(k), "old");
            if isempty(previous)
                id = 'References:NoPreviousState';
                message = 'the first stored state of a root has no previous state';
                return
            end
            if ~isfield(previous.values, field) || ~isempty(previous.errorId.(field))
                id = 'References:NoPreviousState';
                message = sprintf('%s of the previous state is not available', field);
                return
            end
            args{end+1} = previous.values.(field); %#ok<AGROW>
    end
end
end

function tf = hasInput(method, name)
tf = any(strcmp(method.inputNames, name));
end

function value = packOutputs(outputs, outputNames)
% One output stays as it is; several become a struct by their declared names.
if numel(outputs) == 1
    value = outputs{1};
else
    names = cellstr(matlab.lang.makeValidName(string(outputNames)));
    value = cell2struct(reshape(outputs, 1, []), reshape(names, 1, []), 2);
end
end

function outputs = nodeByNodeOutputs(obj, method, args, nz, outputCount)
% One call per node; the node index goes where zIdx stands (after the other
% inputs), and every numeric input with nz rows gives that node's row.
parts = cell(nz, outputCount);
for node = 1:nz
    nodeArgs = cellfun(@(a) rowOf(a, node, nz), args, 'UniformOutput', false);
    nodeOutputs = cell(1, outputCount);
    [nodeOutputs{1:outputCount}] = feval(method.name, obj, nodeArgs{:}, node);
    parts(node, :) = nodeOutputs;
end
outputs = cell(1, outputCount);
for j = 1:outputCount
    column = parts(:, j);
    if ~all(cellfun(@(v) isnumeric(v) || islogical(v), column))
        error('References:NodeByNodeNotNumeric', ...
            'Output %d of %s is not numeric, so the nodes cannot be stacked', j, method.name);
    end
    outputs{j} = vertcat(column{:});
end
end

function a = rowOf(a, node, nz)
if isnumeric(a) && size(a, 1) == nz
    a = a(node, :);
end
end

function [seen, methods] = addMethods(seen, methods, className, list)
% The methods of a class are listed once, however many states there are.
if any(seen == string(className))
    return
end
seen(end+1) = string(className);
if ~isempty(list)
    methods = [methods, list];
end
end

function printSummary(derived)
fprintf('exportDerived: %d method(s) found, %d exported\n', ...
    numel(derived.methods), sum([derived.methods.exported]));
for name = reshape(string(fieldnames(derived)), 1, [])
    if name == "methods"
        continue
    end
    states = derived.(name);
    failures = strings(1, 0);
    for k = 1:numel(states)
        failures = [failures, failedMethods(states(k).errorId)]; %#ok<AGROW>
        for child = reshape(string(fieldnames(states(k).children)), 1, [])
            failures = [failures, failedMethods(states(k).children.(child).errorId, child)]; %#ok<AGROW>
        end
    end
    fprintf('  %s: %d state(s), %d failed call(s)', name, numel(states), numel(failures));
    if ~isempty(failures)
        fprintf(': %s', strjoin(unique(failures), ', '));
    end
    fprintf('\n');
end
end

function names = failedMethods(errorId, prefix)
% The methods with a real error (not a missing previous state), as a string row.
if nargin < 2
    prefix = "";
end
names = strings(1, 0);
for name = reshape(string(fieldnames(errorId)), 1, [])
    id = errorId.(name);
    if ~isempty(id) && ~strcmp(id, 'References:NoPreviousState')
        label = name;
        if strlength(prefix) > 0
            label = prefix + "." + name;
        end
        names(end+1) = label; %#ok<AGROW>
    end
end
end
