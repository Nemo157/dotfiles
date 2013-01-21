#!/usr/bin/env zsh

help="Usage: $0 file_name bit_rate"

if [[ -z "$1" || -z "$2" ]] {
  echo $help
  exit 1
}

file="$1"
bitrate="${2}k"

volume="${$(exiftool -config <(<<-"END"
  %Image::ExifTool::UserDefined = (
    'Image::ExifTool::Composite' => {
        ReplaygainAlbumGainClean => {
          Desire => {
              0 => 'ReplaygainAlbumGain',
              1 => 'UserDefinedText',
          },
          ValueConv => sub {
              my $val = shift;
              my $self = shift;

              my @gainTags = (@$val[0]);
              my $userTags = $self->GetInfo("*:UserDefinedText");
              foreach (values %$userTags) {
                  next unless $_ && $_ =~ /replaygain_album_gain/;
                  push (@gainTags, $_);
              }

              my $gain = 0;
              foreach (@gainTags) {
                  next unless $_ && $_ =~ /([+-]?\d+(?:\.\d+)?)/;
                  $gain = $1;
              }
              return $gain;
          },
        },
      },
    );
  1;
  END) -ReplaygainAlbumGainClean -s3 "$file"):-0}dB"

echo "ReplayGain Album Gain = ${volume}" >&2
ffmpeg -i "$file" -ab "$bitrate" -v warning -f mp3 -filter "volume=${volume}" -
