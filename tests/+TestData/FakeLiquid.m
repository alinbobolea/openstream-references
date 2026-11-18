classdef FakeLiquid < TestData.FakeBase
    %FAKELIQUID A phase of FakeMixture: it reads the number of nodes from its
    % mixture, which it keeps in a private property, like the upstream phases.

    properties (GetAccess = private, SetAccess = private)
        mix
        NZ
    end

    methods

        function liquid = FakeLiquid(mix)
            liquid.mix = mix;
            liquid.NZ = mix.NZ;
        end

        function v = TEMPERATURE(liquid, zIdx)
            if nargin < 2, zIdx = (1:liquid.NZ).'; end
            v = liquid.mix.OFFSET + 1000 + zIdx;
        end

        function v = NU(liquid, twall, zIdx)
            % Errors for more than one node: the node-by-node call must give
            % the row of twall of that node, as upstream's NU needs.
            if nargin < 3, zIdx = (1:liquid.NZ).'; end
            if numel(zIdx) > 1
                error('Fake:vector', 'one node at a time');
            end
            v = twall(:, 1) + 0.5 * zIdx;
        end

        function v = SEESPARENT(liquid)
            v = liquid.mix.OFFSET;
        end

    end

end
