package WebAPI::DBIC::Resource::Role::DBIC;
$WebAPI::DBIC::Resource::Role::DBIC::VERSION = '0.001000'; # TRIAL
use Carp qw(croak confess);
use Devel::Dwarn;
use JSON::MaybeXS qw(JSON);

use Moo::Role;


has set => (
   is => 'rw',
   required => 1,
);

has writable => (
   is => 'ro',
);

has http_auth_type => (
   is => 'ro',
);

has prefetch => (
    is => 'rw',
    default => sub { {} },
);

has throwable => (
    is => 'rw',
    required => 1,
);


# XXX probably shouldn't be a role, just functions, or perhaps a separate rendering object

# default render for DBIx::Class item
# https://metacpan.org/module/DBIx::Class::Manual::ResultClass
# https://metacpan.org/module/DBIx::Class::InflateColumn
sub render_item_as_plain_hash {
    my ($self, $item) = @_;
    my $data = { $item->get_columns }; # XXX ?
    # DateTimes
    return $data;
}


sub path_for_item {
    my ($self, $item) = @_;

    my $result_source = $item->result_source;

    my $id = join "-", map { $item->get_column($_) } $result_source->primary_columns;

    my $url = $self->uri_for(id => $id, result_class => $result_source->result_class)
        or confess sprintf("panic: no route found to result_class %s id %s (%s)",
            $result_source->result_class, $id, join(", ",
                map { "$_=".$item->get_column($_) } $result_source->primary_columns
            )
        );

    return $url;
}


# Uses the router to find the route that matches the given parameter hash
# returns nothing if there's no match, else
# returns the absolute url in scalar context, or in list context it returns
# the prefix (SCRIPT_NAME) and the relative url (from the router)
sub uri_for { ## no critic (RequireArgUnpacking)
    my $self = shift; # %pk in @_

    my $url = $self->router->uri_for(@_)
        or return;
    my $prefix = $self->request->env->{SCRIPT_NAME};

    return "$prefix/$url" unless wantarray;
    return ($prefix, $url);

}


sub render_item_into_body {
    my ($self, $item) = @_;

    # XXX ought to be a cloned request, with tweaked url/params?
    my $item_request = $self->request;

    # XXX shouldn't hard-code GenericItemDBIC here
    my $item_resource = WebAPI::DBIC::Resource::GenericItemDBIC->new(
        request => $item_request, response => $item_request->new_response,
        set => $self->set,
        item => $item, id => undef, # XXX dummy id
        prefetch => $self->prefetch,
        throwable => $self->throwable,
        #  XXX others?
    );
    $self->response->body( $item_resource->to_json_as_hal );

    return;
}


sub render_item_as_hal_hash {
    my ($self, $item) = @_;

    my $data = $self->render_item_as_plain_hash($item);

    my $itemurl = $self->path_for_item($item);
    $data->{_links}{self} = {
        href => $self->add_params_to_url($itemurl, {}, {})->as_string,
    };

    while (my ($prefetch, $info) = each %{ $self->prefetch || {} }) {
        next if $prefetch eq 'self';
        my $subitem = $item->$prefetch();
        # XXX perhaps render_item_as_hal_hash but requires cloned WM, eg without prefetch
        # If we ever do render_item_as_hal_hash then we need to ensure that "a link
        # inside an embedded resource implicitly relates to that embedded
        # resource and not the parent."
        # See http://blog.stateless.co/post/13296666138/json-linking-with-hal
        $data->{_embedded}{$prefetch} = (defined $subitem)
            ? $self->render_item_as_plain_hash($subitem)
            : undef; # show an explicit null from a prefetch
    }

    my $curie = (0) ? "r" : ""; # XXX we don't use CURIE syntax yet

    # add links for relationships
    # XXX much of this relation selection logic could be pre-calculated and cached
    my $result_class = $item->result_class;
    for my $relname ($result_class->relationships) {
        my $rel = $result_class->relationship_info($relname);

        # TODO support more kinds of relationships
        # TODO refactor
        # TODO For 'multi' I think we 'just' need to link to the set (ie call uri_for()
        # without an id param) and add a "?me.foo=..." to the url

        # accessor is the inflation type (single/filter/multi)
        if ($rel->{attrs}{accessor} !~ /^(?: single | filter )$/x) {
            unless (our $warn_once->{"$result_class $relname"}++) {
                warn "$result_class relationship $relname ignored since we only support 'single' accessors (not $rel->{attrs}{accessor}) at the moment\n";
                Dwarn $rel if $ENV{WEBAPI_DBIC_DEBUG};
            }
            next;
        }

        # this is really a performance issue, so we could just warn
        if (not $rel->{attrs}{is_foreign_key_constraint}) {
            unless (our $warn_once->{"$result_class $relname"}++) {
                warn "$result_class relationship $relname ignored since we only support foreign key constraints at the moment\n";
                Dwarn $rel if $ENV{WEBAPI_DBIC_DEBUG};
            }
            next;
        }

        my $cond = $rel->{cond};
        # https://metacpan.org/pod/DBIx::Class::Relationship::Base#add_relationship
        if (ref $cond ne 'HASH') { # eg need to add support for CODE refs
            # we'll may end up silencing this warning till we can offer better support
            unless (our $warn_once->{"$result_class $relname"}++) {
                warn "$result_class relationship $relname cond value $cond not handled yet\n";
                Dwarn $rel if $ENV{WEBAPI_DBIC_DEBUG};
            }
            next;
        }

        if (keys %$cond > 1) {
            unless (our $warn_once->{"$result_class $relname"}++) {
                warn "$result_class relationship $relname ignored since it has multiple conditions\n";
                Dwarn $rel if $ENV{WEBAPI_DBIC_DEBUG};
            }
            next;
        }

        my $fieldname = (values %$cond)[0]; # first and only value
        $fieldname =~ s/^self\.// if $fieldname;

        if (not $fieldname) {
            unless (our $warn_once->{"$result_class $relname"}++) {
                warn "$result_class relationship $relname ignored since we can't determine a fieldname (foreign.id)\n";
                Dwarn $rel if $ENV{WEBAPI_DBIC_DEBUG};
            }
            next;
        }


        my $result_class = $rel->{source};
        my $id = $data->{$fieldname}; # XXX id vs pk?
        next if not defined $id; # no link because value is null

        my $linkurl = $self->uri_for( result_class => $result_class, id => $id );
        if (not $linkurl) {
            warn "Result source $rel->{source} has no resource uri in this app so relations (like $result_class $relname) won't have _links for it.\n"
                unless our $warn_once->{"$result_class $relname $rel->{source}"}++;
            next;
        }
        $data->{_links}{ ($curie?"$curie:":"") . $relname} = {
            href => $self->add_params_to_url($linkurl, {}, {})->as_string
        };
    }
    if ($curie) {
       $data->{_links}{curies} = [{
         name => $curie,
         href => "http://docs.acme.com/relations/{rel}", # XXX
         templated => JSON->true,
       }];
   }

    return $data;
}


sub router {
    return shift->request->env->{'plack.router'};
}


sub add_params_to_url {
    my ($self, $base, $passthru_params, $override_params) = @_;
    $base || croak "no base";

    my $req_params = $self->request->query_parameters;
    my @params = (%$override_params);

    # turns 'foo~json' into 'foo', and 'me.bar' into 'me'.
    my %override_param_basenames = map { (split(/\W/,$_,2))[0] => 1 } keys %$override_params;

    # TODO this logic should live elsewhere
    for my $param (sort keys %$req_params) {

        # ignore request params that we have an override for
        my $param_basename = (split(/\W/,$param,2))[0];
        next if defined $override_param_basenames{$param_basename};

        next unless $passthru_params->{$param_basename};

        push @params, $param => $req_params->get($param);
    }
    my $uri = URI->new($base);
    $uri->query_form(@params);
    return $uri;
}


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

WebAPI::DBIC::Resource::Role::DBIC

=head1 VERSION

version 0.001000

=head1 AUTHOR

Tim Bunce <Tim.Bunce@pobox.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Tim Bunce.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
