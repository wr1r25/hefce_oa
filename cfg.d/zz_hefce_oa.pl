$c->{plugins}{"Screen::EPrint::HefceOA"}{params}{disable} = 0;
$c->{plugins}{"Screen::Report::REF_CC"}{params}{disable} = 0;
$c->{plugins}{"Screen::Report::REF_CC_EX"}{params}{disable} = 0;
$c->{plugins}{"Screen::Report::REF_CC::2015"}{params}{disable} = 1;
$c->{plugins}{"Screen::Report::REF_CC::2016"}{params}{disable} = 1;
$c->{plugins}{"Screen::Report::REF_CC::2017"}{params}{disable} = 1;
$c->{plugins}{"Screen::Report::REF_CC::2018"}{params}{disable} = 1;
$c->{plugins}{"Screen::Report::REF_CC::2019"}{params}{disable} = 1;
$c->{plugins}{"Screen::Report::REF_CC::2020"}{params}{disable} = 1;
$c->{plugins}{"Screen::Report::REF_CC::2021"}{params}{disable} = 1;
$c->{plugins}{"Screen::Report::REF_CC::2022"}{params}{disable} = 1;
$c->{plugins}{"Screen::Report::REF_CC::2023"}{params}{disable} = 1;
$c->{plugins}{"Screen::Report::REF_CC::2024"}{params}{disable} = 1;
$c->{plugins}{"Screen::Report::REF_CC::2025"}{params}{disable} = 1;
$c->{plugins}{"Screen::Report::REF_CC::2026"}{params}{disable} = 1;
$c->{plugins}{"Screen::Report::REF_CC::2027"}{params}{disable} = 1;
$c->{plugins}{"Screen::Report::REF_CC_EX::2015"}{params}{disable} = 1;
$c->{plugins}{"Screen::Report::REF_CC_EX::2016"}{params}{disable} = 1;
$c->{plugins}{"Screen::Report::REF_CC_EX::2017"}{params}{disable} = 1;
$c->{plugins}{"Screen::Report::REF_CC_EX::2018"}{params}{disable} = 1;
$c->{plugins}{"Screen::Report::REF_CC_EX::2019"}{params}{disable} = 1;
$c->{plugins}{"Screen::Report::REF_CC_EX::2020"}{params}{disable} = 1;
$c->{plugins}{"Screen::Report::REF_CC_EX::2021"}{params}{disable} = 1;
$c->{plugins}{"Screen::Report::REF_CC_EX::2022"}{params}{disable} = 1;
$c->{plugins}{"Screen::Report::REF_CC_EX::2023"}{params}{disable} = 1;
$c->{plugins}{"Screen::Report::REF_CC_EX::2024"}{params}{disable} = 1;
$c->{plugins}{"Screen::Report::REF_CC_EX::2025"}{params}{disable} = 1;
$c->{plugins}{"Screen::Report::REF_CC_EX::2026"}{params}{disable} = 1;
$c->{plugins}{"Screen::Report::REF_CC_EX::2027"}{params}{disable} = 1;
$c->{plugins}{"Export::Report::CSV::REF_CC"}{params}{disable} = 0;

#set which can have a custom search, allowing their filter function to be overwridden
$c->{plugins}{"Screen::Report::REF_CC"}{params}{custom} = 1;
$c->{plugins}{"Screen::Report::REF_CC_EX"}{params}{custom} = 1;

push @{ $c->{user_roles}->{editor} }, qw{ +eprint/hefce_oa };
push @{ $c->{user_roles}->{admin} }, qw{ +eprint/hefce_oa };
push @{ $c->{user_roles}->{admin} }, qw{ +report/hefce_oa };

#hide REF CC tab post ref - set to 1 if you want to hide the REF CC for eprints accepted/published after 31/03/2021
$c->{hefce_oa}->{hide_tab} = 0;

# set REF scopes
$c->{hefce_oa}->{ref2029_in_scope} = 1; # Items published between 01-01-2021 and 21-12-2028
$c->{hefce_oa}->{ref2021_in_scope} = 0; # Items accepted before 01-04-2021

#set if embargoed records should appear in report as compliant
$c->{hefce_oa}->{embargo_as_compliant} = 0;

#set if an article needs an issn not to be considered out of scope
#$c->{hefce_oa}->{enforce_issn} = 1;

# First Open Access (FOA) retraction period.
# If this configuration value is set, and an item is updated within the number of day specified,
# the FOA date can be removed, if the item no longer has an appropriate Open Access document attached.
# If the value below is commented-out, or undef, no FOA retractions will happen.
# If the value below is 0, then only updates on the same day can alter the FOA date.
# If the value below is 1, then updates on the same day, or the day after the FOA date may change the value.
# A value of 2 means up to 2 days after the FOA date... etc.
# The value below
$c->{hefce_oa}->{foa_retraction_period} = undef; #number of days

# The value above is referenced in the following method, called by a commit trigger
$c->{hefce_oa}->{commit_in_foa_retraction_period} = sub
{
    my( $repo, $date_foa ) = @_;

    use Time::Piece;
    use Time::Seconds;

    return unless defined $date_foa;
    my $period = $repo->config( "hefce_oa", "foa_retraction_period" );
    return unless defined $period;


    my $retraction_end = Time::Piece->strptime( $date_foa, "%Y-%m-%d"); #defaults to 00:00:00
    $retraction_end += ONE_DAY * $period;

    # older versions of Time::Piece don't have the 'truncate' method. The below should return
    # a consistent date for comparisons
    my $today = Time::Piece->strptime( EPrints::Time::get_iso_date(), "%Y-%m-%d" );

    return 1 if $today <= $retraction_end;  
};

#set order of preference for export plugins (GRF v3.1)
$c->{hefce_report}->{export_plugins} = [ qw( Export::Report::CSV Export::Report::HTML Export::Report::JSON )];

$c->{hefce_report}->{exportfields} = {
    ref_core => [ qw(
        eprintid
        documents.content
        type
        title
        abstract
        creators
        publisher
        publication
        divisions
        dates
        id_number
        isbn
        issn
        official_url                                            
    )],
    ref_rioxx => [ qw(
        rioxx2_free_to_read
        rioxx2_license_ref
        rioxx2_coverage
        rioxx2_source
        rioxx2_subject
        rioxx2_dateAccepted
        rioxx2_publication_date
        rioxx2_apc
        rioxx2_project
        rioxx2_version
        rioxx2_version_of_record
    )],
    ref_exceptions => [ qw(
        hoa_compliant
        hoa_problems
        hoa_gold
        hoa_ref_pan
        hoa_ex_dep
        hoa_ex_dep_txt
        hoa_ex_acc
        hoa_ex_acc_txt
        hoa_ex_tec
        hoa_ex_tec_txt
        hoa_ex_fur
        hoa_ex_fur_txt
    )],
};

$c->{hefce_report}->{exportfield_defaults} = [ qw( eprintid documents.content type title creators dates hoa_compliant hoa_problems ) ];

$c->{hefce_report}->{custom_export} = {
    hoa_compliant => sub {
        my( $dataobj, $plugin ) = @_;

            my $compliance = "Compliant";

            my $repo = $dataobj->repository;

            my $out_of_scope = $repo->call( [ "hefce_oa", "OUT_OF_SCOPE_reason" ], $repo, $dataobj );
                
            if( $out_of_scope eq "acc" || $out_of_scope eq "pub" )
            {
                return "Out of scope (Pre April 2016)";
            }
            elsif( $out_of_scope eq "issn" )
            {
                return "Out of scope (no ISSN)";
            }
            elsif( $out_of_scope eq "over" )
            {
                return "Out of scope (post REF2021 submission deadline)";
            }

            my @problems = $plugin->validate_dataobj( $dataobj );
            if( scalar( @problems ) > 0 )
            {
                $compliance = "Not Compliant";
            }

            my $state = $plugin->get_state( $dataobj );
            if( defined $state && $state eq "#E19141" )
            {
                $compliance = "Compliant pending open access";
            }
            return $compliance;
        },
        creators => sub {
            my( $dataobj ) = @_;

            my @creator_names;
            my $creators = $dataobj->get_value( "creators" );
            foreach my $c ( @{$creators} )
            {
                push @creator_names, EPrints::Utils::make_name_string( $c->{name} );
            }
            return join( ";", @creator_names );
        },
        dates => sub {
            my( $dataobj ) = @_;

            my @date_strings;
            my $dates = $dataobj->get_value( "dates" );
            foreach my $d ( @{$dates} )
            {
                push @date_strings, $d->{date} . " (" . $d->{date_type} . ")";
            }
            return join( ";", @date_strings );
        },
        rioxx2_free_to_read => sub {
            my( $dataobj ) = @_;
    
            my $free_to_read = $dataobj->get_value( "rioxx2_free_to_read" );
            if( exists $free_to_read->{free_to_read} &&  $free_to_read->{free_to_read} eq "Yes" )
            {
                my $string = "Free_to_read: Yes";
                if( exists $free_to_read->{start_date} && defined $free_to_read->{start_date} )
                {
                    $string .= ", Start_date: " . $free_to_read->{start_date};
                }
                return $string;
            }
            else
            {
                return undef;
            }
        },
        rioxx2_license_ref => sub {
            my( $dataobj ) = @_;
            my $license_ref = $dataobj->get_value( "rioxx2_license_ref" );
            if( exists $license_ref->{license_ref} )
            {
                my $string = "License_ref: " . $license_ref->{license_ref};
                if( exists $license_ref->{start_date} && defined $license_ref->{start_date} )
                {
                    $string .= ", Start_date: " . $license_ref->{start_date};
                }
                return $string;
            }
            else
            {
                return undef;
            }
        },
};

####################################################
# Trigger to map exceptions from old to new values #
# Deposit exception (g) --> Further exception (b)  #
# Deposit exception (f) --> Gold OA (hoa_gold)     #
# Other exception --> Further exception (a)        #
####################################################
$c->add_dataset_trigger( 'eprint', EPrints::Const::EP_TRIGGER_BEFORE_COMMIT, sub
{
    my( %args ) = @_;
    my( $repo, $eprint, $changed ) = @args{qw( repository dataobj changed )};

    # Deposit exception (g) --> Further exception (b)
    if( ( $eprint->is_set( "hoa_ex_dep" ) && $eprint->get_value( "hoa_ex_dep" ) eq "g" ) ||
        ( exists $changed->{hoa_ex_dep} && $changed->{hoa_ex_dep} eq "g" ) )
    {
        $eprint->set_value( "hoa_ex_dep", undef ); #unset existing value
        $eprint->set_value( "hoa_ex_fur", "b" );
        if( $eprint->is_set( "hoa_ex_dep_txt" ) )
        {
            $eprint->set_value( "hoa_ex_fur_txt", $eprint->get_value( "hoa_ex_dep_txt" ) );
            $eprint->set_value( "hoa_ex_dep_txt", undef );
        }
    }

    # Deposit exception (f) --> Gold OA (hoa_gold)
    if( ( $eprint->is_set( "hoa_ex_dep" ) && $eprint->get_value( "hoa_ex_dep" ) eq "f" ) ||
        ( exists $changed->{hoa_ex_dep} && $changed->{hoa_ex_dep} eq "f" ) )
    {
        $eprint->set_value( "hoa_ex_dep", undef );
        $eprint->set_value( "hoa_gold", "TRUE" );
    }

    # Other exception --> Further exception (a)
    if( ( $eprint->is_set( "hoa_ex_oth" ) && $eprint->get_value( "hoa_ex_oth" ) eq "TRUE" ) ||
        ( exists $changed->{hoa_ex_oth} && $changed->{hoa_ex_oth} eq "TRUE" ) )
    {
        $eprint->set_value( "hoa_ex_oth", undef );
        $eprint->set_value( "hoa_ex_fur", "a" );
        if( $eprint->is_set( "hoa_ex_oth_txt" ) )
        {
            $eprint->set_value( "hoa_ex_fur_txt", $eprint->get_value( "hoa_ex_oth_txt" ) );
        }
    }
}, priority => 50 );
