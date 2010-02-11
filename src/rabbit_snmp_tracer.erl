-module(rabbit_snmp_tracer).
-behaviour(gen_server).

-export([start/0, start/2, stop/0, stop/1, start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-export([start_trace/1, stop_trace/1]).

-record(state, {table}).

start() ->
    start_link(),
    ok.

start(normal, []) ->
    start_link().

stop() ->
    ok.

stop(_State) ->
    stop().

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    Table = ets:new(queue_throughput_stats, []),
    {ok, #state{table = Table}}.

handle_call({start_trace, Pid}, _From, State) ->
    ets:insert(State#state.table, {Pid, 0}),
    erlang:trace(Pid, true, [{tracer, self()}, 'receive']),
    {reply, ok, State};

handle_call({stop_trace, Pid}, _From, State) ->
    ets:delete(State#state.table, Pid),
    erlang:trace(Pid, false, [{tracer, self()}, 'receive']),
    {reply, ok, State};

handle_call({get_count, Pid}, _From, State) ->
    Result = case ets:lookup(State#state.table, Pid) of
        [] -> no_stats;
        [{Pid, Count}] -> Count
    end,
    {reply, Result, State};

handle_call(_Msg,_From,State) ->
    %io:format("Call: ~p~nState: ~p~n", [Msg, State]),
    {reply, unknown_command, State}.

handle_cast(_Msg,State) ->
    %io:format("Cast: ~p~nState: ~p~n", [Msg, State]),
    {noreply, State}.

handle_info({trace, Pid, 'receive', {'$gen_cast', {deliver,_,_,_}}}, State) ->
    ets:update_counter(State#state.table, Pid, 1),
    {noreply, State};

handle_info(_Info, State) ->
    {noreply, State}.

start_trace(Pid) ->
    io:format("Starting Trace of: ~p~n", [Pid]),
    gen_server:call(?MODULE, {start_trace, Pid}).

stop_trace(Pid) ->
    io:format("Stopping Trace of: ~p~n", [Pid]),
    gen_server:call(?MODULE, {stop_trace, Pid}).

terminate(_,_State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

