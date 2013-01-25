package WR::Imager;
use Moose;
use Imager;

has '_path' => (is => 'ro', isa => 'Str', required => 1, builder => '_build_path', lazy => 1);
has '_bg'   => (is => 'ro', isa => 'Imager', builder => '_build_bg', required => 1, lazy => 1);
has '_overlay' => (is => 'ro', isa => 'Imager', builder => '_build_overlay', required => 1, lazy => 1);

sub BUILD {
    my $self = shift;

    $self->_path;
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
    my $background = Imager->new();
    $background->read(file => sprintf('%s/../../etc/img/background.png', $self->_path)) or die 'failed reading background', "\n";
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
    $self->_bg->rubthrough(top => 0, left => 60, src => $vehicle);

    # start doing text
    my $labelcolor = Imager::Color->new('#E0E0E0');
    my $textcolor  = Imager::Color->new('#FFFFFF');
    my $resultcolor = ($args{result} eq 'victory')
        ? Imager::Color->new('#00FF00')
        : ($args{'result'} eq 'draw')
            ? Imager::Color->new('A0A0A0')
            : Imager::Color->new('FF0000');


    my $resultfont = Imager::Font->new(
        file => sprintf('%s/../../etc/fonts/OpenSans-CondBold.ttf', $self->_path),
        size => 12,
        color => $resultcolor,
        );

    my $textfont = Imager::Font->new(
        file => sprintf('%s/../../etc/fonts/OpenSans-CondBold.ttf', $self->_path),
        size => 12,
        color => $textcolor,
        );

    $self->_bg->string(
        text => $args{xp} || '-',
        font => $textfont,
        aa   => 1,
        color => $textcolor,
        x => 260,
        y => 22,
    );

    $self->_bg->string(
        text => $args{credits} || '-',
        font => $textfont,
        aa   => 1,
        color => $textcolor,
        x => 355,
        y => 22,
    );

    $self->_bg->string(
        text => $args{result} || '-',
        font => $resultfont,
        aa   => 1,
        color => $resultcolor,
        x => 450,
        y => 22,
    );

    $self->_bg->string(
        text => $args{kills} || '-',
        font => $textfont,
        aa   => 1,
        color => $textcolor,
        x => 260,
        y => 52,
    );

    $self->_bg->string(
        text => $args{damaged} || '-',
        font => $textfont,
        aa   => 1,
        color => $textcolor,
        x => 355,
        y => 52,
    );

    $self->_bg->string(
        text => $args{spotted} || '-',
        font => $textfont,
        aa   => 1,
        color => $textcolor,
        x => 450,
        y => 52,
    );

    $self->_bg->string(
        text => 'player:',
        font => $textfont,
        aa   => 1,
        color => $textcolor,
        x => 260,
        y => 82,
    );

    my $bbox = $textfont->bounding_box(string => $args{player});

    $self->_bg->string(
        text => $args{'player'},
        font => $textfont,
        aa   => 1,
        color => $textcolor,
        x => 300,
        y => 82,
    );

    if($args{clan}) {
        $self->_bg->string(
            text => sprintf('[%s]', $args{clan}),
            font => $textfont,
            aa   => 1,
            color => Imager::Color->new('#606060'),
            x => 300 + $bbox->pos_width,
            y => 82,
        );
    }

    $self->_bg->write(file => $args{'destination'});
}

__PACKAGE__->meta->make_immutable;
