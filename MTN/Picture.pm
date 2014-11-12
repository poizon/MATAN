package MTN::Picture;

use strict;
use lib qw(..);
use base qw(MTN::Object);

__PACKAGE__->meta->setup(
    table   => 'pictures',

    columns => [
        idpic    => { type => 'integer', not_null => 1 },
        img      => { type => 'varchar', length => 45 },
        name     => { type => 'varchar', length => 45 },
        descript => { type => 'varchar', length => 45 },
        model => { type => 'varchar', length => 45 }
    ],

    primary_key_columns => [ 'idpic' ],
);

1;

