"""Windows-only synthetic FD tests; never inspect a real source or run checker main."""
import ast
import hashlib
from pathlib import Path, PurePosixPath
import re
import stat
import time
from types import SimpleNamespace
import unittest


CHECKER = Path(__file__).resolve().parents[1] / "release-tools/check-production-source080-v7.py"
TREE = ast.parse(CHECKER.read_bytes())
NAMES = {"Refusal", "require", "identity", "deadline", "scan_source"}
NODES = [node for node in TREE.body if isinstance(node, (ast.ClassDef, ast.FunctionDef)) and node.name in NAMES]
assert len(NODES) == len(NAMES)


def row(inode, mode=stat.S_IFDIR | 0o700, **changes):
    fields = dict(st_dev=1, st_ino=inode, st_uid=1000, st_mode=mode, st_nlink=1,
                  st_size=0, st_mtime_ns=1, st_ctime_ns=1, st_file_attributes=0)
    fields.update(changes)
    return SimpleNamespace(**fields)


class Listing:
    def __init__(self, entries):
        self.entries = entries

    def __enter__(self):
        return iter(self.entries)

    def __exit__(self, *args):
        return False


class FS:
    O_RDONLY, O_DIRECTORY, O_NOFOLLOW, O_CLOEXEC = 1, 2, 4, 8

    def __init__(self, extra="dist", extra_row=None, parent=""):
        self.source = Path("synthetic-root")
        self.rows = {"": row(1), "pyproject.toml": row(2, stat.S_IFREG | 0o600)}
        if parent:
            self.rows[parent] = row(4)
        self.extra = parent + "/" + extra if parent else extra
        self.rows[self.extra] = extra_row or row(3)
        self.fds = {100: ""}
        self.opened, self.closed, self.listed, self.hashed = [], [], [], []
        self.changed_open = self.changed_stat = False

    def getuid(self):
        return 1000

    def fstat(self, fd):
        name = self.fds[fd]
        if name == self.extra and self.changed_open:
            return row(999)
        return self.rows[name]

    def stat(self, name, *, dir_fd=None, follow_symlinks):
        assert follow_symlinks is False
        if dir_fd is None:
            assert name == self.source
            return self.rows[""]
        prefix = self.fds[dir_fd]
        path = prefix + "/" + name if prefix else name
        if path == self.extra and self.changed_stat:
            return row(998)
        return self.rows[path]

    def open(self, name, flags, *, dir_fd):
        prefix = self.fds[dir_fd]
        path = prefix + "/" + name if prefix else name
        assert flags & self.O_NOFOLLOW
        assert flags & self.O_CLOEXEC
        if stat.S_ISDIR(self.rows[path].st_mode):
            assert flags & self.O_DIRECTORY
        fd = max(self.fds) + 1
        self.fds[fd] = path
        self.opened.append(path)
        return fd

    def close(self, fd):
        assert fd not in self.closed
        self.closed.append(fd)

    def scandir(self, fd):
        prefix = self.fds[fd]
        assert prefix != self.extra, "Unmanaged or unknown child contents must never be listed"
        self.listed.append(prefix)
        entries = []
        for path, info in self.rows.items():
            if not path:
                continue
            parent, _, name = path.rpartition("/")
            if parent == prefix:
                def read_stat(*, follow_symlinks, value=info):
                    assert follow_symlinks is False
                    return value
                entries.append(SimpleNamespace(name=name, stat=read_stat))
        return Listing(entries)

    def digest(self, fd, limit, end):
        assert self.fds[fd] == "pyproject.toml", "Only expected public source files may be hashed"
        self.hashed.append(self.fds[fd])
        return "expected", self.fstat(fd)

    def namespace(self):
        ns = {"os": self, "stat": stat, "time": time, "PurePosixPath": PurePosixPath,
              "SOURCE": self.source, "MAX_FILE_BYTES": 100, "MAX_ENTRIES": 100,
              "OPAQUE_EXCLUSIONS": {".git", ".venv", "frontend/dist"},
              "CACHE_FILE": re.compile(r"[^/]+\.cpython-312\.pyc\Z"),
              "canonical": lambda *args, **kwargs: None,
              "open_directory_chain": lambda path: 100, "digest_fd": self.digest}
        exec(compile(ast.Module(body=NODES, type_ignores=[]), str(CHECKER), "exec"), ns)
        return ns

    def scan(self, expected=None):
        return self.namespace()["scan_source"](expected or {"pyproject.toml": "expected"}, time.monotonic() + 5)


class PreservationTests(unittest.TestCase):
    def test_owned_normal_root_output_is_not_traversed_or_hashed(self):
        fs = FS()
        counts, files, dirs = fs.scan()
        self.assertEqual((counts["matched"], counts["unexpected"], counts["ignored_subtrees"]), (1, 0, 1))
        self.assertEqual(fs.listed, [""])
        self.assertEqual(fs.hashed, ["pyproject.toml"])
        self.assertIn("dist", dirs)
        self.assertEqual(set(fs.closed), set(fs.fds))

    def test_manifest_collisions_reject_before_opening_source(self):
        for expected in ({"dist": "x"}, {"dist/file.whl": "x"}):
            with self.subTest(expected=next(iter(expected))):
                fs = FS()
                with self.assertRaisesRegex(RuntimeError, "unmanaged_output_manifest_collision"):
                    fs.scan(expected)
                self.assertEqual((fs.opened, fs.listed, fs.hashed), ([], [], []))

    def test_wrong_type_owner_links_reparse_are_not_excluded(self):
        for info in (row(3, stat.S_IFREG | 0o600), row(3, stat.S_IFLNK | 0o700),
                     row(3, stat.S_IFIFO | 0o600), row(3, st_uid=999), row(3, st_file_attributes=0x400)):
            with self.subTest(mode=info.st_mode, uid=info.st_uid, attributes=info.st_file_attributes):
                fs = FS(extra_row=info)
                with self.assertRaises(RuntimeError):
                    fs.scan()
                self.assertNotIn("dist", fs.listed)
                self.assertEqual(set(fs.closed), set(fs.fds))

    def test_directory_replacement_refuses_and_closes_retained_fd(self):
        for stage in ("changed_open", "changed_stat"):
            with self.subTest(stage=stage):
                fs = FS(); setattr(fs, stage, True)
                with self.assertRaisesRegex(RuntimeError, "unmanaged_output_replaced"):
                    fs.scan()
                self.assertEqual(set(fs.closed), set(fs.fds))

    def test_other_unknown_outputs_still_block_without_content_reads(self):
        for extra in ("build", "dist-other", "DIST"):
            with self.subTest(extra=extra):
                fs = FS(extra=extra)
                counts, _, _ = fs.scan()
                self.assertEqual((counts["unexpected"], counts["ignored_subtrees"]), (1, 0))
                self.assertNotIn(extra, fs.opened)

    def test_nested_dist_is_not_the_root_policy(self):
        fs = FS(parent="tests")
        counts, _, _ = fs.scan({"pyproject.toml": "expected", "tests/missing.py": "x"})
        self.assertEqual((counts["missing"], counts["unexpected"], counts["ignored_subtrees"]), (1, 1, 0))
        self.assertNotIn("tests/dist", fs.opened)

    def test_existing_frontend_exclusion_is_unchanged(self):
        fs = FS(parent="frontend")
        counts, _, _ = fs.scan({"pyproject.toml": "expected", "frontend/missing.js": "x"})
        self.assertEqual((counts["missing"], counts["unexpected"], counts["ignored_subtrees"]), (1, 0, 1))
        self.assertNotIn("frontend/dist", fs.opened)

    def test_preserved_directory_identity_remains_in_two_pass_comparison(self):
        fs = FS()
        first = fs.scan()[2]
        fs.closed.clear(); fs.fds = {100: ""}
        fs.rows["dist"] = row(777)
        second = fs.scan()[2]
        self.assertNotEqual(first, second)


if __name__ == "__main__":
    unittest.main(verbosity=2)
