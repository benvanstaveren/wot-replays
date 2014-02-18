package WR::QuickDB;
use Mojo::Base '-base';

has data    => sub { [] };
has indexes => sub { {} };

sub index_for {
    my $self = shift;
    my $key  = shift;
    my $val  = shift;

    return $self->indexes->{$key}->{$val} if(defined($self->indexes->{$key}) && defined($self->indexes->{$key}->{$val}));

    my $i = 0;
    foreach my $doc (@{$self->data}) {
        if($doc->{$key} eq $val) {
            $self->indexes->{$key}->{$val} = $i;
            return $i;
        }
        $i++;
    }
}

sub get_multi {
    my $self = shift;
    my %args = (@_);
    my $c    = scalar(keys(%args));

    foreach my $doc (@{$self->data}) {
        my $m = 0;
        foreach my $key (keys(%args)) {
            next unless(defined($doc->{$key}));
            $m++ if($doc->{$key} eq $args{$key});
        }
        return $doc if($m == $c);
    }
    return undef;
}

sub all {
    my $self = shift;
    my $key  = shift;
    my $val  = shift;
    my @res  = ();

    foreach my $doc (@{$self->data}) {
        push(@res, $doc) if($doc->{$key} eq $val);
    }
    return @res;
}

sub get {
    my $self = shift;
    my $key  = shift;
    my $val  = shift;

    return $self->data->[$self->index_for($key, $val)];
}

1;
