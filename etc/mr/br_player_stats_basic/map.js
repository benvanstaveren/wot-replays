function() {
    // we want to emit stuff on a per-player basis, key is dbid-playername
    var players     = this.battle_result.players;
    var vehicles    = this.battle_result.vehicles;
    var common      = this.battle_result.common;

    for(vehicleID in vehicles) {
        var vehicle = vehicles[vehicleID + ''];
        var player  = players[vehicle.accountDBID + ''];
        var key     = vehicle.accountDBID + '-' + player.name;
        var emitData = {
            count:          1,
            kills:          vehicle.kills,
            damaged:        vehicle.damaged,
            spotted:        vehicle.spotted,
            damageDealt:    vehicle.damageDealt,
            damageAssisted: vehicle.damageAssisted,
            xp:             vehicle.xp,
            credits:        vehicle.credits,
            repair:         vehicle.repair,
            health:         vehicle.health,
            survived:       (vehicle.health > 0) ? 1 : 0,
            mileage:        vehicle.mileage,
            shots:          vehicle.shots,
            pierced:        vehicle.pierced,
            hits:           vehicle.hits
        };
        emit(key, emitData);
    }
}
