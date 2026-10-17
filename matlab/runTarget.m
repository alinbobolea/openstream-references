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
%     (exportInputFixture).
%
%   Any other target errors with References:UnknownTarget.

arguments
    target (1,1) string
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
    otherwise
        error('References:UnknownTarget', 'Unknown target: %s', target);
end

end
