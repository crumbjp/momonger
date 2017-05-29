#!/usr/bin/env bash
COFFEE=`dirname $0`/../node_modules/coffee-script/bin/coffee
$COFFEE --nodejs --max-old-space-size=8192 $*
