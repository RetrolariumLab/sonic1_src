                include "src/game/world/LevelSizeLoad & BgScrollSpeed.asm"  ; merged with "LevelSizeLoad & BgScrollSpeed (JP1).asm"
                if      Revision=0
                include "src/rendering/world/DeformLayers (REV00).asm"
                include "src/rendering/world/Level Drawing (REV00).asm"
                else
                include "src/rendering/world/DeformLayers (REV01).asm"
                include "src/rendering/world/Level Drawing (REV01).asm"
                endif
                include "src/game/world/LevelLayoutLoad.asm"  ; includes LevelDataLoad, LevelLayoutLoad, and LevelLayoutLoad2

                include "src/game/world/DynamicLevelEvents.asm"

; ===========================================================================
; >>> Various level objects
                include "src/game/objects/environment/11 GHZ Bridge.asm"
                include "src/game/objects/environment/15 Swinging Platforms.asm"  ; includes "MvSonicOnPtfm" subroutine
                include "src/game/objects/environment/17 GHZ Spiked Pole Helix.asm"
                include "src/game/objects/environment/18 Platforms.asm"
                include "src/game/objects/environment/19 Unused - GHZ Ball.asm"  ; this was the rolling GHZ ball in the prototype
Map_GBall:   include "src/rendering/mappings/GHZ Ball.asm"
                include "src/game/objects/environment/1A, 53 Collapsing Ledges and Floors.asm"  ; includes "SlopeObject_AssumeStoodOn" subroutine
                include "src/game/objects/environment/1C GHZ, SYZ Scenery.asm"
                include "src/game/objects/environment/1D Unused - Switch.asm"
                include "src/game/objects/environment/2A SBZ Small Door.asm"
                include "src/game/objects/services/sub SolidWall.asm"

; ===========================================================================
; >>> Badniks, explosions, and Badnik-related objects
                include "src/game/objects/enemies/1E, 20 Badnik - Ball Hog and Cannonball.asm"
                include "src/game/objects/environment/24 Unused - Small Explosion.asm"
                include "src/game/objects/environment/27, 3F Explosions.asm"
                include "src/rendering/animation/Ball Hog.asm"
Map_Hog:   include "src/rendering/mappings/Ball Hog.asm"
Map_UnkExplode:   include "src/rendering/mappings/Unused Explosion.asm"
                include "src/rendering/mappings/Explosions.asm"
                include "src/game/objects/items/28, 29 Animals and Points.asm"
                include "src/game/objects/enemies/1F Badnik - Crabmeat.asm"
                include "src/game/objects/enemies/22, 23 Badnik - Buzz Bomber and Missile.asm"

; ===========================================================================
; >>> Rings
                include "src/game/objects/items/25, 37 Rings.asm"
                include "src/game/objects/items/4B, 7C Giant Ring and Flash.asm"
                include "src/rendering/animation/Rings.asm"
Map_Ring:
                if      Revision=0
                include "src/rendering/mappings/Rings (REV00).asm"
                else
; REV01 added an extra blank frame, possibly to mitigate
; rings occasionally popping up in the sign post sparkles
                include "src/rendering/mappings/Rings (REV01).asm"
                endif
Map_GRing:   include "src/rendering/mappings/Giant Ring.asm"
Map_Flash:   include "src/rendering/mappings/Ring Flash.asm"

; ===========================================================================
; >>> Monitors
                include "src/game/objects/items/26, 2E Monitors and Power-Ups.asm"

; ===========================================================================
; >>> Title screen objects (includes AnimateSprite)
                include "src/ui/objects/0E, 0F Title Screen - Sonic, Press Start, TM.asm"

; ===========================================================================
; >>> More Badniks and level objects
                include "src/game/objects/enemies/2B Badnik - Chopper.asm"
                include "src/game/objects/enemies/2C Badnik - Jaws.asm"
                include "src/game/objects/enemies/2D Badnik - Burrobot.asm"
                include "src/game/objects/environment/2F, 35 MZ Large Grassy Platforms and Burning Grass.asm"
Map_Fire:   include "src/rendering/mappings/Fireballs.asm"
                include "src/game/objects/environment/30 MZ Large Green Glass Blocks.asm"
                include "src/game/objects/environment/31 MZ Chained Stompers.asm"
                include "src/game/objects/environment/45 Unused - MZ Sideways Stomper.asm"
Map_CStom:   include "src/rendering/mappings/Chained Stompers.asm"
Map_SStom:   include "src/rendering/mappings/Sideways Stomper.asm"
                include "src/game/objects/environment/32 Button.asm"
                include "src/game/objects/environment/33 MZ, LZ Pushable Blocks.asm"

; ===========================================================================
; >>> Title card objects
                include "src/ui/objects/34 Title Cards.asm"
                include "src/ui/objects/39 Game Over.asm"
                include "src/ui/objects/3A Got Through Card.asm"
                include "src/game/special_stage/objects/7E, 7F Special Stage Results and Chaos Emeralds.asm"
                include "src/rendering/mappings/Title Cards.asm"  ; includes "Map_Card", "Map_Over", "Map_Got", and "Map_SSR"
Map_SSRC:   include "src/rendering/mappings/SS Result Chaos Emeralds.asm"

; ===========================================================================
; >>> More level objects
                include "src/game/objects/environment/36 Spikes.asm"
                include "src/game/objects/environment/3B GHZ Purple Rock.asm"
                include "src/game/objects/environment/49 GHZ Waterfall Sound.asm"
Map_PRock:   include "src/rendering/mappings/Purple Rock.asm"
                include "src/game/objects/environment/3C GHZ, SLZ Smashable Wall.asm"  ; includes SmashObject

; ===========================================================================
; Subroutines to run, render, and update objects
                include "src/game/objects/ExecuteObjects.asm"
                include "src/game/objects/Object Pointers.asm"  ; includes Obj_Index
                include "src/game/physics/object_motion.asm"
                include "src/rendering/sprite_queue.asm"
                include "src/game/objects/services/sub DeleteObject.asm"
                include "src/rendering/sprite_list.asm"
                include "src/game/objects/services/sub ChkObjectVisible.asm"
                include "src/game/objects/ObjPosLoad.asm"
                include "src/game/objects/services/sub FindFreeObj.asm"

; ===========================================================================
; >>> More level objects
                include "src/game/objects/items/41 Springs.asm"
                include "src/game/objects/enemies/42 Badnik - Newtron.asm"
                include "src/game/objects/enemies/43 Badnik - Roller.asm"
                include "src/game/objects/environment/44 GHZ Edge Walls.asm"
                include "src/game/objects/environment/13, 14 MZ, SLZ Fire Balls and Maker.asm"
                include "src/game/objects/environment/6D SBZ Flamethrower.asm"
                include "src/game/objects/environment/46 MZ Bricks.asm"
                include "src/game/objects/environment/12 SYZ Search Light.asm"
                include "src/game/objects/environment/47 SYZ Bumper.asm"
                include "src/game/objects/environment/0D Signpost.asm"  ; includes "GotThroughAct" subroutine
                include "src/game/objects/environment/4C, 4D MZ Lava Geyser and Maker.asm"
                include "src/game/objects/environment/4E MZ Wall of Lava.asm"
                include "src/game/objects/environment/54 MZ Invisible Lava Tag.asm"
                include "src/rendering/animation/Lava Geyser.asm"
                include "src/rendering/animation/Wall of Lava.asm"
Map_Geyser:   include "src/rendering/mappings/Lava Geyser.asm"
Map_LWall:   include "src/rendering/mappings/Wall of Lava.asm"
                include "src/game/objects/enemies/40 Badnik - Moto Bug.asm"  ; includes "_incObj/sub RememberState.asm" subroutine
                include "src/game/objects/environment/4F Unused - Splats.asm"  ; this was Splats in the prototype
                include "src/game/objects/enemies/50 Badnik - Yadrin.asm"
                include "src/game/objects/services/sub SolidObject.asm"
                include "src/game/objects/environment/51 MZ Smashable Green Block.asm"
                include "src/game/objects/environment/52 Moving Blocks.asm"
                include "src/game/objects/enemies/55 Badnik - Basaran.asm"
                include "src/game/objects/environment/56 SYZ, SLZ Floating Blocks and LZ Doors.asm"
                include "src/game/objects/environment/57 SYZ, LZ Spiked Ball and Chain.asm"
                include "src/game/objects/environment/58 SYZ Big Spiked Ball.asm"
                include "src/game/objects/environment/59 SLZ Elevators.asm"
                include "src/game/objects/environment/5A SLZ Circling Platform.asm"
                include "src/game/objects/environment/5B SLZ Staircase.asm"
                include "src/game/objects/environment/5C SLZ Foreground Pylon.asm"
                include "src/game/objects/environment/1B LZ Water Surface.asm"
                include "src/game/objects/environment/0B LZ Pole that Breaks.asm"
                include "src/game/objects/environment/0C LZ Flapping Door.asm"
                include "src/game/objects/environment/71 Invisible Solid Barriers.asm"
                include "src/game/objects/environment/5D SLZ Fan.asm"
                include "src/game/objects/environment/5E SLZ Seesaw.asm"
                include "src/game/objects/enemies/5F Badnik - Walking Bomb.asm"
                include "src/game/objects/enemies/60 Badnik - Orbinaut.asm"
                include "src/game/objects/environment/16 LZ Harpoon.asm"
                include "src/game/objects/environment/61 LZ Blocks.asm"
                include "src/game/objects/environment/62 LZ Gargoyle.asm"
                include "src/game/objects/environment/63 LZ Conveyor.asm"
                include "src/game/objects/environment/64 LZ Air Bubbles.asm"
                include "src/game/objects/environment/65 LZ Waterfalls.asm"

; ===========================================================================
; >>> Main Sonic player object
                include "src/game/player/01 Sonic.asm"

; ===========================================================================
; >>> Various unique objects
                include "src/game/objects/environment/0A LZ Drowning Countdown.asm"  ; includes ResumeMusic
                include "src/game/objects/environment/38 Shield and Invincibility.asm"
                include "src/game/special_stage/objects/4A Unused - Special Stage Entry.asm"
                include "src/game/objects/environment/08 LZ Water Splash.asm"
                include "src/rendering/animation/Shield and Invincibility.asm"
Map_Shield:   include "src/rendering/mappings/Shield and Invincibility.asm"
                include "src/rendering/animation/Special Stage Entry (Unused).asm"
Map_Vanish:   include "src/rendering/mappings/Special Stage Entry (Unused).asm"
                include "src/rendering/animation/Water Splash.asm"
Map_Splash:   include "src/rendering/mappings/Water Splash.asm"

; ===========================================================================
; >>> Collision subroutines for Sonic and other objects
                include "src/game/player/Sonic AnglePos.asm"
                include "src/game/collision/tile_scans.asm"
                include "src/game/world/ConvertCollisionArray (Unused).asm"
                include "src/game/player/Sonic Collision.asm"

; ===========================================================================
; >>> SBZ level objects
                include "src/game/objects/environment/66 SBZ Rotating Junction.asm"
                include "src/game/objects/environment/67 SBZ Running Disc.asm"
                include "src/game/objects/environment/68 SBZ Conveyor Belt.asm"
                include "src/game/objects/environment/69 SBZ Spinning Platforms and Trapdoors.asm"
                include "src/game/objects/environment/6A SBZ Saws and Pizza Cutters.asm"
                include "src/game/objects/environment/6B SBZ Stomper and Sliding Door.asm"
                include "src/game/objects/environment/6C SBZ Vanishing Platforms.asm"
                include "src/game/objects/environment/6E SBZ Electrocuter.asm"
                include "src/game/objects/environment/6F SBZ Spin Platform Conveyor.asm"
                include "src/game/objects/environment/70 SBZ Girder Block.asm"
                include "src/game/objects/environment/72 SBZ Teleporter.asm"

; ===========================================================================
; >>> Misc objects
                include "src/game/objects/enemies/78 Badnik - Caterkiller.asm"
                include "src/game/objects/items/79 Lamppost.asm"
                include "src/game/objects/environment/7D Hidden Bonuses.asm"
                include "src/game/player/8A Credits and Sonic Team Presents.asm"

; ===========================================================================
; >>> Bosses and related objects
                include "src/game/objects/bosses/3D, 48 Boss - GHZ Main and Wrecking Ball.asm"  ; includes "BossDefeated" and "BossMove" subroutines
                include "src/rendering/animation/Eggman.asm"
Map_Eggman:   include "src/rendering/mappings/Eggman.asm"
Map_BossItems:   include "src/rendering/mappings/Boss Items.asm"
                include "src/game/objects/bosses/77 Boss - LZ Main.asm"
                include "src/game/objects/bosses/73, 74 Boss - MZ Main and Fire.asm"
                include "src/game/objects/bosses/7A, 7B Boss - SLZ Main and Spike Balls.asm"
                include "src/game/objects/bosses/75, 76 Boss - SYZ Main and Blocks.asm"
                include "src/game/objects/bosses/82, 83 SBZ Eggman Cutscene and Crumbling Floor.asm"
                include "src/game/objects/bosses/85,84,86 Boss - FZ Main, Cylinders, and Plasma Balls.asm"
                include "src/game/objects/items/3E Prison Capsule.asm"

; ===========================================================================
; >>> Object-to-object touch response handler for Sonic
                include "src/game/player/Sonic ReactToItem.asm"

; ===========================================================================
; >>> Special Stage rendering and objects
; The following includes "SS_ShowLayout", "SS_AniWallsRings",
; "SS_FindFreeAnimationSlot", "SS_AniItems", and "SS_Load"
                include "src/game/special_stage/Special Stage Loading & Drawing.asm"

                include "src/game/special_stage/Special Stage Mappings & VRAM Pointers.asm"
Map_SS_Shared:   include "src/rendering/mappings/SS Shared Block.asm"
Map_SS_Glass:   include "src/rendering/mappings/SS Glass Block.asm"
Map_SS_Up:   include "src/rendering/mappings/SS UP Block.asm"
Map_SS_Down:   include "src/rendering/mappings/SS DOWN Block.asm"
Map_SS_Chaos:   include "src/rendering/mappings/SS Chaos Emeralds.asm"
                include "src/game/player/09 Sonic in Special Stage.asm"

; ===========================================================================
; >>> Deleted, blank object that is randomly mixed in here
                include "src/rendering/unused_animation_test.asm"  ; this was an animation test object for Sonic in the prototype

; ===========================================================================
; >>> Subroutine for in-place level animations in VRAM
                include "src/rendering/world/AnimateLevelGfx.asm"

; ===========================================================================
; >>> HUD objects
                include "src/ui/hud/object.asm"
                include "src/game/objects/services/sub AddPoints.asm"
                include "src/ui/hud/HUD Update.asm"     ; includes "ContScrCounter" subroutine

                include "src/ui/hud/art.asm"

; ===========================================================================
; >>> Debug Mode
                include "src/ui/debug_mode.asm"

; ===========================================================================
; >>> Level definitions
                include "src/game/world/LevelHeaders.asm"
                include "src/rendering/world/Pattern Load Cues.asm"

; ===========================================================================
