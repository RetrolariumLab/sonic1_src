Sonic_Hurt:                                       ; Routine 4

                jsr     (SpeedToPos).l                  ; update Sonic's current position based on his velocities
                addi.w  #gravity-8,obVelY(a0)           ; apply gravity (this is 8 less than the normal gravity of $38)
                btst    #status_underwater_bit,obStatus(a0)  ; is Sonic underwater?
                beq.s   .notunderwater                  ; if not, branch
                subi.w  #gravity-$18,obVelY(a0)         ; reduce gravity to be only $10 while underwater
; loc_1380C:
.notunderwater:
                bsr.w   Sonic_HurtStop                  ; check if Sonic has landed again after taking damage and revert to normal state
                bsr.w   Sonic_LevelBound                ; make sure Sonic stays within level bounds and handle bottomless pits
                bsr.w   Sonic_RecordPosition            ; record Sonic's previous position for the invincibility stars trail
                bsr.w   Sonic_Animate                   ; run Sonic's animation scripts
                bsr.w   Sonic_LoadGfx                   ; update Sonic's graphics if necessary
                jmp     (DisplaySprite).l               ; display Sonic's sprites
; End of function Sonic_Hurt

; ---------------------------------------------------------------------------
; Subroutine to stop Sonic falling after he's been hurt
; ---------------------------------------------------------------------------

Sonic_HurtStop:
                move.w  (v_limitbtm2).w,d0              ; get current target bottom level boundary
                addi.w  #224,d0                         ; add screen height
                cmp.w   obY(a0),d0                      ; has Sonic touched the bottom level boundary?
; This would cause Sonic to die from the upper/top boundary of the level, while in hurt state
; Also, the above branch goes out of range just from enabling FixBugs
                blo.w   KillSonic                       ; if yes, kill Sonic (unsigned, this will kill Sonic if leaving the top screen)

                bsr.w   Sonic_Floor                     ; handle Sonic landing on the floor again
                btst    #status_in_air_bit,obStatus(a0)  ; is Sonic still in the air?
                bne.s   .continuehurt                   ; if yes, branch

                moveq   #0,d0                           ; clear d0
                move.w  d0,obVelY(a0)                   ; set Y-speed to 0
                move.w  d0,obVelX(a0)                   ; set X-speed to 0
                move.w  d0,obInertia(a0)                ; set ground speed to 0
                move.b  #id_Walk,obAnim(a0)             ; set to walking animation
                subq.b  #2,obRoutine(a0)                ; set routine back to Sonic_Control
                move.w  #2*60,flashtime(a0)             ; set flash time to 2 seconds of invulnerability frames

; locret_13860:
.continuehurt:
                rts                                     ; return
; End of function Sonic_HurtStop

; ===========================================================================
; ---------------------------------------------------------------------------
; Sonic when he dies (triggered from "KillSonic" in ReactToItem and when drowning)
; ---------------------------------------------------------------------------

; Obj01_Death:
Sonic_Death:                                       ; Routine 6

                bsr.w   Sonic_HandleDeath               ; handle Sonic falling, deducting a life, and maybe triggering game over
                jsr     (ObjectFall).l                  ; apply gravity
                bsr.w   Sonic_RecordPosition            ; record Sonic's previous position for the invincibility stars trail (kinda pointless here...)
                bsr.w   Sonic_Animate                   ; run Sonic's animation scripts
                bsr.w   Sonic_LoadGfx                   ; update Sonic's graphics if necessary
                jmp     (DisplaySprite).l               ; display Sonic's sprite
; End of function Sonic_Death

; ---------------------------------------------------------------------------
; Subroutine to check if Sonic has gone below the screen after dying, and
; update lives, restart the level, and potentially run game over
; ---------------------------------------------------------------------------

; GameOver: <-- old misnomer (this routine ALSO handles game overs, but not just)
Sonic_HandleDeath:
                move.w  (v_limitbtm2).w,d0              ; get current bottom boundary position
                addi.w  #$100,d0                        ; go $100 pixels lower
                cmp.w   obY(a0),d0                      ; has Sonic's death animation gone below the screen?
                bhs.w   .return                         ; if not, branch

; Bottom reached, remove a life and check if game over was triggered
                move.w  #-gravity,obVelY(a0)            ; set to -$38 to cancel ObjectFall gravity (freeze Sonic in place)
                addq.b  #2,obRoutine(a0)                ; go to Sonic_ResetLevel
                clr.b   (f_timecount).w                 ; stop time counter
                addq.b  #1,(f_lifecount).w              ; update lives counter
                subq.b  #1,(v_lives).w                  ; subtract 1 from number of lives
                bne.s   .extraLivesRemaining            ; did you run out of extra lives? if not, branch

; GAME OVER
                move.w  #0,restartime(a0)               ; set to not restart the level
                move.b  #id_GameOverCard,(v_gameovertext1).w  ; load GAME object
                move.b  #id_GameOverCard,(v_gameovertext2).w  ; load OVER object
                move.b  #1,(v_gameovertext2+obFrame).w  ; set OVER object to correct frame
                clr.b   (f_timeover).w                  ; clear time over flag

; loc_138C2:
.gameOverBgmAndPatterns:
                move.w  #bgm_GameOver,d0                ; set GAME OVER music
                jsr     (QueueSound1).l                 ; play it
                moveq   #plcid_GameOver,d0              ; set game over patterns
                jmp     (AddPLC).l                      ; load them
; ===========================================================================

; loc_138D4:
.extraLivesRemaining:
                move.w  #60,restartime(a0)              ; set reset level delay to 1 second
                tst.b   (f_timeover).w                  ; is TIME OVER tag set?
                beq.s   .return                         ; if not, branch
                move.w  #0,restartime(a0)               ; set to not restart the level
                move.b  #id_GameOverCard,(v_gameovertext1).w  ; load GAME object
                move.b  #id_GameOverCard,(v_gameovertext2).w  ; load OVER object
                move.b  #2,(v_gameovertext1+obFrame).w  ; set GAME frame to TIME
                move.b  #3,(v_gameovertext2+obFrame).w  ; set OVER frame to OVER (different frame ID, but looks identical)
                bra.s   .gameOverBgmAndPatterns         ; play music and load patterns
; ===========================================================================

; locret_13900:
.return:
                rts                                     ; return
; End of function Sonic_HandleDeath

; ===========================================================================
; ---------------------------------------------------------------------------
; Sonic after having died and fallen off the bottom of the screen
; ---------------------------------------------------------------------------

; Obj01_ResetLevel:
Sonic_ResetLevel:                                       ; Routine 8
                tst.w   restartime(a0)                  ; was no restart time set? (game over / time over)
                beq.s   .return                         ; if yes, don't restart level
                subq.w  #1,restartime(a0)               ; subtract 1 from time delay
                bne.s   .return                         ; if time remains, branch
                move.w  #1,(f_restart).w                ; restart the level

; locret_13914:
.return:
                rts                                     ; return
; End of function Sonic_ResetLevel

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to make Sonic run around loops (GHZ/SLZ)
; The visual effect of rendering Sonic behind the loop is handled through
; bit 6 in obRender, of which Sonic is the only object in the entire game
; to use it. The effect itself is handled in "FindNearestTile"
; ---------------------------------------------------------------------------
