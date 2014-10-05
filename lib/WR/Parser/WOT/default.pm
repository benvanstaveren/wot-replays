package WR::Parser::WOT::default;
use Mojo::Base 'WR::Parser::WOT::Base';
use Try::Tiny qw/try catch/;
use WR::Util::Pickle qw//;

sub can_playback { return 0 }

sub has_battle_result {
    my $self = shift;

    return ($self->num_blocks == 2) ? 1 : 0;
}

sub get_battle_result { return shift->decode_block(2) }

1;
