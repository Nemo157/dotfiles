sub search_custom_tags {
  my $self = shift;
  my $tagName = shift;
  my @values = ();

  for (my $i=0; ; ++$i) {
    my $key = "UserDefinedText" . ($i ? " ($i)" : '');
    my $val = $self->GetValue($key);
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

sub get_first_value {
  my $values = shift;
  foreach (@$values) {
    return $_ if $_;
  }
}

%Image::ExifTool::UserDefined = (
  'Image::ExifTool::Composite' => {
    ReplaygainAlbumPeakClean => {
      Desire => {
        0 => 'ReplaygainAlbumPeak',
        1 => 'ReplayGainAlbumPeak',
        2 => 'UserDefinedText',
        3 => 'Name',
        4 => 'Data'
      },
      ValueConv => sub {
        my $val = shift;
        my $self = shift;
        my @values = (@$val[0], @$val[1], search_custom_tags($self, 'replaygain_album_peak'));
        return get_first_number(\@values);
      },
    },
    ReplaygainAlbumGainClean => {
      Desire => {
        0 => 'ReplaygainAlbumGain',
        1 => 'ReplayGainAlbumGain',
        2 => 'UserDefinedText',
        3 => 'Name',
        4 => 'Data'
      },
      ValueConv => sub {
        my $val = shift;
        my $self = shift;
        my @values = (@$val[0], @$val[1], search_custom_tags($self, 'replaygain_album_gain'));
        return get_first_number(\@values);
      },
    },
    ReplaygainTrackPeakClean => {
      Desire => {
        0 => 'ReplaygainTrackPeak',
        1 => 'ReplayGainTrackPeak',
        2 => 'UserDefinedText',
        3 => 'Name',
        4 => 'Data'
      },
      ValueConv => sub {
        my $val = shift;
        my $self = shift;
        my @values = (@$val[0], @$val[1], search_custom_tags($self, 'replaygain_track_peak'));
        return get_first_number(\@values);
      },
    },
    ReplaygainTrackGainClean => {
      Desire => {
        0 => 'ReplaygainTrackGain',
        1 => 'ReplayGainTrackGain',
        2 => 'UserDefinedText',
        3 => 'Name',
        4 => 'Data'
      },
      ValueConv => sub {
        my $val = shift;
        my $self = shift;
        my @values = (@$val[0], @$val[1], search_custom_tags($self, 'replaygain_track_gain'));
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
    DiscTitle => {
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
          return "disc $disc" ;
        } else {
          return "";
        }
      },
    },
    AlbumArtistOrArtist => {
      Desire => {
        0 => 'AlbumArtist',
        1 => 'Albumartist',
        2 => 'Band',
        3 => 'Artist',
      },
      ValueConv => sub {
        my $val = shift;
        return get_first_value(\@$val);
      },
    },
    TitleWithoutSlash => {
      Require => 'Title',
      ValueConv => '$val =~ tr/\//_/;$val'
    },
  },
);

1;
