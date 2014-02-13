package WR::Parser::Base;
use Mojo::Base '-base';
use IO::File ();
use Digest::SHA1 qw/sha1_hex/;
use Try::Tiny qw/try catch/;
use boolean;
use Data::Dumper;
use JSON::XS;
use WR::Parser::Unpack;
use WR::Parser::Stream;
use WR::Parser::Game;
use WR::Util::PyPickle;

has 'file' => undef;
has 'fh'   => sub {
    my $self = shift;
    my $fh   = IO::File->new($self->file);

    die 'could not open file: "', $self->file, '": ', $!, "\n" unless($fh);

    $fh->binmode(1);
    return $fh;
};

has 'num_blocks'        => 0;
has 'block_meta'        => sub { [] };
has 'blocks'            => sub { [] };
has 'data_offset'       => 0;
has 'pickle_block'      => 3;
has '_decoded_blocks'   => sub { [] };
has '_battle_result'    => undef;
has 'bf_key'            => undef;

has 'debug'             => 0;
has 'version'           => 0;

use constant SEEK_SET => 0;
use constant SEEK_CUR => 1;
use constant SEEK_END => 2;
use constant REPLAY_START_POS => 8;

sub decode_block {
    my $self = shift;
    my $block = shift;

    return $self->_decoded_blocks->[$block] if(defined($self->_decoded_blocks->[$block]));

    if(my $d = $self->get_block($block)) {
        $self->_decoded_blocks->[$block] = JSON::XS->new()->decode($d);
        return $self->_decoded_blocks->[$block]; 
    } else {
        return undef;
    }
}

sub new {
    my $package = shift;
    my $self = $package->SUPER::new(@_);
    bless($self, $package);

    die 'You must pass a "file" parameter', "\n" unless(defined($self->file));

    return $self->BUILD;
}

sub BUILD {
    my $self = shift;

    $self->fh->seek(4, SEEK_SET);
    $self->fh->read(my $blockheader, 4) || die '[header]: could not read replay header', "\n";
    $self->num_blocks(unpack('I', $blockheader));

    $self->pickle_block($self->num_blocks) if($self->num_blocks >= 2);

    my $block_meta = [];
    my $i = $self->num_blocks;
    my $start_pointer = REPLAY_START_POS;

    while($i > 0) {
        my $m = {};
        $self->fh->seek($start_pointer, SEEK_SET);
        $self->fh->read(my $blocklen, 4) || die '[block]: could not read block length', "\n";
        $m->{length} = unpack('L', $blocklen);
        $m->{pointer} = $start_pointer + 4;
        $start_pointer = $m->{pointer} + $m->{length};
        push(@$block_meta, $m);
        $i--;
    }
    $self->block_meta($block_meta);
    $self->data_offset($start_pointer);
    return $self;
}

sub get_data {
    my $self = shift;

    my $out = IO::String->new();
    $out->binmode(1);
    $self->fh->seek($self->data_offset, SEEK_SET);
    while($self->fh->read(my $buf, 1024)) {
        $out->write($buf);
    }
    return $out;
}

sub unpack {
    my $self = shift;

    my $u = WR::Parser::Unpack->new(fh => $self->get_data, bf_key => $self->bf_key);
    return $u->unpack;
}

sub stream {
    my $self = shift;
    my %args = (@_);

    my $stream = WR::Parser::Stream->new(fh => $self->unpack);
    return $stream;
}

sub game {
    my $self = shift;

    my $game = WR::Parser::Game->new(stream => $self->stream);
    return $game;
}

sub get_block {
    my $self = shift;
    my $block = shift;

    die '[get_block]: block index (', $block, ') out of bounds', "\n" if($block > $self->num_blocks || $block < 1);

    return $self->blocks->[$block - 1] if(defined($self->blocks->[$block - 1]));

    my $bm = $self->block_meta->[$block - 1 ];

    $self->fh->seek($bm->{pointer}, SEEK_SET);
    $self->fh->read(my $blockdata, $bm->{length}) || die '[get_block]: could not read block', "\n";
    $self->blocks->[$block - 1] = $blockdata;

    return $self->blocks->[$block -1 ];
}

sub has_battle_result {
    my $self = shift;
    my $rv = 0;

    warn 'base has_battle_result', "\n";

    try {
        $self->get_battle_result;
        $rv = 1;
    } catch {
        warn 'err: ', $_, "\n";
    };

    return $rv;
}

sub get_battle_result {
    my $self = shift;

    return $self->_battle_result if(defined($self->_battle_result));
    my $p = WR::Util::PyPickle->new(data => $self->get_block($self->pickle_block));
    try {
        $self->_battle_result($p->unpickle);
    };
    return $self->_battle_result;
}

sub DESTROY {
    my $self = shift;
    $self->fh->close if(defined($self->fh));
};

1;
