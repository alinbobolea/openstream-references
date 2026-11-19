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
            for list = {testCase.mixture, testCase.bennett, testCase.groeneveld}
                testCase.verifyEmpty(RealCaseListsTest.nameProblems(list{1}));
            end
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
            for k = 1:numel(testCase.mixture)
                c = testCase.mixture{k};
                testCase.verifyTrue(all(isfield(c, required)), c.name);
                if isfield(c, 'boundaryConditions')
                    boundaryConditionLines(c.boundaryConditions);
                end
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
