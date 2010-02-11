-module(rabbit_snmp_worker).
-behaviour(gen_server).

-export([start/0, start/2, stop/0, stop/1, start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).


-record(state, {update_interval}).

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
    application:start(snmp),
    UpdateInterval = case application:get_env(rabbit_snmp, update_interval) of
        undefined -> 10000;
        Value -> Value
    end,
    io:format("Started snmp state poller w/~pms interval~n", [UpdateInterval]),
    erlang:send_after(1, self(), update_stats),
    {ok, #state{update_interval = UpdateInterval}}.

create_exchange_row([]) ->
    ok;
create_exchange_row([Row|Rest]) ->
    {exchange, {resource, Vhost, exchange, ExchangeName}, ExchangeType, ExchangeDurability, ExchangeAutoDelete, _Args} = Row,
    ListVhost    = binary_to_list(Vhost),
    ListExchange = binary_to_list(ExchangeName),

    SnmpRow = {ListVhost, ListExchange,
        atom_to_list(ExchangeType),
        ExchangeDurability,
        ExchangeAutoDelete
    },
    snmpa_local_db:table_create_row(exchangeTable, ListVhost ++ ListExchange, SnmpRow),
    create_exchange_row(Rest).

create_vhost_row([]) ->
    ok;
create_vhost_row([Row|Rest]) ->
    {Vhost, QueueCount, ExchangeCount, MessageCount} = Row,
    ListVhost = binary_to_list(Vhost),
    SnmpRow = {ListVhost, QueueCount, ExchangeCount, MessageCount},
    snmpa_local_db:table_create_row(vhostTable, ListVhost, SnmpRow),
    create_vhost_row(Rest).

create_queue_row([]) ->
    ok;
create_queue_row([Row|Rest]) ->
    {resource, Vhost, queue, QueueName} = proplists:get_value(name, Row),
    ListVhost = binary_to_list(Vhost),
    ListQueue = binary_to_list(QueueName),
    QueuePid = proplists:get_value(pid, Row),
    MessagesSent = case gen_server:call(rabbit_snmp_tracer, {get_count, QueuePid}) of
        no_stats -> gen_server:call(rabbit_snmp_tracer, {start_trace, QueuePid}), 0;
        Count -> Count
    end,

    SnmpRow = {ListVhost, ListQueue,
        proplists:get_value(durable, Row),
        proplists:get_value(auto_delete, Row),
        proplists:get_value(messages, Row),
        proplists:get_value(messages_unacknowledged, Row),
        proplists:get_value(messages_uncommitted, Row),
        proplists:get_value(messages_ready, Row),
        proplists:get_value(acks_uncommitted, Row),
        proplists:get_value(consumers, Row),
        proplists:get_value(transactions, Row),
        proplists:get_value(memory, Row),
        MessagesSent
    },

    snmpa_local_db:table_create_row(queueTable, ListVhost ++ ListQueue, SnmpRow),
    create_queue_row(Rest).

sum_queue_info(InfoAll, Name) ->
    lists:foldl(fun(Props, Acc) -> Acc + proplists:get_value(Name, Props) end,
                0,
                InfoAll).

update_stats() ->
    Vhosts = rabbit_access_control:list_vhosts(),
    VhostsQueuesAndExchanges = [{X, rabbit_amqqueue:info_all(X), rabbit_exchange:list(X)} || X <- Vhosts],

    VhostRows = [{X, length(Q), length(E), sum_queue_info(Q, messages)} || {X,Q,E} <- VhostsQueuesAndExchanges],
    create_vhost_row(VhostRows),

    QueueRows = lists:append([Q || {_,Q,_} <- VhostsQueuesAndExchanges]),
    create_queue_row(QueueRows),

    ExchangeRows = lists:append([E || {_,_,E} <- VhostsQueuesAndExchanges]),
    create_exchange_row(ExchangeRows),
    ok.

handle_call(_Msg,_From,State) ->
    {reply, unknown_command, State}.

handle_cast(_,State) ->
    {noreply, State}.

handle_info(update_stats, State) ->
    update_stats(),
    erlang:send_after(State#state.update_interval, self(), update_stats),
    {noreply, State};

handle_info(Info, State) ->
    io:format("Info: ~p~nState: ~p~n", [Info, State]),
    {noreply, State}.

terminate(_,_State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

