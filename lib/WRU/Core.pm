package WRU::Core;
use strict;
use warnings;

use constant V_NUM => '1.0.2';

# win32 specific
use Win32::GUI ();
use Win32::GUI::BitmapInline();
use Win32::TieRegistry ( Delimiter => q{/} );

# global
use IO::File;
use Mojo::UserAgent;

use constant WM_NOTIFYICON => 32768 + 2;
use constant WR_URL => 'http://www.wot-replays.org/wru/';
use constant NI_DEFAULT_ICON => q(
AAABAAIAICAQAAAAAADoAgAAJgAAACAgAAAAAAAAqAgAAA4DAAAoAAAAIAAAAEAAAAABAAQAAAAA
AIACAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAgAAAgAAAAICAAIAAAACAAIAAgIAAAMDAwACAgIAA
AAD/AAD/AAAA//8A/wAAAP8A/wD//wAA////AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIgAd3AAiIAAAAAAAAAAAAgHgIcACAiAAAAAAAAAAAAI
CIiAAAAIAAAAAAAAAAAAAAiIAAAAAAAAAAAAAAAAAIgHiAAAAAAAAAAAAAAAAACIB3cACAAAAAAA
AAAAAAAACIB3gAAAAAgAAAAAAAAAAAAIgIiAAAAAAAAAAAAAAAAAAAAAiAiAgAAAAAAAAAAAAAAA
AAeIiAAAAAAAAAAAAAAIgIAAiAiAAAAAAAAAAAAAAIdwAACAAAAAAAAAAAAAgAAABwAAAAAAAAAA
AAAAAAAICHcAAAAAAAAAAAAAAAAACAB3cHAACIgAAAAAAAAIAAiId3gIAAgHAAAAAAAAAAiAB3d4
AIAABwAAAAAAAId3d3eIiAAAAAgAAAAAh3eHd3dwAAiAAACAAAAACAh3d3d3AAAHeAAAAAAAAAAA
iAh3dwCIAAgIeAAAAAAACIiHAHAAh3gAgHAAAAAAAAgACIAACAeIgICAAAAAAAAAAAAAAACIcAiA
AAAAAAAAAAAAAAAAAAAIiAAAAAAAAAAAAAAAAIAACIAAAAAAAAAAAAAAAAAIgIAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/////////////////wAAf/8AAH//AAB//wAAf/8A
AH//AAB//wAAP/8AAD//AAA//4AAH/+AAB//wAAf/8AAH//gAB//4AAP/4AAD/gAAA/4AAAP8AAA
H+AAAD/wAAA/+AAAP/iAAH//+AD///4A////Af///4f///////////8oAAAAIAAAAEAAAAABAAgA
AAAAAIAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgAAAgAAAAICAAIAAAACAAIAAgIAAAMDAwADA
3MAA8MqmANTw/wCx4v8AjtT/AGvG/wBIuP8AJar/AACq/wAAktwAAHq5AABilgAASnMAADJQANTj
/wCxx/8Ajqv/AGuP/wBIc/8AJVf/AABV/wAASdwAAD25AAAxlgAAJXMAABlQANTU/wCxsf8Ajo7/
AGtr/wBISP8AJSX/AAAA/gAAANwAAAC5AAAAlgAAAHMAAABQAOPU/wDHsf8Aq47/AI9r/wBzSP8A
VyX/AFUA/wBJANwAPQC5ADEAlgAlAHMAGQBQAPDU/wDisf8A1I7/AMZr/wC4SP8AqiX/AKoA/wCS
ANwAegC5AGIAlgBKAHMAMgBQAP/U/wD/sf8A/47/AP9r/wD/SP8A/yX/AP4A/gDcANwAuQC5AJYA
lgBzAHMAUABQAP/U8AD/seIA/47UAP9rxgD/SLgA/yWqAP8AqgDcAJIAuQB6AJYAYgBzAEoAUAAy
AP/U4wD/sccA/46rAP9rjwD/SHMA/yVXAP8AVQDcAEkAuQA9AJYAMQBzACUAUAAZAP/U1AD/sbEA
/46OAP9rawD/SEgA/yUlAP4AAADcAAAAuQAAAJYAAABzAAAAUAAAAP/j1AD/x7EA/6uOAP+PawD/
c0gA/1clAP9VAADcSQAAuT0AAJYxAABzJQAAUBkAAP/w1AD/4rEA/9SOAP/GawD/uEgA/6olAP+q
AADckgAAuXoAAJZiAABzSgAAUDIAAP//1AD//7EA//+OAP//awD//0gA//8lAP7+AADc3AAAubkA
AJaWAABzcwAAUFAAAPD/1ADi/7EA1P+OAMb/awC4/0gAqv8lAKr/AACS3AAAerkAAGKWAABKcwAA
MlAAAOP/1ADH/7EAq/+OAI//awBz/0gAV/8lAFX/AABJ3AAAPbkAADGWAAAlcwAAGVAAANT/1ACx
/7EAjv+OAGv/awBI/0gAJf8lAAD+AAAA3AAAALkAAACWAAAAcwAAAFAAANT/4wCx/8cAjv+rAGv/
jwBI/3MAJf9XAAD/VQAA3EkAALk9AACWMQAAcyUAAFAZANT/8ACx/+IAjv/UAGv/xgBI/7gAJf+q
AAD/qgAA3JIAALl6AACWYgAAc0oAAFAyANT//wCx//8Ajv//AGv//wBI//8AJf//AAD+/gAA3NwA
ALm5AACWlgAAc3MAAFBQAPLy8gDm5uYA2traAM7OzgDCwsIAtra2AKqqqgCenp4AkpKSAIaGhgB6
enoAbm5uAGJiYgBWVlYASkpKAD4+PgAyMjIAJiYmABoaGgAODg4A8Pv/AKSgoACAgIAAAAD/AAD/
AAAA//8A/wAAAP8A/wD//wAA////AOnp6enp6enp6enp6enp6enp6enp6enp6enp6enp6enr5+T/
//////8AAAAA6+sAAAcHBwAAAOvr6///////5Ovn5P///////wAAAOsAB+sA6wcAAADrAOvr////
///k6+fk////////AAAA6wDr6+vrAAAAAAAA6wD//////+Tr5+T///////8AAAAAAOvr6wAAAAAA
AAAAAP//////5Ovn5P///////wAA6+sAB+vrAAAAAAAAAAAA///////k6+fk////////AADr6wAH
BwcAAADrAAAAAAD//////+Tr5+T///////8AAADr6wAHB+sAAAAAAAAAAOv/////5Ovn5P//////
/wAAAAAA6+sA6+vrAAAAAAAAAP/////k6+fk////////AAAAAAAAAAAAAOvrAOvrAOsA/////+Tr
5+T/////////AAAAAAAAAAAAAAfr6+vrAAAA////5Ovn5P////////8AAAAA6+sA6wAAAOvrAOvr
AAD////k6+fk//////////8AAAAA6wcHAAAAAADrAAAAAP///+Tr5+T//////////+sAAAAAAAAH
AAAAAAAAAAAA////5Ovn5P///////////wAA6wDrBwcAAAAAAAAAAAD////k6+fk////////////
AADrAAAHBwcABwAAAADr6+v//+Tr5+T/////////6wAAAOvr6wcHB+sA6wAAAOsAB///5Ovn5P//
/wAAAAAAAOvrAAAHBwcH6wAA6wAAAAAH///k6+fk////AAAA6wcHBwcHBwfr6+vrAAAAAAAAAOv/
/+Tr5+T//+sHBwfrBwcHBwcHAAAAAOvrAAAAAADr////5Ovn5P/rAOsHBwcHBwcHBwAAAAAABwfr
AAAAAP/////k6+fk//8AAOvrAOsHBwcHAADr6wAAAOsA6wfr/////+Tr5+T////r6+vrBwAABwAA
AOsHB+sAAOsABwD/////5Ovn5P///+sAAP/r6wAAAADrAAfr6+sA6wDr///////k6+fk////////
//////8AAADr6wcAAOvrAP///////+Tr5+T/////////////////AAAAAAAA6+vr////////5Ovn
5P//////////////////6wAAAADr6//////////k6+fn5+fn5+fn5+fn5+fn5+fn6+sA6+fn5+fn
5+fn5wfr5wcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHB+vnZxFnZ2dnZ2dnZ2dnZ2dnZ2dn
Z2dnZ2dn6+vr6+tn6+dnDmdnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2cH6gfqB2fr5+vr6+vr6+vr6+vr
6+vr6+vr6+vr6+vr6+vr6+vr6+sAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA==
);

use constant WIN32_TIMEZONES => {
        'Afghanistan'                     => 'Asia/Kabul',
        'Afghanistan Standard Time'       => 'Asia/Kabul',
        'Alaskan'                         => 'America/Anchorage',
        'Alaskan Standard Time'           => 'America/Anchorage',
        'Arab'                            => 'Asia/Riyadh',
        'Arab Standard Time'              => 'Asia/Riyadh',
        'Arabian'                         => 'Asia/Muscat',
        'Arabian Standard Time'           => 'Asia/Muscat',
        'Arabic Standard Time'            => 'Asia/Baghdad',
        'Argentina Standard Time'         => 'America/Argentina/Buenos_Aires',
        'Armenian Standard Time'          => 'Asia/Yerevan',
        'Atlantic'                        => 'America/Halifax',
        'Atlantic Standard Time'          => 'America/Halifax',
        'AUS Central'                     => 'Australia/Darwin',
        'AUS Central Standard Time'       => 'Australia/Darwin',
        'AUS Eastern'                     => 'Australia/Sydney',
        'AUS Eastern Standard Time'       => 'Australia/Sydney',
        'Azerbaijan Standard Time'        => 'Asia/Baku',
        'Azores'                          => 'Atlantic/Azores',
        'Azores Standard Time'            => 'Atlantic/Azores',
        'Bangkok'                         => 'Asia/Bangkok',
        'Bangkok Standard Time'           => 'Asia/Bangkok',
        'Bangladesh Standard Time'        => 'Asia/Dhaka',
        'Beijing'                         => 'Asia/Shanghai',
        'Canada Central'                  => 'America/Regina',
        'Canada Central Standard Time'    => 'America/Regina',
        'Cape Verde Standard Time'        => 'Atlantic/Cape_Verde',
        'Caucasus'                        => 'Asia/Yerevan',
        'Caucasus Standard Time'          => 'Asia/Yerevan',
        'Cen. Australia'                  => 'Australia/Adelaide',
        'Cen. Australia Standard Time'    => 'Australia/Adelaide',
        'Central'                         => 'America/Chicago',
        'Central America Standard Time'   => 'America/Regina',
        'Central Asia'                    => 'Asia/Almaty',
        'Central Asia Standard Time'      => 'Asia/Almaty',
        'Central Brazilian Standard Time' => 'America/Cuiaba',
        'Central Europe'                  => 'Europe/Prague',
        'Central Europe Standard Time'    => 'Europe/Prague',
        'Central European'                => 'Europe/Belgrade',
        'Central European Standard Time'  => 'Europe/Belgrade',
        'Central Pacific'                 => 'Pacific/Guadalcanal',
        'Central Pacific Standard Time'   => 'Pacific/Guadalcanal',
        'Central Standard Time'           => 'America/Chicago',
        'Central Standard Time (Mexico)'  => 'America/Mexico_City',
        'China'                           => 'Asia/Shanghai',
        'China Standard Time'             => 'Asia/Shanghai',
        'Dateline'                        => '-1200',
        'Dateline Standard Time'          => '-1200',
        'E. Africa'                       => 'Africa/Nairobi',
        'E. Africa Standard Time'         => 'Africa/Nairobi',
        'E. Australia'                    => 'Australia/Brisbane',
        'E. Australia Standard Time'      => 'Australia/Brisbane',
        'E. Europe'                       => 'Europe/Minsk',
        'E. Europe Standard Time'         => 'Europe/Minsk',
        'E. South America'                => 'America/Sao_Paulo',
        'E. South America Standard Time'  => 'America/Sao_Paulo',
        'Eastern'                         => 'America/New_York',
        'Eastern Standard Time'           => 'America/New_York',
        'Egypt'                           => 'Africa/Cairo',
        'Egypt Standard Time'             => 'Africa/Cairo',
        'Ekaterinburg'                    => 'Asia/Yekaterinburg',
        'Ekaterinburg Standard Time'      => 'Asia/Yekaterinburg',
        'Fiji'                            => 'Pacific/Fiji',
        'Fiji Standard Time'              => 'Pacific/Fiji',
        'FLE'                             => 'Europe/Helsinki',
        'FLE Standard Time'               => 'Europe/Helsinki',
        'Georgian Standard Time'          => 'Asia/Tbilisi',
        'GFT'                             => 'Europe/Athens',
        'GFT Standard Time'               => 'Europe/Athens',
        'GMT'                             => 'Europe/London',
        'GMT Standard Time'               => 'Europe/London',
        'Greenland Standard Time'         => 'America/Godthab',
        'Greenwich'                       => 'GMT',
        'Greenwich Standard Time'         => 'GMT',
        'GTB'                             => 'Europe/Athens',
        'GTB Standard Time'               => 'Europe/Athens',
        'Hawaiian'                        => 'Pacific/Honolulu',
        'Hawaiian Standard Time'          => 'Pacific/Honolulu',
        'India'                           => 'Asia/Calcutta',
        'India Standard Time'             => 'Asia/Calcutta',
        'Iran'                            => 'Asia/Tehran',
        'Iran Standard Time'              => 'Asia/Tehran',
        'Israel'                          => 'Asia/Jerusalem',
        'Israel Standard Time'            => 'Asia/Jerusalem',
        'Jordan Standard Time'            => 'Asia/Amman',
        'Kamchatka Standard Time'         => 'Asia/Kamchatka',
        'Korea'                           => 'Asia/Seoul',
        'Korea Standard Time'             => 'Asia/Seoul',
        'Magadan Standard Time'           => 'Asia/Magadan',
        'Mauritius Standard Time'         => 'Indian/Mauritius',
        'Mexico'                          => 'America/Mexico_City',
        'Mexico Standard Time'            => 'America/Mexico_City',
        'Mexico Standard Time 2'          => 'America/Chihuahua',
        'Mid-Atlantic'                    => 'Atlantic/South_Georgia',
        'Mid-Atlantic Standard Time'      => 'Atlantic/South_Georgia',
        'Middle East Standard Time'       => 'Asia/Beirut',
        'Montevideo Standard Time'        => 'America/Montevideo',
        'Morocco Standard Time'           => 'Africa/Casablanca',
        'Mountain'                        => 'America/Denver',
        'Mountain Standard Time'          => 'America/Denver',
        'Mountain Standard Time (Mexico)' => 'America/Chihuahua',
        'Myanmar Standard Time'           => 'Asia/Rangoon',
        'N. Central Asia Standard Time'   => 'Asia/Novosibirsk',
        'Namibia Standard Time'           => 'Africa/Windhoek',
        'Nepal Standard Time'             => 'Asia/Katmandu',
        'New Zealand'                     => 'Pacific/Auckland',
        'New Zealand Standard Time'       => 'Pacific/Auckland',
        'Newfoundland'                    => 'America/St_Johns',
        'Newfoundland Standard Time'      => 'America/St_Johns',
        'North Asia East Standard Time'   => 'Asia/Irkutsk',
        'North Asia Standard Time'        => 'Asia/Krasnoyarsk',
        'Pacific'                         => 'America/Los_Angeles',
        'Pacific SA'                      => 'America/Santiago',
        'Pacific SA Standard Time'        => 'America/Santiago',
        'Pacific Standard Time'           => 'America/Los_Angeles',
        'Pacific Standard Time (Mexico)'  => 'America/Tijuana',
        'Pakistan Standard Time'          => 'Asia/Karachi',
        'Paraguay Standard Time'          => 'America/Asuncion',
        'Prague Bratislava'               => 'Europe/Prague',
        'Romance'                         => 'Europe/Paris',
        'Romance Standard Time'           => 'Europe/Paris',
        'Russian'                         => 'Europe/Moscow',
        'Russian Standard Time'           => 'Europe/Moscow',
        'SA Eastern'                      => 'America/Cayenne',
        'SA Eastern Standard Time'        => 'America/Cayenne',
        'SA Pacific'                      => 'America/Bogota',
        'SA Pacific Standard Time'        => 'America/Bogota',
        'SA Western'                      => 'America/Guyana',
        'SA Western Standard Time'        => 'America/Guyana',
        'Samoa'                           => 'Pacific/Apia',
        'Samoa Standard Time'             => 'Pacific/Apia',
        'Saudi Arabia'                    => 'Asia/Riyadh',
        'Saudi Arabia Standard Time'      => 'Asia/Riyadh',
        'SE Asia'                         => 'Asia/Bangkok',
        'SE Asia Standard Time'           => 'Asia/Bangkok',
        'Singapore'                       => 'Asia/Singapore',
        'Singapore Standard Time'         => 'Asia/Singapore',
        'South Africa'                    => 'Africa/Harare',
        'South Africa Standard Time'      => 'Africa/Harare',
        'Sri Lanka'                       => 'Asia/Colombo',
        'Sri Lanka Standard Time'         => 'Asia/Colombo',
        'Syria Standard Time'             => 'Asia/Damascus',
        'Sydney Standard Time'            => 'Australia/Sydney',
        'Taipei'                          => 'Asia/Taipei',
        'Taipei Standard Time'            => 'Asia/Taipei',
        'Tasmania'                        => 'Australia/Hobart',
        'Tasmania Standard Time'          => 'Australia/Hobart',
        'Tokyo'                           => 'Asia/Tokyo',
        'Tokyo Standard Time'             => 'Asia/Tokyo',
        'Tonga Standard Time'             => 'Pacific/Tongatapu',
        'Ulaanbaatar Standard Time'       => 'Asia/Ulaanbaatar',
        'US Eastern'                      => 'America/Indianapolis',
        'US Eastern Standard Time'        => 'America/Indianapolis',
        'US Mountain'                     => 'America/Phoenix',
        'US Mountain Standard Time'       => 'America/Phoenix',
        'UTC'                             => 'UTC',
        'UTC+12'                          => '+1200',
        'UTC-02'                          => '-0200',
        'UTC-11'                          => '-1100',
        'Venezuela Standard Time'         => 'America/Caracas',
        'Vladivostok'                     => 'Asia/Vladivostok',
        'Vladivostok Standard Time'       => 'Asia/Vladivostok',
        'W. Australia'                    => 'Australia/Perth',
        'W. Australia Standard Time'      => 'Australia/Perth',
        'W. Central Africa Standard Time' => 'Africa/Luanda',
        'W. Europe'                       => 'Europe/Berlin',
        'W. Europe Standard Time'         => 'Europe/Berlin',
        'Warsaw'                          => 'Europe/Warsaw',
        'West Asia'                       => 'Asia/Karachi',
        'West Asia Standard Time'         => 'Asia/Karachi',
        'West Pacific'                    => 'Pacific/Guam',
        'West Pacific Standard Time'      => 'Pacific/Guam',
        'Western Brazilian Standard Time' => 'America/Rio_Branco',
        'Yakutsk'                         => 'Asia/Yakutsk',
        'Yakutsk Standard Time'           => 'Asia/Yakutsk',
};

sub new {
    my $package = shift;
    my $class   = ref($package) || $package;
    my $self = bless({
        ua => Mojo::UserAgent->new(),
        config => {},
        seen   => {},
        uploads => [],
    }, $class);

    $self->{ua}->on(start => sub {
        my ($ua, $tx) = (@_);

        my $timer = $ua->ioloop->recurring(0.25 => sub {
            Win32::GUI::DoEvents();
        });

        $tx->on(finished => sub {
            $timer = undef;
        });

        $tx->on(connection => sub {
            my ($tx, $connection) = @_;

            my $stream = $ua->ioloop->stream($connection);
            my $read = $stream->on(read => sub {
                my ($stream, $chunk) = (@_);
                Win32::GUI::DoEvents();
            });
            my $write = $stream->on(write => sub {
                my ($stream, $chunk) = (@_);
		        Win32::GUI::DoEvents();
            });
        });
    });

    return $self;
}

sub init {
    my $self = shift;

    my $dot_wotreplay = $Registry->{'HKEY_CLASSES_ROOT/.wotreplay/shell/open/command/'};
    my $replay_open   = $dot_wotreplay->{'/'};

    $replay_open =~ s/"(.*\\).*"/$1/g;
    $replay_open = $replay_open . '\\' if($replay_open !~ /\\$/);

    $self->{config}->{replay_path} = sprintf('%sreplays', $replay_open);

    my $tzinfo = $Registry->{'HKEY_LOCAL_MACHINE/SYSTEM/CurrentControlSet/Control/TimeZoneInformation/'};
    my $tzname = $tzinfo->{'/TimeZoneKeyName'};

    $self->{config}->{timezone} = __PACKAGE__->WIN32_TIMEZONES->{$tzname};

    my $app_data = $ENV{'LOCALAPPDATA'} || $ENV{'APPDATA'};
    my $our_app_data = sprintf('%s\\wot_replay_upload', $app_data);
    mkdir($our_app_data, 0777) unless(-e $our_app_data);

    $self->{config}->{'seen_file'} = sprintf('%s\\seen.txt', $our_app_data);
    $self->{config}->{'token_file'} = sprintf('%s\\token.wru', $our_app_data);
    $self->{config}->{'app_data'} = $our_app_data;
    $self->{config}->{'app_lib'} = sprintf('%s\\applib', $our_app_data);

    mkdir($self->{config}->{app_lib}, 0777) unless(-e $self->{config}->{app_lib});

    if(my $fh = IO::File->new($self->{config}->{'seen_file'})) {
        while(chomp(my $fn = <$fh>)) {
            $self->{seen}->{$fn} = 1;
        }
        $fh->close;
    }
    if(my $fh = IO::File->new($self->{config}->{token_file})) {
        chomp(my $token = <$fh>);
        $self->{config}->{wru_token} = $token;
    }
}

sub get_new_replays {
    my $self = shift;
    my $dir;
    my $replays = [];

    opendir($dir, $self->{config}->{'replay_path'});
    foreach my $file (readdir($dir)) {
        next unless($file =~ /\.wotreplay$/);
        next if(defined($self->{seen}->{$file}));
        next if($file eq 'temp.wotreplay');
        push(@$replays, $file);
    }
    closedir($dir);
    return $replays;
}

sub save_seen {
    my $self = shift;
    my $f    = shift;

    $self->{seen}->{$f} = 1 if(defined($f));

    if(my $fh = IO::File->new('>' . $self->{config}->{seen_file})) {
        $fh->print(join("\n", keys(%{$self->{seen}})));
        $fh->close;
    }
}

sub init_win32 {
    my $self = shift;

    # actually the main window does't contain much of anything except the log for now
    my $mWin = Win32::GUI::Window->new(
        -text => sprintf('World of Tanks Replay Uploader v%s', __PACKAGE__->V_NUM),
        -name => 'main',
        -hasminimize => 0,
        -hasmaximize => 0,
        -sizable => 0,
        -resizable => 0,
        -width => 800,
        -height => 310,
        -onTimer => sub {
            $self->onTimer(@_);
        },
        -onTerminate => sub {
            $self->onTerminate(@_);
        },
    );

    $mWin->AddNotifyIcon(
	    -icon => $self->get_defaulticon(),
	    -tip  => 'WoT Replay Uploader',
	    -balloon => 0
	    );

    $mWin->Hook(WM_NOTIFYICON, sub {
        $self->process_notify_icon_event(@_);
    });

    # this needs to change to something a bit more reasonable
    $mWin->AddTimer('replayWatcher', 60000);
    $mWin->AddTimer('performUpload', 300000);
    $mWin->AddTimer('logMark', 60000);

    my $mLog   = $mWin->AddTextfield(
        -name => 'uLog',
        -pos => [0, 0],
        -size => [790, 280],
        -multiline => 1,
        -hscroll => 1,
        -vscroll => 1,
        -autohscroll => 0,
        -autovscroll => 1,
        -readonly => 1,
        );

    $self->{gui}->{main} = $mWin;
    $self->{gui}->{log}  = $mLog;
    $self->{gui}->{visible} = 0;
}

sub logMark {
    my $self = shift;

    $self->log('--- MARK ---');
}

sub process_notify_icon_event {
    my $self = shift;
	my ($win, $id, $lParam, $type, $msgcode) = @_;
    
    return if(defined($self->{gui}->{ignore_systray}) && $self->{gui}->{ignore_systray} == 1);

	return unless $msgcode == WM_NOTIFYICON;
	return unless $type == 0;
	return unless $lParam == 513;
  
    if($self->{gui}->{visible} == 0) { 
        $self->{gui}->{visible} = 1;
        $self->{gui}->{main}->Show();
    } else {
        $self->{gui}->{visible} = 0;
        $self->{gui}->{main}->Hide();
    }
}

sub onTimer {
    my $self = shift;
    my $win  = shift;
    my $timer = shift;

    $self->$timer() if($self->can($timer));
}

sub log {
    my $self = shift;

    return unless(defined($self->{gui}->{log}));

    my $t = sprintf('[%s]: %s', scalar(localtime(time)), join(' ', @_));
    $t .= "\r\n";

    my $l = $self->{gui}->{log}->Text();

    my @l = split(/\r\n/, $l);
    $l = join("\r\n", splice(@l, 0, 49));
    $self->{gui}->{log}->Text($t . $l);
}

sub replayWatcher {
    my $self = shift;

    return unless(defined($self->{config}->{wru_token}));

    my $new  = $self->get_new_replays();

    foreach my $file (@$new) {
        next if(defined({ map { $_ => 1 } @{$self->{uploads}} }->{$file}));
        push(@{$self->{uploads}}, $file);
        $self->log(sprintf('added "%s" to the upload queue, now at %d files', $file, scalar(@{$self->{uploads}})));
    }

    # see if we're doing anything 
    $self->performUpload unless(defined($self->{upload}->{busy}) && $self->{upload}->{busy} == 1);
}

sub _do_upload {
    my $self = shift;
    my $file = shift;
    my $real_file = shift;

    $self->log(sprintf('uploading "%s"', $file));

    my $tx = $self->{ua}->post_form('www.wot-replays.org/wru/upload' => {
        replay     => { file => $real_file },
        wru_token  => $self->{config}->{wru_token},
        timezone   => $self->{config}->{timezone},
    });

    if(my $res = $tx->success) {
        my $ok = $res->json->{ok} || 0;
        if($ok) {
            shift(@{$self->{uploads}});
            $self->log(sprintf('upload of "%s" complete OK', $file));
            $self->save_seen($file);
        } else {
            my $dup = $res->json->{duplicate} || 0;
            if($dup) {
                $self->log(sprintf('upload of "%s" complete OK but it was a duplicate', $file));
                $self->save_seen($file);
                shift(@{$self->{uploads}});
            } else {
                $self->log(sprintf('upload of "%s" failed: %s', $real_file, $res->json->{error} || 'unknown error'));
                shift(@{$self->{uploads}});
            }
        }
    } else {
        $self->log(sprintf('upload of "%s" failed: %s', $real_file, ($tx->error)[0]));
    }   
}

sub performUpload {
    my $self = shift;

    return unless(scalar(@{$self->{uploads}}) > 0);
    return unless(defined($self->{config}->{wru_token}));
    return if(defined($self->{upload}->{busy}) && $self->{upload}->{busy} == 1);

    $self->{upload}->{busy} = 1;

    my $file = $self->{uploads}->[0];
    my $real_file = sprintf('%s\\%s', $self->{config}->{'replay_path'}, $file);

    if(my $fh = IO::File->new($real_file)) {
        my $buf;
        $fh->seek(4, 0); # SEEK_SET
        $fh->read($buf, 4);
        my $block_count = unpack('I*', $buf);

        if(defined($self->{config}->{only_complete}) && $self->{config}->{only_complete} == 1 && $block_count == 1) {
            $self->log(sprintf('skipping "%s", incomplete replay', $file));
            $self->save_seen($file); # skip it
        } else {
            $self->_do_upload($file, $real_file);
        }
    } else {
        $self->log(sprintf('something went wrong, can\'t seem to read "%s"', $real_file));
    }
    $self->{upload}->{busy} = 0;
}

sub onTerminate {
    my $self = shift
    return -1;
}

sub get_defaulticon { return newIcon Win32::GUI::BitmapInline(__PACKAGE__->NI_DEFAULT_ICON) };

sub consdie {
    my $self = shift;
    print << 'EOT';
    ---------------------------------------------------------------------
                                      Press [Enter] to close the uploader 
EOT
    my $d = <STDIN>;
    exit(0);
}

sub start {
    my $self = shift;

    $self->init;

    if(!defined($self->{config}->{wru_token})) {
        print <<"EOT";
--[ World of Tanks Replay Uploader ]---------------------------------

    Thanks for using the replay uploader! However, it seems this 
    is the first time you've ran this application, so we need to 
    take care of a few things first. 

    To make sure uploads to go the right place, please use your 
    wot-replays.org account details to log in. If you haven't 
    got an account yet, please visit http://www.wot-replays.org 
    and click the 'Register' button.

EOT

        my $email;
        my $pass;
        my $auth = 0;
        while(!$auth) {
            print "\n", '    -- [ Log in to your wot-replays.org account ]--------------------', "\n";
            while(!$email) {
                print '    Email address', "\n";
                print '    > ';
                chomp($email = <STDIN>);
                if($email !~ /.*\@.*\.\w{2,3}$/) {
                    print '    Mmm no, no, that does not look like an email address at all, try again!', "\n";
                    $email = undef;
                }
            }
            while(!$pass) {
                print "\n", '    Password (and yes, it will echo on screen, sorry!)', "\n";
                print '    > ';
                chomp($pass = <STDIN>);
                if(length($pass) < 1) {
                    print '    Come on now, are you using a blank password? I do not think so, try again!', "\n";
                    $pass = undef;
                }
            }

            print "\n", '    Okay, let\'s see if we can get you logged in, hold on to your socks...', "\n", "\n";

            my $tx = $self->{ua}->post_form('http://www.wot-replays.org/wru/get_token' => {
                u => $email,
                p => $pass,
                tz => $self->{config}->{timezone},
            });

            if(my $res = $tx->success) {
                if($res->json->{ok} == 1) {
                    print q|    Looks like that went alright! |;
                    $self->{config}->{wru_token} = $res->json->{token};
                    if(my $fh = IO::File->new('>' . $self->{config}->{token_file})) {
                        $fh->print($self->{config}->{wru_token});
                        $fh->close;
                        print "\n", "\n";
                        $auth = 1;
                    } else {
                        print q|Except saving some information didn't...|, "\n";
                        print q|    This would be considered a fatal error, so please|, "\n", q|    inform Scrambled, and try this again later okay?|, "\n";
                        $self->consdie();
                    }
                } else {
                    print q|    Mmmnope, that didn't work out, an error occurred:|, "\n    ", $res->json->{error}, "\n";
                    $self->consdie() if($res->json->{term} == 1);
                    $auth = 0;
		    $email = undef;
		    $pass = undef;
                }
            } else {
                print q|    Uh, hmm, that's funny, it seems the website is down or|, "\n", q|    otherwise unable to respond. Try again later okay?|, "\n";
                $self->consdie();
            }
        }

        print "\n";
        my $wr = $self->{config}->{replay_path};
        my $tf = $self->{config}->{token_file};
        print << "EOT";
    ---------------------------------------------------------------------

    Your setup is complete, so you won't be seeing this ugly console 
    window again.  If you want to re-do the setup, simply remove this file:

    $tf

    And we'll re-do the setup. Oh, and as a last check, replays will be 
    scanned for in the following folder:

    $wr

    Now, when you hit enter, we'll go and hide this console window, and 
    will put the uploader in the system tray. Clicking the icon will bring 
    up a very simple window that shows a log of what's been going on. 
    
    To close the uploader, first click the icon so the window shows, 
    then close the window and there you go, it'll stop.

    ---------------------------------------------------------------------
                            Press [Enter] to close and start the uploader 
EOT
        chomp(my $dummy = <STDIN>);

        $self->{gui}->{dos} = Win32::GUI::GetPerlWindow();
        Win32::GUI::Hide($self->{gui}->{dos});

        $self->init_win32;
	$self->log('Starting...');
        Win32::GUI::Dialog();
        Win32::GUI::Show($self->{gui}->{dos});
    } else {
        $self->{gui}->{dos} = Win32::GUI::GetPerlWindow();
        Win32::GUI::Hide($self->{gui}->{dos});

        $self->init_win32;
	$self->log('Starting...');
        Win32::GUI::Dialog();
        Win32::GUI::Show($self->{gui}->{dos});
    }
}

1;
