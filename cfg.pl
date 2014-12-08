#!/usr/bin/env perl
use common::sense;
use Mojolicious::Lite;
use lib qw(.);
use MTN::DB;
use MTN::Option::Manager;
use MTN::Picture::Manager;
use MTN::Printer::Manager;
use MTN::Inform::Manager;
use MTN::Order::Manager;
#use Data::Dumper;

# глобальные настройки
my $cfg = plugin 'Config' => {file => 'app.conf'};
# db connect
MTN::DB->registry->add_entry(%{$cfg->{db}});
# логирование
my $log = Mojo::Log->new(
   path  => $cfg->{logfile},
   level => $cfg->{log_level},
);

get '/' => sub {
  my $self   = shift;
  my $prn = MTN::Printer::Manager->get_printers(limit => 4);
  my $prn2 = MTN::Printer::Manager->get_printers(limit => 1, offset => 4);
  $self->stash(row1 => $prn,
               row2 => $prn2);
  $self->render('index');  
};

get '/model/:model' => {model => '1'} => sub {
  my $self   = shift;
  my $model   = $self->param('model') || '1';
  $self->session(id => $model);# пишем в куки просматриваемую модель
  $model =~ s/[^0-9]+//g;
  my $prn = MTN::Printer->new(idprinters => $model);
  
  unless ($prn->load(speculative => 1)) {
    $self->redirect_to('/');
  }
  
  my $pic = MTN::Picture::Manager->get_pictures(query => [model => $prn->model]);
  my $opt = MTN::Option::Manager->get_options(query => [model => $prn->model]);
  $self->stash(
               model     => $prn->model,
               foto_main => $prn->foto_main,
               descr     => $prn->description,
               pictures  => $pic,
               options   => $opt
               );
  $self->render('matan');
};

post '/config' => sub {
  my $self   = shift;
  my $model   = $self->session('id') || '1';# читаем id из куков
  my $usopt = $self->every_param('usopt');
  # сохраняем в сессию список опций через запятую
  my $sess_opt = join(',',@$usopt);
  $self->session(options => $sess_opt);
  
  my $prn = MTN::Printer->new(idprinters => $model);
  
  unless ($prn->load(speculative => 1)) {
    $self->redirect_to('/');
  }
  
  my $pic = MTN::Picture::Manager->get_pictures(query => [model => $prn->model]);
  my $opt = MTN::Option::Manager->get_options(query => [model => $prn->model, include => 1]);

  my $selopt = [];
  # если есть хотя бы одна выбранная опция
  if ($usopt->[0]) {
     $selopt = MTN::Option::Manager->get_options(query => [idoptions => $usopt]);
  }
  
  $self->stash(
               model     => $prn->model,
               id        => $model,
               foto_main => $prn->foto_main,
               descr     => $prn->description,
               pictures  => $pic,
               options   => $opt,
               selopt     => $selopt,
               );
  $self->render('config');  
};

get '/download' => sub {
  my $self   = shift;
  my $model   = $self->session('id') || '1';# читаем id из куков
  $model =~ s/[^0-9]+//g;
  my $prn = MTN::Printer->new(idprinters => $model);
  $prn->load;
  my $pic = MTN::Picture::Manager->get_pictures(query => [model => $prn->model]);
  
  $self->stash(
               id        => $model,
               model     => $prn->model,
               foto_main => $prn->foto_main,
               descr     => $prn->description,
               pictures  => $pic,
              );
  
  $self->render('download');  
};

get '/service' => sub {
  my $self   = shift;
  my $model   = $self->session('id') || '1';# читаем id из куков
  $model =~ s/[^0-9]+//g;
  my $prn = MTN::Printer->new(idprinters => $model);
  $prn->load;
  my $pic = MTN::Picture::Manager->get_pictures(query => [model => $prn->model]);
  
  $self->stash(
               id        => $model,
               model     => $prn->model,
               foto_main => $prn->foto_main,
               descr     => $prn->description,
               pictures  => $pic,
              );
  $self->render('service'); 
};

get '/info/:id' => => {id => '1'} => sub {
  my $self   = shift;
  my $model   = $self->session('id') || '1';# читаем id из куков
  my $id = $self->param('id');
  $id =~ s/[^0-9]+//g;
  my $info = MTN::Inform->new(idinform => $id);
  
  unless ($info->load(speculative => 1)) {
    $self->redirect_to('/');
  }
  
  $self->stash(
               id   => $id,
               model => $model,
               info => $info,
              );
  
  $self->render('info');
  
};

post '/diller' => sub {
  my $self   = shift;
  my $model   = $self->session('id');# читаем модель из куков
  my $opt = $self->session('options');# читаем опции из куков
  my $client = substr($self->param('client'),0,98);
  my $email = substr($self->param('email'),0,49);
  
  my $tel = $self->param('tel');
  $tel =~ s/[^0-9]+//g;
  $tel = substr($tel,0,14);
  
  my $ord = MTN::Order->new(client => $client,tel => $tel, email => $email, options => $opt, model => $model, status => 0);
  $ord->save;
  $self->flash(message => 'Спасибо, ' . $client . '! Мы свяжемся с Вами в самое ближайшее время!');
  $self->redirect_to('/info/16.html');
};

app->secrets([$cfg->{secret}]);
app->log->level($cfg->{log_level});
app->sessions->default_expiration($cfg->{session_exp});
app->start;

