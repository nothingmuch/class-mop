
package BinaryTree;

use strict;
use warnings;

use metaclass;

our $VERSION = '0.02';

BinaryTree->meta->add_attribute('$:uid' => (
    reader  => 'getUID',
    writer  => 'setUID',
    default => sub { 
        my $instance = shift;
        ("$instance" =~ /\((.*?)\)$/);
    }
));

BinaryTree->meta->add_attribute('$:node' => (
    reader   => 'getNodeValue',
    writer   => 'setNodeValue',
    init_arg => ':node'
));

BinaryTree->meta->add_attribute('$:parent' => (
    predicate => 'hasParent',
    reader    => 'getParent',
    writer    => 'setParent'
));

BinaryTree->meta->add_attribute('$:left' => (
    predicate => 'hasLeft',         
    reader    => 'getLeft',
    writer => { 
        'setLeft' => sub {
            my ($self, $tree) = @_;
        	$tree->setParent($self) if defined $tree;
            $self->{'$:left'} = $tree;    
            $self;                    
        }
   },
));

BinaryTree->meta->add_attribute('$:right' => (
    predicate => 'hasRight',           
    reader    => 'getRight',
    writer => {
        'setRight' => sub {
            my ($self, $tree) = @_;   
        	$tree->setParent($self) if defined $tree;
            $self->{'$:right'} = $tree;      
            $self;                    
        }
    }
));

sub new {
    my $class = shift;
    $class->meta->new_object(':node' => shift);            
}    
        
sub removeLeft {
    my ($self) = @_;
    my $left = $self->getLeft();
    $left->setParent(undef);   
    $self->setLeft(undef);     
    return $left;
}

sub removeRight {
    my ($self) = @_;
    my $right = $self->getRight;
    $right->setParent(undef);   
    $self->setRight(undef);    
    return $right;
}
             
sub isLeaf {
	my ($self) = @_;
	return (!$self->hasLeft && !$self->hasRight);
}

sub isRoot {
	my ($self) = @_;
	return !$self->hasParent;                    
}
     
sub traverse {
	my ($self, $func) = @_;
    $func->($self);
    $self->getLeft->traverse($func)  if $self->hasLeft;    
    $self->getRight->traverse($func) if $self->hasRight;
}

sub mirror {
    my ($self) = @_;
    # swap left for right
    my $left = $self->getLeft;
    $self->setLeft($self->getRight());
    $self->setRight($left);
    # and recurse
    $self->getLeft->mirror()  if $self->hasLeft();
    $self->getRight->mirror() if $self->hasRight();
    $self;
}

sub size {
    my ($self) = @_;
    my $size = 1;
    $size += $self->getLeft->size()  if $self->hasLeft();
    $size += $self->getRight->size() if $self->hasRight();    
    return $size;
}

sub height {
    my ($self) = @_;
    my ($left_height, $right_height) = (0, 0);
    $left_height = $self->getLeft->height()   if $self->hasLeft();
    $right_height = $self->getRight->height() if $self->hasRight();    
    return 1 + (($left_height > $right_height) ? $left_height : $right_height);
}                      

1;