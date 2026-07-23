


; === PARTIE A : SONS DIRECTS (bloquants) ===

; <<<buzz_tone :Emet une tonalite carre sur PE2
; in : a0 = demi-periode (cycles / 3), a1 = nombre de periodes>>>
buzz_tone:
    push    a0
    push    a1
    push    b0
    push    b1
buzz_tone_outer:
    mov     b0, a0
    in      b1, BUZZER_PORT
    ldi     w, (1<<BUZZER_BIT)
    eor     b1, w
    out     BUZZER_PORT, b1
buzz_tone_inner:
    nop
    nop
    nop
    nop
    dec     b0
    brne    buzz_tone_inner
    dec     a1
    brne    buzz_tone_outer
    ;<<< Assure que PE2 est eteint a la fin>>>
    in      w, BUZZER_PORT
    cbr     w, (1<<BUZZER_BIT)
    out     BUZZER_PORT, w
    pop     b1
    pop     b0
    pop     a1
    pop     a0
    ret

; <<<Sons predetermines utilises par les jeux >>>

;<<< buzz_tic : bip court (utilisation generique)>>>
buzz_tic:
    ldi     a0, 50
    ldi     a1, 5
    call   buzz_tone
    ret

; <<<buzz_light : bip ascendant court pour chaque feu F1 allume>>>
buzz_light:
    ldi     a0, 40
    ldi     a1, 8
    call   buzz_tone
    ldi     a0, 25
    ldi     a1, 6
    call   buzz_tone
    ret

; <<<buzz_win : accord montant (victoire)>>>
buzz_win:
    ldi     a0, 60
    ldi     a1, 10
    call   buzz_tone
    ldi     a0, 50
    ldi     a1, 10
    call   buzz_tone
    ldi     a0, 40
    ldi     a1, 15
    call   buzz_tone
    ldi     a0, 30
    ldi     a1, 15
    call   buzz_tone
    ret

; <<<buzz_lose : accord descendant (defaite)>>>
buzz_lose:
    ldi     a0, 150
    ldi     a1, 12
    call   buzz_tone
    ldi     a0, 200
    ldi     a1, 14
    call   buzz_tone
    ldi     a0, 250
    ldi     a1, 18
    call   buzz_tone
    ret

;<<< buzz_jackpot_high : son aigu pour jackpot>>>
buzz_jackpot_high:
    ldi     a0, 25
    ldi     a1, 12
    call   buzz_tone
    ldi     a0, 20
    ldi     a1, 12
    call   buzz_tone
    ret

; <<<buzz_go : son "GO!" montant et fort (test de reaction)>>>
buzz_go:
    ldi     a0, 80
    ldi     a1, 15
    call   buzz_tone
    ldi     a0, 55
    ldi     a1, 20
    call   buzz_tone
    ldi     a0, 35
    ldi     a1, 30
    call   buzz_tone
    ldi     a0, 20
    ldi     a1, 40
    call   buzz_tone
    ret


; === PARTIE B : PRNG (generateur pseudo-aleatoire, LFSR 16 bits) ===

; <<<Utilise Timer0 et Timer2 comme sources d'entropie.>>>


prng_seed:
    in      a0, TCNT2
    sts     g_lfsr_l, a0
    com     a0
    sts     g_lfsr_h, a0
    ret

 
; <<<prng_next:  Genere le prochain nombre (LFSR Galois 16 bits)
; out : a0:a1 = nouvelle valeur du LFSR (g_lfsr_l:g_lfsr_h mis a jour)
; Polynome : x^16 + x^14 + x^13 + x^11 + 1 (tap 0xB400)>>>

prng_next:
    lds     a0, g_lfsr_l
    lds     a1, g_lfsr_h
    lsr     a1
    ror     a0
    brcc    prng_no_xor
    ldi     w, 0xB4
    eor     a1, w
prng_no_xor:
    sts     g_lfsr_l, a0
    sts     g_lfsr_h, a1
    ret


; <<<prng_symbol:  Retourne un symbole slot aleatoire via la table PRNG_SYMBOL_TABLE
; out : a0 = symbole (SYM_*)>>>

prng_symbol:
    call   prng_next
    andi    a0, 0x07
    ldi     ZL, low(PRNG_SYMBOL_TABLE * 2)
    ldi     ZH, high(PRNG_SYMBOL_TABLE * 2)
    add     ZL, a0
    clr     w
    adc     ZH, w
    lpm     a0, Z
    ret


; === PARTIE C : MOTEUR MUSIQUE (lecture de table, pilote par Timer3) ==


; <<<music_play  --  Programme Timer3 pour emettre la note de periode a0
; Le Timer3 en mode CTC avec prescaler /64 genere l'interrupt de toggle buzzer.>>>

music_play:
    clr     w
    sts     OCR3AH, w
    sts     OCR3AL, a0
    sts     TCNT3H, w
    sts     TCNT3L, w
    ldi     w, (1<<WGM32)|(1<<CS31)|(1<<CS30)  ; CTC, prescaler /64
    sts     TCCR3B, w
    ret


;<<< stop_music  --  Arrete la musique et coupe le buzzer>>>

stop_music:
    ldi     w, (1<<WGM32)           
    sts     TCCR3B, w
    in      w, BUZZER_PORT
    cbr     w, (1<<BUZZER_BIT)
    out     BUZZER_PORT, w
    clr     w
    sts     g_music_loop, w
    sts     g_music_idx,  w
    ldi     w, 0xFF
    sts     g_music_ticks, w
    ret


; <<<music_start_loop  --  Lance la musique de fond en boucle (MUSIC_TABLE)>>

music_start_loop:
    ldi     w, low(MUSIC_TABLE * 2)
    sts     g_music_table_l, w
    ldi     w, high(MUSIC_TABLE * 2)
    sts     g_music_table_h, w
    ldi     w, 1
    sts     g_music_loop, w
    clr     w
    sts     g_music_idx,   w
    sts     g_music_ticks, w
    ret


; <<<music_play_jingle  --  Lance un jingle une seule fois
; in : a0:a1 = adresse de la table (low:high, en octets flash * 2)>>>

music_play_jingle:
    sts     g_music_table_l, a0
    sts     g_music_table_h, a1
    clr     w
    sts     g_music_loop,  w
    sts     g_music_idx,   w
    sts     g_music_ticks, w
    ret


;<<< music_tick  --  Avance le sequenceur d'une unite (appeler chaque 50ms)
; Decremente le compteur de la note courante, charge la note suivante si besoin.>>>

music_tick:
    lds     a0, g_music_ticks
    tst     a0
    breq    music_next_note
    dec     a0
    sts     g_music_ticks, a0
    ret

music_next_note:
    push    ZL
    push    ZH
    lds     ZL, g_music_table_l
    lds     ZH, g_music_table_h
    lds     w,  g_music_idx
    add     ZL, w
    clr     a0
    adc     ZH, a0
    lpm     b0, Z+              ; b0 = periode (ou marqueur)
    lpm     b1, Z               ; b1 = duree
    pop     ZH
    pop     ZL
    ;<<< Marqueur STOP : fin de jingle>>>
    cpi     b0, MUSIC_STOP
    brne    mnn_check_end
    call   stop_music
    clr     w
    sts     g_music_idx, w
    ldi     w, 0xFF
    sts     g_music_ticks, w
    ret
mnn_check_end:
    ; <<<Marqueur END : fin de table>>>
    cpi     b0, MUSIC_END
    brne    mnn_play
    lds     w, g_music_loop
    tst     w
    brne    mnn_loop
    call   stop_music
    ldi     w, 0xFF
    sts     g_music_ticks, w
    ret
mnn_loop:
    clr     w
    sts     g_music_idx, w
    rjmp    music_next_note
mnn_play:
    ; <<<Note normale : avance l'index et programme Timer3>>>
    lds     w, g_music_idx
    inc     w
    inc     w                   ; chaque entree = 2 octets (periode + duree)
    sts     g_music_idx,   w
    sts     g_music_ticks, b1
    tst     b0
    breq    mnn_silent
    mov     a0, b0
    call   music_play
    ret
mnn_silent:
    ; <<<Note REST : coupe Timer3 sans toucher g_music_ticks>>>
    ldi     w, (1<<WGM32)
    sts     TCCR3B, w
    in      w, BUZZER_PORT
    cbr     w, (1<<BUZZER_BIT)
    out     BUZZER_PORT, w
    ret

; <<<< Raccourcis jingle (chargent la bonne table puis appellent music_play_jingle) >>>

jingle_win:
    ldi     a0, low(MUSIC_WIN_JINGLE * 2)
    ldi     a1, high(MUSIC_WIN_JINGLE * 2)
    call   music_play_jingle
    ret

jingle_lose:
    ldi     a0, low(MUSIC_LOSE_JINGLE * 2)
    ldi     a1, high(MUSIC_LOSE_JINGLE * 2)
    call   music_play_jingle
    ret

jingle_jackpot:
    ldi     a0, low(MUSIC_JACKPOT_JINGLE * 2)
    ldi     a1, high(MUSIC_JACKPOT_JINGLE * 2)
    call   music_play_jingle
    ret

jingle_newbest:
    ldi     a0, low(MUSIC_NEWBEST_JINGLE * 2)
    ldi     a1, high(MUSIC_NEWBEST_JINGLE * 2)
    call   music_play_jingle
    ret


; <<<jingle_pump  --  Joue le jingle courant pendant a0 ticks de 50ms
; Bloquant : attend la fin avant de rendre la main.
; Chaque note de duree D necessite D+1 appels music_tick pour avancer.>>>

jingle_pump:
    push    b0
    mov     b0, a0
jingle_pump_loop:
    call   music_tick
    WAIT_MS 50
    dec     b0
    brne    jingle_pump_loop
    call   stop_music
    pop     b0
    ret