{ pkgs, ... }:

with pkgs;

{
  mediaPackages = [
    ffmpeg-full
    vlc
    mpv
    # thumbnails and helpers
    ffmpegthumbnailer
  ];
}
