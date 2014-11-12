package MTN::Printer;

use strict;
use lib qw(..);
use base qw(MTN::Object);

__PACKAGE__->meta->setup(
    table   => 'printers',

    columns => [
        idprinters  => { type => 'integer', not_null => 1 },
        model       => { type => 'varchar', length => 45 },
        description => { type => 'text', length => 65535 },
        price       => { type => 'numeric', precision => 10, scale => '0' },
        foto_main   => { type => 'varchar', length => 45 },
    ],

    primary_key_columns => [ 'idprinters' ],
);

1;

