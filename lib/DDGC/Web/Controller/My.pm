package DDGC::Web::Controller::My;
use Moose;
use namespace::autoclean;

use DDGC::Config;
use DDGC::User;
use Email::Valid;
use Digest::MD5 qw(md5_base64 md5_hex);
use Gravatar::URL;

BEGIN {extends 'Catalyst::Controller'; }

sub base :Chained('/base') :PathPart('my') :CaptureArgs(0) {
    my ( $self, $c ) = @_;
#	$c->stash->{headline_template} = 'headline/my.tt';
	$c->stash->{title} = 'My Account';
	$c->add_bc($c->stash->{title}, $c->chained_uri('My','account'));
}

sub logout :Chained('base') :Args(0) {
    my ( $self, $c ) = @_;
	$c->logout;
	$c->response->redirect($c->chained_uri('Base','welcome'));
}

sub logged_in :Chained('base') :PathPart('') :CaptureArgs(0) {
    my ( $self, $c ) = @_;
	if (!$c->user) {
		$c->response->redirect($c->chained_uri('My','login'));
		return $c->detach;
	}
	push @{$c->stash->{template_layout}}, 'my/base.tt';
}

sub logged_out :Chained('base') :PathPart('') :CaptureArgs(0) {
    my ( $self, $c ) = @_;
	if ($c->user) {
		$c->response->redirect($c->chained_uri('My','account'));
		return $c->detach;
	}
}

sub account :Chained('logged_in') :Args(0) {
    my ( $self, $c ) = @_;

    my $saved = 0;

    for (keys %{$c->req->params}) {

    	if ($_ =~ m/^update_language_(\d+)/) {
    		my $grade = $c->req->param('language_grade_'.$1);
    		if ($grade) {
	    		my ( $user_language ) = $c->user->db->user_languages->search({ language_id => $1 })->all;
	    		if ($user_language) {
	    			$user_language->grade($grade);
	    			$user_language->update;
					$saved = 1;
	    		}
    		}
    	}

		if ($_ eq 'add_language') {
			my $language_id = $c->req->params->{language_id};
			my $grade = $c->req->params->{language_grade};
			if ($grade and $language_id) {
				$c->user->db->update_or_create_related('user_languages',{
					grade => $grade,
					language_id => $language_id,
				},{
					key => 'user_language_language_id_username',
				});
				$saved = 1;
			}
		}

		if ($_ eq 'remove_language') {
			my $language_id = $c->req->params->{$_};
			$c->user->db->user_languages->search({ language_id => $language_id })->delete;
			$saved = 1;
		}

		if ($_ eq 'set_gravatar_email') {
			if ( Email::Valid->address($c->req->params->{gravatar_email}) ) {
				my $data = $c->user->data || {};
				$data->{gravatar_email} = $c->req->params->{gravatar_email};
				$data->{gravatar_urls} = {};
				for (qw/16 32 48 64 80/) {
					$data->{gravatar_urls}->{$_} = gravatar_url(
						email => $data->{gravatar_email},
						rating => "g",
						size => $_,
					);
				}
				$c->user->data($data);
				$c->user->update;
				$saved = 1;
			} else {
				$c->stash->{no_valid_gravatar_email} = 1;
			}
		}

		if ($_ eq 'unset_gravatar_email') {
			my $data = $c->user->data || {};
			delete $data->{gravatar_email};
			delete $data->{gravatar_urls};
			$c->user->data($data);
			$c->user->update;
		}

    }

    $c->stash->{saved} = $saved;

	$c->stash->{languages} = [$c->d->rs('Language')->search({},{
		order_by => { -asc => 'locale' },
	})->all];
}

sub apps :Chained('logged_in') :Args(0) {
    my ( $self, $c ) = @_;
}

sub timeline :Chained('logged_in') :Args(0) {
    my ( $self, $c ) = @_;
}

sub email :Chained('logged_in') :Args(0) {
	my ( $self, $c, ) = @_;

	return $c->detach if !$c->req->params->{save_email};

	if (!$c->validate_captcha($c->req->params->{captcha})) {
		$c->stash->{wrong_captcha} = 1;
		return;
	}

	my $email = $c->req->params->{emailaddress};

	if ( !$email || !Email::Valid->address($email) ) {
		$c->stash->{no_valid_email} = 1;
		return;
	}

	$c->user->data({}) if !$c->user->data;
	my $data = $c->user->data();
	$data->{email} = $email;
	$c->user->data($data);
	$c->user->update;

	$c->response->redirect($c->chained_uri('My','account'));
	return $c->detach;
}

sub delete :Chained('logged_in') :Args(0) {
    my ( $self, $c ) = @_;

	return $c->detach unless $c->req->params->{delete_profile};
	
	if (!$c->validate_captcha($c->req->params->{captcha})) {
		$c->stash->{wrong_captcha} = 1;
		return $c->detach;
	}

	if ($c->req->params->{delete_profile}) {
		my $username = $c->user->username;
		$c->d->delete_user($username);
		$c->logout;
		$c->response->redirect($c->chained_uri('Base','welcome'));
		return $c->detach;
	}
}

sub public :Chained('logged_in') :Args(0) {
    my ( $self, $c ) = @_;

    if ($c->user->public) {
	    $c->add_bc('Make Private', $c->chained_uri('My','public'));
    } else {
	    $c->add_bc('Make Public', $c->chained_uri('My','public'));
    }

	return $c->detach if !($c->req->params->{hide_profile} || $c->req->params->{show_profile});
	
	if (!$c->validate_captcha($c->req->params->{captcha})) {
		$c->stash->{wrong_captcha} = 1;
		return $c->detach;
	}

	if ($c->req->params->{hide_profile}) {
		$c->user->public(0);
	} elsif ($c->req->params->{show_profile}) {
		$c->user->public(1);
	}
	$c->user->update();

	$c->response->redirect($c->chained_uri('My','account'));
	return $c->detach;

}

sub forgotpw_tokencheck :Chained('logged_out') :Args(2) {
	my ( $self, $c, $username, $token ) = @_;

	$c->stash->{check_username} = $username;
	$c->stash->{check_token} = $token;

	my $user = $c->d->find_user($username);

	return unless $user && $user->username eq $username;
	return if !$c->req->params->{forgotpw_tokencheck};
	
	my $error = 0;

	if ($c->req->params->{repeat_password} ne $c->req->params->{password}) {
		$c->stash->{password_different} = 1;
		$error = 1;
	}

	if (!defined $c->req->params->{password} or length($c->req->params->{password}) < 3) {
		$c->stash->{password_too_short} = 1;
		$error = 1;
	}

	return if $error;
	
	my $newpass = $c->req->params->{password};
	$c->d->update_password($username,$newpass);

	$c->stash->{email} = {
		to          => $user->data->{email},
		from        => 'noreply@dukgo.com',
		subject     => '[DuckDuckGo Community] New password for '.$username,
		template        => 'email/newpw.tt',
		charset         => 'utf-8',
		content_type => 'text/plain',
	};

	$c->forward( $c->view('Email::TT') );

	$c->stash->{resetok} = 1;
}

sub changepw :Chained('logged_in') :Args(0) {
	my ( $self, $c ) = @_;

	return if !$c->req->params->{changepw};
	
	my $error = 0;

	if (!$c->user->check_password($c->req->params->{old_password})) {
		$c->stash->{old_password_wrong} = 1;
		$error = 1;
	}

	if ($c->req->params->{repeat_password} ne $c->req->params->{password}) {
		$c->stash->{password_different} = 1;
		$error = 1;
	}

	if (!defined $c->req->params->{password} or length($c->req->params->{password}) < 3) {
		$c->stash->{password_too_short} = 1;
		$error = 1;
	}

	return if $error;
	
	my $newpass = $c->req->params->{password};
	$c->d->update_password($c->user->username,$newpass);

	if ($c->user->data && $c->user->data->{email}) {
		$c->stash->{email} = {
			to          => $c->user->data->{email},
			from        => 'noreply@dukgo.com',
			subject     => '[DuckDuckGo Community] New password for '.$c->user->username,
			template        => 'email/newpw.tt',
			charset         => 'utf-8',
			content_type => 'text/plain',
		};

		$c->forward( $c->view('Email::TT') );
	}

	$c->stash->{changeok} = 1;
}

sub forgotpw :Chained('logged_out') :Args(0) {
	my ( $self, $c ) = @_;
	$c->add_bc('Forgot password', $c->chained_uri('My','forgotpw'));
	return $c->detach if !$c->req->params->{requestpw};
	$c->stash->{forgotpw_username} = lc($c->req->params->{username});
	$c->stash->{forgotpw_email} = $c->req->params->{email};
	my $user = $c->d->find_user($c->stash->{forgotpw_username});
	if (!$user || !$user->data || !$user->data->{email} || $c->stash->{forgotpw_email} ne $user->data->{email}) {
		$c->stash->{wrong_user_or_wrong_email} = 1;
		return;
	}
	
	my $token = md5_hex(int(rand(99999999)));
	$user->data->{token} = $token;
	$user->update;
	$c->stash->{token} = $token;
	$c->stash->{user} = $user->username;
	
	$c->stash->{email} = {
		to          => $user->data->{email},
		from        => 'noreply@dukgo.com',
		subject     => '[DuckDuckGo Community] Reset password for '.$user->username,
		template	=> 'email/forgotpw.tt',
		charset		=> 'utf-8',
		content_type => 'text/plain',
	};

	$c->forward( $c->view('Email::TT') );
	
	$c->stash->{sentok} = 1;
}

sub login :Chained('logged_out') :Args(0) {
    my ( $self, $c ) = @_;
	$c->add_bc('Login', $c->chained_uri('My','login'));

	$c->stash->{no_userbox} = 1;

	if ($c->req->params->{username} && $c->req->params->{username} !~ /^[a-zA-Z0-9_\.]+$/) {
		$c->stash->{not_valid_username} = 1;
	} else {
		if ( my $username = lc($c->req->params->{username}) and my $password = $c->req->params->{password} ) {
			if ($c->authenticate({
				username => $username,
				password => $password,
			}, 'users')) {
				$c->response->redirect($c->chained_uri('My','account'));
			} else {
				$c->stash->{login_failed} = 1;
			}
		}
	}
}

sub register :Chained('logged_out') :Args(0) {
    my ( $self, $c ) = @_;
	$c->add_bc('Register', $c->chained_uri('My','register'));

	$c->stash->{no_login} = 1;

	return $c->detach if !$c->req->params->{register};

	$c->stash->{username} = $c->req->params->{username};
	$c->stash->{email} = $c->req->params->{email};

	if (!$c->validate_captcha($c->req->params->{captcha})) {
		$c->stash->{wrong_captcha} = 1;
		return $c->detach;
	}

	my $error = 0;

	if ($c->req->params->{repeat_password} ne $c->req->params->{password}) {
		$c->stash->{password_different} = 1;
		$error = 1;
	}

	if (!defined $c->req->params->{password} or length($c->req->params->{password}) < 3) {
		$c->stash->{password_too_short} = 1;
		$error = 1;
	}

	if (!defined $c->req->params->{username} or $c->req->params->{username} eq '') {
		$c->stash->{need_username} = 1;
		$error = 1;
	}

	if ( $c->req->params->{email} && !Email::Valid->address($c->req->params->{email}) ) {
		$c->stash->{not_valid_email} = 1;
		$error = 1;
	}

	if ($c->req->params->{username} !~ /^[a-zA-Z0-9_\.]+$/) {
		$c->stash->{not_valid_chars} = 1;
		$error = 1;
	}

	return $c->detach if $error;
	
	my $username = lc($c->req->params->{username});
	my $password = $c->req->params->{password};
	my $email = $c->req->params->{email};
	
	my %xmpp = $c->model('DDGC')->xmpp->user($username);

	if (%xmpp) {
		$c->stash->{user_exist} = $username;
		$error = 1;
	}

	my $user = $c->model('DDGC')->create_user($username,$password);

	if ($user) {
		if ($email) {
			$user->data({}) if !$user->data;
			my $data = $user->data();
			$data->{email} = $email;
			$user->data($data);
			$user->update;
		}
	} else {
		$c->stash->{register_failed} = 1;
		return $c->detach;
	}

	$c->response->redirect($c->chained_uri('My','login',{ register_successful => 1 }));

}

__PACKAGE__->meta->make_immutable;

1;
