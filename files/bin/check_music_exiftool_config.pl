sub search_custom_tags {
  my $self = shift;
  my $tagName = shift;
  my @values = ();

  for (my $i=0; ; ++$i) {
    my $val = $self->GetValue("UserDefinedText" . ($i ? " ($i)" : ''));
    last unless defined $val;
    push (@values, $val) if $val =~ qr/$tagName/;
  }

  for (my $i=0; ; ++$i) {
    my $name = $self->GetValue("Name" . ($i ? " ($i)" : ''));
    my $data = $self->GetValue("Data" . ($i ? " ($i)" : ''));
    last unless defined $name;
    push (@values, $$data) if $name =~ qr/$tagName/;
  }

  return @values;
}

sub get_first_number {
  my $values = shift;
  foreach (@$values) {
    next unless $_ && $_ =~ /([+-]?\d+(?:\.\d+)?)/;
    return $1;
  }
}

%Image::ExifTool::UserDefined = (
  'Image::ExifTool::Composite' => {
    ReplaygainAlbumPeakClean => {
      Desire => {
        0 => 'ReplaygainAlbumPeak',
        1 => 'UserDefinedText',
        2 => 'Name',
        3 => 'Data'
      },
      ValueConv => sub {
        my $val = shift;
        my $self = shift;
        my @values = (@$val[0], search_custom_tags($self, 'replaygain_album_peak'));
        return get_first_number(\@values);
      },
    },
    ReplaygainAlbumGainClean => {
      Desire => {
        0 => 'ReplaygainAlbumGain',
        1 => 'UserDefinedText',
        2 => 'Name',
        3 => 'Data'
      },
      ValueConv => sub {
        my $val = shift;
        my $self = shift;
        my @values = (@$val[0], search_custom_tags($self, 'replaygain_album_gain'));
        return get_first_number(\@values);
      },
    },
    ReplaygainTrackPeakClean => {
      Desire => {
        0 => 'ReplaygainTrackPeak',
        1 => 'UserDefinedText',
        2 => 'Name',
        3 => 'Data'
      },
      ValueConv => sub {
        my $val = shift;
        my $self = shift;
        my @values = (@$val[0], search_custom_tags($self, 'replaygain_track_peak'));
        return get_first_number(\@values);
      },
    },
    ReplaygainTrackGainClean => {
      Desire => {
        0 => 'ReplaygainTrackGain',
        1 => 'UserDefinedText',
        2 => 'Name',
        3 => 'Data'
      },
      ValueConv => sub {
        my $val = shift;
        my $self = shift;
        my @values = (@$val[0], search_custom_tags($self, 'replaygain_track_gain'));
        return get_first_number(\@values);
      },
    },
    OnlyTrack => {
      Desire => {
        0 => 'Track',
        1 => 'Tracknumber',
        2 => 'TrackNumber',
      },
      ValueConv => sub {
        my $val = shift;
        foreach (@$val) {
          next unless $_ && $_ =~ /^(\d+)(?:(?:\/| of )(\d+))?$/;
          return $1;
        }
      },
      PrintConv => 'sprintf("%02s", $val)',
    },
    DiscTitleAndSlash => {
      Desire => {
        0 => 'PartOfSet',
        1 => 'DiskNumber',
        2 => 'Discnumber',
        3 => 'Disctotal',
      },
      ValueConv => sub {
        my $val = shift;
        my ($disc, $total);
        if (@$val[0] && @$val[0] =~ /^(\d+)(?:\/| of )(\d+)/) {
          $disc = $1;
          $total = $2;
        }
        if (@$val[1] && @$val[1] =~ /^(\d+)(?:\/| of )(\d+)/) {
          $disc = $1;
          $total = $2;
        }
        if (@$val[2] && @$val[3]) {
          $disc = @$val[2];
          $total = @$val[3];
        }
        if ($total && $total > 1) {
          return "disc $disc/" ;
        } else {
          return "";
        }
      },
    },
    AlbumArtistOrArtist => {
      Desire => {
        0 => 'Artist',
        1 => 'Band',
      },
      ValueConv => sub {
        my $val = shift;
        return @$val[1] ? @$val[1] : @$val[0];
      },
    },
    TitleWithoutSlash => {
      Require => 'Title',
      ValueConv => '$val =~ tr/\//_/;$val'
    },
  },
);

1;
