package WR::Bigworld::Replay::File;
use Mojo::Base '-base';
use IO::File ();
use Try::Tiny qw/try catch/;
use Data::Dumper;
use Mojo::JSON;
use WR::Bigworld::Replay::Unpack;

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
has '_decoded_blocks'   => sub { [] };

# assume we can, at the very least, use self->debug 

use constant SEEK_SET => 0;
use constant SEEK_CUR => 1;
use constant SEEK_END => 2;
use constant REPLAY_START_POS => 8;

sub decode_block {
    my $self = shift;
    my $block = shift;

    if(my $d = $self->get_block($block)) {
        return Mojo::JSON->new()->decode($d);
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

    warn 'BUILD: have ', $self->num_blocks, ' blocks in file', "\n";

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

sub DESTROY {
    my $self = shift;
    $self->fh->close if(defined($self->fh));
};

1;
