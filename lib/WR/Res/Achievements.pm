package WR::Res::Achievements;
use Mojo::Base '-base';
use Mojo::JSON;
use File::Slurp qw/read_file/;
use Data::Dumper;

has 'path' => sub {
    my $self = shift;

    # yes, this is still ghetto as all fuck
    return (-e '/home/ben/projects/wot-replays/site')
        ? '/home/ben/projects/wot-replays/site/etc/res'
        : '/home/wotreplay/wot-replays/site/etc/res';
};


has achievements                => sub { [] };
has achievements_reverse        => sub { {} };
has achievements_by_type        => sub {
    my $self = shift;
    my $h    = [];
    my $i    = 0;

    foreach my $a (@{$self->achievements}) {
        next unless(defined($a));
        $h->[$i++] = $a->{type};
    }
    return $h;
};
has achievements_by_group       => sub {
    my $self = shift;
    my $h    = [];
    my $i    = 0;

    foreach my $a (@{$self->achievements}) {
        next unless(defined($a) && defined($a->{group}));
        $h->[$i++] = $a->{group};
    }
    return $h;
};

sub new {
    my $package = shift;
    my $self    = $package->SUPER::new(@_);
    
    bless($self, $package);

    my $groups = Mojo::JSON->new->decode(read_file(sprintf('%s/achievementgroups.json', $self->path)));
    my $achievements = Mojo::JSON->new->decode(read_file(sprintf('%s/achievements.json', $self->path)));
    my $types = {};
    foreach my $idx (keys(%$achievements)) {
        next if($achievements->{$idx}->[0] !~ /^achievement/);
        my $name = $achievements->{$idx}->[1];

        my $type = $groups->{$name}->{type};
        my $sec  = $groups->{$name}->{section};

        $self->achievements->[$idx] = {
            name    => $name,
            type    => $type,
            section => $sec,
        };
        $self->achievements_reverse->{$name} = $idx;
        $types->{$type}++ if(defined($type) && length($type) > 0);
    }

    foreach my $t (keys(%$types)) {
        no strict 'refs';
        *{"${package}::is_${t}"} = sub {
            my ($self, $idx) = (@_);
            return ($self->achievements->[$idx]->{type} eq $t) ? 1 : 0;
        } unless($package->can("is_${t}"));
        use strict 'refs';
    }

    return $self;
}

sub is_battle {
    my $self = shift;
    my $idx  = shift;

    return ($self->is_award($idx) && $self->achievements->[$idx]->{section} eq 'battle') ? 1 : 0;
}

sub is_award {
    my $self = shift;
    my $idx  = shift;

    return (defined($self->achievements->[$idx])) 
        ? 1 
        : 0
    ;
}

sub index_to_idstr {
    my $self = shift;
    my $idx  = shift;
    
    $idx += 0;

    return (defined($self->achievements->[$idx])) ? $self->achievements->[$idx]->{name} : 'no_' .$idx;
}

1;
