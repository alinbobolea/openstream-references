function exportSemanticsFixture(manifestFile, openstreamRoot, outputDir)
%EXPORTSEMANTICSFIXTURE Record what MATLAB functions and the fluid properties do.
%
%   EXPORTSEMANTICSFIXTURE(MANIFESTFILE, OPENSTREAMROOT, OUTPUTDIR) puts
%   OpenSTREAM on the path, reads the manifest MANIFESTFILE (a JSON array of
%   cases, see validateSemanticsList) and validates it, files included,
%   before any case runs. It then runs every case and saves
%   OUTPUTDIR/semantics_fixture.mat (MAT-file version 7) holding one
%   variable, "fixture", a struct whose field "cases" is a 1xN cell array,
%   one struct per manifest entry:
%
%   - name, kind:         from the manifest entry;
%   - input:              the manifest entry (toPlain);
%   - args:               for an mcall case, a cell with describeValue of each
%                         converted argument (recorded even when the call
%                         errors); {} for the other kinds;
%   - ok:                 true when the case finished without error;
%   - errorId,
%     errorMessage:       the error ('' when ok);
%   - console:            everything the case printed, warnings included
%                         (evalc, warning backtraces off);
%   - lastWarningId,
%     lastWarningMessage: lastwarn after the case (reset to '' before it);
%   - result:             the case's result, per kind (runSemanticsCase; []
%                         when not ok).
%
%   Every case runs inside try/catch with the same warning state, so one
%   failing case never stops the run or changes the next one. Many cases
%   fail on purpose (sizes that do not match, arguments a function refuses):
%   those errors are data. The run then writes
%   OUTPUTDIR/environment.json and finally errors with
%   References:InvalidSemanticsFixture if a case failed with an identifier
%   that starts with "References:", which only the fixture's own code raises
%   (a malformed manifest or an unknown kind), so that a manifest fault
%   cannot pass for an intended failure. File paths in the manifest are
%   relative to the current folder.

arguments
    manifestFile (1,1) string
    openstreamRoot (1,1) string
    outputDir (1,1) string
end

setupOpenstream(openstreamRoot);
entries = jsondecode(fileread(manifestFile));
validateSemanticsList(entries, true);
entries = FixtureArguments.list(entries);

if ~isfolder(outputDir)
    mkdir(outputDir);
end

previousWarnings = warning;
restoreWarnings = onCleanup(@() warning(previousWarnings));
warning('off', 'backtrace');
caseWarnings = warning;

cases = cell(1, numel(entries));
for k = 1:numel(entries)
    warning(caseWarnings);
    cases{k} = runCase(entries{k});
    fprintf('%s (%s): ok=%d\n', cases{k}.name, cases{k}.kind, cases{k}.ok);
end
clear restoreWarnings

fixture = struct();
fixture.cases = cases;
save(fullfile(outputDir, "semantics_fixture.mat"), "fixture", "-v7");

environmentRecord(fullfile(outputDir, "environment.json"));

checkFixtureErrors(cases);

end

function c = runCase(entry)
% One case, with its console output, last warning and error recorded.
c = struct();
c.name = char(entry.name);
c.kind = char(entry.kind);
c.input = toPlain(entry);

lastwarn('', '');
[console, outcome] = runCaptured(@() runGuarded(entry));
[warningMessage, warningId] = lastwarn;

c.args = outcome.args;
c.ok = isempty(outcome.err);
if c.ok
    c.errorId = '';
    c.errorMessage = '';
    result = outcome.result;
else
    c.errorId = outcome.err.identifier;
    c.errorMessage = outcome.err.message;
    result = [];
end
c.console = console;
c.lastWarningId = warningId;
c.lastWarningMessage = warningMessage;
c.result = result;
end

function [console, outcome] = runCaptured(guarded)
% Call GUARDED (which never throws) for its outcome, capturing the console
% with evalc; console is '' when evalc itself fails.
try
    % Outputs named in the evalc call, as the evalc documentation advises.
    [console, outcome] = evalc('guarded()');
catch evalcError
    % runGuarded catches every error of the case; this guards evalc itself.
    console = '';
    outcome = struct('args', {{}}, 'result', [], 'err', evalcError);
end
end

function outcome = runGuarded(entry)
% Run one case; return its arguments, result and error instead of throwing.
outcome = struct('args', {{}}, 'result', [], 'err', []);
try
    outcome.args = describedArguments(entry);
    outcome.result = runSemanticsCase(entry);
catch caught
    outcome.err = caught;
end
end

function args = describedArguments(entry)
% describeValue of each converted argument of an mcall case ({} for other
% kinds). Set before the call is made, so the arguments of a call that
% errors are still recorded.
args = {};
if ~strcmp(char(entry.kind), 'mcall')
    return
end
list = FixtureArguments.list(entry.args);
args = cell(1, numel(list));
for k = 1:numel(list)
    args{k} = describeValue(FixtureArguments.value(list{k}));
end
end

function checkFixtureErrors(cases)
% Fail when a case failed with an identifier of the fixture's own code.
bad = strings(1, 0);
for k = 1:numel(cases)
    if startsWith(cases{k}.errorId, 'References:')
        bad(end+1) = string(cases{k}.name); %#ok<AGROW>
    end
end
if ~isempty(bad)
    error('References:InvalidSemanticsFixture', ...
        'Case(s) failed because of the manifest: %s', strjoin(bad, ', '));
end
end
