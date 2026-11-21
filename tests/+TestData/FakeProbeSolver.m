classdef FakeProbeSolver < handle
    %FAKEPROBESOLVER A solved solver for the tests of exportProbes.
    %
    % mixtureInit holds three states (offsets 1, 2, 3) and mixture one (offset 9),
    % each a TestData.FakeProbeField; inputSet and fluid are text.

    properties
        mixture
        mixtureInit
        inputSet = 'the input set'
        fluid = 'the fluid'
    end

    methods

        function obj = FakeProbeSolver()
            obj.mixtureInit = [TestData.FakeProbeField('i', 'f', 1), ...
                TestData.FakeProbeField('i', 'f', 2), ...
                TestData.FakeProbeField('i', 'f', 3)];
            obj.mixture = TestData.FakeProbeField('i', 'f', 9);
        end

    end

end
