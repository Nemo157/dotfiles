use strict; use warnings;

use Irssi;
use Net::Twitter;
use File::Path::Expand;
use YAML::XS qw(LoadFile);
use vars qw($VERSION %IRSSI);

$VERSION = "1";
%IRSSI = (
    authors     => "Nemo157 (Wim Looman)",
    contact     => "wim\@nemo157.com",
    name        => "Twitter",
    description => "Inline tweets",
    license     => "",
    url         => "",
    changed     => "2016-03-04"
);

sub public {
  my ($server, $msg, $nick, $address, $target) = @_;

  if ($msg =~ /.*https?:\/\/twitter\.com\/[^\/ ]+\/status\/([^\/ ]+)/) {
    my $id = $1;

    eval {
      my $config_file = Irssi::settings_get_str('twitter_config_file');
      if (!$config_file) {
        Irssi::print("twitter: twitter_config_file not set");
        return;
      }

      my $config = LoadFile(expand_filename($config_file));
      if (!$config) {
        Irssi::print("twitter: twitter_config_file not readable");
        return;
      }

      my $twitter = Net::Twitter->new(
        traits   => [qw/API::RESTv1_1/],
        consumer_key        => $config->{consumer_key},
        consumer_secret     => $config->{consumer_secret},
        access_token        => $config->{access_token},
        access_token_secret => $config->{access_token_secret},
      );

      my $status = $twitter->show_status($id);
      my $text = $status->{text};
      $server->print($target, "twit: $text", MSGLEVEL_CLIENTNOTICE | MSGLEVEL_NO_ACT);
    };
    if ($@) {
      Irssi::print("twitter error: $@");
    }
  }
}

Irssi::settings_add_str('twitter', 'twitter_config_file', '');

Irssi::signal_add_last('message public', 'public')
