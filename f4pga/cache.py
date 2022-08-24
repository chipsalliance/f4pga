#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# Copyright (C) 2022 F4PGA Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0

from pathlib import Path
from zlib import adler32 as zlib_adler32
from json import dump as json_dump, load as json_load, JSONDecodeError

from f4pga.common import sfprint


def _get_hash(path: Path):
    if not path.is_dir():
        with path.open("rb") as rfptr:
            return zlib_adler32(rfptr.read())
    return 0  # Directories always get '0' hash.


class F4Cache:
    """
    `F4Cache` is used to track changes among dependencies and keep the status of the files on a persistent storage.
    Files which are tracked get their checksums calculated and stored in a file.
    If file's checksum differs from the one saved in a file, that means, the file has changed.
    """

    hashes: "dict[str, dict[str, str]]"
    current_hashes: "dict[str, str]"
    status: "dict[str, str]"
    cachefile_path: str

    def __init__(self, cachefile_path):
        """
        `chachefile_path` - path to a file used for persistent storage of checksums.
        """

        self.status = {}
        self.current_hashes = {}
        self.cachefile_path = cachefile_path
        self.load()

    def _try_pop_consumer(self, path: str, consumer: str):
        if self.status.get(path) and self.status[path].get(consumer):
            self.status[path].pop(consumer)
            if len(self.status[path]) == 0:
                self.status.pop(path)
        if self.hashes.get(path) and self.hashes[path].get(consumer):
            self.hashes[path].pop(consumer)
            if len(self.hashes[path]) == 0:
                self.hashes.pop(path)

    def _try_push_consumer_hash(self, path: str, consumer: str, hash):
        if not self.hashes.get(path):
            self.hashes[path] = {}
        self.hashes[path][consumer] = hash

    def _try_push_consumer_status(self, path: str, consumer: str, status):
        if not self.status.get(path):
            self.status[path] = {}
        self.status[path][consumer] = status

    def process_file(self, path: Path):
        """Process file for tracking with f4cache."""

        hash = _get_hash(path)
        self.current_hashes[path.as_posix()] = hash

    def update(self, path: Path, consumer: str):
        """Add/remove a file to.from the tracked files, update checksum if necessary and calculate status.

        Multiple hashes are stored per file, one for each consumer module.
        "__target" is used as a convention for a "fake" consumer in case the file is requested as a target and not used
        by a module within the active flow.
        """

        posix_path = path.as_posix()

        assert self.current_hashes.get(posix_path) is not None

        if not path.exists():
            self._try_pop_consumer(posix_path, consumer)
            return True

        hash = self.current_hashes[posix_path]
        last_hashes = self.hashes.get(posix_path)
        last_hash = None if last_hashes is None else last_hashes.get(consumer)

        if hash != last_hash:
            self._try_push_consumer_status(posix_path, consumer, "changed")
            self._try_push_consumer_hash(posix_path, consumer, hash)
            return True
        self._try_push_consumer_status(posix_path, consumer, "same")
        return False

    def get_status(self, path: str, consumer: str):
        """Get status for a file with a given path.
        returns 'untracked' if the file is not tracked.
        """

        assert self.current_hashes.get(path) is not None

        statuses = self.status.get(path)
        if not statuses:
            hashes = self.hashes.get(path)
            if hashes is not None:
                last_hash = hashes.get(consumer)
                if last_hash is not None:
                    if self.current_hashes[path] != last_hash:
                        return "changed"
                    return "same"
            return "untracked"
        status = statuses.get(consumer)
        if not status:
            return "untracked"
        return status

    def load(self):
        """Loads cache's state from the persistent storage"""

        try:
            with Path(self.cachefile_path).open("r") as rfptr:
                self.hashes = json_load(rfptr)
        except JSONDecodeError:
            sfprint(
                0,
                f"WARNING: `{self.cachefile_path}` f4cache is corrupted!\n"
                "This will cause flow to re-execute from the beginning.",
            )
            self.hashes = {}
        except FileNotFoundError:
            sfprint(
                0,
                f"Couldn't open `{self.cachefile_path}` cache file.\n"
                "This will cause flow to re-execute from the beginning.",
            )
            self.hashes = {}

    def save(self):
        """Saves cache's state to the persistent storage."""
        with Path(self.cachefile_path).open("w") as wfptr:
            json_dump(self.hashes, wfptr, indent=4)
