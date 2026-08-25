use HefceOA::Const;
use Time::Piece;
use Time::Seconds;

$c->{hefce_oa}->{run_test} = sub {
    my( $repo, $test, $eprint, $flag ) = @_;

    if( $repo->can_call( "hefce_oa", "run_test_$test" ) )
    {
        return $repo->call( [ "hefce_oa", "run_test_$test" ], $repo, $eprint, $flag );
    }

    return 0;
};

$c->{hefce_oa}->{run_test_COMPLIANT} = sub {
    my( $repo, $eprint, $flag ) = @_;

    if( $repo->can_call( "hefce_oa", "run_test_OUT_OF_SCOPE" ) )
    {
        return 1 if($repo->call( [ "hefce_oa", "run_test_OUT_OF_SCOPE" ], $repo, $eprint ));
    }

    return 1 if( $eprint->is_set( "hoa_override" ) && $eprint->get_value( "hoa_override" ) eq "TRUE" );

    return 1 if( $eprint->is_set( "hoa_gold" ) && $eprint->get_value( "hoa_gold" ) eq "TRUE" );

    return 1 if $flag & HefceOA::Const::EX_DEP;

    return 1 if
        $flag & HefceOA::Const::EX_ACC &&
        $flag & HefceOA::Const::DEP &&
        $flag & HefceOA::Const::DIS;

    return 1 if $flag & HefceOA::Const::EX_TEC;

    return 1 if $flag & HefceOA::Const::EX_FUR;

    return 1 if
        $flag & HefceOA::Const::DEP &&
        $flag & HefceOA::Const::DIS &&
        $flag & HefceOA::Const::ACC;

    return 0;
};

$c->{hefce_oa}->{run_test_DEP} = sub {
    my( $repo, $eprint, $flag ) = @_;

    return 1 if
        $flag & HefceOA::Const::DEP_COMPLIANT &&
        $flag & HefceOA::Const::DEP_TIMING;

    return 0;
};

$c->{hefce_oa}->{run_test_DIS} = sub {
    my( $repo, $eprint, $flag ) = @_;

    return 1 if $flag & HefceOA::Const::DIS_DISCOVERABLE;

    return 0;
};

$c->{hefce_oa}->{run_test_ACC} = sub {
    my( $repo, $eprint, $flag ) = @_;

    return 1 if
        $flag & HefceOA::Const::ACC_TIMING &&
        $flag & HefceOA::Const::ACC_EMBARGO;

    return 0;
};

$c->{hefce_oa}->{run_test_EX_DEP} = sub {
    my( $repo, $eprint, $flag ) = @_;

    return 1 if $eprint->is_set( "hoa_ex_dep" );

    return 0;
};

$c->{hefce_oa}->{run_test_EX_ACC} = sub {
    my( $repo, $eprint, $flag ) = @_;

    return 1 if $eprint->is_set( "hoa_ex_acc" );

    return 0;
};

$c->{hefce_oa}->{run_test_EX_TEC} = sub {
    my( $repo, $eprint, $flag ) = @_;

    return 1 if $eprint->is_set( "hoa_ex_tec" );

    return 0;
};

$c->{hefce_oa}->{run_test_EX_FUR} = sub {
    my( $repo, $eprint, $flag ) = @_;

    return 1 if $eprint->is_set( "hoa_ex_fur" );

    return 0;
};


#$c->{hefce_oa}->{run_test_EX_OTH} = sub {
#    my( $repo, $eprint, $flag ) = @_;
#
#    return 1 if $eprint->is_set( "hoa_ex_oth" );
#
#    return 0;
#};

$c->{hefce_oa}->{run_test_DEP_TIMING} = sub {
	my( $repo, $eprint, $flag ) = @_;

	return 0 unless $eprint->is_set( "hoa_date_fcd" );
	
	my $dep = Time::Piece->strptime( $eprint->value( "hoa_date_fcd" ), "%Y-%m-%d" );
	my $APR18 = Time::Piece->strptime( "2018-04-01", "%Y-%m-%d" );

	# checks based on date of acceptance (if set)
	if( $eprint->is_set( "hoa_date_acc" ) )
	{
		my $acc;
		if( $repo->can_call( "hefce_oa", "handle_possibly_incomplete_date" ) )
		{
			$acc = $repo->call( [ "hefce_oa", "handle_possibly_incomplete_date" ], $eprint->value( "hoa_date_acc" ) );
		}
		if( !defined( $acc ) ) #above call can return undef - fallback to default
		{
			$acc = Time::Piece->strptime( $eprint->value( "hoa_date_acc" ), "%Y-%m-%d" );
		}
	
		# deposit is within 3  months of acceptance
		return 1 if $dep <= $acc->add_months(3); 

		#for pre-April '18, base calculation on pub date
		if( $acc < $APR18 && $eprint->is_set( "hoa_date_pub" ) )
		{
			my $pub;
			if( $repo->can_call( "hefce_oa", "handle_possibly_incomplete_date" ) )
			{
				$pub = $repo->call( [ "hefce_oa", "handle_possibly_incomplete_date" ], $eprint->value( "hoa_date_pub" ) );
			}
			if( !defined( $pub ) ) #above call can return undef - fallback to default
			{
				$pub = Time::Piece->strptime( $eprint->value( "hoa_date_pub" ), "%Y-%m-%d" );
			}
			return 1 if $dep <= $pub->add_months(3);
		}
		
	}
	elsif( $eprint->is_set( "hoa_date_pub" ) )
	{
		my $pub;
		if( $repo->can_call( "hefce_oa", "handle_possibly_incomplete_date" ) )
		{
			$pub = $repo->call( [ "hefce_oa", "handle_possibly_incomplete_date" ], $eprint->value( "hoa_date_pub" ) );
		}
		if( !defined( $pub ) ) #above call can return undef - fallback to default
		{
			$pub = Time::Piece->strptime( $eprint->value( "hoa_date_pub" ), "%Y-%m-%d" );
		}
		
		#if published date is before 2018-04-01, acceptance date must be too.
		# NB we may need to introduce a lag here - if it normally takes a month to get something published,
		# we may need to check for 'APR18 + 1 month'
		if( $pub < $APR18 )
		{
			return 1 if $dep <= $pub->add_months(3);
		}
	}

	return 0;
};

$c->{hefce_oa}->{run_test_DEP_COMPLIANT} = sub {
	my( $repo, $eprint, $flag ) = @_;

	return $eprint->is_set( "hoa_date_fcd" );
};

$c->{hefce_oa}->{run_test_DIS_DISCOVERABLE} = sub {
    my( $repo, $eprint, $flag ) = @_;

    return 1 if $eprint->value( "eprint_status" ) eq "archive";

    return 0;
};

$c->{hefce_oa}->{run_test_ACC_TIMING} = sub {
    my( $repo, $eprint, $flag ) = @_;

    my $len = $eprint->value( "hoa_emb_len" ) || 0;

    if( $len > 0  )
    {
        # we need a publication date to work out when our embargo ends
        return 0 unless $eprint->is_set( "hoa_date_pub" );
        my $pub;
        if( $repo->can_call( "hefce_oa", "handle_possibly_incomplete_date" ) )
        {
            $pub = $repo->call( [ "hefce_oa", "handle_possibly_incomplete_date" ], $eprint->value( "hoa_date_pub" ) );
        }
        if( !defined( $pub ) ) #above call can return undef - fallback to default
        {
            $pub = Time::Piece->strptime( $eprint->value( "hoa_date_pub" ), "%Y-%m-%d" );
        }

        my $end = $pub->add_months( $len ); # embargo end

        # emabargoes that end at/after the submission deadline are compliant
        # DEADLINE TO BE CONFIRMED BUT WILL BE BEFORE 2028
        my $DEADLINE = Time::Piece->strptime( "2028-01-01", "%Y-%m-%d" );
        if( $end >= $DEADLINE )
        {
            return 1;
        }

        # we now need a first open access date to see if this happened in time with respect to the embargo
        return 0 unless $eprint->is_set( "hoa_date_foa" );

        my $foa = Time::Piece->strptime( $eprint->value( "hoa_date_foa" ), "%Y-%m-%d" );

        # oa within one month of embargo end
        return 1 if $foa <= $end->add_months( 1 );
    }
    elsif( $eprint->is_set( "hoa_pre_pub" ) && $eprint->value( "hoa_pre_pub" ) eq "TRUE" ) 
    {
        # pre publication embargo - i .e. no embargo has been set but we want to base this test on the published date, not fcd date
        
        return 0 unless $eprint->is_set( "hoa_date_pub" );
        my $pub;
        if( $repo->can_call( "hefce_oa", "handle_possibly_incomplete_date" ) )
        {
            $pub = $repo->call( [ "hefce_oa", "handle_possibly_incomplete_date" ], $eprint->value( "hoa_date_pub" ) );
        }
        if( !defined( $pub ) ) #above call can return undef - fallback to default
        {
            $pub = Time::Piece->strptime( $eprint->value( "hoa_date_pub" ), "%Y-%m-%d" );
        }

        my $end = $pub->add_months( 1 ); # embargo end

        # emabargoes that end at/after the submission deadline are compliant
        # DEADLINE TO BE CONFIRMED BUT WILL BE BEFORE 2028
        my $DEADLINE = Time::Piece->strptime( "2028-01-01", "%Y-%m-%d" );
        if( $end >= $DEADLINE )
        {
            return 1;
        }

        # we now need a first open access date to see if this happened in time with respect to the embargo
        return 0 unless $eprint->is_set( "hoa_date_foa" );

        my $foa = Time::Piece->strptime( $eprint->value( "hoa_date_foa" ), "%Y-%m-%d" );

        # oa within one month of embargo end
        return 1 if $foa <= $end->add_months( 1 );
    }
    else # no embargo
    {
        return 0 unless $eprint->is_set( "hoa_date_fcd" ) && $eprint->is_set( "hoa_date_foa" );

        my $fcd = Time::Piece->strptime( $eprint->value( "hoa_date_fcd" ), "%Y-%m-%d" );
        my $foa = Time::Piece->strptime( $eprint->value( "hoa_date_foa" ), "%Y-%m-%d" );

        # oa with one month of deposit
        return 1 if $foa <= $fcd->add_months( 1 );
    }

    return 0;
};

$c->{hefce_oa}->{run_test_ACC_EMBARGO} = sub {
	my( $repo, $eprint, $flag ) = @_;

	my $len = $eprint->value( "hoa_emb_len" ) || 0;

	my $pan = $eprint->value( "hoa_ref_pan" );
	if( !defined $pan && $repo->can_call( 'hefce_oa', 'deduce_panel' ) )
	{
		$pan = $repo->call( [ 'hefce_oa', 'deduce_panel' ], $eprint );
	}

	my $max = ( defined $pan && $pan eq "AB" ) ? 12 : 24;

	return 1 unless $len > $max;

	return 0;
};

$c->{hefce_oa}->{run_test_EX} = sub {
    my( $repo, $eprint, $flag ) = @_;

    return 1 if
        $flag & HefceOA::Const::EX_DEP ||
        $flag & HefceOA::Const::EX_ACC ||
        $flag & HefceOA::Const::EX_TEC ||
        $flag & HefceOA::Const::EX_FUR;

    return 0;
};

$c->{hefce_oa}->{could_become_ACC_TIMING_compliant} = sub {
    my( $repo, $eprint ) = @_;

    my $last_compliant_date = $repo->call( [ "hefce_oa", "calculate_last_compliant_foa_date" ], $repo, $eprint );
    return 1 if( $last_compliant_date && ( localtime() <= $last_compliant_date ) );

    return 0;
};

$c->{hefce_oa}->{OUT_OF_SCOPE_reason} = sub {

    my( $repo, $eprint ) = @_;

    my $APR16 = Time::Piece->strptime( "2016-04-01", "%Y-%m-%d" );
    my $JAN21 = Time::Piece->strptime( "2021-01-01", "%Y-%m-%d" );

    if( $eprint->is_set( "hoa_date_pub" ) )
    {
        my $pub;
        if( $repo->can_call( "hefce_oa", "handle_possibly_incomplete_date" ) )
        {
            $pub = $repo->call( [ "hefce_oa", "handle_possibly_incomplete_date" ], $eprint->value( "hoa_date_pub" ) );
        }
        if( !defined( $pub ) ) #above call can return undef - fallback to default
        {
            $pub = Time::Piece->strptime( $eprint->value( "hoa_date_pub" ), "%Y-%m-%d" );
        }

        # Published before 1st Apr 2016, compliant as out of OA policy scope
        return "2014_pub" if $pub < $APR16;

        if( !$repo->config( "hefce_oa", "ref2021_in_scope" ) )
        {
            # Published is before 1st Jan 2021, out of scope of 2029
            return "2021_pub" if $pub < $JAN21;
        }
    }

    if( EPrints::Utils::is_set( $repo->config( "hefce_oa", "enforce_issn" ) ) && $repo->config( "hefce_oa", "enforce_issn" ) == 1 && !$eprint->is_set( "issn" ) )
    {
        return "issn";
    }

    return 0;
};

$c->{hefce_oa}->{run_test_OUT_OF_SCOPE} = sub {

    my( $repo, $eprint ) = @_;

    my $out_of_scope = $repo->call( [ "hefce_oa", "OUT_OF_SCOPE_reason" ], $repo, $eprint );
    if( $out_of_scope )
    {
        return 1;
    }
    else
    {
        return 0;
    }
};

$c->{hefce_oa}->{run_test_AUDIT} = sub {
    my( $repo, $eprint, $flag ) = @_;

    return 1 if
        $flag & HefceOA::Const::AUD_UP_OA &&
        $flag & HefceOA::Const::AUD_UP_URL;

    return 0;
};

$c->{hefce_oa}->{run_test_AUD_UP_OA} = sub {
    my( $repo, $eprint, $flag ) = @_;
    
    # get audit record
    my $audit_ds = $repo->dataset( "hefce_oa_audit" );
    my $audit = $audit_ds->dataobj_class->get_audit_record( $repo, $eprint );

    return 0 unless defined $audit;
    return 0 unless $audit->is_set( "up_is_oa" );

    if( $audit->get_value( "up_is_oa" ) eq "TRUE" )
    {
        return 1;
    }

    return 0;
};

$c->{hefce_oa}->{run_test_AUD_UP_URL} = sub {
    my( $repo, $eprint, $flag ) = @_;

    # get audit record
    my $audit_ds = $repo->dataset( "hefce_oa_audit" );
    my $audit = $audit_ds->dataobj_class->get_audit_record( $repo, $eprint );

    return 0 unless defined $audit;
    return 1 if $audit->is_set( "up_url_for_pdf" );

    return 0;
};

$c->{hefce_oa}->{run_test_AUD_CORE_DATES} = sub {
    my( $repo, $eprint, $flag ) = @_;

    # get audit record
    my $audit_ds = $repo->dataset( "hefce_oa_audit" );
    my $audit = $audit_ds->dataobj_class->get_audit_record( $repo, $eprint );

    return 0 unless defined $audit;
    return 0 unless $audit->is_set( "core_sources" );

    foreach my $cs ( @{$audit->get_value( "core_sources" )} )
    {
        next unless defined $cs->{datePublished};
        next unless defined $cs->{depositedDate};

        my $dp = $cs->{datePublished};
        my $dd = $cs->{depositedDate};
        # datePublished is a string and can be incomplete (others are timestamps)
        # It would be better to use publishedDate rather than datePublished but RE say use DP
        if( $repo->can_call( "hefce_oa", "handle_possibly_incomplete_date" ) )
        {
            $dp = $repo->call( [ "hefce_oa", "handle_possibly_incomplete_date" ], $dp );
        }

        my $dep = Time::Piece->strptime( $dd, "%Y-%m-%d" );
    
        my $diff = $dep - $dp;
        if( $diff->days < 92 ){ # one of them was deposited in time
            return 1;
        }
    }

    return 0;
};
