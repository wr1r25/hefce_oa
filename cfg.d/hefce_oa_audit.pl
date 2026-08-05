$c->{"hefce_oa"}->{"core_url"} = "https://core.ac.uk/display/";

# HEFCE OA Audit DataObj
{
no warnings;

package EPrints::DataObj::HefceOA_Audit;

@EPrints::DataObj::HefceOA_Audit::ISA = qw( EPrints::DataObj );

sub get_dataset_id { "hefce_oa_audit" }

sub get_url { shift->uri }

sub get_defaults
{
    my( $class, $session, $data, $dataset ) = @_;

    $data = $class->SUPER::get_defaults( @_[1..$#_] );

    return $data;
}

# gets an audit record for a given eprint
sub get_audit_record
{
    my( $class, $session, $eprint ) = @_;

    return $session->dataset( $class->get_dataset_id )->search(
        filters => [
            { meta_fields => [qw( eprintid )], value => $eprint->id, match => "EX", },
        ],
    )->item( 0 );
}

# define the dataset
$c->{datasets}->{hefce_oa_audit} = {
    class => "EPrints::DataObj::HefceOA_Audit",
    sqlname => "hefce_oa_audit",
    name => "hefce_oa_audit",
    columns => [qw( auditid )],
    index => 1,
    import => 1,
};

# define fields
$c->{fields}->{hefce_oa_audit} = [] if !defined $c->{fields}->{hefce_oa_audit};
unshift @{$c->{fields}->{hefce_oa_audit}}, (
    {
        name => "auditid",
        type => "counter",
        required => 1,
        can_clone => 0,
        sql_counter => "auditid"
    },
    {
        name => "eprintid",
        type => "itemref",
        datasetid => "eprint",
        required => 1,
        show_in_html => 0
    },
    {
        name => "up_datestamp",
        type => "time",
        required => 0,
        import => 0,
        render_res => "minute",
        render_style => "short",
        can_clone => 0
    },
    {
        name => "core_datestamp",
        type => "time",
        required => 0,
        import => 0,
        render_res => "minute",
        render_style => "short",
        can_clone => 0
    },
    # Unpaywall fields
    {
        name => 'up_is_oa',
        type => 'boolean'
    },
    {
        name => 'up_url_for_pdf',
        type => 'url',
    },
    {
        name => 'up_locations',
        type => 'compound',
        multiple => 1,
        fields => [
            {
                sub_name => 'url',
                type  => 'url',
            },
            {
                sub_name => 'pmh_id',
                type  => 'text',
                allow_null => 1,
            },
            {
                sub_name => 'is_best',
                type  => 'boolean',
            },
        ],
    },
    # CORE fields
    {
        name => 'core_sources',
        type => 'compound',
        multiple => 1,
        fields => [
            {
                sub_name => 'core_id',
                type  => 'int',
            },
            {
                sub_name => 'repo_name',
                type => 'text',
                allow_null => 1,
            },
            {
                sub_name => 'datePublished',
                type  => 'text',
                allow_null => 1,
            },
            {
                sub_name => 'depositedDate',
                type  => 'timestamp',
                allow_null => 1,
            },
            {
                sub_name => 'publishedDate',
                type  => 'timestamp',
                allow_null => 1,
            },
            {
                sub_name => 'acceptedDate',
                type  => 'timestamp',
                allow_null => 1,
            },
        ],
    },
);

}


$c->{hefce_oa}->{get_unpaywall} = sub {

    my ($repo, $eprint) = @_;

    use LWP::Simple;
    use LWP::UserAgent;
    use URI;



    #start with an assumption
    my $doi_field = "id_number";
    if(EPrints::Utils::is_set($repo->get_conf("hefce_oa","eprintdoifield"))){
        #a) have we defined the doi_field within the hefce_oa conf?
        $doi_field = $repo->get_conf("hefce_oa","eprintdoifield");
    }elsif(EPrints::Utils::is_set($repo->get_conf("datacitedoi","eprintdoifield"))){
        #b) have we already defined the doi_field within the dataitedoi plugin?
        $doi_field = $repo->get_conf("datacitedoi","eprintdoifield");
    }

    return("ERROR", "There is no DOI ($doi_field) set ") if (!$eprint->exists_and_set($doi_field));

    my $doi = $eprint->value($doi_field);

    if($doi = $repo->call(["hefce_oa", "format_doi"], $doi)){

        my $up_email = $repo->get_conf("hefce_oa", "unpaywall_email") || $repo->get_conf("adminemail");
        
        my $api_request_uri = URI->new($repo->get_conf("hefce_oa","unpaywall_api_base")."$doi?email=".$up_email);

        my $ua = LWP::UserAgent->new(ssl_opts => { verify_hostname => 0 });
        my @headers = (
            'Accept' => 'application/json',
    #		'Authorization' => 'Bearer' . $user->value( "orcid_access_token" ),
        );
        print $api_request_uri."\n";
        my $response = $ua->get( $api_request_uri, @headers );
        return("SUCCESS", $response);

    }else{
        return("ERROR", "No suitable DOI set in $doi_field (".$eprint->value($doi_field).")");
    }
};

$c->{hefce_oa}->{get_core} = sub {

    my ($repo, $eprint) = @_;

    use LWP::Simple;
    use LWP::UserAgent;
    use URI;


    #start with an assumption
    my $doi_field = "id_number";
    if(EPrints::Utils::is_set($repo->get_conf("hefce_oa","eprintdoifield"))){
        #a) have we defined the doi_field within the hefce_oa conf?
        $doi_field = $repo->get_conf("hefce_oa","eprintdoifield");
    }elsif(EPrints::Utils::is_set($repo->get_conf("datacitedoi","eprintdoifield"))){
        #b) have we already defined the doi_field within the dataitedoi plugin?
        $doi_field = $repo->get_conf("datacitedoi","eprintdoifield");
    }

    return("ERROR", "There is no DOI ($doi_field) set ") if (!$eprint->exists_and_set($doi_field));

    my $doi = $eprint->value($doi_field);

    if($doi = $repo->call(["hefce_oa", "format_doi"], $doi)){
        
        # core requires that the doi is not encoded but that it 
        # is wrapped in double quotes that are encoded and 
        # proceeded by a colon that is also encoded... go figure!
        my $api_request_uri = URI->new($repo->get_conf("hefce_oa","core_api_base")."/search/doi%3A%22".$doi."%22?page=1&pageSize=100&apiKey=".$repo->get_conf("hefce_oa","core_api_key"));

        my $ua = LWP::UserAgent->new(ssl_opts => { verify_hostname => 0 });
        my @headers = (
            'Accept' => 'application/json',
    #		'Authorization' => 'Bearer' . $user->value( "orcid_access_token" ),
        );

        my $response = $ua->get( $api_request_uri, @headers );
        return("SUCCESS", $response);

    }else{
        return("ERROR", "No suitable DOI set in $doi_field (".$eprint->value($doi_field).")");
    }
};


$c->{hefce_oa}->{format_doi} = sub {

    my( $doi ) = @_;
    my $parsed_doi = EPrints::DOI->parse( $doi );

    if (defined $parsed_doi) {
        return $parsed_doi->to_string(noprefix => 1);
    }
    return 0;
};


