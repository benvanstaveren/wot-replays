var Player = function(id) {
	this.id 		= id;
	this.position 	= null;
	this.alive		= null;
	this.clock		= null;
	this.health     = 0;
    this.hp         = 0;
    this.element    = $('div#player-' + id);
    this.age        = 0;
    this.hull_dir   = null;
    this.recorder   = ($(this.element).hasClass('recorder')) ? true : false;
    this.damaged    = false;
    this.damagesource = null;
    this.damager    = null;
}
Player.prototype = {
    hide: function() {
        $(this.element).hide();
    },
    setAge: function(newAge) {
        this.age = newAge;
        $(this.element).css({ opacity: 1 - this.age });
    },
    show: function() {
        $(this.element).show();
    },
    move: function(ctop, cleft) {
        $(this.element).hide();
        $(this.element).css({ top: ctop, left: cleft });
        $(this.element).show();
    },
    rotate: function() {
        // the hull direction is in fact in radians, so convert to degrees first
        var degrees = this.hull_dir * (180 / Math.PI);
        var c = {
            '-moz-transform': 'rotate(' + Math.round(degrees) + 'deg)',
            '-ms-transform': 'rotate(' + Math.round(degrees) + 'deg)',
            '-webkit-transform': 'rotate(' + Math.round(degrees) + 'deg)',
            '-o-transform': 'rotate(' + Math.round(degrees) + 'deg)',
            'transform': 'rotate(' + Math.round(degrees) + 'deg)'
        };
        // we don't use our element but we use #recorder-icon instead
        $('#recorder-icon').css(c);
    },
    updateHealth: function(newhealth) {
        if(newhealth < 0) newhealth = 0;
        if(newhealth > this.hp) return;
        if(this.hp > 0) {
            if(newhealth > 0) {
                var percentage_of = Math.floor(100/(this.hp/newhealth));
                if(percentage_of > 100) percentage_of = 0; // for some reason ammo rackings cause this to go really badly wrong
                $('#player-health-' + this.id).css({ width: percentage_of + '%' });
            } else {
                $('#player-health-' + this.id).css({ width: '0%' });
            }
        }
        this.health = newhealth;
        if(this.health <= 0) this.alive = false;
    },
    death: function() {
        $(this.element).hide();
        $(this.element).addClass('dead').css({ 'background-color': 'rgba(0, 0, 0, 0.8)', 'opacity': 0.8 });
        $(this.element).show();
    }
};

var Game = function(game, map_boundaries, playerDetails) {
	this.players 	    = {};
	this.playerDetails 	= playerDetails;
	this.clock		    = 0;
	this.game		    = game;
    this.mode           = game.mode;
    this.map_boundaries = map_boundaries;
}

Game.prototype = {
	getPlayer: function(id) {
		var player = this.players[id];
		if (typeof(player) == 'undefined') {
			player = new Player(id);
			player.alive = true;
            if(typeof(this.playerDetails[id]) != 'undefined') {
                player.hp = this.playerDetails[id].hp;
                player.health = this.playerDetails[id].hp;
            }
			this.players[id] = player;
		}
		return player;
	},
	update: function(frame) {
		if (typeof(frame.clock) == 'undefined') return;
		if (frame.clock != null && frame.clock >= this.clock) this.clock = frame.clock;
        if(typeof(frame.id) != 'undefined') {
			var player      = this.getPlayer(frame.id);
            player.clock    = this.clock;

		    if (typeof(frame.position) != 'undefined') {
                player.position = frame.position;
            }
            if(typeof(frame.orientation) != 'undefined') {
                if(player.recorder) player.hull_dir = frame.orientation[0];
            }
            if (typeof(frame.health) != 'undefined') {
                player.updateHealth(frame.health);
                if (typeof(frame.source) != 'undefined') {
                    var source = this.getPlayer(frame.source);
                    player.damaged = true;
                    player.damagesource = source.position;
                    player.damager = frame.source;
                }
            }
        }
	}
}

var BattleViewer = function(options) {
    this.container     = options.container;
    this.tracercount   = 1;
    this.clock         = options.clock;
    this.packet_url    = options.packets;
    this.game_data     = options.gamedata;
    this.onError       = options.onError;
    this.map_boundaries = this.game_data.map_boundaries;
    this.player_details = options.player_details || {};
    this.onLoaded       = options.onLoaded;
    this.stopping = false;
    this.updateSpeed = 100; // realtime?
}

BattleViewer.prototype = {
	start: function() {
        var bv = this;
        // hide all players, and the clock
        $('div.player').hide();
        $(this.clock).hide();
        if(this.packets) {
            this._replay();
            return;
        }
        $.ajax({
            url: this.packet_url,
            type: 'GET',
            dataType: 'json',
            crossDomain: true,
            timeout: 60000,
            success: function(d, t, x) {
                bv.packets = d;
                bv.onLoaded();
                bv._replay();
            },
            error: function(j, t, e) {
                if(bv.onError) bv.onError(t, e);
            },
        });
    },
    stop: function() {
        this.stopping = true;
    },
    setSpeed: function(newspeed) {
        this.updateSpeed = newspeed;
    },
    _replay: function() {
        this.game = new Game(this.game_data, this.map_boundaries, this.player_details);
		var update = function(game, packets, window_start, window_size, start_ix) {
			if (this.game != game) return;
			var window_end = window_start + window_size, ix;
			for (ix = start_ix; ix < packets.length; ix++) {
				var packet = packets[ix];
				if (typeof(packet.clock) == 'undefined') continue;
				if (packet.clock > window_end) break;
				game.update(packet);
			}

			this.show();

            if(this.stopping) ix = packets.length;
			
			if (ix < packets.length) {
				setTimeout(update.bind(this, game, packets, window_end, window_size, ix), this.updateSpeed);	
			} else {
				this.updateChat('Replay finished.');
			}
		}
		update.call(this, this.game, this.packets, 0, 0.1, 0);
	},
	updateChat: function(message) {
        console.log('chat: ', message);
    },
	show: function() {
		for (var player_id in this.game.players) {
			var player = this.game.getPlayer(player_id);
            player.hide();

			if (player.position == null) continue;

			var coord = this.to_2d_coord(player.position, this.game.map_boundaries, 512, 512);
            if(coord == null) continue;

            var age = player.alive ? ((this.game.clock - player.clock) / 20) : 0;
            age = age > 0.66 ? 0.66 : age;

            player.setAge(age);
            if(player.damaged) {
                if(typeof(player.damagesource) == 'object' && typeof(player.position) == 'object') {
                    var source = this.to_2d_coord(player.damagesource, this.game.map_boundaries, 512, 512);
                    if(source != null) this.drawTracer(source, coord);
                }
                player.damaged = false;
                player.damagesource = null;
                player.damager = null;
            }
            if(player.recorder) player.rotate();
			if (player.alive) {
                player.move(Math.round(coord.y - (17/2)), Math.round(coord.x - (17/2)));
	 		} else {
                player.death();
 			}
		}
        $(this.clock).html(this.getClock(this.game.clock, this.game.mode));
        // if the clock is hidden, show it
        if(!$(this.clock).is(':visible')) $(this.clock).show();
	},
    delta: function(a, b) {
        if(a < b) {
            return b - a;
        } else {
            return a - b;
        }
    },
    difference: function(a, b) {
        return a - b;
    },
    distance: function(p1, p2) {
        // distance = sqrt(a^2 + b^2) 
        var a = this.delta(p1.x, p2.x);
        var b = this.delta(p1.y, p2.y);
        var d = Math.sqrt(Math.pow(a, 2) + Math.pow(b, 2));
        return d;
    },
    min: function(a, b) {
        if(a < b) {
            return a;
        } else {
            return b;
        }
    },
    max: function(a, b) {
        if(a > b) {
            return a;
        } else {
            return b;
        }
    },
    drawTracer: function(s, t) {
        s.x = Math.floor(s.x);
        s.y = Math.floor(s.y);
        t.x = Math.floor(t.x);
        t.y = Math.floor(t.y);

        var length = this.distance(s, t);

        if(length < 50) return; // no need to jump through the hoops

        var tracer = $('<div>').attr('id', 'tracer-' + this.tracercount).addClass('tracer');
        $(tracer).css({ 
            'top': s.y + 'px',
            'left': s.x + 'px',
            'position': 'absolute',
            '-moz-transform-origin': '0% 0%',
            '-webkit-transform-origin': '0% 0%',
            '-o-transform-origin': '0% 0%',
            '-ms-transform-origin': '0% 0%',
            'transform-origin': '0% 0%',
            'width': length + 'px',
            'z-index': 5,
        });

        // figure out which quad we need
        var quad = 1;
        if(s.y >= t.y) {
            if(s.x <= t.x) quad = 1;
            if(s.x > t.x) quad = 4;
        } else {
            // s.y < t.y
            if(s.x <= t.x) quad = 2;
            if(s.x > t.x) quad = 3;
        }

        // we need to add quad * 90 degrees to the end result, but since we're
        // dealing with CSS transforms, angle 0 is actually angle 90 so, quad - 1 * 90

        var x_delta = this.delta(s.x, t.x);
        var y_delta = this.delta(s.y, t.y);
        var atan = Math.atan2(y_delta, x_delta);
        if(atan < 0) atan = atan * -1; 

        var atan_angle = atan * 180 / Math.PI;

        var angle = 0;
        if(quad == 1) {
            angle = 360 - atan_angle; // because we need to flip it around
        } else if(quad == 2) {
            angle = atan_angle; // because this works
        } else if(quad == 3) {
            // 90 + atan_angle
            angle = 180 - atan_angle;
        } else {
            // quad 4, 180 + atan_angle 
            angle = 180 + atan_angle;
        }

        angle = Math.round(angle);

        //console.log('tracer ', this.tracercount, ' at length: ', length, ' atan_angle: ', atan_angle, ' angle: ', angle, ' y_delta: ', y_delta, ' x_delta: ', x_delta, ' quad: ', quad);
        
        $(tracer).css({
            'transform': 'rotate(' + angle + 'deg)',
            '-ms-transform': 'rotate(' + angle + 'deg)',
            '-o-transform': 'rotate(' + angle + 'deg)',
            '-webkit-transform': 'rotate(' + angle + 'deg)',
            '-moz-transform': 'rotate(' + angle + 'deg)'
        });

        var sdiv = $('<div>').css({ 'z-index': 500, 'text-align': 'center', 'font-weight': 'bold', 'width': '17px', 'height': '17px', 'background': '#0f0 none repeat scroll 0 0', 'position': 'absolute', 'top': s.y - 8, 'left': s.x - 8 }).html(this.tracercount).attr('id', 'sdiv-' + this.tracercount);
        var tdiv = $('<div>').css({ 'z-index': 500, 'text-align': 'center', 'font-weight': 'bold', 'width': '17px', 'height': '17px', 'background': '#f00 none repeat scroll 0 0', 'position': 'absolute', 'top': t.y - 8, 'left': t.x - 8 }).html(this.tracercount).attr('id', 'tdiv-' + this.tracercount);

        $(tracer).attr('source', s.x + ',' + s.y);
        $(tracer).attr('target', t.x + ',' + t.y);


        //$(this.container).append($(tracer), $(sdiv), $(tdiv));
        $(this.container).append($(tracer));
        //$(sdiv).hide().fadeIn(this.updateSpeed);
        //$(tdiv).hide().fadeIn(this.updateSpeed);
        $(tracer).hide().fadeIn(this.updateSpeed, function() {
            $(tracer).fadeOut(400, function() {
                $(tracer).remove();
            });
        });

        this.tracercount++;
    },
    to_2d_coord: function(position, map_boundaries, width, height) {
        try {
            var x = position[0], y = position[2], z = position[1];
            x = (x - map_boundaries[0][0]) * (width / (map_boundaries[1][0] - map_boundaries[0][0] + 1));
            y = (map_boundaries[1][1] - y) * (height / (map_boundaries[1][1] - map_boundaries[0][1] + 1));
            return { x: x, y: y };
        } catch(err) {
            console.log('tried getting position out of ', position, ' failed with ', err);
            return null;
        }
    },
    getClock: function(clock, mode) {
	    var gamelength = (mode == 'ctf' ? 938 : 638);
	    var clockseconds = gamelength-clock;
	    var minutes = Math.floor(clockseconds / 60);
	    var seconds = Math.floor(clockseconds - minutes * 60);
	    seconds = (seconds < 10 ? '0' + seconds : seconds);
	    return minutes + ":" + seconds;
    }
};
