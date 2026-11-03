# Audio

PipeWire and sound.

- For a fair comparison, Kiln needs the same audio output as the Ubuntu baseline. Ubuntu result: smallest clean buffer 256 samples under compile load.
- Freezing the test playback for 1 second was counted as dropouts during the measurement script test. Keep the test playback undisturbed.
- The Ubuntu baseline measured through `alsa_output.pci-0000_02_00.1.hdmi-stereo-extra1`, the WX 3200. The live system defaults to USB audio S/PDIF. Set the same output before measuring.
