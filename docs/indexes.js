// sort indexes
db.replays.ensureIndex({
    'site.uploaded_at': -1
    }, { 
        name: 'wr.query.sort.uploaded_at',
    }
);
db.replays.ensureIndex({
    'site.likes': -1
    }, { 
        name: 'wr.query.sort.likes',
    }
);
db.replays.ensureIndex({
    'game.battle_level': -1
    }, { 
        name: 'wr.query.sort.battle_level',
    }
);
db.replays.ensureIndex({
    'site.downloads': -1
    }, { 
        name: 'wr.query.sort.downloads',
    }
);
db.replays.ensureIndex({
    'site.uploaded_at': -1
    }, { 
        name: 'wr.query.sort.uploaded_at',
    }
);
db.replays.ensureIndex({
    'game.started': -1
    }, { 
        name: 'wr.query.sort.started',
    }
);
db.replays.ensureIndex({
    'stats.originalXP': -1
    }, { 
        name: 'wr.query.sort.xp',
    }
);
db.replays.ensureIndex({
    'stats.damageDealt': -1
    }, { 
        name: 'wr.query.sort.damage',
    }
);
db.replays.ensureIndex({
    'stats.damageAssistedRadio': -1
    }, { 
        name: 'wr.query.sort.scouted',
    }
);


// privacy indexes
db.replays.ensureIndex({
    'site.visible': 1,
    'site.privacy': 1,
    'game.server': 1,
    'game.recorder.name': 1,
    'game.recorder.account_id': 1
    }, {
        name: 'privacy.player'
    }
);
db.replays.ensureIndex({
    'site.visible': 1,
    'site.privacy': 1,
    'game.server': 1,
    'game.recorder.name': 1,
    'game.recorder.account_id': 1,
    'game.recorder.clan': 1
    }, {
        name: 'privacy.any'
    }
);
db.replays.ensureIndex({
    'site.visible': 1,
    'site.privacy': 1,
    'game.server': 1,
    'game.recorder.clan': 1
    }, {
        name: 'privacy.clan'
    }
);

// filter indexes
db.replays.ensureIndex({
    'site.visible': 1,
    'site.privacy': 1,
    'game.server': 1,
    'game.map': 1,
    'game.type': 1,
    'game.bonus_type': 1,
    'game.recorder.vehicle.tier': 1,
    'game.recorder.vehicle.ident': 1,
    'game.recorder.name': 1,
    'game.recorder.account_id': 1,
    'involved.players': 1,
    'site.uploaded_at': -1,
    'site.likes': -1,
    'site.downloads': -1,
    'site.uploaded_at': -1,
    'game.started': -1,
    'stats.originalXP': -1,
    'stats.damageDealt': -1,
    'stats.damageAssistedRadio': -1,
    'game.battle_level': -1,
    }, {
        name: 'filter.all',
    }
);
