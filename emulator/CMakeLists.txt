cmake_minimum_required(VERSION 3.8)

project(emulator)

option(SDL_SHARED "" false)
option(SDL_STATIC "" true)
add_subdirectory(sdl2)

set(Z80EX_STATIC_ONLY true)
add_subdirectory(z80ex)

add_executable(emulator emulator.cpp)

set_target_properties(
	emulator PROPERTIES
	CXX_STANDARD 20
	RUNTIME_OUTPUT_DIRECTORY ${PROJECT_SOURCE_DIR}
	RUNTIME_OUTPUT_DIRECTORY_DEBUG ${PROJECT_SOURCE_DIR}
	RUNTIME_OUTPUT_DIRECTORY_RELEASE ${PROJECT_SOURCE_DIR})

target_include_directories(
	emulator
	PRIVATE z80ex/include)

target_link_libraries(emulator
	PRIVATE SDL2::SDL2-static
	PRIVATE z80ex-static)


