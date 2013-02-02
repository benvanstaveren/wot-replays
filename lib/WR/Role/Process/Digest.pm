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

    foreach my $vid (keys(%{$res->{vehicles}})) {
        next unless(defined($res->{vehicles}->{$vid}->{name}));
        $md5->add($res->{vehicles}->{$vid}->{name});
        $md5->add($res->{vehicles}->{$vid}->{typeCompDescr});
    }

    $md5->add($res->{map}->{id});

    $res->{replay_digest} = $md5->hexdigest;
    return $res;
};

no Moose::Role;
1;
