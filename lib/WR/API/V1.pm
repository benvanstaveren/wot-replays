package WR::API::V1;
use Mojo::Base 'Mojolicious::Controller';
use WR::Parser;
use WR::Util::PyPickle;
use WR::Process;
use WR::ServerFinder;
use WR::Res::Achievements;
use WR::Imager;
use boolean;
use Try::Tiny qw/try catch/;

sub token_valid {
    my $self = shift;
    my $t    = shift;

    if(my $rec = $self->model('wot-replays.api')->find_one({ _id => $t })) {
        return 1;
    } else {
        return undef;
    }
}

sub stringify_awards {
    my $self = shift;
    my $m_data = shift;
    my $a    = WR::Res::Achievements->new();
    my $t    = [];

    foreach my $item (@{$m_data->{statistics}->{dossierPopUps}}) {
        next unless($a->is_award($item->[0]));
        my $str = $a->index_to_idstr($item->[0]);
        $str .= $item->[1] if($a->is_class($item->[0]));
        push(@$t, $a->index_to_idstr($item->[0]));
    }
    return $t;
}

sub check_token {
    my $self = shift;
    my $t    = $self->req->param('t');

    # find out if the token is allowed to access and what the limits are
    if(my $rv = $self->token_valid($t)) {
        if($rv == -1) {
            # out of requests
            $self->render(json => { ok => 0, error => 'Request limit exceeded' }, status => 420);
        } else {
            return 1;
        }
    } else {
        # token's not valid so return the proper HTTP code as well
        $self->render(json => { ok => 0, error => 'Token Invalid' }, status => 401);
        return 0;
    }
}

sub fuck_boolean {
    my $self = shift;
    my $obj = shift;

    return $obj unless(ref($obj));

    if(ref($obj) eq 'ARRAY') {
        return [ map { $self->fuck_boolean($_) } @$obj ];
    } elsif(ref($obj) eq 'HASH') {
        foreach my $field (keys(%$obj)) {
            next unless(ref($obj->{$field}));
            if(ref($obj->{$field}) eq 'HASH') {
                $obj->{$field} = $self->fuck_boolean($obj->{$field});
            } elsif(ref($obj->{$field}) eq 'ARRAY') {
                my $t = [];
                push(@$t, $self->fuck_boolean($_)) for(@{$obj->{$field}});
                $obj->{$field} = $t;
            } elsif(boolean::isBoolean($obj->{$field})) {
                $obj->{$field} = ($obj->{$field}) ? Mojo::JSON->true : Mojo::JSON->false;
            }
        }
        return $obj;
    }
}

sub data {
    my $self = shift;
    my $type = $self->stash('type');

    if($type =~ /^(vehicles|equipment|components|consumables)$/) {
        my $m = sprintf('wot-replays.data.%s', $type);
        my $a = [ $self->model($m)->find()->all() ];
        $self->render(json => { ok => 1, data => $self->fuck_boolean($a) });
    } elsif($type eq 'players') {
        $self->render(json => { ok => 1, data => $self->fuck_boolean([ $self->model('wot-replays.cache.server_finder')->find()->all() ]) });
    } else {
        $self->render(json => { ok => 0, error => 'Invalid data type specified' });
    }
}

sub parse {
    my $self = shift;
    my $s    = ($self->req->param('ns')) ? 0 : 1;

    if(my $upload = $self->req->upload('replay')) {
        my $asset = $upload->asset;
        if(ref($asset) eq 'Mojo::File::Memory') {
            my $fileasset = Mojo::Asset::File->new();
            $fileasset->add_chunk($asset->slurp);
            $asset = $fileasset; # heh
        }

        my $p = WR::Process->new(
            file    => $asset->path,
            db      => $self->db('wot-replays'),
            bf_key  => $self->stash('config')->{wot}->{bf_key},
        );

        my $m_data;
        try {
            $m_data = $p->process();
        } catch {
            $self->render(json => { ok => 0, error => "[process]: $_" });
        };
        return unless(defined($m_data));

        my $filename = $upload->filename;
        $filename =~ s/.*\\//g if($filename =~ /\\/);
        $m_data->{file} = $filename;
        
        my $url = undef;


        if($s == 1) {
            unless($self->model('wot-replays.replays')->find_one({ replay_digest => $m_data->{replay_digest}})) {
                my $replay_file = sprintf('%s/%s', $self->stash('config')->{paths}->{replays}, $filename);
                $asset->move_to($replay_file);

                $self->model('wot-replays.replays')->save({
                    %$m_data,
                    site => {
                        description => undef,
                        uploaded_at => time(),
                        uploaded_by => undef,
                        from_wpa    => true,
                        visible     => true,
                    }
                });
                $url = sprintf('http://www.wot-replays.org/replay/%s.html', $m_data->{_id}->to_string);

                # do the image thing
                try {
                    my $pv = $m_data->{player}->{vehicle}->{full};
                    $pv =~ s/:/-/;

                    my $xp = $m_data->{statistics}->{xp};
                    if($m_data->{statistics}->{dailyXPFactor10} > 10) {
                        $xp .= sprintf(' (x%d)', $m_data->{statistics}->{dailyXPFactor10}/10);
                    }

                    my $i = WR::Imager->new();
                    $i->create(
                        map     => $m_data->{map}->{id},
                        vehicle => lc($pv),
                        result  => 
                            ($m_data->{game}->{isWin})
                                ? 'victory'
                                : ($m_data->{game}->{isDraw})
                                    ? 'draw'
                                    : 'defeat',
                        map_name     => $self->model('wot-replays.data.maps')->find_one({ _id => $m_data->{map}->{id} })->{label},
                        vehicle_name => $self->model('wot-replays.data.vehicles')->find_one({ _id => $m_data->{player}->{vehicle}->{full} })->{label},
                        credits => $m_data->{statistics}->{credits},
                        xp      => $xp,
                        kills   => $m_data->{statistics}->{kills},
                        spotted => $m_data->{statistics}->{spotted},
                        damaged => $m_data->{statistics}->{damaged},
                        player  => $m_data->{player}->{name},
                        clan    => $m_data->{player}->{clan},
                        destination => sprintf('%s/%s.png', $self->stash('config')->{paths}->{replays}, $m_data->{_id}->to_string),
                        awards  => $self->stringify_awards($m_data),
                    );
                } catch {
                    # nothing
                };
            }
        } else {
            $asset->cleanup;
        }
        my $data = {
            ok          =>  1,
            replay      =>  $self->fuck_boolean($m_data),
        };
        $data->{url} = $url if($s == 1 && defined($url));
        $self->render(json => $data);
    } else {
        $self->render(json => { ok => 0, error => 'No file passed' });
    }
}

1;
