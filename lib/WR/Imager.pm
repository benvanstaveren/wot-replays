package WR::Imager;
use Moose;
use Imager;

has '_path' => (is => 'ro', isa => 'Str', required => 1, builder => '_build_path', lazy => 1);
has '_bg'   => (is => 'ro', isa => 'Imager', builder => '_build_bg', required => 1, lazy => 1);
has '_overlay' => (is => 'ro', isa => 'Imager', builder => '_build_overlay', required => 1, lazy => 1);
has '_text' => (is => 'ro', isa => 'ArrayRef', writer => '_set_text');

sub BUILD {
    my $self = shift;

    $self->_path;

    $self->_set_text([
        {
            'text' => 'result',
        },
        {
            'text' => 'xp',
        },
        {
            'text' => 'credits',
        },
        {
            'text' => 'spotted',
        },
        {
            'text' => 'damaged',
        },
        {
            'text' => 'killed',
        },
        {
            'text' => 'survived',
        },
        {
            'text' => 'server',
        },
        {
            'text' => 'version',
        },
    ]);
}

sub _build_path {
    my $self = shift;

    return (-e '/home/ben') 
        ? '/home/ben/projects/wot-replays/sites/images.wot-replays.org'
        : '/home/wotreplay/wot-replays/sites/images.wot-replays.org'
        ;
}

sub _build_overlay {
    my $self = shift;

    my $overlay = Imager->new();
    $overlay->read(file => sprintf('%s/mapscreen/overlay.png', $self->_path)) or die 'failed reading overlay', "\n";
    return $overlay;
}

sub _build_bg {
    my $self    = shift;
    my $background = Imager->new(xsize => 720, ysize => 98, channels => 4);

    $background->box(filled => 1, color => 'black') or die 'failed creating background', "\n";
    return $background;
}

sub create {
    my $self = shift;
    my %args = (@_);

    # map will be the ID of the map we want to use so we can read the mapscreen
    my $mapscreen = Imager->new();
    my $vehicle = Imager->new();

    $mapscreen->read(file => sprintf('%s/mapscreen/%s.png', $self->_path, $args{map})) or die 'failed reading mapscreen from: ', sprintf('%s/mapscreen/%s.png', $self->_path, $args{map}), ': ', $mapscreen->errstr, "\n";
    $vehicle->read(file => sprintf('%s/vehicles/100/%s.png', $self->_path, $args{vehicle})) or die 'failed reading vehicle', "\n";

    $self->_bg->rubthrough(top => 0, left => 0, src => $mapscreen);
    $self->_bg->rubthrough(top => 0, left => 0, src => $self->_overlay);
    $self->_bg->rubthrough(top => 0, left => 78, src => $vehicle);

    my $lc = Imager::Color->new(128, 128, 128);
    $self->_bg->line(color => $lc, x1 => 235, x2 => 460, y1 => 26, y2 => 26);




    $self->_bg->write(file => '/tmp/replay.png');
}

__PACKAGE__->meta->make_immutable;
