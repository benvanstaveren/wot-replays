db.replays.find({ 'site.privacy': { '$not': { '$exists': 1 }}}).forEach(function(replay) {
    replay.site.privacy = 0; // public
    if(!replay.site.visible) replay.site.privacy = 1; // unlisted

    var entry = replay.roster[replay.game.recorder.index];
    if(entry) {
        var recorder = entry.player;
        if(recorder) {
            if(recorder.clanAbbrev && recorder.clanAbbrev.length > 0) {
                replay.game.recorder.clan = recorder.clanAbbrev;
            } else {
                replay.game.recorder.clan = null;
            }
        }
    }

    db.replays.save(replay);
});
