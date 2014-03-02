package WR::Parser::Game;
use Mojo::Base 'WR::Parser::Game::Base';

has 'statistics' => sub { {} }; 
has 'personal'   => sub { {} };
has 'bperf'      => sub { {} };

sub set_stat {
    my $self = shift;
    my $p    = shift;
    my $k    = shift;
    my $v    = shift;

    $self->statistics->{$p} ||= {};
    $self->statistics->{$p}->{$k} = $v;
}

sub get_stat {
    my $self = shift;
    my $p    = shift;
    my $k    = shift;
    my $d    = shift;

    $self->statistics->{$p} ||= {};
    return (defined($self->statistics->{$p}->{$k})) ? $self->statistics->{$p}->{$k} : $d;
}

sub inc_stat {
    my $self = shift;
    my $p    = shift;
    my $k    = shift;
    my $v    = shift || 1;

    return unless(defined($v));

    $self->set_stat($p, $k, $self->get_stat($p, $k, 0) + $v);
}

sub set_pers {
    my $self = shift;
    my $k    = shift;
    my $v    = shift;

    $self->personal->{$k} = $v;
}

sub get_pers {
    my $self = shift;
    my $k    = shift;
    my $d    = shift;

    return (defined($self->personal->{$k})) ? $self->personal->{$k} : $d;
}

sub inc_pers {
    my $self = shift;
    my $k    = shift;
    my $v    = shift;

    return unless(defined($v));

    $self->set_pers($k, $self->get_pers($k, 0) + $v);
}

sub add_handlers {
    my $self = shift;

    # adds the low level stream -> useful event handlers
    $self->SUPER::add_handlers();

    # here's some chintzy shit 
    $self->on('player.position' => sub {
        my ($self, $update) = (@_);
        $self->inc_stat($update->{id}, 'mileage', $update->{distance_t});
        $self->inc_pers('mileage' => $update->{distance_t}) if($self->is_recorder($update->{id}));
    });

    # these things come in when damage occurs; if this happens followed by
    # a damage packet, the damage packet's health has already been set;
    # so keep a delta packet around in case
    $self->on('player.health' => sub {
        my ($self, $update) = (@_);

        if(my $th_prev = $self->get_stat($update->{id}, 'health')) {
            my $th_cur  = $update->{health};
            my $done    = $th_prev - $th_cur;
            $self->set_stat($update->{id}, 'h_last_delta', $done);
        }
        $self->set_stat($update->{id}, 'health', $update->{health});
    });

    $self->on('player.tank.destroyed' => sub {
        my ($self, $update) = (@_);

        $self->inc_stat($update->{destroyer}, 'kills', 1);
        if($self->is_recorder($update->{destroyer})) {
            $self->inc_pers('kills', 1);
            if(my $name = $self->player_name($update->{id})) {
                $self->bperf->{$name} ||= {};
                $self->bperf->{$name}->{killed} = 1;
            }
        }
    });

    $self->on('player.tank.damaged' => sub {
        my ($self, $update) = (@_);
        my $done = $self->get_stat($update->{id}, 'h_last_delta') ;

        $self->inc_stat($update->{source}, 'damageDealt', $done);
        if($self->is_recorder($update->{source})) {
            $self->inc_pers('damageDealt' => $done);
            if(my $name = $self->player_name($update->{id})) {
                $self->bperf->{$name} ||= {};
                $self->bperf->{$name}->{damageDealt} += $done if(defined($done));
            }
        }
    });
}

1;
