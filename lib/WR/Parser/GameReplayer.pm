package WR::Parser::GameReplayer;
use Mojo::Base 'WR::Parser::Game';

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

    $self->statistics->{$p} ||= {};
    return $self->statistics->{$p}->{$k};
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

    return $self->personal->{$k};
}

sub add_handlers {
    my $self = shift;

    $self->SUPER::add_handlers();

    # here's some chintzy shit 
    $self->on('player.position' => sub {
        my ($self, $update) = (@_);

        $self->set_stat(
            $update->{id}, 
            'mileage', 
            $self->get_stat($update->{id}, 'mileage') + $update->{distance_t}
        );
        $self->set_pers('mileage' => $self->get_pers('mileage') + $update->{distance_t}) if($self->is_recorder($update->{id}));
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

    $self->on('player.tank.damaged' => sub {
        my ($self, $update) = (@_);
        my $done = $self->get_stat($update->{id}, 'h_last_delta') ;

        $self->set_stat($update->{source}, 'damageDealt', $self->get_stat($update->{source}, 'damageDealt') + $done);
        if($self->is_recorder($update->{source})) {
            $self->set_pers('damageDealt' => $self->get_pers('damageDealt') + $done);
            if(my $name = $self->player_name($update->{id})) {
                $self->bperf->{$name} ||= {};
                $self->bperf->{$name}->{damageDealt} += $done;
            }
        }
    });
}

1;
