{ pkgs, ... }:

with pkgs;

{
  # Media tools are intentionally separate; they are convenient, but they do
  # not belong to a minimal workstation profile.
  mediaPackages = [
    ffmpeg-full
    mpv
    # thumbnails and helpers
    ffmpegthumbnailer
  ];
}
