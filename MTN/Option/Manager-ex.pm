package Giftec::MjContact::Manager;

use strict;
use utf8;
use base qw(Rose::DB::Object::Manager);
use lib qw(../..);
use Giftec::MjContact;

sub object_class { 'Giftec::MjContact' }

__PACKAGE__->make_manager_methods('contacts');

sub list_contacts {
    my ($class, %args) = @_;
    my $db = $args{'db'} || Giftec::Object->init_db;
    my $sth = $db->dbh->prepare( qq{SELECT a.id_contacts,a.company,a.name,a.email,a.tel,a.price,DATE_FORMAT(a.reqdate,'%d.%m.%Y %H:%i') reqdate
                                FROM mj_contacts a
                                ORDER BY a.id_contacts DESC
                                ;} );#LIMIT $args{limit_s},$args{limit_end}   
    $sth->execute;
    my $t = $sth->fetchall_arrayref;
    $sth->finish;
    return $t;
}

1;

