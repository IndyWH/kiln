# Audio

PipeWire and sound.

- For a fair comparison, Kiln needs the same audio output as the Ubuntu baseline. Ubuntu result: smallest clean buffer 256 samples under compile load.
- Freezing the test playback for 1 second was counted as dropouts during the measurement script test. Keep the test playback undisturbed.
- The Ubuntu baseline measured through `alsa_output.pci-0000_02_00.1.hdmi-stereo-extra1`, the WX 3200. The live system defaults to USB audio S/PDIF. Set the same output before measuring.
- Kiln also picked USB S/PDIF on first boot, as no output had been chosen. The owner uses the Philips through the WX 3200. Set with `wpctl set-default`, which saves to ~/.local/state/wireplumber/default-nodes, so a fresh install needs it set again. Volume is 70%.
- A first test on each output was not heard: a short sound at 40% on an output at 40%. A steady 6-second tone with the output at 70% was heard. Test with that before suspecting the hardware.
