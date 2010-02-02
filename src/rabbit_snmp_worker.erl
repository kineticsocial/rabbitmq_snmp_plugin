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
    gen_server:start_link({global, ?MODULE}, ?MODULE, [], []).

init([]) ->
    application:start(snmp),
    {ok, UpdateInterval} = application:get_env(rabbit_snmp, update_interval),
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
    SnmpRow = {binary_to_list(Row)},
    snmpa_local_db:table_create_row(vhostTable, binary_to_list(Row), SnmpRow),
    create_vhost_row(Rest).

create_queue_row([]) ->
    ok;
create_queue_row([Row|Rest]) ->
    {resource, Vhost, queue, QueueName} = proplists:get_value(name, Row),
    ListVhost = binary_to_list(Vhost),
    ListQueue = binary_to_list(QueueName),

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
        proplists:get_value(memory, Row)
    },

    snmpa_local_db:table_create_row(queueTable, ListVhost ++ ListQueue, SnmpRow),
    create_queue_row(Rest).


update_stats() ->
    Vhosts = rabbit_access_control:list_vhosts(),
    create_vhost_row(Vhosts),
    Queues = lists:append([rabbit_amqqueue:info_all(X) || X <- Vhosts]),
    create_queue_row(Queues),
    Exchanges = lists:append([rabbit_exchange:list(X) || X <- Vhosts]),
    create_exchange_row(Exchanges),
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

