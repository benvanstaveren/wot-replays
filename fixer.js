var fixfunction = function(replay) {
    if(replay.game.server != null) {
        var server = replay.game.server.toLowerCase();
        var cid = { 
            player: null,
            clan: null,
            involved: {
                player: [],
                clan: [],
                team: [],
            }
        };

        if(replay.game.recorder.name != null) cid.player = server + '-' + replay.game.recorder.name.toLowerCase();
        if(replay.game.recorder.clan != null) cid.clan = server + '-' + replay.game.recorder.clan.toLowerCase();

        if(replay.involved != null) {
            if(replay.involved.players != null) 
                replay.involved.players.forEach(function(player) {
                    if(player != null) cid.involved.player.push(server + '-' + player.toLowerCase());
                });

            if(replay.involved.clans != null) 
                replay.involved.clans.forEach(function(clan) {
                    if(clan != null) cid.involved.clan.push(server + '-' + clan.toLowerCase());
                });

            if(replay.involved.team != null) 
                replay.involved.team.forEach(function(player) {
                    if(player != null) cid.involved.team.push(server + '-' + player.toLowerCase());
                });

            db.replays.update({ _id: replay._id }, {
                '$unset': {
                    'game.recorder.cid': 1,
                    'game.recorder.ccid': 1
                },
                '$set': {
                    'cid': cid
                }
            });
        }
    }
};

//db.replays.find().forEach(fixfunction);
