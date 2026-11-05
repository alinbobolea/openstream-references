function runTarget(target)
%RUNTARGET Run one named set of reference cases.
%
%   RUNTARGET(TARGET) runs, from the repository root:
%
%   - "tutorial1": the TUTORIAL1 case list (runCases, exportReferences and
%     writeFormatFixture);
%   - "nuthos15-bartolomey": the dataset-driven Bartolomey cases
%     (runDatasetCases);
%   - "input-fixture": the input-parsing cases of cases/input-fixture.json
%     (exportInputFixture);
%   - "semantics-fixture": the function-behaviour and fluid-property cases of
%     cases/semantics-fixture.json (exportSemanticsFixture);
%   - "extension": "semantics-fixture" and then "input-fixture" in one MATLAB
%     session. If the first fails the second still runs, so that its results
%     are saved; the target then errors with References:ExtensionFailed,
%     naming each one that failed and why;
%   - "input-fixture-windows": the cases of cases/input-fixture-windows.json
%     (exportInputFixture), to be run on Windows by the Windows job of the
%     workflow; it is not a choice of the workflow input.
%
%   The accepted names are listed by knownTargets, and every one of them has
%   a case below. Any other target errors with References:UnknownTarget,
%   whose message lists the known targets.

arguments
    target (1,1) string
end

if ~ismember(target, knownTargets())
    error('References:UnknownTarget', 'Unknown target: %s (known targets: %s)', ...
        target, strjoin(knownTargets(), ', '));
end

switch target
    case "tutorial1"
        runCases("cases/tutorial1.json", "upstream/openstream", ...
            "results/tutorial1");
        exportReferences("cases/tutorial1.json", "upstream/openstream", ...
            "results/tutorial1-upstream");
        writeFormatFixture("fixtures/format_fixture.mat");
    case "nuthos15-bartolomey"
        runDatasetCases("cases/nuthos15-bartolomey.json", ...
            "upstream/openstream", "upstream/openstream-database", ...
            "results/nuthos15-bartolomey");
    case "input-fixture"
        exportInputFixture("cases/input-fixture.json", "upstream/openstream", ...
            "results/input-fixture");
    case "semantics-fixture"
        exportSemanticsFixture("cases/semantics-fixture.json", ...
            "upstream/openstream", "results/semantics-fixture");
    case "extension"
        runExtension();
    case "input-fixture-windows"
        exportInputFixture("cases/input-fixture-windows.json", ...
            "upstream/openstream", "results/input-fixture-windows");
end

end

function runExtension()
% The semantics fixture and then the input fixture, each with the calls of
% its own target. An error of one is kept until the other has run, then
% reported with the errors of both.
steps = { ...
    "semantics-fixture", @() exportSemanticsFixture("cases/semantics-fixture.json", ...
        "upstream/openstream", "results/semantics-fixture"); ...
    "input-fixture", @() exportInputFixture("cases/input-fixture.json", ...
        "upstream/openstream", "results/input-fixture")};
failures = strings(1, 0);
for k = 1:size(steps, 1)
    try
        steps{k, 2}();
    catch err
        failures(end+1) = sprintf('%s failed: %s', steps{k, 1}, err.message); %#ok<AGROW>
    end
end
if ~isempty(failures)
    error('References:ExtensionFailed', 'extension: %s', strjoin(failures, '; '));
end
end
