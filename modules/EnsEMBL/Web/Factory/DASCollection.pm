package EnsEMBL::Web::Factory::DASCollection;
=head1 NAME

EnsEMBL::Web::Factory::DASCollection;

=head1 SYNOPSIS

Module to create EnsEMBL::Web::Factory::DASCollection objects.

=head1 DESCRIPTION

Example:

my $dasfact = EnsEMBL::Web::Proxy::Factory->new( 'DASCollection', { '_databases' => $dbc, '_input' => $input } );
$dasfact->createObjects();
my( $das_collection) = @{$dasfact->DataObjects};

Creates DASCollection Data objects to be used within the web_api.

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

=head1 CONTACT

Eugene Kulesha - ek3@sanger.ac.uk

=cut

use strict;
use warnings;
no warnings "uninitialized";

use Bio::EnsEMBL::ExternalData::DAS::DASAdaptor;
use Bio::EnsEMBL::ExternalData::DAS::DAS;

use EnsEMBL::Web::Factory;
use EnsEMBL::Web::Problem;
use EnsEMBL::Web::ExternalDAS;
use EnsEMBL::Web::Proxy::Object;
use SOAP::Lite;
use Data::Dumper;
use vars qw( @ISA );
@ISA = qw(  EnsEMBL::Web::Factory );

#----------------------------------------------------------------------

=head2 _createObjects

  Arg [1]   : none
  Function  : Creates EnsEMBL::Web::Data::DASCollection objects
              1. examines SpeciesDefs for DAS config
              2. examines Input for DAS config
  Returntype: 
  Exceptions: 
  Caller    : $self->createObjects
  Example   : $self->_createObjects

=cut

sub createObjects {
    my $self = shift;

# Get the view that is requesting DASCollection Factory
    my $conf_script = $self->param("conf_script") || $self->script;

# Read the DAS config from the ini files
    my $das_conftype = "ENSEMBL_INTERNAL_DAS_SOURCES"; # combined GeneDAS and Internal DAS
    my %sources_conf;
    my $ini_confdata = $self->species_defs->$das_conftype() || {};
    ref( $ini_confdata ) eq 'HASH' or die("$das_conftype badly configured" );
    use Data::Dumper;

    foreach my $source( keys %$ini_confdata ){
	my $source_confdata = $ini_confdata->{$source} || ( warn( "$das_conftype source $source not configured" ) && next );

        next if exists($source_confdata->{assembly}) && $self->species_defs->ENSEMBL_GOLDEN_PATH ne $source_confdata->{assembly};
	ref( $source_confdata ) eq 'HASH' || ( warn( "$das_conftype source $source badly configured" ) && next );

	# Is source enabled for this view?
	if (! defined($source_confdata->{enable})) {
	    @{$source_confdata->{enable}} = @{ $source_confdata->{on} || []}; # 
	}

	my %valid_scripts = map{ $_, 1 } @{$source_confdata->{enable}};
	$valid_scripts{$conf_script} || next;
	$source_confdata->{conftype} = 'internal'; # Denotes where conf is from
	$source_confdata->{type} ||= 'ensembl_location'; # 
	$source_confdata->{color} ||= $source_confdata->{col}; # 
	$source_confdata->{id} = $source;
	$source_confdata->{description} ||= $source_confdata->{label} ;
	$source_confdata->{stylesheet} ||= 'N';
	$source_confdata->{stylesheet} = 'Y' if ($source_confdata->{stylesheet} eq '1'); # 
	$source_confdata->{score} ||= 'N';
	$source_confdata->{score} = 'Y' if ($source_confdata->{score} eq '1'); # 

	$source_confdata->{name} ||= $source;
	$source_confdata->{group} ||= 'N';
	$source_confdata->{group} = 'Y' if ($source_confdata->{group} eq '1'); # 
	
#	warn("ADD INTERNAL: $source");
#	warn(Dumper($source_confdata));
	$sources_conf{$source} = $source_confdata;
    }

# Add external sources (ones added by user)
    my $extdas = new EnsEMBL::Web::ExternalDAS( $self );
    $extdas->getConfigs($conf_script, $conf_script);
    my %daslist = %{$extdas->{'data'}};
	 
    for my $source ( keys %daslist ) {
	my %valid_scripts = map{ $_, 1 } @{$daslist{$source}->{enable} || [] };
	$valid_scripts{$conf_script} || next;
	
	my $das_species = $daslist{$source}->{'species'};
	next if( $das_species && $das_species ne '' && $das_species ne $ENV{'ENSEMBL_SPECIES'} );
	
	my $source_confdata = $daslist{$source};
	
#	warn("ADD EXTERNAL: $source");
#	warn(Dumper($source_confdata));
	$source_confdata->{conftype} ||= 'external';
	$sources_conf{$source} = $source_confdata;
    }


# Get parameters of the view that has called upon dasconfview
    my %script_params = ();
    my @udas = ();
    my @conf_params = split('zzz', $self->param("conf_script_params") || '');

    foreach my $p (@conf_params) {
	next if ($p =~ /^=/);
	my @plist = split('=', $p);
	if ($plist[0] eq 'data_URL') {
	    push(@udas, $plist[1]);
	} elsif ($plist[0] eq 'h' || $plist[0] eq 'highlight') {
	    if (defined($plist[1])) {
		my @hlist = split(/\|/, $plist[1]);
		foreach my $h (@hlist) {
		    if ($h =~ /URL:/) {
			$h =~ s/URL://;
			push(@udas, $h);
		    } else {
			push(@{$script_params{$plist[0]}}, $plist[1] || '');
						  }
		}
	    }
	} else {
	    push(@{$script_params{$plist[0]}}, $plist[1] || '');
	}
    }
  
# Add sources that are attached via URL
#  warn("URL SOURCES: @udas");
    my $urlnum = 1;
    foreach my $u (@udas) {
	my $das_name = "_URL_$urlnum";
	$sources_conf{$das_name}->{name} = $das_name;
	$sources_conf{$das_name}->{url} = $u;
	$sources_conf{$das_name}->{conftype} = 'url';
	$urlnum ++;
    }


# Get the sources selection, i.e which sources' annotation should be displayed
    my $uca    = $self->get_userconfig_adaptor();
    my $config = $uca->getUserConfig( 'dasconfview' );
    my $section = $conf_script;

    my @das_params = CGI::param('DASselect');
    foreach my $src (@das_params) {
        my $sp = "DASselect_$src";
	my $value = CGI::param($sp) || 0;

	if (CGI::param($sp)) {
	    $config->set($section, $src, "on", 1);
	} else {
	    $config->set($section, $src, "off", 1);
	}
    }
    $config->save( );

    my @selection = ();

    foreach my $src (keys (%sources_conf)) {
	my $value = $config->get($section, $src) || 'undef';
	if ($value eq 'on') {
	    push(@selection, $src);
	}
    }

    if( @selection ) {
      $self->param("DASselect", @selection);
    } else {
      $self->delete_param("DASselect" );
    }
    my %DASsel = map {$_ => 1} $self->param("DASselect");


# Process the dasconfig form input - Get DAS sources to add/delete/edit;
    my %das_submit = map{$_,1} ($self->param( "_das_submit" ) || ());
    my %das_del    = map{$_,1} ($self->param( "_das_delete" ) || ());
    my %urldas_del = map{$_,1} ($self->param( "_urldas_delete" ) || ());
    my %das_edit   = map{$_,1} ($self->param( "_das_edit" ) || ());
    my %das_add    = map{$_,1} ($self->param( "add_das_source" ) || ());

    if( %das_add ) {
	# Clean up any add_das parameters
      $self->delete_param('add_das_source');
    }
    
    foreach (keys (%das_del)){
      $extdas->delete_das_source($_);
      delete($sources_conf{$_});
    }
    
    foreach (keys %urldas_del){
	warn("DELETE1 : $_");
	delete($sources_conf{$_});
    }
  
    if (defined(my $dedit  = $self->param("DASedit"))) {
	$sources_conf{$dedit}->{conftype} = 'external_editing';
    }

    my @confkeys = qw( name protocol domain dsn type strand labelflag);

# DAS sources can be added from URL 
# URL will have to be of the following format:
# /geneview?gene=BRCA2&add_das_source=(url=http://das1:9999/das+dsn=mouse_ko_allele+type=markersymbol+name=MySource+active=1)
# other parameters also can be specified, but the those are optional .. 

    foreach my $dconf (keys %das_add){
	$dconf =~ s/[\(|\)]//g;
	my @das_keys = split(/\s/, $dconf);
	my %das_data = map { split (/\=/, $_,2) } @das_keys; 
	my $das_name = $das_data{name} || $das_data{dsn} || 'NamelessSource';
	
	if( exists( $sources_conf{$das_name} ) and  (! defined($sources_conf{$das_name}->{conftype}) or $sources_conf{$das_name}->{conftype} ne 'external_editing' )){ 
	    my $das_name_ori = $das_name;
	    for( my $i = 1; 1; $i++ ){
		$das_name = $das_name_ori ."_$i";
		if( ! exists( $sources_conf{$das_name} ) ){
		    $das_data{name} =  $das_name;
		    last;
		}
	    }
	}
#	warn("ADD DAS $das_name");
#	warn(Dumper(\%das_data));

	if ( ! exists $das_data{url} || ! exists $das_data{dsn} || ! exists $das_data{type}) {
	    warn("WARNING: DAS source $das_name has not been added: Missing parameters");
	    next;
	}
	
	# Add to the conf list
	$das_data{label} or $das_data{label} = $das_data{name};
	$das_data{caption} or $das_data{caption} = $das_data{name};
	$das_data{stylesheet} or $das_data{stylesheet} = 'n';
	$das_data{score} or $das_data{score} = 'n';
	if (exists $das_data{enable}) {
	    my @enable_on = split(/\,/, $das_data{enable});
	    delete $das_data{enable};
	    push @{$das_data{enable}}, @enable_on;
	}
	push @{$das_data{enable}}, $conf_script;
	push @{$das_data{mapping}} , split(/\,/, $das_data{type});
	$das_data{conftype} = 'external';
	$das_data{type} = 'mixed' if (scalar(@{$das_data{mapping}} > 1));
	$sources_conf{$das_name} ||= {};
	foreach my $key( @confkeys, 'label', 'url', 'conftype', 'group', 'stylesheet', 'score', 'enable', 'mapping', 'caption', 'active', 'color', 'depth', 'help', 'linktext', 'linkurl' ) {
	    if (defined $das_data{$key}) {
		$sources_conf{$das_name}->{$key} = $das_data{$key};
	    }
	}
	$extdas->add_das_source(\%das_data);
	if ($das_data{active}) {
	    $DASsel{$das_name} = 1;
	    push @selection, $das_name;
	    $self->param("DASselect", \@selection);
	}

    }

    # Add '/das' suffix to _das_domain param
    if( my $domain = $self->param( "DASdomain" ) ){
	$domain =~ s/(\/das)?\/?\s*$/\/das/;
	$self->param('DASdomain',$domain );
    }
    
    # Have we got new DAS? If so, validate, and add to Input
    
    
    if( $self->param("_das_submit") ){
	if ($self->param("DASsourcetype") eq 'das_url') {
	    my $url = $self->param("DASurl") || ( warn( "_error_das_url: Need a url!") &&  $self->param( "_error_das_url", "Need a url!" ));
	    my $das_name = "_URL_$urlnum"; 
	    
	    $sources_conf{$das_name}->{name} = $das_name;
	    $sources_conf{$das_name}->{url} = $url;
	    $sources_conf{$das_name}->{conftype} = 'url';
	} elsif ($self->param("DASsourcetype") eq 'das_registry') {
	    my $registry = $self->getRegistrySources();

	    foreach my $id ($self->param("DASregistry")) {
		my $err = 0;
		my %das_data;
		$self->getSourceData($registry->{$id}, \%das_data);
		foreach my $key( @confkeys ){
		    if (defined($self->param("DAS${key}"))) {
			$das_data{$key} = $self->param("DAS${key}");
		    }
		}
		my $das_name = $das_data{name};
		if( exists( $sources_conf{$das_name} ) and  (! defined($sources_conf{$das_name}->{conftype}) or $sources_conf{$das_name}->{conftype} ne 'external_editing' )){ 
		    my $das_name_ori = $das_name;
		    for( my $i = 1; 1; $i++ ){
			$das_name = $das_name_ori ."_$i";
			if( ! exists( $sources_conf{$das_name} ) ){
			    $das_data{name} =  $das_name;
			    last;
			}
		    }
		}
		# Add to the conf list
		$das_data{label} = $self->param('DASlabel') || $das_data{name};
		$das_data{caption} = $das_data{name};
		
		$das_data{stylesheet} = $self->param('DASstylesheet');
		$das_data{score} = $self->param('DASscore');
		$das_data{group} = $self->param('DASgroup');
		$das_data{url} = $das_data{protocol}.'://'.$das_data{domain};
		@{$das_data{enable}} = $self->param('DASenable');
		$das_data{conftype} = 'external';
		$das_data{color} = $self->param("DAScolor");
		$das_data{depth} = $self->param("DASdepth");
		$das_data{help} = $self->param("DAShelp");
		$das_data{linktext} = $self->param("DASlinktext");
		$das_data{linkurl} = $self->param("DASlinkurl");
		$das_data{active} = 1; # Enable by default
		foreach my $key( @confkeys, 'label', 'url', 'conftype', 'group', 'stylesheet', 'score', 'enable', 'mapping', 'caption', 'active', 'color', 'depth', 'help', 'linktext', 'linkurl' ) {
		    $sources_conf{$das_name} ||= {};
		    $sources_conf{$das_name}->{$key} = $das_data{$key};
		}
		$extdas->add_das_source(\%das_data);
		$DASsel{$das_name} = 1;

	    }

	} else {
	    my $err = 0;
	    my %das_data;

	    if ($self->param("DASsourcetype") eq 'das_file') {
		$self->param("DAStype", "ensembl_location");
	    }

	    foreach my $key( @confkeys ){
		$das_data{$key} = $self->param("DAS${key}") || ( warn( "_error_das_$key: Need a $key!") &&  $self->param( "_error_das_$key", "Need a $key!" ) && $err++ );
	    }

	    
	    if( ! $err ){
		# Check if new name exists, and not source edit. If so, make new name.
		my $das_name = $das_data{name};
		if( exists( $sources_conf{$das_name} ) and  (! defined($sources_conf{$das_name}->{conftype}) or $sources_conf{$das_name}->{conftype} ne 'external_editing' )){ 
		    my $das_name_ori = $das_name;
		    for( my $i = 1; 1; $i++ ){
			$das_name = $das_name_ori ."_$i";
			if( ! exists( $sources_conf{$das_name} ) ){
			    $das_data{name} =  $das_name;
			    last;
			}
		    }
		}
		
		if (defined( my $usersrc = $self->param("DASuser_source") || undef)) {
		    $das_data{domain} = $self->species_defs->ENSEMBL_DAS_UPLOAD_SERVER.'/das';
		    $das_data{dsn} = $usersrc;
		}

		# Add to the conf list
		$das_data{label} = $self->param('DASlabel') || $das_data{name};
		$das_data{caption} = $das_data{name};
		
		$das_data{stylesheet} = $self->param('DASstylesheet');
		$das_data{score} = $self->param('DASscore');
		$das_data{group} = $self->param('DASgroup');
		$das_data{url} = $das_data{protocol}.'://'.$das_data{domain};
		@{$das_data{enable}} = $self->param('DASenable');
		@{$das_data{mapping}} = $self->param('DAStype');
		$das_data{conftype} = 'external';
		$das_data{color} = $self->param("DAScolor");
		$das_data{depth} = $self->param("DASdepth");
		$das_data{help} = $self->param("DAShelp");
		$das_data{linktext} = $self->param("DASlinktext");
		$das_data{linkurl} = $self->param("DASlinkurl");
		$das_data{type} = 'mixed' if (scalar(@{$das_data{mapping}} > 1));
		$das_data{active} = 1; # Enable by default
		foreach my $key( @confkeys, 'label', 'url', 'linktext', 'linkurl', 'conftype', 'group', 'stylesheet', 'score', 'enable', 'caption', 'active', 'color', 'depth', 'help', 'mapping' ) {
		    $sources_conf{$das_name} ||= {};
		    $sources_conf{$das_name}->{$key} = $das_data{$key};
		}
		$extdas->add_das_source(\%das_data);
		$DASsel{$das_name} = 1;
	    }
				
	}
    }
    # Clean up any 'dangling' _das parameters
    if( $self->delete_param( "_das_delete" ) ){
	foreach my $key( @confkeys ){ $self->delete_param("DAS$key") }
    }
  
    my @udaslist = ();
    my @das_objs = ();
 
# Now we have a list of all active das sources - for each of them  create a DAS adaptor capable of retrieving das features 
    foreach my $source( sort keys %sources_conf ){
	# Create the DAS adaptor from the (valid) conf
	my $source_conf = $sources_conf{$source};
	push (@udaslist, "URL:$source_conf->{url}") if ($source_conf->{conftype} eq 'url');
		  
	$source_conf->{active} = defined ($DASsel{$source}) ? 1 : 0;

	if( ! $source_conf->{url} and ! ( $source_conf->{protocol} && $source_conf->{domain} ) ){
	    next;
	}
	my $das_adapt = Bio::EnsEMBL::ExternalData::DAS::DASAdaptor->new
	    ( 
	      -name       => $source,
	      -url        => $source_conf->{url}       || '',
	      -protocol   => $source_conf->{protocol}  || '',
	      -domain     => $source_conf->{domain}    || '',
	      -dsn        => $source_conf->{dsn}       || '',
	      -type       => $source_conf->{type}      || '',
	      -authority  => $source_conf->{authority} || '',
	      -label      => $source_conf->{label}     || '',
	      -labelflag  => $source_conf->{labelflag} || '',
	      -caption    => $source_conf->{caption}   || '',
	      -color      => $source_conf->{color} || $source_conf->{col} || '',
	      -linktext   => $source_conf->{linktext}  || '',
	      -linkurl    => $source_conf->{linkurl}   || '',
	      -strand     => $source_conf->{strand}    || '',
	      -depth      => $source_conf->{depth},
	      -group      => $source_conf->{group}     || '',
	      -stylesheet => $source_conf->{stylesheet}|| '',
	      -score      => $source_conf->{score} || '',
	      -conftype   => $source_conf->{conftype}  || 'external',
	      -active     => $source_conf->{active}    || 0, 
	      -description => $source_conf->{description}    || '', 
	      -types      => $source_conf->{types} || [],
	      -on         => $source_conf->{on}    || [],
	      -enable     => $source_conf->{enable}    || [],
	      -help     => $source_conf->{help}    || '',
	      -mapping     => $source_conf->{mapping}    || [],
	      -fasta      => $source_conf->{fasta} || [],
	      );				
	$das_adapt->ensembldb( $self->DBConnection('core') );
	if( my $p = $self->species_defs->ENSEMBL_WWW_PROXY ){
	    $das_adapt->proxy($p);
	}

	# Create the DAS object itself
	my $das_obj = Bio::EnsEMBL::ExternalData::DAS::DAS->new( $das_adapt );
	push @das_objs, $das_obj;
    }
    
    # Create the collection object
    my $dataobject = EnsEMBL::Web::Proxy::Object->new( 'DASCollection', [@das_objs], $self->__data );
    $self->DataObjects( $dataobject );
    
  return 1; #success
}

sub getEnsemblMapping {
    my ($self, $cs) = @_;
#    my ($realm, $base, $species) = split(/\,/, $cs);

    my ($realm, $base, $species) = ($cs->{name}, $cs->{category}, $cs->{organismName});
    my $smap ='unknown';


    if ($base =~ /Chromosome|Clone|Contig|Scaffold/) {
	$smap = 'ensembl_location';
    } elsif ($base eq 'Gene_ID') {
	if ($realm eq 'Ensembl') {
	    $smap = 'ensembl_gene';
	} elsif ($realm eq 'HUGO_ID') {
	    $smap = 'hugo';
	} elsif ($realm eq 'MGI') {
	    $smap = 'mgi';
	} elsif ($realm eq 'MarkerSymbol') {
	    $smap = 'markersymbol';
	} elsif ($realm eq 'EntrezGene') {
	    $smap = 'entrezgene';
	} elsif ($realm eq 'IPI') {
	    $smap = 'ipi';
	} 
    } elsif ($base eq 'Protein Sequence') {
	if ($realm eq 'UniProt') {
	    $smap = 'uniprot/swissprot_acc';
	} elsif ($realm =~ /Ensembl/) {
	    $smap = 'ensembl_peptide';
	}
    }

    $species or $species = '.+';
#    warn "B:$cs#".join('*', $realm, $base, $species)."#$smap";
    return wantarray ? ($smap, $species) : $smap;
}

sub getRegistrySources {
    my $self = shift;

    if (defined($self->{data}->{_das_registry})) {
	return $self->{data}->{_das_registry};
    }

    my $filterT = sub {
	return 1;
    };
    my $filterM = sub {
	return 1;
    };

    my $keyText = $self->param('keyText');
    my $keyMapping = $self->param('keyMapping');

    if (defined (my $dd = CGI::param('_apply_search=registry.x'))) {
	if ($keyText) {
	    $filterT = sub { 
		my $src = shift; 
		return 1 if ($src->{url} =~ /$keyText/); 
		return 1 if ($src->{nickname} =~ /$keyText/); 
		return 1 if ($src->{description} =~ /$keyText/); 
		return 0; };
	}
	
	if ($keyMapping ne 'any') {
	    $filterM = sub { 
		my $src = shift; 
		foreach my $cs (@{$src->{coordinateSystem}}) {
		    return 1 if ($self->getEnsemblMapping($cs) eq $keyMapping);
		}
		return 0; };
	}
											       
    }
    my $das_url = $self->species_defs->DAS_REGISTRY_URL;

    my $source_arr = SOAP::Lite->service("${das_url}/services/das:das_directory?wsdl")->listServices();
    my $i = 0;
    my %registryHash = ();
    my $spec = $ENV{ENSEMBL_SPECIES};
    $spec =~ s/\_/ /g;
    while(ref $source_arr->[$i]){
	my $dassource = $source_arr->[$i++];
	next if ("@{$dassource->{capabilities}}" !~ /features/);
	foreach my $cs (@{$dassource->{coordinateSystem}}) {
	    my ($smap, $sp) = $self->getEnsemblMapping($cs);
	    if ($smap ne 'unknown' && ($spec =~ /$sp/) && $filterT->($dassource) && $filterM->($dassource)) {
		my $id = $dassource->{id};
		$registryHash{$id} = $dassource; 
		last;
	    }
	}


    }
    $self->{data}->{_das_registry} = \%registryHash;
    return $self->{data}->{_das_registry};
}


sub getSourceData {
    my ($self, $dassource, $dasconf) = @_;

    if ($dassource->{url} =~ /(https?:\/\/)(.+das)\/(.+)/) {
	($dasconf->{protocol}, $dasconf->{domain}, $dasconf->{dsn}) = ($1, $2, $3);
	$dasconf->{dsn} =~ s/\///;
	$dasconf->{protocol} =~ s/\:\/\///;

	my ($smap, $species);
	foreach my $cs (@{$dassource->{coordinateSystem}}) {
	    ($smap, $species) = $self->getEnsemblMapping($cs);
	    push (@{$dasconf->{mapping}}, $smap) if ($smap ne 'unknown' && (! grep {$_ eq $smap} @{$dasconf->{mapping}}));
	}
	$dasconf->{name} = $dassource->{nickname};
	$dasconf->{type} = scalar(@{$dasconf->{mapping}}) > 1 ? 'mixed' : $smap;
    }
}

1;
