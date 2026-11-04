function Options(filePathName, fidMode, ID, varargin)
%OPTIONS Write an Options input file with a file mode chosen by the caller.
%
%   OPTIONS(FILEPATHNAME, FIDMODE, ID, NAME1, VALUE1, ...) writes what
%   Inputs.Options.writeInputFile writes, with the fopen mode FIDMODE
%   instead of the "a+" that the class method fixes.
%
%   This file is named like the class on purpose. Inputs.Input.writeInputFile
%   finds the property descriptions of the class from the name of the file
%   that calls it (the second entry of dbstack), so the call has to come
%   from a file called Options.m. The file does nothing else.

Inputs.Input.writeInputFile(filePathName, fidMode, "ID", ID, varargin{:});

end
