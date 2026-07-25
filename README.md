# mini-casino

![Language](https://img.shields.io/badge/language-AVR%20Assembly-blue)
![Target](https://img.shields.io/badge/MCU-ATmega128L-orange)
![Board](https://img.shields.io/badge/board-STK300-lightgrey)

A three-in-one arcade console built from scratch in **AVR assembly** for the **ATmega128L**. The player selects and controls every game with an infrared remote (RC5 protocol); an LCD renders game state, a piezo buzzer provides sound effects and background music, and credits/high scores survive power cycles via external and internal EEPROM.

Developed for the EPFL **MICRO210 / EE208** course (Microcontrollers and Digital Systems).

## Contents

- [Overview](#overview)
- [Games](#games)
- [Hardware](#hardware)
- [Controls](#controls-rc5-remote)
- [Architecture](#architecture)
- [Repository structure](#repository-structure)
- [Persistence](#persistence)
- [Building and flashing](#building-and-flashing)
- [Course context](#course-context)

## Overview

The system is driven by a central finite-state machine (`fsm.asm`) that manages boot, idle, betting, spin/play, result, game-over, and history states, and dispatches to one of three game modules. All peripherals (LCD, I²C EEPROM, buzzer, IR receiver) are driven by hand-written, interrupt-based drivers — no vendor HAL or C runtime is used.

## Games

| Game | Description |
|---|---|
| **Slot Machine** | Wager credits and spin three reels. Matching symbols (cherry, lemon, bar, dollar, star, seven) pay out; triple sevens pays the jackpot. |
| **Cyclo Jackpot** | A needle sweeps across the LCD; stop it inside the target window to win. |
| **F1 Reaction Test** | A five-light start sequence in the style of an F1 grid start; react as fast as possible once the lights go out. No betting — the best time is recorded. |

## Hardware

| Component | Role |
|---|---|
| ATmega128L, STK300 board (~4.19 MHz) | Main MCU |
| IR receiver + remote control (RC5 protocol) | Sole player input device |
| HD44780-compatible 2×16 character LCD | Game display |
| I²C EEPROM (24LC256 / M24C64) | External persistence: credits, high score, game history |
| ATmega128 internal EEPROM | Persistence: best F1 reaction time |
| Piezo buzzer, driven from Timer3 | Sound effects and background music |

## Controls (RC5 remote)

| Button | Action |
|---|---|
| `CH+` / `CH-` | Switch between mini-games |
| `0`–`9` | Enter or adjust the bet amount |
| `OK` | Confirm / spin / stop |

## Architecture

```
IR remote ──▶ RC5 decode ──▶ FSM (fsm.asm) ──▶ game_slot.asm
                                 │              game_cyclo.asm
                                 │              game_reaction.asm
                                 ▼
                    display.asm / lcd.asm ──▶ LCD
                    buzzer.asm ──▶ piezo buzzer
                    nvm.asm / twi.asm ──▶ external I²C EEPROM
                    internal EEPROM ──▶ best reaction time
```

## Repository structure

| File | Purpose |
|---|---|
| `main.asm` | Entry point: reset vector, initialization, main loop |
| `fsm.asm` | Main finite-state machine (boot, idle, betting, spin, result, game over, history, per-game states) |
| `game_slot.asm` | Slot Machine game logic |
| `game_cyclo.asm` | Cyclo Jackpot game logic |
| `game_reaction.asm` | F1 Reaction Test game logic |
| `display.asm` | LCD rendering helpers, per-screen layouts |
| `lcd.asm` | Low-level HD44780 driver |
| `buzzer.asm` | Timer3-based tone and music playback |
| `nvm.asm` | External I²C EEPROM read/write (credits, high score, history) |
| `twi.asm` | I²C (TWI) bus driver |
| `printf.asm` | Formatted output helpers for the LCD |
| `macros.asm` | Shared assembler macros |
| `definitions.asm` | Project-wide constants: FSM states, EEPROM addresses, RC5 key codes, note periods |
| `m128def.inc` | ATmega128 register and bit definitions |

## Persistence

- **External I²C EEPROM** — a magic value guards against reading uninitialized memory; stores high score, current credits, and a rolling, checksummed history of past games (head pointer + count).
- **Internal ATmega128 EEPROM** — stores the best F1 reaction time, in 50 ms ticks.

Credits are capped at 9999 and persist across resets and power loss.

## Building and flashing

Assemble with **Atmel Studio** (AVRASM2) or the open-source **avra** assembler:

```bash
avra main.asm
```

Flash the resulting `.hex` file to the ATmega128L on the STK300 board using your preferred programmer (e.g. AVR Dragon, STK500).

## Course context

Built for EPFL MICRO210 / EE208, Group 10. Deliverables for the project included the source code in this repository, a technical report, and a short demo video.
