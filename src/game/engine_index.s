                include "src/game/world/level_size_load_and_bg_scroll_speed.s"  ; merged with "LevelSizeLoad & BgScrollSpeed (JP1).asm"
                if      Revision=0
                include "src/rendering/world/deform_layers_rev00.s"
                include "src/rendering/world/level_drawing_rev00.s"
                else
                include "src/rendering/world/deform_layers_rev01.s"
                include "src/rendering/world/level_drawing_rev01.s"
                endif
                include "src/game/world/level_layout_load.s"  ; includes LevelDataLoad, LevelLayoutLoad, and LevelLayoutLoad2

                include "src/game/world/dynamic_level_events.s"

; ===========================================================================
; >>> Various level objects
                include "src/game/objects/environment/ghz/ghz_bridge.s"
                include "src/game/objects/environment/common/swinging_platforms.s"  ; includes "MvSonicOnPtfm" subroutine
                include "src/game/objects/environment/ghz/ghz_spiked_pole_helix.s"
                include "src/game/objects/environment/common/platforms.s"
                include "src/game/objects/environment/unused/unused_ghz_ball.s"  ; this was the rolling GHZ ball in the prototype
Map_GBall:   include "src/rendering/mappings/bosses/ghz_ball.s"
                include "src/game/objects/environment/common/collapsing_ledges_and_floors.s"  ; includes "SlopeObject_AssumeStoodOn" subroutine
                include "src/game/objects/environment/common/ghz_syz_scenery.s"
                include "src/game/objects/environment/unused/unused_switch.s"
                include "src/game/objects/environment/sbz/sbz_small_door.s"
                include "src/game/objects/services/solid_wall.s"

; ===========================================================================
; >>> Badniks, explosions, and Badnik-related objects
                include "src/game/objects/enemies/ball_hog_and_cannonball.s"
                include "src/game/objects/environment/unused/unused_small_explosion.s"
                include "src/game/objects/environment/common/explosions.s"
                include "src/rendering/animation/enemies/ball_hog.s"
Map_Hog:   include "src/rendering/mappings/enemies/ball_hog.s"
Map_UnkExplode:   include "src/rendering/mappings/unused/unused_explosion.s"
                include "src/rendering/mappings/environment/common/explosions.s"
                include "src/game/objects/items/animals_and_points.s"
                include "src/game/objects/enemies/crabmeat.s"
                include "src/game/objects/enemies/buzz_bomber_and_missile.s"

; ===========================================================================
; >>> Rings
                include "src/game/objects/items/rings.s"
                include "src/game/objects/items/giant_ring_and_flash.s"
                include "src/rendering/animation/items/rings.s"
Map_Ring:
                if      Revision=0
                include "src/rendering/mappings/items/rings_rev00.s"
                else
; REV01 added an extra blank frame, possibly to mitigate
; rings occasionally popping up in the sign post sparkles
                include "src/rendering/mappings/items/rings_rev01.s"
                endif
Map_GRing:   include "src/rendering/mappings/items/giant_ring.s"
Map_Flash:   include "src/rendering/mappings/items/ring_flash.s"

; ===========================================================================
; >>> Monitors
                include "src/game/objects/items/monitors_and_power_ups.s"

; ===========================================================================
; >>> Title screen objects (includes AnimateSprite)
                include "src/ui/objects/title_screen_sonic_press_start_tm.s"

; ===========================================================================
; >>> More Badniks and level objects
                include "src/game/objects/enemies/chopper.s"
                include "src/game/objects/enemies/jaws.s"
                include "src/game/objects/enemies/burrobot.s"
                include "src/game/objects/environment/mz/mz_large_grassy_platforms_and_burning_grass.s"
Map_Fire:   include "src/rendering/mappings/environment/common/fireballs.s"
                include "src/game/objects/environment/mz/mz_large_green_glass_blocks.s"
                include "src/game/objects/environment/mz/mz_chained_stompers.s"
                include "src/game/objects/environment/unused/unused_mz_sideways_stomper.s"
Map_CStom:   include "src/rendering/mappings/environment/mz/chained_stompers.s"
Map_SStom:   include "src/rendering/mappings/unused/sideways_stomper.s"
                include "src/game/objects/environment/common/button.s"
                include "src/game/objects/environment/common/mz_lz_pushable_blocks.s"

; ===========================================================================
; >>> Title card objects
                include "src/ui/objects/title_cards.s"
                include "src/ui/objects/game_over.s"
                include "src/ui/objects/got_through_card.s"
                include "src/game/special_stage/objects/special_stage_results_and_chaos_emeralds.s"
                include "src/rendering/mappings/ui/title_cards.s"  ; includes "Map_Card", "Map_Over", "Map_Got", and "Map_SSR"
Map_SSRC:   include "src/rendering/mappings/special_stage/ss_result_chaos_emeralds.s"

; ===========================================================================
; >>> More level objects
                include "src/game/objects/environment/common/spikes.s"
                include "src/game/objects/environment/ghz/ghz_purple_rock.s"
                include "src/game/objects/environment/ghz/ghz_waterfall_sound.s"
Map_PRock:   include "src/rendering/mappings/environment/ghz/purple_rock.s"
                include "src/game/objects/environment/common/ghz_slz_smashable_wall.s"  ; includes SmashObject

; ===========================================================================
; Subroutines to run, render, and update objects
                include "src/game/objects/execute_objects.s"
                include "src/game/objects/object_pointers.s"  ; includes Obj_Index
                include "src/game/physics/object_motion.s"
                include "src/rendering/sprite_queue.s"
                include "src/game/objects/services/delete_object.s"
                include "src/rendering/sprite_list.s"
                include "src/game/objects/services/chk_object_visible.s"
                include "src/game/objects/obj_pos_load.s"
                include "src/game/objects/services/find_free_obj.s"

; ===========================================================================
; >>> More level objects
                include "src/game/objects/items/springs.s"
                include "src/game/objects/enemies/newtron.s"
                include "src/game/objects/enemies/roller.s"
                include "src/game/objects/environment/ghz/ghz_edge_walls.s"
                include "src/game/objects/environment/common/mz_slz_fire_balls_and_maker.s"
                include "src/game/objects/environment/sbz/sbz_flamethrower.s"
                include "src/game/objects/environment/mz/mz_bricks.s"
                include "src/game/objects/environment/syz/syz_search_light.s"
                include "src/game/objects/environment/syz/syz_bumper.s"
                include "src/game/objects/environment/common/signpost.s"  ; includes "GotThroughAct" subroutine
                include "src/game/objects/environment/mz/mz_lava_geyser_and_maker.s"
                include "src/game/objects/environment/mz/mz_wall_of_lava.s"
                include "src/game/objects/environment/mz/mz_invisible_lava_tag.s"
                include "src/rendering/animation/environment/lava_geyser.s"
                include "src/rendering/animation/environment/wall_of_lava.s"
Map_Geyser:   include "src/rendering/mappings/environment/mz/lava_geyser.s"
Map_LWall:   include "src/rendering/mappings/environment/mz/wall_of_lava.s"
                include "src/game/objects/enemies/moto_bug.s"  ; includes "_incObj/sub RememberState.asm" subroutine
                include "src/game/objects/environment/unused/unused_splats.s"  ; this was Splats in the prototype
                include "src/game/objects/enemies/yadrin.s"
                include "src/game/objects/services/solid_object.s"
                include "src/game/objects/environment/mz/mz_smashable_green_block.s"
                include "src/game/objects/environment/common/moving_blocks.s"
                include "src/game/objects/enemies/basaran.s"
                include "src/game/objects/environment/common/syz_slz_floating_blocks_and_lz_doors.s"
                include "src/game/objects/environment/common/syz_lz_spiked_ball_and_chain.s"
                include "src/game/objects/environment/syz/syz_big_spiked_ball.s"
                include "src/game/objects/environment/slz/slz_elevators.s"
                include "src/game/objects/environment/slz/slz_circling_platform.s"
                include "src/game/objects/environment/slz/slz_staircase.s"
                include "src/game/objects/environment/slz/slz_foreground_pylon.s"
                include "src/game/objects/environment/lz/lz_water_surface.s"
                include "src/game/objects/environment/lz/lz_pole_that_breaks.s"
                include "src/game/objects/environment/lz/lz_flapping_door.s"
                include "src/game/objects/environment/common/invisible_solid_barriers.s"
                include "src/game/objects/environment/slz/slz_fan.s"
                include "src/game/objects/environment/slz/slz_seesaw.s"
                include "src/game/objects/enemies/walking_bomb.s"
                include "src/game/objects/enemies/orbinaut.s"
                include "src/game/objects/environment/lz/lz_harpoon.s"
                include "src/game/objects/environment/lz/lz_blocks.s"
                include "src/game/objects/environment/lz/lz_gargoyle.s"
                include "src/game/objects/environment/lz/lz_conveyor.s"
                include "src/game/objects/environment/lz/lz_air_bubbles.s"
                include "src/game/objects/environment/lz/lz_waterfalls.s"

; ===========================================================================
; >>> Main Sonic player object
                include "src/game/player/sonic.s"

; ===========================================================================
; >>> Various unique objects
                include "src/game/objects/environment/lz/lz_drowning_countdown.s"  ; includes ResumeMusic
                include "src/game/objects/environment/common/shield_and_invincibility.s"
                include "src/game/special_stage/objects/unused_special_stage_entry.s"
                include "src/game/objects/environment/lz/lz_water_splash.s"
                include "src/rendering/animation/items/shield_and_invincibility.s"
Map_Shield:   include "src/rendering/mappings/items/shield_and_invincibility.s"
                include "src/rendering/animation/special_stage/special_stage_entry_unused.s"
Map_Vanish:   include "src/rendering/mappings/unused/special_stage_entry_unused.s"
                include "src/rendering/animation/environment/water_splash.s"
Map_Splash:   include "src/rendering/mappings/environment/lz/water_splash.s"

; ===========================================================================
; >>> Collision subroutines for Sonic and other objects
                include "src/game/player/sonic_angle_pos.s"
                include "src/game/collision/tile_scans.s"
                include "src/game/world/convert_collision_array_unused.s"
                include "src/game/player/sonic_collision.s"

; ===========================================================================
; >>> SBZ level objects
                include "src/game/objects/environment/sbz/sbz_rotating_junction.s"
                include "src/game/objects/environment/sbz/sbz_running_disc.s"
                include "src/game/objects/environment/sbz/sbz_conveyor_belt.s"
                include "src/game/objects/environment/sbz/sbz_spinning_platforms_and_trapdoors.s"
                include "src/game/objects/environment/sbz/sbz_saws_and_pizza_cutters.s"
                include "src/game/objects/environment/sbz/sbz_stomper_and_sliding_door.s"
                include "src/game/objects/environment/sbz/sbz_vanishing_platforms.s"
                include "src/game/objects/environment/sbz/sbz_electrocuter.s"
                include "src/game/objects/environment/sbz/sbz_spin_platform_conveyor.s"
                include "src/game/objects/environment/sbz/sbz_girder_block.s"
                include "src/game/objects/environment/sbz/sbz_teleporter.s"

; ===========================================================================
; >>> Misc objects
                include "src/game/objects/enemies/caterkiller.s"
                include "src/game/objects/items/lamppost.s"
                include "src/game/objects/environment/common/hidden_bonuses.s"
                include "src/game/player/credits_and_sonic_team_presents.s"

; ===========================================================================
; >>> Bosses and related objects
                include "src/game/objects/bosses/ghz_main_and_wrecking_ball.s"  ; includes "BossDefeated" and "BossMove" subroutines
                include "src/rendering/animation/bosses/eggman.s"
Map_Eggman:   include "src/rendering/mappings/bosses/eggman.s"
Map_BossItems:   include "src/rendering/mappings/bosses/boss_items.s"
                include "src/game/objects/bosses/lz_main.s"
                include "src/game/objects/bosses/mz_main_and_fire.s"
                include "src/game/objects/bosses/slz_main_and_spike_balls.s"
                include "src/game/objects/bosses/syz_main_and_blocks.s"
                include "src/game/objects/bosses/sbz_eggman_cutscene_and_crumbling_floor.s"
                include "src/game/objects/bosses/fz_main_cylinders_and_plasma_balls.s"
                include "src/game/objects/items/prison_capsule.s"

; ===========================================================================
; >>> Object-to-object touch response handler for Sonic
                include "src/game/player/sonic_react_to_item.s"

; ===========================================================================
; >>> Special Stage rendering and objects
; The following includes "SS_ShowLayout", "SS_AniWallsRings",
; "SS_FindFreeAnimationSlot", "SS_AniItems", and "SS_Load"
                include "src/game/special_stage/special_stage_loading_and_drawing.s"

                include "src/game/special_stage/special_stage_mappings_and_vram_pointers.s"
Map_SS_Shared:   include "src/rendering/mappings/special_stage/ss_shared_block.s"
Map_SS_Glass:   include "src/rendering/mappings/special_stage/ss_glass_block.s"
Map_SS_Up:   include "src/rendering/mappings/special_stage/ss_up_block.s"
Map_SS_Down:   include "src/rendering/mappings/special_stage/ss_down_block.s"
Map_SS_Chaos:   include "src/rendering/mappings/special_stage/ss_chaos_emeralds.s"
                include "src/game/player/sonic_in_special_stage.s"

; ===========================================================================
; >>> Deleted, blank object that is randomly mixed in here
                include "src/rendering/unused_animation_test.s"  ; this was an animation test object for Sonic in the prototype

; ===========================================================================
; >>> Subroutine for in-place level animations in VRAM
                include "src/rendering/world/animate_level_gfx.s"

; ===========================================================================
; >>> HUD objects
                include "src/ui/hud/object.s"
                include "src/game/objects/services/add_points.s"
                include "src/ui/hud/hud_update.s"       ; includes "ContScrCounter" subroutine

                include "src/ui/hud/art.s"

; ===========================================================================
; >>> Debug Mode
                include "src/ui/debug_mode.s"

; ===========================================================================
; >>> Level definitions
                include "src/game/world/level_headers.s"
                include "src/rendering/world/pattern_load_cues.s"

; ===========================================================================
