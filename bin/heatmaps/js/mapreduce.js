// get a child database for wot replays 
conn = new Mongo();
wotreplays = conn.getDB('wot-replays');
heatmaps = db;

var rpcursor = wotreplays.replays.find({ has_packets: true });
while(rpcursor.hasNext()) {
    replay      = rpcursor.next();
    replayid    = replay._id;
    game_type   = replay.game.type;
    bonus_type  = replay.game.bonus_type;
    map_id      = replay.game.map;

     

    // the above basically goes into the standard packet record, well, mostly at any rate... 
    heatmaps.createCollection('location_tmp');

    print(replayid);
    var a = wotreplays.packets.find({ '_meta.replay': replayid, '_meta.fields': { '$in': [ 'position' ] }});
    
    a.forEach(function(packet) {
        // packet.location is defined, we may want to obtain some additional information for vehicle type here later
        // as far as it goes for queries and such things, the entire kit and kaboodle will have to become part of _id
        // in the map reduce to ensure uniqueness, and to be able to websocket the crap out of it 

        heatmaps.location_tmp.insert({ 
            p   : { x: packet.position[0], y: packet.position[2] },
            gt  : game_type,
            bt  : bonus_type,
            m   : map_id,
            vt  : replay.roster[replay.vehicles[packet.id]].vehicle.type
            });
    });

    var mapf = function() {
        emit({ x: this.x, y: this.y, gt: this.gt, bt: this.bt, m: this.m, vt: this.vt }, 1);
    };
    var redf = function(k, v) {
        var sum = 0;
        v.forEach(function(e) {
            sum += e;
        });
        return sum;
    };

    heatmaps.location_tmp.mapReduce(mapf, redf, { out: { replace: 'locations' }, verbose: true });
    heatmaps.location_tmp.drop();
}

        




    




