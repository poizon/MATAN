package Giftec::MjPage;

use strict;
use lib qw(..);
use base qw(Giftec::Object);

__PACKAGE__->meta->setup(
    table   => 'mj_pages',

    columns => [
        id_pages     => { type => 'serial', not_null => 1 },
        date_pages   => { type => 'datetime' },
        name_pages   => { type => 'varchar', length => 80 },
        body_pages   => { type => 'text', length => 65535 },
        id_lang      => { type => 'varchar', length => 3 },
        id_cat       => { type => 'integer' },
        root_pages   => { type => 'character', default => '0', length => 1 },
        parent_pages => { type => 'integer', default => '0' },
        name_alt     => { type => 'varchar', length => 100 },
        publish      => { type => 'character', default => 'N', length => 1 },
        old_url     => { type => 'varchar', length => 60 },
        keywords     => { type => 'varchar', length => 300 },
    ],

    primary_key_columns => [ 'id_pages' ],
    unique_key => [ 'old_url' ],

    foreign_keys => [
        mj_cat => {
            class       => 'Giftec::MjCat',
            key_columns => { id_cat => 'id_cat' },
        },
    ],
);

1;

