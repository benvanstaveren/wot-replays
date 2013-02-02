package WR::Role::Process::InteractionDetails;
use Moose::Role;
use boolean;
use WR::Util::InteractionDetails;

around 'process' => sub {
    my $orig = shift;
    my $self = shift;
    my $res  = $self->$orig;

    return $res unless($self->_parser->is_complete);

    # the vehicle hash contains it all
    foreach my $vid (keys(%{$res->{vehicles}})) {
        next unless(defined($res->{vehicles}->{$vid}->{details}));

        my $interactiondetails = WR::Util::InteractionDetails->new(data => $res->{vehicles}->{$vid}->{details});
        $res->{vehicles}->{$vid}->{details} = $interactiondetails->dict;
    }
    return $res;
};

no Moose::Role;
1;
