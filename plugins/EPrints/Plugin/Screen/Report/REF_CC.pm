package EPrints::Plugin::Screen::Report::REF_CC;

use EPrints::Plugin::Screen::Report;
our @ISA = ( 'EPrints::Plugin::Screen::Report' );

use HefceOA::Const;
use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{datasetid} = 'eprint';
	$self->{searchdatasetid} = 'archive';
	$self->{custom_order} = '-title/creators_name';
	$self->{appears} = [];
	$self->{report} = 'ref_cc';
	$self->{sconf} = 'hefce_report';
	$self->{export_conf} = 'hefce_report';
	$self->{disable} = 1;
	$self->{sort_conf} = 'hefce_report';
	$self->{group_conf} = 'hefce_report';  
	
	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return 0 if( !$self->SUPER::can_be_viewed );

	return $self->allow( 'report/hefce_oa' );
}

sub filters
{
	my( $self ) = @_;

	my @filters = @{ $self->SUPER::filters || [] };

	#only report on the types we're interest in
	my $session = $self->{session};
        my $types = join( ' ', @{$session->config( "hefce_oa", "item_types" )} );

	push @filters, { meta_fields => [ 'type' ], value => $types, match => 'EQ', merge => 'ANY' };
	push @filters, { meta_fields => [ 'eprint_status' ], value => 'archive', match => 'EX' };
	push @filters, { meta_fields => [ 'hoa_exclude' ], value => 'FALSE', match => 'EX' };

	return \@filters;
}

sub ajax_eprint
{
	my( $self ) = @_;

	my $repo = $self->repository;

	my $json = { data => [] };

	$repo->dataset( "eprint" )
	->list( [$repo->param( "eprint" )] )
	->map(sub {
		(undef, undef, my $eprint) = @_;

		return if !defined $eprint; # odd

		my $frag = $eprint->render_citation_link_staff;
		push @{$json->{data}}, { 
			datasetid => $eprint->dataset->base_id, 
			dataobjid => $eprint->id, 
			summary => EPrints::XML::to_string( $frag ),
#			grouping => sprintf( "%s", $eprint->value( SOME_FIELD ) ),
			problems => [ $self->validate_dataobj( $eprint ) ],
			state => $self->get_state( $eprint ),
			is_compliant => $self->is_compliant( $eprint ),
		};
	});

	print $self->to_json( $json );
}

sub is_compliant
{
	my( $self, $eprint ) = @_;

	my $repo = $self->{repository};
	if( $repo->config( "hefce_oa", "embargo_as_compliant" ) )
	{
		if( $self->get_state( $eprint ) )
		{
			return "Y";
		}
	}
	return undef;
}

#define any custom validation states
sub get_state
{
        my( $self, $eprint ) = @_;
	    my $repo = $eprint->repository;
        my $flag = $eprint->value( "hoa_compliant" );
	    unless ( $flag & HefceOA::Const::COMPLIANT )
        {
        	if( $flag & HefceOA::Const::DEP &&
                	        $flag & HefceOA::Const::DIS &&
                        	$flag & HefceOA::Const::ACC_EMBARGO &&
	                        $repo->call( ["hefce_oa", "could_become_ACC_TIMING_compliant"], $repo, $eprint ) ) #will be compliant in future, nothing administrator can do
        	{
	                return "#E19141"; #orange
        	}
	    }

	#return blue if compliance not relevant
#	if( $eprint->is_set( "hoa_date_acc" ) )
#	{
#		my $acc;
#		if( $repo->can_call( "hefce_oa", "handle_possibly_incomplete_date" ) ){
#			$acc = $repo->call( [ "hefce_oa", "handle_possibly_incomplete_date" ], $eprint->value( "hoa_date_acc" ) );
#		}
#		#Fallback (may error on incomplete dates
#		if(!defined $acc){
#			$acc = Time::Piece->strptime( $eprint->value( "hoa_date_acc" ), "%Y-%m-%d" );
#		}
#
#		my $APR16 = Time::Piece->strptime( "2016-04-01", "%Y-%m-%d " );
#		if(defined $acc &&  $acc < $APR16 )
#		{
#			return "#1F73C7"; #blue
#		}
#    }
	#return grey if out of scope
	my $out_of_scope = $repo->call( [ "hefce_oa", "OUT_OF_SCOPE_reason" ], $repo, $eprint );
    if( $out_of_scope )
    {
		return "#A9A9A9"; #grey
	}

	# return green if compliant override
	if( $eprint->is_set( "hoa_override" ) && $eprint->get_value( "hoa_override" ) eq "TRUE" )
	{
		return "#1F7E02"; # green
	}

	return undef;
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

	if( $eprint->is_set( "hoa_override" ) && $eprint->get_value( "hoa_override" ) eq "TRUE" )
	{
		 push @problems,  EPrints::XML::to_string( $repo->html_phrase( "report_compliant_override", override_reason => $repo->xml->create_text_node( $eprint->get_value( "hoa_override_txt" ) ) ) );
	}

	my $flag = $eprint->value( "hoa_compliant" );
	unless ( $flag & HefceOA::Const::COMPLIANT )
	{
		push @problems, $repo->phrase( "Plugin/Screen/EPrint/HefceOA:non_compliant" ); 
		foreach my $test ( qw(
			DEP_COMPLIANT
			DEP_TIMING
			DIS_DISCOVERABLE
			ACC_TIMING
			ACC_EMBARGO
		))
		{
			unless ( $flag & HefceOA::Const->$test )
			{
				push @problems, $repo->phrase( "hefce_oa:test_title:$test" ); 
			}
		}
		if( $flag & HefceOA::Const::DEP &&
                	$flag & HefceOA::Const::DIS &&
	                $flag & HefceOA::Const::ACC_EMBARGO &&
        	        $repo->call( ["hefce_oa", "could_become_ACC_TIMING_compliant"], $repo, $eprint ) )
		{
			push @problems,  EPrints::XML::to_string( $repo->html_phrase( "report_future_compliant", last_foa_date => $repo->xml->create_text_node( $repo->call( [ "hefce_oa", "calculate_last_compliant_foa_date" ], $repo, $eprint )->strftime( "%Y-%m-%d" ) ) ) );

            if( $eprint->is_set( "hoa_pre_pub" ) && $eprint->value( "hoa_pre_pub" ) eq "TRUE" )
            {
                push @problems, EPrints::XML::to_string( $repo->html_phrase( "report_pre_pub" ) );
                
            }
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
