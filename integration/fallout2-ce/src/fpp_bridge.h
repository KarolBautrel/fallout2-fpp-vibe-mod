#ifndef FPP_BRIDGE_H
#define FPP_BRIDGE_H

#include "obj_types.h"

namespace fallout {

void fppBridgeResetMapObjects();
void fppBridgeRegisterMapObject(const Object* object, int instanceId);
void fppBridgeRegisterDoor(const Object* door);
void fppBridgeEmitMapLoaded(const char* mapName, int mapIndex, const Object* player);
void fppBridgePollPlayer(const Object* player);
void fppBridgeEmitInteraction(const Object* actor, const Object* target, int result);
void fppBridgeEmitDoorState(const Object* door);

} // namespace fallout

#endif /* FPP_BRIDGE_H */
