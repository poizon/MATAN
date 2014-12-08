#!/usr/bin/perl -w
# 
# РАССЫЛКА version 1.0 
# Pavel Kupstov pavel@kuptsov.info
# Алгоритм:
use common::sense;
use Net::SMTP;
use DBI;
use MIME::Entity;
use MIME::Base64;
use Date::Format;
use Encode;
use HTML::Parser;
use IO::File;

## GLOBAL VARS ##
my $path = absPath('sender_ee.pl');
#DBI->trace('SQL');
openPidFile("$path/.mypid");
my $pid = $$;
#$host,$db,$user,$pass
my $dbh = db_connect('qiwi.giftec.ru','web','web','web');

my $logfile = "$path/logfile.txt";
# глобальные переменные для хранения списка адресов, настроек сервера
my ($emails,$mailserver,$maillist);

# настройки почтового сервера
my %ms = ( username => 'Report@giftec.ru', password => 'rR12345678',
          mailhost => 'dsrv.giftec.ru', mail_from => 'Report@giftec.ru',
          mail_to => 'p.kuptsov@giftec.ru' );

# выбираем рассылки которые должны быть отправлены сегодня
$maillist = $dbh->selectall_arrayref(qq{SELECT idorders,client,email,tel,options, model FROM orders WHERE status='0'});

for my $subscr(@$maillist) {
        my $body = get_body($subscr->[1], $subscr->[2], $subscr->[3],$subscr->[4],$subscr->[5]);
        $body = prepare_body($ms{mail_from},$ms{mail_to},'Конфигуратор. Заявка # ' . $subscr->[0],$body);
        send_mail($body);
# обновляем статус рассылки и сбрасываем активацию
$dbh->do(qq{UPDATE orders SET status = '1' WHERE idorders = '$subscr->[0]'});
}

# чистим ща собой pid файл
END {unlink "$path/.mypid" if $pid==$$;};

### SUBS ####
sub get_body {
    my ($client,$email,$tel,$options, $model) =@_;
    
    $model = $dbh->selectrow_hashref(qq{SELECT model FROM web.printers where idprinters=$model});

    $options = $dbh->selectall_arrayref(qq{SELECT `name`,`price` FROM web.options where model = '$model->{model}' and idoptions IN($options)});
    
    my $body = qq(
    <table>
    <tr><td>Клиент: $client </td><td>Email: $email Тел: $tel</td></tr>
    <tr><td colspan="2">Интересовался моделью: $model->{model} </td></tr>
    <tr><td colspan="2">Выбрал опции:</td></tr>
    <tr  bgcolor="#a9afaf"><td>Название опции</td><td>Цена</td></tr>
    );
    
    for my $opt(@$options) {
        $body.= qq(<tr><td>$opt->[0]</td><td>$opt->[1]</td></tr>);
    }
    
    $body.= qq(</table>);
    
    return $body;
}

sub send_mail {
    my $body = shift;
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
      
    $smtp->mail($ms{mail_from});
    
    eval {        
            $smtp->to($ms{mail_to},{SkipBad => 1 });
        };
    
    my_log('WARN',$@) if $@;# перехватываем исключения
    
    #eval {$body = prepare_body($ms{mail_from},$ms{mail_to},'Заявка от конфигуратора',$body);};    
    #my_log('WARN',$@) if $@;# перехватываем исключения
    
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


# коннект к бд
sub db_connect {
    my ($host,$db,$user,$pass) = @_;
    my $dbh = DBI->connect(
        "DBI:mysql:host=$host;database=$db",
        $user,
        $pass,
        { PrintError => 1, RaiseError => 0, mysql_enable_utf8 => 1 }
    );
    
    return $dbh ? $dbh : die "Can't connect to db";
}

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