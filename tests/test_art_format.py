from fo2remix.art_format import ArtCatalog, fid_list_index, fid_type


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
