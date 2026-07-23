; Toutes les routines d'affichage du projet sont ici.
; Elles utilisent LCD_clear, LCD_home, LCD_putc, PRINTF (lcd.asm / printf.asm).
; UTILITAIRE : print_dec16
; Affiche un nombre 16 bits sur le LCD en decimal sans zeros de tete.

print_dec16:
    push    YL
    push    b0
    push    b1
    clr     YL                      ; YL = nombre de chiffres empiles
pd16_div_outer:
    clr     b0
    ldi     b1, 16
pd16_div_bit:
    lsl     a0
    rol     a1
    rol     b0
    cpi     b0, 10
    brlo    pd16_div_skip
    subi    b0, 10
    inc     a0
pd16_div_skip:
    dec     b1
    brne    pd16_div_bit
    subi    b0, -(('0'))            ; convertit en ASCII
    push    b0
    inc     YL
    mov     b0, a0
    or      b0, a1
    brne    pd16_div_outer
pd16_print_loop:
    pop     a0
    call   LCD_putc
    dec     YL
    brne    pd16_print_loop
    pop     b1
    pop     b0
    pop     YL
    ret

; ==============================================================================
; UTILITAIRE : sym_to_char
; Convertit un indice de symbole slot (SYM_*) en caractere ASCII.
; in : a0 = indice symbole [0..5]
; out : a0 = caractere ASCII
; ==============================================================================
sym_to_char:
    ldi     ZL, low(SYMBOL_TABLE * 2)
    ldi     ZH, high(SYMBOL_TABLE * 2)
    add     ZL, a0
    clr     w
    adc     ZH, w
    lpm     a0, Z
    ret


;=== ECRANS MACHINE A SOUS ===


display_splash:
    call   LCD_clear
    call   LCD_home
    PRINTF  LCD
    .db "SlotMega128 v3 ", LF, "  Press digit  ", 0
    ret

display_idle:
    call   LCD_clear
    call   LCD_home
    PRINTF  LCD
    .db "CRED:", 0
    lds     a0, g_credit_l
    lds     a1, g_credit_h
    call   print_dec16
    PRINTF  LCD
    .db "      ", LF, "HI  :", 0, 0
    lds     a0, g_highscore_l
    lds     a1, g_highscore_h
    call   print_dec16
    PRINTF  LCD
    .db "      ", 0, 0
    ret

display_betting:
    call   LCD_clear
    call   LCD_home
    PRINTF  LCD
    .db "CRED:", 0
    lds     a0, g_credit_l
    lds     a1, g_credit_h
    call   print_dec16
    PRINTF  LCD
    .db "    ", LF, "BET :", 0, 0
    lds     a0, g_bet_l
    lds     a1, g_bet_h
    call   print_dec16
    PRINTF  LCD
    .db " OK?", 0, 0
    ret

;=== display_reels Affiche les 3 rouleaux sous la forme [ X | X | X ] ===
display_reels:
    call   LCD_clear
    WAIT_MS 2
    ldi     a0, '['
    call   LCD_putc
    ldi     a0, ' '
    call   LCD_putc
    lds     a0, g_reels
    call   sym_to_char
    call   LCD_putc
    ldi     a0, ' '
    call   LCD_putc
    ldi     a0, '|'
    call   LCD_putc
    ldi     a0, ' '
    call   LCD_putc
    lds     a0, g_reels+1
    call   sym_to_char
    call   LCD_putc
    ldi     a0, ' '
    call   LCD_putc
    ldi     a0, '|'
    call   LCD_putc
    ldi     a0, ' '
    call   LCD_putc
    lds     a0, g_reels+2
    call   sym_to_char
    call   LCD_putc
    ldi     a0, ' '
    call   LCD_putc
    ldi     a0, ']'
    call   LCD_putc
    ret

display_result_win:
    call   LCD_clear
    call   LCD_home
    PRINTF  LCD
    .db "  *** WIN ***  ", LF, "  +", 0
    lds     a0, g_bet_l
    lds     a1, g_bet_h
    lsl     a0                      ; gain = mise x2
    rol     a1
    call   print_dec16
    PRINTF  LCD
    .db " credits!  ", 0
    ret

display_result_lose:
    call   LCD_clear
    call   LCD_home
    PRINTF  LCD
    .db "   no luck     ", LF, "  Try again !  ", 0
    ret

display_jackpot:
    call   LCD_clear
    call   LCD_home
    PRINTF  LCD
    .db " *** JACKPOT***", LF, "** 7-7-7  x100*", 0
    ret

; <<< display_jackpot_anim Un flash rapide avant l'affichage final >>>
display_jackpot_anim:
    call   display_jackpot
    WAIT_MS 80
    call   LCD_clear
    WAIT_MS 40
    call   display_jackpot
    ret

display_gameover:
    call   LCD_clear
    call   LCD_home
    PRINTF  LCD
    .db "  GAME OVER!  ", LF, "  POWER=+100  ", 0
    ret

display_mute_reset:
    call   LCD_clear
    call   LCD_home
    PRINTF  LCD
    .db "  FULL RESET!  ", LF, "CR:1000 HS:0   ", 0
    ret

;=== ECRANS JEU CYCLO ===


;<<< display_cyclo_init  --  Ecran d'accueil du jeu Cyclo >>>
display_cyclo_init:
    call   stop_music
    clr     w
    sts     g_cyclo_run,      w
    sts     g_cyclo_substate, w
    sts     g_cyclo_btn_prev, w
    call   LCD_clear
    call   LCD_home
    PRINTF  LCD
    .db " Cyclo Jackpot ", LF, "OK/btn:Ante=10 ", 0
    ret

;<<< display_cyclo_spin  --  Ligne 1 : credits + indicateur spin, ligne 2 : barre de position >>>
display_cyclo_spin:
    call   LCD_clear
    call   LCD_home
    PRINTF  LCD
    .db "CRED:", 0
    lds     a0, g_credit_l
    lds     a1, g_credit_h
    call   print_dec16
    PRINTF  LCD
    .db "  spin>>", LF, 0
    call   display_cyclo_bar
    ret

;<<< display_cyclo_bar  --  Barre 16 cases : '#' = aiguille, '*' = jackpot, '+' = gain
; La position g_cyclo_pos [0..47] est mappee sur 16 cases. >>>
display_cyclo_bar:
    push    b0
    push    b1
    lds     b0, g_cyclo_pos
    clr     b1
dcb_div3:
    cpi     b0, 3
    brlo    dcb_div3_end
    subi    b0, 3
    inc     b1
    rjmp    dcb_div3
dcb_div3_end:
    clr     b0
dcb_loop:
    cp      b0, b1
    brne    dcb_not_cursor
    ldi     a0, '#'             ; aiguille courante
    rjmp    dcb_emit
dcb_not_cursor:
    cpi     b0, 7
    breq    dcb_jp
    cpi     b0, 8
    breq    dcb_jp
    cpi     b0, 6
    breq    dcb_win_zone
    cpi     b0, 9
    breq    dcb_win_zone
    ldi     a0, '.'
    rjmp    dcb_emit
dcb_jp:
    ldi     a0, '*'             ; zone jackpot
    rjmp    dcb_emit
dcb_win_zone:
    ldi     a0, '+'             ; zone gain simple
dcb_emit:
    call   LCD_putc
    inc     b0
    cpi     b0, 16
    brlo    dcb_loop
    pop     b1
    pop     b0
    ret

display_cyclo_result_win:
    call   LCD_clear
    call   LCD_home
    PRINTF  LCD
    .db " CYCLO  WIN !  ", LF, "  +30 credits  ", 0
    ret

display_cyclo_result_lose:
    call   LCD_clear
    call   LCD_home
    PRINTF  LCD
    .db " CYCLO  miss   ", LF, "  -10 credits  ", 0
    ret

display_cyclo_result_jp:
    call   LCD_clear
    call   LCD_home
    PRINTF  LCD
    .db "***JACKPOT*** ", LF, "* +1000 credits", 0, 0
    ret

;=== ECRANS JEU REACTION (feux F1) ===

display_reaction_idle:
    call   LCD_clear
    call   LCD_home
    PRINTF  LCD
    .db " REACTION GAME ", LF, "  Press OK:Go! ", 0
    ret

;<<< display_reaction_wait  --  "Get Ready" avec spinner anime >>>
display_reaction_wait:
    call   LCD_clear
    call   LCD_home
    PRINTF  LCD
    .db " REACTION GAME ", LF, 0, 0
    PRINTF  LCD
    .db " Get Ready!   ", 0, 0
    lds     a0, g_anim_tick
    andi    a0, 0x03
    ldi     ZL, low(SPINNER_TABLE * 2)
    ldi     ZH, high(SPINNER_TABLE * 2)
    add     ZL, a0
    clr     w
    adc     ZH, w
    lpm     a0, Z
    call   LCD_putc
    ret

display_reaction_go:
    call   LCD_clear
    call   LCD_home
    PRINTF  LCD
    .db " REACTION GAME ", LF, " >>> PRESS! <<<", 0
    ret

;<<< display_reaction_result  --  Temps courant et meilleur temps (en ms) >>>
display_reaction_result:
    call   LCD_clear
    call   LCD_home
    PRINTF  LCD
    .db " TIME:", 0, 0
    lds     a0, g_rt_timer
    ldi     b0, 50
    mul     a0, b0              ; ticks * 50 = temps en ms
    mov     a0, r0
    mov     a1, r1
    clr     r1
    call   print_dec16
    PRINTF  LCD
    .db "ms ", LF, " BEST:", 0, 0
    lds     a0, g_rt_best
    ldi     b0, 50
    mul     a0, b0
    mov     a0, r0
    mov     a1, r1
    clr     r1
    call   print_dec16
    PRINTF  LCD
    .db "ms ", 0
    ret

display_reaction_newbest:
    call   LCD_clear
    call   LCD_home
    PRINTF  LCD
    .db " ** NEW BEST **", LF, " TIME:", 0, 0
    lds     a0, g_rt_timer
    ldi     b0, 50
    mul     a0, b0
    mov     a0, r0
    mov     a1, r1
    clr     r1
    call   print_dec16
    PRINTF  LCD
    .db "ms !!  ", 0
    ret

display_reaction_timeout:
    call   LCD_clear
    call   LCD_home
    PRINTF  LCD
    .db " REACTION GAME ", LF, "  TOO SLOW!!!  ", 0
    ret

display_reaction_falsestart:
    call   LCD_clear
    call   LCD_home
    PRINTF  LCD
    .db " REACTION GAME ", LF, " FALSE START!  ", 0
    ret

;<<< display_reaction_lights  --  Affiche les feux F1 sur la ligne 2
; in : a0 = nombre de feux allumes [0..5]
; Ligne 2 : "[*][*][*][*][*]" >>>

display_reaction_lights:
    push    b0
    push    b1
    mov     b1, a0              ; b1 = nombre de feux a allumer
    call   LCD_clear
    call   LCD_home
    PRINTF  LCD
    .db " F1 START LIGHTS", LF, 0
    clr     b0                  ; b0 = index feu courant [0..4]
drl_loop:
    cpi     b0, 5
    breq    drl_end
    ldi     a0, '['
    call   LCD_putc
    cp      b0, b1
    brlo    drl_on
    ldi     a0, ' '             ; feu eteint
    rjmp    drl_mid
drl_on:
    ldi     a0, '*'             ; feu allume
drl_mid:
    call   LCD_putc
    ldi     a0, ']'
    call   LCD_putc
    inc     b0
    rjmp    drl_loop
drl_end:
    ldi     a0, ' '             ; 5*3 = 15 chars + 1 espace = 16
    call   LCD_putc
    pop     b1
    pop     b0
    ret