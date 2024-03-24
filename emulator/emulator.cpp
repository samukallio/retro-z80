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
	u64 frame_cycle;
	Z80EX_CONTEXT* cpu;
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

void save_state(Machine* m, char const* path)
{
	FILE* file = fopen(path, "wb");

	u16 word = 0;

#define WRITE_REGISTER(REG) \
	word = z80ex_get_reg(m->cpu, REG); \
	fwrite(&word, sizeof(u16), 1, file);

	WRITE_REGISTER(regAF);
	WRITE_REGISTER(regBC);
	WRITE_REGISTER(regDE);
	WRITE_REGISTER(regHL);
	WRITE_REGISTER(regAF_);
	WRITE_REGISTER(regBC_);
	WRITE_REGISTER(regDE_);
	WRITE_REGISTER(regHL_);
	WRITE_REGISTER(regIX);
	WRITE_REGISTER(regIY);
	WRITE_REGISTER(regPC);
	WRITE_REGISTER(regSP);
	WRITE_REGISTER(regI);
	WRITE_REGISTER(regR);
	WRITE_REGISTER(regR7);
	WRITE_REGISTER(regIM);
	WRITE_REGISTER(regIFF1);
	WRITE_REGISTER(regIFF2);

#undef WRITE_REGISTER

fwrite(&m->frame_cycle, sizeof(u64), 1, file);

fwrite(m->ram, sizeof(u8), 8192, file);
fwrite(m->vram, sizeof(u8), 8192, file);

fclose(file);
}

void load_state(Machine* m, char const* path)
{
	FILE* file = fopen(path, "rb");

	u16 word = 0;

#define READ_REGISTER(REG) \
	fread(&word, sizeof(u16), 1, file); \
	z80ex_set_reg(m->cpu, REG, word);

	READ_REGISTER(regAF);
	READ_REGISTER(regBC);
	READ_REGISTER(regDE);
	READ_REGISTER(regHL);
	READ_REGISTER(regAF_);
	READ_REGISTER(regBC_);
	READ_REGISTER(regDE_);
	READ_REGISTER(regHL_);
	READ_REGISTER(regIX);
	READ_REGISTER(regIY);
	READ_REGISTER(regPC);
	READ_REGISTER(regSP);
	READ_REGISTER(regI);
	READ_REGISTER(regR);
	READ_REGISTER(regR7);
	READ_REGISTER(regIM);
	READ_REGISTER(regIFF1);
	READ_REGISTER(regIFF2);

#undef READ_REGISTER

	fread(&m->frame_cycle, sizeof(u64), 1, file);

	fread(m->ram, sizeof(u8), 8192, file);
	fread(m->vram, sizeof(u8), 8192, file);

	fclose(file);
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

	m->frame_cycle = 0;

	fread(m->rom, 1, 8192, file);
	fread(m->ram, 1, 8192, file);
	memset(m->vram, 0, 8192);
	fclose(file);

	m->cpu = z80ex_create(
		memory_read, m,
		memory_write, m,
		port_read, m,
		port_write, m,
		interrupt_read, m);
	assert(m->cpu);

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

			if (event.type == SDL_KEYDOWN) {
				if (event.key.keysym.scancode == SDL_SCANCODE_F1)
					save_state(m, "state.dat");
				if (event.key.keysym.scancode == SDL_SCANCODE_F2)
					load_state(m, "state.dat");
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
		while (m->frame_cycle < FRAME_CYCLES) {
			// Execute one opcode.
			m->frame_cycle += z80ex_step(m->cpu);

			// Entering vertical blank, assert NMI.
			if (m->frame_cycle >= VIDEO_CYCLES && !nmi_accepted) {
				i64 nmi_cycles = z80ex_nmi(m->cpu);
				m->frame_cycle += nmi_cycles;
				nmi_accepted = nmi_cycles > 0;
			}
		}
		m->frame_cycle -= FRAME_CYCLES;

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