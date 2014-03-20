package WR::App::Controller::Statistics::Mastery;
use Mojo::Base 'WR::App::Controller';
use Mango::BSON;

sub _generate_mastery_data {
    my $self = shift;
    my $cb   = shift;

    # only do this if the mastery data is out of date; updates once a day
    $self->model('wot-replays.statistics')->find_one({ _id => 'mastery' } => sub {
        my ($c, $e, $d) = (@_);
        my $refresh = 0;

        if(!defined($d)) {
            $refresh = 1;
        } elsif(defined($d) && $d->{last_update} + 86400 < time()) {
            $refresh = 1;
        } elsif(defined($e)) {
            $refresh = 1;
        } else {
            return $cb->();
        }

        # only use last week's battles
        my $query = {
            'game.started' => { '$gte' => Mango::BSON::bson_time((time() - (86400 * 7)) * 1000) },
        };

        my $tstats = {};

        my $cursor = $self->model('wot-replays.replays')->find($query)->fields({ stats => 1, 'game.recorder' => 1});
        while(my $replay = $cursor->next()) {
            foreach my $popup (@{$replay->{stats}->{dossierPopUps}}) {
                if($popup->[0] == 79) {
                    # 79 is the ID for markOfMastery, popup->[1] contains the level
                    my $level = $popup->[1];
                    my $xp    = $replay->{stats}->{originalXP};
                    my $vid   = $replay->{game}->{recorder}->{vehicle}->{ident};

                    $tstats->{$vid} ||= [];
                    if(!defined($tstats->{$vid}->[$level])) {
                        $tstats->{$vid}->[$level] = $xp;
                    } elsif($xp < $tstats->{$vid}->[$level]) {
                        $tstats->{$vid}->[$level] = $xp;
                    }
                }
            }
        }

        return $cb->() if(scalar(keys(%$tstats)) < 1);

        my $delay = Mojo::IOLoop->delay(sub {
            return $cb->();
        });

        foreach my $vid (keys(%$tstats)) {
            my $end = $delay->begin(0);
            $self->model('wot-replays.statistics_mastery')->save({
                _id     => $vid,
                mastery => $tstats->{$vid}
            } => sub { $end->() });
        }

        my $uend = $delay->begin(0);
        $self->model('wot-replays.statistics')->save({ _id => 'mastery', last_update => time() } => sub { $uend->() });
    });
}

sub index {
    my $self = shift;

    $self->render_later;
    $self->_generate_mastery_data(sub {
        $self->model('wot-replays.statistics_mastery')->find()->all(sub {
            my ($c, $e, $d) = (@_);

            # sort the list based on the actual vehicle name
            my $vd = {};
            foreach my $doc (@$d) {
                my $name = $self->loc($self->vehicle_name($doc->{_id}));
                $vd->{$name} = $doc->{mastery};
            }

            my $list = [];
            foreach my $name (sort { $a cmp $b } (keys(%$vd))) {
                push(@$list, { name => $name, mastery => $vd-{$name} });
            }
                
            $self->respond(template => 'statistics/mastery', stash => {
                page        => { title => 'statistics.mastery.page.title' },
                mastery     => $list
            });
        });
    });
}

1;
