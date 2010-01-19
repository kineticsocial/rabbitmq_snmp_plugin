PACKAGE=rabbitmq-snmp
DEPS=
EXTRA_PACKAGE_DIRS=snmp

include ../include.mk


ebin/rabbit_snmp.beam: include/RABBITMQ-MIB.hrl snmp/RABBITMQ-MIB.bin

snmp/RABBITMQ-MIB.bin: snmp/RABBITMQ-MIB.mib
	erlc -o snmp/ $<
include/RABBITMQ-MIB.hrl: snmp/RABBITMQ-MIB.bin
	erlc -o include/ $<
