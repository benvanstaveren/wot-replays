package WR::Parser::LL;
use strict;
use Moose;
use namespace::autoclean;
use IO::String;

=pod

=head1 ABSTRACT

This module is used as a low-level block parser for the WoT replay file, it 
doesn't do much in the way of encoding or decoding, but just reads chunks.

At the moment it reads them from a string buffer, but eventually Moose roles will
determine what we read from, whether it's a string buffer or a real file handle. 

=head1 SYNOPSIS
    
    my $ll_parser = WR::Parser::LL->new(data => $raw_data_from_replay_file)

=head1 METHODS/PROPERTIES

=head2 num_blocks

Returns the number of data blocks found in the file. A complete replay has 2 data blocks.

=head2 complete

Returns true or false depending on whether the replay is complete

=head2 block_meta

Returns an arrayref containing block meta information. Each item is a hashref with two keys, pointer and length. Pointer is the offset within the replay file where the block starts, and length is the size in bytes of the block

=head2 blocks

Returns an arrayref containing the raw block data for each data block

=head2 get_block($block_number)

Shortcut to get the data blocks. The block number starts at 1.

=head1 COPYRIGHT

This module was written by Scrambled <scrambled@xirinet.com> and is released under a "do whatever you want with it" license.

=cut


has 'data' => (is => 'ro', isa => 'Str', required => 1);

has 'buf'  => (is => 'ro', isa => 'IO::String', required => 1, builder => '_build_buf', lazy => 1, init_arg => undef);
has 'num_blocks' => (is => 'ro', isa => 'Num', required => 1, default => 0, writer => '_set_num_blocks', init_arg => undef);
has 'block_meta' => (is => 'ro', isa => 'ArrayRef', required => 1, default => sub { [] }, writer => '_set_block_meta', init_arg => undef);
has 'blocks' => (is => 'ro', isa => 'ArrayRef', required => 1, default => sub { [] }, init_arg => undef);

has '_rest' => (is => 'ro', isa => 'Num', required => 1, default => 0, init_arg => undef, writer => '_set_rest');

use constant SEEK_SET => 0;
use constant SEEK_CUR => 1;
use constant SEEK_END => 2;

use constant REPLAY_START_POS => 8;

sub _build_buf {
    my $self = shift;
    my $str =  IO::String->new($self->data);
    $str->binmode(1);
    return $str;
}

sub get_block {
    my $self = shift;
    my $block = shift;

    return $self->blocks->[$block - 1];
}

sub complete { 
    return (shift->num_blocks <= 1) ? 0 : 1;
}

sub BUILD {
    my $self = shift;

    $self->buf->seek(4, SEEK_SET);
    $self->buf->read(my $blockheader, 4) || die '[header]: could not read replay header', "\n";
    $self->_set_num_blocks(unpack('I*', $blockheader));

    my $block_meta = [];
    my $i = $self->num_blocks;
    my $start_pointer = REPLAY_START_POS;

    while($i > 0) {
        my $m = {};
        $self->buf->seek($start_pointer, SEEK_SET);
        $self->buf->read(my $blocklen, 4) || die '[block]: could not read block length', "\n";
        $m->{length} = unpack('L*', $blocklen);
        $m->{pointer} = $start_pointer + 4;
        $start_pointer = $m->{pointer} + $m->{length};
        push(@$block_meta, $m);
        $i--;
    }
    $self->_set_block_meta($block_meta);
    $self->_set_rest($start_pointer);


    $i = 0;
    foreach my $bm (@$block_meta) {
        $self->buf->seek($bm->{pointer}, SEEK_SET);
        $self->buf->read(my $block, $bm->{length}) || die '[block]: could not read block', "\n";
        $self->blocks->[$i++] = $block;
    }
}

sub DEMOLISH {
    my $self = shift;

    $self->buf->close();
}

__PACKAGE__->meta->make_immutable;
