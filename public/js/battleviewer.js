/*
    wotreplays.org battle viewer 2.0 20131208 0426

    Based on work done by Evido (http://github.com/evido)
   
    Alterations by Scrambled:
    - Use HTML5 instead of canvas
    - Modified to use the different packet format that wotreplays.org writes out

    Feel free to copy and use for your own purposes
*/
var Player = function(id) {
	this.id 		= id;
	this.position 	= null;
	this.alive		= null;
	this.clock		= null;
	this.health     = 0;
    this.team       = 0;
    this.hp         = 0;
    this.name       = null;
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
        $(this.element).css({ top: ctop, left: cleft });
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
        var oldHealth = this.health;
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
        var diff = oldHealth - newhealth;
        return diff;
    },
    death: function() {
        this.alive = false; 
        this.updateHealth(0);
        $(this.element).addClass('dead');
    }
};

var Game = function(game, map_boundaries, playerDetails, periodPanel, chatPanel, playerTeam) {
	this.players 	    = {};
	this.playerDetails 	= playerDetails;
    this.playerTeam     = playerTeam;
    this.periodPanel    = periodPanel;
	this.clock		    = 0;
	this.game		    = game;
    this.mode           = game.mode;
    this.map_boundaries = map_boundaries;
    this.period         = 0;
    this.period_length  = -1;
    this.clock_at_period = 0;
    this.chatPanel       = chatPanel;
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
                player.name = this.playerDetails[id].name;
                player.team = this.playerDetails[id].team;
            }
			this.players[id] = player;
		}
		return player;
	},
    updateChatRaw: function(message) {
        $(this.chatPanel).append(
            $(message).addClass('clearfix')
        );
    },
    updateChat: function(message) {
        if(this.chatPanel) {
            $(this.chatPanel).append(
                $('<div>').addClass('clearfix').html(message)
            );
        } else {
            console.log('Chat: ', message);
        }
    },
    isEnemy: function(player) {
        return (player.team == this.playerTeam) ? false : true;
    },
    teamColorName: function(player) {
        var s = $('<span>');
        if(this.isEnemy(player)) {
            $(s).addClass('enemy');
        } else {
            $(s).addClass('friendly');
        }
        $(s).text(player.name);
        return s;
    },
	update: function(frame) {
        var g = this;
        if (frame.period) {
            //console.log('got frame.period: ', frame.period);
            this.period = frame.period;
            if(this.period == 2) {
                $(this.periodPanel).html('Countdown...');
            } else if(this.period == 3) {
                $(this.periodPanel).html('In Battle...');
            } else if(this.period == 4) {
                $(this.periodPanel).html('After Battle...');
            }
            this.period_length = frame.period_length;
            this.clock_at_period = this.clock;
        }
		if (typeof(frame.clock) == 'undefined') return;
		if (frame.clock != null && frame.clock >= this.clock) this.clock = frame.clock;
        if (typeof(frame.text) != 'undefined') this.updateChat(frame.text);

        if(typeof(frame.id) != 'undefined') {
			var player      = this.getPlayer(frame.id);
            player.clock    = this.clock;

            // we could in theory keep track of all this for dead entities
            // but we don't...

            if (typeof(frame.position) != 'undefined') {
                player.position = frame.position;
            }
            if(typeof(frame.orientation) != 'undefined') {
                if(player.recorder) player.hull_dir = frame.orientation[0];
            }
            if(typeof(frame.destroyer) != 'undefined' && typeof(frame.destroyed) != 'undefined') {
                var destroyed = this.getPlayer(frame.destroyed);
                var destroyer = this.getPlayer(frame.destroyer);
                this.updateChatRaw( 
                    $('<div>').append(
                        this.teamColorName(destroyer),
                        $('<b>').css({ 'margin-left': '5px', 'margin-right': '5px' }).text('destroyed'),
                        this.teamColorName(destroyed) 
                    )
                );
                destroyed.death();
            }
            if(player.alive) {
                if (typeof(frame.health) != 'undefined') {
                    player.updateHealth(frame.health);
                    if (typeof(frame.source) != 'undefined') {
                        var source = g.getPlayer(frame.source);
                        if(source) {
                            player.damaged = true;
                            player.damagesource = source.position;
                            player.damager = frame.source;
                        }
                    }
                }
            }
        }
	}
}

var BattleViewer = function(options) {
    this.container      = options.container;
    this.tracercount    = 1;
    this.clock          = options.clock;
    this.packet_url     = options.packets;
    this.game_data      = options.gamedata;
    this.onError        = options.onError;
    this.map_boundaries = this.game_data.map_boundaries;
    this.player_details = options.player_details || {};
    this.onLoaded       = options.onLoaded;
    this.stopping       = false;
    this.updateSpeed    = 100; // realtime?
    this.chatPanel      = options.chatPanel;
    this.periodPanel    = options.periodPanel;
    this.playerTeam     = options.playerTeam;
}

BattleViewer.prototype = {
	start: function() {
        console.log('battleViewer start');
        $('div.player').hide(); // hide all players, we'll show them once we first get a position in move()
        var bv = this;
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
        // kill the clock
        this.stopping = true;
    },
    setSpeed: function(newspeed) {
        console.log('new speed: ', newspeed);
        this.updateSpeed = newspeed;
    },
    updateClock: function() {
        var clockHtml = "--:--";
        if(this.game) {
            if(this.game.period_length > 0) {
                // clock seconds is period length minus (the game clock minus the clock_at_period value)
                //console.log('update clock, period len: ', this.game.period_length, ' clock: ', this.game.clock, ' clock_at_period: ', this.game.clock_at_period, ' time in period: ', this.game.clock - this.game.clock_at_period);
	            var clockseconds = this.game.period_length - (this.game.clock - this.game.clock_at_period);
	            var minutes = Math.floor(clockseconds / 60);
	            var seconds = Math.floor(clockseconds - minutes * 60);
	            seconds = (seconds < 10 ? '0' + seconds : seconds);
	            minutes = (minutes < 10 ? '0' + minutes : minutes);
	            clockHtml = minutes + ":" + seconds;
            } 
        } 
        $(this.clock).html(clockHtml);

    },
    _replay: function() {
        this.game = new Game(this.game_data, this.map_boundaries, this.player_details, this.periodPanel, this.chatPanel, this.playerTeam);
        var me = this;

		var update = function(game, packets, window_start, window_size, start_ix) {
			if (this.game != game) return;
			var window_end = window_start + window_size, ix;
			for (ix = start_ix; ix < packets.length; ix++) {
				var packet = packets[ix];
				if (typeof(packet.clock) == 'undefined' && (typeof(packet.period) == 'undefined')) continue; // chat has clock, period doesnt(?)
				if (packet.clock > window_end) break;
                game.update(packet);
			}

			this.show();

            if(this.stopping) ix = packets.length;

            this.updateClock();
			
			if (ix < packets.length) {
				setTimeout(update.bind(this, game, packets, window_end, window_size, ix), this.updateSpeed);	
			} else {
				this.updateChat('Replay finished.');
			}
		}
		update.call(this, this.game, this.packets, 0, 0.1, 0);
	},
	updateChat: function(message) {
        this.game.updateChat(message);
    },
	show: function() {
        if(!$(this.clock).is(':visible')) $(this.clock).show();
		for (var player_id in this.game.players) {
			var player = this.game.getPlayer(player_id);

			if (player.position == null) continue;

            player.show();

			var coord = this.to_2d_coord(player.position, this.game.map_boundaries, 512, 512);
            if(coord == null) continue;

            var age = player.alive ? ((this.game.clock - player.clock) / 20) : 0;
            age = age > 0.66 ? 0.66 : age;

            player.setAge(age);

            if(player.damaged) {
                //console.log('player damaged');
                if(typeof(player.damagesource) == 'object' && typeof(player.position) == 'object') {
                    //console.log('source is another player');
                    var source = this.to_2d_coord(player.damagesource, this.game.map_boundaries, 512, 512);
                    if(source != null) {
                        //console.log('source coordinates established, drawing tracer from ', source, ' to ', coord);
                        this.drawTracer(source, coord);
                    }
                }
                player.damaged      = false;
                player.damagesource = null;
            }
            if(player.recorder) player.rotate();
            player.move(Math.round(coord.y - (17/2)), Math.round(coord.x - (17/2)));
		}
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

        $(this.container).append($(tracer));
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
            //console.log('tried getting position out of ', position, ' failed with ', err);
            return null;
        }
    },
};


$(document).ready(function() {
    bView.start();
});
