
package Class::MOP::Browser::Controller::Root;

use strict;
use warnings;

use base 'Catalyst::Controller';

our $VERSION = '0.01';

__PACKAGE__->config->{namespace} = 'cgi-bin/class_mop_browser.pl';

sub default : Private {
    my ($self, $c) = @_;
    $c->response->body("Helloooooo World");
} 

sub index : Public {
    my ( $self, $c ) = @_;
}

sub end : ActionClass('RenderView') {}

1;

__END__

=pod

=head1 NAME

Class::MOP::Browser::Controller::Root - Root Controller for Class::MOP::Browser

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=head2 default

=cut

=head2 end

Attempt to render a view, if needed.

=head1 AUTHOR

Stevan Little

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
