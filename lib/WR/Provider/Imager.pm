package WR::Provider::Imager;
use Mojo::Base '-base';
use Imager;

has '_path'         => sub { return shift->_build_path };
has '_config_path'  => sub { return shift->_build_config_path };
has '_bg'           => sub { return shift->_build_bg };
has '_overlay'      => sub { return shift->_build_overlay };

sub new {   
    my $package = shift;
    my $self = $package->SUPER::new(@_);
    
    bless($self, $package);
    $self->_path;
    return $self;
}

sub _build_path {
    my $self = shift;

    # this is still cheese, need to either take a root param or figure this out
    # better, we know the 'sites/images...' bit is always the same regardless.
    return (-e '/home/ben') 
        ? '/home/ben/projects/wot-replays/public'
        : '/home/wotreplay/wot-replays/public'
        ;
}

sub _build_config_path {
    my $self = shift;

    # this is still cheese, need to either take a root param or figure this out
    # better, we know the 'sites/images...' bit is always the same regardless.
    return (-e '/home/ben') 
        ? '/home/ben/projects/wot-replays/site/etc'
        : '/home/wotreplay/wot-replays/etc'
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
    $background->read(file => sprintf('%s/img/background.png', $self->_config_path)) or die 'failed reading background', "\n";
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

    my $bar = Imager->new(xsize => 545, ysize => 20, channels => 4);
    $bar->box(filled => 1, color => 'black');

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
        file => sprintf('%s/fonts/OpenSans-CondBold.ttf', $self->_config_path),
        size => 12,
        color => $resultcolor,
        );
    die 'No resultfont from: ', sprintf('%s/fonts/OpenSans-CondBold.ttf', $self->_config_path), "\n" unless(defined($resultfont));

    my $textfont = Imager::Font->new(
        file => sprintf('%s/fonts/OpenSans-CondBold.ttf', $self->_config_path),
        size => 12,
        color => $textcolor,
        );
    die 'No textfont from: ', sprintf('%s/fonts/OpenSans-CondBold.ttf', $self->_config_path), "\n" unless(defined($textfont));

    $self->_bg->string(
        text => $args{xp} || '-',
        font => $textfont,
        aa   => 1,
        color => $textcolor,
        x => 260,
        y => 36,
    );

    $self->_bg->string(
        text => $args{credits} || '-',
        font => $textfont,
        aa   => 1,
        color => $textcolor,
        x => 355,
        y => 36,
    );

    $self->_bg->string(
        text => $args{result} || '-',
        font => $resultfont,
        aa   => 1,
        color => $resultcolor,
        x => 445,
        y => 36,
    );

    $self->_bg->string(
        text => $args{kills} || '0',
        font => $textfont,
        aa   => 1,
        color => $textcolor,
        x => 260,
        y => 66,
    );

    $self->_bg->string(
        text => $args{damaged} || '0',
        font => $textfont,
        aa   => 1,
        color => $textcolor,
        x => 355,
        y => 66,
    );

    $self->_bg->string(
        text => $args{spotted} || '0',
        font => $textfont,
        aa   => 1,
        color => $textcolor,
        x => 445,
        y => 66,
    );

    $self->_bg->compose(tx => 0, ty => 0, src => $bar, opacity => 0.7);
    $self->_bg->compose(tx => 0, ty => 98-20, src => $bar, opacity => 0.7);

    my $bbox = $textfont->bounding_box(string => $args{player});

    $self->_bg->string(
        text => $args{'player'},
        font => $textfont,
        aa   => 1,
        color => $textcolor,
        x => 5,
        y => 14,
    );

    if($args{clan}) {
        $self->_bg->string(
            text => sprintf('[%s]', $args{clan}),
            font => $textfont,
            aa   => 1,
            color => Imager::Color->new('#909090'),
            x => 5 + $bbox->pos_width,
            y => 14,
        );
    }

    $self->_bg->string(
        text => $args{'vehicle_name'},
        font => $textfont,
        aa   => 1,
        color => $textcolor,
        x => 5,
        y => (98-20) + 14,
    );

    $bbox = $textfont->bounding_box(string => $args{'vehicle_name'});
    my $o1 = 10 + $bbox->pos_width;

    $bbox = $textfont->bounding_box(string => ' - ');
    my $o2 = $o1 + $bbox->pos_width + 5;

    $self->_bg->string(
        text => ' - ',
        font => $textfont,
        aa   => 1,
        color => Imager::Color->new('#909090'),
        x => $o1,
        y => (98-20) + 14,
    );

    $self->_bg->string(
        text => $args{'map_name'},
        font => $textfont,
        aa   => 1,
        color => $textcolor,
        x => $o2,
        y => (98-20) + 14,
    );

    # load the award icons
    my $x = 545 - 5 - 16;
    foreach my $award (@{$args{awards}}) {
        my $aicon = Imager->new();
        $aicon->read(file => sprintf('%s/icon/awards/16/%s.png', $self->_path, $award)) or die 'failed reading award: ' . $award, "\n";
        $self->_bg->compose(src => $aicon, tx => $x, ty => 2);
        $x -= (16 + 5);
    }

    if(ref($args{destination}) eq 'ARRAY') {
        $self->_bg->write(file => $_, type => 'jpeg') for(@{$args{'destination'}});
    } else {
        $self->_bg->write(file => $args{'destination'}, type => 'jpeg');
    }

    return $args{'destination'};
}

1;

