from fo2remix.art_format import (
    ArtCatalog,
    fid_animation,
    fid_list_index,
    fid_type,
    fid_weapon_animation,
)


class _Archive:
    def __init__(self, entries: dict[str, bytes]) -> None:
        self.entries = {path.lower(): payload for path, payload in entries.items()}

    def read(self, path: str) -> bytes:
        return self.entries[path.lower()]


def test_resolves_two_wall_fids_with_zero_based_list_indices() -> None:
    archive = _Archive(
        {
            r"art\walls\walls.lst": (
                b"first.frm\nblock.frm metadata\ntemple02.frm;comment\n"
            )
        }
    )
    catalog = ArtCatalog(archive)  # type: ignore[arg-type]

    block = catalog.resolve(0x03000001)
    temple = catalog.resolve(0x03000002)

    assert block.path == r"art\walls\block.frm"
    assert temple.path == r"art\walls\temple02.frm"
    assert block.list_index == 1
    assert temple.list_index == 2
    assert fid_type(0x03000001) == 3
    assert fid_list_index(0x03001002) == 2


def test_resolves_two_critter_fids_with_fallout_animation_codes() -> None:
    archive = _Archive(
        {
            r"art\critters\critters.lst": (
                b"hmjmps,0,1\nmarobm,0,1\n"
            )
        }
    )
    catalog = ArtCatalog(archive)  # type: ignore[arg-type]

    unarmed_stand = catalog.resolve(0x01000001)
    spear_stand = catalog.resolve(0x01004000)

    assert unarmed_stand.path == r"art\critters\marobmaa.frm"
    assert spear_stand.path == r"art\critters\hmjmpsga.frm"
    assert fid_animation(0x01134000) == 19
    assert fid_weapon_animation(0x01004000) == 4
