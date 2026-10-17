classdef InputFileReader < Inputs.Input
    %INPUTFILEREADER Expose OpenSTREAM's input-file parser for the input fixture.
    %
    %   S = INPUTFILEREADER.READ(FILE) returns what the protected static
    %   method Inputs.Input.readInputFile returns for FILE, unchanged. The
    %   subclass exists only to reach that method; it adds no behaviour.
    %   OpenSTREAM must be on the path.

    methods (Static)

        function inputStruct = read(filePath)
            inputStruct = Inputs.Input.readInputFile(filePath);
        end

    end

end
