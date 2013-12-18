#!/bin/bash
mongo wtr-heatmaps js/start.js
rm import.json
for a in `find ../../data/packets/ -name "*.json"`; do
    script/import.pl $a >> import.json;
done
mongoimport -d wtr-heatmaps -c raw_location < import.json

mongo wtr-heatmaps js/maplist.js
mongo wtr-heatmaps js/gameplaylist.js
mongo wtr-heatmaps js/bonustypelist.js
mongo wtr-heatmaps js/loc-global.js

script/export.pl > export.sh
. ./export.sh

rm import.json
rm export.sh
