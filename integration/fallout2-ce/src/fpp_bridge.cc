#include "fpp_bridge.h"

#include <stdio.h>
#include <stdlib.h>

#include <unordered_map>

namespace fallout {

static FILE* gFppBridgeStream = nullptr;
static bool gFppBridgeOpenAttempted = false;
static unsigned long long gFppBridgeSequence = 0;
static bool gFppBridgeHasPlayerState = false;
static int gFppBridgePlayerTile = -1;
static int gFppBridgePlayerElevation = -1;
static int gFppBridgePlayerRotation = -1;
static std::unordered_map<const Object*, int> gFppBridgeInstanceIds;

static FILE* fppBridgeGetStream()
{
    if (gFppBridgeOpenAttempted) {
        return gFppBridgeStream;
    }

    gFppBridgeOpenAttempted = true;

    const char* path = getenv("FALLOUT2_FPP_BRIDGE_PATH");
    if (path == nullptr || *path == '\0') {
        return nullptr;
    }

    gFppBridgeStream = fopen(path, "ab");
    if (gFppBridgeStream == nullptr) {
        fprintf(stderr, "Unable to open Fallout 2 FPP bridge output: %s\n", path);
        return nullptr;
    }

    fprintf(gFppBridgeStream,
        "{\"schema\":\"fo2remix.bridge-v1\",\"sequence\":%llu,\"event\":\"session_started\"}\n",
        gFppBridgeSequence++);
    fflush(gFppBridgeStream);

    return gFppBridgeStream;
}

static void fppBridgeWriteJsonString(FILE* stream, const char* value)
{
    fputc('"', stream);

    if (value != nullptr) {
        const unsigned char* cursor = reinterpret_cast<const unsigned char*>(value);
        while (*cursor != '\0') {
            unsigned char ch = *cursor++;
            switch (ch) {
            case '"':
                fputs("\\\"", stream);
                break;
            case '\\':
                fputs("\\\\", stream);
                break;
            case '\b':
                fputs("\\b", stream);
                break;
            case '\f':
                fputs("\\f", stream);
                break;
            case '\n':
                fputs("\\n", stream);
                break;
            case '\r':
                fputs("\\r", stream);
                break;
            case '\t':
                fputs("\\t", stream);
                break;
            default:
                if (ch < 0x20) {
                    fprintf(stream, "\\u%04x", ch);
                } else {
                    fputc(ch, stream);
                }
                break;
            }
        }
    }

    fputc('"', stream);
}

static void fppBridgeWriteObjectState(FILE* stream, const Object* object, bool includeInstanceId)
{
    fputc('{', stream);

    if (includeInstanceId) {
        int instanceId = -1;
        auto iterator = gFppBridgeInstanceIds.find(object);
        if (iterator != gFppBridgeInstanceIds.end()) {
            instanceId = iterator->second;
        }
        fprintf(stream, "\"instance_id\":%d,", instanceId);
    }

    if (object == nullptr) {
        fputs("\"object_id\":-1,\"pid\":-1,\"hex_index\":-1,\"elevation\":-1,\"rotation\":-1}", stream);
        return;
    }

    fprintf(stream,
        "\"object_id\":%d,\"pid\":%d,\"hex_index\":%d,\"elevation\":%d,\"rotation\":%d}",
        object->id,
        object->pid,
        object->tile,
        object->elevation,
        object->rotation);
}

void fppBridgeResetMapObjects()
{
    if (fppBridgeGetStream() == nullptr) {
        return;
    }

    gFppBridgeInstanceIds.clear();
    gFppBridgeHasPlayerState = false;
}

void fppBridgeRegisterMapObject(const Object* object, int instanceId)
{
    if (fppBridgeGetStream() == nullptr || object == nullptr) {
        return;
    }

    gFppBridgeInstanceIds[object] = instanceId;
}

void fppBridgeEmitMapLoaded(const char* mapName, int mapIndex, const Object* player)
{
    FILE* stream = fppBridgeGetStream();
    if (stream == nullptr || player == nullptr) {
        return;
    }

    fprintf(stream,
        "{\"schema\":\"fo2remix.bridge-v1\",\"sequence\":%llu,\"event\":\"map_loaded\",\"map\":{\"name\":",
        gFppBridgeSequence++);
    fppBridgeWriteJsonString(stream, mapName);
    fprintf(stream, ",\"index\":%d},\"player\":", mapIndex);
    fppBridgeWriteObjectState(stream, player, false);
    fputs("}\n", stream);
    fflush(stream);

    gFppBridgePlayerTile = player->tile;
    gFppBridgePlayerElevation = player->elevation;
    gFppBridgePlayerRotation = player->rotation;
    gFppBridgeHasPlayerState = true;
}

void fppBridgePollPlayer(const Object* player)
{
    FILE* stream = fppBridgeGetStream();
    if (stream == nullptr || player == nullptr) {
        return;
    }

    if (gFppBridgeHasPlayerState
        && gFppBridgePlayerTile == player->tile
        && gFppBridgePlayerElevation == player->elevation
        && gFppBridgePlayerRotation == player->rotation) {
        return;
    }

    fprintf(stream,
        "{\"schema\":\"fo2remix.bridge-v1\",\"sequence\":%llu,\"event\":\"player_moved\",\"player\":",
        gFppBridgeSequence++);
    fppBridgeWriteObjectState(stream, player, false);
    fputs("}\n", stream);
    fflush(stream);

    gFppBridgePlayerTile = player->tile;
    gFppBridgePlayerElevation = player->elevation;
    gFppBridgePlayerRotation = player->rotation;
    gFppBridgeHasPlayerState = true;
}

void fppBridgeEmitInteraction(const Object* actor, const Object* target, int result)
{
    FILE* stream = fppBridgeGetStream();
    if (stream == nullptr) {
        return;
    }

    fprintf(stream,
        "{\"schema\":\"fo2remix.bridge-v1\",\"sequence\":%llu,\"event\":\"interaction\",\"actor\":",
        gFppBridgeSequence++);
    fppBridgeWriteObjectState(stream, actor, false);
    fputs(",\"target\":", stream);
    fppBridgeWriteObjectState(stream, target, true);
    fprintf(stream, ",\"result\":%d}\n", result);
    fflush(stream);
}

void fppBridgeEmitDoorState(const Object* door)
{
    FILE* stream = fppBridgeGetStream();
    if (stream == nullptr || door == nullptr) {
        return;
    }

    int openFlags = door->data.scenery.door.openFlags;
    bool isOpen = (openFlags & 0x01) != 0;
    fprintf(stream,
        "{\"schema\":\"fo2remix.bridge-v1\",\"sequence\":%llu,\"event\":\"object_state\",\"target\":",
        gFppBridgeSequence++);
    fppBridgeWriteObjectState(stream, door, true);
    fprintf(stream,
        ",\"state\":{\"kind\":\"door\",\"open\":%s,\"locked\":%s,\"jammed\":%s,\"blocks_movement\":%s}}\n",
        isOpen ? "true" : "false",
        (openFlags & DOOR_FLAG_LOCKED) != 0 ? "true" : "false",
        (openFlags & DOOR_FLAG_JAMMGED) != 0 ? "true" : "false",
        isOpen ? "false" : "true");
    fflush(stream);
}

} // namespace fallout
