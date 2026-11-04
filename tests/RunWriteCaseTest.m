classdef RunWriteCaseTest < matlab.unittest.TestCase
    %RUNWRITECASETEST Unit tests for runWriteCase, the call a write case makes.
    %
    % The cases run for real against the OpenSTREAM checkout in
    % upstream/openstream. Every expected text is the text of a direct call of
    % the class writer (Inputs.Geometry.writeInputFile and its siblings) or of
    % the file functions of MATLAB, made in the test into a file of its own,
    % so a runner that writes with another mode, another order or another
    % class fails. Entries are decoded with jsondecode from JSON text, as the
    % exporter decodes them.
    %
    % The result of a case is the text of the file after all its calls, a
    % char row; for an entry in which some value of some call is an empty text
    % it is struct(char, string): the text of the file written with the value
    % as the empty char the converter gives, and the text of another file
    % written with the same value converted by string.

    properties
        folder
    end

    methods (TestClassSetup)

        function addPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            here = fileparts(mfilename('fullpath'));
            root = fullfile(here, '..');
            testCase.applyFixture(PathFixture(fullfile(root, 'matlab')));
            % The folder of the tests, for the package TestData.
            testCase.applyFixture(PathFixture(here));
            upstream = fullfile(root, 'upstream', 'openstream');
            testCase.assertTrue(isfolder(fullfile(upstream, '+Inputs')), ...
                'upstream/openstream is not checked out');
            testCase.applyFixture(PathFixture(upstream));
        end

    end

    methods (TestMethodSetup)

        function makeFolder(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture);
            testCase.folder = fixture.Folder;
        end

    end

    methods (Static)

        function e = entry(className, calls)
            % A write entry of class CLASSNAME; CALLS is the JSON text of
            % the list of calls.
            e = jsondecode(['{"name":"w","kind":"write","class":"' className ...
                '","calls":' calls '}']);
        end

        function text = geometryCall(mode, key, value)
            % The JSON text of a Geometry call writing KEY with the JSON
            % text VALUE; MODE is the mode, or '' for a call without one.
            if isempty(mode)
                modeText = '';
            else
                modeText = ['"mode":"' mode '",'];
            end
            text = ['{"id":"G",' modeText '"values":[["' key '",' value ']]}'];
        end

        function text = readText(file)
            text = fileread(file);
        end

    end

    methods

        function file = newFile(testCase, name)
            % The path of a file NAME of this test, not yet made.
            file = fullfile(testCase.folder, name);
            testCase.assertFalse(isfile(file));
        end

        function text = directGeometry(testCase, pairs)
            % The text of a new file after direct calls of the class writer,
            % one per row of PAIRS ({key, value; ...}), all with the id G.
            file = testCase.newFile('direct.inp');
            for k = 1:size(pairs, 1)
                Inputs.Geometry.writeInputFile(file, 'G', pairs{k, 1}, pairs{k, 2});
            end
            text = fileread(file);
            delete(file);
        end

    end

    methods (Test)

        function testCallsWithoutModeWriteLikeTheClassWriter(testCase)
            % No mode: the class writer is used, so the text is that of
            % direct calls of it (mode a+, appending), for each class. For
            % BoundaryConditions the class writer picks w+ at time 0 and a+
            % later, so two calls give two blocks in the file.
            two = RunWriteCaseTest.entry('Geometry', ['[' ...
                RunWriteCaseTest.geometryCall('', 'LENGTH', '{"double":["5.5"]}') ',' ...
                RunWriteCaseTest.geometryCall('', 'AREA', '{"double":["2"]}') ']']);
            direct = testCase.directGeometry({'LENGTH', 5.5; 'AREA', 2});
            testCase.verifyEqual(runWriteCase(two), direct);
            % The second call is in the text (a runner that wrote only the
            % last call, or only the first, would differ).
            testCase.verifySubstring(direct, 'LENGTH');
            testCase.verifySubstring(direct, 'AREA');

            file = testCase.newFile('direct_model.inp');
            Inputs.Model.writeInputFile(file, 'M', 'NNODES', 100);
            model = RunWriteCaseTest.entry('Model', ['[{"id":"M","values":' ...
                '[["NNODES",{"double":["100"]}]]}]']);
            testCase.verifyEqual(runWriteCase(model), fileread(file));
            delete(file);

            file = testCase.newFile('direct_options.inp');
            Inputs.Options.writeInputFile(file, 'O', 'TSTEP', 0.5);
            options = RunWriteCaseTest.entry('Options', ['[{"id":"O","values":' ...
                '[["TSTEP",{"double":["0.5"]}]]}]']);
            testCase.verifyEqual(runWriteCase(options), fileread(file));
            delete(file);

            file = testCase.newFile('direct_bc.inp');
            Inputs.BoundaryConditions.writeInputFile(file, 0, 6e6, 1e6, 0.1, 'POWER', 100);
            Inputs.BoundaryConditions.writeInputFile(file, 1, 6e6, 1e6, 0.1, 'POWER', 200);
            bc = RunWriteCaseTest.entry('BoundaryConditions', ['[' ...
                RunWriteCaseTest.bcCall('', '0', '100') ',' ...
                RunWriteCaseTest.bcCall('', '1', '200') ']']);
            testCase.verifyEqual(runWriteCase(bc), fileread(file));
            delete(file);
        end

        function testUnknownClassIsRejected(testCase)
            e = RunWriteCaseTest.entry('Mod', ['[{"id":"M","values":' ...
                '[["NNODES",{"double":["100"]}]]}]']);
            testCase.verifyError(@() runWriteCase(e), 'References:InvalidInputFixture');
            e.class = 'Model';
            testCase.verifyClass(runWriteCase(e), 'char');
        end

        function testModeWOnAFreshFileWritesTheSameText(testCase)
            % On a file that does not exist, w, a and a+ all create it and
            % write the call: the text of one direct call. Each mode is its
            % own entry.
            direct = testCase.directGeometry({'LENGTH', 5.5});
            for mode = {'w', 'a', 'a+'}
                e = RunWriteCaseTest.entry('Geometry', ['[' RunWriteCaseTest.geometryCall( ...
                    mode{1}, 'LENGTH', '{"double":["5.5"]}') ']']);
                testCase.verifyEqual(runWriteCase(e), direct, mode{1});
            end
        end

        function testModeRPlusOnAMissingFileErrorsAndTheErrorIsNotCaught(testCase)
            % r+ opens an existing file only: fopen fails and the writer
            % errors 'An error occurred while creating <file>'. The error
            % reaches the caller (the exporter records it as the case's error).
            e = RunWriteCaseTest.entry('Geometry', ['[' RunWriteCaseTest.geometryCall( ...
                'r+', 'LENGTH', '{"double":["5.5"]}') ']']);
            try
                runWriteCase(e);
                testCase.verifyFail('r+ on a file that does not exist did not error');
            catch err
                testCase.verifySubstring(err.message, 'An error occurred while creating');
            end
        end

        function testModeOnAFileMadeBeforeFollowsFopen(testCase)
            % Two calls into one file: the first without a mode makes it
            % (LENGTH), the second has the mode. Expected by the file
            % functions of MATLAB:
            % - w truncates: only the text of the second call;
            % - a and a+ append: both calls (as two direct class-writer calls);
            % - r+ writes from the start of the file without truncating: the
            %   text of the second call over the beginning of the first.
            % The first value is a long text, so that the first text is
            % longer than the second and r+ differs from w.
            first = testCase.directGeometry({'LENGTH', 'a rather long text'});
            second = testCase.directGeometry({'AREA', 2});
            both = testCase.directGeometry({'LENGTH', 'a rather long text'; 'AREA', 2});
            testCase.assertGreaterThan(numel(first), numel(second));
            overwritten = [second first(numel(second)+1:end)];
            expected = struct('w', second, 'a', both, 'aplus', both, 'rplus', overwritten);
            testCase.assertNotEqual(expected.rplus, expected.w);
            testCase.assertNotEqual(expected.a, expected.w);
            modes = {'w', 'a', 'a+', 'r+'};
            names = {'w', 'a', 'aplus', 'rplus'};
            for k = 1:numel(modes)
                e = RunWriteCaseTest.entry('Geometry', ['[' ...
                    RunWriteCaseTest.geometryCall('', 'LENGTH', ...
                    '{"text":"a rather long text"}') ',' ...
                    RunWriteCaseTest.geometryCall(modes{k}, 'AREA', '{"double":["2"]}') ']']);
                testCase.verifyEqual(runWriteCase(e), expected.(names{k}), modes{k});
            end
        end

        function testModeOfBoundaryConditionsReplacesTheClassRule(testCase)
            % The class writer takes w+ at time 0 and a+ otherwise; with a
            % mode the mode is used instead: a second call at time 1 with
            % mode w truncates (a+ would append), and a first call at time 0
            % with mode a appends to nothing (same as w+ on a new file).
            file = testCase.newFile('direct_bc.inp');
            Inputs.BoundaryConditions.writeInputFile(file, 1, 6e6, 1e6, 0.1, 'POWER', 200);
            onlySecond = fileread(file);
            delete(file);
            e = RunWriteCaseTest.entry('BoundaryConditions', ['[' ...
                RunWriteCaseTest.bcCall('', '0', '100') ',' ...
                RunWriteCaseTest.bcCall('w', '1', '200') ']']);
            testCase.verifyEqual(runWriteCase(e), onlySecond);
            % Without the mode the same two calls append.
            e = RunWriteCaseTest.entry('BoundaryConditions', ['[' ...
                RunWriteCaseTest.bcCall('', '0', '100') ',' ...
                RunWriteCaseTest.bcCall('', '1', '200') ']']);
            testCase.verifyNotEqual(runWriteCase(e), onlySecond);
            % A first call at time 0 with mode a on a new file.
            file = testCase.newFile('direct_bc0.inp');
            Inputs.BoundaryConditions.writeInputFile(file, 0, 6e6, 1e6, 0.1, 'POWER', 100);
            first = fileread(file);
            delete(file);
            e = RunWriteCaseTest.entry('BoundaryConditions', ['[' ...
                RunWriteCaseTest.bcCall('a', '0', '100') ']']);
            testCase.verifyEqual(runWriteCase(e), first);
        end

        function testModeOfModelAndOptionsCalls(testCase)
            % The caller files of the other two id classes: mode w after a
            % first call leaves only the second call.
            file = testCase.newFile('m.inp');
            Inputs.Model.writeInputFile(file, 'M', 'NNODES', 7);
            onlySecond = fileread(file);
            delete(file);
            e = RunWriteCaseTest.entry('Model', ['[{"id":"M","values":' ...
                '[["NNODES",{"double":["100"]}]]},{"id":"M","mode":"w","values":' ...
                '[["NNODES",{"double":["7"]}]]}]']);
            testCase.verifyEqual(runWriteCase(e), onlySecond);
            file = testCase.newFile('o.inp');
            Inputs.Options.writeInputFile(file, 'O', 'TSTEP', 0.25);
            onlySecond = fileread(file);
            delete(file);
            e = RunWriteCaseTest.entry('Options', ['[{"id":"O","values":' ...
                '[["TSTEP",{"double":["0.5"]}]]},{"id":"O","mode":"w","values":' ...
                '[["TSTEP",{"double":["0.25"]}]]}]']);
            testCase.verifyEqual(runWriteCase(e), onlySecond);
        end

        function testMatrixAndArrayValuesAreWrittenColumnByColumn(testCase)
            % The two entries of the writer that carry a matrix and an
            % array: the text is that of the direct call with the same
            % MATLAB value.
            e = TestData.CaseEntries.entry('write', 'ext_write_01');
            direct = testCase.directGeometry({'PERIM', [1 2; 3 4]});
            testCase.verifyEqual(runWriteCase(e), direct);
            e = TestData.CaseEntries.entry('write', 'ext_write_06');
            direct = testCase.directGeometry({'PERIM', cat(3, [1 2], [3 4])});
            testCase.verifyEqual(runWriteCase(e), direct);
        end

        function testNonEmptyTextKeepsThePlainResult(testCase)
            % A text value that is not empty: the result is the text itself
            % (a char row), the same as the direct call; no pair.
            e = RunWriteCaseTest.entry('Geometry', ['[' RunWriteCaseTest.geometryCall( ...
                '', 'PERIM', '{"text":"ab"}') ']']);
            result = runWriteCase(e);
            testCase.verifyClass(result, 'char');
            testCase.verifyEqual(result, testCase.directGeometry({'PERIM', 'ab'}));
        end

        function testEmptyTextIsWrittenOnceAsCharAndOnceAsString(testCase)
            % The entry with an empty text value: the result is a struct
            % with the fields char and string, each the text of a new file;
            % the char text is that of a direct call with '' and the string
            % text that of a direct call with string(''). (The two writers
            % treat an empty char argument and an empty string differently
            % in fprintf; the expected texts come from the direct calls.)
            e = TestData.CaseEntries.entry('write', 'ext_write_05');
            result = runWriteCase(e);
            testCase.verifyEqual(sort(fieldnames(result)), {'char'; 'string'});
            testCase.verifyEqual(result.char, testCase.directGeometry({'PERIM', ''}));
            testCase.verifyEqual(result.string, ...
                testCase.directGeometry({'PERIM', string('')}));
        end

        function testEmptyTextInALaterCallOrBoundaryConditions(testCase)
            % The rule is "any value of any call": an empty text in the
            % second call, and in a BoundaryConditions call, gives the pair
            % too; the other call is written the same way in both files.
            e = RunWriteCaseTest.entry('Geometry', ['[' ...
                RunWriteCaseTest.geometryCall('', 'LENGTH', '{"double":["5.5"]}') ',' ...
                RunWriteCaseTest.geometryCall('', 'PERIM', '{"text":""}') ']']);
            result = runWriteCase(e);
            testCase.verifyEqual(result.char, ...
                testCase.directGeometry({'LENGTH', 5.5; 'PERIM', ''}));
            testCase.verifyEqual(result.string, ...
                testCase.directGeometry({'LENGTH', 5.5; 'PERIM', string('')}));

            e = RunWriteCaseTest.entry('BoundaryConditions', ['[' ...
                RunWriteCaseTest.bcCall('', '0', '{"text":""}') ']']);
            result = runWriteCase(e);
            testCase.verifyEqual(sort(fieldnames(result)), {'char'; 'string'});
            file = testCase.newFile('bc_char.inp');
            Inputs.BoundaryConditions.writeInputFile(file, 0, 6e6, 1e6, 0.1, 'POWER', '');
            testCase.verifyEqual(result.char, fileread(file));
            delete(file);
            Inputs.BoundaryConditions.writeInputFile(file, 0, 6e6, 1e6, 0.1, 'POWER', string(''));
            testCase.verifyEqual(result.string, fileread(file));
        end

        function testEmptyTextWithAModeUsesTheModeInBothWrites(testCase)
            % Both files are written with the mode of the call: with r+ on a
            % file that does not exist the first write errors and the error
            % reaches the caller; with w both texts are those of a direct
            % call.
            e = RunWriteCaseTest.entry('Geometry', ['[' RunWriteCaseTest.geometryCall( ...
                'r+', 'PERIM', '{"text":""}') ']']);
            try
                runWriteCase(e);
                testCase.verifyFail('r+ on a file that does not exist did not error');
            catch err
                testCase.verifySubstring(err.message, 'An error occurred while creating');
            end
            e = RunWriteCaseTest.entry('Geometry', ['[' RunWriteCaseTest.geometryCall( ...
                'w', 'PERIM', '{"text":""}') ']']);
            result = runWriteCase(e);
            testCase.verifyEqual(result.char, testCase.directGeometry({'PERIM', ''}));
            testCase.verifyEqual(result.string, ...
                testCase.directGeometry({'PERIM', string('')}));
        end

        function testTemporaryFilesAreRemoved(testCase)
            % tempname is shadowed by a stub that names files under a folder
            % of the test; after a plain case, a pair case and a case that
            % errors, nothing is left there.
            import matlab.unittest.fixtures.PathFixture
            % The folder of the test (made for every test) holds the base of
            % the temporary files and the stub, each in a subfolder.
            base = fullfile(testCase.folder, 'tmpfiles');
            mkdir(base);
            stubFolder = fullfile(testCase.folder, 'stub');
            mkdir(stubFolder);
            setappdata(0, 'RunWriteCaseTestBase', base);
            setappdata(0, 'RunWriteCaseTestCount', 0);
            testCase.addTeardown(@RunWriteCaseTest.clearState);
            lines = [ ...
                "function name = tempname(varargin)"
                "base = getappdata(0, 'RunWriteCaseTestBase');"
                "count = getappdata(0, 'RunWriteCaseTestCount') + 1;"
                "setappdata(0, 'RunWriteCaseTestCount', count);"
                "name = fullfile(base, sprintf('tmp%d', count));"
                "end"];
            fid = fopen(fullfile(stubFolder, 'tempname.m'), 'w');
            fprintf(fid, '%s\n', strjoin(reshape(lines, 1, []), newline));
            fclose(fid);
            testCase.applyFixture(PathFixture(stubFolder));
            testCase.assertTrue(startsWith(tempname, base));

            plain = TestData.CaseEntries.entry('write', 'ext_write_02');
            pair = TestData.CaseEntries.entry('write', 'ext_write_05');
            failing = RunWriteCaseTest.entry('Geometry', ['[' ...
                RunWriteCaseTest.geometryCall('r+', 'LENGTH', '{"double":["1"]}') ']']);
            for e = {plain, pair, failing}
                before = getappdata(0, 'RunWriteCaseTestCount');
                try
                    runWriteCase(e{1});
                catch
                end
                testCase.verifyGreaterThan(getappdata(0, 'RunWriteCaseTestCount'), before);
                listing = dir(base);
                testCase.verifyEmpty(setdiff({listing.name}, {'.', '..'}));
            end
        end

    end

    methods (Static)

        function clearState()
            for name = {'RunWriteCaseTestBase', 'RunWriteCaseTestCount'}
                if isappdata(0, name{1})
                    rmappdata(0, name{1});
                end
            end
        end

        function text = bcCall(mode, time, value)
            % The JSON text of a BoundaryConditions call at TIME (a JSON
            % number text as a decimal text, e.g. '0') writing POWER with
            % VALUE, a JSON text: a plain number text such as '100' is
            % turned into {"double":["100"]}, anything starting with { is
            % used as it is.
            if isempty(mode)
                modeText = '';
            else
                modeText = ['"mode":"' mode '",'];
            end
            if startsWith(value, '{')
                valueText = value;
            else
                valueText = ['{"double":["' value '"]}'];
            end
            d = @(x) ['{"double":["' x '"]}'];
            text = ['{"time":' d(time) ',"pressure":' d('6e6') ',"hin":' d('1e6') ...
                ',"mflow":' d('0.1') ',' modeText '"values":[["POWER",' valueText ']]}'];
        end

    end

end
