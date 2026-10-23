#include "fpp_bridge.h"

#include <stdio.h>
#include <stdlib.h>

using namespace fallout;

int main(int argc, char** argv)
{
    if (argc != 2) {
        fprintf(stderr, "usage: fallout2_fpp_bridge_contract <trace-path>\n");
        return 2;
    }

    remove(argv[1]);

#ifdef _WIN32
    if (_putenv_s("FALLOUT2_FPP_BRIDGE_PATH", argv[1]) != 0) {
        return 3;
    }
#else
    if (setenv("FALLOUT2_FPP_BRIDGE_PATH", argv[1], 1) != 0) {
        return 3;
    }
#endif

    Object player = {};
    player.id = 18000;
    player.pid = 16777216;
    player.tile = 18492;
    player.elevation = 0;
    player.rotation = 1;

    Object target = {};
    target.id = 16;
    target.pid = 33554448;
    target.tile = 15284;
    target.elevation = 0;
    target.rotation = 0;

    fppBridgeResetMapObjects();
    fppBridgeRegisterMapObject(&target, 17);
    fppBridgeRegisterDoor(&target);
    fppBridgeEmitMapLoaded("AR\"TEMPLE.MAP", 1, &player);

    // An unchanged frame must not duplicate player state.
    fppBridgePollPlayer(&player);

    player.rotation = 2;
    fppBridgePollPlayer(&player);
    fppBridgeEmitInteraction(&player, &target, 0);
    target.data.scenery.door.openFlags = 0x01;
    fppBridgeEmitDoorState(&target);

    return 0;
}
