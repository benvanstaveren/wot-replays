#!/bin/bash
mongo wot-replays js/start.js
script/import.pl ../../data/packets/5

mongo wot-replays js/maplist.js
mongo wot-replays js/gameplaylist.js
mongo wot-replays js/bonustypelist.js
mongo wot-replays js/mapreduce.js

mongo wot-replays js/end.js
