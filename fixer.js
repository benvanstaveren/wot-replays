db.replays.find().forEach(function(replay) {
    var server = replay.game.server.toLowerCase();
    
    var cid = {};
    cid.player = server + '-' + replay.game.recorder.name.toLowerCase();
    if(replay.game.recorder.clan != null) {
        cid.clan = server + '-' + replay.game.recorder.clan.toLowerCase();
    } else {
        cid.clan = null;
    }

    cid.involved = {
        player: [],
        clan: [],
        team: [],
    };

    cid.involved.players.forEach(function(player) {
        cid.involved.player.push(server + '-' + player.toLowerCase());
    });
    cid.involved.clans.forEach(function(clan) {
        cid.involved.clan.push(server + '-' + clan.toLowerCase());
    });
    cid.involved.team.forEach(function(player) {
        cid.involved.team.push(server + '-' + player.toLowerCase());
    });


    db.replays.update({ _id: replay._id }, {
        '$unset': {
            'game.recorder.cid': 1,
            'game.recorder.ccid': 1,
        },
        '$set': {
            'cid': cid
        }
    });
});
