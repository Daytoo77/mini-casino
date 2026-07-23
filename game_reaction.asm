


;=== HANDLER TICK REACTION (appele depuis handle_tick chaque 50ms) ===



;<<< ht_reaction:  Dispatche selon g_rt_substate>>>
ht_reaction:
    lds     w, g_rt_substate
    cpi     w, RT_ST_IDLE
    breq    htr_idle
    cpi     w, RT_ST_LIGHTS
    breq    htr_lights
    cpi     w, RT_ST_WAIT
    breq    htr_wait
    cpi     w, RT_ST_GO
    breq    htr_go
    ret

htr_idle:
    ret

; <<<Allumage sequentiel des feux
; g_rt_timer    = nombre de feux deja allumes [0..5]
; g_rt_beep_ctr = ticks depuis le dernier allumage (periode 8 ticks = 400ms)>>>
htr_lights:
    lds     b0, g_rt_beep_ctr
    inc     b0
    cpi     b0, 8
    brlo    htr_lights_tick     ; pas encore 400ms
    clr     b0
    lds     a0, g_rt_timer
    inc     a0                  ; allume le feu suivant
    sts     g_rt_timer, a0
    call   buzz_light
    call   display_reaction_lights
    ; <<<IMPORTANT : display_reaction_lights corrompt a0 (dernier putc = ' ').
    ; On recharge g_rt_timer depuis la SRAM avant le test de fin.>>>
    lds     a0, g_rt_timer
    cpi     a0, 5
    breq    htr_lights_done
htr_lights_tick:
    sts     g_rt_beep_ctr, b0
    ret
htr_lights_done:
    ; <<<Tous les 5 feux allumes : tirage du delai aleatoire (1.0 .. 2.55 s)>>>
    call   prng_seed
    call   prng_next
    lds     a0, g_lfsr_l
    andi    a0, 0x1F                    ; 0..31 ticks aleatoires
    subi    a0, -RT_MIN_WAIT            ; + 20 ticks minimum = 1.0 s
    sts     g_rt_timer, a0
    clr     w
    sts     g_rt_beep_ctr, w
    ldi     w, RT_ST_WAIT
    sts     g_rt_substate, w
    ret

; <<< Attente aleatoire (feux restes affiches) >>>
htr_wait:
    lds     a0, g_rt_timer
    dec     a0
    sts     g_rt_timer, a0
    brne    htr_wait_done       ; compte a rebours pas encore ecoule
    ;<<< Timer = 0 : signal GO !>>>
    clr     w
    sts     g_rt_timer, w       ; reset pour mesure du temps de reaction
    ldi     w, RT_ST_GO
    sts     g_rt_substate, w
    call   display_reaction_go
    call   buzz_go
htr_wait_done:
    ret

; <<< Mesure du temps de reaction >>>
htr_go:
    lds     a0, g_rt_timer
    inc     a0
    sts     g_rt_timer, a0
    cpi     a0, RT_TIMEOUT
    brlo    htr_go_blink
    ; <<<Timeout 5s : forfait>>>
    call   display_reaction_timeout
    call   jingle_lose
    ldi     a0, 4
    call   jingle_pump
    ldi     w, RT_ST_IDLE
    sts     g_rt_substate, w
    call   display_reaction_idle
    ret
htr_go_blink:
    ; <<<Clignotement du "PRESS!" toutes les 4 ticks (200ms)>>>
    lds     a0, g_anim_tick
    andi    a0, 0x03
    brne    htr_go_done
    call   display_reaction_go
htr_go_done:
    ret


;  === HANDLER IR -- REACTION (appele depuis handle_ir_cmd sur touche OK) ===



; <<<hi_reaction  --  Traite la pression de la touche OK selon l'etat courant>>>

hi_reaction:
    cpi     a0, RC5_KEY_OK
    breq    hr_ok
    ret

hr_ok:
    lds     w, g_rt_substate
    cpi     w, RT_ST_IDLE
    breq    hr_start
    cpi     w, RT_ST_LIGHTS
    breq    hr_early_press      ; appui pendant allumage = faux depart
    cpi     w, RT_ST_WAIT
    breq    hr_early_press      ; appui pendant attente  = faux depart
    cpi     w, RT_ST_GO
    breq    hr_stop
    ret

hr_start:
    ; <<<Lance la sequence de feux>>>
    clr     w
    sts     g_rt_timer,    w
    sts     g_rt_beep_ctr, w
    ldi     w, RT_ST_LIGHTS
    sts     g_rt_substate, w
    ldi     a0, 0
    call   display_reaction_lights
    ret

hr_early_press:
    ;<<< Faux depart : son et message, puis retour IDLE>>>
    call   buzz_lose
    ldi     w, RT_ST_IDLE
    sts     g_rt_substate, w
    call   display_reaction_falsestart
    WAIT_MS 500
    call   display_reaction_idle
    ret

hr_stop:
    ; <<<Enregistre le temps et compare au record>>>
    lds     a0, g_rt_timer
    lds     b0, g_rt_best
    cp      a0, b0
    brsh    hr_no_newbest
    ; Nouveau record !
    sts     g_rt_best, a0
    call   iee_save_best
    call   display_reaction_newbest
    call   jingle_newbest
    ldi     a0, 6
    call   jingle_pump
    ldi     w, RT_ST_IDLE
    sts     g_rt_substate, w
    call   display_reaction_idle
    ret
hr_no_newbest:
    call   display_reaction_result
    call   jingle_lose
    ldi     a0, 5
    call   jingle_pump
    ldi     w, RT_ST_IDLE
    sts     g_rt_substate, w
    call   display_reaction_idle
    ret