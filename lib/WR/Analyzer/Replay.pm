package WR::Analyzer::Replay;
use Mojo::Base '-base';
use WR::Parser;

# this should be given a replay file
has 'file'          => undef;
has 'config'        => undef;

has 'packets'       => sub { [] };
has 'roster'        => sub { {} };
has 'scores'        => sub { {} }; 

sub name_by_vehicle_id { 
    my $self = shift;
    my $id   = shift;

    return $self->roster->{$id}->{name};
}

sub add_score {
    my $self  = shift;
    my $id    = shift;
    my $score = shift;

    $self->scores->{$self->name_by_vehicle_id($id)} += $score;
}

sub process {
    my $self = shift;

    

}

1;
