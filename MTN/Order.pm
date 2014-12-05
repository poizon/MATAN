package MTN::Order;

use strict;
use lib qw(..);
use base qw(MTN::Object);

__PACKAGE__->meta->setup(
    table   => 'orders',

    columns => [
        idorders => { type => 'serial', not_null => 1 },
        client   => { type => 'varchar', length => 100 },
        tel      => { type => 'varchar', length => 15 },
        email    => { type => 'varchar', length => 50 },
        options  => { type => 'varchar', length => 150 },
        model    => { type => 'integer'},
    ],

    primary_key_columns => [ 'idorders' ],
);

1;

