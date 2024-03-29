# Hardware Design

<p align=center>
  <img src="https://github.com/samukallio/retro-z80/blob/main/media/block-diagram.png?raw=true">
  Figure 1: High-level hardware block diagram.
</p>

## Core System

The core system is a basic Z80 design with ROM, RAM, and two 8-bit registers mapped to I/O ports.

### Memory address decoding

A 74HC138 3-to-8 line decoder is used to decode address lines A13, A14 and A15, splitting the 64K address space into 8x8K segments. The first segment ($0000-$1FFF) is mapped to an 8K EEPROM (AT28C64B) and the second segment ($2000-$3FFF) is mapped to an 8K SRAM (AS6C6264). The third segment ($4000-$5FFF) is mapped to VRAM (or rather, the VRAM control circuitry, which arbitrates access to VRAM). The remaining segments ($6000-$FFFF) are unmapped.

The address decoder is enabled by `/MREQ` and disabled by `/RFSH`. The `/RFSH` signal is used to refresh dynamic memories, which the system does not have. Typically, it would be fine to ignore this signal altogether, since it has no effect on SRAM and EEPROM chips. However, the VRAM circuitry is affected just by being selected, and I wanted to ensure that the `/VRAM` signal would never be asserted unless a genuine memory access was being made. Since the refresh address consists only of the low 7 address lines, this would probably never happen anyway, but I decided leave it in for the prototype design regardless.

### Input ports and I/O address decoding

The system has two 74HC574 octal D flip-flops (DFFs) acting as controller input ports. These are mapped to I/O ports `8*N` and `8*N+1` by feeding address lines A0, A1 and A2 to another 74HC138 3-to-8 line decoder. This decoder controls the output enable (`/OE`) pins of the DFFs. The decoder is enabled when the CPU asserts both the `/IORQ` and `/RD` lines. There are currently no other I/O ports, and no I/O ports that can be output to.

## Video Timing

### Keeping track of the raster position

The video timing circuit generates timing signals necessary for non-interlaced PAL video output. A non-interlaced PAL frame consists of 312 scanlines, including blank lines and the vertical retrace period. Each scanline is 64 &mu;s long, which on a 8 MHz system clock works out to a convenient 512 clock cycles per line. Therefore, a non-interlaced frame is exactly 312*512 = 159744 clock cycles long. This means that we can use an 18-bit binary counter to keep track of the raster position, where the top 9 bits represent the current scanline and the bottom 9 bits represent the horizontal raster position.

The video generator produces a constant stream of frames, one after another. From a timing perspective, all that matters is that things happen in the correct sequence. In particular, we are free to index the scanlines however we like. Since we are generating 256 lines of visible output per frame, it is convenient to use the scanline counter values 0 to 255 for the visible portion of the frame. Counter values 256 to 311 then cover the blank lines below the visible lines of the current frame, the vertical retrace period, and the blank lines above the visible lines of the next frame. Now, the top bit of the scanline counter directly indicates a vertical blanking period, which is useful.

### Timing circuit

The design consists of a 74HC4040 12-stage ripple counter and an ATF22V10C programmable logic (PLD). The ripple counter generates the full 9 bits of the horizontal raster position as well as the low 3 bits of the scanline counter. The PLD generates the top 6 bits of the scanline counter, as well as three active-low timing signals that are derived from the position counter:
* `/SYNC`: PAL composite sync signal that achieves non-interlaced operation.
* `/BLANK`: Active during the vertical blank period (lines 256 to 311). This is effectively the top bit of the scanline counter, but inverted.
* `/VIDEO`: A "video output enable" signal that is active during the visible portion of a visible scanline (256 clock cycles).

These timing signals are produced as registered outputs of the PLD. Using registered (rather than combinatorial) outputs is necessary, because the ripple counter output is unstable while the clock signal is propagating through it. A combinatorial sync pulse output might produce spurious sync pulses during this unstable period. As a result of using registers, the timing signals (derived from the counter value) lag behind the current counter value. It is useful to think of the current counter state as denoting the upcoming raster position, rather than the current one.

The output of the ripple counter is wired so that bit 3 of the counter clocks the registers of the PLD, and bits 4 to 11 are provided as inputs to the PLD. Since bit 3 of the ripple counter becomes high exactly once every 16 system clock cycles, the PLD operates at a 16-cycle (or 2 &mu;s) granularity. This is sufficient to generate the required timing signals for PAL. The reason for clocking the PLD from the ripple counter is to give the counter sufficient time to settle before the PLD is clocked. If clocked from the system clock, the ripple counter would have to settle within half a clock period (the ripple counter clock is negative-edge-triggered), which the 74HC4040 cannot meet. By clocking the PLD from bit 3 of the counter, bits 4 to 11 are guaranteed to be stable (since they only change when bit 3 becomes 0).

In addition to the counter value, the PLD also receives the processor `/RESET` signal as an input to clear the upper bits of the scanline counter when the machine is being reset. This is done to avoid the possibility generating an NMI immediately after reset, before the processor has had time to set up an NMI handler.

### Notes

The ripple counter clock is actually an inverted video clock (which itself is a twice-inverted system clock). As the video clock goes high, the ripple counter clock goes low, triggering a count. This then possibly clocks the PLD after 4 bit-to-bit propagation delays, changing the PLD outputs after the PLD clock propagation delay. Without inverting the ripple counter clock, this all would have to happen within the 62.5ns (half a clock cycle, ignoring setup time requirements) before the video clock goes high again. Rather than gamble on this, an inverted clock is used to give the signals twice as much time to propagate.
