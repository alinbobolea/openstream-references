classdef RealCaseListsTest < matlab.unittest.TestCase
    %REALCASELISTSTEST Checks of the case lists of the targets mixture-options,
    % bennett1967 and groeneveld2019 (cases/*.json): their structure, that every
    % dataset record is run with every model it is chosen for, and, where
    % upstream's code is on the path (the tests job checks it out), that the
    % option sweep names every member of every option kind.
    %
    % Each check is a function of a list, run on the real list and on the same
    % list with one fault, so that the check is seen to fail.

    properties
        mixture
        mixture2
        bennett
        groeneveld
    end

    methods (TestClassSetup)

        function addPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            here = fileparts(mfilename('fullpath'));
            testCase.applyFixture(PathFixture(fullfile(here, '..', 'matlab')));
        end

        function readLists(testCase)
            here = fileparts(mfilename('fullpath'));
            read = @(file) RealCaseListsTest.asCells(jsondecode( ...
                fileread(fullfile(here, '..', 'cases', file))));
            testCase.mixture = read('mixture-options.json');
            testCase.mixture2 = read('mixture-options-2.json');
            testCase.bennett = read('bennett1967.json');
            testCase.groeneveld = read('groeneveld2019.json');
        end

    end

    methods (Static)

        function cells = asCells(list)
            if iscell(list)
                cells = reshape(list, 1, []);
            else
                cells = num2cell(reshape(list, 1, []));
            end
        end

        function names = namesOf(list)
            names = strings(1, numel(list));
            for k = 1:numel(list)
                names(k) = string(list{k}.name);
            end
        end

        function problems = nameProblems(list)
            % What is wrong with the names of LIST (a string row, empty when
            % nothing): each is a lower-case word with digits and underscores,
            % and none repeats.
            names = RealCaseListsTest.namesOf(list);
            problems = strings(1, 0);
            if numel(unique(names)) < numel(names)
                problems(end+1) = "a name repeats";
            end
            bad = names(cellfun(@isempty, regexp(cellstr(names), '^[a-z][a-z0-9_]*$', 'once')));
            if ~isempty(bad)
                problems(end+1) = "names that are not lower-case words: " + strjoin(bad, ", ");
            end
        end

        function problems = recordProblems(list, field, expected)
            % What is wrong with the way LIST runs each record (a testID): the
            % value of model.FIELD must take every one of the strings EXPECTED
            % for each testID, once.
            problems = strings(1, 0);
            ids = cellfun(@(c) c.testID, list);
            for id = unique(ids)
                values = strings(1, 0);
                for k = find(ids == id)
                    values(end+1) = string(list{k}.model.(field)); %#ok<AGROW>
                end
                if ~isequal(sort(values), sort(string(expected)))
                    problems(end+1) = sprintf('testID %d runs %s, not %s', id, ...
                        strjoin(values, '/'), strjoin(string(expected), '/')); %#ok<AGROW>
                end
            end
        end

        function c = namedCase(list, name)
            names = RealCaseListsTest.namesOf(list);
            index = find(names == string(name));
            assert(isscalar(index), 'no case named %s', char(string(name)));
            c = list{index};
        end

        function values = valuesOfKind(list, kind)
            % The strings that LIST gives the key KIND, in the model or in the
            % options of any case.
            values = strings(1, 0);
            for k = 1:numel(list)
                for part = ["model" "options"]
                    if isfield(list{k}, part) && isfield(list{k}.(part), kind)
                        values(end+1) = string(list{k}.(part).(kind)); %#ok<AGROW>
                    end
                end
            end
            values = unique(values);
        end

    end

    methods (Test)

        function testNamesAreValidAndUnique(testCase)
            for list = {testCase.mixture, testCase.mixture2, testCase.bennett, ...
                    testCase.groeneveld}
                testCase.verifyEmpty(RealCaseListsTest.nameProblems(list{1}));
            end
        end

        function testNoNameIsInTwoOfTheMixtureLists(testCase)
            % The cases of both lists are frozen under their names: one name,
            % one case.
            both = [RealCaseListsTest.namesOf(testCase.mixture), ...
                RealCaseListsTest.namesOf(testCase.mixture2)];
            testCase.verifyEqual(numel(unique(both)), numel(both));
        end

        function testNameCheckSeesARepeatedAndABadName(testCase)
            list = testCase.mixture;
            repeated = [list, list(1)];
            testCase.verifyNotEmpty(RealCaseListsTest.nameProblems(repeated));
            bad = list;
            bad{1}.name = 'Bad-Name';
            testCase.verifyNotEmpty(RealCaseListsTest.nameProblems(bad));
        end

        function testDatasetListsPassTheDatasetValidator(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            root = testCase.applyFixture(TemporaryFolderFixture).Folder;
            mkdir(fullfile(root, '+Bennett1967'));
            mkdir(fullfile(root, '+Groeneveld2019'));
            validateDatasetCaseList(testCase.bennett, root);
            validateDatasetCaseList(testCase.groeneveld, root);
        end

        function testInputFileListPassesTheOverrideRules(testCase)
            % The structure of every case, without upstream's files: the
            % required fields and the override rules of validateCaseList are
            % applied by the runner; here the overrides are written out.
            required = {'name', 'solver', 'modelFile', 'modelID', 'optionsFile', ...
                'optionsID', 'geometryFile', 'geometryID', 'bcFile'};
            for list = {testCase.mixture, testCase.mixture2}
                for k = 1:numel(list{1})
                    c = list{1}{k};
                    testCase.verifyTrue(all(isfield(c, required)), c.name);
                    if isfield(c, 'boundaryConditions')
                        boundaryConditionLines(c.boundaryConditions);
                    end
                end
            end
        end

        function testTheSecondTargetHasTheTwentySixAgreedCases(testCase)
            names = RealCaseListsTest.namesOf(testCase.mixture2);
            expected = ["round2_tpfm_epri_3mpa" "round2_tpfm_epri_2mpa" ...
                "round2_sahazuber_20kw" "round2_sahazuber_40kw" ...
                "round2_sahazuber_60kw" "round2_two_walls_vapor" ...
                "round2_two_walls_dougall" "round2_two_walls_bishop" ...
                "round2_two_walls_moeck" "round2_two_walls_delorme" ...
                "round2_two_walls_condieiv" ...
                "round2_thermalnoneq_epri_2kw" "round2_thermalnoneq_epri_4kw" ...
                "round2_two_walls_biasi_vapor" "round2_two_walls_biasi_dougall" ...
                "round2_two_walls_biasi_bishop" "round2_two_walls_biasi_moeck" ...
                "round2_two_walls_biasi_delorme" "round2_two_walls_biasi_condieiv" ...
                "round3_euler_relax_0p25" "round3_euler_relax_0p2" ...
                "round3_fourier_coefficients" "round3_void_quality_exponent" ...
                "round3_fourierx_table" "round3_nearwallh_film_low_flux" ...
                "round3_romie_dry_outlet"];
            testCase.verifyEqual(sort(names), sort(expected));
        end

        function testTheEulerCasesRelaxTheVaporMoreThanTheDefault(testCase)
            % The Euler integration does not converge with the default vapor
            % relaxation of 0.7 (the first Euler case stopped not converged);
            % these two converge.
            for relax = [0.25 0.2]
                name = "round3_euler_relax_" + strrep(num2str(relax), '.', 'p');
                c = RealCaseListsTest.namedCase(testCase.mixture2, name);
                testCase.verifyEqual(string(c.options.MRMTIMEINT), "EULER", char(name));
                testCase.verifyEqual(c.options.RELAXWV, relax, char(name));
                testCase.verifyEqual(c.options.RELAXHV, relax, char(name));
            end
        end

        function testTheFourierCasesUseCoefficientsThatTheDefaultsHide(testCase)
            c = RealCaseListsTest.namedCase(testCase.mixture2, ...
                "round3_fourier_coefficients");
            testCase.verifyEqual(string(c.model.THERMALRELAX), "FOURIER");
            condCoef = c.model.RELAXCONDFOCOEF;
            evapCoef = c.model.RELAXEVAPFOCOEF;
            testCase.verifyNotEqual(condCoef(3), condCoef(4), 'the exponents differ');
            testCase.verifyNotEqual(evapCoef(3), evapCoef(4), 'the exponents differ');
            testCase.verifyGreaterThan(condCoef(3), 0);
            testCase.verifyLessThan(evapCoef(5), 0.00881463768115942, ...
                'the reference diameter is below the hydraulic diameter');
            v = RealCaseListsTest.namedCase(testCase.mixture2, ...
                "round3_void_quality_exponent");
            testCase.verifyEqual(string(v.model.THERMALRELAX), "VOID");
            testCase.verifyEqual(v.model.RELAXCONDCOEF(4), 0.5);
            testCase.verifyEqual(v.model.RELAXEVAPCOEF(4), 0.5);
            x = RealCaseListsTest.namedCase(testCase.mixture2, ...
                "round3_fourierx_table");
            testCase.verifyEqual(string(x.model.THERMALRELAX), "FOURIERX");
            testCase.verifyGreaterThan(numel(unique(x.model.RELAXCONDFO)), 1);
            testCase.verifyGreaterThan(numel(unique(x.model.RELAXEVAPFO)), 1);
        end

        function testTheLowFluxAndTheDryOutletCasesReachTheirBounds(testCase)
            % The film enthalpy ratio is 1 up to a mass flux of 900 kg/m2/s; the flow
            % area of the tutorial channel is about 6.1e-5 m2, so 0.045 kg/s is
            % about 740.
            c = RealCaseListsTest.namedCase(testCase.mixture2, ...
                "round3_nearwallh_film_low_flux");
            testCase.verifyEqual(string(c.model.NEARWALLH), "FILM");
            testCase.verifyEqual(c.boundaryConditions(1).MFLOW, 0.045);
            d = RealCaseListsTest.namedCase(testCase.mixture2, ...
                "round3_romie_dry_outlet");
            testCase.verifyEqual(string(d.model.TPKM), "ROMIE");
            testCase.verifyEqual(string(d.model.VOID), "HOMOGENEOUS");
            testCase.verifyEqual(string(d.model.THERMALNONEQ), "EQUILIBRIUM");
            testCase.verifyEqual(d.boundaryConditions(1).POWER, 400000);
        end

        function testTheEpriVaporQualityCasesKeepTheOutletSubcooled(testCase)
            % The EPRI vapor quality (THERMALNONEQ = EPRI) has a branch for a
            % channel in which no node passes the bubble-departure quality; it
            % needs a power below about 5 kW at this flow and inlet enthalpy.
            for kilowatts = [2 4]
                name = sprintf('round2_thermalnoneq_epri_%dkw', kilowatts);
                c = RealCaseListsTest.namedCase(testCase.mixture2, name);
                testCase.verifyEqual(string(c.model.THERMALNONEQ), "EPRI", name);
                testCase.verifyEqual(c.boundaryConditions(1).POWER, kilowatts * 1000, name);
            end
        end

        function testTheTwoWallBiasiCasesFlagTheTransitionFromTheHeatFlux(testCase)
            % CBT = ELEVATION fails with two walls in upstream (CBT_CALC builds
            % one column), so these cases use the heat-flux flag.
            members = ["VAPOR" "DOUGALL" "BISHOP" "MOECK" "DELORME" "CONDIEIV"];
            for member = members
                c = RealCaseListsTest.namedCase(testCase.mixture2, ...
                    "round2_two_walls_biasi_" + lower(member));
                testCase.verifyEqual(string(c.model.BTHTM), member);
                testCase.verifyEqual(string(c.model.CBT), "BIASI", char(member));
                testCase.verifyNumElements(c.geometry.PERIM, 2, char(member));
                testCase.verifyEqual(c.boundaryConditions(1).WPOWER(:).', ...
                    [0.6 0.1 0.2 0.1], 'AbsTol', 1e-15);
            end
        end

        function testTheEpriCasesAreBelowTheLowPressureLimitOfTheCorrelation(testCase)
            % Upstream's EPRI multiplier changes below 4.137 MPa.
            for name = ["round2_tpfm_epri_3mpa" "round2_tpfm_epri_2mpa"]
                c = RealCaseListsTest.namedCase(testCase.mixture2, name);
                testCase.verifyEqual(string(c.model.TPFM), "EPRI", char(name));
                testCase.verifyLessThan(c.boundaryConditions(1).PRESSURE, 4.137e6, ...
                    char(name));
            end
        end

        function testTheSahaZuberCasesHaveLowPowers(testCase)
            powers = [20 40 60] * 1000;
            for k = 1:3
                name = sprintf('round2_sahazuber_%dkw', powers(k) / 1000);
                c = RealCaseListsTest.namedCase(testCase.mixture2, name);
                testCase.verifyEqual(string(c.model.THERMALNONEQ), "SAHAZUBER", name);
                testCase.verifyEqual(c.boundaryConditions(1).POWER, powers(k), name);
            end
        end

        function testTheTwoWallCasesRunEveryPostTransitionModelOnTwoWalls(testCase)
            members = ["VAPOR" "DOUGALL" "BISHOP" "MOECK" "DELORME" "CONDIEIV"];
            for member = members
                c = RealCaseListsTest.namedCase(testCase.mixture2, ...
                    "round2_two_walls_" + lower(member));
                testCase.verifyEqual(string(c.model.BTHTM), member);
                testCase.verifyEqual(string(c.model.CBT), "ELEVATION", char(member));
                testCase.verifyNumElements(c.geometry.PERIM, 2, char(member));
                testCase.verifyEqual(c.boundaryConditions(1).WPOWER(:).', ...
                    [0.6 0.1 0.2 0.1], 'AbsTol', 1e-15);
            end
        end

        function testEveryBennettRecordRunsWithEveryPostTransitionModel(testCase)
            expected = ["VAPOR" "DOUGALL" "BISHOP" "MOECK" "DELORME" "CONDIEIV"];
            testCase.verifyEmpty(RealCaseListsTest.recordProblems( ...
                testCase.bennett, 'BTHTM', expected));
            for k = 1:numel(testCase.bennett)
                c = testCase.bennett{k};
                testCase.verifyTrue(c.cbtElevationFromRecord, c.name);
                testCase.verifyEqual(string(c.model.CBT), "ELEVATION", c.name);
                testCase.verifyFalse(isfield(c.model, 'CBTELEVATION'), c.name);
            end
        end

        function testEveryGroeneveldRecordRunsWithBothCorrelations(testCase)
            testCase.verifyEmpty(RealCaseListsTest.recordProblems( ...
                testCase.groeneveld, 'CBT', ["BIASI" "BEZRUKOV"]));
        end

        function testRecordCheckSeesAModelThatIsLeftOut(testCase)
            % The control of the two tests above.
            shortened = testCase.bennett(2:end);
            testCase.verifyNotEmpty(RealCaseListsTest.recordProblems( ...
                shortened, 'BTHTM', ...
                ["VAPOR" "DOUGALL" "BISHOP" "MOECK" "DELORME" "CONDIEIV"]));
        end

        function testTheInterpolationCasesUseEachOfTheNineMethods(testCase)
            methods = ["linear" "nearest" "next" "previous" "pchip" "cubic" ...
                "v5cubic" "makima" "spline"];
            for shape = ["power_step" "flow_ramp"]
                names = "transient_" + shape + "_" + methods;
                for k = 1:numel(names)
                    index = find(RealCaseListsTest.namesOf(testCase.mixture) == names(k));
                    testCase.assertNumElements(index, 1, char(names(k)));
                    c = testCase.mixture{index};
                    testCase.verifyEqual(string(c.options.TIMEINTERP), methods(k));
                    times = [c.boundaryConditions.TIME];
                    testCase.verifyEqual(diff(times), repmat(diff(times(1:2)), 1, 3), ...
                        'the times are equally spaced (v5cubic needs that)');
                end
            end
        end

        function testTheSweepNamesEveryMemberOfEveryOptionKind(testCase)
            upstream = fullfile(fileparts(mfilename('fullpath')), '..', ...
                'upstream', 'openstream');
            testCase.assumeTrue(isfolder(fullfile(upstream, '+InputEnums')), ...
                'upstream OpenSTREAM is not checked out');
            import matlab.unittest.fixtures.PathFixture
            testCase.applyFixture(PathFixture(upstream));
            kinds = ["VOID" "THERMALNONEQ" "THERMALRELAX" "NEARWALLRELAX" ...
                "NEARWALLH" "OAF" "SPMTM" "TPFM" "TPKM" "BTMTM" "CBT" "MFBT" ...
                "SPHTM" "TPHTM" "BTHTM" "INTTRANSH" "MRMTIMEINT"];
            model = Inputs.Model();
            options = Inputs.Options();
            for kind = kinds
                members = string(enumeration("InputEnums." + kind));
                if kind == "MRMTIMEINT"
                    default = string(options.(kind));
                else
                    default = string(model.(kind));
                end
                named = RealCaseListsTest.valuesOfKind(testCase.mixture, kind);
                % A member is run when a case names it or when it is the default
                % that the cases that do not name the kind have.
                testCase.verifyEmpty(setdiff(setdiff(members, named), default), ...
                    sprintf('members of %s that no case runs', kind));
            end
        end

    end

end
