# mini-casino

Mini gaming console built on an **ATmega128L** (STK300 board, ~4.19 MHz), programmed entirely in **AVR assembly**. Developed for the EPFL MICRO210/EE208 (Microcontrollers and Digital Systems) course.

The console runs three mini-games controlled entirely by an IR remote, with an LCD display, a piezo buzzer for sound/music, and persistent storage of credits and high scores across power cycles.

## Games

- **Slot Machine** — bet credits, spin three reels, win on matching symbols (cherry, lemon, bar, dollar, star, seven), jackpot on triple sevens.
- **Cyclo Jackpot** — a spinning needle animation on the LCD; stop it inside the target zone to win.
- **F1 Reaction Test** — classic F1-style light sequence (5 lights); react as fast as possible after they go out. Best time is saved, no betting involved.

## Hardware

| Component | Role |
|---|---|
| ATmega128L (STK300) | Main MCU, ~4.19 MHz |
| IR receiver + remote (RC5 protocol) | Player input (only required peripheral for control) |
| HD44780 2×16 LCD | Game display |
| I²C EEPROM (24LC256/M24C64) | External persistence: credits, high score, game history |
| ATmega128 internal EEPROM | Persistence: best reaction time |
| Piezo buzzer (Timer3 PWM) | Sound effects and background music |

## Controls (RC5 remote)

| Button | Action |
|---|---|
| `CH+` / `CH-` | Switch between mini-games |
| `0`–`9` | Enter/adjust bet amount |
| `OK` | Confirm / spin / stop |

## Project structure

| File | Purpose |
|---|---|
| `main.asm` | Entry point, reset/init, main loop |
| `fsm.asm` | Main finite-state machine (boot, idle, betting, spinning, result, game over, history, per-game states) |
| `game_slot.asm` | Slot machine logic |
| `game_cyclo.asm` | Cyclo Jackpot logic |
| `game_reaction.asm` | F1 reaction test logic |
| `display.asm` | LCD rendering helpers |
| `lcd.asm` | Low-level HD44780 driver |
| `buzzer.asm` | Timer3-based tone/music playback |
| `nvm.asm` | External I²C EEPROM read/write (credits, high score, history) |
| `twi.asm` | I²C (TWI) driver |
| `printf.asm` | Formatted output helpers for the LCD |
| `macros.asm` | Shared assembler macros |
| `definitions.asm` | Project-wide constants (states, EEPROM addresses, RC5 key codes, note periods, etc.) |
| `m128def.inc` | ATmega128 register/bit definitions |

## Persistence

- **External I²C EEPROM**: magic value check, high score, current credits, and a rolling game history (head/count + entries), with checksum.
- **Internal EEPROM**: best F1 reaction time (in 50 ms ticks).

Credits are capped at 9999 and persist across resets.

## Building

Assemble with **Atmel Studio** (AVRASM2) or **avra**:

```bash
avra main.asm
```

Flash the resulting `.hex` to the ATmega128L on the STK300 board.
