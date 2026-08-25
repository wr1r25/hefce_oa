# A REF CC dataobj that will be used to store all things REF OA compliance
# related for an EPrint. This has two main advantages...
# 1) We don't need to add more fields to the EPrints table
# 2) All of our methods needed for assessing compliance can be made here

package EPrints::DataObj::REF2029_CC;

our @ISA = qw( EPrints::DataObj::SubObject );

use constant {
    COMPLIANT               => 1,
    DEP                     => 2,
    DEP_TIMING              => 4,
    DEP_COMPLIANT           => 8,
    DIS                     => 16,
    DIS_DISCOVERABLE        => 32,
    ACC                     => 64,
    ACC_TIMING              => 128,
    ACC_EMBARGO             => 256,
    ACC_LIC                 => 512,
    ACC_POTENTIAL           => 1024,
    ACC_TIMING_POTENTIAL    => 2048,
    ACC_LIC_POTENTIAL       => 4096,
    EX_DEP                  => 8192,
    EX_ACC_EMB              => 16384,
    EX_ACC_LIC              => 32768,
    EX_TEC                  => 65536,
    EX_FUR                  => 131072,
    EX_LIC                  => 262144,
    EX                      => 524288,
    GOLD                    => 1048576,
};

use strict;
use Data::Dumper;
use Time::Piece;

# The new method can simply return the constructor of the super class (Dataset)
sub new
{
    return shift->SUPER::new( @_ );
}

# There must be a better way of doing this sort of thing?
sub get_const
{
    my( $self, $const ) = @_;

    return $self->$const;
}

sub get_dataset_id
{
    my ($self) = @_;
    return "ref2029_cc";
}

sub get_parent_dataset_id
{
    "eprint";
}

sub get_parent_id
{
    my( $self ) = @_;

    return $self->get_value( "eprintid" );
}

sub get_system_field_info
{
    my( $class ) = @_;

    return
    (
        { name => "ref2029_ccid", type => "counter", required => 1, import => 0, show_in_html => 0, can_clone => 0, sql_counter => "ref2029_ccid" },

        { name => "eprintid", type => "itemref", datasetid => "eprint", required => 1 },
    );
}

sub commit
{
    my( $self, $force ) = @_;

    # this will call set_ref2029_cc_automatic_fields
    $self->update_triggers();

    if( scalar( keys %{$self->{changed}} ) == 0 )
    {
        # don't do anything if there isn't anything to do
        return( 1 ) unless $force;
    }

    return $self->SUPER::commit( $force );
}

sub create_from_data
{
    my( $class, $session, $data, $dataset ) = @_;

    my $self = $class->SUPER::create_from_data( $session, $data, $dataset );

    return undef unless defined $self;

    # this will call set_ref2029_cc_automatic_fields
    $self->update_triggers();

    $self->SUPER::commit();

    return $self;
}

sub calculate_scope
{
    my( $self ) = @_;

    my $repo = $self->repository;

    # get the eprint
    my $eprint = $self->get_parent;
    return unless defined $eprint;

    my $scope = "out";

    # check when the item was published
    my $JAN21 = Time::Piece->strptime( "2021-01-01", "%Y-%m-%d" ); 
    my $DEC25 = Time::Piece->strptime( "2025-12-31", "%Y-%m-%d" );
    my $JAN26 = Time::Piece->strptime( "2026-01-01", "%Y-%m-%d" );
    my $DEC28 = Time::Piece->strptime( "2028-12-31", "%Y-%m-%d" );    

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

        if( $pub >= $JAN26 && $pub <= $DEC28 )
        {
            $scope = "26-28";
        }
        elsif( $pub > $JAN21 && $pub <= $DEC25 )
        {
            $scope = "21-25";
        }
        
        $self->set_value( "scope", $scope );
        $self->commit;
        return;
    }
    elsif( $eprint->is_set( "hoa_date_acc" ) )
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

        if( $acc >= $JAN26 && $acc <= $DEC28 ) # accepted after JAN26 means we're published after JAN26 (this may catch some stuff that falls out of scope if accepted too close to DEC28 though...)
        {           
            $scope = "26-28";
            $self->set_value( "scope", $scope );
            $self->commit;
            return;
        }
    }

    # set the default as out of scope
    $self->set_value( "scope", $scope );
    $self->commit;
    return;
}  

sub update_data
{
    my( $self ) = @_;

    my $repo = $self->repository;

    my $eprint = $self->get_parent;

    # double check our scope 
    $self->calculate_scope;

    # gather other bits of data we might need to check compliance
    # earliest embargo date
    my @embargoes;
    for( $eprint->get_all_documents )
    {
        next unless $_->is_set( "content" );
        my $content = $_->value( "content" );
        next unless grep( /^$content$/, @{$repo->config( "hefce_oa", "document_content" )});
        push @embargoes, $_->value( "date_embargo" ) if $_->is_set( "date_embargo" );
    }

    if( scalar @embargoes > 0 )
    {
       @embargoes = sort {$a cmp $b} @embargoes;
       my $earliest_date = shift @embargoes;
       $self->set_value( "embargo", $earliest_date );
    }

    # get the date the first time a document that had an appropriate licence was made available
    if( !$self->is_set( "licensed_foa" ) )
    {
        for( $eprint->get_all_documents )
        {
            # is it the correct type
            next unless $_->is_set( "content" );
            my $content = $_->value( "content" );                         
            next unless grep( /^$content$/, @{$repo->config( "hefce_oa", "document_content" )} );

            # and is it open
            next unless $_->is_public;

            # we don't need to worry about the licence for this eprint (OA policy: 7.5.4)
            if( $self->is_set( "ref2029_pub_agreement" ) && $self->value( "ref2029_pub_agreement" ) eq "TRUE" )
            {
                # we may have just set a pub agreement for the first time on an old record that previously had hoa_date_foa set
                if( $eprint->is_set( "hoa_date_foa" ) )
                {
                    $self->set_value( "licensed_foa", $eprint->value( "hoa_date_foa" ) );
                }
                else
                {
                    $self->set_value( "licensed_foa", EPrints::Time::get_iso_date() );
                }
                last;
            }
            else # we do care about a licence
            {
                # does it have a correct license
                next unless $_->is_set( "license" );
                my $license = $_->value( "license" );                         
                next unless grep( /^$license$/, @{$repo->config( "ref2029", "licenses" )} );

                # we have seen the correct license on an open document
                $self->set_value( "licensed_foa", EPrints::Time::get_iso_date() );
                last;
            }
        }
    }
    else
    {
        # licensed_foa is set, but is it set to the right value
        if( $eprint->is_set( "hoa_date_foa" ) &&
            $eprint->value( "hoa_date_foa" ) ne $self->value( "licensed_foa" ) &&
            $self->is_set( "ref2029_pub_agreement" ) &&
            $self->value( "ref2029_pub_agreement" ) eq "TRUE" )
        {
            # we have conditions which match the old REF rules
            $self->set_value( "licensed_foa", $eprint->value( "hoa_date_foa" ) );
        }

    }

    $self->commit;
}

sub run_flag_check
{
    my( $self, $test ) = @_;

    return 0 if !$self->is_set( "compliant" );

    my $flag = $self->value( "compliant" );
    return $flag & $self->$test;
}

sub test_compliance
{
    my( $self ) = @_;

    my $repo = $self->repository;

    my $eprint = $self->get_parent;

    my $flag = 0;
    for(qw(
        DEP_COMPLIANT
        DEP_TIMING
        DEP
        DIS_DISCOVERABLE
        DIS
        ACC_TIMING
        ACC_EMBARGO
        ACC_LIC   
        ACC
        ACC_TIMING_POTENTIAL
        ACC_LIC_POTENTIAL
        ACC_POTENTIAL
        EX_DEP
        EX_ACC_EMB
        EX_ACC_LIC
        EX_TEC
        EX_FUR
        EX_LIC
        EX
        GOLD
        COMPLIANT
    ))
    {
        my $test_fn = "test_$_";
        $flag |= $self->$_ if $self->$test_fn( $repo, $eprint, $flag );
    }
    $self->set_value( "compliant", $flag );
    $self->commit;
}

# returns a true/false for compliance and the reasoning
# the reasoning can be used by the screen to display a useful message
sub test_COMPLIANT
{
    my( $self, $repo, $eprint, $flag ) = @_;

    # compliant if overridden
    return (1, "override") if( $self->is_set( "ref2029_override" ) && $self->get_value( "ref2029_override" ) eq "TRUE" );
    
    # compliant if flagged as compliant elsewhere
    return (1, "pre_compliant") if( $self->is_set( "ref2029_pre_compliant" ) && $self->get_value( "ref2029_pre_compliant" ) eq "TRUE" );

    # compliant if gold OA
    return (1, "gold_oa") if $flag & GOLD;

    # compliant if EX_DEP
    return (1, "ex_dep") if $flag & EX_DEP;

    # compliant if EX_ACC_EMB = 8.2.2 && DEP && DIS && ACC_TIMING && ACC_LIC
    return (1, "ex_acc_emb" ) if
        $flag & EX_ACC_EMB &&
        $flag & DEP &&
        $flag & DIS &&
        $flag & ACC_TIMING &&
        $flag & ACC_LIC;

    # compliant if EX_ACC_LIC = 8.2.3 && DEP && DIS
    return (1, "ex_acc_lic" ) if
        $flag & EX_ACC_LIC &&
        $flag & DEP &&
        $flag & DIS;

    # compliant if EX_TEC
    return (1, "ex_tec") if $flag & EX_TEC;

    # compliant if EX_FUR
    return (1, "ex_fur") if $flag & EX_FUR;

    # 1 if DEP && DIS && ACC && LIC
    return (1, "compliant" ) if
        $flag & DEP &&
        $flag & DIS &&
        $flag & ACC;

    return( 1, "acc_potential_emb" ) if
        $flag & EX_ACC_EMB &&
        $flag & DEP &&
        $flag & DIS &&
        $flag & ACC_POTENTIAL;
 
     return( 1, "acc_potential" ) if
        $flag & DEP &&
        $flag & DIS &&
        $flag & ACC_EMBARGO &&
        $flag & ACC_POTENTIAL;
    
    return 0;
}

sub test_DEP
{
    my( $self, $repo, $eprint, $flag ) = @_;

    return 1 if
        $flag & DEP_COMPLIANT &&
        $flag & DEP_TIMING;

    return 0;
}

# 7.2.3 - copy should be deposited within three months of publication
sub test_DEP_TIMING
{
    my( $slef, $repo, $eprint, $flag ) = @_;
    
    return 0 unless $eprint->is_set( "hoa_date_fcd" );

    my $dep = Time::Piece->strptime( $eprint->value( "hoa_date_fcd" ), "%Y-%m-%d" );
   
    # check if we have a publication date and deposit date is within 3 months
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

        return 1 if $dep <= $pub->add_months(3);       
    }

    # we might have an acceptance date, if we're within 3 months of acceptance date then we will be within 3 months of publication (as publication comes after acceptance)
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
    }

    return 0;  
}

# 7.2.5 - deposit should be either AAM or VoR
sub test_DEP_COMPLIANT
{
    my( $self, $repo, $eprint, $flag ) = @_;

    return $eprint->is_set( "hoa_date_fcd" ); # fcd only gets set when we have an AAM or VoR
}

sub test_DIS
{
    my( $self, $repo, $eprint, $flag ) = @_;

    return 1 if $flag & DIS_DISCOVERABLE;

    return 0;
}

# 7.3.1 - output must be discoverable by readers and automated tools
sub test_DIS_DISCOVERABLE
{
    my( $self, $repo, $eprint, $flag ) = @_;

    return 1 if $eprint->value( "eprint_status" ) eq "archive";

    return 0;
}

sub test_ACC
{
    my( $self, $repo, $eprint, $flag ) = @_;   

    return 1 if
        $flag & ACC_TIMING &&
        $flag & ACC_EMBARGO &&
        $flag & ACC_LIC;

    return 0;
}

sub test_ACC_POTENTIAL
{
    my( $self, $repo, $eprint, $flag ) = @_;   

    return 1 if
        $flag & ACC_LIC_POTENTIAL &&
        $flag & ACC_TIMING_POTENTIAL;

    return 0;
}

sub test_ACC_LIC_POTENTIAL
{
    my( $self, $repo, $eprint, $flag ) = @_;   

    # do we have a document with the correct licence that has an embargo at least?
    for( $eprint->get_all_documents )
    {
        # is it the correct type
        next unless $_->is_set( "content" );
        my $content = $_->value( "content" );                         
        next unless grep( /^$content$/, @{$repo->config( "hefce_oa", "document_content" )} );

        # check to see if we need to check the license for this record
        unless( $self->is_set( "ref2029_pub_agreement" ) && $self->value( "ref2029_pub_agreement" ) eq "TRUE" )
        {    
            # does it have a correct license
            next unless $_->is_set( "license" );
            my $license = $_->value( "license" );                         
            next unless grep( /^$license$/, @{$repo->config( "ref2029", "licenses" )} );
        }

        next if $_->is_public; # this is already public, we don't care about potential stuff...
       
        next unless $self->is_set( "embargo" );
        next unless $_->is_set( "date_embargo" );

        my $local_time = localtime();

        # this document needs to have an appropriate licence and an embargo date that is before the earliest embargo release
        my $emb;
        if( $repo->can_call( "hefce_oa", "handle_possibly_incomplete_date" ) )
        {
            $emb = $repo->call( [ "hefce_oa", "handle_possibly_incomplete_date" ], $self->value( "embargo" ) );
        }
        if( !defined( $emb ) ) #above call can return undef - fallback to default
        {
            $emb = Time::Piece->strptime( $self->value( "embargo" ), "%Y-%m-%d" );
        }         

        my $doc_emb;
        if( $repo->can_call( "hefce_oa", "handle_possibly_incomplete_date" ) )
        {
            $doc_emb = $repo->call( [ "hefce_oa", "handle_possibly_incomplete_date" ], $_->value( "date_embargo" ) );
        }
        if( !defined( $doc_emb ) ) #above call can return undef - fallback to default
        {
            $doc_emb = Time::Piece->strptime( $_->value( "date_embargo" ), "%Y-%m-%d" );
        }       

        return 1 if $local_time <= $emb && $doc_emb <= $emb;
    }
}

sub test_ACC_TIMING_POTENTIAL
{
    my( $self, $repo, $eprint, $flag ) = @_;   

    my $local_time = localtime();

    if( $self->is_set( "embargo" ) )
    {
         # we have an embargo, open access must be available as soon as embargo expires
        my $emb;
        if( $repo->can_call( "hefce_oa", "handle_possibly_incomplete_date" ) )
        {
            $emb = $repo->call( [ "hefce_oa", "handle_possibly_incomplete_date" ], $self->value( "embargo" ) );
        }
        if( !defined( $emb ) ) #above call can return undef - fallback to default
        {
            $emb = Time::Piece->strptime( $self->value( "embargo" ), "%Y-%m-%d" );
        }                         
        
        return 1 if $local_time <= $emb;  
    }
    else
    {
        # we must be within three months of publication still
        # check if we have a publication date and deposit date is within 3 months
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
            return 1 if $local_time <= $pub->add_months(3);       
        }  
    }

    return 0;
}


# 7.4.2 - output must be made fully accessible on deposit, subject to embargo 
sub test_ACC_TIMING
{
    my( $self, $repo, $eprint, $flag ) = @_;

	my $foa;

	if( $eprint->is_set( "hoa_date_foa" ) &&
        $self->is_set( "ref2029_pub_agreement" ) &&
        $self->value( "ref2029_pub_agreement" ) eq "TRUE" )	
    {
		# old foa date will do...
		$foa = Time::Piece->strptime( $self->value( "licensed_foa" ), "%Y-%m-%d" );
	}
	elsif( $self->is_set( "licensed_foa" ) )
	{
		$foa = Time::Piece->strptime( $self->value( "licensed_foa" ), "%Y-%m-%d" );
	}

	return 0 unless defined $foa;

    if( $self->is_set( "embargo" ) )
    {
        # we have an embargo, open access must be available as soon as embargo expires
        my $emb;
        if( $repo->can_call( "hefce_oa", "handle_possibly_incomplete_date" ) )
        {
            $emb = $repo->call( [ "hefce_oa", "handle_possibly_incomplete_date" ], $self->value( "embargo" ) );
        }
        if( !defined( $emb ) ) #above call can return undef - fallback to default
        {
            $emb = Time::Piece->strptime( $self->value( "embargo" ), "%Y-%m-%d" );
        }                         

        return 1 if $foa <= $emb;
    }
    else
    {
        # we must be within three months of publication still
        # check if we have a publication date and deposit date is within 3 months
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
            return 1 if $foa <= $pub->add_months(3);       
        }  

        # we might have an acceptance date, if we're within 3 months of acceptance date then we will be within 3 months of publication (as publication comes after acceptance)
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

            # within 3  months of acceptance
            return 1 if $foa <= $acc->add_months(3);
        }
    }

    return 0;
}

# 7.6.1 - Embargo period must be up to 6 months for Panels A and B, or 12 months for Panels C and D
sub test_ACC_EMBARGO
{
    my( $self, $repo, $eprint, $flag ) = @_;

    my $len = $eprint->value( "hoa_emb_len" ) || 0;

    my $pan = $eprint->value( "hoa_ref_pan" );
    if( !defined $pan && $repo->can_call( 'hefce_oa', 'deduce_panel' ) )
    {
        $pan = $repo->call( [ 'hefce_oa', 'deduce_panel' ], $eprint );
    }

    my $max = ( defined $pan && $pan eq "AB" ) ? 6 : 12;

    return 1 unless $len > $max;

    return 0;
}

# 7.5.2 - outputs should use a CC-BY, CC-BY-NC, CC-BY-ND or CC-BY-NC-ND
sub test_ACC_LIC
{
    my( $self, $repo, $eprint, $flag ) = @_;

    # we don't need to check the license for this record
    if( $self->is_set( "ref2029_pub_agreement" ) && $self->value( "ref2029_pub_agreement" ) eq "TRUE" )
    {
        return 1;
    }
    else
    {
        # do we have a correctly licensed document  
        return $self->is_set( "licensed_foa" ); # licensed_foa only gets set when we have an AAM or VoR, publicly available under a valid licence
    }
}

sub test_EX_DEP
{
    my( $self, $repo, $eprint, $flag ) = @_;

    return 1 if $self->is_set( "ref2029_ex_dep" );

    return 0;
}

sub test_EX_ACC_EMB
{
    my( $self, $repo, $eprint, $flag ) = @_;

    return 1 if $self->is_set( "ref2029_ex_acc" ) && $self->value( "ref2029_ex_acc" ) eq "a";

    return 0;
}

sub test_EX_ACC_LIC
{
    my( $self, $repo, $eprint, $flag ) = @_;

    return 1 if $self->is_set( "ref2029_ex_acc" ) && $self->value( "ref2029_ex_acc" ) eq "b";

    return 0;
}

sub test_EX_TEC
{
    my( $self, $repo, $eprint, $flag ) = @_;

    return 1 if $self->is_set( "ref2029_ex_tec" );

    return 0;
}

sub test_EX_FUR
{
    my( $self, $repo, $eprint, $flag ) = @_;

    return 1 if $self->is_set( "ref2029_ex_fur" ) &&  $self->value( "ref2029_ex_fur" ) eq "TRUE";

    return 0;
}

sub test_EX
{
    my( $self, $repo, $eprint, $flag ) = @_;

    return 1 if
        $flag & EX_DEP ||
        $flag & EX_ACC_EMB ||
        $flag & EX_ACC_LIC ||
        $flag & EX_TEC ||
        $flag & EX_FUR;

    return 0;
}

sub test_EX_LIC
{
    my( $self, $repo, $eprint, $flag ) = @_;

    return 1 if $self->is_set( "ref2029_pub_agreement" ) && $self->get_value( "ref2029_pub_agreement" ) eq "TRUE";

    return 0;
}

sub test_GOLD
{
    my( $self, $repo, $eprint, $flag ) = @_;

    return 1 if $self->is_set( "ref2029_gold_oa" ) && $self->get_value( "ref2029_gold_oa" ) eq "TRUE";

    return 0;
}
