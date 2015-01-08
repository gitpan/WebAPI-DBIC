package WebAPI::DBIC::Resource::Role::DBIC_JSONAPI;
$WebAPI::DBIC::Resource::Role::DBIC_JSONAPI::VERSION = '0.002001';

use Carp qw(croak confess);
use Devel::Dwarn;
use JSON::MaybeXS qw(JSON);

use Moo::Role;


requires 'get_url_for_item_relationship';
requires 'render_item_as_plain_hash';
requires 'path_for_item';
requires 'add_params_to_url';
requires 'prefetch';


my %result_class_to_jsonapi_type; # XXX ought to live elsewhere


sub jsonapi_type { # XXX this is a hack - needs more thought
    my ($self) = @_;
    my $result_class = $self->set->result_source->result_class;
    my $path = $self->jsonapi_type_for_result_class($result_class)
        or confess sprintf("panic: no route found to %s result_class %s",
            $self, $result_class
        );
    return $path;
}
sub jsonapi_type_for_result_class { # XXX this is a hack - needs more thought
    my ($self, $result_class) = @_;
    my $url = $self->uri_for(result_class => $result_class)
        or return undef;
    my $path = URI->new($url,'http')->path;
    $path =~ s!^/([^/]+)!$1! or die "panic: Can't get jsonapi_type from $path";
    return $path;
}


sub top_link_for_relname { # XXX cacheable
    my ($self, $relname) = @_;

    my $link_url_templated = $self->get_url_template_for_set_relationship($self->set, $relname);
    return if not defined $link_url_templated;

    # XXX a hack to keep the template urls readable!
    $link_url_templated =~ s/%7B/{/g;
    $link_url_templated =~ s/%7D/}/g;

    my $rel_info = $self->set->result_class->relationship_info($relname);
    my $result_class = $rel_info->{class}||die "panic";

    my $rel_jsonapi_type = $result_class_to_jsonapi_type{$result_class}
        ||= $self->jsonapi_type_for_result_class($result_class);

    my $path = $self->jsonapi_type .".". $relname;
    return $path => {
        href => "$link_url_templated", # XXX stringify the URL object
        type => $rel_jsonapi_type,
    };
}


sub render_jsonapi_response { # return top-level document hashref
    my ($self) = @_;

    my $set = $self->set;

    my %item_edit_rel_hooks;

    my %top_links;
    my %compound_links;

    for my $prefetch (@{$self->prefetch||[]}) {
        while (my ($relname, $sub_rel) = each %{$prefetch}){

            next if $self->param('distinct');

            #Dwarn
            my $rel_info = $set->result_class->relationship_info($relname);
            my $result_class = $rel_info->{class}||die "panic";

            my @idcolumns = $result_class->unique_constraint_columns('primary');
            if (@idcolumns > 1) { # eg many-to-many that doesn't have a separate id
                warn "Result class $result_class has has multiple keys so relations like $relname won't have links generated.\n"
                    unless our $warn_once->{"$result_class $relname"}++;
                next;
            }

            my ($top_link_key, $top_link_value) = $self->top_link_for_relname($relname)
                or next;
            $top_links{$top_link_key} = $top_link_value;

            $item_edit_rel_hooks{$relname} = sub { 
                my ($jsonapi_obj, $row) = @_;

                my $subitem = $row->$relname();

                my $link_keys;
                if (not defined $subitem) {
                    $link_keys = undef;
                }
                elsif ($subitem->isa('DBIx::Class::ResultSet')) { # one-to-many rel
                    $link_keys = [];
                    while (my $subrow = $subitem->next) {
                        my $id = $subrow->id;
                        push @$link_keys, $id;
                        $compound_links{$relname}{$id} = $self->render_item_as_jsonapi_hash($subrow); # XXX typename
                    }
                }
                elsif ($subitem->isa('DBIx::Class::Row')) { # one-to-many rel
                    $link_keys = $subitem->id;
                    $compound_links{$relname}{$subitem->id} = $self->render_item_as_jsonapi_hash($subitem); # XXX typename
                }
                else {
                    die "panic: don't know how to handle $row $relname value $subitem";
                }

                $jsonapi_obj->{links}{$relname} = $link_keys;
            }
        }
    }

    my $set_data = $self->render_set_as_array_of_jsonapi_resource_objects($set, undef, sub {
        my ($jsonapi_obj, $row) = @_;
        $_->($jsonapi_obj, $row) for values %item_edit_rel_hooks;
    });

    my $set_key = ($self->param('distinct')) ? 'data' : $self->jsonapi_type;
    my $top_doc = { # http://jsonapi.org/format/#document-structure-top-level
        $set_key => $set_data,
    };
    $top_doc->{links} = \%top_links if keys %top_links;
    while ( my ($k, $v) = each %compound_links) {
        my @ids = sort keys %$v; # sort just for test stability,
        $top_doc->{linked}{$k} = [ @{$v}{@ids} ]; # else just [ values %$v ] would do
    }

    my $total_items;
    if (($self->param('with')||'') =~ /count/) { # XXX
        $total_items = $set->pager->total_entries;
        $top_doc->{meta}{count} = $total_items; # XXX detail not in spec
    }

    return $top_doc;
}



sub render_item_as_jsonapi_hash {
    my ($self, $item) = @_;

    my $data = $self->render_item_as_plain_hash($item);

    $data->{id} //= $item->id;
    $data->{type} = $self->jsonapi_type_for_result_class($item->result_source->result_class);
    $data->{href} = $self->path_for_item($item);

    #$self->_render_prefetch_jsonapi($item, $data, $_) for @{$self->prefetch||[]};

    # add links for relationships

    return $data;
}


sub _render_prefetch_jsonapi {
    my ($self, $item, $data, $prefetch) = @_;

    while (my ($rel, $sub_rel) = each %{$prefetch}){
        next if $rel eq 'self';

        my $subitem = $item->$rel();

        if (not defined $subitem) {
            $data->{_embedded}{$rel} = undef; # show an explicit null from a prefetch
        }
        elsif ($subitem->isa('DBIx::Class::ResultSet')) { # one-to-many rel
            my $rel_set_resource = $self->web_machine_resource(
                set         => $subitem,
                item        => undef,
                prefetch    => ref $sub_rel eq 'ARRAY' ? $sub_rel : [$sub_rel],
            );
            $data->{_embedded}{$rel} = $rel_set_resource->render_set_as_array_of_jsonapi_resource_objects($subitem, undef);
        }
        else {
            $data->{_embedded}{$rel} = $self->render_item_as_plain_hash($subitem);
        }
    }
}

sub render_set_as_array_of_jsonapi_resource_objects {
    my ($self, $set, $render_method, $edit_hook) = @_;
    $render_method ||= 'render_item_as_jsonapi_hash';

    my @jsonapi_objs;
    while (my $row = $set->next) {
        push @jsonapi_objs, $self->$render_method($row);
        $edit_hook->($jsonapi_objs[-1], $row) if $edit_hook;
    }

    return \@jsonapi_objs;
}




sub _jsonapi_page_links {
    my ($self, $set, $base, $page_items, $total_items) = @_;

    # XXX we ought to allow at least the self link when not pages
    return () unless $set->is_paged;

    # XXX we break encapsulation here, sadly, because calling
    # $set->pager->current_page triggers a "select count(*)".
    # XXX When we're using a later version of DBIx::Class we can use this:
    # https://metacpan.org/source/RIBASUSHI/DBIx-Class-0.08208/lib/DBIx/Class/ResultSet/Pager.pm
    # and do something like $rs->pager->total_entries(sub { 99999999 })
    my $rows = $set->{attrs}{rows} or confess "panic: rows not set";
    my $page = $set->{attrs}{page} or confess "panic: page not set";

    # XXX this self link this should probably be subtractive, ie include all
    # params by default except any known to cause problems
    my $url = $self->add_params_to_url($base, { distinct=>1, with=>1, me=>1 }, { rows => $rows });
    my $linkurl = $url->as_string;
    $linkurl .= "&page="; # hack to optimize appending page 5 times below

    my @link_kvs;
    push @link_kvs, self  => {
        href => $linkurl.($page),
        title => $set->result_class,
    };
    push @link_kvs, next  => { href => $linkurl.($page+1) }
        if $page_items == $rows;
    push @link_kvs, prev  => { href => $linkurl.($page-1) }
        if $page > 1;
    push @link_kvs, first => { href => $linkurl.1 }
        if $page > 1;
    push @link_kvs, last  => { href => $linkurl.$set->pager->last_page }
        if $total_items and $page != $set->pager->last_page;

    return @link_kvs;
}


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

WebAPI::DBIC::Resource::Role::DBIC_JSONAPI

=head1 VERSION

version 0.002001

=head1 NAME

WebAPI::DBIC::Resource::Role::DBIC_JSONAPI - a role with core JSON API methods for DBIx::Class resources

=head1 AUTHOR

Tim Bunce <Tim.Bunce@pobox.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Tim Bunce.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
