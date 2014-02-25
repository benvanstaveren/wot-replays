package WR::Parser::Versions::v81100;
use Mojo::Base 'WR::Parser::Base';
use Try::Tiny qw/try catch/;

sub has_battle_result {
    my $self = shift;

    return ($self->num_blocks == 2) ? 1 : 0;
}

sub get_battle_result {
    my $self = shift;
    my $br;

    # these don't have a pickle, but the 2nd JSON block now contains the same data as the pickle used to (in theory)
    try {
        $br = $self->decode_block(2)->[0];
    } catch {
        $br = undef;
    };
    return $br;
}

1;
