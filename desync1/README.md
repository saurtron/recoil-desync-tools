## QTPFSv2 foundational desync

### Environment

* zk: v1.13.4.3 (see below for changes to force QTPFS)
* engine: `rel2503-dh`, should be around 2025.04.04.
* known good version: 8e1a0e6443b8d10a229669aefdea67212c4494d0, before QTPFSv2 was introduced.

### Abstract

We started investigating a pathing system desync on Zero-K happening both on HAPFS and QTPFS. Apparently BAR not affected.

Not 100% sure it's the same one with hapfs, since this only seems to be related to QTPFS but it's quite heavy hitting in the case of zk. for this one I did go back with git until I found it works, but that's just before QTPFSv2 was introduced, couldnt trace the exact commit since it becomes very crashy on load after it's introduced for quite some time.

Since reports where like desync is easier to reproduce with QTPFS it could be there's two different ones.

### Investigation

There are several reasons as of why this desyncs, first of all I noticed is return of `pathManager->PathUpdated(pathID)` can diverge when called inside `CGroundMoveType::CanSetNextWayPoint` this seems to be related to `pathManager->TerrainChange` inside `CBasicMapDamage::RecalcArea` (commenting that eliminates the desync).

For what I seen eventually it marks areas dirty and enqueues `QTPFS::PathCache::MarkDeadPaths` in different order and processes them in `QTPFS::PathManager::Update()`, likely that causes some divergence.

I investigated what's up with the diverging order, since not sure it's by design, or an issue with sync and it does come from `LuaPathFinder::RequestPath` calling into `QTPFS::PathManager::RequestPath` that can be called from synced or unsynced. It's suppossed to support unsynced calling, but don't think that's the case, maybe it is for HAPFS and QTPFSv1, but not QTPFSv2 atm.

I think the `for_mt` for `UpdateNodeLayer` inside `QTPFS::PathManager::Update` can also cause slight desync. Didnt see a desync itself, but I think I seen divergence, can investigate that later.

This desync hits hard on ZK and not BAR is probably because bar doesn't use lua RequestPath at least from desynced, they have couple uses but seem niche, ZK on the other hand uses it in several widgets and gadgets since they use it to check IsTargetReachable.

### Git info

```
baddf30d1271d08ab51197996c04ece3826f7bed Wed Dec 27 13:29:14 2023 +0100 - desync
226a0e67ea9ba36f4ab44fb3f76d551c15cc39a5 Fri Dec 1 16:01:10 2023 +0000 crash
b8c719442c2ae0a9a225c1c38b1c8718e290d25f desync and crash
4f6701e10c0537d1ec46909537c324a3d98cf14a Sun Nov 5 22:42:49 2023 +0000 desync slower?? 1000+
deacf22c8afcc6dc113b51d0037ffd6fc1674a4c Tue Oct 24 19:23:23 2023 +0100 CRASH
00105d79c7d8ed4631dbf808cf1c77f011189f6f Mon Oct 23 12:41:59 2023 +0100 CRASH
851ef282881e2513083d9f1c2ff0335d131b5b74 Tue Aug 29 23:18:42 2023 +0200 CRASH
8e1a0e6443b8d10a229669aefdea67212c4494d0 Tue Aug 22 02:11:43 2023 +0200 GOOD
``` 

### ZK patch

Use this, first part is just for old engines, second part is important so it will use QTPFS instead of HAPFS.

```diff
diff --git a/LuaRules/engine_compat.lua b/LuaRules/engine_compat.lua
index 76815aa56..2f1f3f8d9 100644
--- a/LuaRules/engine_compat.lua
+++ b/LuaRules/engine_compat.lua
@@ -771,7 +771,7 @@ if not Script.IsEngineMinVersion(105, 0, 2182) then
 
        if UnitDefs then
                for _, unitDef in pairs (UnitDefs) do
-                       unitDef.buildeeBuildRadius = 64 -- arbitrary
+                       --unitDef.buildeeBuildRadius = 64 -- arbitrary
                end
        end
 end
diff --git a/gamedata/modrules.lua b/gamedata/modrules.lua
index f3595bf19..7d97110ce 100644
--- a/gamedata/modrules.lua
+++ b/gamedata/modrules.lua
@@ -15,7 +15,7 @@ if (modoptions and (modoptions.mtpath == 0 or modoptions.mtpath == "0")) then
 end
 Spring.Echo("forceSingleThreaded", forceSingleThreaded)
 
-local pathExperiment = Script.IsEngineMinVersion and Script.IsEngineMinVersion(2025, 3, 0)
+local pathExperiment = true
 
 local modrules  = {
```
