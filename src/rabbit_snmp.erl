-module(rabbit_snmp).

-export([start/0, stop/0, start/2, stop/1]).

-include("RABBITMQ-MIB.hrl").

load_snmp_environment() ->
    Path = code:lib_dir(rabbitmq,snmp),

    ok = application:load(snmp),
    {ok, Agent} = application:get_env(snmp, agent),
    Config = proplists:get_value(config, Agent),
    NewConfig = lists:keystore(dir, 1, Config, {dir, Path ++ "/agent/conf"}),
    NewAgent = lists:keystore(db_dir, 1, (lists:keystore(config, 1, Agent, {config, NewConfig})), {db_dir, Path ++ "/agent/db"}),
    application:set_env(snmp, agent, NewAgent),

    ok = application:start(snmp),
    ok = snmpa:load_mibs(snmp_master_agent, [Path ++ "/RABBITMQ-MIB"]),
    ok.

start() ->
    load_snmp_environment(),
    rabbit_snmp_sup:start_link(),
    ok.

stop() ->
    ok.

start(normal, []) ->
    load_snmp_environment(),
    rabbit_snmp_sup:start_link().

stop(_State) ->
    ok.
