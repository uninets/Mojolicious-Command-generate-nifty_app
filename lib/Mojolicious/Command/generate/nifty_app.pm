package Mojolicious::Command::generate::nifty_app;

use strict;
use warnings;
use Mojo::Base 'Mojolicious::Command';
use Mojo::Util qw(class_to_path class_to_file);
use String::Random qw(random_string);

our $VERSION = 0.03;

has description => "Generate Mojolicious application directory structure.\n";
has usage       => "usage: $0 generate nifty_app [NAME]\n";

sub run {
    my ($self, $class) = @_;

    if (not $class =~ /^[A-Z](?:\w|::)+$/){
        die 'Your application name has to be a well formed (camel case) Perl module name like MyApp::Nifty.';
    }

    # get paths to create in ./lib
    my $model_namespace      = "${class}::DB";
    my $controller_namespace = "${class}::Controller";

    # get app lib path from class name
    my $name = class_to_file $class;
    my $app  = class_to_path $class;

    # script
    $self->render_to_rel_file('script', "$name/script/$name", $class);
    $self->chmod_file("$name/script/$name", 0744);

    # templates, static and assets
    $self->render_to_rel_file('static', "$name/public/index.html");
    $self->render_to_rel_file('style', "$name/public/style.css");
    $self->render_to_rel_file('layout', "$name/templates/layouts/nifty.html.ep");
    $self->render_to_rel_file('login_form', "$name/templates/auth/login.html.ep");
    $self->render_to_rel_file('welcome_template', "$name/templates/example/welcome.html.ep");

    # application class
    my $model_name = class_to_file $model_namespace;
    $self->render_to_rel_file('appclass', "$name/lib/$app", $class, $controller_namespace, $model_namespace, $model_name, random_string('s' x 64));

    # controllers
    my $example_controller = class_to_path "${controller_namespace}::Example";
    my $auth_controller    = class_to_path "${controller_namespace}::Auth";
    $self->render_to_rel_file('example_controller', "$name/lib/$example_controller", "${controller_namespace}::Example");
    $self->render_to_rel_file('auth_controller', "$name/lib/$auth_controller", "${controller_namespace}::Auth");

    # models
    my $schema = class_to_path $model_namespace;
    $self->render_to_rel_file('schema', "$name/lib/$schema", $model_namespace);
    my $usermodel = class_to_path "${model_namespace}::Result::User";
    $self->render_to_rel_file('users_model', "$name/lib/$usermodel", $model_namespace);

    # db_deploy_script
    $self->render_to_rel_file('db_deploy', "$name/script/deploy_$model_name", $model_namespace, $model_name);
    $self->chmod_file("$name/script/deploy_$model_name", 0744);

    # tests
    $self->render_to_rel_file('test', "$name/t/basic.t", $class );

    # config
    $self->render_to_rel_file('config', "$name/config.yml", $model_name);

    # share (to play with DBIx::Class::Migration nicely
    $self->create_rel_dir("$name/share");

    return 1;
}

1;

__DATA__

@@ script
% my $class = shift;
#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

# Start command line interface for application
require Mojolicious::Commands;
Mojolicious::Commands->start_app('<%= $class %>');

@@ schema
% my $class = shift;
use utf8;
package <%= $class %>;

use strict;
use warnings;

our $VERSION = 0.01;

use base 'DBIx::Class::Schema';

__PACKAGE__->load_namespaces;

1;

@@ appclass
% my $class                = shift;
% my $controller_namespace = shift;
% my $model_namespace      = shift;
% my $model_name           = shift;
% my $secret               = shift;
package <%= $class %>;
use Mojo::Base 'Mojolicious';
use YAML;
use DBIx::Connector;
use <%= $model_namespace %>;

# This method will run once at server start
sub startup {
    my $self = shift;

    # default config
    my %config = (
        database => {
            driver => 'SQLite',
            dbname => 'share/<%= $model_name %>.db',
            dbuser => '',
            dbpass => '',
            dbhost => '',
            dbport => 0,
        },
        session_secret => '<%= $secret %>',
        loglevel => 'info',
        hypnotoad => {
            listen => ['http://*:8080'],
        },
    );

    # load yaml file
    my $config_file = 'config.yml';
    my $config = YAML::LoadFile($config_file);

    # merge default value with loaded config
    @config{ keys %$config } = values %$config;

    # set application config
    $self->config(\%config);
    # set sectret
    $self->secret($self->config->{session_secret});
    # set loglevel
    $self->app->log->level($self->config->{loglevel});

    # Documentation browser under "/perldoc"
    $self->plugin('PODRenderer');

    # database connection prefork save with DBIx::Connector
    my $connector = DBIx::Connector->new(build_dsn($self->config->{database}));
    $self->helper(
        model => sub {
            my ($self, $resultset) = @_;
            my $dbh = <%= $model_namespace %>->connect( sub { return $connector->dbh } );
            return $resultset ? $dbh->resultset($resultset) : $dbh;
        }
    );

    # Router
    my $r = $self->routes;
    $r->namespaces(["<%= $controller_namespace %>"]);

    # Normal route to controller
    $r->get('/')              ->to('example#welcome');
    $r->get('/login')         ->to('auth#login');
    $r->get('/logout')        ->to('auth#logout');
    $r->post('/authenticate') ->to('auth#authenticate');
}

# build dsn
sub build_dsn {
    my $config = shift;

    return 'dbi:'
        . $config->{driver}
        . ':dbname='
        . $config->{dbname}
        . ';host='
        . $config->{dbhost}
        . ';port='
        . $config->{dbport};
}

1;

@@ users_model
% my $class = shift;
use utf8;
package <%= $class %>::Result::User;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components('InflateColumn::DateTime');
__PACKAGE__->table('users');

__PACKAGE__->add_columns(
    'id',
    {
        data_type         => 'integer',
        is_auto_increment => 1,
        is_nullable       => 0,
        sequence          => 'users_id_seq',
    },
    'login',
    { data_type => 'varchar', is_nullable => 0, size => 255 },
    'email',
    { data_type => 'varchar', is_nullable => 0, size => 255 },
    'password',
    { data_type => 'varchar', is_nullable => 0, size => 255 },
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->add_unique_constraint('users_email_key', ['email']);
__PACKAGE__->add_unique_constraint('users_login_key', ['login']);

1;

@@ db_deploy
% my $class = shift;
% my $name = shift;
#!/usr/bin/env perl

use strict;
use warnings;
use lib 'lib';
use Getopt::Long;
use <%= $class %>;

my $db = 'share/<%= $name %>.db';
my $driver = 'SQLite';
my $user = '';
my $pass = '';
my $host = '';
my $port = 0;

my $result = GetOptions(
    'h|host=s' => \$host,
    'p|port=i' => \$port,
    'u|user=s' => \$user,
    'p|pass=s' => \$pass,
    'd|db=s' => \$db,
    'm|driver=s' => \$driver,
);

my $dsn_head = "dbi:$driver:dbname=$db;";
my $dsn_host = $host ? "host=$host;" : '';
my $dsn_port = $port ? "port=$port;" : '';

my $dsn = $dsn_head . $dsn_host . $dsn_port;

my $schema = <%= $class %>->connect($dsn, $user, $pass);
$schema->deploy;

# create default user:
# username: admin
# password: password
$schema->resultset('User')->create({
    login => 'admin',
    email => 'admin@example.com',
    password => '$6$salt$IxDD3jeSOb5eB1CX5LBsqZFVkJdido3OUILO5Ifz5iwMuTS4XMS130MTSuDDl3aCI6WouIL9AjRbLCelDCy.g.'
});

exit 0;

@@ login_form
%% layout 'nifty';
%% title 'Login';
%%= form_for '/authenticate' => ( method => 'POST', class => 'well' ) => begin
    <label>Username</label>
    %%= text_field 'username', class => 'span3', type => 'text'
    <label>Password</label>
    %%= password_field 'password'
    <br />
    %%= submit_button 'Login', class => 'btn'
%% end

@@ auth_controller
% my $class = shift;
package <%= $class %>;
use Mojo::Base 'Mojolicious::Controller';
use Crypt::Passwd::XS;

sub login {
    my $self = shift;
    $self->render();
}

sub authenticate {
    my $self = shift;

    my $username = $self->param('username');
    my $password = $self->param('password');

    if ($self->_authenticate_user($username, $password)){
        $self->session( authenticated => 1, username => $username );
        $self->flash( type => 'notice', msg => 'Logged in!' );
        $self->redirect_to('/');
    }
    else {
        $self->flash( type => 'error', msg => 'Use "admin" and "password" to log in.' );
        $self->redirect_to('/login');
    }

}

sub logout {
    my $self = shift;

    $self->session( username => undef, authenticated => undef, role => undef );
    $self->flash( type => 'notice', msg => 'Logged out!' );

    $self->redirect_to('/');
}

sub _authenticate_user {
    my ($self, $username, $password) = @_;

    my $user = $self->model('User')->find({ login => $username });
    my $salt = (split '\$', $user->password)[2];

    # no salt, no user
    return 0 unless $salt;

    # replace this check with something sane
    return Crypt::Passwd::XS::unix_sha512_crypt($password, $salt) eq $user->password;
}

1;

@@ example_controller
% my $class = shift;
package <%= $class %>;
use Mojo::Base 'Mojolicious::Controller';

# This action will render a template
sub welcome {
    my $self = shift;

    $self->render();
}

1;

@@ welcome_template
%% layout 'nifty';
%% title 'Welcome';
<h3>Welcome to Mojolicious</h3>
This page was generated from the template "templates/example/welcome.html.ep"
and the layout "templates/layouts/default.html.ep",
<a href="<%%== url_for %>">click here</a> to reload the page or
<a href="/index.html">here</a> to move forward to a static page.

@@ layout
<!DOCTYPE html>
<html>
    <head>
        %%= stylesheet '/style.css'
        <title>
            <%%= title %>
        </title>
    </head>
    <body>
        <div id="container">
            <div id="user_header">
                %% if (my $username = session 'username'){
                    %%= "logged in as $username"
                    %%== q{<a href="/logout">logout</a>}
                %% } else {
                    %%== q{<a href="/login">login</a>}
                %% }
            </div>
            %% my $flash_type = flash 'type';
            %% my $flash_msg  = flash 'msg';
            %% if ($flash_type && $flash_msg){
                <div id="flash_<%%= $flash_type %>"><%%= $flash_msg %></div>
            %% }
            <%%= content %>
        </div>
    </body>
</html>

@@ static
<!DOCTYPE html>
<html>
    <head>
        <link href="/style.css" media="screen" rel="stylesheet">
        <title>Welcome to the Mojolicious real-time web framework!</title>
    </head>
    <body>
        <div id="container">
                <h3>Welcome to the Mojolicious real-time web framework!</h3>
                This is the static document "public/index.html",
                <a href="/">click here</a> to get back to the start.
        </div>
    </body>
</html>

@@ style
body {
  background-color: #4B7399;
  font-family: Verdana, Helvetica, Arial;
  font-size: 14px;
}

a img {
  border: none;
}

a {
  color: #0000FF;
}

.clear {
  clear: both;
  height: 0;
  overflow: hidden;
}

#container {
  width: 75%;
  margin: 0 auto;
  background-color: #FFF;
  padding: 20px 40px;
  border: solid 1px black;
  margin-top: 20px;
}

#user_header {
  float: right;
}

#flash_notice, #flash_error, #flash_alert {
  padding: 5px 8px;
  margin: 10px 0;
  width: 400px;
}

#flash_notice {
  background-color: #CFC;
  border: solid 1px #6C6;
}

#flash_error, #flash_alert {
  background-color: #FCC;
  border: solid 1px #C66;
}

@@ test
% my $class = shift;
use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

my $t = Test::Mojo->new('<%= $class %>');
$t->get_ok('/')->status_is(200)->content_like(qr/Mojolicious/i);
$t->get_ok('/login')->status_is(200)->content_like(qr/Username/i)->content_like(qr/Password/i);
$t->post_form_ok('/authenticate' => { username => 'admin', password => 'password' })
    ->status_is(302)
    ->get_ok('/')->status_is(200)
    ->element_exists('div#user_header')->content_like(qr/logged in as admin/i);

done_testing();

@@ config
% my $db_name = shift;
database:
  driver: "SQLite"
  dbname: "share/<%= $db_name %>.db"
  dbuser: ""
  dbhost: ""
  dbpass: ""
  dbport: 0

loglevel: "debug"
hypnotoad:
  listen:
    - "http://*:8080"

__END__

=head1 NAME

Mojolicious::Command::generate::nifty_app - Generates a basic application with simple DBIC-based authentication!

=head1 VERSION

Version 0.01

=head1 SYNOPSIS

This command generate an application with a DBIx::Class model and a simple authentication controller.
The layout and style are taken from Ryan Bates nifty_generators.

To generate an app run:

    mojo generate nifty_app My::Nifty::App

This will create the directory structure with a default YAML config and basic testing.

    cd my_nifty_app
    script/deploy_my_nifty_app_db

will create the default database and the schema. Default driver is SQLite and the database will be my_nifty_app_db.sqlite for above example.

=head1 AUTHOR

Matthias Krull, C<< <m.krull at uninets.eu> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-mojolicious-command-generate-nifty_app at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Mojolicious-Command-generate-nifty_app>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Mojolicious::Command::generate::nifty_app


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Mojolicious-Command-generate-nifty_app>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Mojolicious-Command-generate-nifty_app>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Mojolicious-Command-generate-nifty_app>

=item * Search CPAN

L<http://search.cpan.org/dist/Mojolicious-Command-generate-nifty_app/>

=item * Repository

L<https://github.com/mugenken/Mojolicious-Command-generate-nifty_app/>

=back


=head1 LICENSE AND COPYRIGHT

Copyright 2013 Matthias Krull.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

