

handle_tick:
    lds     w, g_state
    cpi     w, ST_SPINNING
    brne    htick_chk_cyclo
    call   ht_do_spin
    ret
htick_chk_cyclo:
    cpi     w, ST_CYCLO
    brne    htick_chk_reaction
    call   ht_cyclo
    ret
htick_chk_reaction:
    cpi     w, ST_REACTION
    brne    htick_end
    call   ht_reaction
htick_end:
    ret


; <<<DISPATCHER IR>>>


handle_ir_cmd:
    lds     a0, f_ir_cmd
    lds     b0, g_last_rc5_raw
    cp      a0, b0
    brne    hi_process
    ret

hi_process:
    sts     g_last_rc5_raw, a0
    andi    a0, 0x3F

    cpi     a0, RC5_KEY_CHP
    brne    hi_chk_chm
    jmp     do_switch_game
hi_chk_chm:
    cpi     a0, RC5_KEY_CHM
    brne    hi_chk_mute
    jmp     do_switch_game
hi_chk_mute:
    cpi     a0, RC5_KEY_MUTE
    brne    hi_chk_power
    jmp     do_mute_reset
hi_chk_power:
    cpi     a0, RC5_KEY_POWER
    brne    hi_dispatch_state
    call   do_power_key
    ret

hi_dispatch_state:
    lds     w, g_state
    cpi     w, ST_IDLE
    brne    hids_chk_bet
    jmp     hi_idle_key
hids_chk_bet:
    cpi     w, ST_BETTING
    brne    hids_chk_spin
    jmp     hi_betting_key
hids_chk_spin:
    cpi     w, ST_SPINNING
    brne    hids_chk_result
    jmp     hi_spinning_key
hids_chk_result:
    cpi     w, ST_RESULT
    brne    hids_chk_go
    jmp     hi_result_key
hids_chk_go:
    cpi     w, ST_GAMEOVER
    brne    hids_chk_cyclo
    jmp     hi_gameover_key
hids_chk_cyclo:
    cpi     w, ST_CYCLO
    brne    hids_chk_react
    jmp     hi_cyclo_key
hids_chk_react:
    cpi     w, ST_REACTION
    brne    hids_end
    jmp     hi_reaction_key
hids_end:
    ret


;<<< COMMANDES GLOBALES>>>


do_power_key:
    lds     w, g_state
    cpi     w, ST_GAMEOVER
    brne    power_chk_spin
    jmp     power_add_credits
power_chk_spin:
    cpi     w, ST_SPINNING
    breq    power_ignore
    ldi     w, ST_IDLE
    sts     g_state, w
    call   display_idle
power_ignore:
    ret
power_add_credits:
    lds     b0, g_credit_l
    lds     b1, g_credit_h
    ldi     w, 100
    add     b0, w
    clr     w
    adc     b1, w
    call   credit_clamp
    sts     g_credit_l, b0
    sts     g_credit_h, b1
    call   nvm_save_credit
    ldi     w, ST_IDLE
    sts     g_state, w
    call   display_idle
    ret

do_mute_reset:
    call   stop_music
    clr     w
    sts     g_cyclo_run,      w
    sts     g_cyclo_substate, w
    sts     g_rt_substate,    w
    sts     g_bet_l,          w
    sts     g_bet_h,          w
    ldi     w, low(1000)
    sts     g_credit_l, w
    ldi     w, high(1000)
    sts     g_credit_h, w
    call   nvm_save_credit
    clr     w
    sts     g_highscore_l, w
    sts     g_highscore_h, w
    call   nvm_save_highscore
    ldi     a0, 0xFF
    sts     g_rt_best, a0
    call   iee_save_best
    ldi     w, ST_IDLE
    sts     g_state,      w
    sts     g_prev_state, w
    call   display_mute_reset
    WAIT_MS 800
    call   display_idle
    ret

do_switch_game:
    lds     w, g_state
    cpi     w, ST_CYCLO
    brne    sg_chk_reaction
    jmp     sg_cyclo_to_reaction
sg_chk_reaction:
    cpi     w, ST_REACTION
    brne    sg_slot_to_cyclo
    jmp     sg_reaction_to_slot

sg_slot_to_cyclo:
    sts     g_prev_state, w
    call   stop_music
    clr     w
    sts     g_cyclo_run,      w
    sts     g_cyclo_substate, w
    sts     g_cyclo_btn_prev, w
    ldi     w, ST_CYCLO
    sts     g_state, w
    call   display_cyclo_init
    ret

sg_cyclo_to_reaction:
    call   stop_music
    clr     w
    sts     g_cyclo_run,      w
    sts     g_cyclo_substate, w
    ldi     w, ST_REACTION
    sts     g_state, w
    clr     w
    sts     g_rt_substate, w
    call   display_reaction_idle
    ret

sg_reaction_to_slot:
    call   stop_music
    clr     w
    sts     g_rt_substate, w
    lds     w, g_prev_state
    cpi     w, ST_IDLE
    breq    sgr_restore
    cpi     w, ST_BETTING
    breq    sgr_restore
    cpi     w, ST_GAMEOVER
    breq    sgr_restore
    ldi     w, ST_IDLE
sgr_restore:
    sts     g_state, w
    cpi     w, ST_IDLE
    brne    sgr_chk_bet
    call   display_idle
    ret
sgr_chk_bet:
    cpi     w, ST_BETTING
    brne    sgr_chk_go
    call   display_betting
    ret
sgr_chk_go:
    cpi     w, ST_GAMEOVER
    brne    sgr_default
    call   display_gameover
    ret
sgr_default:
    call   display_idle
    ret


;<<< HANDLERS PAR ETAT>>>


hi_idle_key:
    cpi     a0, 10
    brlo    hi_idle_digit
    cpi     a0, RC5_KEY_VOLP
    breq    hi_idle_credit_plus
    cpi     a0, RC5_KEY_VOLM
    breq    hi_idle_credit_minus
    ret
hi_idle_digit:
    clr     w
    sts     g_bet_l, w
    sts     g_bet_h, w
    sts     g_bet_l, a0
    ldi     w, ST_BETTING
    sts     g_state, w
    call   display_betting
    ret
hi_idle_credit_plus:
    lds     b0, g_credit_l
    lds     b1, g_credit_h
    ldi     w, 50
    add     b0, w
    clr     w
    adc     b1, w
    call   credit_clamp
    sts     g_credit_l, b0
    sts     g_credit_h, b1
    call   nvm_save_credit
    call   display_idle
    ret
hi_idle_credit_minus:
    lds     b0, g_credit_l
    lds     b1, g_credit_h
    ldi     w, 50
    sub     b0, w
    clr     w
    sbc     b1, w
    brcc    hcm_no_under
    clr     b0
    clr     b1
hcm_no_under:
    sts     g_credit_l, b0
    sts     g_credit_h, b1
    call   nvm_save_credit
    call   display_idle
    ret

hi_betting_key:
    cpi     a0, 10
    brlo    hi_bet_digit
    cpi     a0, RC5_KEY_OK
    brne    hi_bet_done
    rjmp    hi_bet_launch
hi_bet_done:
    ret
hi_bet_digit:
    push    a0
    lds     b0, g_bet_l
    lds     b1, g_bet_h
    cpi     b1, 0
    brne    hbd_overflow
    cpi     b0, 100
    brsh    hbd_overflow
    ldi     w, 10
    mul     b0, w
    mov     b0, r0
    mov     b1, r1
    clr     r1
    pop     a0
    add     b0, a0
    clr     w
    adc     b1, w
    sts     g_bet_l, b0
    sts     g_bet_h, b1
    call   display_betting
    ret
hbd_overflow:
    pop     a0
    WAIT_MS 400
    clr     w
    sts     g_bet_l, w
    sts     g_bet_h, w
    ldi     w, ST_IDLE
    sts     g_state, w
    call   display_idle
    ret
hi_bet_launch:
    lds     a0, g_bet_l
    lds     a1, g_bet_h
    lds     b0, g_credit_l
    lds     b1, g_credit_h
    cp      b0, a0
    cpc     b1, a1
    brsh    bet_is_valid
    call   buzz_lose
    clr     w
    sts     g_bet_l, w
    sts     g_bet_h, w
    ldi     w, ST_IDLE
    sts     g_state, w
    call   display_idle
    ret
bet_is_valid:
    call   game_deduct_bet
    call   music_start_loop
    ldi     a0, 1
    sts     g_reel_active,   a0
    sts     g_reel_active+1, a0
    sts     g_reel_active+2, a0
    ldi     a0, 255
    sts     g_reel_speed,    a0
    sts     g_reel_speed+1,  a0
    sts     g_reel_speed+2,  a0
    ldi     w, ST_SPINNING
    sts     g_state, w
    ret

hi_spinning_key:
    cpi     a0, RC5_KEY_OK
    brne    hi_sp_done
    lds     w, g_reel_active
    tst     w
    breq    hi_sp_chk1
    clr     w
    sts     g_reel_active, w
    ret
hi_sp_chk1:
    lds     w, g_reel_active+1
    tst     w
    breq    hi_sp_chk2
    clr     w
    sts     g_reel_active+1, w
    ret
hi_sp_chk2:
    lds     w, g_reel_active+2
    tst     w
    breq    hi_sp_done
    clr     w
    sts     g_reel_active+2, w
hi_sp_done:
    ret

hi_result_key:
    call   nvm_save_credit
    call   game_update_highscore
    lds     a0, g_credit_l
    lds     a1, g_credit_h
    or      a0, a1
    brne    hi_res_idle
    ldi     w, ST_GAMEOVER
    sts     g_state, w
    call   display_gameover
    ret
hi_res_idle:
    ldi     w, ST_IDLE
    sts     g_state, w
    call   display_idle
    ret

hi_gameover_key:
    cpi     a0, RC5_KEY_VOLP
    brne    hi_go_done
    jmp     hi_idle_credit_plus
hi_go_done:
    ret

hi_cyclo_key:
    cpi     a0, RC5_KEY_OK
    brne    hck_done
    call   cyclo_button_action
hck_done:
    ret

hi_reaction_key:
    call   hi_reaction
    ret