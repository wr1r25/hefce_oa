package EPrints::Plugin::Screen::Report::REF_2029_CC;

use EPrints::Plugin::Screen::Report;
our @ISA = ( 'EPrints::Plugin::Screen::Report' );

use HefceOA::Const;
use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{datasetid} = 'eprint';
	$self->{searchdatasetid} = 'eprint';
	$self->{custom_order} = '-title/creators_name';
	$self->{appears} = [];
	$self->{report} = 'ref2029_cc';
	$self->{sconf} = 'hefce_report';
	$self->{export_conf} = 'ref2029_cc_report';
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

        # we need a ref2029 cc record
        my $ref2029_cc = undef;
        if( $eprint->is_set( "ref2029_cc" ) && $eprint->value( "ref2029_cc" )->value( "scope" ) eq "26-28" )
        {
            $ref2029_cc = $eprint->value( "ref2029_cc" );
        }

		my $frag = $eprint->render_citation_link_staff;
		push @{$json->{data}}, { 
			datasetid => $eprint->dataset->base_id, 
			dataobjid => $eprint->id, 
			summary => EPrints::XML::to_string( $frag ),
			problems => [ $self->validate_dataobj( $eprint, $ref2029_cc ) ],
			state => $self->get_state( $eprint, $ref2029_cc ),
			bullets => [ $self->bullet_points( $eprint, $ref2029_cc ) ],
		};
	});

	print $self->to_json( $json );
}

sub get_state
{
    my( $self, $eprint, $ref2029_cc ) = @_;
    my $repo = $eprint->repository;

    return undef unless $ref2029_cc;

    my $flag = $ref2029_cc->value( "compliant" ) || 0;
    my( $result, $reason ) = $ref2029_cc->test_COMPLIANT( $repo, $eprint, $flag );

    if( $reason eq "acc_potential_emb" || $reason eq "acc_potential" )
    {
        return "#E19141"; # orange
    }

    return undef;
}

sub validate_dataobj
{
	my( $self, $eprint, $ref2029_cc ) = @_;

	my $repo = $self->{repository};

	my @problems;

    # we need a ref2029 cc record
    if( !defined $ref2029_cc )
    {
        push @problems, $repo->phrase( "ref2029_cc:missing_ref2029_record" );
        return @problems;
    }

    my $flag = $ref2029_cc->value( "compliant" ) || 0;
	unless ( $ref2029_cc->test_COMPLIANT( $repo, $eprint, $flag ) )
	{
		push @problems, $repo->phrase( "ref2029_cc:non_compliant" ); 
		foreach my $test ( qw(
			DEP_COMPLIANT
			DEP_TIMING
			DIS_DISCOVERABLE
			ACC_TIMING
            ACC_LIC
			ACC_EMBARGO
		))
		{
			unless( $ref2029_cc->run_flag_check( $test ) )
			{
				push @problems, $repo->phrase( "ref2029_cc:problem:$test" ); 
			}
		}
	}

	return @problems;
}

sub bullet_points
{
    my( $self, $eprint, $ref2029_cc ) = @_;

    my $repo = $self->{repository};

    my @bullets;

    if( !defined $ref2029_cc )
    {
        return @bullets;
    }    

    foreach my $field ( qw(
	    ref2029_pub_agreement
		ref2029_gold_oa
		ref2029_override
        ref2029_pre_compliant
        ref2029_ex_acc
        ref2029_ex_tec
        ref2029_ex_fur
	))
    {
        if( $ref2029_cc->is_set( $field ) )
        {
            my $value = $ref2029_cc->value( $field );
            if( $value ne "" && $value ne "FALSE" )
            {   
                if( $field eq "ref2029_ex_acc" ||
                    $field eq "ref2029_ex_tec" || 
                    $field eq "ref2029_ex_fur" )
                {
                    push @bullets, $repo->html_phrase( "ref2029_cc_fieldname_$field" ).": ".$repo->html_phrase( "ref2029_cc_fieldopt_$field\_$value" );
                }
                else
                {
                    push @bullets, $repo->html_phrase( "ref2029_cc_fieldname_$field" ).": ".$value;
                }
            }
        }
    }
    return @bullets;
}

# applies any mandatory filters to a search object - used to enforce certain search criteria, even with a custom report
sub apply_filters
{
	my( $self ) = @_;

	my $ds = $self->repository->dataset( 'eprint' );

    # this report should only include items published after the rule change in Jan 26
    my $pub_field = $ds->field( "hoa_date_pub" );
	$self->{processor}->{search}->add_field( fields => $pub_field,
		value => '2026-01-01-',
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
