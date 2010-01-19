{application, rabbit_snmp,
 [{description, "Embedded SNMP Agent"},
  {vsn, "0.0.1"},
  {modules, [
    rabbit_snmp,
    rabbit_snmp_sup,
    rabbit_snmp_worker
  ]},
  {registered, []},
  {mod, {rabbit_snmp, []}},
  {env, []},
  {applications, [kernel, stdlib, rabbit]}]}.
