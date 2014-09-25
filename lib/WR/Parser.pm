package WR::Parser;
use Mojo::Base 'WR::Bigworld::Replay::File';
use Module::Load qw/load/;
use Try::Tiny qw/try catch/;
use Data::Dumper qw/Dumper/;

has 'meta'      =>  undef;
has 'type'      =>  undef;
has 'version'   =>  undef;

our @ISA;

sub version_wot_numeric {
    my $self = shift;
    my $v    = shift;
    # you would imagine that a simple , separator would work, but... WG managed to have 
    # this fuck up in 0.9.0 for some reason so... 

    my @ver = split(/\,/, $v);
    my @wgfix = ();
    while(@ver) {
        my $a = shift(@ver);
        $a =~ s/^\s+//g;
        $a =~ s/\s+$//g; 
        if($a =~ /\s+/) {
            push(@wgfix, (split(/\s+/, $a)));
        } else {
            push(@wgfix, $a);
        }
    }
    return $wgfix[0] * 1000000 + $wgfix[1] * 10000 + $wgfix[2] * 100 + $wgfix[3];
}

sub version_wowp_numeric {
    my $self = shift;
    my $str  = shift;

    $str =~ s/\s+$//g;

    if($str =~ /(\d+)\.(\d+)\.(\d+)$/) {
        my $major = $1;
        my $minor = $2;
        my $rev   = $3;
        
        return ($major * 1000000) + ($minor * 10000) + ($rev * 100);
    } else {
        die 'Possible malformed World of Warplanes version string (', $str, '): could not determine version', "\n";
    }
}

sub alter_isa {
    my $self    = shift;
    my $version = shift;

    my $isa_module = sprintf('WR::Parser::%s::%s', uc($self->type), $version);
    try {
        load($isa_module);
    } catch {
        die 'Could not load parser module for ', $self->type, ' from ', $isa_module, "\n\t", $_, "\n"; #, 'Meta block: ', Dumper($self->meta), "\n";
    };
    our @ISA = ( 'WR::Bigworld::Replay::File', $isa_module ); # clobber the fuck out of that
}

sub new {
    my $package = shift;
    my $self    = $package->SUPER::new(@_);

    bless($self, $package);

    try {
        $self->meta($self->decode_block(1));
    } catch {
        die 'Could not read meta block', "\n";
    };

    if(defined($self->meta->{clientVersionFromExe})) {
        $self->type('wot');
        $self->version($self->version_wot_numeric($self->meta->{clientVersionFromExe}));
    } elsif(defined($self->meta->{clientVersion})) {
        $self->type('wowp');
        $self->version($self->version_wowp_numeric($self->meta->{clientVersion}));
    } else {
        # it must be an (old)er version of world of tanks, we'll sort that out later
        $self->type('wot');
        $self->version(-1);
    }

    my $version = ($self->version == -1) ? 'default' : sprintf('v%d', $self->version);

    $self->alter_isa($version);

    if($version ne 'default') {
        $self->debug('Instantiating self with @ISA: ', Dumper([@ISA]));
        return $self;
    }

    # go see if we can lift the version from the replay
    if($self->upgrade) {
        # the version can be had from the first packet in the stream
        my $stream  = $self->stream;
        $stream->scan([0x14] => sub {
            my ($stream, $packet) = (@_);
            $self->version($packet->version);
            $version = sprintf('v%d', $packet->version);
            return undef; # stop scanning 
        });
        $self->alter_isa($version) if($version ne 'default');
    }
    return $self;
}

1;
