# Desktop

Hyprland, graphics and the screen.

- The screen is on mini DisplayPort from the WX 3200, which has only mini DisplayPort sockets. HDMI into the RTX 4090 is the fallback if a live image shows a black screen.
- Kiln needs a login screen that reaches graphical.target, for a fair boot comparison with Ubuntu.
- Card numbers and connector names change. Ubuntu called the screen `card2-DP-7`, and the live system `card0-DP-4`, on the same WX 3200. Choose the card by PCI address 02:00.0.
- The firmware starts on the WX 3200. The screen runs 5120x1440 at 120 Hz through it.
- The RTX 4090 runs at x8, not x16, with both cards fitted. The owner decided this does not matter, as the card is mainly for ML work.
