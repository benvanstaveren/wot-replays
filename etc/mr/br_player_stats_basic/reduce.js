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
        hits:           0
    };

    v.forEach(function(val) {
        [ 'count', 'kills', 'damaged', 'spotted', 'damageDealt', 'damageAssisted', 'xp', 'credits', 'repair', 'health', 'survived', 'mileage', 'shots', 'pierced', 'hits' ].forEach(function(ikey) {
            res[ikey] += val[ikey];
        });
    });

    return res;
}
