#!/bin/bash
cd /home/wotreplay/wot-replays/data
rm -rf mongo
mkdir mongo
mongodump -d wot-replays -o /home/wotreplay/wot-replays/data/mongo
lftp -u $BACKUP_USER,$BACKUP_PASS -e "mirror -RP 4 /home/wotreplay/wot-replays/data/replays wot-replays/replays" ftp://dutchdk.dyndns.org
lftp -u $BACKUP_USER,$BACKUP_PASS -e "mirror -RP 4 /home/wotreplay/wot-replays/data/mongo wot-replays/mongo" ftp://dutchdk.dyndns.org
