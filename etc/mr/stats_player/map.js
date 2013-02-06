function() {
    for(k in this.vehicles) {
        var key = this.vehicles[k].name + '_' + this.player.server;
        if(this.vehicles[k].vehicleType) {
            emit(key, {
                kills: this.vehicles[k].kills,
                destroyed: this.vehicles[k].destroyed,
                spotted: this.vehicles[k].spotted,
                damage_dealt: this.vehicles[k].damageDealt,
                damage_assisted: this.vehicles[k].damageAssisted,
                vehicle: this.vehicles[k].vehicleType.full,
                map: this.map.id
            });
        }
    }
}
