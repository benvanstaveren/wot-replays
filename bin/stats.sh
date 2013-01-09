#!/bin/bash
cd /home/wotreplay/wot-replays/bin
./mr.pl ../etc/mr/stats_bybonustype stats.bybonustype
./mr.pl ../etc/mr/stats_byclass stats.byclass
./mr.pl ../etc/mr/stats_bycountry stats.bycountry
./mr.pl ../etc/mr/stats_bygametype stats.bygametype
./mr.pl ../etc/mr/stats_bytier stats.bytier
./mr.pl ../etc/mr/stats_byversion stats.byversion
./mr.pl ../etc/mr/stats_byserver stats.byserver
