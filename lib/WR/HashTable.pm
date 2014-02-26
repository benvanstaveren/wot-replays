package WR::HashTable;
use Mojo::Base '-base';

has 'data' => sub { {} };

has '_ex' => sub { {} };

sub _export_as_path {
    my $self = shift;
    my $root = shift;
    my $hash = shift;

    foreach my $key (keys(%{$hash})) {
        if(!ref($hash->{$key})) {
            $self->_ex->{sprintf('%s%s%s', $root, (defined($root)) ? '.' : '', $key)} = $hash->{$key};
        } else {
            $self->_export_as_path(sprintf('%s%s%s', $root, (defined($root)) ? '.' : '', $key) => $hash->{$key});
        }
    }
}

sub export {
    my $self = shift;

    $self->_ex({});
    $self->_export_as_path(undef, $self->data);
    return { %{$self->_ex()} };
}

sub slice {
    my $self   = shift;
    my $fields = shift; # arrayref of fields we want to extract

    if(ref($self->data) eq 'HASH') {
        my %rec = ();
        foreach my $path (@$fields) {
            if(my $value = $self->path($path)) {
                $self->set_path($path, $value, \%rec);
            } else {
                return undef;
            }
        }
        return \%rec;
    } elsif(ref($self->data) eq 'ARRAY') {
        my @rec = ();
        foreach my $e (@{$self->data}) {
            my %rec = ();
            foreach my $path (@$fields) {
                if(my $value = $self->path($path => $e)) {
                    $self->set_path($path, $value, \%rec);
                } else {
                    return undef;
                }
            }
            push(@rec, \%rec);
        }
        return \@rec;
    }
}

sub delete {
    my $self  = shift;
    my $path  = shift;
    my $_root = shift || $self->data;

    return undef if(!defined($_root));

    my $root  = { %{$_root} };

    return undef unless(defined($root) && scalar(keys(%$root)) > 0);

    my @comps = split(/\./, $path);
    my $last  = pop(@comps);

    while(my $c = shift(@comps)) {
        if(defined($root) && ref($root) eq 'HASH') {
            $root = $root->{$c};
        } else {
            $root = undef;
        }
    }

    if(scalar(@comps)>0) {
        return undef;
    } else {
        delete($root->{$last});
    }
}

sub set { return shift->set_path(@_) }
sub set_path {
    my $self  = shift;
    my $path  = shift;
    my $value = shift;
    my $hash  = shift || $self->data;

    my @comps = split(/\./, $path);

    my $last = pop(@comps);
    while(my $c = shift(@comps)) {
        $hash->{$c} ||= {};
        $hash = $hash->{$c};
    }
    $hash->{$last} = $value;
}

sub append {
    my $self = shift;
    my $path = shift;
    my $what = shift;
    
    my $a = $self->get($path) || [];
    push(@$a, $what);
    $self->set($path => $a);
}

sub get { return shift->path(@_) }
sub path {
    my $self  = shift;
    my $path  = shift;
    my $_root = shift || $self->data;

    return undef if(!defined($_root));

    my $root  = { %{$_root} };

    return undef unless(defined($root) && scalar(keys(%$root)) > 0);

    my @comps = split(/\./, $path);

    while(my $c = shift(@comps)) {
        if(defined($root) && ref($root) eq 'HASH') {
            $root = $root->{$c};
        } else {
            $root = undef;
        }
    }

    if(scalar(@comps)>0) {
        return undef;
    } else {
        return $root;
    }
}

1;
