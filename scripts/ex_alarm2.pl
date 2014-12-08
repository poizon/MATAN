#!/usr/bin/perl -w
#
# программа для рассылки предупреждений
# Автор П.Купцов P.Kuptsov@giftec.ru
use strict;
use utf8;
use Net::SMTP;
use MIME::Entity;
use MIME::Base64;
use Date::Format;
use Encode;

my %ms = ( username => 'Report@giftec.ru', password => 'rR12345678', mailhost => 'dsrv.giftec.ru', mail_from => 'Report@giftec.ru', mail_to => 'p.kuptsov@giftec.ru' );
my $path = absPath('alarm.pl');
my $logfile = "$path/logfile.alarm.txt";

send_mail('Alarm! Высокая температура!','Высокая температура на сервере DSRV!');
### SUBS
sub send_mail {
    my ($subject,$body) = @_;
    my $result;# для возврата результата в лог
    # создаем сессию SMTP
    my $smtp = Net::SMTP->new($ms{mailhost},
                                   Hello => 'dsrv.giftec.ru',
                                   Timeout => 20,
                                   Debug => 0) or my_log('ERR', $!);
# пишем логи
    if($smtp) {
        my_log('connect','OK');
    } else {
        my_log('ERR',$smtp->message());
    }
    
    #print $smtp->auth_types();
    
   # $smtp->auth('LOGIN', $ms{username}, $ms{password});
   # my_log('auth',$smtp->message());
    
    $smtp->mail($ms{mail_from});
    
    eval {        
            $smtp->to($ms{mail_to},{SkipBad => 1 });
        };
    
    my_log('WARN',$@) if $@;# перехватываем исключения
    
    eval {$body = prepare_body($ms{mail_from},$ms{mail_to},$subject,$body);};    
    my_log('WARN',$@) if $@;# перехватываем исключения
    
    $smtp->data();
    $smtp->datasend($body);
    $smtp->dataend();
    # пишем в лог последний ответ сервера через временную переменную
    my $tmp = $smtp->message();
    my_log('result',$tmp);
    $smtp->quit;
}
# готовим заголовок
sub make_subject {
    my $string = shift;
       $string = encode_utf8($string);
       $string = encode_base64($string);
    chomp($string);
    return '=?UTF-8?B?'.$string.'?=';
}
# готовим тело сообщения
sub prepare_body {
    my ($from,$to,$subject, $message) = @_; # строки из БД: заголовок и тело сообщения и т.п.
    # форматируем дату ##
    my @lt =  localtime();
    my $date =  strftime("%a, %e %b %Y %T %z",@lt);
    # фишечки
    my $misc = qq(User-Agent: SquirrelMail/1.4.13\nImportance: Normal);
    # заголовок
       $subject = make_subject($subject);   
    # готовим сообщение   
    my $mime = MIME::Entity->build( From      => $from,
                                    To         => $to,
                                    Subject    => $subject,
                                    Type       => 'multipart/alternative',
                                    Date       => $date,
                                    'X-Mailer' => 'G.mailer 1.0'
                            );   
    # формируем тело сообщения
    $mime = make_body($mime,$message);
    # сформированное сообщение
    return $mime->as_string;
}

sub make_body {
    my ($mime, $message) = @_;
    
    # создаем текстовый формат
    $mime->attach(  Type => 'text/plain',
                    Charset  => 'utf-8',
                    Encoding => 'base64',
                    Data     => $message
                );
    # создаем формат html
    $mime->attach( Type => 'text/html',
                   Charset  => 'utf-8',
                   Encoding => 'base64',
                   Data     => $message
                );
    
    return $mime;
}

# пишем логи в файл
sub my_log {
    my ($code, $msg) = @_;
    $msg =~ s/\n/ /g;
    # если передан id пишем в БД
    open(LOG,">>",$logfile) || die "can't open log file: $!";
    print LOG localtime() . ':' . $code . ':' . $msg,"\n";
    close(LOG);
    exit if $code eq 'ERR';
    return 1;
}

# абсолютный путь (чтобы найти конфиг если запускаем с крона)
sub absPath {
    my $file = shift;
    $0 =~ /(.+)$file$/;
    my $path = $1;
    $path = './' unless defined $path;
    return $path;
}