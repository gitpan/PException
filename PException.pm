# -*- cperl -*-
#
# Copyright (c) 1997-2003 Samuel    MOUNIEE
#
#    This file is part of PException.
#
#    PException is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    PException is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with PException; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
package PException;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use Debug ( 0 );

require Exporter;

$VERSION= "2.3.1";

=pod

=head1 NAME

Exception - Exception manager

=head1 SYNOPSIS

  use Exception;


  try {
		throw( AnException->new() )	if $something;
		throw( AnOtherException->new( [] ) )
			unless	$anotherthing;
	}
	catch	AnException( sub { } ) ,
	onfly	AnOtherException( sub { } ) ;


=cut

@ISA		= qw( Exporter );
@EXPORT		= qw( throw try );
@EXPORT_OK	= qw( );

$_XCPHDL_	= [ { 
	EXCEPTIONS	=> 1,
	FLYS		=> 2,
	STACKFLY	=> 3,
	ONFLY		=> 4,
	FRESH		=> 5,
	CANDIE		=> 6
  }, [], [], [], 0, 0, 0 ];

BEGIN
{
  $SIG{__WARN__}	= \&__onflyhandler;

  $SIG{__DIE__}		= sub	{
#	$Exception::_XCPHDL_->{CANDIE}	= 1;

#	if( $@ && hadWaittingExceptions() )
#				{ debug( 2, "NN-> $@ <" ) }
#	elsif ( $@ )		{ debug( 2, "NO-> $@ <" ); $@ = undef }
#	elsif	( @_ )		{ debug( 2, "ON->", @_, "<" ) }
#	else			{ debug( 2, "OO->", $@, @_, "<" ) }
#	$@ .= " - ";

	die ( $@, @_ );
#	throw();
  };
}


=pod

=head1	DESCRIPTION

=head2	Methods & Functions

=over	4

=item	try

execute code until its end or an exception happens.

=cut

sub	try(&@)
{
	my $e	= shift;

	my	@catch	= grep { $_->isa("Exception::CATCH") } @_;
	my	@onfly	= grep { $_->isa("Exception::ONFLY") } @_;

## add an new stack of onfly exception

	push( @{$Exception::_XCPHDL_->{STACKFLY}}, [ @onfly ] );

	#debug( 1, "try\t\t", $e, @_ );

	eval { &$e; };

## remove the stack of onfly exception

	pop( @{$Exception::_XCPHDL_->{STACKFLY}} );

	if( $@ && hadWaittingExceptions() )
	{
#	  chomp( $@ );
	  #debug( 2, "---> $@ <" );
	  throw() if checkException( @catch );
	}
	elsif ( $@ )
	{
#	  chomp( $@ );
	  #debug( 2, "no-> $@ <" );
	  $@	= undef;
	}

	#debug( 2, "STACKFLY", scalar( @{$Exception::_XCPHDL_->{STACKFLY}} ) );
}

=pod

=item	throw

throw a list of exceptions.

=cut

sub	throw(@)
{
  #debug( 1, "throw\t", "begin" );

  $Exception::_XCPHDL_->{FRESH}	= 0;
  if	( scalar(@_) > 0 )
  {
	push( @{$Exception::_XCPHDL_->{EXCEPTIONS}}, @_ );
	$Exception::_XCPHDL_->{FRESH}	= 1;
  }

  my @tmp	= @{$Exception::_XCPHDL_->{EXCEPTIONS}};

  #debug( 2, "throw\t", @tmp );

  map { $_ = ref($_) . "($$_)" } @tmp;

  if ( !$Exception::_XCPHDL_->{ONFLY} && $Exception::_XCPHDL_->{CANDIE} )
  {
	#debug( 2, "throw\t", "Die" );
	$_XCPHDL_->{CANDIE}	= 0;
	die( join( "\t- ", "Die", @tmp ) );
  }
  elsif( !$Exception::_XCPHDL_->{ONFLY} )
  {
	#debug( 2, "throw\t", "Warn" );
	warn( join( "\t- ", "Warn", @tmp ) );
  }
}


=pod

=item	new

create a new instance of an Exception.

=cut

sub	new($@)
{
  my $classe	= shift;
  my $sc	= shift;

  return bless $sc, $classe	if ref( $sc );
  return bless \$sc, $classe;
}


=pod

=item	catch

execute an subroutine if this kind of exception is thrown

=cut
sub	catch($&)	{ return newTypedCatching( $_[0], $_[1], "CATCH" ) }

=pod

=item	onfly

execute an subroutine and continue the execution of the last try
if this kind of exception is thrown

=cut
sub	onfly($&)	{ return newTypedCatching( $_[0], $_[1], "ONFLY" ) }


=pod

=item	addFlyingHandler

add a flying exception handler. it allows to continue the try
block where the exception appear.

=cut
sub	addFlyingHandler($&)
{ push( @{$Exception::_XCPHDL_->{FLYS}}, newTypedCatching( $_[0], $_[1], "FLYS" ) ) }


=pod

=back

=head2	Internal Calls

=over	4

=item	hadWaittingExceptions

return true if there is waitting exceptions, false elsewhere

=cut
sub	hadWaittingExceptions	{ return scalar(@{$Exception::_XCPHDL_->{EXCEPTIONS}})>0 }


=pod

=item	newTypedCatching

create an object for catching methods.
when a catch happens, 

=cut
sub	newTypedCatching($$$)
{
  my ( $s, $c, $sig ) = @_;

  if	( !defined( $c ) )
	{ $c = sub {}	unless	( $c = $s->can( handleException ) ) }

  return bless sub()
  {
	#debug( 1, $sig,$s, $c, @{$Exception::_XCPHDL_->{EXCEPTIONS}} );

	if ( my @tmp = grep { $_->isa($s) } @{$Exception::_XCPHDL_->{EXCEPTIONS}} )
	{
		@{$Exception::_XCPHDL_->{EXCEPTIONS}} =
			grep { !($_->isa($s)) } @{$Exception::_XCPHDL_->{EXCEPTIONS}};
		&$c(@tmp);
#		@{$Exception::_XCPHDL_->{EXCEPTIONS}} = ( @{$Exception::_XCPHDL_->{EXCEPTIONS}}, @tmp );
		return 1;
	}
	return 0;
  }, "Exception::$sig";
}

=pod

=item	checkException

control if there is some exceptions to catch & treat in an stack

=cut
sub	checkException(@)
{
  foreach(@_){&{$_}()}
  return hadWaittingExceptions();
}


=pod

=item	handleException

code for handling a exception. it's an empty sub actually.
you overload it if you want a default handler for an exception.

=cut
sub	handleException		{ }


=pod

=item	__onflyhandler

the handler which intercept __WARN__ or __DIE__ signal

=cut
sub	__onflyhandler
{
  if	( hadWaittingExceptions() )
  {
	my ( @tmp );
	#debug( 1, "FLYS HANDLER", "Begin" );

## get the current stack of onfly exception
	if	( scalar( @{$Exception::_XCPHDL_->{STACKFLY}} ) )
	{
	  @tmp	= @{$Exception::_XCPHDL_->{STACKFLY}->[
			$#{$Exception::_XCPHDL_->{STACKFLY}}]};
	}
	else	{
	  my ( $i, @tmp ) = ( 0 );

	  while( @tmp = caller( $i++ ) )
	  { print STDERR "$i\t> " . join( " + ", grep { defined $_ } @tmp, "\n" ) }

	  for ( @{$Exception::_XCPHDL_->{EXCEPTIONS}} )
		{ print STDERR "\t>$_ - ", $$_ , "\n" }
	  die( "ya1kouille! Exception thrown with no try block" )
	}

	#debug( 2, "FLYS HANDLER", @tmp );

## add flying handlers if fresh exception
	push( @tmp, @{$Exception::_XCPHDL_->{FLYS}} )
		if ( ( $Exception::_XCPHDL_->{FRESH} ) &&
			scalar( @{$Exception::_XCPHDL_->{FLYS}} ) );

	$Exception::_XCPHDL_->{ONFLY}	= 1;

	if	( checkException( @tmp ) )
	{
	  #debug( 2, "FLYS HANDLER", "Following" );
	  $Exception::_XCPHDL_->{ONFLY}	= 0;
	  $Exception::_XCPHDL_->{CANDIE}= 1;
	  throw();
	}
	#debug( 2, "FLYS HANDLER", "End" );
	undef $@;
	$Exception::_XCPHDL_->{ONFLY}	= 0;
  }
  else	{ print STDERR $@ }
}

__END__

=pod

=back

=head1	Internal Mechanism

=head2	_XCPHDL_ Structure


	local	%_XCPHDL_	= (
		EXCEPTIONS	=> [],
		FLYS		=> [],
		STACKFLY	=> [],
		ONFLY		=> 0,
		FRESH		=> 0,
		CANDIE		=> 0
		);


=over	4

=item	EXCEPTIONS

@{$Exception::_XCPHDL_->{EXCEPTIONS}} is the stack of thrown
exceptions.

=item	FLYS

@{$Exception::_XCPHDL_->{FLYS}} is the stack of fly exception
handler.

=item	STACKFLY

@{$Exception::_XCPHDL_->{STACKFLY}} contain a stack of the list of
onfly exception. each list is linked to a nested try.

=item	ONFLY

it's a flag which determine if an handler can die when it throws.

=item	FRESH

is up only when fresh exception are thrown.

=item	CANDIE

is up when a die call must be done.

=back

=head2	Try mechanism

a try block is a code block which is evaluated.

when you throw a new set of exception, this set is pushed in
@{$Exception::_XCPHDL_->{EXCEPTIONS}} , the system call die.

=head2	Onfly mechanism

then $SIG{__DIE__} check if any waitting may be catched, when
it finish and there is waitting exception yet, it die, else it
continues the try block ; it's the onfly exception handling.

=head2	Catch mechanism

the catching part is the same thing than upside, but you can't
continue the execution of the try block.

=head1	BUGS

Don't try to change $SIG{__WARN__} and $SIG{__DIE__} inside a try block.

=head1	TO DO

=over	4

=item	Better documentation

=item	Add the waitting exception capacity ( aka warning exceptions which
are thrown when others exceptions are thrown )

=item	Overload CORE::warn & CORE::die by other function which don't
interact with the engine

=item	Add a "transaction" try ( aka try blocks wich are executed totaly or
not )

=item	Add other tests ...

=back

=head1 COPYRIGHT, LICENCE

 Copyright (c) 1998-2003 Samuel    MOUNIEE

This file is part of PException.

PException is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

PException is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with PException; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA


=head1 AUTHOR

Samuel Mouniée E<lt>mouns@mouns.netE<gt>

=cut

