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
            'x'    => 235,
            'y'    => 40,
        },
        {
            'text' => 'xp',
            'y'    => 40,
            'x'    => 315,
        },
        {
            'text' => 'credits',
            'y'    => 40,
            'x'    => 410,
        },
        {
            'text' => 'spotted',
            'x'    => 235,
            'y'    => 60,
        },
        {
            'text' => 'damaged',
            'y'    => 60,
            'x'    => 315,
        },
        {
            'text' => 'killed',
            'y'    => 60,
            'x'    => 410,
        },
        {
            'text' => 'survived',
            'x'    => 235,
            'y'    => 80,
        },
        {
            'text' => 'server',
            'y'    => 80,
            'x'    => 315,
        },
        {
            'text' => 'version',
            'y'    => 80,
            'x'    => 410,
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
    my $background = Imager->new(xsize => 500, ysize => 98, channels => 4);

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
    $self->_bg->line(color => $lc, x1 => 235, x2 => 495, y1 => 26, y2 => 26);

    # draw the player and map names
    my $hc      = Imager::Color->new('#F9D088');
    my $font    = Imager::Font->new(file => sprintf('%s/../../etc/fonts/OpenSans-CondBold.ttf', $self->_path), color => $hc, aa => 1);
    my $dfont   = Imager::Font->new(file => sprintf('%s/../../etc/fonts/OpenSans-CondBold.ttf', $self->_path), color => $lc, aa => 1);

    my $pbox = $font->bounding_box(string => $args{player}, size => 15);
    my $dashbox = $font->bounding_box(string => ' - ', size => 15);
    my $vehbox = $font->bounding_box(string => $args{vehicle_name}, size => 15);
    my $mapbox = $font->bounding_box(string => $args{map_name}, size => 15);

    my $offset = 235;
    $font->align(string => $args{player}, size => 15, x => $offset, y => 15, valign => 'center', halign => 'left', image => $self->_bg);
    $offset += ($pbox->pos_width - $pbox->neg_width) + 2;
    $dfont->align(string => ' - ', size => 15, x => $offset, y => 18, valign => 'center', halign => 'left', image => $self->_bg);
    $offset += ($dashbox->pos_width - $dashbox->neg_width) + 2;
    $font->align(string => $args{vehicle_name}, size => 15, x => $offset, y => 15, valign => 'center', halign => 'left', image => $self->_bg);
    $offset += ($vehbox->pos_width - $vehbox->neg_width) + 2;
    $dfont->align(string => ' - ', size => 15, x => $offset, y => 18, valign => 'center', halign => 'left', image => $self->_bg);
    $offset += ($dashbox->pos_width - $dashbox->neg_width) + 2;
    $font->align(string => $args{map_name}, size => 15, x => $offset, y => 15, valign => 'center', halign => 'left', image => $self->_bg);

    foreach my $e (@{$self->_text}) {
        if(defined($e->{x}) && defined($e->{y})) {
            $self->_bg->string(text => $e->{text} . ':', size => 11, x => $e->{x}, y => $e->{y}, color => $lc, aa => 1, font => $dfont);
            $self->_bg->string(text => $args{$e->{text}}, size => 11, x => $e->{x} + 25, y => $e->{y}, color => $lc, aa => 1, font => $dfont);
        }
    }
            

    $self->_bg->write(file => '/tmp/replay.png');
}

__PACKAGE__->meta->make_immutable;
