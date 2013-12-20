var mapf = function() {
    emit({ cell: this.cell, gameplay_id: this.gameplay_id, bonus_id: this.bonus_type }, 1);
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
            is: 'location',
        }
    });

    var rec = { _id: mapid, g: {}, };
    db.locations_tmp.find().forEach(function(loc) {
        value = loc.value;
        if(!rec.g[loc._id.gameplay_id]) rec.g[loc._id.gameplay_id] = {};
        if(!rec.g[loc._id.gameplay_id][loc._id.bonus_id]) rec.g[loc._id.gameplay_id][loc._id.bonus_id] = {};
        if(!rec.g[loc._id.gameplay_id][loc._id.bonus_id][loc._id.cell]) rec.g[loc._id.gameplay_id][loc._id.bonus_id][loc._id.cell] = 0;
        rec.g[loc._id.gameplay_id][loc._id.bonus_id][loc._id.cell] += value;
    });
    db.hm_location.save(rec);

    rec.g = {}
    db.raw_location.mapReduce(mapf, redf, {
        out: { 'replace': 'locations_tmp' },
        query: {
            map_id: mapid,
            is: 'death',
        }
    });
    db.locations_tmp.find().forEach(function(loc) {
        value = loc.value;
        if(!rec.g[loc._id.gameplay_id]) rec.g[loc._id.gameplay_id] = {}
        if(!rec.g[loc._id.gameplay_id][loc._id.bonus_id]) rec.g[loc._id.gameplay_id][loc._id.bonus_id] = {}
        if(!rec.g[loc._id.gameplay_id][loc._id.bonus_id][loc._id.cell]) rec.g[loc._id.gameplay_id][loc._id.bonus_id][loc._id.cell] = 0;
        rec.g[loc._id.gameplay_id][loc._id.bonus_id][loc._id.cell] += value;
    });
    db.hm_deaths.save(rec);

    rec.g = {}
    db.raw_location.mapReduce(mapf, redf, {
        out: { 'replace': 'locations_tmp' },
        query: {
            map_id: mapid,
            is: 'damage_r',
        }
    });
    db.locations_tmp.find().forEach(function(loc) {
        value = loc.value;
        if(!rec.g[loc._id.gameplay_id]) rec.g[loc._id.gameplay_id] = {}
        if(!rec.g[loc._id.gameplay_id][loc._id.bonus_id]) rec.g[loc._id.gameplay_id][loc._id.bonus_id] = {}
        if(!rec.g[loc._id.gameplay_id][loc._id.bonus_id][loc._id.cell]) rec.g[loc._id.gameplay_id][loc._id.bonus_id][loc._id.cell] = 0;
        rec.g[loc._id.gameplay_id][loc._id.bonus_id][loc._id.cell] += value;
    });
    db.hm_damage_r.save(rec);

    rec.g = {}
    db.raw_location.mapReduce(mapf, redf, {
        out: { 'replace': 'locations_tmp' },
        query: {
            map_id: mapid,
            is: 'damage_d',
        }
    });
    db.locations_tmp.find().forEach(function(loc) {
        value = loc.value;
        if(!rec.g[loc._id.gameplay_id]) rec.g[loc._id.gameplay_id] = {}
        if(!rec.g[loc._id.gameplay_id][loc._id.bonus_id]) rec.g[loc._id.gameplay_id][loc._id.bonus_id] = {}
        if(!rec.g[loc._id.gameplay_id][loc._id.bonus_id][loc._id.cell]) rec.g[loc._id.gameplay_id][loc._id.bonus_id][loc._id.cell] = 0;
        rec.g[loc._id.gameplay_id][loc._id.bonus_id][loc._id.cell] += value;
    });
    db.hm_damage_d.save(rec);

});
db.locations_tmp.drop();
db.raw_location.drop();
