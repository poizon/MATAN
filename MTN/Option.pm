package MTN::Option;

use strict;
use lib qw(..);
use base qw(MTN::Object);

__PACKAGE__->meta->setup(
    table   => 'options',

    columns => [
        idoptions   => { type => 'integer', not_null => 1 },
        model       => { type => 'varchar', length => 45 },
        name       => { type => 'varchar', length => 45 },
        description => { type => 'text', length => 65535 },
        include     => { type => 'varchar', length => 1 },
        price       => { type => 'numeric', precision => 10, scale => '0' },
    ],

    primary_key_columns => [ 'idoptions' ],
);

1;

