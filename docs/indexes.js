// sort indexes
db.replays.ensureIndex({
    'game.started': -1 
    }, {
        name: 'sort.game.started',
    }
);
db.replays.ensureIndex({
    'site.uploaded_at': -1 
    }, {
        name: 'sort.site.uploaded_at',
    }
);
db.replays.ensureIndex({
    'site.likes': -1 
    }, {
        name: 'sort.site.likes',
    }
);
db.replays.ensureIndex({
    'site.downloads': -1 
    }, {
        name: 'sort.site.downloads',
    }
);
db.replays.ensureIndex({
    'stats.originalXP': -1 
    }, {
        name: 'sort.stats.originalXP',
    }
);
db.replays.ensureIndex({
    'stats.originalCredits': -1 
    }, {
        name: 'sort.stats.originalCredits',
    }
);
db.replays.ensureIndex({
    'stats.damageDealt': -1 
    }, {
        name: 'sort.stats.damageDealt',
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
    'involved.players': 1
    }, {
        name: 'filter.all',
    }
);
db.replays.ensureIndex({
    'game.server': 1,
    'game.recorder.name': 1,
    'game.recorder.account_id': 1,
    }, {
        name: 'filter.player.pp'
    }
);
db.replays.ensureIndex({
    'game.server': 1,
    'game.recorder.name': 1,
    'game.recorder.account_id': 1,
    'involved.players': 1
    }, {
        name: 'filter.player.pi'
    }
);
db.replays.ensureIndex({
    'game.recorder.vehicle.ident': 1,
    }, {
        name: 'filter.vehicle.type'
    }
);
db.replays.ensureIndex({
    'game.recorder.vehicle.tier': 1
    }, {
        name: 'filter.vehicle.tier'
    }
);
db.replays.ensureIndex({
    'game.server': 1,
    }, {
        name: 'filter.server',
    }
);
db.replays.ensureIndex({
    'game.map': 1,
    }, {
        name: 'filter.map',
    }
);
db.replays.ensureIndex({
    'game.type': 1,
    }, {
        name: 'filter.type',
    }
);
db.replays.ensureIndex({
    'game.bonus_type': 1,
    }, {
        name: 'filter.bonus_type',
    }
);
