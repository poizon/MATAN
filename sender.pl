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
my $cfg = parse_php("$path/config.php");
openPidFile("$path/.mypid");
my $pid = $$;
my $dbh = db_connect($cfg);
my $logfile = "$path/logfile.txt";
# глобальные переменные для хранения списка адресов, настроек сервера
my ($emails,$mailserver,$maillist);
# настройки почтового сервера
$mailserver = $dbh->selectrow_hashref(qq{SELECT mailhost,username,password,mail_from,
                                                timeout,mail_to,helo_domain
                                         FROM email_config WHERE id = 1});
# база адресов для рассылки
$emails = $dbh->selectall_arrayref(qq{SELECT email,code,DATE_FORMAT(date_reg,'%d.%m.%Y')
                                             FROM email_db WHERE subscribe = 1});
# выбираем рассылки которые должны быть отправлены сегодня
$maillist = $dbh->selectall_arrayref(qq{SELECT name,body,id_send,type FROM email_send WHERE activate<>'N'
                                            AND date_send =  DATE_FORMAT( CURRENT_TIMESTAMP( ) , '%Y-%m-%d' )});

for my $subscr(@$maillist) {
# если рассылка общая - отправляем сразу всем    
    if($subscr->[3] eq 'A') {
        # Отправляем рассылку
        send_mail($mailserver, $emails, $subscr->[0], $subscr->[1], $subscr->[2],$subscr->[3]);
    } # если персонифицированная, то отправляем каждому свое письмо
    else {
            for my $m(@$emails) {
                send_mail($mailserver, $m->[0], $subscr->[0], $subscr->[1], $subscr->[2],$subscr->[3]);
            }
    }
# обновляем статус рассылки и сбрасываем активацию
$dbh->do(qq{UPDATE email_send SET status = 'Y', activate='N' WHERE id_send = '$subscr->[2]'});
}

# чистим ща собой pid файл
END {unlink "$path/.mypid" if $pid==$$;};

### SUBS
sub send_mail {
    my ($ms,$email,$subject,$body,$id_send, $type) = @_;
    my $result;# для возврата результата в лог
    # создаем сессию SMTP
    my $smtp = Net::SMTP_auth->new($ms->{mailhost},
                                   Hello => $ms->{helo_domain},
                                   Timeout => $ms->{timeout},
                                   Debug => 0) or my_log('ERR', $!);
# пишем логи
    if($smtp) {
        my_log('connect','OK',$id_send);
    } else {
        my_log('ERR',$smtp->message());
    }

    $smtp->auth('CRAM-MD5', $ms->{username}, $ms->{password});
    my_log('auth',$smtp->message(),$id_send);

    $smtp->mail($ms->{mail_from});
    # общая рассылка
    if($type eq 'A') {
    # это выполнять в блоке eval
        eval { 
            for my $m(@$email) {
                $smtp->to($m->[0],{SkipBad => 1 });
            }
        };
    } # персонифицированная
    else {
        eval {        
            $smtp->recipient($email,{SkipBad => 1 });
        };
    }
        my_log('WARN',$@) if $@;# перехватываем исключения
    # общая рассылка
    if ($type eq 'A') {    
    # выполнять в блоке eval
        eval {$body = prepare_body($ms->{mail_from},$ms->{mail_to},$subject,$body);};
    } # персонифицированная
    else {
        eval {$body = prepare_body($ms->{mail_from},$email,$subject,$body);};    
    }
        my_log('WARN',$@) if $@;# перехватываем исключения
    $smtp->data();
    $smtp->datasend($body);
    $smtp->dataend();
    # пишем в лог последний ответ сервера через временную переменную
    my $tmp = $smtp->message();
    my_log('result',$tmp,$id_send);
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
    my $cfg = shift;
    my $dbh = DBI->connect_cached(
        "DBI:mysql:host=$cfg->{hostname};database=$cfg->{dbname}",
        $cfg->{username},
        $cfg->{password},
        { PrintError => 1, RaiseError => 0, mysql_enable_utf8 => 1 }
    );
    
    return $dbh ? $dbh : die "Can't connect to db";
}
# разбор файла пхп с конфигурацией
sub parse_php {
    my $file = shift;
    my %config;
# читаем пхп файл в хэш
    open( DB, "<:utf8", $file ) or my_log('ERR',$!);
    while (<DB>) {
        next if (/^<|>/);    # сразу пропускаем комментарии
        chomp;
        s/^\s+//;             # Убрать начальные пропуски
        s/\s+$//;             # Убрать конечные пропуски
        s/^\$//;             # Убрать начальные $
        s/;$//;             # Убрать конечные ;
        s/'//g;             # Убрать '
        next unless length;   # Что-нибудь осталось?
        my ( $key, $value ) = split( /\s*=\s*/, $_, 2 );
        $config{lc($key)} = $value if ( defined($key) && defined($value) );
    }

    return \%config;
}
# пишем логи в файл и в БД
sub my_log {
    my ($code, $msg, $id_send) = @_;
    $msg =~ s/\n/ /g;
    # если передан id пишем в БД
    if($id_send) {
        # проверяем есть ли запись с таким id_send в таблице с пустям полем date_send
        my $res = $dbh->selectrow_arrayref(qq{SELECT id FROM `email_log` WHERE `id_send` = '$id_send'
                                 AND `date_send` IS NOT NULL});
        # если записей нет, вставялем строку
        unless($res->[0]) {
            $dbh->do(qq{INSERT INTO `email_log` (id_send,date_send) VALUES('$id_send',CURRENT_TIMESTAMP)})
        }
        # в значении $code - передается имя столбца в БД
        # code IN (connect, auth, result)
        eval { $dbh->do(qq{UPDATE email_log SET $code = '$msg',date_send = CURRENT_TIMESTAMP  WHERE id_send = '$id_send'}); };
        # если ошибка записи в БД, то записать это
        if($@) {$dbh->do(qq{UPDATE email_log SET $code = 'Some error',date_send = CURRENT_TIMESTAMP  WHERE id_send = '$id_send'});}
    }
    else {
        open(LOG,">>",$logfile) || die "can't open log file: $!";
        print LOG localtime() . ':' . $code . ':' . $msg,"\n";
        close(LOG);
    }
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