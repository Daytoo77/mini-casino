
;=== LOGIQUE PRINCIPALE ===

;<<< game_check_win  --  Evalue le resultat des 3 rouleaux >>>

game_check_win:
    lds     a0, g_reels
    lds     a1, g_reels+1
    lds     b0, g_reels+2
    cp      a0, a1
    brne    game_lose
    cp      a1, b0
    brne    game_lose
    cpi     a0, SYM_SEVEN
    breq    game_jackpot
    call   game_apply_x2
    ldi     a0, 1
    ret
game_jackpot:
    call   game_apply_x100
    ldi     a0, 2
    ret
game_lose:
    ldi     a0, 0
    ret

;=== game_apply_x2  --  Ajoute la mise x2 aux credits ===
;=== Utilise b0:b1 pour les credits, a0:a1 pour la mise doublee. ===
game_apply_x2:
    lds     a0, g_bet_l
    lds     a1, g_bet_h
    lsl     a0
    rol     a1
    lds     b0, g_credit_l
    lds     b1, g_credit_h
    add     b0, a0
    adc     b1, a1
    call   credit_clamp
    sts     g_credit_l, b0
    sts     g_credit_h, b1
    ret

;=== game_apply_x100  --  Ajoute la mise x100 aux credits (multiplication 16 bits) ===
game_apply_x100:
    lds     a0, g_bet_l
    lds     b1, g_bet_h
    ldi     w, 100
    mul     a0, w               ; bet_l * 100 -> r1:r0
    mov     a0, r0
    mov     a1, r1
    clr     r1
    tst     b1
    breq    gax100_done
    mul     b1, w               ; bet_h * 100 (contribue a l'octet haut)
    add     a1, r0
    clr     r1
gax100_done:
    lds     b0, g_credit_l
    lds     b1, g_credit_h
    add     b0, a0
    adc     b1, a1
    call   credit_clamp
    sts     g_credit_l, b0
    sts     g_credit_h, b1
    ret

;=== credit_clamp  --  Plafonne b1:b0 a MAX_CREDIT (9999) ===
;=== in/out : b1:b0 = valeur a plafonner ===
credit_clamp:
    cpi     b1, MAX_CREDIT_H + 1
    brsh    cc_clamp
    cpi     b1, MAX_CREDIT_H
    brne    cc_no_clamp
    cpi     b0, MAX_CREDIT_L + 1
    brlo    cc_no_clamp
cc_clamp:
    ldi     b0, MAX_CREDIT_L
    ldi     b1, MAX_CREDIT_H
cc_no_clamp:
    ret

;=== game_deduct_bet  --  Soustrait la mise des credits (sans verification) ===
game_deduct_bet:
    lds     a0, g_credit_l
    lds     a1, g_credit_h
    lds     b0, g_bet_l
    lds     b1, g_bet_h
    sub     a0, b0
    sbc     a1, b1
    sts     g_credit_l, a0
    sts     g_credit_h, a1
    ret

;=== game_update_highscore Met a jour le highscore si les credits actuels sont superieurs. Sauvegarde en EEPROM si modification. ===
game_update_highscore:
    lds     a0, g_credit_l
    lds     a1, g_credit_h
    lds     b0, g_highscore_l
    lds     b1, g_highscore_h
    cp      a1, b1
    brlo    ghs_no
    brne    ghs_yes
    cp      a0, b0
    brlo    ghs_no
ghs_yes:
    sts     g_highscore_l, a0
    sts     g_highscore_h, a1
    call   nvm_save_highscore
ghs_no:
    ret

;=== ANIMATION ROULEAUX (appelee chaque tick 50ms depuis ht_do_spin) ===


; <<< tick_reel0  --  Fait tourner le rouleau 0 ou le fige quand son compteur atteint 0 >>>
tick_reel0:
    lds     a0, g_reel_active
    tst     a0
    brne    tr0_active
    ret
tr0_active:
    lds     a0, g_reel_speed
    dec     a0
    sts     g_reel_speed, a0
    breq    tr0_stop
    call   prng_symbol
    sts     g_reels, a0
    ret
tr0_stop:
    clr     a0
    sts     g_reel_active, a0
    call   prng_symbol
    sts     g_reels, a0
    ret

;<<< tick_reel1  --  Rouleau 1 : 30% de chance d'aligner avec le rouleau 0 a l'arret >>>

tick_reel1:
    lds     a0, g_reel_active+1
    tst     a0
    brne    tr1_active
    ret
tr1_active:
    lds     a0, g_reel_speed+1
    dec     a0
    sts     g_reel_speed+1, a0
    breq    tr1_stop
    call   prng_symbol
    sts     g_reels+1, a0
    ret
tr1_stop:
    clr     a0
    sts     g_reel_active+1, a0
    call   prng_next
    cpi     a0, 77              ; seuil : ~30% de chance d'alignement
    brsh    tr1_random
    lds     a0, g_reels         ; aligne avec le rouleau 0
    sts     g_reels+1, a0
    ret
tr1_random:
    call   prng_symbol
    sts     g_reels+1, a0
    ret

;<<< tick_reel2  --  Rouleau 2 : 30% de chance d'aligner avec le rouleau 1 a l'arret >>>
tick_reel2:
    lds     a0, g_reel_active+2
    tst     a0
    brne    tr2_active
    ret
tr2_active:
    lds     a0, g_reel_speed+2
    dec     a0
    sts     g_reel_speed+2, a0
    breq    tr2_stop
    call   prng_symbol
    sts     g_reels+2, a0
    ret
tr2_stop:
    clr     a0
    sts     g_reel_active+2, a0
    call   prng_next
    cpi     a0, 90              ; seuil : ~35% de chance d'alignement
    brsh    tr2_random
    lds     a0, g_reels+1       ; aligne avec le rouleau 1
    sts     g_reels+2, a0
    ret
tr2_random:
    call   prng_symbol
    sts     g_reels+2, a0
    ret

;=== HANDLER TICK -- SPINNING (appele depuis handle_tick) ===

ht_do_spin:
    call   music_tick          ; avance le sequenceur musical
    call   tick_reel0
    call   tick_reel1
    call   tick_reel2
    ; Mise a jour affichage LCD toutes les 2 ticks (100ms)
    lds     w, g_anim_tick
    andi    w, 0x01
    brne    hds_skip_disp
    call   display_reels
hds_skip_disp:
    ; Verifie si tous les rouleaux sont arretes
    lds     a0, g_reel_active
    lds     a1, g_reel_active+1
    lds     b0, g_reel_active+2
    or      a0, a1
    or      a0, b0
    breq    PC+2                ; tous les rouleaux arretes ?
    jmp     hds_done            ; non -> encore en rotation
    ; Tous arretes : calcule et affiche le resultat
    call   stop_music
    ldi     w, ST_RESULT
    sts     g_state, w
    call   display_reels       ; symboles finaux visibles 1.5s
    WAIT_MS 1500
    call   game_check_win
    tst     a0
    breq    hds_lose
    cpi     a0, 2
    breq    hds_jackpot
hds_win:
    call   display_result_win
    call   jingle_win
    ldi     a0, 6               ; 6 ticks * 50ms = 300ms de jingle
    call   jingle_pump
    rjmp    hds_auto_result
hds_jackpot:
    call   display_jackpot_anim
    call   jingle_jackpot
    ldi     a0, 8               ; 8 ticks = 400ms
    call   jingle_pump
    rjmp    hds_auto_result
hds_lose:
    call   display_result_lose
    call   jingle_lose
    ldi     a0, 5               ; 5 ticks = 250ms
    call   jingle_pump
hds_auto_result:
    call   nvm_save_credit
    call   game_update_highscore
    lds     a0, g_credit_l
    lds     a1, g_credit_h
    or      a0, a1
    breq    hds_gameover
    ldi     w, ST_IDLE
    sts     g_state, w
    call    display_idle
    rjmp    hds_done
hds_gameover:
    ldi     w, ST_GAMEOVER
    sts     g_state, w
    call   display_gameover
hds_done:
    ret