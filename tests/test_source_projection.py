from fo2remix.source_projection import (
    select_art_family_records,
    source_rect_for_record,
    tile_to_reference_screen,
)


def _record(instance_id: int, tile: int, path: str, width: int, height: int) -> dict:
    return {
        "instance_id": instance_id,
        "hex_index": tile,
        "elevation": 0,
        "rotation": 0,
        "frame": 0,
        "screen_offset": [0, 0],
        "flags": {"hidden": False},
        "art": {
            "type": "scenery",
            "path": path,
            "frame": {
                "width": width,
                "height": height,
                "rotation_offsets_x": [48] * 6,
                "rotation_offsets_y": [2] * 6,
            },
        },
    }


def test_reference_screen_matches_two_known_neighbor_deltas() -> None:
    origin = tile_to_reference_screen(16491)
    same_row_neighbor = tile_to_reference_screen(16490)
    next_row = tile_to_reference_screen(16691)

    assert same_row_neighbor == (origin[0] + 32, origin[1])
    assert next_row == (origin[0] + 16, origin[1] + 12)


def test_source_rect_ports_object_get_rect_for_two_frames() -> None:
    first = _record(147, 16491, r"art\scenery\TEMPLE01.FRM", 248, 196)
    second = _record(56, 14870, r"art\scenery\TEMPLE06.FRM", 282, 166)

    first_rect = source_rect_for_record(first)
    second_rect = source_rect_for_record(second)

    assert first_rect.width == 248
    assert first_rect.height == 196
    assert first_rect.bottom - first_rect.top == 195
    assert second_rect.width == 282
    assert second_rect.height == 166
    assert first_rect != second_rect


def test_family_selection_is_case_insensitive_and_skips_hidden_records() -> None:
    visible = _record(1, 1000, r"art\scenery\TEMPLE01.FRM", 10, 20)
    hidden = _record(2, 1001, r"art\scenery\temple02.frm", 10, 20)
    hidden["flags"]["hidden"] = True
    other = _record(3, 1002, r"art\scenery\tree01.frm", 10, 20)
    scene = {"objects": {"records": [visible, hidden, other]}}

    assert select_art_family_records(scene, [r"ART\SCENERY\TEMPLE0"]) == [visible]


def test_family_selection_can_isolate_one_elevation() -> None:
    ground = _record(1, 1000, r"art\walls\temple01.frm", 10, 20)
    upper = _record(2, 1000, r"art\walls\temple01.frm", 10, 20)
    upper["elevation"] = 1
    scene = {"objects": {"records": [ground, upper]}}

    assert select_art_family_records(
        scene,
        [r"art\walls"],
        elevation=0,
    ) == [ground]
    assert select_art_family_records(
        scene,
        [r"art\walls"],
        elevation=1,
    ) == [upper]
