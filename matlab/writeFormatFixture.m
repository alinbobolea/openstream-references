function writeFormatFixture(file)
%WRITEFORMATFIXTURE Save known values for checking MAT-file readers.
%
%   WRITEFORMATFIXTURE(FILE) saves a struct "fixture" (MAT-file version 7)
%   whose values exercise what a reader must get exactly right: special
%   double bit patterns (negative zero, a subnormal, the largest double,
%   eps, Inf, NaN), column-major order of a 3-D array, row and column
%   shapes, integer and logical types, text, an empty array and a nested
%   struct array.

arguments
    file (1,1) string
end

fixture = struct();
fixture.doubles = [pi, -0, realmin/2, realmax, eps, 1+eps, Inf, -Inf, NaN];
fixture.cube = reshape(1:24, 2, 3, 4);
fixture.col = (1:5)';
fixture.row = 1:5;
fixture.u8 = uint8(255);
fixture.i32 = int32(-7);
fixture.flags = [true false true];
fixture.text = 'MRM';
fixture.empty = [];
fixture.nested = struct('a', {1.5, [1 2]});

folder = fileparts(file);
if strlength(folder) > 0 && ~isfolder(folder)
    mkdir(folder);
end
save(file, "fixture", "-v7");

end
