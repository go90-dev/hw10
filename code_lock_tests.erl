-module(code_lock_tests).
-include_lib("eunit/include/eunit.hrl").

-export([setup/0, cleanup/1]).

setup() ->
    {ok, Pid} = code_lock:start_link([1,2,3,4], 0),
    timer:sleep(50),
    Pid.

cleanup(_Pid) ->
    code_lock:stop(),
    timer:sleep(50).

correct_code_test() ->
    Pid = setup(),
    code_lock:button(1),
    code_lock:button(2),
    code_lock:button(3),
    code_lock:button(4),
    timer:sleep(100),
    code_lock:button(0),
    cleanup(Pid),
    ?assert(true).

suspension_test() ->
    Pid = setup(),
    lists:foreach(fun(_) ->
        code_lock:button(1),
        code_lock:button(2),
        code_lock:button(3),
        code_lock:button(9)
    end, lists:seq(1,3)),
    timer:sleep(100),
    cleanup(Pid),
    ?assert(true).

change_code_test() ->
    Pid = setup(),
    code_lock:button(1),
    code_lock:button(2),
    code_lock:button(3),
    code_lock:button(4),
    timer:sleep(100),
    Result = code_lock:change_code([5,6,7,8]),
    cleanup(Pid),
    ?assertEqual(ok, Result).

change_code_when_locked_test() ->
    Pid = setup(),
    Result = code_lock:change_code([9,9,9,9]),
    cleanup(Pid),
    ?assertEqual({error, not_open}, Result).
