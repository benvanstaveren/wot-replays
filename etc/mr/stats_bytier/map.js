function() {
    // find the vehicle and get it's class
    var vehicle = db['data.vehicles'].findOne({ _id: this.player.vehicle.full });
    if(vehicle && vehicle.type) emit(vehicle.level, 1);
}
