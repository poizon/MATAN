package MTN::Inform;

use strict;
use lib qw(..);
use base qw(MTN::Object);

__PACKAGE__->meta->setup(
    table   => 'inform',

    columns => [
        idinform => { type => 'integer', not_null => 1 },
        name     => { type => 'varchar', length => 70 },
        picture  => { type => 'varchar', length => 45 },
        descript => { type => 'text', length => 65535 },
    ],

    primary_key_columns => [ 'idinform' ],
);

1;

