


;  === SECTION 1 : INCLUDES BIBLIOTHEQUES===

.include "m128def.inc"
.include "definitions.asm"
.include "macros.asm"


; === SECTION 2 : CONSTANTES GLOBALES ===

; <<<Horloge et timings IR >>>
.equ    F_CPU_HZ        = 4186000
.equ    T1_US           = 1778          ; demi-periode RC5 en µs
.equ    T1_QUARTER_US   = 444           ; quart de periode RC5

; <<< EEPROM I2C externe (24LC256, adresse esclave 0x50) >>>
.equ    EEPROM_SLA_W    = 0b10100000
.equ    EEPROM_SLA_R    = 0b10100001
.equ    EE_MAGIC_ADDR       = 0x0000   ; magic word 0xC0DE (2 octets)
.equ    EE_HIGHSCORE_ADDR   = 0x0002   ; highscore 16 bits (2 octets)
.equ    EE_CREDIT_ADDR      = 0x0006   ; credits 16 bits (2 octets)
.equ    EE_HIST_HEAD_ADDR   = 0x0008   ; tete historique (1 octet)

; <<< EEPROM interne ATmega128>>>
.equ    IEE_RT_BEST_ADDR    = 0x0000   ; meilleur temps reaction (1 octet, ticks 50ms)

; <<< Codes touches RC5 (telecommande Vivanco) >>>
.equ    RC5_KEY_0       = 0x00
.equ    RC5_KEY_1       = 0x01
.equ    RC5_KEY_2       = 0x02
.equ    RC5_KEY_3       = 0x03
.equ    RC5_KEY_4       = 0x04
.equ    RC5_KEY_5       = 0x05
.equ    RC5_KEY_6       = 0x06
.equ    RC5_KEY_7       = 0x07
.equ    RC5_KEY_8       = 0x08
.equ    RC5_KEY_9       = 0x09
.equ    RC5_KEY_POWER   = 0x0C
.equ    RC5_KEY_MUTE    = 0x0D
.equ    RC5_KEY_VOLP    = 0x10
.equ    RC5_KEY_VOLM    = 0x11
.equ    RC5_KEY_CHP     = 0x20         ; changement de jeu (sens +)
.equ    RC5_KEY_CHM     = 0x21         ; changement de jeu (sens -)
.equ    RC5_KEY_OK      = 0x38

; <<< Etats de la FSM principale >>>
.equ    ST_BOOT         = 0
.equ    ST_IDLE         = 1
.equ    ST_BETTING      = 2
.equ    ST_SPINNING     = 3
.equ    ST_RESULT       = 4
.equ    ST_GAMEOVER     = 5
.equ    ST_HISTORY      = 6
.equ    ST_CYCLO        = 7
.equ    ST_REACTION     = 8

; <<< Symboles slot >>>
.equ    SYM_CHERRY      = 0
.equ    SYM_LEMON       = 1
.equ    SYM_BAR         = 2
.equ    SYM_DOLLAR      = 3
.equ    SYM_STAR        = 4
.equ    SYM_SEVEN       = 5
.equ    NUM_SYMBOLS     = 6

; <<< Limites de credit >>>
.equ    MAX_BET_LOW     = 100
.equ    MAX_CREDIT_L    = 0x0F
.equ    MAX_CREDIT_H    = 0x27          ; plafond = 9999

; <<<Notes du buzzer (periodes pour Timer3, prescaler /64, 4MHz) >>>
.equ    NOTE_C5         = 60
.equ    NOTE_D5         = 53
.equ    NOTE_E5         = 47
.equ    NOTE_F5         = 44
.equ    NOTE_G5         = 39
.equ    NOTE_A5         = 35
.equ    NOTE_B5         = 31
.equ    NOTE_C6         = 29
.equ    NOTE_E6         = 23
.equ    NOTE_G6         = 19
.equ    NOTE_REST       = 0             ; silence
.equ    MUSIC_END       = 0xFF          ; fin de table, reboucle si loop=1
.equ    MUSIC_STOP      = 0xFE          ; fin de table, arret

; <<<Jeu Cyclo >>>
.equ    CYCLO_TARGET_LO = 22            ; zone jackpot [22..25]
.equ    CYCLO_TARGET_HI = 25
.equ    CYCLO_WIN_LO    = 18            ; zone gain simple [18..28] hors jackpot
.equ    CYCLO_WIN_HI    = 28
.equ    CYCLO_NSTEPS    = 48            ; nombre de positions sur le cadran
.equ    CYCLO_ANTE      = 10            ; mise fixe pour jouer

.equ    CY_ST_IDLE      = 0
.equ    CY_ST_SPIN      = 1
.equ    CY_ST_WIN       = 2
.equ    CY_ST_LOSE      = 3
.equ    CY_ST_JP        = 4

; <<< Jeu Reaction (feux F1) >>>
.equ    RT_ST_IDLE      = 0
.equ    RT_ST_LIGHTS    = 1             ; sequence allumage 5 feux
.equ    RT_ST_WAIT      = 2             ; attente aleatoire avant GO
.equ    RT_ST_GO        = 3             ; mesure du temps de reaction
.equ    RT_MIN_WAIT     = 20            ; attente minimum apres feux (ticks 50ms = 1s)
.equ    RT_MAX_WAIT_RND = 32            ; aleatoire supplementaire (0..31 ticks)
.equ    RT_TIMEOUT      = 100           ; forfait apres 5 secondes

; <<< Ports peripheriques >>>
.equ    IR_PIN          = PINE
.equ    IR_BIT          = 7             ; recepteur IR sur PE7
.equ    BUZZER_PORT     = PORTE
.equ    BUZZER_DDR      = DDRE
.equ    BUZZER_BIT      = 2             ; buzzer sur PE2
.equ    CYCLO_BTN_PORT  = PIND
.equ    CYCLO_BTN_BIT   = 4             ; bouton cyclo sur PD4
.equ    HEARTBEAT_BIT   = 0             ; LED de vie sur PB0


;  === SECTION 3 : ALLOCATION SRAM ===

.dseg
.org SRAM_START

; <<< FSM et credits >>>
g_state:        .byte 1     ; etat FSM principal (ST_*)
g_prev_state:   .byte 1     ; etat precedent (pour retour depuis minijeux)
g_substate:     .byte 1     ; sous-etat generique
g_credit_l:     .byte 1     ; credits (octet bas)
g_credit_h:     .byte 1     ; credits (octet haut)
g_highscore_l:  .byte 1     ; meilleur score (octet bas)
g_highscore_h:  .byte 1     ; meilleur score (octet haut)

; <<< Machine a sous >>>>
g_bet_l:        .byte 1     ; mise courante (octet bas)
g_bet_h:        .byte 1     ; mise courante (octet haut)
g_reels:        .byte 3     ; symboles des 3 rouleaux (SYM_*)
g_reel_speed:   .byte 3     ; compteurs de decompte par rouleau
g_reel_active:  .byte 3     ; 1 = rouleau en cours, 0 = arrete

; <<< Temporisation et PRNG>>>
g_anim_tick:    .byte 1     ; compteur incrementé chaque 50ms (animation)
g_lfsr_l:       .byte 1     ; LFSR 16 bits (octet bas)
g_lfsr_h:       .byte 1     ; LFSR 16 bits (octet haut)

; <<< Historique >>>
g_hist_idx:     .byte 1     ; index dans l'historique EEPROM

; <<<< Interface IR >>>
f_ir_ready:     .byte 1     ; flag : une trame RC5 est disponible
f_ir_cmd:       .byte 1     ; commande RC5 decodee (6 bits)
f_tick_50ms:    .byte 1     ; compteur de ticks 50ms en attente
g_last_rc5_raw: .byte 1     ; derniere trame brute (anti-rebond)
ir_bit_count:   .byte 1     ; (reserve)
ir_data_l:      .byte 1     ; (reserve)
ir_data_h:      .byte 1     ; (reserve)
ir_state:       .byte 1     ; etat decodeur IR

; <<< Moteur musique >>>
g_music_idx:     .byte 1    ; index dans la table de notes
g_music_ticks:   .byte 1    ; ticks restants pour la note courante
g_music_table_l: .byte 1    ; pointeur table de musique (octet bas)
g_music_table_h: .byte 1    ; pointeur table de musique (octet haut)
g_music_loop:    .byte 1    ; 1 = lecture en boucle, 0 = lecture unique

; << Jeu Cyclo >>>
g_cyclo_pos:      .byte 1   ; position aiguille [0..CYCLO_NSTEPS-1]
g_cyclo_run:      .byte 1   ; 1 = aiguille en rotation
g_cyclo_substate: .byte 1   ; sous-etat (CY_ST_*)
g_cyclo_btn_prev: .byte 1   ; etat precedent bouton PD4 (debounce)

; <<<Jeu Reaction >>>>
g_rt_substate:   .byte 1    ; sous-etat (RT_ST_*)
g_rt_timer:      .byte 1    ; compteur multi-usage (feux / temps reaction)
g_rt_best:       .byte 1    ; meilleur temps (ticks 50ms), 0xFF = aucun record
g_rt_beep_ctr:   .byte 1    ; ticks depuis le dernier feu allume

.cseg


; === SECTION 4 : TABLE DES VECTEURS D'INTERRUPTION ===

.org 0
    jmp     reset_entry

.org INT7addr
    jmp     isr_int7_ir         ; INT7 : flanc descendant sur PE7 (debut trame RC5)

.org OC0addr
    reti                        ; Timer0 : vecteur de securite (interrupt desactive)

.org OC1Aaddr
    jmp     isr_timer1_compa    ; Timer1 : tick 50ms

.org OC3Aaddr
    jmp     isr_timer3_compa    ; Timer3 : toggle buzzer (generation son)


; === SECTION 5 : POINT D'ENTREE ET INCLUDES MODULES ===

.org 0x0040
reset_entry:
    jmp     reset

; Bibliotheques du cours (non modifiees)
.include "lcd.asm"
.include "printf.asm"
.include "twi.asm"

; Modules du projet
.include "nvm.asm"
.include "buzzer.asm"
.include "display.asm"
.include "game_slot.asm"
.include "game_cyclo.asm"
.include "game_reaction.asm"
.include "fsm.asm"


;  === SECTION 6 : RESET ET INITIALISATION ===

reset:
    LDSP    RAMEND
    call   ports_init
    call   timers_init
    call   extint_init
    call   LCD_init
    WAIT_MS 50
    call   twi_init
    call   sram_init
    call   nvm_init
    call   iee_init_best
    sei
    call   display_splash
    WAIT_MS 800
    ldi     w, ST_IDLE
    sts     g_state, w
    sts     g_prev_state, w
    rjmp    main_loop


; <<<ports_init  --  Configure les directions et etats initiaux des ports >>>

ports_init:
    OUTI    DDRA,  0xFF         ; PA : sorties (inactif)
    OUTI    PORTA, 0x00
    OUTI    DDRC,  0xC0         ; PC6,PC7 : sorties LCD
    OUTI    PORTC, 0x00
    OUTI    DDRB,  0xFF         ; PB : sorties (LEDs, heartbeat PB0)
    OUTI    PORTB, 0xFF         ; LEDs eteintes (actif bas)
    ; PD4 = entree bouton cyclo, reste = sorties
    in      w, DDRD
    ori     w, 0x80
    andi    w, low(~(1<<CYCLO_BTN_BIT))
    out     DDRD, w
    in      w, PORTD
    ori     w, (1<<CYCLO_BTN_BIT)   ; pull-up interne PD4
    out     PORTD, w
    ; <<<PE7 = entree IR, PE2 = sortie buzzer>>>
    in      w, DDRE
    andi    w, low(~(1<<IR_BIT))
    ori     w, (1<<BUZZER_BIT)
    out     DDRE, w
    in      w, PORTE
    ori     w, (1<<IR_BIT)          ; pull-up interne PE7
    andi    w, low(~(1<<BUZZER_BIT))     ; buzzer inactif
    out     PORTE, w
    ret


timers_init:
    OUTI    TCCR0, (1<<WGM01)|(1<<CS02)
    OUTI    OCR0,  255
    OUTI    TCCR1A, 0x00
    OUTI    TCCR1B, (1<<WGM12)|(1<<CS12)
    ldi     w, high(781)
    out     OCR1AH, w
    ldi     w, low(781)
    out     OCR1AL, w
    ldi     w, (1<<OCIE1A)          ; seul OCIE1A active (Timer1)
    out     TIMSK, w
    OUTI    TCCR2, (1<<CS22)|(1<<CS21)|(1<<CS20)
    OUTI    TCNT2, 0
    ; <<<Timer3 : CTC sans prescaler au demarrage (buzzer silencieux)>>>
    ldi     w, (1<<WGM32)
    sts     TCCR3B, w
    clr     w
    sts     TCCR3A, w
    sts     TCCR3C, w
    sts     OCR3AH, w
    sts     OCR3AL, w
    lds     w, ETIMSK
    ori     w, (1<<OCIE3A)
    sts     ETIMSK, w
    ret


;<<<< extint_init  --  Configure INT7 sur flanc descendant (debut trame RC5)>>>

extint_init:
    lds     w, EICRB
    andi    w, 0x3F
    ori     w, (1<<ISC71)           ; flanc descendant sur INT7
    sts     EICRB, w
    in      w, EIMSK
    ori     w, (1<<INT7)
    out     EIMSK, w
    ret


;<<< sram_init  --  Met a zero toute la zone de variables SRAM du projet>>>

sram_init:
    clr     r1
    ldi     XL, low(g_state)
    ldi     XH, high(g_state)
    ldi     w, 48
sram_init_loop:
    st      X+, r1
    dec     w
    brne    sram_init_loop
    ret


; === SECTION 7 : ISR -- INT7 (decodeur RC5 inline) ===
; Declenche sur flanc descendant de PE7. Echantillonne 14 bits a T1_US/2.
; Resultat : f_ir_cmd = commande 6 bits, f_ir_ready = 1 

isr_int7_ir:
    push    w
    in      w, SREG
    push    w
    push    a0
    push    b0
    push    b1
    push    b2
    WAIT_US (1860 / 4)              ; attente quart de periode (centre du bit start)
    CLR2    b1, b0
    ldi     b2, 14                  ; 14 bits a lire (RC5 : 2 start + 1 toggle + 5 adresse + 6 commande)
rc5_read_loop:
    P2C     PINE, 7                 ; echantillonne PE7 -> Carry
    ROL2    b1, b0                  ; shift dans b1:b0
    WAIT_US (1860 - 4)              ; attend la prochaine periode
    DJNZ    b2, rc5_read_loop
    bst     b1, 3                   ; extrait le bit de toggle
    com     b0
    andi    b0, 0x3F                ; isole les 6 bits de commande
    bld     b0, 7                   ; reinsere le toggle en bit 7
    sts     f_ir_cmd,   b0
    ldi     a0, 1
    sts     f_ir_ready, a0
    ldi     w, (1<<INTF7)
    out     EIFR, w                 ; efface le flag INT7
    pop     b2
    pop     b1
    pop     b0
    pop     a0
    pop     w
    out     SREG, w
    pop     w
    reti


;=== SECTION 8 : ISR -- Timer1 CompA (tick 50ms) ===
; Incremente g_anim_tick (animation), bascule la LED heartbeat toutes les 800ms,
; et pose un jeton dans f_tick_50ms pour la boucle principale.

isr_timer1_compa:
    push    w
    in      w, SREG
    push    w
    push    a0
    lds     a0, g_anim_tick
    inc     a0
    sts     g_anim_tick, a0
    andi    a0, 0x0F
    brne    isr_t1_skip_hb
    in      a0, PORTB               ; bascule PB0 (heartbeat LED)
    ldi     w, (1<<HEARTBEAT_BIT)
    eor     a0, w
    out     PORTB, a0
isr_t1_skip_hb:
    lds     a0, f_tick_50ms
    inc     a0
    sts     f_tick_50ms, a0
    pop     a0
    pop     w
    out     SREG, w
    pop     w
    reti


; === SECTION 9 : ISR -- Timer3 CompA (generation buzzer par toggle) ===
; Appele a chaque demi-periode de la note courante -> bascule PE2.

isr_timer3_compa:
    push    w
    in      w, SREG
    push    w
    push    a0
    in      a0, BUZZER_PORT
    ldi     w, (1<<BUZZER_BIT)
    eor     a0, w
    out     BUZZER_PORT, a0
    pop     a0
    pop     w
    out     SREG, w
    pop     w
    reti


; === SECTION 10 : BOUCLE PRINCIPALE ===
; Traite les evenements IR et les ticks 50ms dans l'ordre de priorite.

main_loop:
    ; <<< Evenement IR disponible ? >>>
    lds     w, f_ir_ready
    tst     w
    breq    ml_check_tick
    clr     w
    sts     f_ir_ready, w
    call   prng_seed               ; reseed a chaque touche -> meilleure entropie
    call   handle_ir_cmd
    ldi     w, (1<<INTF7)
    out     EIFR, w                 ; efface tout flanc parasite
    clr     w
    sts     ir_state, w

ml_check_tick:
    ; <<<Tick 50ms disponible ? >>>
    lds     w, f_tick_50ms
    tst     w
    breq    ml_loop_end
    dec     w
    sts     f_tick_50ms, w
    call   handle_tick
ml_loop_end:
    jmp     main_loop


;<<< SECTION 11 : TABLES EN FLASH >>
SYMBOL_TABLE:
    .db "CL=$*7"                    ; caracteres des 6 symboles (indices SYM_*)

PRNG_SYMBOL_TABLE:
    .db SYM_SEVEN,  SYM_CHERRY, SYM_SEVEN, SYM_LEMON
    .db SYM_CHERRY, SYM_BAR,    SYM_DOLLAR, SYM_STAR

SPINNER_TABLE:
    .db '|', '/', '-', 0x5C        ; caracteres d'animation (0x5C = '\')

; <<< Musique de fond (jouee en boucle pendant le spin) >>>
MUSIC_TABLE:
    .db NOTE_C5, 4,  NOTE_E5, 4,  NOTE_G5, 4,  NOTE_C6, 4
    .db NOTE_E6, 8,  NOTE_C6, 4,  NOTE_G5, 4,  NOTE_E5, 8
    .db NOTE_REST,2, NOTE_E5, 4,  NOTE_G5, 4,  NOTE_C6, 4
    .db NOTE_E6, 4,  NOTE_G6, 8,  NOTE_E6, 4,  NOTE_C6, 8
    .db NOTE_REST,4
    .db MUSIC_END, 0

; <<< Jingles resultat (lecture unique) >>>
MUSIC_WIN_JINGLE:
    .db NOTE_C5, 3,  NOTE_E5, 3,  NOTE_G5, 3,  NOTE_C6, 4
    .db NOTE_E6, 8,  NOTE_REST, 2
    .db MUSIC_STOP, 0

MUSIC_LOSE_JINGLE:
    .db NOTE_G5, 4,  NOTE_E5, 4,  NOTE_D5, 4,  NOTE_C5, 10
    .db NOTE_REST, 2
    .db MUSIC_STOP, 0

MUSIC_JACKPOT_JINGLE:
    .db NOTE_C6, 2,  NOTE_E6, 2,  NOTE_G6, 2,  NOTE_E6, 2
    .db NOTE_C6, 2,  NOTE_E6, 2,  NOTE_G6, 2,  NOTE_E6, 2
    .db NOTE_C6, 2,  NOTE_E6, 2,  NOTE_G6, 8,  NOTE_REST, 2
    .db NOTE_E6, 2,  NOTE_G6, 2,  NOTE_C6, 8
    .db NOTE_REST, 2
    .db MUSIC_STOP, 0

MUSIC_NEWBEST_JINGLE:
    .db NOTE_C5, 2,  NOTE_E5, 2,  NOTE_G5, 2,  NOTE_C6, 2
    .db NOTE_E6, 2,  NOTE_G6, 2,  NOTE_C6, 2,  NOTE_G6, 2
    .db NOTE_E6, 2,  NOTE_C6, 2,  NOTE_G6, 6,  NOTE_REST, 2
    .db MUSIC_STOP, 0
