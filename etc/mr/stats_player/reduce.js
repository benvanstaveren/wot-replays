function(k, v) {
    var count    = 0;
    var result   = { vehicle: {}, map: {} };

    v.forEach(function(val) {
        result.kills += val.kills;
        result.destroyed += val.destroyed;
        result.spotted += val.spotted;
        result.damage_dealt += val.damage_dealt;

        if(val.vehicle instanceof String) {
            if(result.vehicle[val.vehicle]) {
                result.vehicle[val.vehicle] += 1;
            } else {
                result.vehicle[val.vehicle] = 1;
            }
        } else {
            for(vk in val.vehicle) {
                if(result.vehicle[vk]) {
                    result.vehicle[vk] += 1;
                } else {
                    result.vehicle[vk] = 1;
                }
            }
        }
        if(val.map instanceof String) {
            if(result.map[val.map]) {
                result.map[val.map] += 1;
            } else {
                result.map[val.map] = 1;
            }
        } else {
            for(vk in val.map) {
                if(result.map[vk]) {
                    result.map[vk] += 1;
                } else {
                    result.map[vk] = 1;
                }
            }
        }
    });
    return result;
}
