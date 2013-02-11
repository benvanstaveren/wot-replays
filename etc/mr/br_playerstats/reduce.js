function(k, v) {
    var res = {
        count:          0,
        kills:          0,
        damaged:        0,
        spotted:        0,
        damageDealt:    0,
        damageAssisted: 0,
        xp:             0,
        credits:        0,
        repair:         0,
        health:         0,
        survived:       0,
        mileage:        0,
        shots:          0,
        pierced:        0,
        hits:           0,
        vehicleType:    {},
        vehicleClass:   {},
        gameMap:        {},
        gameType:       {},
        bonusType:      {}
    };

    v.forEach(function(val) {
        [ 'count', 'kills', 'damaged', 'spotted', 'damageDealt', 'damageAssisted', 'xp', 'credits', 'repair', 'health', 'survived', 'mileage', 'shots', 'pierced', 'hits' ].forEach(function(ikey) {
            res[ikey] += val[ikey];
        });

        [ 'vehicleType', 'vehicleClass', 'gameMap', 'gameType', 'bonusType' ].forEach(function(ikey) {
            for(t in val[ikey]) {
                if(res[ikey][t]) {
                    res[ikey][t] += val[ikey][t];
                } else {
                    res[ikey][t] = 1;
                }
            }
        });
    });

    return res;
}
