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
%     cases/semantics-fixture.json (exportSemanticsFixture).
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
end

end
