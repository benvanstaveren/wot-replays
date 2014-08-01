package WR::Parser::Versions::v80600;
use Mojo::Base 'WR::Parser::Versions::default';
use Try::Tiny qw/try catch/;

sub has_battle_result {
    my $self = shift;

    return ($self->num_blocks == 2) ? 1 : 0;
}

sub _fix_br_values {
    my $self = shift;
    my $br   = shift;

    return $br unless(defined($br));

    if(ref($br) eq 'HASH') {
        foreach my $key (keys(%$br)) {
            if(ref($br->{$key}) eq 'HASH') {
                $self->_fix_br_values($br->{$key});
            } elsif(ref($br->{$key}) eq 'ARRAY') {
                my $new = [];
                foreach my $e (@{$br->{$key}}) {
                    push(@$new, $self->_fix_br_values($e));
                }
                $br->{$key} = $new;
            } elsif($br->{$key} =~ /^\d+$/) {
                $br->{$key} += 0;
            }
        }
    } elsif(ref($br) eq 'ARRAY') {
        my $new = [];
        foreach my $e (@$br) {
            push(@$new, $self->_fix_br_values($e));
        }
        $br = $new;
    } elsif($br =~ /^\d+$/) {
        $br += 0;
    } elsif($br =~ /^\d+\.\d+$/) {
        # float..
        $br += 0.0;
    }
    return $br;
}

sub get_battle_result {
    my $self = shift;
    my $br;

    # these don't have a pickle, but the 2nd JSON block now contains the same data as the pickle used to (in theory)
    # unfortunately, there's a lot of data in here that's numeric but gets "understood" as a string,
    # so we want to fix that
    try {
        $br = $self->decode_block(2)->[0];
    } catch {
        $br = undef;
    };

    $self->_fix_br_values($br);

    $br->{arenaUniqueID} .= '';

    return $br;
}

1;
