package EnsEMBL::Web::Text::FeatureParser::WIG;

use strict;
use warnings;

use base qw(EnsEMBL::Web::Text::FeatureParser);

sub parse_row {
  my( $self, $row ) = @_;
  my $columns;

  if ($row =~ /variableStep\s+chrom=(chr)?([^\s]+)(\s+span=)?(\d+)?/i) {
    my $wigConfig = {
		  'format' => 'v',
		  'region' => $2,
		  'span' => $4 || 1,
	  };
	  $self->{'tracks'}{ $self->current_key }->{'mode'} = $wigConfig;
  } 
  elsif ($row =~ /fixedStep\s+chrom=(chr)?(.+)\s+start=(\d+)\s+step=(\d+)(\s+span=)?(\d+)?/i) {
	  my $wigConfig = {
		  'format' => 'f',
		  'region' => $2,
		  'span' => $6 || 1,
		  'start' => $3,
		  'step' => $4,
	  };
	  $self->{'tracks'}{ $self->current_key }->{'mode'} = $wigConfig;
	} 
  else {
    ## Actual data row
    $row =~ s/^\s+//;
	  my @ws_delimited = split /\s+/, $row;
	  push @ws_delimited, $ws_delimited[0];

	  my $wigConfig = $self->{'tracks'}{ $self->current_key }->{'mode'};
	  if ($wigConfig->{format}) {
		  if ($wigConfig->{format} eq 'v') {
		    $columns = [
                    $wigConfig->{'region'}, 
                    $ws_delimited[0], 
                    $ws_delimited[0] + $wigConfig->{span} - 1, 
                    $ws_delimited[1], 
                    $ws_delimited[2]
        ];
		  } 
      elsif ($wigConfig->{format} eq 'f') {
		    $columns = [
                    $wigConfig->{'region'}, 
                    $wigConfig->{start}, 
                    $wigConfig->{start} + $wigConfig->{span} - 1, 
                    $ws_delimited[0], 
                    $ws_delimited[1]
        ];
		    $self->{'tracks'}{ $self->current_key }->{'mode'}->{'start'} += $wigConfig->{step};
		  }
	  } 
    else {
		  $columns = \@ws_delimited;
    }
	}
  return $columns; 
}


1;
