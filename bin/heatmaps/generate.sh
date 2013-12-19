#!/bin/bash
mongo wtr-heatmaps js/start.js
for a in `find ../../data/packets/ -name "*.json"`; do
    script/import.pl $a;
done

mongo wtr-heatmaps js/maplist.js
mongo wtr-heatmaps js/gameplaylist.js
mongo wtr-heatmaps js/bonustypelist.js
mongo wtr-heatmaps js/mapreduce.js

script/export.pl > export.sh
rm -rf ../../data/packets/heatmaps/*.json
. ./export.sh
rm export.sh
