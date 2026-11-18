function text = formatInputValue(value)
%FORMATINPUTVALUE The text of a value in an input file entry.
%
%   TEXT = FORMATINPUTVALUE(VALUE) returns a string that stands after the ">"
%   of an entry line of an upstream .inp input file:
%
%   - a numeric array of finite real numbers: the elements in column order,
%     separated by one space, each with 17 significant digits so that it reads
%     back as the same double;
%   - a logical array: TRUE or FALSE for each element;
%   - a char row or string scalar: the text itself, which may hold only the
%     characters the upstream reader keeps (letters, digits, underscore,
%     white space and @ > < = & | ( ) / * [ ] , + - .).
%
%   Anything else errors with References:InvalidOverride. An empty value
%   errors as well, because the reader would save it as empty text.

if isnumeric(value)
    if isempty(value) || ~isreal(value) || ~all(isfinite(value(:)))
        error('References:InvalidOverride', ...
            'A numeric value must be non-empty, real and finite');
    end
    text = strjoin(compose('%.17g', reshape(double(value), 1, [])), ' ');
elseif islogical(value)
    if isempty(value)
        error('References:InvalidOverride', 'A logical value must not be empty');
    end
    names = ["FALSE" "TRUE"];
    text = strjoin(names(reshape(value, 1, []) + 1), ' ');
elseif ischar(value) || (isstring(value) && isscalar(value))
    text = strtrim(string(value));
    if size(value, 1) > 1 || strlength(text) == 0
        error('References:InvalidOverride', ...
            'A text value must be one non-empty row');
    end
    if ~isempty(regexp(char(text), '[^@><=&|()/*\[\],\w\s\+\-\.]', 'once'))
        error('References:InvalidOverride', ...
            'The text "%s" has a character that the input reader would drop', text);
    end
else
    error('References:InvalidOverride', ...
        'A value of class %s cannot be written to an input file', class(value));
end
text = string(text);

end
