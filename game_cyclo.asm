;=== HANDLER TICK -- CYCLO (appele depuis handle_tick) ===

ht_cyclo:
    lds     w, g_cyclo_substate
    cpi     w, CY_ST_SPIN
    brne    htcy_check_btn
    ; Aiguille en rotation : avance de 2 positions par tick
    lds     a0, g_cyclo_pos
    subi    a0, -2              ; equivalent a ADD 2 (subi de -2)
    cpi     a0, CYCLO_NSTEPS
    brlo    htcy_pos_ok
    subi    a0, CYCLO_NSTEPS   ; wrap-around modulo 48
htcy_pos_ok:
    sts     g_cyclo_pos, a0
    ; Mise a jour LCD toutes les 2 ticks (100ms)
    lds     a0, g_anim_tick
    andi    a0, 0x01
    brne    htcy_check_btn
    call   display_cyclo_spin

htcy_check_btn:
    ; Lecture bouton PD4 avec debounce (1 action par appui)
    in      w, CYCLO_BTN_PORT
    andi    w, (1<<CYCLO_BTN_BIT)
    breq    htcy_pressed
    clr     w
    sts     g_cyclo_btn_prev, w ; bouton relache : reinitialise l'anti-rebond
    rjmp    htcy_done
htcy_pressed:
    lds     w, g_cyclo_btn_prev
    tst     w
    brne    htcy_done           ; deja traite lors de cet appui
    ldi     w, 1
    sts     g_cyclo_btn_prev, w
    call   cyclo_button_action
htcy_done:
    ret

; === ACTIONS ===

;<<< cyclo_button_action  Demarre ou arrete l'aiguille selon l'etat courant >>>

cyclo_button_action:
    lds     w, g_cyclo_substate
    cpi     w, CY_ST_IDLE
    breq    cy_start
    cpi     w, CY_ST_SPIN
    breq    cy_stop
    ret

; --- Demarrage : debite l'ante et lance l'animation ---
cy_start:
    lds     a0, g_credit_l
    lds     a1, g_credit_h
    cpi     a1, 0
    brne    cy_have_credit
    cpi     a0, CYCLO_ANTE
    brlo    cy_no_credit
cy_have_credit:
    subi    a0, CYCLO_ANTE
    sbci    a1, 0
    sts     g_credit_l, a0
    sts     g_credit_h, a1
    call   nvm_save_credit
    ; Position de depart aleatoire
    call   prng_seed
    call   prng_next
    lds     a0, g_lfsr_l
cy_pos_norm:
    cpi     a0, CYCLO_NSTEPS
    brlo    cy_pos_ok
    subi    a0, CYCLO_NSTEPS
    rjmp    cy_pos_norm
cy_pos_ok:
    sts     g_cyclo_pos, a0
    ldi     w, CY_ST_SPIN
    sts     g_cyclo_substate, w
    ldi     w, 1
    sts     g_cyclo_run, w
    call   music_start_loop    ; musique de fond pendant le spin
    call   display_cyclo_spin
    ret
cy_no_credit:
    call   buzz_lose
    call   display_cyclo_init
    ret

; --- Arret : evalue la position et distribue le gain ---
cy_stop:
    call   stop_music
    clr     w
    sts     g_cyclo_run, w
    lds     a0, g_cyclo_pos
    ;<<< Test zone jackpot [CYCLO_TARGET_LO .. CYCLO_TARGET_HI] >>>
    cpi     a0, CYCLO_TARGET_LO
    brlo    cy_check_win_low
    cpi     a0, CYCLO_TARGET_HI + 1
    brlo    cy_jackpot
    ;<<< Test zone gain haut [CYCLO_TARGET_HI+1 .. CYCLO_WIN_HI] >>>
    cpi     a0, CYCLO_WIN_HI + 1
    brlo    cy_win_only
    rjmp    cy_lose
cy_check_win_low:
    ;<<< Test zone gain bas [CYCLO_WIN_LO .. CYCLO_TARGET_LO-1] >>>
    cpi     a0, CYCLO_WIN_LO
    brlo    cy_lose
    rjmp    cy_win_only

cy_jackpot:
    lds     b0, g_credit_l
    lds     b1, g_credit_h
    ldi     w, low(1000)
    add     b0, w
    ldi     w, high(1000)
    adc     b1, w
    call   credit_clamp
    sts     g_credit_l, b0
    sts     g_credit_h, b1
    call   nvm_save_credit
    ldi     w, CY_ST_JP
    sts     g_cyclo_substate, w
    call   display_cyclo_result_jp
    call   jingle_jackpot
    ldi     a0, 8               ; 8 ticks = 400ms de jingle
    call   jingle_pump
    call   game_update_highscore
    call   display_cyclo_init
    ret

cy_win_only:
    lds     b0, g_credit_l
    lds     b1, g_credit_h
    ldi     w, 30
    add     b0, w
    clr     w
    adc     b1, w
    call   credit_clamp
    sts     g_credit_l, b0
    sts     g_credit_h, b1
    call   nvm_save_credit
    ldi     w, CY_ST_WIN
    sts     g_cyclo_substate, w
    call   display_cyclo_result_win
    call   jingle_win
    ldi     a0, 6               ; 6 ticks = 300ms
    call   jingle_pump
    call   game_update_highscore
    call   display_cyclo_init
    ret

cy_lose:
    ldi     w, CY_ST_LOSE
    sts     g_cyclo_substate, w
    call   display_cyclo_result_lose
    call   jingle_lose
    ldi     a0, 5               ; 5 ticks = 250ms
    call   jingle_pump
    call   display_cyclo_init
    ret