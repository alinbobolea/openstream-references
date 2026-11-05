function exe = pythonExecutable(pythonLocation, isWindows)
%PYTHONEXECUTABLE The Python program inside the folder actions/setup-python made.
%
%   EXE = PYTHONEXECUTABLE(PYTHONLOCATION) returns the path, as a char
%   vector, of the Python program in the folder PYTHONLOCATION (the
%   environment variable pythonLocation): python3 in its bin folder on
%   Linux, python.exe directly in the folder on Windows.
%
%   EXE = PYTHONEXECUTABLE(PYTHONLOCATION, ISWINDOWS) selects the form
%   explicitly (true for the Windows form); the default is ispc().

arguments
    pythonLocation (1,1) string
    isWindows (1,1) logical = ispc()
end

if isWindows
    exe = fullfile(char(pythonLocation), 'python.exe');
else
    exe = fullfile(char(pythonLocation), 'bin', 'python3');
end

end
