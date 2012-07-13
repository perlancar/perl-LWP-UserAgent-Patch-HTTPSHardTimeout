package LWP::UserAgent::patch::https_hard_timeout;

use 5.010001;
use strict;
no warnings;
use Log::Any '$log';

use parent qw(Module::Patch);

# VERSION

our %config;

my $p_send_request = sub {
    my $orig = shift;

    my ($self, $request, $arg, $size) = @_;
    my $url    = $request->uri;
    my $scheme = $url->scheme;
    if ($scheme eq 'https' && $config{-timeout} > 0) {
        my $resp;
        eval {
            $log->tracef("Wrapping send_request() with alarm timeout (%d)",
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
        config => {
            -timeout => {
                schema  => 'int*',
                default => 3600,
            },
        },
        versions => {
            '6.04' => {
                subs => {
                    send_request => $p_send_request,
                },
            },
        },
    };
}

1;
# ABSTRACT: Patch module for LWP::UserAgent

=head1 SYNOPSIS

 use LWP::UserAgent::patch::https_hard_timeout -timeout => 300;


=head1 DESCRIPTION

This module contains a simple workaround for hanging issue with HTTPS requests.
It wraps send_request() with an alarm() timeout.


=head1 FAQ

=head2 Why not subclass?

By patching, you do not need to replace all the client code which uses
LWP::UserAgent (or WWW::Mechanize, and so on).


=head1 SEE ALSO

http://stackoverflow.com/questions/9400068/make-timeout-work-for-lwpuseragent-https

L<LWPx::ParanoidAgent>

=cut