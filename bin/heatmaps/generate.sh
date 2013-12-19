#!/bin/bash
mongo wtr-heatmaps js/start.js
for a in `find ../../data/packets/ -name "*.json"`; do
    script/import.pl $a >> ../../data/packets/import.json;
done
mongoimport -d wtr-heatmaps -c raw_location < ../../data/packets/import.json

mongo wtr-heatmaps js/maplist.js
mongo wtr-heatmaps js/gameplaylist.js
mongo wtr-heatmaps js/bonustypelist.js
mongo wtr-heatmaps js/loc-global.js

script/export.pl > export.sh
rm -rf ../../data/packets/heatmaps/*.json
. ./export.sh

rm ../../data/packets/import.json
rm export.sh
