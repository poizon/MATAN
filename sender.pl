#!/usr/bin/perl -w
# 
# РАССЫЛКА version 1.0 
# Pavel Kupstov pavel@kuptsov.info
# Алгоритм:
# расылка confirmation писем если у письма статус - Новый (0),
# затем отправка активных рассылок по адресам со статусом 1
#use lib qw(/home/giftec/www/site1/public_html/sender/lib);
use common::sense;
use Net::SMTP_auth;
use DBI;
#use DBD::mysql;
use MIME::Entity;
use MIME::Base64;
use Date::Format;
use Encode;
use HTML::Parser;
use IO::File;

## GLOBAL VARS ##
my $path = absPath('sender.pl');

openPidFile("$path/.mypid");
my $pid = $$;
#$host,$db,$user,$pass
my $dbh = db_connect('qiwi.giftec.ru','web','web','web');

my $logfile = "$path/logfile.txt";
# глобальные переменные для хранения списка адресов, настроек сервера
my ($emails,$mailserver,$maillist);

# настройки почтового сервера
my %mailserver = (
                  mailhost => 'dsrv.giftec.ru',
                  username => 'Report@giftec.ru',
                  password => 'rR12345678',
                  mail_from => 'GIFTEC <Report@giftec.ru>',
                  timeout   => 10,
                  helo_domain => 'giftec.ru',
                  mail_to     => 'pavel@giftec.ru'
                  );

# выбираем рассылки которые должны быть отправлены сегодня
$maillist = $dbh->selectall_arrayref(qq{SELECT idorders,client,email,tel,options, model FROM orders WHERE status='0'});

for my $subscr(@$maillist) {
# если рассылка общая - отправляем сразу всем    
# Отправляем рассылку
        send_mail(\%mailserver, $subscr->[1], $subscr->[2], $subscr->[3],$subscr->[4],$subscr->[5]);
# обновляем статус рассылки и сбрасываем активацию
#$dbh->do(qq{UPDATE orders SET status = '1' WHERE idorders = '$subscr->[0]'});
}

# чистим ща собой pid файл
END {unlink "$path/.mypid" if $pid==$$;};

### SUBS
sub send_mail {
    my ($ms,$client,$email,$tel,$options,$model) = @_;
    my $result;# для возврата результата в лог
    my $body = "$client $email $tel $options $model";
    # создаем сессию SMTP
    my $smtp = Net::SMTP_auth->new($ms->{mailhost},
                                   Hello => $ms->{helo_domain},
                                   Timeout => $ms->{timeout},
                                   Debug => 1) or my_log('ERR', $!);
# пишем логи
    if($smtp) {
        my_log('connect','OK');
    } else {
        my_log('ERR',$smtp->message());
    }

    $smtp->auth('CRAM-MD5', $ms->{username}, $ms->{password});
    my_log('auth',$smtp->message());

    $smtp->mail($ms->{mail_from});
    # это выполнять в блоке eval
        eval { 
            for my $m(@$email) {
                $smtp->to($m->[0],{SkipBad => 1 });
            }
        };
    
        my_log('WARN',$@) if $@;# перехватываем исключения
    # выполнять в блоке eval
    eval {$body = prepare_body($ms->{mail_from},$ms->{mail_to},'Заявка от конфигуратора',$body);}; ####
    
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
# самая важная функция
# парсим текст сообщения, отделяем все IMG - на лету конвертим в нужный формат
# в зависимости от расширения рисунка - ставим правильный content-type (Type => 'image/jpeg' 'image/png', и т.п.)
# html конвертим в base64 отправлять как text/html, текст выдергиваем из собщения и отправляем в text/plain base64
sub make_body {
    my ($mime, $message) = @_;
    my (%images,$data,$is_html);
    # не пугайтесь абракадабры - сделал анонимные функции чтобы был виден хэш %images без заморочек со ссылками
    my $p = HTML::Parser->new(  api_version => 3,
                                start_h => [sub {my ($tag,$attr) = @_;
                                                 $is_html = 1 if defined $tag;# текст в html если нашли хотя бы 1 тэг
                                                 if($tag eq 'img') {
                                                    my $image = $attr->{src};
                                                    $image =~ s/\//@/g;
                                                    $images{$image} = $attr->{src};
                                                 }}, "tagname, attr"],
                                text_h  => [sub {$data .= shift;},"dtext"]
                            );
    # парсим
    $p->parse($message);
    # замена картинок в строке на cid'ы
    for my $image(keys %images) {
        $message =~ s/$images{$image}/cid:$image/g;
    }
    # создаем текстовый формат
    $mime->attach(  Type => 'text/plain',
                    Charset  => 'utf-8',
                    Encoding => 'base64',
                    Data     => $data
                );
    # делаем возврат тут, если текст - чистый plain/text
    return $mime unless $is_html;
    # создаем формат html
    $mime->attach( Type => 'text/html',
                   Charset  => 'utf-8',
                   Encoding => 'base64',
                   Data     => $message
                );
    
    # аттачим все найденные картинки
    for my $image(keys %images) {
    $mime->attach(  Type => 'image/jpeg',
                    Encoding => 'base64',
                    Path     => "$path/$images{$image}",
                    'Content-ID' => "<$image>"
                );
        }
    return $mime;
}
# коннект к бд
sub db_connect {
    my ($host,$db,$user,$pass) = @_;
    my $dbh = DBI->connect_cached(
        "DBI:mysql:host=$host;database=$db",
        $user,
        $pass,
        { PrintError => 1, RaiseError => 0, mysql_enable_utf8 => 1 }
    );
    
    return $dbh ? $dbh : die "Can't connect to db";
}
## разбор файла пхп с конфигурацией
#sub parse_php {
#    my $file = shift;
#    my %config;
## читаем пхп файл в хэш
#    open( DB, "<:utf8", $file ) or my_log('ERR',$!);
#    while (<DB>) {
#        next if (/^<|>/);    # сразу пропускаем комментарии
#        chomp;
#        s/^\s+//;             # Убрать начальные пропуски
#        s/\s+$//;             # Убрать конечные пропуски
#        s/^\$//;             # Убрать начальные $
#        s/;$//;             # Убрать конечные ;
#        s/'//g;             # Убрать '
#        next unless length;   # Что-нибудь осталось?
#        my ( $key, $value ) = split( /\s*=\s*/, $_, 2 );
#        $config{lc($key)} = $value if ( defined($key) && defined($value) );
#    }
#
#    return \%config;
#}
# пишем логи в файл и в БД
sub my_log {
    my ($code, $msg) = @_;
    $msg =~ s/\n/ /g;
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
# проверка - запущен ли процесс
sub openPidFile { 
     my $file=shift;# имя pid файла 
     return 0 if $^O eq 'MSWin32';# не создаем на win машинах 
        if(-e $file) {# файл существует, пытаемся прочитать 
            my $fh=IO::File->new($file) || return; 
            my $pid=<$fh>; 
            # скрипт уже работает, если kill 0 возвращает true 
            # при этом по kill (0,pid) процессор не убивается, а проверяется 
            # на наличие в таб.процессов 
            die "Script already running with PID $pid" if (kill (0,$pid)); 
            # если на предыдущей строке не "умерли", значит выводим сообщени
            # что проц. "зомби", и удаляем pid-файл 
            warn "Removing PID file for defunct script process $pid.\n"; 
            die "Can't unlink PID file $file" unless -w $file && unlink $file; 
          } 
        # если досюда дошли, значит либо новый запуск, либо убрали "зомбака". 
        my $fh=IO::File->new($file,O_WRONLY|O_CREAT|O_EXCL,0644) 
                                            or die "Can't create $file: $!\n"; 
        # вносим в pid файл id текущего процесса 
        print $fh $$; 
    }