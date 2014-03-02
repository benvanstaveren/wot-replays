#!/bin/bash
cat gendupes.js | mongo wot-replays
cat cleardupes.js | mongo wot-replays
