function root = setupOpenstream(openstreamRoot)
%SETUPOPENSTREAM Select the Python environment and put OpenSTREAM on the path.
%
%   ROOT = SETUPOPENSTREAM(OPENSTREAMROOT) points MATLAB at the Python
%   installed by actions/setup-python (environment variable pythonLocation)
%   when one is set and Python is not loaded yet, then adds the OpenSTREAM
%   checkout to the path. ROOT is the checkout's absolute path.

arguments
    openstreamRoot (1,1) string
end

pythonLocation = getenv('pythonLocation');
if ~isempty(pythonLocation)
    pe = pyenv;
    if pe.Status == "NotLoaded"
        pyenv(Version = fullfile(pythonLocation, 'bin', 'python3'));
    end
end

root = char(openstreamRoot);
if ~startsWith(root, filesep)
    root = fullfile(pwd, root);
end
addpath(root);

end
