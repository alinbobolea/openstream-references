function exportReferences(caseListFile, openstreamRoot, outputDir)
%EXPORTREFERENCES Re-export upstream's committed reference solver objects.
%
%   EXPORTREFERENCES(CASELISTFILE, OPENSTREAMROOT, OUTPUTDIR) loads, for each
%   case with a non-empty upstreamReference, the solver object saved in
%   OPENSTREAMROOT/<upstreamReference>, exports it with exportSolver, and
%   saves it as OUTPUTDIR/<name>.mat (variable "result", MAT-file version 7).
%   It finally writes OUTPUTDIR/environment.json. Comparing these files with
%   RUNCASES output compares a fresh run with upstream's approved references
%   in a format any MAT-file reader can open.

arguments
    caseListFile (1,1) string
    openstreamRoot (1,1) string
    outputDir (1,1) string
end

root = setupOpenstream(openstreamRoot);
cases = jsondecode(fileread(caseListFile));
validateCaseList(cases, root);
if ~iscell(cases)
    cases = num2cell(cases);
end

if ~isfolder(outputDir)
    mkdir(outputDir);
end

for k = 1:numel(cases)
    c = cases{k};
    if ~isfield(c, 'upstreamReference') || strlength(string(c.upstreamReference)) == 0
        continue
    end
    fprintf('\n=== %s (upstream reference) ===\n', c.name);
    saved = load(fullfile(root, c.upstreamReference));
    result = exportSolver(saved.solver, c); %#ok<NASGU> saved below
    save(fullfile(outputDir, c.name + ".mat"), "result", "-v7");
end

environmentRecord(fullfile(outputDir, "environment.json"));

end
