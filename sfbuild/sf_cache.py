import os
import zlib
import json

def _get_file_hash(path: str):
    with open(path, 'rb') as f:
        b = f.read()
        return str(zlib.adler32(b))

class SymbiCache:
    """
    `SymbiCache` is used to track changes among dependencies and keep
    the status of the files on a persistent storage.
    Files which are tracked get their checksums calculated and stored in a file.
    If file's checksum differs from the one saved in a file, that means, the file
    has changed.
    """

    hashes: 'dict[str, dict[str, str]]'
    status: 'dict[str, str]'
    cachefile_path: str

    def __init__(self, cachefile_path):
        """ `chachefile_path` - path to a file used for persistent storage of
        checksums. """

        self.status = {}
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
    
    def _get_last_hash(self, path: str, consumer: str):
        last_hashes = self.hashes.get(path)
        if last_hashes is None:
            return None
        return last_hashes.get(consumer)

    def update(self, path: str, consumer: str):
        """ Add/remove a file to.from the tracked files, update checksum
        if necessary and calculate status.

        Multiple hashes are stored per file, one for each consumer module.
        "__target" is used as a convention for a "fake" consumer in case the file
        is requested as a target and not used by a module within the active flow.
        """

        isdir = os.path.isdir(path)
        if not (os.path.isfile(path) or os.path.islink(path) or isdir):
            self._try_pop_consumer(path, consumer)
            return True
        hash = 0 # Directories always get '0' hash.
        if not isdir:
            hash = _get_file_hash(path)
        last_hash = self._get_last_hash(path, consumer)
        if hash != last_hash:
            self._try_push_consumer_status(path, consumer, 'changed')
            self._try_push_consumer_hash(path, consumer, hash)
            return True
        else:
            self._try_push_consumer_status(path, consumer, 'same')
            return False
    
    def get_status(self, path: str, consumer: str):
        """ Get status for a file with a given path.
        returns 'untracked' if the file is not tracked or hasn't been
        treated with `update` procedure before calling `get_status`. """

        statuses = self.status.get(path)
        if not statuses:
            return 'untracked'
        status = statuses.get(consumer)
        if not status:
            return 'untracked'
        return status
    
    def load(self):
        """Loads cache's state from the persistent storage"""

        try:
            with open(self.cachefile_path, 'r') as f:
                b = f.read()
                self.hashes = json.loads(b)
        except json.JSONDecodeError as jerr:
            print('WARNING: .symbicache is corrupted! '
                    'This will cause flow to re-execute from the beggining.')
            self.hashes = {}
        except FileNotFoundError:
            print('Couldn\'t open .symbicache cache file. '
                    'This will cause flow to re-execute from the beggining.')
            self.hashes = {}

    def save(self):
        """Saves cache's state to the persistent storage"""

        with open(self.cachefile_path, 'w') as f:
            b = json.dumps(self.hashes, indent=4)
            f.write(b)