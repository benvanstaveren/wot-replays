package WR::Parser::Playback::WOT;
use Mojo::Base 'WR::Parser::Playback';
use WR::Util::VehicleDescriptor;
use WR::Util::TypeComp qw/parse_int_compact_descr type_id_to_name/;
use WR::Constants qw/nation_id_to_name/;

has 'map_done'  =>  0;
has 'recorder'  =>  sub { {} };
has [qw/vshells_initial vcons_initial/] => sub { {} };

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
        $self->vshells_initial->{$item} = {
            item => $tc,
            count => $count,
        } unless(defined($self->vshells_initial->{$item}));
    } elsif(type_id_to_name($tc->{type_id}) eq 'equipment') {
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
        $self->emit('setup.map' => $packet->space) if($self->map_done == 0); # seems we get 2 0x0b packets, one contains stuff and space, one just stuff (map constraints maybe)
        $self->map_done(1);
    }
}

sub onArenaInit {
    my $self   = shift;
    my $packet = shift;
    $self->emit('arena.initialize' => $packet->to_hash);
    $self->recorder->{name} = $packet->player_name;
}

sub onMinimapClicked {
    my $self   = shift;
    my $packet = shift;

    $self->emit('cell.attention' => { clock => $packet->clock, cell_id => $packet->cell_id, ident => 'cell.attention' });
}

sub onUpdatePosition {
    my $self = shift;
    my $packet = shift;

    my $update = {
        id              => $packet->player_id,
        position        => $packet->position,
        clock           => $packet->clock,
        orientation     => $packet->hull_orientation,
        ident           => 'player.position',
    };
    $self->emit('player.position' => $update);
}

sub onArenaHandler {
    my $self    = shift;
    my $packet  = shift;

    if($packet->update_type == 0x01) {
        my $roster = $packet->update;
        my $new    = [];

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

            push(@$new, $h);

            if($h->{name} eq $self->recorder->{name}) {
                $self->emit('recorder.id' => $h->{vehicleID}); 
                $self->emit('recorder.account_id' => $h->{accountDBID});
            }
        }

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

        if($h->{name} eq $self->recorder->{name}) {
            $self->emit('recorder.id' => $h->{vehicleID});
            $self->emit('recorder.account_id' => $h->{accountDBID});
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
    } elsif($packet->update_type == 0x04) {
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

sub add_handlers {
    my $self = shift;

    $self->add_handler(0x00 => sub { shift->onArenaInit(@_) });
    $self->add_handler(0x0a => sub { shift->onUpdatePosition(@_) });
    $self->add_handler(0x0b => sub { shift->onSpaceInit(@_) });
    $self->add_handler(0x21 => sub { shift->onMinimapClicked(shift) });

    $self->add_handler(0x08 => sub {
        my $self   = shift;
        my $packet = shift;

        # these seem to always appear under subtype 29 (1d) (?)
        if(
            ($self->version < 80900 && $packet->subtype == 0x1a) ||
            ($self->version >= 80900 && $packet->subtype == 0x1d) ||
            ($self->version >= 90300 && $packet->subtype == 0x1e)
        ) {
            $self->onArenaHandler($packet);
        } elsif(
            ($self->version < 80900 && $packet->subtype == 0x0a) ||
            ($self->version >= 80900 && $packet->subtype == 0x09)
        ) {
            $self->onSlotChange($packet);
        } elsif($packet->subtype == 0x01) {
            $self->onDamageReceived($packet);
        }
    });

    $self->add_handler(0x1f => sub { shift->onChat(@_) });

    $self->add_handler(0x07 => sub {
        my $self = shift;
        my $packet = shift;

        if($packet->subtype == 0x03) {
            $self->emit('player.health' => { 
                ident   => 'player.health',
                id      => $packet->player_id, 
                health  => $packet->health,
                clock   => $packet->clock,
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

1;
