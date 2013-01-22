package WR::Role::Process::Digest;
use Moose::Role;
use Try::Tiny qw/catch try/;
use Digest::MD5;

around 'process' => sub {
    my $orig = shift;
    my $self = shift;
    my $res  = $self->$orig;

    my $md5 = Digest::MD5->new();

    $md5->add($res->{player}->{name});
    $md5->add($res->{player}->{vehicle}->{full});

    foreach my $pid (keys(%{$res->{players}})) {
        $md5->add($res->{players}->{$pid}->{name});
        $md5->add($res->{vehicles}->{$pid}->{typeCompDescr});
    }

    $res->{replay_digest} = $md5->hexdigest;
    return $res;
};

no Moose::Role;
1;
