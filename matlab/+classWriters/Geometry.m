function Geometry(filePathName, fidMode, ID, varargin)
%GEOMETRY Write a Geometry input file with a file mode chosen by the caller.
%
%   GEOMETRY(FILEPATHNAME, FIDMODE, ID, NAME1, VALUE1, ...) writes what
%   Inputs.Geometry.writeInputFile writes, with the fopen mode FIDMODE
%   instead of the "a+" that the class method fixes.
%
%   This file is named like the class on purpose. Inputs.Input.writeInputFile
%   finds the property descriptions of the class from the name of the file
%   that calls it (the second entry of dbstack), so the call has to come
%   from a file called Geometry.m. The file does nothing else.

Inputs.Input.writeInputFile(filePathName, fidMode, "ID", ID, varargin{:});

end
