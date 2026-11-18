classdef FakeBase < handle
    %FAKEBASE Stands for Solvers.AbstractField and Solvers.AbstractPhase in the
    % tests of exportDerived. BASEMETHOD is public and returns a value, like
    % the plotting and copying methods of the real base class; the tests give
    % this class as an excluded class, so exportDerived must not call it.

    methods

        function v = BASEMETHOD(obj) %#ok<MANU>
            v = -1;
        end

    end

end
