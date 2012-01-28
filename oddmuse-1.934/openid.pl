# Copyright (C) 2008, 2009  Alex Schroeder <alex@gnu.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Based on documentation from
# http://code.google.com/intl/en/apis/accounts/docs/OpenID.html

$ModulesDescription .= '<p>$Id: openid.pl $</p>';

use Net::OpenID::Consumer;
use Cache::File;
use CGI::Session;

use vars qw($OpenIdSession);

$Action{openid} = \&DoOpenId;

sub DoOpenId {
  print GetHeader('',T('OpenID Login')), $q->start_div({-class=>'content password openid'});
  print $q->p(T('Your identity is saved in a cookie, if you have cookies enabled. Cookies may get lost if you connect from another machine, from another account, or using another software.'));
  my $homepage = GetParam('homepage', '');
  if ($homepage) {
    print $q->p(Ts('Your homepage is set to %s.',
		   $q->a({-href=>$homepage}, $homepage)));
  } else {
    print $q->p(T('You have no homepage set.'));
  }
  print GetFormStart(undef, undef, 'openid login'),
    $q->p(GetHiddenValue('action', 'login'), T('Homepage:'), ' ',
	  $q->textfield(-name=>'homepage', -size=>50, -maxlength=>250),
	  $q->submit(-name=>'Save', -accesskey=>T('s'), -value=>T('Save'))),
	    $q->endform;
  print $q->end_div();
  my $validated = $OpenIdSession->param('validated');
  if ($validated) {
    print $q->p(Ts('You are logged in as %s.',
		   $q->a({-href=>$validated}, $validated)));
  } else {
    print $q->p(T('You are not logged in.'));
  }
  PrintFooter();
}

$Action{login} = \&DoOpenIdLogin;

sub DoOpenIdLogin {
  my $homepage = GetParam('homepage', '');
  ReportError(T('Homepage is missing')) unless $homepage;
  # Setting up the consumer.
  my $ua = LWP::UserAgent->new;
  my $cache = Cache::File->new(cache_root => $TempDir,
			       default_expires => '600 sec');
  my $consumer = Net::OpenID::Consumer->new;
  $consumer->ua($ua);
  $consumer->cache($cache);
  $consumer->args($q);
  $consumer->required_root($ScriptName);
  $consumer->consumer_secret('5t437');
  # The first step is to fetch that page, parse it, and get a
  # Net::OpenID::ClaimedIdentity object:
  # FIXME: This crashes unconditionally!?
  my $claimed_identity = $consumer->claimed_identity($homepage);
  # FIXME: Add error handling based on $consumer->errcode.
  ReportError(Ts("OpenID error %s", $consumer->errcode))
	      unless $claimed_identity;
  # now we send them to their identity server's endpoint to get
  # redirected to either a positive assertion that they own that
  # identity, or where they need to go to login.
  my %opts = ();
  $opts{trust_root} = $ScriptName;
  $opts{return_to} = ScriptUrl('action=openid');
  my $check_url = $claimed_identity->check_url(
           return_to  => "http://example.com/openid-check.app?yourarg=val",
           trust_root => "http://example.com/",
         );
  # so you send the user off there, and then they come back to
  # openid-check.app, then you see what the identity server said.
  $consumer->handle_server_response
    (not_openid => sub {
       ReportError("Not an OpenID message"); # FIXME
     },
     setup_required => sub {
       my $setup_url = shift;
       ReportError("Must visit $setup_url"); # FIXME
     },
     cancelled => sub {
       ReportError('Cancelled!'); # FIXME
     },
     verified => sub {
       my $vident = shift;
       ReportError("Verified: $vident");
     },
     error => sub {
       die(@_);
     });
  ReportError('WTF');
}

push(@MyInitVariables, \&OpenIdSessionSetup);

sub OpenIdSessionSetup {
  my $sessionDir = "$TempDir/sessions";
  CreateDir($sessionDir);
  $OpenIdSession = new CGI::Session(undef, undef, {Directory=>$sessionDir});
}
