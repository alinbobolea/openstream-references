function probes = exportProbes(solver, opts)
%EXPORTPROBES Direct calls of the Mixture classes that no solve makes.
%
%   PROBES = EXPORTPROBES(SOLVER) makes, on a solved Mixture solver, four calls
%   that the solve itself never reaches, and returns what each gave. Run under
%   the profiler (runProfiled) it records the lines those calls execute, and the
%   answers can be compared with another program's:
%
%   - construct: a Mixture built with its two arguments, (inputSet, fluid), as
%     a user can build one; the solver builds its states without arguments and
%     sets their properties;
%   - chf: the critical heat flux asked for at some nodes, CHF(zIdx), of the last
%     physical state, beside the value for all nodes;
%   - copyAll: copyFlowProperties with all = true (every row, the inlet row
%     included) from the first iteration state into a copy of the second;
%   - copyMismatch: copyFlowProperties into an object that is not on the mesh
%     of the source (a Mixture built without arguments), which upstream refuses
%     with the error AbstractFieldError:copyFlowPropertiesError.
%
%   Every probe is a struct with the logical field ok (the call completed), the
%   char fields errorId and errorMessage ('' when it completed), and its own
%   fields:
%
%   - construct:     class (the class of the object that was built);
%   - chf:           zIdx (the nodes asked for, a column), values (CHF at those
%                    nodes), full (CHF for all nodes);
%   - copyAll:       sourceW, sourceH (the source's mass flow rate and enthalpy),
%                    targetBeforeW, targetBeforeH (the target's, before the copy),
%                    targetAfterW, targetAfterH (after it);
%   - copyMismatch:  threw (the copy errored, which is the answer upstream gives
%                    for objects that are not on one mesh), thrownId and
%                    thrownMessage (that error; '' when it did not error). The
%                    probe itself completes, so ok is true.
%
%   A probe that errors does not stop the others. A solver that is not a Mixture
%   solver (the other solvers of upstream) gives an empty struct: the calls are
%   those of the Mixture classes only.
%
%   Name-value option (for the tests of this function): mixtureClass (default
%   "Solvers.Mixture.Mixture"), the class that the construct and copyMismatch
%   probes build.

arguments
    solver (1,1)
    opts.mixtureClass (1,1) string = "Solvers.Mixture.Mixture"
end

probes = struct();
if ~isprop(solver, 'mixture') || ~isprop(solver, 'mixtureInit')
    return
end

% Warnings of the calls are not part of the export (restored when it ends).
warningState = warning;
warning('off', 'all');
restoreWarnings = onCleanup(@() warning(warningState));

probes.construct = tryProbe(@() probeConstruct(solver, opts.mixtureClass));
probes.chf = tryProbe(@() probeChf(solver));
probes.copyAll = tryProbe(@() probeCopyAll(solver));
probes.copyMismatch = tryProbe(@() probeCopyMismatch(solver, opts.mixtureClass));

end

function result = tryProbe(call)
% The result of CALL with ok true, or ok false with the error that stopped it.
try
    result = call();
    result.ok = true;
    result.errorId = '';
    result.errorMessage = '';
catch err
    result = struct('ok', false, 'errorId', char(err.identifier), ...
        'errorMessage', char(err.message));
end
end

function result = probeConstruct(solver, mixtureClass)
built = feval(mixtureClass, solver.inputSet, solver.fluid);
result = struct('class', class(built));
end

function result = probeChf(solver)
states = solver.mixture;
last = states(end);
nz = last.NZ;
zIdx = unique([1; ceil(nz / 2); nz]);
result = struct('zIdx', zIdx, 'values', last.CHF(zIdx), 'full', last.CHF);
end

function result = probeCopyAll(solver)
states = solver.mixtureInit;
source = states(1);
target = copy(states(2));
before = struct('W', target.W, 'H', target.H);
copyFlowProperties(source, target, 'all', true);
result = struct('sourceW', source.W, 'sourceH', source.H, ...
    'targetBeforeW', before.W, 'targetBeforeH', before.H, ...
    'targetAfterW', target.W, 'targetAfterH', target.H);
end

function result = probeCopyMismatch(solver, mixtureClass)
% The error is the answer: the probe reports it, and fails when there is none.
source = solver.mixtureInit(1);
target = feval(mixtureClass);
try
    copyFlowProperties(source, target);
catch err
    result = struct('threw', true, 'thrownId', char(err.identifier), ...
        'thrownMessage', char(err.message));
    return
end
result = struct('threw', false, 'thrownId', '', 'thrownMessage', '');
end
