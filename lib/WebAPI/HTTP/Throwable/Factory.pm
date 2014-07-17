package WebAPI::HTTP::Throwable::Factory;
$WebAPI::HTTP::Throwable::Factory::VERSION = '0.001000'; # TRIAL
use parent 'HTTP::Throwable::Factory';
use Carp qw(carp cluck);
use JSON::MaybeXS qw(JSON);

sub extra_roles {
    return (
        'WebAPI::HTTP::Throwable::Role::JSONBody', # remove HTTP::Throwable::Role::TextBody
        'StackTrace::Auto'
    );
}

sub throw_bad_request {
    my ($class, $status, %opts) = @_;
    cluck("bad status") unless $status =~ /^4\d\d$/;
    carp("throw_bad_request @_") if $ENV{WEBAPI_DBIC_DEBUG};

    # XXX TODO validations
    my $data = {
        errors => $opts{errors},
    };
    my $json_body = JSON->new->ascii->pretty->encode($data);
    # [ 'Content-Type' => 'application/hal+json' ],
    $class->throw( BadRequest => {
        status_code => $status,
        message => $json_body,
    });
    return;                     # not reached
}



1;

__END__

=pod

=encoding UTF-8

=head1 NAME

WebAPI::HTTP::Throwable::Factory

=head1 VERSION

version 0.001000

=head1 AUTHOR

Tim Bunce <Tim.Bunce@pobox.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Tim Bunce.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
