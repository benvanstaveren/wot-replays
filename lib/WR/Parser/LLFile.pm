package WR::Parser::LLFile;
use strict;
use Moose;
use namespace::autoclean;
use IO::File;

has 'file' => (is => 'ro', isa => 'Str', required => 1);
has 'fh' => (is => 'ro', isa => 'IO::File', lazy => 1, required => 1, builder => '_build_fh');

has 'num_blocks' => (is => 'ro', isa => 'Num', required => 1, default => 0, writer => '_set_num_blocks', init_arg => undef);
has 'block_meta' => (is => 'ro', isa => 'ArrayRef', required => 1, default => sub { [] }, writer => '_set_block_meta', init_arg => undef);
has 'blocks' => (is => 'ro', isa => 'ArrayRef', required => 1, default => sub { [] }, init_arg => undef);
has '_rest' => (is => 'ro', isa => 'Num', required => 1, default => 0, writer => '_set_rest', init_arg => undef);

use constant SEEK_SET => 0;
use constant SEEK_CUR => 1;
use constant SEEK_END => 2;
use constant REPLAY_START_POS => 8;

sub _build_fh {
    my $self = shift;
    my $fh =  IO::File->new($self->file);
    $fh->binmode(1);
    return $fh;
}

sub complete { 
    return (shift->num_blocks <= 1) ? 0 : 1;
}

sub BUILD {
    my $self = shift;

    $self->fh->seek(4, SEEK_SET);
    $self->fh->read(my $blockheader, 4) || die '[header]: could not read replay header', "\n";
    $self->_set_num_blocks(unpack('I', $blockheader));

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
    $self->_set_block_meta($block_meta);
    $self->_set_rest($start_pointer);
}

sub save_data {
    my $self = shift;
    my %args = (to => undef, @_);

    die 'must pass a "to" parameter', "\n" unless($args{to});
    if(my $fh = IO::File->new(sprintf('>%s', $args{to}))) {
        $fh->binmode(1);
        $self->fh->seek($self->_rest, SEEK_SET);
        my $buffer;
        while(my $bread = $self->fh->read($buffer, 1024)) {
            $fh->write($buffer);
        }
        $fh->close();
        return 1;
    } else {
        die 'failed to save: ', $!, "\n";
    }
}

sub get_block {
    my $self = shift;
    my $block = shift;

    die '[get_block]: block index out of bounds', "\n" if($block > $self->num_blocks || $block < 1);

    return $self->blocks->[$block - 1] if(defined($self->blocks->[$block - 1]));

    my $bm = $self->block_meta->[$block - 1 ];

    $self->fh->seek($bm->{pointer}, SEEK_SET);
    $self->fh->read(my $block, $bm->{length}) || die '[get_block]: could not read block', "\n";
    $self->blocks->[$block - 1] = $block;
    return $block;
}

sub DEMOLISH {
    my $self = shift;

    $self->fh->close();
}

__PACKAGE__->meta->make_immutable;
