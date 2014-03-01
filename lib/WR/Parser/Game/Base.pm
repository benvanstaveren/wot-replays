package WR::Parser::Game::Base;
use Mojo::Base 'Mojo::EventEmitter';
use WR::Util::VehicleDescriptor;
use WR::Util::TypeComp qw/parse_int_compact_descr type_id_to_name/;
use WR::Constants qw/nation_id_to_name/;
use Data::Dumper;

has 'stream'            => undef;
has '_roster'           => undef;      # the players in the match 
has 'vehicles'          => sub { {} }; # maps vehicle id to roster entry    
has 'recorder'          => sub { {} };      
has 'positions'         => sub { {} }; # position recording by vehicle ID
has 'rosteridx'         => 0;

# initial and current shell and consumable slot setup
has 'vshells'           => sub { {} };
has 'vcons'             => sub { {} };
has 'vshells_initial'   => sub { {} };
has 'vcons_initial'     => sub { {} };

# game version and packet counter
has 'version'           =>  0;
has 'pcounter'          =>  0;

has 'stopping'          => 0;
has 'handlers'          => sub { [] };
has 'map_done'          => 0;
has 'arena_period'      => 0;

# speshul, we'll try to reconstruct the battle result out of whatever
# is in the replay data. it will, of course, be missing a lot of stuff
# that the game adds after a match (xp, credits, resupply, etc.) 
has 'playerstats'       => sub { {} };
has 'playerhealth'      => sub { {} }; # records health by vehicle

sub roster {
    my $self = shift;
    my $v    = shift;

    if($v) { 
        $self->_roster($v);
    } else {
        return $self->_roster;
    }
}

sub start {
    my $self = shift;
    my $stopping = 0;
    my $status   = 0;

    $self->add_handlers;

    $self->emit('replay.size' => $self->stream->len);

    $self->stream->on('finish' => sub {
        my ($stream, $status) = (@_);

        warn 'stream finished in Game.pm, re-emit using: ', Dumper($status), "\n";
        $self->emit(finish => $status);
        $stopping = 1;
    });

    while(!$stopping) {
        if($self->stopping) {
            $self->emit(finish => { ok => 1, reason => 'stopped' });
            $stopping = 1;
        } else {
            if(my $packet = $self->stream->next()) {
                $self->process_packet($packet);
            } else {
                $stopping = 1;
            }
        }
    }
}

sub is_player {
    my $self = shift;
    my $vid  = shift;

    return (defined($self->vehicles->{$vid})) ? 1 : 0;
}

sub process_packet {
    my $self = shift;
    my $packet = shift;

    $self->pcounter($self->pcounter + 1);
    
    $self->emit('replay.position' => $self->stream->position) if($self->pcounter % 50 == 0);

    if(defined($self->handlers->[$packet->type])) {
        die 'Packet type mismatch, packet type hex is ', sprintf('%02x', $packet->type), ' but blessed to ', ref($packet), "\n" if(sprintf('WR::Parser::Stream::Packet::0x%02x', $packet->type) ne ref($packet));
        $self->handlers->[$packet->type]->($self, $packet);
    } else {
        $self->emit('unknown' => $packet);
    }

    # by default we also emit all packets without handling them, if you don't subscribe to the event it doesn't cause overhead
    $self->emit('packet' => $packet);
}

sub add_handler {
    my $self = shift;
    my $type = shift;
    my $sub  = shift;

    # type has to be a module 
    my $pm = sprintf('WR::Parser::Stream::Packet::0x%02x', $type);

    my $hsub = sub {
        my ($self, $packet) = (@_);

        if(ref($packet) eq $pm) {
            $sub->($self => $packet);
        } else {
            warn 'packet handler mismatch, wanted ', $pm, ' got ', ref($packet), "\n";
        }
    };
    $self->handlers->[$type] = $hsub;
}

sub add_handlers {
    my $self = shift;

    $self->add_handler(0x00 => sub { shift->onArenaInit(@_) });
    $self->add_handler(0x14 => sub { shift->onGameInit(@_) });
    $self->add_handler(0x0a => sub { shift->onUpdatePosition(@_) });
    $self->add_handler(0x0b => sub { shift->onSpaceInit(@_) });
    $self->add_handler(0x21 => sub { shift->onMinimapClicked(shift) });

    $self->add_handler(0x08 => sub {
        my $self   = shift;
        my $packet = shift;

        # these seem to always appear under subtype 29 (1d) (?)
        if($packet->subtype == 0x1d) {
            $self->onArenaHandler($packet);
        } elsif($packet->subtype == 0x09) { # 0.8.9 changed subtype to 0x09, 0x0a is now used for something else
            $self->onSlotChange($packet);
        } elsif($packet->subtype == 0x01) {
            $self->onDamageReceived($packet);
        }
    });

    $self->add_handler(0x1f => sub { shift->onChat(@_) });
    $self->add_handler(0x17 => sub { shift->onViewMode(@_) });

    $self->add_handler(0x07 => sub {
        my $self = shift;
        my $packet = shift;

        if($packet->subtype == 0x03) {
            $self->emit('player.health' => { 
                ident   => 'player.health',
                id      => $packet->player_id, 
                health  => $packet->health,
                clock   => $packet->clock,
                _packet => $packet->to_hash(1),
            });
        } elsif($packet->subtype == 0x07) {
            $self->emit('player.track.destroyed' => { 
                id      => $packet->player_id, 
                ident   => 'player.track.destroyed',
                track   => (defined($packet->destroyed_track_id))
                    ?  ($packet->destroyed_track_id == 0xf0) 
                        ? 'left'
                        : ($packet->destroyed_track_id == 0xf6)
                            ? 'right'
                            : 'none'
                    : 'none',
                clock   => $packet->clock,
            });
        }
    });
}

sub onViewMode {
    my $self = shift;
    my $packet = shift;

    $self->emit('recorder.viewmode' => {
        clock   => $packet->clock,
        ident   => 'recorder.viewmode',
        mode    => $packet->viewmode,
    });
}

sub onChat {
    my $self = shift;
    my $packet = shift;
    $self->emit('player.chat' => {
        clock   => $packet->clock,
        ident   => 'player.chat',
        text    => $packet->text
    });
}

sub onDamageReceived {
    my $self = shift;
    my $packet = shift;

    # damage packet, should in theory be followed by a 0x03 to indicate the damage
    # and such that was done, but we can live with this
    $self->emit('player.tank.damaged' => {
        ident   => 'player.tank.damaged',
        clock   => $packet->clock,
        id      => $packet->player_id,
        health  => $packet->health,
        source  => $packet->source,
    });
}

sub onSlotChange {
    my $self = shift;
    my $packet = shift;

    return unless (defined($packet->slot)); 

    my $item  = $packet->slot->{item};
    my $count = $packet->slot->{count};

    my $tc = parse_int_compact_descr($item + 0);
    if(type_id_to_name($tc->{type_id}) eq 'shell') {
        $self->vshells->{$item} = {
            item => $tc,
            count => $count,
        };
        $self->vshells_initial->{$item} = {
            item => $tc,
            count => $count,
        } unless(defined($self->vshells_initial->{$item}));
    } elsif(type_id_to_name($tc->{type_id}) eq 'equipment') {
        $self->vcons->{$item} = {
            item => $tc,
            count => $count,
        };
        $self->vcons_initial->{$item} = {
            item => $tc,
            count => $count,
        } unless(defined($self->vcons_initial->{$item}));
    }
    $self->emit('player.slot' => {
        clock     => $packet->clock,
        slot      => {
            item    => $tc,
            count   => $count,
        }
    });
}

sub onSpaceInit {
    my $self = shift;
    my $packet = shift;

    if(defined($packet->space)) {
        $self->emit('setup.map' => $packet->space) if($self->map_done == 0); # seems we get 2 0x0b packets, one contains stuff and space, one just stuff
        $self->map_done(1);
    }
}

sub wot_version_string_to_numeric {
    my $self = shift;
    my $v    = shift;

    my @ver = split(/\,/, $v);
    my @wgfix = ();
    while(@ver) {
        my $a = shift(@ver);
        $a =~ s/^\s+//g;
        $a =~ s/\s+$//g; # ffffuck
        if($a =~ /\s+/) {
            push(@wgfix, (split(/\s+/, $a)));
        } else {
            push(@wgfix, $a);
        }
    }

    return $wgfix[0] * 1000000 + $wgfix[1] * 10000 + $wgfix[2] * 100 + $wgfix[3];
}

sub onGameInit {
    my $self   = shift;
    my $packet = shift;

    $self->emit('game.version'   => $packet->version);
    $self->emit('game.version_n' => $self->wot_version_string_to_numeric($packet->version));
    $self->version($self->wot_version_string_to_numeric($packet->version));
}

sub onArenaInit {
    my $self   = shift;
    my $packet = shift;

    # packet 0x00 itself is the arena setup 
    $self->emit('arena.initialize' => $packet->to_hash);

    $self->recorder->{name} = $packet->player_name;

    $self->emit('recorder.name' => $packet->player_name);
    $self->emit('setup.battle_level' => $packet->battle_level); # this is a bit superfluous now since we can use arena.initialize to get to it
}

sub onMinimapClicked {
    my $self   = shift;
    my $packet = shift;

    $self->emit('cell.attention' => { clock => $packet->clock, cell_id => $packet->cell_id, ident => 'cell.attention' });
}

sub is_recorder {
    my $self = shift;
    my $p    = shift;

    if(ref($p)) {
        return ($p->player_id == $self->recorder->{id}) ? 1 : 0;
    } else {
        return ($p == $self->recorder->{id}) ? 1 : 0;
    }
}

sub get_recorder_position {
    my $self = shift;

    return $self->positions->{$self->recorder->{id}};
}

sub get_player_position {
    my $self = shift;
    my $id   = shift;

    return (defined($self->positions->{$id})) ? $self->positions->{$id} : undef;
}

sub distance {
    my $self = shift;
    my $r = shift;
    my $p = shift;

    return -1 unless(defined($r) && defined($p));

    sub delta {
        my $a = shift;
        my $b = shift;
        return $b - $a if($a < $b);
        return $a - $b;
    }

    my $a = delta($r->[0], $p->[0]);
    my $b = delta($r->[2], $p->[2]);
    my $d = sqrt($a**2 + $b**2);
    return $d;
}

sub distance_to_recorder {
    my $self = shift;
    my $pos  = shift;

    return $self->distance($self->get_recorder_position, $pos);
}

sub distance_to_recorder_points {
    my $self = shift;
    my $pos  = shift;

    my $dist = $self->distance_to_recorder($pos);
    return 0 if($dist < 0);

    return ($dist <= 50)
        ? 0.1
        : ($dist <= 150) 
            ? 0.5
            : ($dist <= 270) 
                ? 1
                : ($dist <= 445)
                    ? 2
                    : 0;
}

sub player_name {
    my $self = shift;
    my $id   = shift;
    
    return undef unless($self->is_player($id));
    return $self->roster->[$self->vehicles->{$id}]->{name};
}

sub onUpdatePosition {
    my $self = shift;
    my $packet = shift;

    # the is_player is required because we sometimes get these for non-player objects or keyed to the arena's base ID,
    # so could be the birds, planes, or w/e activity is there. 
    if($self->is_player($packet->player_id)) {
        my $update = {
            id              => $packet->player_id,
            position        => $packet->position,
            clock           => $packet->clock,
            orientation     => $packet->hull_orientation,
            ident           => 'player.position',
            distance_t      => $self->distance($packet->position, $self->positions->{$packet->player_id}),
            distance_r      => $self->distance_to_recorder($packet->position),
            points          => $self->distance_to_recorder_points($packet->position),
        };
        $self->emit('player.position' => $update);
        $self->positions->{$packet->player_id} = $packet->position;
    }
}

sub onArenaHandler {
    my $self    = shift;
    my $packet  = shift;

    if($packet->update_type == 0x01) {
        my $roster = $packet->update;
        my $new    = [];

        $self->rosteridx(0);

        # this really is arena.VEHICLE_LIST

        foreach my $entry (@$roster) {
            # turn it into a hash, same keys as the usual record from the battle result; non-standard
            # keys are present
            my $h = {
                name            => $entry->[2],
                team            => $entry->[3], 
                accountDBID     => $entry->[7] + 0,
                clanAbbrev      => $entry->[8],
                clanDBID        => $entry->[9] + 0,
                prebattleID     => $entry->[10] + 0,
                vehicleFitting  => WR::Util::VehicleDescriptor->new(descriptor => $entry->[1])->to_hash,
                vehicleID       => $entry->[0],
            };

            # these are still in use
            $self->emit('setup.team' => { 
                id =>  $h->{vehicleID},
                name => $h->{name},
                team => $h->{team} - 1,
            });
            $self->emit('setup.fitting' => {
                id => $h->{vehicleID},
                fitting => $h->{vehicleFitting}
            });

            push(@$new, $h);

            $self->vehicles->{$h->{vehicleID}} = $self->rosteridx;
            $self->rosteridx($self->rosteridx + 1);
            if($h->{name} eq $self->recorder->{name}) {
                $self->emit('recorder.id' => $h->{vehicleID}); 
                $self->emit('recorder.account_id' => $h->{accountDBID});
                $self->recorder->{id} = $h->{vehicleID};
            }
        }

        $self->roster($new);

        $self->emit('setup.roster' => $new);
        $self->emit('arena.vehicle_list' => {
            clock  => $packet->clock,
            list   => $new,
            ident  => 'arena.vehicle_list',
        });
    } elsif($packet->update_type == 0x02) {
        my $entry = $packet->update;
        my $h = {
            name            => $entry->[2],
            team            => $entry->[3],
            accountDBID     => $entry->[7] + 0,
            clanAbbrev      => $entry->[8],
            clanDBID        => $entry->[9] + 0,
            prebattleID     => $entry->[10] + 0,
            vehicleFitting  => WR::Util::VehicleDescriptor->new(descriptor => $entry->[1])->to_hash,
            vehicleID       => $entry->[0],
        };

        push(@{$self->roster}, $h);

        $self->vehicles->{$h->{vehicleID}} = $self->rosteridx;
        $self->rosteridx($self->rosteridx + 1);

        if($h->{name} eq $self->recorder->{name}) {
            $self->emit('recorder.id' => $h->{vehicleID});
            $self->recorder->{id} = $h->{vehicleID};
        }

        $self->emit('arena.vehicle_added' => { clock => $packet->clock, ident => 'arena.vehicle_added', %$h });
    } elsif($packet->update_type == 0x03) {
        $self->emit('arena.period' => {
            clock           => $packet->clock,
            ident           => 'arena.period',
            period          => $packet->update->[0],
            period_end      => $packet->update->[1],
            period_length   => $packet->update->[2] + 0.0,
            activities      => $packet->update->[3],
        });
        $self->arena_period($packet->update->[0]);
    } elsif($packet->update_type == 0x04) {
        # it's not actually the frag list, but statistics, but it only appears once
        $self->emit('setup.fraglist' => $packet->update);
        $self->emit('arena.statistics' => {
            clock   => $packet->clock,
            ident   => 'arena.statistics',
            stats   => $packet->update,
            });
    } elsif($packet->update_type == 0x05) {
        $self->emit('arena.vehicle_statistics' => {
            clock   => $packet->clock,
            ident   => 'arena.vehicle_statistics',
            id      => $packet->update->[0],
            kills   => $packet->update->[1],
        });
    } elsif($packet->update_type == 0x06) {
        my $evtdata = {
            id        => $packet->player_id,
            clock     => $packet->clock,
            ident     => 'arena.vehicle_killed',
            destroyed => $packet->update->[0],
            destroyer => $packet->update->[1],
            reason    => $packet->update->[2],
        };
        for('arena.vehicle_killed', 'player.tank.destroyed') {
            $self->emit($_ => $evtdata);
        }
    } elsif($packet->update_type == 0x07) {
        $self->emit('arena.avatar_ready' => {
            id          => $packet->update,
            clock       => $packet->clock,
            ident       => 'arena.avatar_ready',
        });
    } elsif($packet->update_type == 0x08) {
        my $evt = {
            ident               => 'arena.base_points',
            clock               => $packet->clock,
            id                  => $packet->player_id,
            team                => $packet->update->[0],
            baseID              => $packet->update->[1],
            points              => $packet->update->[2],
            capturingStopped    => $packet->update->[3],
        };
        $self->emit('arena.base_points' => $evt);
    } elsif($packet->update_type == 0x09) {
        # base captured
        $self->emit('arena.base_captured' => {
            ident       => 'arena.base_captured',
            clock       => $packet->clock,
            id          => $packet->player_id,
            baseID      => $packet->update->[1],
            team        => $packet->update->[0],
        });
    } elsif($packet->update_type == 0x0a) {
        $self->emit('arena.team_killer' => { id => $packet->update, clock => $packet->clock, ident => 'arena.team_killer' });
    } elsif($packet->update_type == 0x0b) {
        $self->emit('arena.vehicle_updated' => {
            id      =>  $packet->player_id,
            clock   =>  $packet->clock,
            update  =>  $packet->update,
            ident   =>  'arena.vehicle_updated',
        });
    }
}

1;
