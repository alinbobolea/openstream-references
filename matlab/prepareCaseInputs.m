function prepared = prepareCaseInputs(c, inputFolder, caseFolder)
%PREPARECASEINPUTS The input files and IDs of an input-file case.
%
%   PREPARED = PREPARECASEINPUTS(C, INPUTFOLDER, CASEFOLDER) returns a struct
%   with the fields modelFilePath, modelID, optionsFilePath, optionsID,
%   geometryFilePath, geometryID and bcFilePath for the case C (a case-list
%   entry, see validateCaseList), and overrides (the struct of the override
%   structs the case has, with the fields model, options and geometry; empty
%   fields are absent).
%
%   A case without overrides uses the files of INPUTFOLDER as they are. For
%   each of model, options and geometry that the case has as a non-empty
%   struct, overrideInputEntry writes the entry with the override values to
%   CASEFOLDER (under the name of the base file), with the ID upper(C.name),
%   and that file and ID are used. When the case has boundaryConditions,
%   writeBoundaryConditions writes them to CASEFOLDER/<bcFile name>, and that
%   file is used in place of the base boundary-condition file. CASEFOLDER is
%   made when something is written.

arguments
    c (1,1) struct
    inputFolder (1,1) string
    caseFolder (1,1) string
end

kinds = ["model" "options" "geometry"];
prepared = struct();
prepared.overrides = struct();
newID = upper(string(c.name));

for kind = kinds
    file = string(c.(kind + "File"));
    id = string(c.(kind + "ID"));
    path = fullfile(inputFolder, file);
    if isfield(c, kind) && isstruct(c.(kind)) && ~isempty(fieldnames(c.(kind)))
        makeFolder(caseFolder);
        outFile = fullfile(caseFolder, file);
        overrideInputEntry(path, id, c.(kind), outFile, newID);
        path = outFile;
        id = newID;
        prepared.overrides.(kind) = c.(kind);
    end
    prepared.(kind + "FilePath") = char(path);
    prepared.(kind + "ID") = char(id);
end

bcPath = fullfile(inputFolder, string(c.bcFile));
if isfield(c, 'boundaryConditions')
    makeFolder(caseFolder);
    outFile = fullfile(caseFolder, string(c.bcFile));
    writeBoundaryConditions(c.boundaryConditions, outFile);
    bcPath = outFile;
end
prepared.bcFilePath = char(bcPath);

end

function makeFolder(folder)
if ~isfolder(folder)
    mkdir(folder);
end
end
