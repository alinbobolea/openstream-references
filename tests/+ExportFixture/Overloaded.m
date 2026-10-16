classdef Overloaded < handle
    %OVERLOADED Test fixture whose class overloads struct, as upstream's
    % Solvers.AbstractField does (it returns only TIME, ITR and the flow
    % properties). toPlain must still export every stored property.

    properties
        shown = 1
    end

    properties (Access = private)
        hidden = 2
    end

    methods

        function out = struct(obj)
            out = struct('shown', obj.shown);
        end

    end

end
