#define _CRT_SECURE_NO_WARNINGS
#define SDL_MAIN_HANDLED

#include <cstdint>
#include <cstdio>
#include <cassert>
#include <memory>
#include <SDL.h>
#include <z80ex.h>

using u8 = std::uint8_t;
using u16 = std::uint16_t;
using u32 = std::uint32_t;
using i32 = std::int32_t;
using i64 = std::int64_t;
using u64 = std::uint64_t;

struct Machine
{
	u8 ram[8192];
	u8 rom[8192];
	u8 vram[8192];
	u16 vram_address;
	u8 port_data[2];
};

Z80EX_BYTE memory_read(Z80EX_CONTEXT* cpu, Z80EX_WORD addr, int m1_state, void* user_data)
{
	auto m = static_cast<Machine*>(user_data);

	if (addr >= 0x6000) {
		return 0;
	}
	else if (addr >= 0x4000) {
		m->vram_address = addr & 0x1FFF;
		return m->vram[m->vram_address];
	}
	else if (addr >= 0x2000) {
		return m->ram[addr & 0x1FFF];
	}
	else {
		return m->rom[addr];
	}
}

void memory_write(Z80EX_CONTEXT* cpu, Z80EX_WORD addr, Z80EX_BYTE value, void* user_data)
{
	auto m = static_cast<Machine*>(user_data);
	
	if (addr >= 0x6000) {
		return;
	}
	else if (addr >= 0x4000) {
		m->vram_address = addr & 0x1FFF;
		m->vram[m->vram_address] = value;
	}
	else if (addr >= 0x2000) {
		m->ram[addr & 0x1FFF] = value;
	}
	else {
		return;
	}
}

Z80EX_BYTE port_read(Z80EX_CONTEXT* cpu, Z80EX_WORD port, void* user_data)
{
	auto m = static_cast<Machine*>(user_data);
	return m->port_data[port & 1];
}

void port_write(Z80EX_CONTEXT* cpu, Z80EX_WORD port, Z80EX_BYTE value, void* user_data)
{
	auto m = static_cast<Machine*>(user_data);
}

Z80EX_BYTE interrupt_read(Z80EX_CONTEXT* cpu, void* user_data)
{
	return 0;
}

int main()
{
	FILE* file = fopen("../software/image.bin", "rb");
	if (!file) {
		printf("cannot open image.bin\n");
		return -1;
	}

	auto m = new Machine;
	assert(m);

	fread(m->rom, 1, 8192, file);
	fread(m->ram, 1, 8192, file);
	memset(m->vram, 0, 8192);
 	fclose(file);

	auto z80 = z80ex_create(
		memory_read, m,
		memory_write, m,
		port_read, m,
		port_write, m,
		interrupt_read, m);
	assert(z80);

	SDL_SetMainReady();

	SDL_Window* window = SDL_CreateWindow(
		"Z80 SBC Emulator",
		SDL_WINDOWPOS_UNDEFINED,
		SDL_WINDOWPOS_UNDEFINED,
		1024, 1024,
		SDL_WINDOW_SHOWN);
	assert(window);

	SDL_Surface* surface = SDL_GetWindowSurface(window);
	assert(surface);

	// Accumulates cycles.
	i64 cycles = 0;

	u64 initial_ticks = SDL_GetTicks64();
	u64 current_frame = 0;

	bool exit = false;
	while (!exit) {
		SDL_Event event;
		while (SDL_PollEvent(&event)) {
			if (event.type == SDL_QUIT) {
				exit = true;
				break;
			}
		}

		const u8* keys = SDL_GetKeyboardState(nullptr);
		m->port_data[1]
			= (keys[SDL_SCANCODE_LEFT]   << 0)
			| (keys[SDL_SCANCODE_RIGHT]  << 1)
			| (keys[SDL_SCANCODE_UP]     << 2)
			| (keys[SDL_SCANCODE_DOWN]   << 3)
			| (keys[SDL_SCANCODE_SPACE]  << 4)
			| (keys[SDL_SCANCODE_RETURN] << 5);

		i64 const VIDEO_CYCLES = 256 * 512;
		i64 const FRAME_CYCLES = 312 * 512;

		// Run for one frame.
		bool nmi_accepted = false;
		while (cycles < FRAME_CYCLES) {
			// Execute one opcode.
			cycles += z80ex_step(z80);

			// Entering vertical blank, assert NMI.
			if (cycles >= VIDEO_CYCLES && !nmi_accepted) {
				i64 nmi_cycles = z80ex_nmi(z80);
				cycles += nmi_cycles;
				nmi_accepted = nmi_cycles > 0;
			}
		}
		cycles -= FRAME_CYCLES;

		// Copy VRAM contents onto the window surface.
		SDL_LockSurface(surface);
		u32* pixels = (u32*)surface->pixels;
		for (i32 y = 0; y < 1024; y++) {
			u8* vram_line = m->vram + (y >> 2) * 32;
			for (i32 x = 0; x < 32; x++) {
				u8 vram_byte = vram_line[x];
				for (i32 b = 0; b < 8; b++) {
					u32 color = ((vram_byte >> b) & 1) ? 0xFFFFFFFF : 0x00000000;
					*pixels++ = color;
					*pixels++ = color;
					*pixels++ = color;
					*pixels++ = color;
				}
			}
		}
		SDL_UnlockSurface(surface);
		SDL_UpdateWindowSurface(window);

		current_frame += 1;

		u64 target_ticks = initial_ticks + u64((current_frame * 1000) / 50.080128);
		while (SDL_GetTicks64() < target_ticks);
	}

	return 0;
}