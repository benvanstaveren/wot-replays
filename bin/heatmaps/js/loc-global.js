var mapf = function() {
    emit({ x: this.x, y: this.y, gameplay_id: this.gameplay_id }, 1);
};
var redf = function(k, v) {
    var sum = 0;

    v.forEach(function(e) {
        sum += e;
    });
    return sum;
};

db.map_list.find().forEach(function(map) {
    var mapid = map._id;
    db.raw_location.mapReduce(mapf, redf, {
        out: { 'replace': 'locations_tmp' },
        query: {
            map_id: mapid,
            is_death: 0,
            is_damage: 0,
        }
    });

    db.locations_tmp.find().forEach(function(loc) {
        var coll = 'locations_' + mapid + '_' + loc._id.gameplay_id;
        var rec  = {
            x       : loc._id.x,
            y       : loc._id.y,
            count   : loc.value
        };
        db[coll].save(rec);
    });

    db.raw_location.mapReduce(mapf, redf, {
        out: { 'replace': 'locations_tmp' },
        query: {
            map_id: mapid,
            is_death: 1,
            is_damage: 0,
        }
    });

    db.locations_tmp.find().forEach(function(loc) {
        var coll = 'death_locations_' + mapid + '_' + loc._id.gameplay_id;
        var rec  = {
            x       : loc._id.x,
            y       : loc._id.y,
            count   : loc.value
        };
        db[coll].save(rec);
    });

    db.raw_location.mapReduce(mapf, redf, {
        out: { 'replace': 'locations_tmp' },
        query: {
            map_id: mapid,
            is_death: 0,
            is_damage: 1,
        }
    });

    db.locations_tmp.find().forEach(function(loc) {
        var coll = 'damage_locations_' + mapid + '_' + loc._id.gameplay_id;
        var rec  = {
            x       : loc._id.x,
            y       : loc._id.y,
            count   : loc.value
        };
        db[coll].save(rec);
    });


});

db.locations_tmp.drop();
