package LWP::UserAgent::Patch::HTTPSHardTimeout;

# DATE
# VERSION

use 5.010001;
use strict;
no warnings;
use Log::ger;

use Module::Patch qw();
use base qw(Module::Patch);

our %config;

my $p_send_request = sub {
    my $ctx  = shift;
    my $orig = $ctx->{orig};

    my ($self, $request, $arg, $size) = @_;
    my $url    = $request->uri;
    my $scheme = $url->scheme;
    if ($scheme eq 'https' && $config{-timeout} > 0) {
        my $resp;
        eval {
            log_trace("Wrapping send_request() with alarm timeout (%d)",
                         $config{-timeout});
            local $SIG{ALRM} = sub { die "alarm\n" };
            alarm $config{-timeout};
            $resp = $orig->(@_);
            alarm 0;
        };
        if ($@) {
            die unless $@ eq "alarm\n";
            return LWP::UserAgent::_new_response(
                $request, &HTTP::Status::RC_HTTP_REQUEST_TIMEOUT, $@);
        } else {
            return $resp;
        }
    } else {
        return $orig->(@_);
    }
};

sub patch_data {
    return {
        v => 3,
        config => {
            -timeout => {
                schema  => 'int*',
                default => 3600,
            },
        },
        patches => [
            {
                action => 'wrap',
                mod_version => qr/^6\.+/,
                sub_name => 'send_request',
                code => $p_send_request,
            },
        ],
    };
}

1;
# ABSTRACT: Add hard timeout to HTTPS requests

=head1 SYNOPSIS

 use LWP::UserAgent::Patch::HTTPSHardTimeout -timeout => 300;


=head1 DESCRIPTION

This module contains a simple workaround for hanging issue with HTTPS requests.
It wraps send_request() with an alarm() timeout.

Can be used with L<WWW::Mechanize> because it uses L<LWP::UserAgent>.


=head1 FAQ

=head2 Why not subclass?

By patching, you do not need to replace all the client code which uses
LWP::UserAgent (or WWW::Mechanize, and so on).


=head1 SEE ALSO

http://stackoverflow.com/questions/9400068/make-timeout-work-for-lwpuseragent-https

L<LWPx::ParanoidAgent>

=cut
