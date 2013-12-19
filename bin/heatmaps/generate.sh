#!/bin/bash
mongo wtr-heatmaps js/start.js
script/import.pl ../../data/packets/5

mongo wtr-heatmaps js/maplist.js
mongo wtr-heatmaps js/gameplaylist.js
mongo wtr-heatmaps js/bonustypelist.js
mongo wtr-heatmaps js/mapreduce.js

script/export.pl > export.sh
rm -rf ../../data/packets/heatmaps/*.json
. ./export.sh
rm export.sh
