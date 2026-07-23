
;=== PARTIE A : EEPROM I2C EXTERNE (24LC256, esclave 0x50) ===

;<<< nvm_write_byte  --  Ecrit a0 a l'adresse ZH:ZL >>>

nvm_write_byte:
    push    a0
    call   twi_startc
    CWAI    twi_sla_address_mtwr, EEPROM_SLA_W
    mov     a0, ZH
    call   twi_dataWR_ack
    mov     a0, ZL
    call   twi_dataWR_ack
    pop     a0
    call   twi_dataWR_ack
    call   twi_stopc
    WAIT_MS 6
    ret

;<<< nvm_read_byte  --  Lit l'octet a l'adresse ZH:ZL, retourne dans a0 

nvm_read_byte:
    call   twi_startc
    CWAI    twi_sla_address_mtwr, EEPROM_SLA_W
    mov     a0, ZH
    call   twi_dataWR_ack
    mov     a0, ZL
    call   twi_dataWR_ack
    call   twi_repstartc
    CWAI    twi_sla_address_mtrd, EEPROM_SLA_R
    call   twi_dataRD_noack
    call   twi_stopc
    ret

;<<< nvm_init  --  Verifie le magic word, formate si premier demarrage, puis charge
; Magic word 0xC0DE a l'adresse EE_MAGIC_ADDR >>>

nvm_init:
    ldi     ZL, low(EE_MAGIC_ADDR)
    ldi     ZH, high(EE_MAGIC_ADDR)
    call   nvm_read_byte
    cpi     a0, 0xC0
    brne    nvm_first_boot
    adiw    ZL, 1
    call   nvm_read_byte
    cpi     a0, 0xDE
    brne    nvm_first_boot
    rjmp    nvm_load_state

nvm_first_boot:
    ; Ecriture du magic word
    ldi     ZL, low(EE_MAGIC_ADDR)
    ldi     ZH, high(EE_MAGIC_ADDR)
    ldi     a0, 0xC0
    call   nvm_write_byte
    adiw    ZL, 1
    ldi     a0, 0xDE
    call   nvm_write_byte
    ; Highscore = 0
    ldi     ZL, low(EE_HIGHSCORE_ADDR)
    ldi     ZH, high(EE_HIGHSCORE_ADDR)
    clr     a0
    call   nvm_write_byte
    adiw    ZL, 1
    call   nvm_write_byte
    ; Credits initiaux = 100 (0x0064)
    ldi     ZL, low(EE_CREDIT_ADDR)
    ldi     ZH, high(EE_CREDIT_ADDR)
    ldi     a0, 0x00
    call   nvm_write_byte
    adiw    ZL, 1
    ldi     a0, 0x64
    call   nvm_write_byte
    ; Tete historique = 0
    ldi     ZL, low(EE_HIST_HEAD_ADDR)
    ldi     ZH, high(EE_HIST_HEAD_ADDR)
    clr     a0
    call   nvm_write_byte

nvm_load_state:
    ; Charge highscore (octet haut en premier dans l'EEPROM)
    ldi     ZL, low(EE_HIGHSCORE_ADDR)
    ldi     ZH, high(EE_HIGHSCORE_ADDR)
    call   nvm_read_byte
    sts     g_highscore_h, a0
    adiw    ZL, 1
    call   nvm_read_byte
    sts     g_highscore_l, a0
    ; Charge credits
    ldi     ZL, low(EE_CREDIT_ADDR)
    ldi     ZH, high(EE_CREDIT_ADDR)
    call   nvm_read_byte
    sts     g_credit_h, a0
    adiw    ZL, 1
    call   nvm_read_byte
    sts     g_credit_l, a0
    ret
	 
;<<< nvm_save_credit  --  Sauvegarde g_credit_h:g_credit_l dans l'EEPROM >>>
nvm_save_credit:
    ldi     ZL, low(EE_CREDIT_ADDR)
    ldi     ZH, high(EE_CREDIT_ADDR)
    lds     a0, g_credit_h
    call   nvm_write_byte
    adiw    ZL, 1
    lds     a0, g_credit_l
    call   nvm_write_byte
    ret

;<<< nvm_save_highscore  --  Sauvegarde g_highscore_h:g_highscore_l dans l'EEPROM >>>
nvm_save_highscore:
    ldi     ZL, low(EE_HIGHSCORE_ADDR)
    ldi     ZH, high(EE_HIGHSCORE_ADDR)
    lds     a0, g_highscore_h
    call   nvm_write_byte
    adiw    ZL, 1
    lds     a0, g_highscore_l
    call   nvm_write_byte
    ret

;=== PARTIE B : EEPROM INTERNE (registres EEAR/EEDR/EECR) ===
;=== Usage : stockage du meilleur temps de reaction (1 octet) ===

; ------------------------------------------------------------------------------
; iee_write_byte  --  Ecrit a0 a l'adresse ZH:ZL de l'EEPROM interne
; Attend la fin de toute ecriture precedente, puis execute la sequence
; obligatoire EEMWE -> EEWE (doc ATmega128, section 4.4).
; Les interruptions sont desactivees pendant la sequence critique.
; ------------------------------------------------------------------------------
iee_write_byte:
iee_wb_wait:
    sbic    EECR, EEWE
    rjmp    iee_wb_wait
    cli
    out     EEARH, ZH
    out     EEARL, ZL
    out     EEDR,  a0
    sbi     EECR, EEMWE             ; master write enable
    sbi     EECR, EEWE              ; write enable (doit suivre dans les 4 cycles)
    sei
    ret

;<<< iee_read_byte  --  Lit l'octet a l'adresse ZH:ZL, retourne dans a0>>>

iee_read_byte:
iee_rb_wait:
    sbic    EECR, EEWE
    rjmp    iee_rb_wait
    out     EEARH, ZH
    out     EEARL, ZL
    sbi     EECR, EERE
    in      a0, EEDR
    ret

;<<< iee_init_best  --  Charge g_rt_best depuis l'EEPROM interne au demarrage >>>

iee_init_best:
    ldi     ZL, low(IEE_RT_BEST_ADDR)
    ldi     ZH, high(IEE_RT_BEST_ADDR)
    call   iee_read_byte
    sts     g_rt_best, a0
    ret

;<<< iee_save_best  --  Sauvegarde g_rt_best dans l'EEPROM interne >>>
iee_save_best:
    ldi     ZL, low(IEE_RT_BEST_ADDR)
    ldi     ZH, high(IEE_RT_BEST_ADDR)
    lds     a0, g_rt_best
    call   iee_write_byte
    ret