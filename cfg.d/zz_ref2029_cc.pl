# https://2029.ref.ac.uk/guidance/ref-2029-open-access-policy/

# New Report Plugins
$c->{plugins}{"Screen::Report::REF_CC::Pre2026"}{params}{disable} = 0;
$c->{plugins}{"Screen::Report::REF_CC_EX::Pre2026"}{params}{disable} = 0;
$c->{plugins}{"Screen::Report::REF_2029_CC"}{params}{disable} = 0;
$c->{plugins}{"Screen::Report::REF_2029_CC::Post2026"}{params}{disable} = 0;
$c->{plugins}{"Screen::Report::REF_2029_CC"}{params}{custom} = 1;

$c->{ref2029_cc_report}->{exportfields} = {
    eprints_core => [ qw(
        eprintid
        documents.content
        type
        title
        abstract
        creators_name
        creators_orcid
        creators_id
        publisher
        publication
        divisions
        dates
        id_number
        isbn
        issn
        official_url
    )],
    ref2029 => [qw (
        hoa_compliant
        hoa_ref_pan
        ref2029_cc.ref2029_gold_oa
        ref2029_cc.ref2029_pub_agreement
        ref2029_cc.ref2029_pre_compliant
        ref2029_cc.ref2029_pre_compliant_txt
        ref2029_cc.ref2029_override
        ref2029_cc.ref2029_ex_dep
        ref2029_cc.ref2029_ex_dep_txt
        ref2029_cc.ref2029_ex_acc
        ref2029_cc.ref2029_ex_acc_txt
        ref2029_cc.ref2029_ex_tec
        ref2029_cc.ref2029_ex_tec_txt
        ref2029_cc.ref2029_ex_fur
        ref2029_cc.ref2029_ex_fur_txt
    )],
};

$c->{ref2029_cc_report}->{exportfield_defaults} = [ qw( 
    eprintid
    documents.content
    type
    title
    abstract
    creators_name
    creators_orcid
    creators_id
    publisher
    publication
    divisions
    dates
    id_number
    isbn
    issn
    official_url
    hoa_compliant
    hoa_ref_pan
    ref2029_cc.ref2029_gold_oa
    ref2029_cc.ref2029_pub_agreement
    ref2029_cc.ref2029_pre_compliant
    ref2029_cc.ref2029_pre_compliant_txt
    ref2029_cc.ref2029_override
    ref2029_cc.ref2029_ex_dep
    ref2029_cc.ref2029_ex_dep_txt
    ref2029_cc.ref2029_ex_acc
    ref2029_cc.ref2029_ex_acc_txt
    ref2029_cc.ref2029_ex_tec
    ref2029_cc.ref2029_ex_tec_txt
    ref2029_cc.ref2029_ex_fur
    ref2029_cc.ref2029_ex_fur_txt
)];

$c->{ref2029_cc_report}->{custom_export} = {
    hoa_compliant => sub {
        my( $dataobj, $plugin ) = @_;

        # we need a ref2029 cc record
        my $ref2029_cc = undef;
        if( $dataobj->is_set( "ref2029_cc" ) )
        {
            $ref2029_cc = $dataobj->value( "ref2029_cc" );
        }

        if( !defined $ref2029_cc )
        {
            return "Not Compliant (No REF2029 Compliance data record)";
        }
        elsif( $dataobj->value( "ref2029_cc" )->value( "scope" ) ne "26-28" )
        {
            return "Not Compliant (Not in 26-28 scope)";
        }
        else
        {
            my $repo = $dataobj->repository;
            my $flag = $ref2029_cc->value( "compliant" ) || 0;
            my( $result, $reason ) = $ref2029_cc->test_COMPLIANT( $repo, $dataobj, $flag );

            if( $result )
            {
                if( $reason eq "acc_potential_emb" || $reason eq "acc_potential" )
                {
                   return "Compliant pending open access";
                }
                else
                {
                    return "Compliant";
                }
            }
            else
            {
                return "Not Compliant";
            }
        }
    }
};

# 7.5 Licensing requirements
# Array used to test license requirements
$c->{ref2029}->{licenses} = [qw(
    cc-by
    cc-by-nc
    cc-by-nd
    cc-by-nc-nd
    cc_by_4
    cc_by_nc_4
    cc_by_nd_4
    cc_by_nc_nd_4
    cc_by
    cc_by_nc
    cc_by_nd
    cc_by_nc_nd
)];

# Workflow component
$c->{plugins}{"InputForm::Component::REF2029"}{params}{disable} = 0;

# REF2029 CC Dataobj
use EPrints::DataObj::REF2029_CC;
$c->{datasets}->{ref2029_cc} = {
    class => "EPrints::DataObj::REF2029_CC",
    sqlname => "ref2029_cc",
};

# All articles and conference item records will have REF2029 CC records created
# For now we will just treat records published from Jan 26 as being in scope
# But in future we may want to add other options
$c->add_dataset_field( 'ref2029_cc', { name => 'scope', type=>"set", options =>[qw( out 21-25 26-28 )] }, reuse => 1 );

# Data used to check compliance
$c->add_dataset_field( 'ref2029_cc', { name => 'embargo', type=>"date", }, reuse => 1 );
$c->add_dataset_field( 'ref2029_cc', { name => 'licensed_foa', type=>"date", }, reuse => 1 );

# Results
$c->add_dataset_field( 'ref2029_cc', { name => 'compliant', type => "int", }, reuse => 1 );

# Exception Fields
$c->add_dataset_field( 'ref2029_cc', { name => 'ref2029_ex_dep', type=>"set", options => [qw( a b c )], input_style => "medium" }, reuse => 1 );
$c->add_dataset_field( 'ref2029_cc', { name => 'ref2029_ex_dep_txt', type=>"longtext", sql_index=>0 } );

$c->add_dataset_field( 'ref2029_cc', { name => 'ref2029_ex_acc', type=>"set", options => [qw( a b )], input_style => "medium" }, reuse => 1 );
$c->add_dataset_field( 'ref2029_cc', { name => 'ref2029_ex_acc_txt', type=>"longtext", sql_index=>0 } );

$c->add_dataset_field( 'ref2029_cc', { name => 'ref2029_ex_tec', type=>"set", options => [qw( a b )], input_style => "medium" }, reuse => 1 );
$c->add_dataset_field( 'ref2029_cc', { name => 'ref2029_ex_tec_txt', type=>"longtext", sql_index=>0 } );

$c->add_dataset_field( 'ref2029_cc', { name => 'ref2029_ex_fur', type=>"boolean" }, reuse => 1 );
$c->add_dataset_field( 'ref2029_cc', { name => 'ref2029_ex_fur_txt', type=>"longtext", sql_index=>0 } );

$c->add_dataset_field( 'ref2029_cc', { name => 'ref2029_pub_agreement', type=>"boolean" }, reuse => 1 );

# Override Flags
$c->add_dataset_field( 'ref2029_cc', { name => 'ref2029_override', type=>"boolean" }, reuse => 1 );
$c->add_dataset_field( 'ref2029_cc', { name => 'ref2029_pre_compliant', type=>"boolean" }, reuse => 1 );
$c->add_dataset_field( 'ref2029_cc', { name => 'ref2029_pre_compliant_txt', type=>"longtext", sql_index=>0 } );
$c->add_dataset_field( 'ref2029_cc', { name => 'ref2029_gold_oa', type=>"boolean" }, reuse => 1 );

# New EPrint field for new subobject
$c->add_dataset_field( 'eprint', { name => 'ref2029_cc', type=>"subobject", datasetid => 'ref2029_cc', dataobj_fieldname => 'eprintid', dataset_fieldname => '' } );

# All potentially relevant records now get a REF2029 object, i.e. all articles and conference items
# This allows us to store events that we may need if the EPrint becomes in scope
$c->add_dataset_trigger( 'eprint', EPrints::Const::EP_TRIGGER_BEFORE_COMMIT, sub
{
    my( %args ) = @_;
    my( $repo, $eprint, $changed ) = @args{qw( repository dataobj changed )};

    # we already have one, don't need more
    return if $eprint->is_set( "ref2029_cc" );

    # is this a REF type?
    my $type = $eprint->value( "type" );
    if( defined $type && grep( /^$type$/, @{$repo->config( "hefce_oa", "item_types" )} ) )
    {
        # create the new record
        my $ds = $repo->dataset( "ref2029_cc" );
        my $ref_cc = $ds->dataobj_class->create_from_data(
            $repo,
            {
                eprintid => $eprint->id,
            }
        );

        if( defined $ref_cc )
        {
            # first calculate the scope
            $ref_cc->calculate_scope;
    
            if( $ref_cc->value( "scope" ) eq "26-28" )
            {
                if( $eprint->is_set( "hoa_date_foa" ) )
                {
                    # only copy a FOA value if we have a doc with the correct license of the correct type and is open
                    my $valid_license = 0;
                    for( $eprint->get_all_documents )
                    {
                        # is it the correct type
                        next unless $_->is_set( "content" );
                        my $content = $_->value( "content" );
                        next unless grep( /^$content$/, @{$repo->config( "hefce_oa", "document_content" )} );

                        # and is it open
                        next unless $_->is_public;

                        # does it have a correct license
                        next unless $_->is_set( "license" );
                        my $license = $_->value( "license" );
                        next unless grep( /^$license$/, @{$repo->config( "ref2029", "licenses" )} );

                        $valid_license = 1;
                    }
                    $ref_cc->set_value( "licensed_foa", $eprint->value( "hoa_date_foa" ) ) if $valid_license;
                }

                if( $eprint->is_set( "hoa_gold" ) )
                {
                    $ref_cc->set_value( "ref2029_gold_oa", $eprint->value( "hoa_gold" ) );
                }

                if( $eprint->is_set( "hoa_override" ) )
                {
                    $ref_cc->set_value( "ref2029_override", $eprint->value( "hoa_override" ) );
                }

                $ref_cc->commit;
            }
        }
    }                                  

}, priority => 300 );

# Update REF2029 record with any dates or info from the eprint
$c->add_dataset_trigger( 'eprint', EPrints::Const::EP_TRIGGER_BEFORE_COMMIT, sub
{
    my( %args ) = @_;
    my( $repo, $eprint, $changed ) = @args{qw( repository dataobj changed )};

    my $ref2029_cc = $eprint->value( "ref2029_cc" );

    $ref2029_cc->update_data if defined $ref2029_cc;

}, priority => 350 ); # needs to be called after the pub date has been set

# Set REF CC 2029 Compliance value
$c->add_dataset_trigger( 'eprint', EPrints::Const::EP_TRIGGER_BEFORE_COMMIT, sub
{
    my( %args ) = @_;

    my( $repo, $eprint, $changed ) = @args{qw( repository dataobj changed )};

    my $ref2029_cc = $eprint->value( "ref2029_cc" );

    $ref2029_cc->test_compliance if defined $ref2029_cc;

}, priority => 400 );
