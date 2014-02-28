package WR::QuickDB;
use Mojo::Base '-base';

has data    => sub { [] };

sub index_for {
    my $self = shift;
    my $key  = shift;
    my $val  = shift;

    my $i = 0;
    foreach my $doc (@{$self->data}) {
        return $i if($doc->{$key} eq $val);
        $i++;
    }
    return undef;
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

    my $index = $self->index_for($key, $val);
    return (defined($index)) ? $self->data->[$index] : undef;
}

1;
