db.replays.find().forEach(function(replay) {
    replay.site.privacy = 0; // public
    if(!replay.site.visible) replay.site.privacy = 1; // unlisted

    var recorder = replay.roster[replay.game.recorder.index].player;
    if(recorder.clanAbbrev.length > 0) {
        replay.game.recorder.clan = recorder.clanAbbrev;
    } else {
        replay.game.recorder.clan = null;
    }

    db.replays.save(replay);
});
