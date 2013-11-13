package WR::Provider::ServerFinder;
use Mojo::Base '-base';

use constant SERVERS => {
    'na' => 'worldoftanks.com/community/accounts/%d-%s/',
    'eu' => 'worldoftanks.eu/community/accounts/%d-%s/',
    'ru' => 'worldoftanks.ru/community/accounts/%d-%s/',
    'vn' => 'portal-wot.go.vn/community/accounts/%d-%s/',
    'kr' => 'worldoftanks.kr/community/accounts/%d-%s/',
    'sea' => 'worldoftanks.asia/community/accounts/%d-%s/',
    };

use constant SERVER_INDICES => {
    0   => 'ru',
    1   => 'eu',
    2   => 'na',
    3   => 'sea',
    4   => 'vn',
    5   => 'kr',
};

use constant SERVER_ID_MAPPING => {
    'ru'    => [ 0,            499999999 ],
    'eu'    => [ 500000000,    999999999 ],
    'na'    => [ 1000000000,  1499999999 ],
    'sea'   => [ 2000000000,  2499999999 ],
    'vn'    => [ 2500000000,  2999999999 ],
    'kr'    => [ 3000000000,  3499999999 ],
};

sub get_server_by_id {
    my $self = shift;
    my $id   = shift;

    foreach my $server (keys(%{__PACKAGE__->SERVER_ID_MAPPING})) {
        my $v = __PACKAGE__->SERVER_ID_MAPPING->{$server};
        return $server if($id >= $v->[0] && $id <= $v->[1]);
    }
    return sprintf('unknown:%d', $id);
}

1;
