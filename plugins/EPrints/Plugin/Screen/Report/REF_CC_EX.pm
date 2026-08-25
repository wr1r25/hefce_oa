package EPrints::Plugin::Screen::Report::REF_CC_EX;

use EPrints::Plugin::Screen::Report::REF_CC;
our @ISA = ( 'EPrints::Plugin::Screen::Report::REF_CC' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{report} = 'ref_cc-ex';

	return $self;
}

sub validate_dataobj
{
	my( $self, $eprint ) = @_;

	my $repo = $self->{repository};

	my @problems;

	my $out_of_scope = $repo->call( [ "hefce_oa", "OUT_OF_SCOPE_reason" ], $repo, $eprint );
        if( $out_of_scope )
        {
		push @problems, EPrints::XML::to_string( $repo->html_phrase( "hefce_oa:out_of_scope:$out_of_scope" ) );
		return @problems;
	}

	#show wholly non-compliant records as not being compliant still
	my $flag = $eprint->value( "hoa_compliant" );
        if( !( $flag & HefceOA::Const::COMPLIANT ) )
        {
                push @problems, $repo->phrase( "Plugin/Screen/EPrint/HefceOA:non_compliant" );
        }

	for( qw( hoa_ex_dep hoa_ex_acc hoa_ex_tec hoa_ex_fur ) )
	{
		if( $eprint->is_set( $_ ) )
		{
			push @problems, EPrints::XML::to_string(
				$repo->html_phrase( "Plugin/Screen/EPrint/HefceOA:render_exception", 
					title => $repo->html_phrase( "eprint_fieldname_$_" ),
					exception => $eprint->render_value( $_ ),
					explanation => $eprint->render_value( "$_\_txt" ),
				)
			);
		}
	}
	
	return @problems;
}

# applies any mandatory filters to a search object - used to enforce certain search criteria, even with a custom report
sub apply_filters
{
	my( $self ) = @_;

	my $ds = $self->repository->dataset( 'eprint' );
	my $field = $ds->field( 'hoa_exclude' );

	$self->{processor}->{search}->add_field( fields => $field,
		value => 'FALSE',
		match => 'EX',
	);

    # this report should only include items published before the rule change in Jan 26
    my $pub_field = $ds->field( "hoa_date_pub" );
	$self->{processor}->{search}->add_field( fields => $pub_field,
        value => '2021-01-01-2025-12-31',
		match => 'IN',
	);

    # and only REF CC compatible items
    my $session = $self->{session};
    my $types = join( ' ', @{$session->config( "hefce_oa", "item_types" )} );
    my $type_field = $ds->field( "type" );
    $self->{processor}->{search}->add_field( fields => $type_field,
        value => $types, 
        match => 'EQ', 
        merge => 'ANY',
    );
}

1;
