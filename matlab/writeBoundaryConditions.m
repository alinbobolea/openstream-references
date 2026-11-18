function writeBoundaryConditions(entries, outFile)
%WRITEBOUNDARYCONDITIONS Write a boundary-condition input file from its entries.
%
%   WRITEBOUNDARYCONDITIONS(ENTRIES, OUTFILE) writes the text that
%   boundaryConditionLines(ENTRIES) returns to the upstream .inp file OUTFILE.
%   The errors are those of boundaryConditionLines.

arguments
    entries
    outFile (1,1) string
end

writelines(boundaryConditionLines(entries), outFile);

end
