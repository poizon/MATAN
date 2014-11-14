#!/usr/bin/env perl
use common::sense;
use Mojolicious::Lite;
use Digest::MD5 qw (md5_hex);
use lib qw(.);
use MTN::DB;
use MTN::Option::Manager;
use MTN::Picture::Manager;
use MTN::Printer::Manager;
use Data::Dumper;

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
  $model =~ s/[^0-9]+//g;
  my $usopt = $self->every_param('usopt');
  my $prn = MTN::Printer->new(idprinters => $model);
  $prn->load;
  my $pic = MTN::Picture::Manager->get_pictures(query => [model => $prn->model]);
  my $opt = MTN::Option::Manager->get_options(query => [model => $prn->model, include => 1]);
  my $selopt = MTN::Option::Manager->get_options(query => [idoptions => $usopt]);
  #$log->info(Dumper(@usopt));
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
  my $opt = MTN::Option::Manager->get_options(query => [model => $prn->model, include => 1]);
  $self->stash(
               id        => $model,
               model     => $prn->model,
               foto_main => $prn->foto_main,
               descr     => $prn->description,
               pictures  => $pic,
               options   => $opt,
              );
  
  $self->render('download');  
};

app->secrets([$cfg->{secret}]);
app->log->level($cfg->{log_level});
app->sessions->default_expiration($cfg->{session_exp});
app->start;

### SUBS ###
