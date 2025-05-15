## Linux O1 vs O3 desync

### Environment

* bar: test-27892-bc6a371
* engine: `2025.04.01`
* demo: 5e170b68567a56c991130742f6770e24

### Abstract

Problem appearing on demo replay when compiling with O1.

The desync manifest as different desyncs:

```
[t=00:02:55.398234][f=0020523] Error: [DESYNC WARNING] checksum b20020d7 from demo spectator 11 (Nervensaege) does not match our checksum ba313836 for frame-number 20520
[t=00:03:48.745980][f=0020584] Error: [DESYNC WARNING] checksum a60d3d3d from demo player 1 (Nicopos1) does not match our checksum 24bfda85 for frame-number 20580
[t=00:02:25.502758][f=0020584] Error: [DESYNC WARNING] checksum a60d3d3d from demo player 1 (Nicopos1) does not match our checksum afbe78ac for frame-number 20580
[t=00:02:24.402880][f=0020584] Error: [DESYNC WARNING] checksum a60d3d3d from demo player 1 (Nicopos1) does not match our checksum c08b13e for frame-number 20580
[t=00:02:02.647559][f=0020584] Error: [DESYNC WARNING] checksum a60d3d3d from demo player 1 (Nicopos1) does not match our checksum df7342c8 for frame-number 20580
[t=00:02:39.784731][f=0020645] Error: [DESYNC WARNING] checksum 42b230f3 from demo player 1 (Nicopos1) does not match our checksum 6eac3b0e for frame-number 20640
[t=00:04:18.949615][f=0024184] Error: [DESYNC WARNING] checksum 6651256 from demo spectator 11 (Nervensaege) does not match our checksum 946e0eae for frame-number 24180
[t=00:04:34.213968][f=0025624] Error: [DESYNC WARNING] checksum 51e8a35c from demo spectator 11 (Nervensaege) does not match our checksum 6903215c for frame-number 25620
```

[t=00:01:34.101007][f=0020584] Error: [DESYNC WARNING] checksum a60d3d3d from demo player 1 (Nicopos1) does not match our checksum 8217bcbf for frame-number 20580

[t=00:02:45.985651][f=0020584] Error: [DESYNC WARNING] checksum a60d3d3d from demo player 1 (Nicopos1) does not match our checksum 70876a69 for frame-number 20580


### Investigation

Started investigating the desync at frame 24184 since it seems to be the most consistent.

Checksum desyncs on the line `buildFacing = std::abs(params.facing) % NUM_FACINGS;` inside Unit.cpp, coming LoadUnit from Lua CreateUnit.

buidFacing defined as `SyncedSshort buildFacing = 0;`

Using the TRACE_SYNC cmake option and comparing, shows:

```diff
[Sync::Assert] msg=copyfloat chksum=1710051499 4
-[Sync::Assert] msg==signed int chksum=851495160  O1
+[Sync::Assert] msg==signed int chksum=1690376977 O3
```

```
 [Sync::Assert] msg=copyfloat chksum=1626636303 4
-[Sync::Assert] msg==signed int chksum=2407864291 2
+[Sync::Assert] msg==signed int chksum=1248535725 2
```

Value of params.facing is 2 (O3) or 0 (O1), coming from lua math.random(0, 3) loading a raptor_land_swarmer_basic_t1_v1.

Output from the random generator:

```
#tindex

 [f=0024146] Warning: gsRNG 0.766357 1 3 16763364 16763362

-[f=0024146] Warning: gsRNG0 16763663 16763661 # O1
-[f=0024146] Warning: gsRNG 0.056172 -3 4 16764264 16764261

+[f=0024146] Warning: gsRNG0 16763667 16763665 # O3
+[f=0024146] Warning: gsRNG 0.720095 -3 4 16764259 16764257
```

Random generator starts to diverge on `CBuilder::CreateNanoParticle`:

```
CBuilder::Update
 CBuilder::UpdateBuild
  CreateNanoParticle
```


```
CBuilder::CreateNanoParticle -> nanoPieceCache.GetNanoPiece(script)
--- problem_h_o1.rng	2025-05-13 15:57:25.125229986 +0200

 [f=0024146] Warning: gsRNGN 16763377 2
-[f=0024146] Warning: gsRNGN 16763378 2
-[f=0024146] Warning: gsRNGN 16763379 1
-[f=0024146] Warning: gsRNGN 16763383 2
-[f=0024146] Warning: gsRNGN 16763384 1
-[f=0024146] Warning: gsRNGN 16763391 2
-[f=0024146] Warning: gsRNGN 16763392 1
-[f=0024146] Warning: gsRNGN 16763393 2
(...)
-[f=0024146] Warning: gsRNG 0.056172 -3 4 16764264 16764262


+[f=0024146] Warning: gsRNGN 16763378 1
+[f=0024146] Warning: gsRNGN 16763379 2
+[f=0024146] Warning: gsRNGN 16763383 1
+[f=0024146] Warning: gsRNGN 16763384 2
+[f=0024146] Warning: gsRNGN 16763391 1
+[f=0024146] Warning: gsRNGN 16763392 2
+[f=0024146] Warning: gsRNGN 16763393 1
+[f=0024146] Warning: gsRNGN 16763394 2
(...)
+[f=0024146] Warning: gsRNG 0.720095 -3 4 16764259 16764257
```

With more logs from the output generator:


```
const int modelNanoPiece = nanoPieceCache.GetNanoPiece(script);
+++LOG_L(L_WARNING, "RNGnan %d:%d", id, modelNanoPiece);

 [f=0024146] Warning: gsRNGN 16763377 2
 [f=0024146] Warning: RNGnan 17284:9

-[f=0024146] Warning: gsRNGN 16763378 2
-[f=0024146] Warning: RNGnan 23043:12
-[f=0024146] Warning: gsRNGN 16763379 1
-[f=0024146] Warning: RNGnan 22264:7
 [f=0024146] Warning: gsRNGN 16763380 1
-[f=0024146] Warning: RNGnan 12553:2
 [f=0024146] Warning: gsRNGN 16763381 1
-[f=0024146] Warning: RNGnan 14792:2
 [f=0024146] Warning: gsRNGN 16763382 1
 [f=0024146] Warning: RNGnan 12591:2
-[f=0024146] Warning: gsRNGN 16763383 2
-[f=0024146] Warning: RNGnan 26303:12
-[f=0024146] Warning: gsRNGN 16763384 1


+[f=0024146] Warning: gsRNGN 16763378 1
+[f=0024146] Warning: RNGnan 14160:2

+[f=0024146] Warning: gsRNGN 16763379 2
+[f=0024146] Warning: RNGnan 23043:5
 [f=0024146] Warning: gsRNGN 16763380 1
+[f=0024146] Warning: RNGnan 22264:7
 [f=0024146] Warning: gsRNGN 16763381 1
+[f=0024146] Warning: RNGnan 12553:2
 [f=0024146] Warning: gsRNGN 16763382 1
+[f=0024146] Warning: RNGnan 14792:2
+[f=0024146] Warning: gsRNGN 16763383 1
 [f=0024146] Warning: RNGnan 12591:2
+[f=0024146] Warning: gsRNGN 16763384 2
```

its skipping one unit...

adjBuidSpeed is different 0.0 vs 6.66

checking where this comes from lua:

```
[t=00:04:20.847865][f=0024146] [Game::ClientReadNet][LOGMSG] sender="UnnamedPlayer (spec)" string="[Internal Lua error: Call failure] [string "LuaRules/Gadgets/unit_builder_priority.lua"]:294: Bad SetUnitBuildSpeed
stack traceback:
	[C]: in function 'spSetUnitBuildSpeed'
	[string "LuaRules/Gadgets/unit_builder_priority.lua"]:294: in function 'UpdatePassiveBuilders'
	[string "LuaRules/Gadgets/unit_builder_priority.lua"]:343: in function 'GameFrame'
	[string "LuaRules/gadgets.lua"]:1162: in function 'selffunc'
	[string "LuaRules/gadgets.lua"]:828: in function <[string "LuaRules/gadgets.lua"]:825>"
```

printing results of Spring.GetTeamResources:

```LUA
Spring.Echo("BuilderPassiveMetal", cur, stor, share, sent, rec, stallMarginInc, stallMarginSto, nonPassiveConsTotalExpenseMetal)
Spring.Echo("BuilderPassiveEnergy", cur, stor, share, sent, rec, stallMarginInc, stallMarginSto, nonPassiveConsTotalExpenseEnergy)
```

```diff
-[f=0024146] BuilderPassiveMetal, (109.349075), 10098, 0.99000001, 0, 0, 0.2, 0.01, 46.1444283
+[f=0024146] BuilderPassiveMetal, (109.382401), 10098, 0.99000001, 0, 0, 0.2, 0.01, 46.1444283

-[f=0024146] BuilderPassiveEnergy, (7054.3042), 11174.375, 0.94999999, 0, (83.119545), 0.2, 0.01, 661.737427
+[f=0024146] BuilderPassiveEnergy, (7054.30322), 11174.375, 0.94999999, 0, (83.1190796), 0.2, 0.01, 661.737427
```

inside the lua function:

```cpp
LOG_L(L_WARNING, "TeamRes %d %f %f %f %f", teamID, team->res.metal, [team->res.energy], team->resPrevReceived.metal, team->resPrevReceived.energy);
```

```diff
-[f=0023480] Warning: TeamRes 8 65.544846 [10525.155273] 0.000000 94.220757
+[f=0023480] Warning: TeamRes 8 65.544846 [10525.122070] 0.000000 94.220757
```

problem comes from CTeam::UseEnergy called from one team

```
 [f=0023479] Warning: UseResourcesX 8 10525.155273
+[f=0023479] Warning: UseResEnergy 8 10525.122070
 [f=0023480] Warning: TeamRes 2 1802.766602 47102.765625 0.000000 74.533913
```

Missing energy comes from the hit of proj 12975 on shield 25443:

```cpp
LOG_L(L_WARNING, "ResIncRepulse %d %d %d", owner->id, p->id, p->synced);
```

```
[t=00:04:04.129330][f=0023479] Warning: ResIncRepulse 25443 12975 1
[t=00:04:04.129367][f=0023479] Warning: ResRepulse 25443 12975
[t=00:04:04.129371][f=0023479] Warning: UseResEnergy 8 10525.122070 0.033333

---

[t=00:03:58.764917][f=0024031] Warning: CreateProj 12975
[t=00:03:58.764923][f=0024031] Warning: CreateProjWeapon 12975 corhllllt_hllt_4 BeamLaser
[t=00:03:58.882040][f=0024036] Warning: CreateProj 12975
[t=00:03:58.882044][f=0024036] Warning: CreateProjWeapon 12975 corhllllt_hllt_2 BeamLaser


[t=00:03:44.596155][f=0023476] Warning: CreateProj 12975
[t=00:03:44.596161][f=0023476] Warning: CreateProjWeapon 12975 raptor_allterrain_swarmer_basic_t2_v1_weapon Cannon
```

+[f=0023479] Warning: ProjRepulse 12975 9530.595703 472.013428 2108.673584 9

Enters in `CProjectileHandler::CheckShieldCollisions`

not in `repulser->IncomingProjectile`


`quadField.GetUnitsAndFeaturesColVol` not returning the repulser

turns out there's divergence in repulsor movement:

```
-[f=0015146] Warning: ProjRepMoved 25443 9547.181641 523.678772 2247.230713
+[f=0015146] Warning: ProjRepMoved 25443 9547.636719 489.366608 2253.256348

-[f=0012615] Warning: ProjRepMoved 25443 9522.237305 497.517792 2155.040039
+[f=0012615] Warning: ProjRepMoved 25443 9521.573242 489.366608 2156.106934

-[f=0012615] Warning: ProjRepMoved 25443 9521.829102 490.606628 2155.877197
+[f=0012615] Warning: ProjRepMoved 25443 9521.573242 489.366608 2156.106934
```

more prints show relWeaponMuzzlePos diverges

```
-[f=0012615] Warning: ProjRepMove 25443 9522.237305 497.517792 2155.040039 [16.406042 47.535076 24.261278]
-[f=0012615] Warning: ProjRepMoved 25443 9522.237305 497.517792 2155.040039 16.406042 47.535076 24.261278

+[f=0012615] Warning: ProjRepMove 25443 9521.573242 489.366608 2156.106934 [17.096317 39.383858 23.211105]
+[f=0012615] Warning: ProjRepMoved 25443 9521.573242 489.366608 2156.106934 17.096317 39.383858 23.211105


-[f=0012615] Warning: ProjRepMove 25443 823 9522.237305 497.517792 2155.040039 16.406042 47.535076 24.261278
-[f=0012615] Warning: ProjRepMove 25443 823 9521.573242 489.366608 2156.106934 17.096317 39.383858 23.211105

-[f=0012615] Warning: ProjRepMove 25443 823 9514.259766 476.079895 2160.560547 18.073572 26.097095 14.703983
-[f=0012615] Warning: ProjRepMoved 25443 823 9514.259766 476.079895 2160.560547 18.073572 26.097095 14.703983

+[f=0012615] Warning: ProjRepMove 25443 823 9521.573242 489.366608 2156.106934 17.096317 39.383858 23.211105
+[f=0012615] Warning: ProjRepMoved 25443 823 9521.573242 489.366608 2156.106934 17.096317 39.383858 23.211105
```

looking for the root cause and finding it comes from `CWeapon::UpdateWeaponVectors`:

```diff
-[f=0012615] Warning: ProjEmitInit 25443 824 31 9518.626953 485.991943 2162.419922 17.096317 39.383858 23.211105
+[f=0012615] Warning: ProjEmitInit 25443 824 31 9518.626953 485.991943 2162.419922 18.073572 26.097095 14.703983
```


CWeapon::UpdateWeaponVectors:

```cpp
owner->script->GetEmitDirPos(muzzlePiece, relWeaponMuzzlePos, weaponDir);
```

LocalModelPiece::GetEmitDirPos:

```cpp
emitPos = GetModelSpaceMatrix() *        original->GetEmitPos()        * WORLD_TO_OBJECT_SPACE;
emitDir = GetModelSpaceMatrix() * float4(original->GetEmitDir(), 0.0f) * WORLD_TO_OBJECT_SPACE;
```

investigation still ongoing...
