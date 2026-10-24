function result = runFunctionCase(e)
%RUNFUNCTIONCASE The result of an upper, sprintf, num2str or strcat case.
%
%   RESULT = RUNFUNCTIONCASE(E) makes the call functionCall(E) describes
%   and stores its result: CALL.store(CALL.fn(CALL.args{:})). An error of
%   the call is not caught here; exportInputFixture records it as the
%   case's error.

call = functionCall(e);
result = call.store(call.fn(call.args{:}));

end
