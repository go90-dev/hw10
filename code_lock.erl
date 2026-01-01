-module(code_lock).
-behaviour(gen_statem).
-define(NAME, code_lock_3).

-export([start_link/2,stop/0]).
-export([button/1,set_lock_button/1,change_code/1]).
-export([init/1,callback_mode/0,terminate/3]).
-export([handle_event/4]).

start_link(Code, LockButton) ->
    gen_statem:start_link({local,?NAME}, ?MODULE, {Code,LockButton}, []).
stop() ->
    gen_statem:stop(?NAME).

button(Button) ->
    gen_statem:cast(?NAME, {button,Button}).
set_lock_button(LockButton) ->
    gen_statem:call(?NAME, {set_lock_button,LockButton}).
change_code(NewCode) ->
    gen_statem:call(?NAME, {change_code,NewCode}).

init({Code,LockButton}) ->
    process_flag(trap_exit, true),
    Data = #{code => Code, 
             length => length(Code), 
             buttons => [],
             failures => 0,
             lock_button => LockButton},
    {ok, {locked,LockButton}, Data}.

callback_mode() ->
    [handle_event_function,state_enter].

handle_event(enter, _OldState, {locked,_}, Data) ->
    do_lock(),
    {keep_state, Data#{buttons := []}};
handle_event(state_timeout, button, {locked,_}, Data) ->
    {keep_state, Data#{buttons := []}};

handle_event(cast, {button,Button}, {locked,LockButton},
  #{code := Code, length := Length, buttons := Buttons, failures := Failures} = Data) ->
    NewButtons = 
        if length(Buttons) < Length -> Buttons;
           true -> tl(Buttons)
        end ++ [Button],
    
    if NewButtons =:= Code -> 
            {next_state, {open,LockButton}, Data#{buttons := [], failures := 0}};
       length(NewButtons) =:= Length -> 
            NewFailures = Failures + 1,
            if NewFailures >= 3 -> 
                    {next_state, {suspended,LockButton}, Data#{buttons := [], failures := NewFailures}};
               true -> 
                    {keep_state, Data#{buttons := [], failures := NewFailures}, [{state_timeout,30000,button}]}
            end;
       true -> 
            {keep_state, Data#{buttons := NewButtons}, [{state_timeout,30000,button}]}
    end;

handle_event(enter, _OldState, {open,_}, _Data) ->
    do_unlock(),
    {keep_state_and_data, [{state_timeout,10000,lock}]};

handle_event(state_timeout, lock, {open,LockButton}, Data) ->
    {next_state, {locked,LockButton}, Data};

handle_event(cast, {button,LockButton}, {open,LockButton}, Data) ->
    {next_state, {locked,LockButton}, Data};

handle_event(cast, {button,_}, {open,_}, _Data) ->
    {keep_state_and_data,[postpone]};

handle_event({call,From}, {change_code,NewCode}, {open,_LockButton}, Data) ->
    {keep_state, Data#{code := NewCode, length := length(NewCode)}, [{reply,From,ok}]};

handle_event(enter, _OldState, {suspended,_}, _Data) ->
    {keep_state_and_data, {timeout, 10000, reset}};

handle_event(timeout, reset, {suspended,LockButton}, Data) ->
    {next_state, {locked,LockButton}, Data#{buttons := [], failures := 0}};

handle_event(cast, {button,_Button}, {suspended,_}, _Data) ->
    keep_state_and_data;

handle_event({call,From}, {change_code,_NewCode}, State, _Data) 
  when element(1, State) =/= open ->
    {keep_state_and_data, [{reply,From,{error, not_open}}]};

handle_event({call,From}, {set_lock_button,NewLockButton}, {StateName,_OldLockButton}, Data) ->
    {next_state, {StateName,NewLockButton}, Data#{lock_button := NewLockButton}, [{reply,From,ok}]}.

do_lock() -> ok.
do_unlock() -> ok.

terminate(_Reason, State, _Data) ->
    case State of
        {locked,_} -> ok;
        _ -> do_lock()
    end,
    ok.

