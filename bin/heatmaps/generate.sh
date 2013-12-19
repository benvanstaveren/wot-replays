#!/bin/bash
mongo wtr-heatmaps js/start.js
for a in `find ../../data/packets/ -name "*.json"`; do
    mongoimport --jsonArray -d wtr-heatmaps -c packets $a
done
#mongo wtr-heatmaps js/maplist.js
#mongo wtr-heatmaps js/gameplaylist.js
#mongo wtr-heatmaps js/bonustypelist.js
#mongo wtr-heatmaps js/loc-global.js

#script/export.pl > export.sh
#rm -rf ../../data/packets/heatmaps/*.json
#. ./export.sh

#rm ../../data/packets/import.json
#rm export.sh
