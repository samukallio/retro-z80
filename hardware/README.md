# Hardware Design

<p align=center>
  <img src="https://github.com/samukallio/retro-z80/blob/main/media/block-diagram.png?raw=true">
</p>

This document describes the hardware design of the machine in detail. Aside from the Z80 CPU, the design uses common 55ns SRAM and 150ns EEPROM memory chips, 74HCxx series chips for simple glue logic, and ATF22V10C-15PU programmable logics (PLDs) for more complex timing and control logic. The use of PLDs in particular makes the design relatively compact: the breadboard prototype fits on four 63-row solderless breadboards. The ATF22V10 is compatible with the (discontinued) Lattice GAL22V10 introduced in the 1980s. All of the chips used in the project are roughly contemporaneous, which was one of the design goals of the project.

For schematics, see the KiCad project under `kicad/` or the SVG renders `z80.svg` and `z80-video.svg`. There is no PCB design at this point, as the prototype is still a work-in-progress. I would at least like to add a simple variable-frequency audio tone generator before transfering the design to a PCB.

The logic functions performed by the PLDs are expressed in a programming language called CUPL (see the `.pld` files under `cupl/`). These logic description files are compiled into fuse maps (`.jed` files) using the WinCUPL tool, [available for free](https://www.microchip.com/en-us/development-tool/wincupl) from Microchip. The fuse maps are then programmed into an ATF22V10 similar to programming an EEPROM. Both commerical and open source programmers exist for these chips.

## Base System

The base system is a basic Z80 design with ROM, RAM, and two 8-bit registers mapped to I/O ports.

### ROM, RAM, and memory address decoding

A 74HC138 3-to-8 line decoder is used to decode address lines A13, A14 and A15, splitting the 64K address space into 8x8K segments. The first segment ($0000-$1FFF) is mapped to an 8K EEPROM (AT28C64B) and the second segment ($2000-$3FFF) is mapped to an 8K SRAM (AS6C6264). The third segment ($4000-$5FFF) is mapped to VRAM (or rather, the VRAM control circuitry, which arbitrates access to VRAM). The remaining segments ($6000-$FFFF) are unmapped.

The address decoder is enabled by `/MREQ` and disabled by `/RFSH`. The `/RFSH` signal is used to refresh dynamic memories, which the system does not have. Typically, it would be fine to ignore this signal altogether, since it has no effect on SRAM and EEPROM chips. However, the VRAM circuitry is affected just by being selected, and I wanted to ensure that the `/VRAM` signal would never be asserted unless a genuine memory access was being made. Since the refresh address consists only of the low 7 address lines, this would probably never happen anyway, but I decided leave it in for the prototype design regardless.

### Input ports and I/O address decoding

The system has two 74HC574 octal D flip-flops (DFFs) acting as controller input ports. These are mapped to I/O ports `8*N` and `8*N+1` by feeding address lines A0, A1 and A2 to another 74HC138 3-to-8 line decoder. This decoder controls the output enable (`/OE`) pins of the DFFs. The decoder is enabled when the CPU asserts both the `/IORQ` and `/RD` lines. There are currently no other I/O ports, and no I/O ports that can be output to.

### Interrupts

The `/NMI` input of the CPU is connected directly to the `/BLANK` output of the video timing circuit. This provides a non-maskable interrupt at the start of the vertical blanking interval of each frame. This is useful to synchronize CPU accesses to the VRAM so that all rendering happens during the vertical blanking interval. Maskable interrups are currently unused, and the `/IRQ` input of the CPU is tied high.

## Video Timing

### Keeping track of the raster position

The video timing circuit generates timing signals necessary for non-interlaced PAL video output. A non-interlaced PAL frame consists of 312 scanlines, including blank lines and the vertical retrace period. Each scanline is 64 &mu;s long, which on a 8 MHz system clock works out to a convenient 512 clock cycles per line. Therefore, a non-interlaced frame is exactly 312*512 = 159744 clock cycles long. This means that we can use an 18-bit binary counter to keep track of the raster position, where the top 9 bits represent the current scanline and the bottom 9 bits represent the horizontal raster position.

The video generator produces a constant stream of frames, one after another. From a timing perspective, all that matters is that things happen in the correct sequence. In particular, we are free to index the scanlines however we like. Since we are generating 256 lines of visible output per frame, it is convenient to use the scanline counter values 0 to 255 for the visible portion of the frame. Counter values 256 to 311 then cover the blank lines below the visible lines of the current frame, the vertical retrace period, and the blank lines above the visible lines of the next frame. Now, the top bit of the scanline counter directly indicates a vertical blanking period, which is useful.

### Design

The design consists of a 74HC4040 12-stage ripple counter and an ATF22V10C programmable logic (PLD). The ripple counter generates the full 9 bits of the horizontal raster position as well as the low 3 bits of the scanline counter. The PLD generates the top 6 bits of the scanline counter, as well as three active-low timing signals that are derived from the position counter:
* `/SYNC`: PAL composite sync signal that achieves non-interlaced operation.
* `/BLANK`: Active during the vertical blank period (lines 256 to 311). This is effectively the top bit of the scanline counter, but inverted.
* `/VIDEO`: A "video output enable" signal that is active during the visible portion of a visible scanline (256 clock cycles).

These timing signals are produced as registered outputs of the PLD. Using registered (rather than combinatorial) outputs is necessary, because the ripple counter output is unstable while the clock signal is propagating through it. A combinatorial sync pulse output might produce spurious sync pulses during this unstable period. As a result of using registers, the timing signals (derived from the counter value) lag behind the current counter value. It is useful to think of the current counter state as denoting the upcoming raster position, rather than the current one.

The output of the ripple counter is wired so that bit 3 of the counter clocks the registers of the PLD, and bits 4 to 11 are provided as inputs to the PLD. Since bit 3 of the ripple counter becomes high exactly once every 16 system clock cycles, the PLD operates at a 16-cycle (or 2 &mu;s) granularity. This is sufficient to generate the required timing signals for PAL. The reason for clocking the PLD from the ripple counter is to give the counter sufficient time to settle before the PLD is clocked. If clocked from the system clock, the ripple counter would have to settle within half a clock period (the ripple counter clock is negative-edge-triggered), which the 74HC4040 cannot meet. By clocking the PLD from bit 3 of the counter, bits 4 to 11 are guaranteed to be stable (since they only change when bit 3 becomes 0).

In addition to the counter value, the PLD also receives the processor `/RESET` signal as an input to clear the upper bits of the scanline counter when the machine is being reset. This is done to avoid the possibility generating an NMI immediately after reset, before the processor has had time to set up an NMI handler.

### Notes

The ripple counter clock is actually an inverted video clock (which itself is a twice-inverted system clock). As the video clock goes high, the ripple counter clock goes low, triggering a count. This then possibly clocks the PLD after 4 bit-to-bit propagation delays, changing the PLD outputs after the PLD clock propagation delay. Without inverting the ripple counter clock, this all would have to happen within the 62.5ns (half a clock cycle, ignoring setup time requirements) before the video clock goes high again. Rather than gamble on this being enough, an inverted clock is used to give the signals twice as much time to propagate.

## VRAM Control

The video RAM exists on a separate address/data bus from the CPU. This design allows the CPU to run independently of the video system, without interference from raster scan VRAM accesses during the visible portion of the frame. The VRAM control logic generates the VRAM address during the active video part of the frame. It also arbitrates CPU access to VRAM by acting as a buffer between the CPU and VRAM address and data buses.

### Design

The design consists of two 74HC161 4-bit synchronous presettable counters, a 74HC245 8-bit bus transceiver, and an ATF22V10C programmable logic (PLD). The PLD implements the main control logic, as well as a synchronous counter for the low 5 bits of the VRAM address. The two 4-bit synchronous counters provide the top 8 bits of the VRAM address. The bus transceiver connects the CPU data bus to the VRAM data bus in one direction or the other, depending on whether the VRAM is being read from or written to.

The PLD generates the following control signals (in addition to the 5 address bits):
* `/VRAMOE`: Output enable signal for the VRAM chip. Also sets the direction of the data bus transceiver.
* `/VRAMWE`: Write enable signal for the VRAM chip.
* `/DATAOE`: Output enable signal for the data bus transceiver.
* `RCO`: Ripple carry output for the clock enable signal of the first 74HC161 4-bit address counter.

These signals (with the exception of `RCO`) are generated as registered outputs from the PLD, and hence they lag the inputs by up to 1 clock cycle. The PLD is clocked by the video clock, which is derived from the system clock by inverting it twice.

### VRAM access by the CPU

The PLD receives the `/VRAM` signal from the CPU address decoder, and the `/RD` and `/WR` signals from the CPU. The `/VRAM` signal is also wired to the synchronous load input of the two 4-bit counters. When the CPU places a VRAM address on the address bus and asserts `/MREQ` during CPU T-state 1, the `/VRAM` signal goes active, enabling the parallel load function of both 4-bit binary counters and the custom 5-bit binary counter in the PLD. On the next rising clock edge (start of CPU T-state 2), the VRAM address counter is loaded with the contents of the CPU address bus, and the address appears on the VRAM address bus.

For reads, the CPU asserts `/RD` simultaneously with `/MREQ` (during T-state 1). This causes `/VRAMOE` and `/DATAOE` to go active at the same time (start of CPU T-state 2) as the address is driven onto the VRAM address bus. This state remains active until the CPU de-asserts `/MREQ` and `/RD`, and the PLD is clocked, which happens at the end of CPU T-state 3.

For writes, the CPU asserts `/WR` during T-state 2. This causes `/VRAMWE` and `/DATAOE` to go active one cycle after the address is driven onto the VRAM address bus (start of T-state 3). This state remains active until the CPU de-asserts `/MREQ` and `/WR`, and the PLD is clocked, which happens at the end of CPU T-state 3.

The arbitration logic makes it safe for the CPU to access the VRAM even when the VRAM is being scanned out during the visible portion of the frame. The CPU access overrides the scanning logic, and the VRAM address increment is suppressed. Once the CPU access is complete, the VRAM will continue being scanned out, starting from the address of the previous access.

### VRAM scan logic

The PLD receives the `/VIDEO` signal from the video timing circuit. This signal is active for exactly 256 clock cycles on each visible scanline (of which there are 256 per frame). While this signal is active, the VRAM control logic reads out the contents of the VRAM to output pixels to the monitor.

Each byte in VRAM corresponds to a row of 8 pixels. When `/VIDEO` is active, the VRAM control logic drives `/VRAMOE` low every 8 clock cycles to read the next 8 pixels from VRAM. After this, the VRAM address counter is incremented. To keep count of these 8 clock cycles, the PLD receives bits 0 to 2 from the ripple counter of the video timing generator. The ripple propagation delay for these lower bits is low enough to fit within the 125ns clock cycle.

Note that the VRAM address counter is never reset. Instead, the VRAM address counter ends up exactly where it started from after scanning out a single frame. It is possible for the CPU to control the starting VRAM address of the frame by (for example) performing a dummy read from a VRAM location during the vertical blanking period. This enables a crude form of hardware-accelerated scrolling.

## Video Signal Generator

The `/SYNC` signal from the video timing logic, and the pixel data from the VRAM, are combined to form a monochrome PAL video signal.

### Design

The design consists of a 74HC165 parallel-load shift register, a 74HC27 three triple-input NOR gates (for glue logic), a resistive voltage divider and adder, and an an output amplifier. Every 8 clock cycles, 8 bits (corresponding to 8 pixels) from VRAM are loaded into the shift register, and shifted out one bit at a time. The `/SYNC` signal, and the serial output of the shift register, are fed into a resistive voltage divider and adder network that generates the correct PAL output voltages: 0V for sync, 0.3V for black, and 1V for white. This signal is fed to an output amplifier with an output impedance of roughly 75&Omega;.

### Pixel shift register

The shift register runs off the video clock. It is loaded every time the VRAM outputs a byte while `/VIDEO` is active. When `/VIDEO` is not active, the register will shift low bits from the serial inputs to produce a low output. This is important, because in order to produce a correct sync pulse level, the output of the shift register must be low when `/SYNC` is asserted. It is not sufficient to simply load the shift register whenever the VRAM outputs a byte, since then it might be loaded when the CPU reads from VRAM during the vertical blank period, causing the shift register output to disrupt the synchronization pulses.

The active-low load enable input of the shift register is generated using the 74HC27 as glue logic, combining `/VRAMOE`, `/VIDEO` and `CLK` (the video clock). The clock signal is included, because the load enable input is asynchronous on the 74HC165, and enabling it for a whole clock period would cause the register to ignore one clock pulse, duplicating the first pixel of a group of 8, and losing the last one. A better solution would probably be to use a 74HC166, which has a synchronous load function, but I did not have any at hand when building the prototype.
