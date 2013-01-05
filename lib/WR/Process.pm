package WR::Process;
use Moose;
use namespace::autoclean;
use boolean;
use WR::Parser;
use Try::Tiny qw/try catch/;

has 'file' => (is => 'ro', isa => 'Str');
has 'data' => (is => 'ro', isa => 'Str');

has 'db' => (is => 'ro', isa => 'MongoDB::Database', required => 1);

# this oughta come from a config file ;) 
has 'bf_key' => (is => 'ro', isa => 'Str');

has '_error' => (is => 'ro', isa => 'Maybe[Str]', required => 1, default => undef, writer => '_set_error', init_arg => undef);
has '_parser' => (is => 'ro', isa => 'WR::Parser', writer => '_set_parser', init_arg => undef, handles => [qw/is_complete/]);
has '_result' => (is => 'ro', isa => 'HashRef', writer => '_set_result', required => 1, default => sub { {} }, init_arg => undef);

has 'match_info' => (is => 'ro', isa => 'HashRef', writer => '_set_match_info', init_arg => undef);
has 'match_result' => (is => 'ro', isa => 'ArrayRef', writer => '_set_match_result', init_arg => undef);
has 'pickledata' => (is => 'ro', isa => 'HashRef', writer => '_set_pickledata', init_arg => undef);

# load order here is important, the roles are applied left to right, first role applied is the first level in the 'around' chain

with (
        'WR::Role::Process::PickleData',     # must be first, it inflates the pickle data for complete replays
        'WR::Role::Process::ExpandResult',   # must be second, it inflates some result values 
        'WR::Role::Process::ResolveServer',  # get player server
        'WR::Role::Process::Mastery',        # resolve heroes 
        'WR::Role::Process::Fittings',       # process vehicle fittings
        'WR::Role::Process::Platoon',        # process platoons
    );

sub error {
    my $self = shift;
    my $message = join(' ', @_);

    $self->_set_error($message);
    die '[process]: ', $message, "\n";
}

sub process {
    my $self = shift;
    my $lltrait = 'LL::File';

    my %args = (
        bf_key  => $self->bf_key,
    );

    if(defined($self->data)) {
        $args{data} = $self->data;
        $lltrait = 'LL::Memory';
    } elsif(defined($self->file)) {
        $args{file} = $self->file;
        $lltrait = 'LL::File';
    } else {
        die 'you must pass either a "file" or "data" parameter', "\n";
    }
    $args{traits} = [$lltrait, qw/Data::Decrypt Data::Reader Data::Attributes/];

    $self->_set_parser(try {
        return WR::Parser->new(%args);
    } catch {
        $self->error('unable to parse replay: ', $_);
    });

    warn 'number of blocks: ', $self->_parser->num_blocks, "\n";

    $self->_set_match_result($self->fuck_booleans($self->_parser->decode_block(2))) if($self->_parser->is_complete);

    my $match_info = { 
        %{$self->_parser->decode_block(1)},
    };
    my $vehicles = [];

    my $realv = ($self->_parser->is_complete) ? $self->match_result->[1] : $match_info->{vehicles};

    foreach my $vid (keys(%$realv)) {
        my $veh = $realv->{$vid};
        my ($v_c, $v_n) = split(/:/, $veh->{vehicleType}, 2);
        $veh->{vehicleType} = {
            name => $v_n,
            country => $v_c,
            full => $veh->{vehicleType},
        };
        my $data = { id => $vid, %$veh };
        if($self->_parser->is_complete) {
            $data->{frags} = (defined($self->match_result->[2]->{$vid}->{frags})) ? $self->match_result->[2]->{$vid}->{frags} + 0 : 0,
        } else {
            $data->{frags} = undef; 
            $data->{isAlive} = undef; 
        }
        push(@$vehicles, $data);
    }

    $match_info->{vehicles} = $vehicles;
    $self->_set_match_info($self->fuck_booleans($match_info));
    return $self->match_info;
}

sub fuck_booleans {
    my $self = shift;
    my $obj = shift;

    return $obj unless(ref($obj));

    if(ref($obj) eq 'ARRAY') {
        return [ map { $self->fuck_booleans($_) } @$obj ];
    } elsif(ref($obj) eq 'HASH') {
        foreach my $field (keys(%$obj)) {
            next unless(ref($obj->{$field}));
            if(ref($obj->{$field}) eq 'HASH') {
                $obj->{$field} = $self->fuck_booleans($obj->{$field});
            } elsif(ref($obj->{$field}) eq 'ARRAY') {
                my $t = [];
                push(@$t, $self->fuck_booleans($_)) for(@{$obj->{$field}});
                $obj->{$field} = $t;
            } elsif(ref($obj->{$field}) eq 'JSON::XS::Boolean') {
                $obj->{$field} = ($obj->{$field}) ? true : false;
            }
        }
        return $obj;
    }
}

__PACKAGE__->meta->make_immutable;
