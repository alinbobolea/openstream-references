classdef FakeSolver < handle
    %FAKESOLVER A solver with two roots of stored states, like the mixture
    % solver's mixtureInit (several iteration states) and mixture (one state),
    % and properties that are not roots.

    properties
        mixtureInit
        mixture
        scalarNumber = 5
        emptyField = []
        textField = 'not an object'
    end

    methods

        function solver = FakeSolver(initialStates)
            % INITIALSTATES: the number of elements of mixtureInit.
            for k = 1:initialStates
                state = TestData.FakeMixture(10 * k);
                state.liquid = TestData.FakeLiquid(state);
                state.vapor = TestData.FakeLiquid(state);
                states(k) = state; %#ok<AGROW>
            end
            solver.mixtureInit = states;
            one = TestData.FakeMixture(0);
            one.liquid = TestData.FakeLiquid(one);
            one.vapor = TestData.FakeLiquid(one);
            solver.mixture = one;
        end

    end

end
